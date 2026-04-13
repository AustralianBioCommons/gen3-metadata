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


# ----------------------------------------------------------------------------
# data_release filter tests
# ----------------------------------------------------------------------------

test_that("fetch_all_metadata filters by specific data_release", {

    tmp_key_file <- tempfile(fileext = ".json")
    writeLines(fake_api_key, tmp_key_file)

    mock_get_node_order <- function(key_file) c("subject")
    original_get_node_order <- gen3metadata::get_node_order
    assignInNamespace("get_node_order", mock_get_node_order, ns = "gen3metadata")

    mock_post <- stub_request("post", uri = "https://data.test.biocommons.org.au/user/credentials/cdis/access_token")
    mock_post <- to_return(mock_post,
                           body = "{\"access_token\": \"fake_access_token\"}",
                           status = 200,
                           headers = list("Content-Type" = "application/json"))

    mock_get_subject <- stub_request("get", uri = "https://data.test.biocommons.org.au/api/v0/submission/program1/AusDiab/export/?node_label=subject&format=json")
    mock_get_subject <- to_return(
        mock_get_subject,
        body = paste0(
            "{\"data\": [",
            "{\"id\": 1, \"data_release\": \"v1\"},",
            "{\"id\": 2, \"data_release\": \"v2\"},",
            "{\"id\": 3, \"data_release\": \"v1\"}",
            "]}"
        ),
        status = 200,
        headers = list("Content-Type" = "application/json")
    )

    result <- suppressMessages(
        fetch_all_metadata(tmp_key_file, "program1", "AusDiab", data_release = "v1")
    )

    # Nested list view: two records, both v1
    expect_equal(length(result$subject), 2)
    expect_equal(result$subject[[1]]$data_release, "v1")
    expect_equal(result$subject[[2]]$data_release, "v1")
    expect_equal(result$subject[[1]]$id, 1)
    expect_equal(result$subject[[2]]$id, 3)

    # data.frame view: aligned with nested list
    dfs <- to_df(result)
    expect_s3_class(dfs$subject, "data.frame")
    expect_equal(nrow(dfs$subject), 2)
    expect_equal(dfs$subject$id, c(1, 3))
    expect_equal(dfs$subject$data_release, c("v1", "v1"))

    assignInNamespace("get_node_order", original_get_node_order, ns = "gen3metadata")
    unlink(tmp_key_file)
    webmockr::stub_registry_clear()
})


test_that("fetch_all_metadata selects latest data_release_date", {

    tmp_key_file <- tempfile(fileext = ".json")
    writeLines(fake_api_key, tmp_key_file)

    mock_get_node_order <- function(key_file) c("sample")
    original_get_node_order <- gen3metadata::get_node_order
    assignInNamespace("get_node_order", mock_get_node_order, ns = "gen3metadata")

    mock_post <- stub_request("post", uri = "https://data.test.biocommons.org.au/user/credentials/cdis/access_token")
    mock_post <- to_return(mock_post,
                           body = "{\"access_token\": \"fake_access_token\"}",
                           status = 200,
                           headers = list("Content-Type" = "application/json"))

    mock_get_sample <- stub_request("get", uri = "https://data.test.biocommons.org.au/api/v0/submission/program1/AusDiab/export/?node_label=sample&format=json")
    mock_get_sample <- to_return(
        mock_get_sample,
        body = paste0(
            "{\"data\": [",
            "{\"id\": 10, \"data_release_date\": \"2024-01-15\"},",
            "{\"id\": 11, \"data_release_date\": \"2024-06-01\"},",
            "{\"id\": 12, \"data_release_date\": \"2023-12-01\"}",
            "]}"
        ),
        status = 200,
        headers = list("Content-Type" = "application/json")
    )

    expect_message(
        result <- fetch_all_metadata(tmp_key_file, "program1", "AusDiab", data_release = "latest"),
        "2024-06-01"
    )

    expect_equal(length(result$sample), 1)
    expect_equal(result$sample[[1]]$id, 11)
    expect_equal(result$sample[[1]]$data_release_date, "2024-06-01")

    dfs <- to_df(result)
    expect_equal(nrow(dfs$sample), 1)
    expect_equal(dfs$sample$id, 11)

    assignInNamespace("get_node_order", original_get_node_order, ns = "gen3metadata")
    unlink(tmp_key_file)
    webmockr::stub_registry_clear()
})


