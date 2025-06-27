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

