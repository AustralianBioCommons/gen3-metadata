import pytest
import json
import logging
from unittest.mock import patch, mock_open, MagicMock
from requests.exceptions import HTTPError, RequestException
from gen3_metadata.gen3_metadata_parser import Gen3MetadataParser, get_node_order, fetch_all_metadata, MetadataCollection
from gen3_metadata._filter import filter_records_by_data_release
import types
import requests
import pandas as pd
import jwt

@pytest.fixture
def fake_api_key():
    """Fixture to provide a fake API key. Note: these credentials have been inactivated."""
    # This is a valid JWT and UUID, but is not active.
    return {
        "api_key": (
            "eyJhbGciOiJSUzI1NiIsImtpZCI6ImZlbmNlX2tleV9rZXkiLCJ0eXAiOiJKV1QifQ."
            "eyJwdXIiOiJhcGlfa2V5Iiwic3ViIjoiMjEiLCJpc3MiOiJodHRwczovL2RhdGEudGVzdC5i"
            "aW9jb21tb25zLm9yZy5hdS91c2VyIiwiYXVkIjpbImh0dHBzOi8vZGF0YS50ZXN0LmJpb2Nv"
            "bW1vbnMub3JnLmF1L3VzZXIiXSwiaWF0IjoxNzQyMjUzNDgwLCJleHAiOjE3NDQ4NDU0ODAs"
            "Imp0aSI6ImI5MDQyNzAxLWIwOGYtNDBkYS04OWEzLTc1M2JlNGVkMTIyOSIsImF6cCI6IiIs"
            "InNjb3BlIjpbImdvb2dsZV9jcmVkZW50aWFscyIsIm9wZW5pZCIsImdvb2dsZV9zZXJ2aWNl"
            "X2FjY291bnQiLCJkYXRhIiwiZmVuY2UiLCJnb29nbGVfbGluayIsImFkbWluIiwidXNlciIs"
            "ImdhNGdoX3Bhc3Nwb3J0X3YxIl19."
            "SGPjs6ljCJbwDu-6WAnI5dN8o5467_ktcnsxRFrX_aCQNrOwSPgTCDvWEzamRmB5Oa0yB6cn"
            "jduhWRKnPWIZDal86H0etm77wilCteHF_zFl1IV6LW23AfOVOG3zB9KL6o-ZYqpSRyo0FDj0"
            "vQJzrHXPjqvQ15S6Js2sIwIa3ONTeHbR6fRecfPaLK1uGIY5tJFeigXzrLzlifKCEnt_2gqp"
            "MU2_b2QgW1315FixNIUOl8A7FZJ2-ddSMJPO0IYQ0QMSWV9-bbxie4Zjsaa1HtQYOhfXLU3v"
            "SdUOBO0btSfd6-NnWfx_-lDo5V9lkSH_aecEyew0IHBx-e7rSR5cxA"
        ),
        "key_id": "b9042701-b08f-40da-89a3-753be4ed1229"
    }

@pytest.fixture
def gen3_metadata_parser():
    """Fixture to create a Gen3MetadataParser instance."""
    return Gen3MetadataParser(key_file_path="fake_credentials.json")

@pytest.fixture
def malformed_json_credentials():
    """Fixture for malformed JSON credentials (no quotes, not valid Python dict)."""
    # This is a string, not a dict, to simulate malformed file content.
    return '{api_key: abc.def.ghi, key_id: 18bdaa-b018}'

def test_add_quotes_to_json_valid(gen3_metadata_parser):
    """Test _add_quotes_to_json with valid JSON (should parse as-is)."""
    valid_json = '{"api_key": "abc.def.ghi", "key_id": "18bdaa-b018"}'
    result = gen3_metadata_parser._add_quotes_to_json(valid_json)
    assert result == {"api_key": "abc.def.ghi", "key_id": "18bdaa-b018"}

def test_add_quotes_to_json_malformed(gen3_metadata_parser):
    """Test _add_quotes_to_json with malformed JSON (no quotes)."""
    malformed = '{api_key: abc.def.ghi, key_id: 18bdaa-b018}'
    result = gen3_metadata_parser._add_quotes_to_json(malformed)
    assert result == {"api_key": "abc.def.ghi", "key_id": "18bdaa-b018"}

def test_add_quotes_to_json_url_and_uuid(gen3_metadata_parser):
    """Test _add_quotes_to_json with keys/values including url and uuid."""
    malformed = '{key1: value1, key2:123, url: https://example.com, uuid: 18bdaa-b018}'
    result = gen3_metadata_parser._add_quotes_to_json(malformed)
    assert result == {
        "key1": "value1",
        "key2": "123",
        "url": "https://example.com",
        "uuid": "18bdaa-b018"
    }

