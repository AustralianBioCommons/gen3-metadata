#' Get topological node order from a Gen3 data dictionary
#'
#' Fetches the public data dictionary endpoint for a Gen3 commons,
#' walks each non-excluded node's links to build a directed graph, and
#' returns the nodes in topological (parent-before-child) order using
#' Kahn's algorithm. Pure R — no Python dependency.
#'
#' The dictionary endpoint (\code{/api/v0/submission/_dictionary/_all})
#' is unauthenticated, but the credentials JSON file is still required
#' to derive the base URL from the JWT \code{iss} claim.
#'
#' @param key_file Character string path to the Gen3 credentials JSON file
#'
#' @return A character vector of node names in topological order.
#'   \code{core_metadata_collection}, if present, is forced to the end of
#'   the result. The excluded nodes (\code{_definitions}, \code{_terms},
#'   \code{_settings}, \code{program}, \code{metaschema}, \code{root}) are
#'   skipped when extracting edges, but may still appear in the output if
#'   they are referenced as link targets by other nodes (matching the
#'   behavior of the original Python implementation).
#'
#' @importFrom httr GET http_error content status_code
#' @importFrom jsonlite fromJSON
#' @export
get_node_order <- function(key_file) {

    # Validate key file path
    if (!file.exists(key_file)) {
        stop("Key file not found: ", key_file)
    }

    # Derive base URL from the JWT in the credentials file. We don't need
    # the bearer token because the dictionary endpoint is public, but we do
    # need the base URL.
    creds    <- load_key_file(key_file)
    base_url <- get_base_url(creds$api_key)

    # Fetch the full data dictionary. No auth header required.
    url <- paste0(base_url, "/api/v0/submission/_dictionary/_all")
    res <- httr::GET(url)
    if (httr::http_error(res)) {
        stop(sprintf(
            "Failed to fetch Gen3 data dictionary: HTTP %s",
            httr::status_code(res)
        ))
    }
    schema <- jsonlite::fromJSON(
        httr::content(res, as = "text", encoding = "UTF-8"),
        simplifyVector = FALSE
    )

    # Match the Python excluded_nodes list used in
    # gen3_metadata.gen3_metadata_parser.get_node_order
    excluded_nodes <- c(
        "_definitions", "_terms", "_settings",
        "program", "metaschema", "root"
    )

    edges <- .extract_node_edges(schema, excluded_nodes)
    .topo_sort_kahn(edges)
}


#' Extract directed edges from a Gen3 schema's link graph
#'
#' For each non-excluded node in the schema, walks its \code{links} array
#' (handling the optional \code{subgroup} wrapper) and emits one edge per
#' link in the form \code{c(target_type, node_id)} — i.e. parent -> child.
#'
#' @keywords internal
#' @noRd
.extract_node_edges <- function(schema, excluded_nodes) {
    edges <- list()
    for (node_name in names(schema)) {
        if (node_name %in% excluded_nodes) next

        node    <- schema[[node_name]]
        node_id <- node[["id"]]
        links   <- node[["links"]]

        if (is.null(node_id) || is.null(links) || length(links) == 0) next

        # Python: if "subgroup" in links[0]: links = links[0]["subgroup"]
        # Some Gen3 dictionaries wrap the actual link list inside a single
        # subgroup entry. Unwrap it if present.
        if (!is.null(links[[1]][["subgroup"]])) {
            links <- links[[1]][["subgroup"]]
        }

        for (link in links) {
            target_type <- link[["target_type"]]
            if (is.null(target_type)) next
            edges[[length(edges) + 1L]] <- c(target_type, node_id)
        }
    }
    edges
}


#' Topological sort using Kahn's algorithm
#'
#' Takes a list of (upstream, downstream) edges and returns a character
#' vector of node names in topological order. Mirrors the Python
#' \code{DataDictionary.get_node_order} implementation, including the
#' special case that forces \code{core_metadata_collection} to the end of
#' the result.
#'
#' @keywords internal
#' @noRd
.topo_sort_kahn <- function(edges) {
    graph     <- list()       # named list: upstream -> chr vector of downstreams
    in_degree <- integer(0)   # named integer vector

    for (edge in edges) {
        upstream   <- edge[1]
        downstream <- edge[2]

        graph[[upstream]] <- c(graph[[upstream]], downstream)

        if (is.na(in_degree[downstream])) {
            in_degree[downstream] <- 0L
        }
        in_degree[downstream] <- in_degree[downstream] + 1L

        if (is.na(in_degree[upstream])) {
            in_degree[upstream] <- 0L
        }
    }

    sorted_order   <- character(0)
    zero_in_degree <- names(in_degree)[in_degree == 0L]

    while (length(zero_in_degree) > 0) {
        node           <- zero_in_degree[1]
        zero_in_degree <- zero_in_degree[-1]
        sorted_order   <- c(sorted_order, node)

        for (neighbor in graph[[node]]) {
            in_degree[neighbor] <- in_degree[neighbor] - 1L
            if (in_degree[neighbor] == 0L) {
                zero_in_degree <- c(zero_in_degree, neighbor)
            }
        }
    }

    if ("core_metadata_collection" %in% sorted_order) {
        sorted_order <- c(
            setdiff(sorted_order, "core_metadata_collection"),
            "core_metadata_collection"
        )
    }

    sorted_order
}
