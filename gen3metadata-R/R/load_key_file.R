#' Load Gen3 credentials from key file
#'
#' This function reads a JSON key file containing Gen3 API credentials.
#'
#' @param key_file Character string path to the JSON key file
#' 
#' @return List containing 'api_key' and 'key_id' credentials
#' 
#' @importFrom jsonlite fromJSON
load_key_file <- function(key_file) {

    # Check if the key file exists
    if (!file.exists(key_file)) {
        stop("Key file does not exist: ", key_file)
    }

    # Read the JSON file
    creds <- jsonlite::fromJSON(key_file)

    # Validate the contents of the key file
    if (!"api_key" %in% names(creds) || !"key_id" %in% names(creds)) {
        stop("Key file must contain 'api_key' and 'key_id'.")
    }

    # Return the credentials as a list
    return(creds)
}