test_that("fetch_all_metadata passes through nodes without release columns", {

    tmp_key_file <- tempfile(fileext = ".json")
    writeLines(fake_api_key, tmp_key_file)

    mock_get_node_order <- function(key_file) c("demographic")
    original_get_node_order <- gen3metadata::get_node_order
    assignInNamespace("get_node_order", mock_get_node_order, ns = "gen3metadata")

    mock_post <- stub_request("post", uri = "https://data.test.biocommons.org.au/user/credentials/cdis/access_token")
    mock_post <- to_return(mock_post,
                           body = "{\"access_token\": \"fake_access_token\"}",
                           status = 200,
                           headers = list("Content-Type" = "application/json"))

    mock_get_demo <- stub_request("get", uri = "https://data.test.biocommons.org.au/api/v0/submission/program1/AusDiab/export/?node_label=demographic&format=json")
    mock_get_demo <- to_return(
        mock_get_demo,
        body = "{\"data\": [{\"id\": 20, \"age\": 30}, {\"id\": 21, \"age\": 40}]}",
        status = 200,
        headers = list("Content-Type" = "application/json")
    )

    # Filter value "v1" but node has no release fields → pass through + message
    expect_message(
        result <- fetch_all_metadata(tmp_key_file, "program1", "AusDiab", data_release = "v1"),
        "demographic"
    )

    expect_equal(length(result$demographic), 2)
    expect_equal(nrow(to_df(result)$demographic), 2)

    assignInNamespace("get_node_order", original_get_node_order, ns = "gen3metadata")
    unlink(tmp_key_file)
    webmockr::stub_registry_clear()
})


test_that("fetch_all_metadata json and data.frame stay aligned after filter", {

    tmp_key_file <- tempfile(fileext = ".json")
    writeLines(fake_api_key, tmp_key_file)

    mock_get_node_order <- function(key_file) c("subject")
    original_get_node_order <- gen3metadata::get_node_order
    assignInNamespace("get_node_order", mock_get_node_order, ns = "gen3metadata")

    mock_post <- stub_request("post", uri = "https://data.test.biocommons.org.au/user/credentials/cdis/access_token")
    mock_post <- to_return(mock_post,
                           body = "{\"access_token\": \"fake_access_token\"}",
                           status = 200,
                           headers = list("Content-Type" = "application/json"))

    mock_get_subject <- stub_request("get", uri = "https://data.test.biocommons.org.au/api/v0/submission/program1/AusDiab/export/?node_label=subject&format=json")
    mock_get_subject <- to_return(
        mock_get_subject,
        body = paste0(
            "{\"data\": [",
            "{\"id\": 1, \"data_release\": \"v1\"},",
            "{\"id\": 2, \"data_release\": \"v2\"},",
            "{\"id\": 3, \"data_release\": \"v1\"},",
            "{\"id\": 4, \"data_release\": \"v2\"}",
            "]}"
        ),
        status = 200,
        headers = list("Content-Type" = "application/json")
    )

    result <- suppressMessages(
        fetch_all_metadata(tmp_key_file, "program1", "AusDiab", data_release = "v2")
    )

    expect_equal(length(result$subject), nrow(to_df(result)$subject))
    expect_equal(to_df(result)$subject$id, c(2, 4))

    assignInNamespace("get_node_order", original_get_node_order, ns = "gen3metadata")
    unlink(tmp_key_file)
    webmockr::stub_registry_clear()
})