def test_add_quotes_to_json_invalid(gen3_metadata_parser):
    """Test _add_quotes_to_json with unrecoverable malformed JSON."""
    bad = '{key1 value1, key2:}'
    with pytest.raises(ValueError):
        gen3_metadata_parser._add_quotes_to_json(bad)

def test_load_api_key_valid_json(gen3_metadata_parser, fake_api_key):
    """Test the _load_api_key method with valid JSON file content."""
    # Simulate reading a valid JSON file
    with patch("builtins.open", mock_open(read_data=json.dumps(fake_api_key))):
        result = gen3_metadata_parser._load_api_key()
        assert result == fake_api_key

def test_load_api_key_malformed_json(gen3_metadata_parser, malformed_json_credentials):
    """Test the _load_api_key method with malformed JSON (no quotes)."""
    # Simulate reading a malformed JSON file (no quotes)
    with patch("builtins.open", mock_open(read_data=malformed_json_credentials)):
        result = gen3_metadata_parser._load_api_key()
        assert result == {"api_key": "abc.def.ghi", "key_id": "18bdaa-b018"}

def test_load_api_key_invalid_json(gen3_metadata_parser):
    """Test the _load_api_key method with unrecoverable malformed JSON."""
    # Simulate reading a badly malformed JSON file
    bad_content = '{key1 value1, key2:}'
    with patch("builtins.open", mock_open(read_data=bad_content)):
        with pytest.raises(ValueError):
            gen3_metadata_parser._load_api_key()

def test_url_from_jwt(gen3_metadata_parser, fake_api_key):
    """Test if you can infer the data commons url from the JWT token"""
    url = gen3_metadata_parser._url_from_jwt(fake_api_key)
    print(f"The inferred URL is: {url}")
    assert url == "https://data.test.biocommons.org.au"


@patch("requests.post")
def test_authenticate(mock_post, gen3_metadata_parser, fake_api_key):
    """Test the _authenticate method."""
    # Mock response from requests.post
    fake_response = {"access_token": "fake_token"}
    mock_post.return_value.status_code = 200
    mock_post.return_value.json.return_value = fake_response

    # Mock _load_api_key to return the fake API key
    with patch.object(gen3_metadata_parser, "_load_api_key", return_value=fake_api_key):
        gen3_metadata_parser.authenticate()

        # Verify that headers are set correctly
        assert gen3_metadata_parser.headers == {"Authorization": "bearer fake_token"}

        # Verify that requests.post was called with correct arguments
        mock_post.assert_called_once_with(
            "https://data.test.biocommons.org.au/user/credentials/cdis/access_token",
            json=fake_api_key,
        )

@patch("requests.post")
def test_authenticate_http_error(mock_post, gen3_metadata_parser, fake_api_key):
    """Test _authenticate method when an HTTP error occurs."""
    mock_post.return_value.status_code = 401
    mock_post.return_value.raise_for_status.side_effect = requests.exceptions.HTTPError("Unauthorized")

    with patch.object(gen3_metadata_parser, "_load_api_key", return_value=fake_api_key):
        with pytest.raises(requests.exceptions.HTTPError, match="Unauthorized"):
            gen3_metadata_parser.authenticate()


@patch("requests.post")
def test_authenticate_missing_token(mock_post, gen3_metadata_parser, fake_api_key):
    """Test _authenticate method when 'access_token' is missing."""
    mock_post.return_value.status_code = 200
    mock_post.return_value.json.return_value = {}  # Missing 'access_token'

    with patch.object(gen3_metadata_parser, "_load_api_key", return_value=fake_api_key):
        with pytest.raises(KeyError, match="'access_token'"):
            gen3_metadata_parser.authenticate()


@patch("requests.get")
def test_fetch_data_success(mock_get, gen3_metadata_parser, fake_api_key):
    """Test fetch_data for successful API response."""
    fake_response = {"data": [{"id": 1, "name": "test"}]}
    mock_get.return_value.status_code = 200
    mock_get.return_value.json.return_value = fake_response

    program_name = "test_program"
    project_code = "test_project"
    node_label = "subjects"
    
    with patch("builtins.open", mock_open(read_data=json.dumps(fake_api_key))):
        gen3_metadata_parser.fetch_data(program_name, project_code, node_label, return_data=False)
        key = f"{program_name}/{project_code}/{node_label}"
        assert key in gen3_metadata_parser.data_store
        assert gen3_metadata_parser.data_store[key] == fake_response


