#' Unit tests for fetch_all_metadata

library(testthat)
library(webmockr)
library(gen3metadata)

# Enable webmockr to intercept HTTP requests
webmockr::enable()

## Fixture to provide a fake API key. Note: these credentials have been inactivated.
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


test_that("fetch_all_metadata returns metadata_collection with to_df()", {

    # Create a temporary key file
    tmp_key_file <- tempfile(fileext = ".json")
    writeLines(fake_api_key, tmp_key_file)

    # Mock get_node_order to return known nodes
    mock_get_node_order <- function(key_file) c("subject", "sample")
    original_get_node_order <- gen3metadata::get_node_order
    assignInNamespace("get_node_order", mock_get_node_order, ns = "gen3metadata")

    # Mock authenticate POST
    mock_post <- stub_request("post", uri = "https://data.test.biocommons.org.au/user/credentials/cdis/access_token")
    mock_post <- to_return(mock_post,
                           body = "{\"access_token\": \"fake_access_token\"}",
                           status = 200,
                           headers = list("Content-Type" = "application/json"))

    # Mock GET for subject node
    mock_get_subject <- stub_request("get", uri = "https://data.test.biocommons.org.au/api/v0/submission/program1/AusDiab/export/?node_label=subject&format=json")
    mock_get_subject <- to_return(mock_get_subject,
                                  body = "{\"data\": [{\"id\": 1, \"name\": \"alice\"}]}",
                                  status = 200,
                                  headers = list("Content-Type" = "application/json"))

    # Mock GET for sample node
    mock_get_sample <- stub_request("get", uri = "https://data.test.biocommons.org.au/api/v0/submission/program1/AusDiab/export/?node_label=sample&format=json")
    mock_get_sample <- to_return(mock_get_sample,
                                 body = "{\"data\": [{\"id\": 2, \"sample_type\": \"blood\"}]}",
                                 status = 200,
                                 headers = list("Content-Type" = "application/json"))

    result <- fetch_all_metadata(tmp_key_file, "program1", "AusDiab")

    # Returns metadata_collection
    expect_s3_class(result, "metadata_collection")

    # JSON access via $
    expect_true("subject" %in% names(result))
    expect_true("sample" %in% names(result))
    expect_type(result$subject, "list")

    # to_df() returns named list of data.frames
    dfs <- to_df(result)
    expect_type(dfs, "list")
    expect_true("subject" %in% names(dfs))
    expect_true("sample" %in% names(dfs))
    expect_s3_class(dfs$subject, "data.frame")
    expect_equal(dfs$subject$id, 1)
    expect_equal(dfs$sample$sample_type, "blood")

    # Restore original and clean up
    assignInNamespace("get_node_order", original_get_node_order, ns = "gen3metadata")
    unlink(tmp_key_file)
    webmockr::stub_registry_clear()
})


test_that("fetch_all_metadata skips failed nodes gracefully", {

    tmp_key_file <- tempfile(fileext = ".json")
    writeLines(fake_api_key, tmp_key_file)

    mock_get_node_order <- function(key_file) c("subject", "sample")
    original_get_node_order <- gen3metadata::get_node_order
    assignInNamespace("get_node_order", mock_get_node_order, ns = "gen3metadata")

    # Mock authenticate
    mock_post <- stub_request("post", uri = "https://data.test.biocommons.org.au/user/credentials/cdis/access_token")
    mock_post <- to_return(mock_post,
                           body = "{\"access_token\": \"fake_access_token\"}",
                           status = 200,
                           headers = list("Content-Type" = "application/json"))

    # subject succeeds
    mock_get_subject <- stub_request("get", uri = "https://data.test.biocommons.org.au/api/v0/submission/program1/AusDiab/export/?node_label=subject&format=json")
    mock_get_subject <- to_return(mock_get_subject,
                                  body = "{\"data\": [{\"id\": 1}]}",
                                  status = 200,
                                  headers = list("Content-Type" = "application/json"))

    # sample fails with 400
    mock_get_sample <- stub_request("get", uri = "https://data.test.biocommons.org.au/api/v0/submission/program1/AusDiab/export/?node_label=sample&format=json")
    mock_get_sample <- to_return(mock_get_sample,
                                 body = "{\"error\": \"bad request\"}",
                                 status = 400,
                                 headers = list("Content-Type" = "application/json"))

    result <- suppressWarnings(fetch_all_metadata(tmp_key_file, "program1", "AusDiab"))

    # Successful node present
    expect_true("subject" %in% names(result))
    expect_s3_class(to_df(result)$subject, "data.frame")

    # Failed node absent
    expect_false("sample" %in% names(result))
    expect_false("sample" %in% names(to_df(result)))

    # Restore and clean up
    assignInNamespace("get_node_order", original_get_node_order, ns = "gen3metadata")
    unlink(tmp_key_file)
    webmockr::stub_registry_clear()
})


test_that("fetch_all_metadata errors when key file does not exist", {
    expect_error(fetch_all_metadata("nonexistent_file.json", "p", "c"), "Key file not found")
})
