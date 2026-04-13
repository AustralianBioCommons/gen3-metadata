#' Get topological node order from a Gen3 data dictionary
#'
#' This function calls the Python \code{get_node_order} function from the
#' \code{gen3_metadata} package via \code{reticulate}. It returns the nodes
#' of a Gen3 data dictionary in dependency order (parents before children).
#'
#' @param key_file Character string path to the Gen3 credentials JSON file
#'
#' @return A character vector of node names in topological order
#'
#' @importFrom reticulate import
#' @export
get_node_order <- function(key_file) {

    # Check that the key file exists
    if (!file.exists(key_file)) {
        stop("Key file not found: ", key_file)
    }

    # Import the Python module
    gen3_metadata_py <- reticulate::import("gen3_metadata.gen3_metadata_parser")

    # Call the Python function
    node_order <- gen3_metadata_py$get_node_order(key_file)

    # Convert from Python list to R character vector
    return(as.character(node_order))
}