@patch("requests.get")
def test_fetch_data_http_error(mock_get, gen3_metadata_parser, fake_api_key):
    """Test fetch_data when API returns an HTTP error."""
    mock_get.return_value.status_code = 404
    mock_get.return_value.raise_for_status.side_effect = requests.exceptions.HTTPError("Not Found")

    program_name = "test_program"
    project_code = "test_project"
    node_label = "subjects"

    with pytest.raises(requests.exceptions.HTTPError):
        with patch("builtins.open", mock_open(read_data=json.dumps(fake_api_key))):
            gen3_metadata_parser.fetch_data(program_name, project_code, node_label)


@patch("requests.get")
def test_fetch_data_json(mock_get, gen3_metadata_parser, fake_api_key):
    """Test fetch_data_json for successful API response."""
    fake_response = {"data": [{"id": 1, "name": "test"}]}
    mock_get.return_value.status_code = 200
    mock_get.return_value.json.return_value = fake_response

    program_name = "test_program"
    project_code = "test_project"
    node_label = "subjects"

    with patch("builtins.open", mock_open(read_data=json.dumps(fake_api_key))):
        result = gen3_metadata_parser.fetch_data_json(program_name, project_code, node_label)
        key = f"{program_name}/{project_code}/{node_label}"
        assert key in gen3_metadata_parser.data_store
        assert result == fake_response


@pytest.fixture
def mock_gen3_dictionary():
    """Yields a mock Gen3 data dictionary, with `_fetch_gen3_dictionary` patched
    to return it so tests that exercise `get_node_order` / `fetch_all_metadata`
    don't need to mock the HTTP layer themselves.
    """
    dictionary = {
        "subject": {
            "id": "subject",
            "category": "administrative",
            "properties": {
                "submitter_id": {"type": "string"},
                "project_id": {"type": "string"}
            },
            "links": [
                {"target_type": "project"}
            ]
        },
        "sample": {
            "id": "sample",
            "category": "biospecimen",
            "properties": {
                "submitter_id": {"type": "string"},
                "sample_type": {"type": "string"}
            },
            "links": [
                {"target_type": "subject"}
            ]
        },
        "demographic": {
            "id": "demographic",
            "category": "clinical",
            "properties": {
                "submitter_id": {"type": "string"},
                "age": {"type": "integer"}
            },
            "links": [
                {"target_type": "subject"}
            ]
        }
    }
    with patch(
        "gen3_metadata.gen3_metadata_parser._fetch_gen3_dictionary",
        return_value=dictionary,
    ):
        yield dictionary


@patch("gen3_metadata.gen3_metadata_parser.Gen3Submission")
@patch("gen3_metadata.gen3_metadata_parser.Gen3Auth")
def test_get_node_order(mock_auth, mock_sub_class, mock_gen3_dictionary):
    """Test get_node_order returns nodes in topological order."""
    mock_sub_instance = MagicMock()
    mock_sub_instance.get_dictionary_all.return_value = mock_gen3_dictionary
    mock_sub_class.return_value = mock_sub_instance

    result = get_node_order("fake_credentials.json")

    # subject must come before sample and demographic
    assert result.index("subject") < result.index("sample")
    assert result.index("subject") < result.index("demographic")
    # All three nodes should be present
    assert "subject" in result
    assert "sample" in result
    assert "demographic" in result


@patch("requests.get")
@patch("gen3_metadata.gen3_metadata_parser.Gen3Submission")
@patch("gen3_metadata.gen3_metadata_parser.Gen3Auth")
def test_fetch_all_metadata(mock_auth_class, mock_sub_class, mock_get, mock_gen3_dictionary):
    """Test fetch_all_metadata returns a MetadataCollection with dot-access and to_df()."""
    # Mock Gen3Auth
    mock_auth_instance = MagicMock()
    mock_auth_instance.endpoint = "https://test.example.com"
    mock_auth_class.return_value = mock_auth_instance

    # Mock Gen3Submission
    mock_sub_instance = MagicMock()
    mock_sub_instance.get_dictionary_all.return_value = mock_gen3_dictionary
    mock_sub_class.return_value = mock_sub_instance

    # Mock data fetch responses
    fake_response = {"data": [{"id": 1, "name": "test"}]}
    mock_get.return_value.status_code = 200
    mock_get.return_value.json.return_value = fake_response
    mock_get.return_value.raise_for_status.return_value = None

    result = fetch_all_metadata("fake_credentials.json", "prog", "proj", verbose=False)

    # Returns MetadataCollection
    assert isinstance(result, MetadataCollection)

    # Dot-access for JSON
    assert result.subject == fake_response
    assert result.sample == fake_response
    assert result.demographic == fake_response

    # to_df() returns dot-accessible DataFrames
    dfs = result.to_df()
    assert isinstance(dfs, types.SimpleNamespace)
    assert isinstance(dfs.subject, pd.DataFrame)
    assert dfs.subject.equals(pd.DataFrame(fake_response["data"]))


