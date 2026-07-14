#' Unit tests for load_key_file

# Load required packages
library(testthat)
library(gen3metadata)


test_that("load_key_file reads valid JSON file", {

    # Create a temporary file
    tmp <- tempfile(fileext = ".json")

    # Write valid JSON to the temporary file
    writeLines('{"api_key":"abc.def.ghi","key_id":"18b018"}', tmp)

    # Call load_key_file and check the result
    creds <- load_key_file(tmp)

    # Check that the credentials are as expected
    expect_equal(creds,
                 list(api_key = "abc.def.ghi",
                      key_id = "18b018"))

    # Clean up temporary file
    unlink(tmp)
})


test_that("load_key_file errors when file missing or no required fields", {

    # Test that load_key_file raises an error when the file does not exist
    expect_error(load_key_file("no/such/file.json"), "does not exist")

    # Create a temporary file
    tmp <- tempfile(fileext = ".json")

    # Write JSON without required fields
    writeLines('{"api_key":"abc.def.ghi"}', tmp)
    
    # Test that load_key_file raises an error when the file is missing required fields
    expect_error(load_key_file(tmp), "must contain 'api_key' and 'key_id'")

    # Clean up temporary file
    unlink(tmp)
})


test_that("load_key_file handles non-existent file", {

    # Test that load_key_file raises an error when the file does not exist
    expect_error(load_key_file("non_existent_file.json"), "does not exist")
})


test_that("load_key_file handles malformed JSON", {

    # Create a temporary file
    tmp <- tempfile(fileext = ".json")

    # Write malformed JSON to the temporary file
    writeLines('{"api_key":"abc.def.ghi", "key_id":18b018}', tmp)

    # Test that load_key_file raises an error for malformed JSON
    expect_error(gen3metadata:::load_key_file(tmp), "invalid char in json")

    # Clean up temporary file
    unlink(tmp)
})


## Raw credentials JSON string support ---------------------------------------
## Credentials are normally supplied as a path to a credentials.json file.
## load_key_file also accepts the raw credentials JSON string itself
## (auto-detected by a leading "{"), so users can paste the key exported from
## the Gen3 portal directly into a variable without saving it to disk.


test_that("load_key_file accepts a raw JSON credentials string", {

    # The same JSON that would live in a credentials file, passed directly
    # as a string. Must return the identical list a file-based load returns.
    raw <- '{"api_key":"abc.def.ghi","key_id":"18b018"}'

    creds <- load_key_file(raw)

    expect_equal(creds,
                 list(api_key = "abc.def.ghi",
                      key_id = "18b018"))
})


test_that("load_key_file accepts raw JSON with leading whitespace and newlines", {

    # A blob copy-pasted from a terminal often carries surrounding newlines
    # and indentation. Detection strips leading whitespace before checking
    # for "{", so the padded string must parse the same as the clean one.
    raw <- '\n  {"api_key": "abc.def.ghi", "key_id": "18b018"}\n'

    creds <- load_key_file(raw)

    expect_equal(creds$api_key, "abc.def.ghi")
    expect_equal(creds$key_id, "18b018")
})


test_that("load_key_file errors on raw JSON missing required fields", {

    # A pasted key without key_id must fail the same validation as a file
    # missing that field, so users get a consistent, actionable message.
    expect_error(
        load_key_file('{"api_key":"abc.def.ghi"}'),
        "must contain 'api_key' and 'key_id'"
    )
})


test_that("load_key_file errors on malformed raw JSON string", {

    # A string starting with "{" is committed to the raw-JSON path, so
    # invalid JSON must surface as a jsonlite parse error — NOT as a
    # "Key file does not exist" error from treating the blob as a path.
    expect_error(
        load_key_file('{"api_key": abc}'),
        "invalid char in json"
    )
})


test_that("load_key_file handles very long raw JSON strings", {

    # A real api_key JWT is several KB long. The raw-string check must run
    # BEFORE file.exists(), because passing a multi-KB string as a path can
    # fail at the OS level (ENAMETOOLONG) instead of parsing as JSON.
    long_jwt <- paste(rep("a", 3000), collapse = "")
    raw <- paste0('{"api_key":"', long_jwt, '","key_id":"18b018"}')

    creds <- load_key_file(raw)

    expect_equal(nchar(creds$api_key), 3000)
    expect_equal(creds$key_id, "18b018")
})
