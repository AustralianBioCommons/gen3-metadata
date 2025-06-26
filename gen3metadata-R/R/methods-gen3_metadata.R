#' Authenticate gen3_metadata object with Gen3 API
#'
#' This method authenticates a gen3_metadata object by sending a POST request
#' to the Gen3 API with the provided credentials to obtain an access token.
#'
#' @param gen3_metadata A gen3_metadata object containing credentials
#' 
#' @return The authenticated gen3_metadata object with token and headers set (invisibly)
#' 
#' @method authenticate gen3_metadata
#' @rdname authenticate
#' @importFrom httr POST http_error content add_headers
#' @export
authenticate.gen3_metadata <- function(gen3_metadata) {
    
    # Check that the credentials are provided
    if (is.null(gen3_metadata$credentials) || gen3_metadata$credentials$api_key == "") {
        stop("Credentials must be provided to authenticate gen3_metadata.")
    }

    # Send a POST request to the Gen3 API to get an access token
    res <- httr::POST(
        url    = paste0(gen3_metadata$base_url, "/user/credentials/cdis/access_token"),
        body   = gen3_metadata$credentials,
        encode = "json"
    )
    
    # Check for errors in the response
    if (httr::http_error(res)) {
        stop("Failed to authenticate with the Gen3 API. Please check your credentials.")
    }

    # Get the content from the response
    content <- httr::content(res, as = "parsed", type = "application/json")
    
    # Check if the access token is present in the response
    if (is.null(content$access_token)) {
        stop("Authentication failed: access token not found in the response.")
    }

    # Extract the access token
    gen3_metadata$token <- content$access_token

    # Set the headers for future requests
    gen3_metadata$headers <- httr::add_headers(
        Authorization = paste("Bearer", gen3_metadata$token)
    )

    # Return the updated gen3_metadata object
    return(invisible(gen3_metadata))
}


#' Fetch data from Gen3 submission API
#'
#' This method fetches data from a specific node in the Gen3 API
#' for a given program and project. The object must be authenticated first.
#'
#' @param gen3_metadata An authenticated gen3_metadata object
#' @param program_name Character string name of the program
#' @param project_code Character string code of the project  
#' @param node_label Character string label of the node to fetch data from
#' @param api_version Character string API version (default: "v0")
#' 
#' @return Data frame containing the fetched data from the specified node
#' 
#' @method fetch_data gen3_metadata
#' @rdname fetch_data
#' @importFrom glue glue
#' @importFrom httr GET http_error content
#' @importFrom jsonlite fromJSON
#' @export
fetch_data.gen3_metadata <- function(gen3_metadata,
                                     program_name,
                                     project_code,
                                     node_label,
                                     api_version = "v0") {

    # Check that the gen3_metadata is authenticated
    if (is.null(gen3_metadata$headers)) {
        stop("Gen3 metadata object is not authenticated. Please authenticate first.")
    }
    
    # Construct the URL for the API request
    url <- glue::glue(
        "{gen3_metadata$base_url}/api/{api_version}/submission",
        "/{program_name}/{project_code}/export/"
    )

    # Make the GET request to the Gen3 API
    res <- httr::GET(
        url,
        gen3_metadata$headers,
        query = list(node_label = node_label, format = "json")
    )
    
    # Check for errors in the response
    if (httr::http_error(res)) {
        stop("Failed to fetch data from the Gen3 API. Please check your parameters and authentication.")
    }

    # Extract the content from the response
    content <- httr::content(res, as = "text", encoding = "UTF-8")
    
    # Parse the JSON content and return the data
    data <- jsonlite::fromJSON(content, flatten = TRUE)$data

    # Return the fetched data
    return(data)
}


#' Print gen3_metadata object summary
#'
#' This method prints a formatted summary of a gen3_metadata object.
#'
#' @param gen3_metadata A gen3_metadata object
#' 
#' @return The gen3_metadata object (invisibly)
#' 
#' @method print gen3_metadata
#' @rdname print
#' @export
print.gen3_metadata <- function(gen3_metadata) {

    # Print basic information about the gen3_metadata object
    cat("Gen3 Metadata Parser\n")
    cat("====================\n")

    # Display base URL
    cat("Base URL:", gen3_metadata$base_url, "\n")

    # Display authentication status
    if (!is.null(gen3_metadata$headers)) {
        cat("Authentication: Authenticated\n")
    } else {
        cat("Authentication: Not authenticated\n")
    }

    # Display key file path
    cat("\n")

    # Return invisibly
    return(invisible(gen3_metadata))
}