@patch("requests.get")
@patch("gen3_metadata.gen3_metadata_parser.Gen3Submission")
@patch("gen3_metadata.gen3_metadata_parser.Gen3Auth")
def test_fetch_all_metadata_skips_failed_nodes(mock_auth_class, mock_sub_class, mock_get, mock_gen3_dictionary):
    """Test that fetch_all_metadata skips nodes that fail and continues."""
    mock_auth_instance = MagicMock()
    mock_auth_instance.endpoint = "https://test.example.com"
    mock_auth_class.return_value = mock_auth_instance

    mock_sub_instance = MagicMock()
    mock_sub_instance.get_dictionary_all.return_value = mock_gen3_dictionary
    mock_sub_class.return_value = mock_sub_instance

    # sample fails with 403; all other nodes succeed
    def fake_get(url, **kwargs):
        resp = MagicMock()
        if "node_label=sample" in url:
            resp.status_code = 403
            err = requests.exceptions.HTTPError("403 Forbidden")
            err.response = resp
            resp.raise_for_status.side_effect = err
        else:
            resp.status_code = 200
            resp.json.return_value = {"data": [{"id": 1}]}
            resp.raise_for_status.return_value = None
        return resp

    mock_get.side_effect = fake_get

    result = fetch_all_metadata("fake_credentials.json", "prog", "proj", verbose=False)

    # Successful nodes present
    assert hasattr(result, "subject")
    assert hasattr(result, "demographic")

    # Failed node absent
    assert not hasattr(result, "sample")
    assert not hasattr(result.to_df(), "sample")


# ---------------------------------------------------------------------------
# Helper-level tests: filter_records_by_data_release
# ---------------------------------------------------------------------------


def test_filter_records_data_release_none_passthrough():
    """data_release=None returns records unchanged."""
    records = [
        {"id": 1, "data_release": "v1"},
        {"id": 2, "data_release": "v2"},
    ]
    filtered, keep_idx = filter_records_by_data_release(records, None, "subject")
    assert filtered == records
    assert keep_idx == [0, 1]


def test_filter_records_data_release_exact_match():
    """Specific string matches exactly on data_release field."""
    records = [
        {"id": 1, "data_release": "v1"},
        {"id": 2, "data_release": "v2"},
        {"id": 3, "data_release": "v1"},
    ]
    filtered, keep_idx = filter_records_by_data_release(records, "v1", "subject")
    assert filtered == [
        {"id": 1, "data_release": "v1"},
        {"id": 3, "data_release": "v1"},
    ]
    assert keep_idx == [0, 2]


def test_filter_records_data_release_specific_missing_column(caplog):
    """Node has no data_release field anywhere -> pass through + info log."""
    records = [{"id": 1, "name": "a"}, {"id": 2, "name": "b"}]
    with caplog.at_level(logging.INFO, logger="gen3_metadata"):
        filtered, keep_idx = filter_records_by_data_release(records, "v1", "demographic")
    assert filtered == records
    assert keep_idx == [0, 1]
    assert any("demographic" in rec.message and "data_release" in rec.message
               for rec in caplog.records)


def test_filter_records_data_release_specific_drops_missing_field(caplog):
    """Mix of records with/without data_release field; missing rows dropped."""
    records = [
        {"id": 1, "data_release": "v1"},
        {"id": 2},  # no data_release field
        {"id": 3, "data_release": "v1"},
        {"id": 4, "data_release": "v2"},
    ]
    with caplog.at_level(logging.DEBUG, logger="gen3_metadata"):
        filtered, keep_idx = filter_records_by_data_release(records, "v1", "subject")
    assert filtered == [
        {"id": 1, "data_release": "v1"},
        {"id": 3, "data_release": "v1"},
    ]
    assert keep_idx == [0, 2]


