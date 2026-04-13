#' Fetch metadata from all nodes in a Gen3 data dictionary
#'
#' Retrieves nodes in topological order using \code{get_node_order} and fetches
#' data for each node. Returns a metadata_collection object where nodes are
#' accessible via \code{$} (raw JSON as nested lists). Call \code{to_df()} on
#' the result to get a similar object with data.frames.
#'
#' @param key_file Character string path to the Gen3 credentials JSON file
#' @param program_name Character string name of the program
#' @param project_code Character string code of the project
#'
#' @return A metadata_collection object. Access nodes via \code{result$subject}.
#'   Call \code{to_df(result)} to get data.frames instead.
#'
#' @importFrom httr GET http_error content status_code
#' @importFrom jsonlite fromJSON
#' @importFrom glue glue
#' @export
fetch_all_metadata <- function(key_file, program_name, project_code) {

    # Check that the key file exists
    if (!file.exists(key_file)) {
        stop("Key file not found: ", key_file)
    }

    # Get node order
    nodes <- get_node_order(key_file)

    # Create and authenticate parser
    gen3 <- Gen3MetadataParser(key_file)
    gen3 <- authenticate(gen3)

    # Initialize result lists
    json_results <- list()
    pd_results <- list()

    # Loop through nodes and fetch data
    for (node_name in nodes) {
        result <- tryCatch({
            url <- glue::glue(
                "{gen3$base_url}/api/v0/submission",
                "/{program_name}/{project_code}/export/"
            )

            res <- httr::GET(
                url,
                gen3$headers,
                query = list(node_label = node_name, format = "json")
            )

            if (httr::http_error(res)) {
                warning(sprintf("Skipping node '%s': HTTP %s",
                                node_name, httr::status_code(res)))
                NULL
            } else {
                content_text <- httr::content(res, as = "text", encoding = "UTF-8")
                list(
                    json = jsonlite::fromJSON(content_text, simplifyVector = FALSE)$data,
                    pd   = jsonlite::fromJSON(content_text, flatten = TRUE)$data
                )
            }
        }, error = function(e) {
            warning(sprintf("Skipping node '%s': %s", node_name, conditionMessage(e)))
            NULL
        })

        if (!is.null(result)) {
            json_results[[node_name]] <- result$json
            pd_results[[node_name]] <- result$pd
        }
    }

    obj <- json_results
    attr(obj, "pd_results") <- pd_results
    class(obj) <- "metadata_collection"
    return(obj)
}


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
