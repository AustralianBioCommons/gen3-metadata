#' Fetch metadata from all nodes in a Gen3 data dictionary
#'
#' Retrieves nodes in topological order using \code{get_node_order} and fetches
#' data for each node. Returns a metadata_collection object where nodes are
#' accessible via \code{$} (raw JSON as nested lists). Call \code{to_df()} on
#' the result to get a similar object with data.frames.
#'
#' @param key_file Character string: either a path to the Gen3 credentials
#'   JSON file, or the raw credentials JSON string itself (auto-detected)
#' @param program_name Character string name of the program
#' @param project_code Character string code of the project
#' @param data_release Filter for records by data release.
#'   Defaults to \code{"latest"}.
#'   \itemize{
#'     \item \code{"latest"} (default): per node, inspect the
#'       \code{data_release_date} field and keep only records matching the
#'       max ISO date. The selected date is emitted once per node via
#'       \code{message()}. Nodes without a \code{data_release_date} field
#'       pass through unchanged and are aggregated into a single summary
#'       note at the end.
#'     \item Any other string: exact, case-sensitive match on the top-level
#'       \code{data_release} field. Nodes without that field pass through
#'       unchanged.
#'     \item \code{NULL}: disable filtering entirely (returns all records,
#'       no messages).
#'   }
#' @param verbose Logical: show a progress bar and emit progress messages
#'   plus a final summary. Defaults to \code{TRUE}. All console output is
#'   emitted as message-class conditions, so \code{suppressMessages()}
#'   silences it too. Full detail on genuine failures (network errors and
#'   the like) is still raised as a single aggregated \code{warning()}.
#'
#' @details Nodes the export endpoint rejects with an HTTP error (Gen3 does
#'   this for administrative nodes such as \code{root}, \code{program},
#'   \code{project} and \code{data_release}) and nodes with zero records are
#'   reported as "no data available" in the final summary -- they are not
#'   failures. Only network errors and unexpected exceptions are counted as
#'   failed, listed in the summary, and raised as one aggregated warning.
#'
#' @return A metadata_collection object. Access nodes via \code{result$subject}.
#'   Call \code{to_df(result)} to get data.frames instead.
#'
#' @importFrom httr GET http_error content status_code timeout
#' @importFrom jsonlite fromJSON
#' @importFrom glue glue
#' @importFrom cli cli_alert_info cli_alert_success cli_alert_danger
#'   cli_progress_bar cli_progress_update cli_progress_done
#' @export
fetch_all_metadata <- function(key_file, program_name, project_code,
                               data_release = "latest", verbose = TRUE) {

    # Check that the key file exists (skipped for a raw credentials JSON string)
    if (!is_raw_json_credentials(key_file) && !file.exists(key_file)) {
        stop("Key file not found: ", key_file)
    }

    if (verbose) {
        cli::cli_alert_info("fetch_all_metadata: starting for {program_name}/{project_code}")
    }

    # Get node order (fetches the public data dictionary). Wrap so a DNS /
    # connectivity failure produces a readable error instead of an httr
    # traceback.
    if (verbose) {
        cli::cli_alert_info("fetch_all_metadata: fetching data dictionary...")
    }
    nodes <- tryCatch({
        get_node_order(key_file)
    }, error = function(e) {
        stop(sprintf(
            "Could not fetch Gen3 data dictionary. Check VPN / network connectivity. Underlying error: %s",
            conditionMessage(e)
        ), call. = FALSE)
    })
    total <- length(nodes)
    if (verbose) {
        cli::cli_alert_info("fetch_all_metadata: {total} nodes to fetch")
    }

    # Create and authenticate parser. Wrap the auth POST too so offline runs
    # surface a clean error instead of an httr stack.
    gen3 <- Gen3MetadataParser(key_file)
    gen3 <- tryCatch({
        authenticate(gen3)
    }, error = function(e) {
        stop(sprintf(
            "Could not authenticate with Gen3 at %s. Check credentials and network connectivity. Underlying error: %s",
            gen3$base_url %||% "unknown host",
            conditionMessage(e)
        ), call. = FALSE)
    })

    # Initialize result lists and per-outcome bookkeeping
    json_results <- list()
    pd_results <- list()
    nodes_with_data <- character(0)
    no_data_nodes <- character(0)     # HTTP-rejected or zero-record: benign
    failed_nodes <- character(0)      # genuine problems only
    failed_reasons <- character(0)
    passthrough_nodes <- character(0) # nodes with no release metadata
    total_records <- 0L

    filter_log_fn <- if (verbose) message else function(m) invisible(NULL)

    node_name <- ""
    if (verbose) {
        cli::cli_progress_bar(
            format = paste0("Fetching {total} nodes {cli::pb_bar} ",
                            "{cli::pb_current}/{cli::pb_total} | {node_name}"),
            total = total
        )
    }

    # Loop through nodes and fetch data
    for (i in seq_along(nodes)) {
        node_name <- nodes[i]

        result <- tryCatch({
            url <- glue::glue(
                "{gen3$base_url}/api/v0/submission",
                "/{program_name}/{project_code}/export/"
            )

            res <- httr::GET(
                url,
                gen3$headers,
                query = list(node_label = node_name, format = "json"),
                httr::timeout(.DEFAULT_TIMEOUT)
            )

            if (httr::http_error(res)) {
                # The Gen3 export endpoint rejects administrative nodes
                # (root, program, project, data_release) with 4xx/5xx --
                # treat any HTTP error as "no data available", not a failure.
                list(outcome = "no_data")
            } else {
                content_text <- httr::content(res, as = "text", encoding = "UTF-8")
                parsed_json <- jsonlite::fromJSON(content_text, simplifyVector = FALSE)$data
                parsed_pd   <- jsonlite::fromJSON(content_text, flatten = TRUE)$data

                filtered <- filter_records_by_data_release(
                    records      = parsed_json,
                    data_release = data_release,
                    node_name    = node_name,
                    log_fn       = filter_log_fn,
                    on_passthrough = function(m) {
                        passthrough_nodes <<- c(passthrough_nodes, node_name)
                    }
                )

                if (is.data.frame(parsed_pd) && length(filtered$keep_idx) > 0) {
                    pd_filtered <- parsed_pd[filtered$keep_idx, , drop = FALSE]
                    rownames(pd_filtered) <- NULL
                } else if (is.data.frame(parsed_pd)) {
                    pd_filtered <- parsed_pd[0, , drop = FALSE]
                } else {
                    pd_filtered <- parsed_pd
                }

                list(
                    outcome = if (length(parsed_json) > 0) "with_data" else "empty",
                    json = filtered$records,
                    pd   = pd_filtered
                )
            }
        }, error = function(e) {
            list(outcome = "failed", reason = conditionMessage(e))
        })

        if (result$outcome %in% c("with_data", "empty")) {
            json_results[[node_name]] <- result$json
            pd_results[[node_name]] <- result$pd
            if (identical(result$outcome, "with_data")) {
                nodes_with_data <- c(nodes_with_data, node_name)
                total_records <- total_records + length(result$json)
            } else {
                no_data_nodes <- c(no_data_nodes, node_name)
            }
        } else if (identical(result$outcome, "no_data")) {
            no_data_nodes <- c(no_data_nodes, node_name)
        } else {
            failed_nodes <- c(failed_nodes, node_name)
            failed_reasons <- c(failed_reasons, result$reason)
        }

        if (verbose) cli::cli_progress_update()
    }
    if (verbose) cli::cli_progress_done()

    if (verbose) {
        with_data_txt <- sprintf("nodes with data: %d (%d records)",
                                 length(nodes_with_data), total_records)
        cli::cli_alert_success("{with_data_txt}")

        no_data_txt <- sprintf("nodes with no data: %d%s",
                               length(no_data_nodes),
                               if (length(no_data_nodes) > 0) {
                                   sprintf(" (%s)", paste(no_data_nodes, collapse = ", "))
                               } else "")
        cli::cli_alert_info("{no_data_txt}")

        if (length(failed_nodes) > 0) {
            failed_txt <- sprintf("failed: %d", length(failed_nodes))
            cli::cli_alert_danger("{failed_txt}")
            for (j in seq_along(failed_nodes)) {
                failed_detail <- sprintf("  - %s: %s", failed_nodes[j], failed_reasons[j])
                cli::cli_alert_danger("{failed_detail}")
            }
        } else {
            cli::cli_alert_success("failed: 0")
        }

        if (!is.null(data_release) && length(passthrough_nodes) > 0) {
            passthrough_txt <- sprintf(
                "note: no release metadata on %d node(s) (%s); records passed through unchanged",
                length(passthrough_nodes), paste(passthrough_nodes, collapse = ", "))
            cli::cli_alert_info("{passthrough_txt}")
        }
    }

    if (length(failed_nodes) > 0) {
        warning(sprintf(
            "fetch_all_metadata: %d node(s) failed: %s",
            length(failed_nodes),
            paste(sprintf("%s (%s)", failed_nodes, failed_reasons), collapse = ", ")
        ), call. = FALSE)
    }

    obj <- json_results
    attr(obj, "pd_results") <- pd_results
    class(obj) <- "metadata_collection"
    return(obj)
}

# Default HTTP request timeout, seconds. Used by every httr::GET / httr::POST
# in this package to prevent indefinite hangs on network failure.
.DEFAULT_TIMEOUT <- 30

# Null-coalesce operator for use inside stop() messages.
`%||%` <- function(a, b) if (is.null(a) || identical(a, "")) b else a


#' Convert metadata collection to data.frames
#'
#' @param x A metadata_collection object
#' @param ... Additional arguments (unused)
#'
#' @return A named list where each element is a data.frame for a node
#'
#' @export
to_df <- function(x, ...) {
    UseMethod("to_df")
}


#' @export
to_df.metadata_collection <- function(x, ...) {
    attr(x, "pd_results")
}