def test_filter_records_data_release_latest(caplog):
    """data_release='latest' picks max ISO date and filters."""
    records = [
        {"id": 10, "data_release_date": "2024-01-15"},
        {"id": 11, "data_release_date": "2024-06-01"},
        {"id": 12, "data_release_date": "2023-12-01"},
        {"id": 13, "data_release_date": "2024-06-01"},
    ]
    with caplog.at_level(logging.INFO, logger="gen3_metadata"):
        filtered, keep_idx = filter_records_by_data_release(records, "latest", "sample")
    assert filtered == [
        {"id": 11, "data_release_date": "2024-06-01"},
        {"id": 13, "data_release_date": "2024-06-01"},
    ]
    assert keep_idx == [1, 3]
    # Selection logged exactly once per node
    selection_logs = [rec for rec in caplog.records
                      if "selected" in rec.message and "2024-06-01" in rec.message]
    assert len(selection_logs) == 1
    assert "sample" in selection_logs[0].message


def test_filter_records_data_release_latest_unparseable_dates(caplog):
    """Unparseable dates are skipped; max is computed from parseable subset."""
    records = [
        {"id": 1, "data_release_date": "2024-01-15"},
        {"id": 2, "data_release_date": "not-a-date"},
        {"id": 3, "data_release_date": "2024-03-01"},
    ]
    with caplog.at_level(logging.WARNING, logger="gen3_metadata"):
        filtered, keep_idx = filter_records_by_data_release(records, "latest", "sample")
    assert keep_idx == [2]
    assert filtered == [{"id": 3, "data_release_date": "2024-03-01"}]
    # Warning about unparseable dates
    assert any("not-a-date" in rec.message or "unparseable" in rec.message.lower()
               for rec in caplog.records)


def test_filter_records_data_release_latest_all_missing(caplog):
    """No record has data_release_date -> pass through + info log."""
    records = [{"id": 1, "name": "a"}, {"id": 2, "name": "b"}]
    with caplog.at_level(logging.INFO, logger="gen3_metadata"):
        filtered, keep_idx = filter_records_by_data_release(records, "latest", "demographic")
    assert filtered == records
    assert keep_idx == [0, 1]
    assert any("demographic" in rec.message for rec in caplog.records)


def test_filter_records_data_release_latest_no_date_column_but_release_column(caplog):
    """Node has data_release but no data_release_date; 'latest' -> pass through."""
    records = [
        {"id": 1, "data_release": "v1"},
        {"id": 2, "data_release": "v2"},
    ]
    with caplog.at_level(logging.INFO, logger="gen3_metadata"):
        filtered, keep_idx = filter_records_by_data_release(records, "latest", "subject")
    assert filtered == records
    assert keep_idx == [0, 1]


def test_filter_records_data_release_empty_list():
    """Empty record list returns empty result cleanly."""
    filtered, keep_idx = filter_records_by_data_release([], "v1", "subject")
    assert filtered == []
    assert keep_idx == []


def test_filter_records_log_fn_callback_latest():
    """Custom log_fn receives the selection message for 'latest'."""
    messages = []
    records = [
        {"id": 10, "data_release_date": "2024-01-15"},
        {"id": 11, "data_release_date": "2024-06-01"},
    ]
    filter_records_by_data_release(
        records, "latest", "sample", log_fn=messages.append
    )
    assert any("2024-06-01" in m and "selected" in m for m in messages)


def test_filter_records_log_fn_callback_specific():
    """Custom log_fn receives the selection message for exact match."""
    messages = []
    records = [
        {"id": 1, "data_release": "v1"},
        {"id": 2, "data_release": "v2"},
    ]
    filter_records_by_data_release(
        records, "v1", "subject", log_fn=messages.append
    )
    assert any("v1" in m and "selected" in m for m in messages)


def test_filter_records_latest_log_includes_version_and_date():
    """'latest' selection log contains BOTH data_release_date AND data_release."""
    messages = []
    records = [
        {"id": 1, "data_release": "v2.3", "data_release_date": "2024-06-01"},
        {"id": 2, "data_release": "v2.3", "data_release_date": "2024-06-01"},
        {"id": 3, "data_release": "v2.2", "data_release_date": "2024-01-15"},
    ]
    filter_records_by_data_release(
        records, "latest", "subject", log_fn=messages.append
    )
    selection = [m for m in messages if "selected" in m]
    assert len(selection) == 1
    msg = selection[0]
    assert "2024-06-01" in msg
    assert "v2.3" in msg
    assert "data_release_date" in msg
    assert "data_release=" in msg


