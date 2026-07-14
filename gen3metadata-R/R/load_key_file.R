#' Detect a raw credentials JSON string
#'
#' Returns TRUE when the input is a single character string that starts with
#' a left brace after leading whitespace, i.e. raw credentials JSON rather
#' than a file path. Checked before file.exists() so a long JWT string is
#' never used as a path.
#'
#' @param x Object to test
#'
#' @return Logical scalar
#'
#' @keywords internal
is_raw_json_credentials <- function(x) {
    is.character(x) && length(x) == 1 && grepl("^[[:space:]]*\\{", x)
}

#' Load Gen3 credentials from key file or raw JSON string
#'
#' This function reads Gen3 API credentials from a JSON key file, or parses
#' them directly when given the raw credentials JSON string itself.
#'
#' @param key_file Character string: either a path to the JSON key file, or
#'   the raw credentials JSON string itself (auto-detected)
#'
#' @return List containing 'api_key' and 'key_id' credentials
#'
#' @importFrom jsonlite fromJSON
load_key_file <- function(key_file) {

    # A raw JSON string is passed straight to fromJSON; only paths get the
    # existence check (order matters: never call file.exists on a JWT blob)
    if (!is_raw_json_credentials(key_file) && !file.exists(key_file)) {
        stop("Key file does not exist: ", key_file)
    }

    # fromJSON accepts both a file path and a literal JSON string
    creds <- jsonlite::fromJSON(key_file)

    # Validate the contents of the key file
    if (!"api_key" %in% names(creds) || !"key_id" %in% names(creds)) {
        stop("Key file must contain 'api_key' and 'key_id'.")
    }

    # Return the credentials as a list
    return(creds)
}
