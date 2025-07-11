#' Unit tests for authenticate

# Load required packages
library(testthat)
library(webmockr)
library(gen3metadata)

# Enable webmockr to intercept HTTP requests
webmockr::enable()

## Fixture to provide a fake API key. Note: these credentials have been inactivated.
## This is a valid JWT and UUID, but is not active.
fake_api_key <- paste0(
    "{\"api_key\":\"eyJhbGciOiJSUzI1NiIsImtpZCI6ImZlbmNlX2tleV9rZXkiLCJ0eX",
    "AiOiJKV1QifQ.eyJwdXIiOiJhcGlfa2V5Iiwic3ViIjoiMjEiLCJpc3MiOiJodHRwczov",
    "L2RhdGEudGVzdC5iaW9jb21tb25zLm9yZy5hdS91c2VyIiwiYXVkIjpbImh0dHBzOi8vZ",
    "GF0YS50ZXN0LmJpb2NvbW1vbnMub3JnLmF1L3VzZXIiXSwiaWF0IjoxNzQyMjUzNDgwLC",
    "JleHAiOjE3NDQ4NDU0ODAsImp0aSI6ImI5MDQyNzAxLWIwOGYtNDBkYS04OWEzLTc1M2J",
    "lNGVkMTIyOSIsImF6cCI6IiIsInNjb3BlIjpbImdvb2dsZV9jcmVkZW50aWFscyIsIm9w",
    "ZW5pZCIsImdvb2dsZV9zZXJ2aWNlX2FjY291bnQiLCJkYXRhIiwiZmVuY2UiLCJnb29nb",
    "GVfbGluayIsImFkbWluIiwidXNlciIsImdhNGdoX3Bhc3Nwb3J0X3YxIl19.SGPjs6ljC",
    "JbwDu-6WAnI5dN8o5467_ktcnsxRFrX_aCQNrOwSPgTCDvWEzamRmB5Oa0yB6cnjduhWR",
    "KnPWIZDal86H0etm77wilCteHF_zFl1IV6LW23AfOVOG3zB9KL6o-ZYqpSRyo0FDj0vQJ",
    "zrHXPjqvQ15S6Js2sIwIa3ONTeHbR6fRecfPaLK1uGIY5tJFeigXzrLzlifKCEnt_2gqp",
    "MU2_b2QgW1315FixNIUOl8A7FZJ2-ddSMJPO0IYQ0QMSWV9-bbxie4Zjsaa1HtQYOhfXL",
    "U3vSdUOBO0btSfd6-NnWfx_-lDo5V9lkSH_aecEyew0IHBx-e7rSR5cxA\",\"key_id\"",
    ":\"b9042701-b08f-40da-89a3-753be4ed1229\"}"
)


test_that("authenticate method works correctly", {

    # Create a temporary key file
    tmp_key_file <- tempfile(fileext = ".json")
    writeLines(fake_api_key, tmp_key_file)

    # Create the Gen3 metadata parser object
    gen3 <- Gen3MetadataParser(tmp_key_file)

    # Expect that headers and token are NULL initially
    expect_null(gen3$headers)
    expect_null(gen3$token)

    # Mock the POST request to the Gen3 API
    mock_post <- stub_request("post", uri = "https://data.test.biocommons.org.au/user/credentials/cdis/access_token")
    mock_post <- to_return(mock_post, 
                           body = "{\"access_token\": \"fake_access_token\"}",
                           status = 200,
                           headers = list("Content-Type" = "application/json"))

    # Authenticate the Gen3 metadata object
    gen3 <- authenticate(gen3)

    # Check that the token is set correctly
    expect_equal(gen3$token, "fake_access_token")

    # Check that the headers are set correctly
    expect_true(!is.null(gen3$headers))
    expect_equal(gen3$headers$headers, c("Authorization" = "Bearer fake_access_token"))
    
    # Clean up temporary file
    unlink(tmp_key_file)

    # Clear the stub registry to remove the mock
    webmockr::stub_registry_clear()
})


test_that("authenticate method handles HTTP errors", {

    # Create a temporary key file
    tmp_key_file <- tempfile(fileext = ".json")
    writeLines(fake_api_key, tmp_key_file)

    # Create the Gen3 metadata parser object
    gen3 <- Gen3MetadataParser(tmp_key_file)

    # Mock the POST request to return an error
    mock_post <- stub_request("post", uri = "https://data.test.biocommons.org.au/user/credentials/cdis/access_token")
    mock_post <- to_return(mock_post, 
                           body = "{\"error\": \"invalid_grant\"}",
                           status = 400,
                           headers = list("Content-Type" = "application/json"))

    # Expect an error when trying to authenticate
    expect_error(authenticate(gen3), "Failed to authenticate with the Gen3 API. Please check your credentials.")

    # Clean up temporary file
    unlink(tmp_key_file)

    # Clear the stub registry to remove the mock
    webmockr::stub_registry_clear()
})


test_that("authenticate method handles missing access token", {

    # Create a temporary key file
    tmp_key_file <- tempfile(fileext = ".json")
    writeLines(fake_api_key, tmp_key_file)

    # Create the Gen3 metadata parser object
    gen3 <- Gen3MetadataParser(tmp_key_file)

    # Mock the POST request to return an error
    mock_post <- stub_request("post", uri = "https://data.test.biocommons.org.au/user/credentials/cdis/access_token")
    mock_post <- to_return(mock_post, 
                           body = "{}",
                           status = 200,
                           headers = list("Content-Type" = "application/json"))

    # Expect an error when trying to authenticate
    expect_error(authenticate(gen3), "access token not found in the response.")

    # Clean up temporary file
    unlink(tmp_key_file)

    # Clear the stub registry to remove the mock
    webmockr::stub_registry_clear()

})

