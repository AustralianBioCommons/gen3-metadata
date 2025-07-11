#' Unit tests for get_base_url

# Load required packages
library(testthat)
library(gen3metadata)

## Fixture to provide a fake API key. Note: these credentials have been inactivated.
## This is a valid JWT and UUID, but is not active.
fake_api_key <- list(
    "api_key" = paste0(
        "eyJhbGciOiJSUzI1NiIsImtpZCI6ImZlbmNlX2tleV9rZXkiLCJ0eXAiOiJKV1QifQ.",
        "eyJwdXIiOiJhcGlfa2V5Iiwic3ViIjoiMjEiLCJpc3MiOiJodHRwczovL2RhdGEudGVzdC5i",
        "aW9jb21tb25zLm9yZy5hdS91c2VyIiwiYXVkIjpbImh0dHBzOi8vZGF0YS50ZXN0LmJpb2Nv",
        "bW1vbnMub3JnLmF1L3VzZXIiXSwiaWF0IjoxNzQyMjUzNDgwLCJleHAiOjE3NDQ4NDU0ODAs",
        "Imp0aSI6ImI5MDQyNzAxLWIwOGYtNDBkYS04OWEzLTc1M2JlNGVkMTIyOSIsImF6cCI6IiIs",
        "InNjb3BlIjpbImdvb2dsZV9jcmVkZW50aWFscyIsIm9wZW5pZCIsImdvb2dsZV9zZXJ2aWNl",
        "X2FjY291bnQiLCJkYXRhIiwiZmVuY2UiLCJnb29nbGVfbGluayIsImFkbWluIiwidXNlciIs",
        "ImdhNGdoX3Bhc3Nwb3J0X3YxIl19.",
        "SGPjs6ljCJbwDu-6WAnI5dN8o5467_ktcnsxRFrX_aCQNrOwSPgTCDvWEzamRmB5Oa0yB6cn",
        "jduhWRKnPWIZDal86H0etm77wilCteHF_zFl1IV6LW23AfOVOG3zB9KL6o-ZYqpSRyo0FDj0",
        "vQJzrHXPjqvQ15S6Js2sIwIa3ONTeHbR6fRecfPaLK1uGIY5tJFeigXzrLzlifKCEnt_2gqp",
        "MU2_b2QgW1315FixNIUOl8A7FZJ2-ddSMJPO0IYQ0QMSWV9-bbxie4Zjsaa1HtQYOhfXLU3v",
        "SdUOBO0btSfd6-NnWfx_-lDo5V9lkSH_aecEyew0IHBx-e7rSR5cxA"),
    "key_id" = "b9042701-b08f-40da-89a3-753be4ed1229"
)


test_that("get_base_url can get the data commons url from JWT token", {

    # Call get_base_url with the fake API key
    base_url <- gen3metadata:::get_base_url(fake_api_key$api_key)

    # Check that the base URL is as expected
    expect_equal(base_url, "https://data.test.biocommons.org.au")
})


test_that("get_base_url errors when passing empty string", {

    # Test that get_base_url raises an error when the API key is an empty string
    expect_error(gen3metadata:::get_base_url(""), "API key must be provided.")
})