def test_filter_records_specific_log_includes_version_and_date():
    """Exact-match selection log contains BOTH data_release AND data_release_date."""
    messages = []
    records = [
        {"id": 1, "data_release": "v2.3", "data_release_date": "2024-06-01"},
        {"id": 2, "data_release": "v2.3", "data_release_date": "2024-06-01"},
        {"id": 3, "data_release": "v2.2", "data_release_date": "2024-01-15"},
    ]
    filter_records_by_data_release(
        records, "v2.3", "subject", log_fn=messages.append
    )
    selection = [m for m in messages if "selected" in m]
    assert len(selection) == 1
    msg = selection[0]
    assert "v2.3" in msg
    assert "2024-06-01" in msg
    assert "data_release=" in msg
    assert "data_release_date=" in msg


def test_filter_records_latest_log_handles_missing_version():
    """'latest' on records without data_release field -> log date only, no crash."""
    messages = []
    records = [
        {"id": 1, "data_release_date": "2024-06-01"},
        {"id": 2, "data_release_date": "2024-01-15"},
    ]
    filter_records_by_data_release(
        records, "latest", "subject", log_fn=messages.append
    )
    selection = [m for m in messages if "selected" in m]
    assert len(selection) == 1
    assert "2024-06-01" in selection[0]


@patch("requests.get")
@patch("gen3_metadata.gen3_metadata_parser.Gen3Submission")
@patch("gen3_metadata.gen3_metadata_parser.Gen3Auth")
def test_fetch_all_metadata_default_is_latest(
    mock_auth_class, mock_sub_class, mock_get, mock_gen3_dictionary, capsys
):
    """Default data_release is 'latest' — calling with no arg still filters."""
    mock_auth_class.return_value.endpoint = "https://test.example.com"

    mock_sub_instance = MagicMock()
    mock_sub_instance.get_dictionary_all.return_value = mock_gen3_dictionary
    mock_sub_class.return_value = mock_sub_instance

    fake_response = {"data": [
        {"id": 10, "data_release_date": "2024-01-15"},
        {"id": 11, "data_release_date": "2024-06-01"},
    ]}
    mock_get.return_value.status_code = 200
    mock_get.return_value.json.return_value = fake_response
    mock_get.return_value.raise_for_status.return_value = None

    # No data_release arg — should use default "latest"
    result = fetch_all_metadata(
        "fake_credentials.json", "prog", "proj", verbose=True
    )

    assert result.subject["data"] == [{"id": 11, "data_release_date": "2024-06-01"}]
    captured = capsys.readouterr()
    assert "2024-06-01" in captured.out
    assert "selected" in captured.out


@patch("requests.get")
@patch("gen3_metadata.gen3_metadata_parser.Gen3Submission")
@patch("gen3_metadata.gen3_metadata_parser.Gen3Auth")
def test_fetch_all_metadata_none_disables_filtering(
    mock_auth_class, mock_sub_class, mock_get, mock_gen3_dictionary, capsys
):
    """Explicit data_release=None disables filtering; no log lines emitted."""
    mock_auth_class.return_value.endpoint = "https://test.example.com"

    mock_sub_instance = MagicMock()
    mock_sub_instance.get_dictionary_all.return_value = mock_gen3_dictionary
    mock_sub_class.return_value = mock_sub_instance

    fake_response = {"data": [
        {"id": 10, "data_release_date": "2024-01-15"},
        {"id": 11, "data_release_date": "2024-06-01"},
    ]}
    mock_get.return_value.status_code = 200
    mock_get.return_value.json.return_value = fake_response
    mock_get.return_value.raise_for_status.return_value = None

    result = fetch_all_metadata(
        "fake_credentials.json", "prog", "proj", verbose=False, data_release=None
    )

    # All records returned unfiltered
    assert result.subject["data"] == fake_response["data"]


@patch("requests.get")
@patch("gen3_metadata.gen3_metadata_parser.Gen3Submission")
@patch("gen3_metadata.gen3_metadata_parser.Gen3Auth")
def test_fetch_all_metadata_latest_prints_selection(
    mock_auth_class, mock_sub_class, mock_get, mock_gen3_dictionary, capsys
):
    """fetch_all_metadata with verbose=True prints the selected date to stdout."""
    mock_auth_class.return_value.endpoint = "https://test.example.com"

    mock_sub_instance = MagicMock()
    mock_sub_instance.get_dictionary_all.return_value = mock_gen3_dictionary
    mock_sub_class.return_value = mock_sub_instance

    fake_response = {"data": [
        {"id": 10, "data_release_date": "2024-01-15"},
        {"id": 11, "data_release_date": "2024-06-01"},
        {"id": 12, "data_release_date": "2023-12-01"},
    ]}
    mock_get.return_value.status_code = 200
    mock_get.return_value.json.return_value = fake_response
    mock_get.return_value.raise_for_status.return_value = None

    fetch_all_metadata(
        "fake_credentials.json", "prog", "proj",
        verbose=True, data_release="latest"
    )

    captured = capsys.readouterr()
    # Selection message printed for at least one node
    assert "2024-06-01" in captured.out
    assert "selected" in captured.out


