#' Unit tests for get_node_order (pure R version)

library(testthat)
library(webmockr)
library(gen3metadata)

webmockr::enable()

## Fixture: fake API key. JWT iss = "https://data.test.biocommons.org.au/user",
## so base_url resolves to "https://data.test.biocommons.org.au".
## These credentials have been inactivated.
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

DICT_URL <- "https://data.test.biocommons.org.au/api/v0/submission/_dictionary/_all"


test_that("get_node_order returns nodes in topological order", {

    tmp_key_file <- tempfile(fileext = ".json")
    writeLines(fake_api_key, tmp_key_file)

    # subject -> project, sample -> subject, demographic -> subject
    dict_body <- paste0(
        "{",
        "\"subject\": {\"id\": \"subject\", \"links\": [{\"target_type\": \"project\"}]},",
        "\"sample\": {\"id\": \"sample\", \"links\": [{\"target_type\": \"subject\"}]},",
        "\"demographic\": {\"id\": \"demographic\", \"links\": [{\"target_type\": \"subject\"}]}",
        "}"
    )

    mock_get <- stub_request("get", uri = DICT_URL)
    mock_get <- to_return(
        mock_get,
        body    = dict_body,
        status  = 200,
        headers = list("Content-Type" = "application/json")
    )

    result <- get_node_order(tmp_key_file)

    subject_idx     <- which(result == "subject")
    sample_idx      <- which(result == "sample")
    demographic_idx <- which(result == "demographic")

    expect_true(length(subject_idx) == 1)
    expect_true(length(sample_idx) == 1)
    expect_true(length(demographic_idx) == 1)
    expect_true(subject_idx < sample_idx)
    expect_true(subject_idx < demographic_idx)

    unlink(tmp_key_file)
    webmockr::stub_registry_clear()
})


test_that("get_node_order errors when key file does not exist", {
    expect_error(get_node_order("nonexistent_file.json"), "Key file not found")
})


test_that("get_node_order errors when dictionary endpoint returns HTTP error", {

    tmp_key_file <- tempfile(fileext = ".json")
    writeLines(fake_api_key, tmp_key_file)

    mock_get <- stub_request("get", uri = DICT_URL)
    mock_get <- to_return(
        mock_get,
        body    = "",
        status  = 500,
        headers = list("Content-Type" = "application/json")
    )

    expect_error(
        get_node_order(tmp_key_file),
        "Failed to fetch Gen3 data dictionary"
    )

    unlink(tmp_key_file)
    webmockr::stub_registry_clear()
})


test_that("get_node_order forces core_metadata_collection to the end", {

    tmp_key_file <- tempfile(fileext = ".json")
    writeLines(fake_api_key, tmp_key_file)

    dict_body <- paste0(
        "{",
        "\"core_metadata_collection\": {\"id\": \"core_metadata_collection\", \"links\": [{\"target_type\": \"project\"}]},",
        "\"subject\": {\"id\": \"subject\", \"links\": [{\"target_type\": \"project\"}]},",
        "\"sample\": {\"id\": \"sample\", \"links\": [{\"target_type\": \"subject\"}]}",
        "}"
    )

    mock_get <- stub_request("get", uri = DICT_URL)
    mock_get <- to_return(
        mock_get,
        body    = dict_body,
        status  = 200,
        headers = list("Content-Type" = "application/json")
    )

    result <- get_node_order(tmp_key_file)

    expect_equal(result[length(result)], "core_metadata_collection")

    unlink(tmp_key_file)
    webmockr::stub_registry_clear()
})


test_that("get_node_order skips nodes in the excluded list", {

    tmp_key_file <- tempfile(fileext = ".json")
    writeLines(fake_api_key, tmp_key_file)

    # _definitions, _terms, _settings, program, metaschema, root all excluded
    # from edge extraction. They should NOT appear as iterated sources, but
    # they CAN appear as link targets (matching Python behavior).
    dict_body <- paste0(
        "{",
        "\"_definitions\": {\"id\": \"_definitions\"},",
        "\"_terms\": {\"id\": \"_terms\"},",
        "\"_settings\": {\"id\": \"_settings\"},",
        "\"program\": {\"id\": \"program\"},",
        "\"metaschema\": {\"id\": \"metaschema\"},",
        "\"root\": {\"id\": \"root\"},",
        "\"subject\": {\"id\": \"subject\", \"links\": [{\"target_type\": \"project\"}]},",
        "\"sample\": {\"id\": \"sample\", \"links\": [{\"target_type\": \"subject\"}]}",
        "}"
    )

    mock_get <- stub_request("get", uri = DICT_URL)
    mock_get <- to_return(
        mock_get,
        body    = dict_body,
        status  = 200,
        headers = list("Content-Type" = "application/json")
    )

    result <- get_node_order(tmp_key_file)

    # Excluded nodes that are NOT link targets must not appear at all
    expect_false("_definitions" %in% result)
    expect_false("_terms" %in% result)
    expect_false("_settings" %in% result)
    expect_false("program" %in% result)
    expect_false("metaschema" %in% result)
    expect_false("root" %in% result)

    # Data nodes appear in topological order
    expect_true("subject" %in% result)
    expect_true("sample" %in% result)
    expect_true(which(result == "subject") < which(result == "sample"))

    unlink(tmp_key_file)
    webmockr::stub_registry_clear()
})


test_that("get_node_order handles links subgroup wrapper", {

    tmp_key_file <- tempfile(fileext = ".json")
    writeLines(fake_api_key, tmp_key_file)

    # Some Gen3 dictionaries wrap links in a single subgroup entry.
    # Python: if "subgroup" in links[0]: links = links[0]["subgroup"]
    dict_body <- paste0(
        "{",
        "\"subject\": {\"id\": \"subject\", \"links\": [{\"target_type\": \"project\"}]},",
        "\"sample\": {\"id\": \"sample\", \"links\": [",
        "  {\"subgroup\": [",
        "    {\"target_type\": \"subject\"}",
        "  ]}",
        "]}",
        "}"
    )

    mock_get <- stub_request("get", uri = DICT_URL)
    mock_get <- to_return(
        mock_get,
        body    = dict_body,
        status  = 200,
        headers = list("Content-Type" = "application/json")
    )

    result <- get_node_order(tmp_key_file)

    expect_true("subject" %in% result)
    expect_true("sample" %in% result)
    expect_true(which(result == "subject") < which(result == "sample"))

    unlink(tmp_key_file)
    webmockr::stub_registry_clear()
})
