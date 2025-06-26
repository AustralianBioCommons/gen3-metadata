#' Create a Gen3 metadata parser object
#'
#' This function creates a new Gen3 metadata parser object by loading
#' credentials from a key file. Use this object to interact with the Gen3 API.
#'
#' @param key_file Character string path to the JSON key file containing Gen3 credentials
#' 
#' @return A gen3_metadata object with credentials and base URL configured
#' 
#' @export
Gen3MetadataParser <- function(key_file) {

    # Create the object to store data
    obj <- list(
        key_file = key_file,
        base_url = "",
        credentials = list(
            api_key = "",
            key_id = ""
        ),
        header = NULL
    )

    # Load the key file
    creds <- load_key_file(key_file)

    # Set the credentials in the object
    obj$credentials$api_key <- creds$api_key
    obj$credentials$key_id <- creds$key_id

    # Get the base URL from the API key
    obj$base_url <- get_base_url(obj$credentials$api_key)

    # Set the class of the object
    class(obj) <- "gen3_metadata"

    # Return the object
    return(obj)

}