# ---------------------------------------------------------------------------
# Integration tests: fetch_all_metadata + fetch_data with data_release
# ---------------------------------------------------------------------------


@patch("requests.get")
@patch("gen3_metadata.gen3_metadata_parser.Gen3Submission")
@patch("gen3_metadata.gen3_metadata_parser.Gen3Auth")
def test_fetch_all_metadata_filters_by_data_release(
    mock_auth_class, mock_sub_class, mock_get, mock_gen3_dictionary
):
    """fetch_all_metadata with a specific data_release filters each node's records."""
    mock_auth_class.return_value.endpoint = "https://test.example.com"

    mock_sub_instance = MagicMock()
    mock_sub_instance.get_dictionary_all.return_value = mock_gen3_dictionary
    mock_sub_class.return_value = mock_sub_instance

    fake_response = {"data": [
        {"id": 1, "data_release": "v1"},
        {"id": 2, "data_release": "v2"},
        {"id": 3, "data_release": "v1"},
    ]}
    mock_get.return_value.status_code = 200
    mock_get.return_value.json.return_value = fake_response
    mock_get.return_value.raise_for_status.return_value = None

    result = fetch_all_metadata(
        "fake_credentials.json", "prog", "proj",
        verbose=False, data_release="v1"
    )

    # JSON filtered
    assert result.subject == {"data": [
        {"id": 1, "data_release": "v1"},
        {"id": 3, "data_release": "v1"},
    ]}
    # DataFrame filtered and aligned
    df = result.to_df().subject
    assert isinstance(df, pd.DataFrame)
    assert len(df) == 2
    assert list(df["id"]) == [1, 3]


@patch("requests.get")
@patch("gen3_metadata.gen3_metadata_parser.Gen3Submission")
@patch("gen3_metadata.gen3_metadata_parser.Gen3Auth")
def test_fetch_all_metadata_latest(
    mock_auth_class, mock_sub_class, mock_get, mock_gen3_dictionary, caplog
):
    """fetch_all_metadata with data_release='latest' picks max date per node."""
    mock_auth_class.return_value.endpoint = "https://test.example.com"

    mock_sub_instance = MagicMock()
    mock_sub_instance.get_dictionary_all.return_value = mock_gen3_dictionary
    mock_sub_class.return_value = mock_sub_instance

    fake_response = {"data": [
        {"id": 10, "data_release_date": "2024-01-15"},
        {"id": 11, "data_release_date": "2024-06-01"},
        {"id": 12, "data_release_date": "2023-12-01"},
    ]}
    mock_get.return_value.status_code = 200
    mock_get.return_value.json.return_value = fake_response
    mock_get.return_value.raise_for_status.return_value = None

    with caplog.at_level(logging.INFO, logger="gen3_metadata"):
        result = fetch_all_metadata(
            "fake_credentials.json", "prog", "proj",
            verbose=False, data_release="latest"
        )

    # Each node has only the latest date
    assert result.subject["data"] == [{"id": 11, "data_release_date": "2024-06-01"}]
    # Selection log captured for at least one node
    assert any("2024-06-01" in rec.message and "selected" in rec.message
               for rec in caplog.records)


@patch("requests.get")
@patch("gen3_metadata.gen3_metadata_parser.Gen3Submission")
@patch("gen3_metadata.gen3_metadata_parser.Gen3Auth")
def test_fetch_all_metadata_no_release_column_passthrough(
    mock_auth_class, mock_sub_class, mock_get, mock_gen3_dictionary
):
    """Node without release fields + specific data_release -> returned unchanged."""
    mock_auth_class.return_value.endpoint = "https://test.example.com"

    mock_sub_instance = MagicMock()
    mock_sub_instance.get_dictionary_all.return_value = mock_gen3_dictionary
    mock_sub_class.return_value = mock_sub_instance

    fake_response = {"data": [{"id": 1, "name": "a"}, {"id": 2, "name": "b"}]}
    mock_get.return_value.status_code = 200
    mock_get.return_value.json.return_value = fake_response
    mock_get.return_value.raise_for_status.return_value = None

    result = fetch_all_metadata(
        "fake_credentials.json", "prog", "proj",
        verbose=False, data_release="v1"
    )

    # Unchanged (pass-through)
    assert result.subject == fake_response
    assert len(result.to_df().subject) == 2


