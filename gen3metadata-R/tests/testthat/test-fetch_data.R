#' Unit tests for fetch_data

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


test_that("fetch_data method works correctly", {
    
    # Create a temporary key file
    tmp_key_file <- tempfile(fileext = ".json")
    writeLines(fake_api_key, tmp_key_file)

    # Create the Gen3 metadata parser object
    gen3 <- Gen3MetadataParser(tmp_key_file)

    # Mock the POST request to the Gen3 API
    mock_post <- stub_request("post", uri = "https://data.test.biocommons.org.au/user/credentials/cdis/access_token")
    mock_post <- to_return(mock_post, 
                           body = "{\"access_token\": \"fake_access_token\"}",
                           status = 200,
                           headers = list("Content-Type" = "application/json"))

    # Authenticate the Gen3 metadata object
    gen3 <- authenticate(gen3)

    # Mock the GET request to the Gen3 API
    mock_get <- stub_request("get", uri = "https://data.test.biocommons.org.au/api/v0/submission/program1/AusDiab/export/?node_label=subject&format=json")
    mock_get <- to_return(mock_get, 
                          body = "{\"data\": [{\"id\": 1, \"name\": \"test\"}]}",
                          status = 200,
                          headers = list("Content-Type" = "application/json"))

    # Call fetch_data and check the result
    result <- fetch_data(gen3, "program1", "AusDiab", "subject")

    # Check that the result is a data frame
    expect_s3_class(result, "data.frame")

    # Check that the data frame has the expected columns
    expect_true("id" %in% colnames(result))
    expect_true("name" %in% colnames(result))

    # Check that the data frame contains the expected data
    expect_equal(nrow(result), 1)
    expect_equal(result$id, 1)
    expect_equal(result$name, "test")

    # Clean up temporary file
    unlink(tmp_key_file)

    # Clear the stub registry to remove the mock
    webmockr::stub_registry_clear()
})


test_that("fetch_data handles HTTP errors", {
    
    # Create a temporary key file
    tmp_key_file <- tempfile(fileext = ".json")
    writeLines(fake_api_key, tmp_key_file)

    # Create the Gen3 metadata parser object
    gen3 <- Gen3MetadataParser(tmp_key_file)

    # Mock the POST request to the Gen3 API
    mock_post <- stub_request("post", uri = "https://data.test.biocommons.org.au/user/credentials/cdis/access_token")
    mock_post <- to_return(mock_post, 
                           body = "{\"access_token\": \"fake_access_token\"}",
                           status = 200,
                           headers = list("Content-Type" = "application/json"))

    # Authenticate the Gen3 metadata object
    gen3 <- authenticate(gen3)

    # Mock the GET request to the Gen3 API
    mock_get <- stub_request("get", uri = "https://data.test.biocommons.org.au/api/v0/submission/program1/AusDiab/export/?node_label=subject&format=json")
    mock_get <- to_return(mock_get, 
                          body = "{\"data\": [{\"id\": 1, \"name\": \"test\"}]}",
                          status = 400,
                          headers = list("Content-Type" = "application/json"))

    # Call fetch_data and check the result
    expect_error(fetch_data(gen3, "program1", "AusDiab", "subject"), "Failed to fetch data from the Gen3 API")

    # Clean up temporary file
    unlink(tmp_key_file)

    # Clear the stub registry to remove the mock
    webmockr::stub_registry_clear()
})

