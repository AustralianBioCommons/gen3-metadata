#' Extract base URL from Gen3 API key
#'
#' This function extracts the base URL from a Gen3 API key JWT token
#' by parsing the 'iss' (issuer) field from the payload.
#'
#' @param api_key Character string containing the Gen3 API key (JWT token)
#' 
#' @return Character string containing the base URL
#' 
#' @importFrom jose jwt_split
get_base_url <- function(api_key) {

    # Check if the API key is provided
    if (is.null(api_key) || api_key == "") {
        stop("API key must be provided.")
    }

    # Extract the payload from the JWT
    payload  <- jose::jwt_split(api_key)$payload

    # Validate the payload
    if (!"iss" %in% names(payload)) {
        stop("The JWT payload must contain 'iss'.")
    }

    # Extract the base URL from the payload
    base_url <- sub("/user$", "", payload$iss)

    # Return the base url
    return(base_url)
}