@patch("requests.get")
@patch("gen3_metadata.gen3_metadata_parser.Gen3Submission")
@patch("gen3_metadata.gen3_metadata_parser.Gen3Auth")
def test_fetch_all_metadata_nested_release_field(
    mock_auth_class, mock_sub_class, mock_get, mock_gen3_dictionary
):
    """Filter operates on top-level data_release only; nested 'metadata.data_release'
    flattened by json_normalize must not match."""
    mock_auth_class.return_value.endpoint = "https://test.example.com"

    mock_sub_instance = MagicMock()
    mock_sub_instance.get_dictionary_all.return_value = mock_gen3_dictionary
    mock_sub_class.return_value = mock_sub_instance

    # Each record has a nested 'metadata.data_release' but NO top-level one.
    fake_response = {"data": [
        {"id": 1, "metadata": {"data_release": "v1"}},
        {"id": 2, "metadata": {"data_release": "v2"}},
    ]}
    mock_get.return_value.status_code = 200
    mock_get.return_value.json.return_value = fake_response
    mock_get.return_value.raise_for_status.return_value = None

    result = fetch_all_metadata(
        "fake_credentials.json", "prog", "proj",
        verbose=False, data_release="v1"
    )

    # No top-level data_release field -> pass through unchanged
    assert result.subject == fake_response
    df = result.to_df().subject
    assert len(df) == 2
    # The flattened column exists but filter did NOT apply to it
    assert "metadata.data_release" in df.columns


@patch("requests.get")
def test_fetch_data_json_filters_by_data_release(mock_get, gen3_metadata_parser, fake_api_key):
    """fetch_data_json with data_release filters the returned dict."""
    fake_response = {"data": [
        {"id": 1, "data_release": "v1"},
        {"id": 2, "data_release": "v2"},
        {"id": 3, "data_release": "v1"},
    ]}
    mock_get.return_value.status_code = 200
    mock_get.return_value.json.return_value = fake_response
    mock_get.return_value.raise_for_status.return_value = None

    with patch("builtins.open", mock_open(read_data=json.dumps(fake_api_key))):
        result = gen3_metadata_parser.fetch_data_json(
            "prog", "proj", "subject", data_release="v1"
        )

    assert result == {"data": [
        {"id": 1, "data_release": "v1"},
        {"id": 3, "data_release": "v1"},
    ]}


@patch("requests.get")
def test_fetch_data_stores_filtered_in_data_store(mock_get, gen3_metadata_parser, fake_api_key):
    """Gen3MetadataParser.fetch_data stores the filtered data, not the raw."""
    fake_response = {"data": [
        {"id": 1, "data_release": "v1"},
        {"id": 2, "data_release": "v2"},
    ]}
    mock_get.return_value.status_code = 200
    mock_get.return_value.json.return_value = fake_response
    mock_get.return_value.raise_for_status.return_value = None

    with patch("builtins.open", mock_open(read_data=json.dumps(fake_api_key))):
        gen3_metadata_parser.fetch_data(
            "prog", "proj", "subject", data_release="v1"
        )

    key = "prog/proj/subject"
    assert gen3_metadata_parser.data_store[key] == {"data": [
        {"id": 1, "data_release": "v1"},
    ]}


@patch("requests.get")
@patch("gen3_metadata.gen3_metadata_parser.Gen3Submission")
@patch("gen3_metadata.gen3_metadata_parser.Gen3Auth")
def test_fetch_all_metadata_empty_data(mock_auth_class, mock_sub_class, mock_get, mock_gen3_dictionary):
    """Test that empty data returns an empty DataFrame via to_df()."""
    mock_auth_instance = MagicMock()
    mock_auth_instance.endpoint = "https://test.example.com"
    mock_auth_class.return_value = mock_auth_instance

    mock_sub_instance = MagicMock()
    mock_sub_instance.get_dictionary_all.return_value = mock_gen3_dictionary
    mock_sub_class.return_value = mock_sub_instance

    mock_get.return_value.status_code = 200
    mock_get.return_value.json.return_value = {"data": []}
    mock_get.return_value.raise_for_status.return_value = None

    result = fetch_all_metadata("fake_credentials.json", "prog", "proj", verbose=False)

    assert result.subject == {"data": []}
    assert isinstance(result.to_df().subject, pd.DataFrame)
    assert result.to_df().subject.empty
