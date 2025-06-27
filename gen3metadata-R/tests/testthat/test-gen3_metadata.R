#' Unit tests for gen3metadata

# Load required packages
library(testthat)
library(gen3metadata)

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


test_that("Gen3MetadataParser creates an object with correct class", {
    
    # Create a temporary key file
    tmp_key_file <- tempfile(fileext = ".json")
    writeLines(fake_api_key, tmp_key_file)
    
    # Create the Gen3 metadata parser object
    obj <- Gen3MetadataParser(tmp_key_file)
    
    # Check that the object is of class 'gen3_metadata'
    expect_s3_class(obj, "gen3_metadata")
    
    # Check that the key file path is set correctly
    expect_equal(obj$key_file, tmp_key_file)

    # Check that the base URL is set correctly
    expect_equal(obj$base_url, "https://data.test.biocommons.org.au")

    # Read the credentials from the key file
    creds <- load_key_file(tmp_key_file)

    # Check that the credentials are set correctly
    expect_equal(obj$credentials$api_key, creds$api_key)
    expect_equal(obj$credentials$key_id, creds$key_id)

    # Clean up temporary file
    unlink(tmp_key_file)
})


