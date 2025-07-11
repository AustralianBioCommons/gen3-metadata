#' Authenticate with Gen3 API
#'
#' Generic function to authenticate a gen3_metadata object with the Gen3 API
#' and obtain an access token for subsequent requests.
#'
#' @param gen3_metadata A gen3_metadata object
#' 
#' @return The authenticated gen3_metadata object (invisibly)
#' 
#' @export
authenticate <- function(gen3_metadata) {
    UseMethod("authenticate")
}

#' Fetch data from Gen3 API
#'
#' Generic function to fetch data from a specific node in the Gen3 submission API
#' for a given program and project.
#'
#' @param gen3_metadata An authenticated gen3_metadata object
#' @param program_name Character string name of the program
#' @param project_code Character string code of the project
#' @param node_label Character string label of the node to fetch data from
#' @param api_version Character string API version (default: "v0")
#' 
#' @return Data frame containing the fetched data
#' 
#' @export
fetch_data <- function(gen3_metadata, program_name, project_code, node_label, api_version) {
    UseMethod("fetch_data")
}
