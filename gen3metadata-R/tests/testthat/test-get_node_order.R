#' Unit tests for get_node_order

library(testthat)
library(gen3metadata)


test_that("get_node_order returns nodes in topological order", {

    # Skip if reticulate/Python not available
    skip_if_not_installed("reticulate")
    skip_if(!reticulate::py_module_available("gen3_metadata"),
            message = "Python gen3_metadata package not available")
    skip_if(!reticulate::py_module_available("unittest"),
            message = "Python unittest not available")

    # Use Python's unittest.mock to patch Gen3Auth and Gen3Submission
    mock_mod <- reticulate::import("unittest.mock")

    # Mock dictionary with subject, sample, and demographic nodes
    mock_dictionary <- list(
        subject = list(
            id = "subject",
            category = "administrative",
            properties = list(
                submitter_id = list(type = "string")
            ),
            links = list(
                list(target_type = "project")
            )
        ),
        sample = list(
            id = "sample",
            category = "biospecimen",
            properties = list(
                submitter_id = list(type = "string"),
                sample_type = list(type = "string")
            ),
            links = list(
                list(target_type = "subject")
            )
        ),
        demographic = list(
            id = "demographic",
            category = "clinical",
            properties = list(
                submitter_id = list(type = "string"),
                age = list(type = "integer")
            ),
            links = list(
                list(target_type = "subject")
            )
        )
    )

    # Create a temporary credentials file (content doesn't matter, it'll be mocked)
    tmp_key_file <- tempfile(fileext = ".json")
    writeLines("{\"api_key\": \"fake\", \"key_id\": \"fake\"}", tmp_key_file)

    # Patch Gen3Auth and Gen3Submission in the Python module
    auth_patcher <- mock_mod$patch("gen3_metadata.gen3_metadata_parser.Gen3Auth")
    sub_patcher <- mock_mod$patch("gen3_metadata.gen3_metadata_parser.Gen3Submission")

    mock_auth <- auth_patcher$start()
    mock_sub_class <- sub_patcher$start()

    # Configure the mock submission instance to return our dictionary
    mock_sub_instance <- mock_sub_class()
    mock_sub_instance$get_dictionary_all$return_value <- mock_dictionary
    mock_sub_class$return_value <- mock_sub_instance

    result <- get_node_order(tmp_key_file)

    # Stop patchers
    auth_patcher$stop()
    sub_patcher$stop()

    # subject must come before sample and demographic
    subject_idx <- which(result == "subject")
    sample_idx <- which(result == "sample")
    demographic_idx <- which(result == "demographic")

    expect_true(length(subject_idx) == 1)
    expect_true(length(sample_idx) == 1)
    expect_true(length(demographic_idx) == 1)
    expect_true(subject_idx < sample_idx)
    expect_true(subject_idx < demographic_idx)

    # Clean up
    unlink(tmp_key_file)
})


test_that("get_node_order errors when key file does not exist", {
    expect_error(get_node_order("nonexistent_file.json"), "Key file not found")
})
