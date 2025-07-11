import pytest
import json
from unittest.mock import patch, mock_open, MagicMock
from requests.exceptions import HTTPError, RequestException
from gen3_metadata.gen3_metadata_parser import Gen3MetadataParser 
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


def test_json_to_pd(gen3_metadata_parser):
    """Test json_to_pd method."""
    json_data = [
        {"id": 1, "name": "Josh", "age": 30},
        {"id": 2, "name": "Harris", "age": 25}
    ]
    expected_df = pd.DataFrame({
        "id": [1, 2],
        "name": ["Josh", "Harris"],
        "age": [30, 25]
    })
    result_df = gen3_metadata_parser.json_to_pd(json_data)
    pd.testing.assert_frame_equal(result_df, expected_df)


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


@pytest.fixture
def data_store():
    return {
        'data': [
            {'project_id': 'project1', 'submitter_id': 'subject_bdf5291449'},
            {'project_id': 'project1', 'submitter_id': 'subject_acf4281442'}
        ]
    }

def test_data_to_pd(gen3_metadata_parser, data_store):
    """Test data_to_pd method."""
    json_data = data_store
    test_key = "program1/project1/subject"
    # Populate data_store with mock data
    gen3_metadata_parser.data_store[test_key] = json_data
    # Expected DataFrame
    expected_df = pd.DataFrame({"project_id": ['project1', 'project1'], "submitter_id": ["subject_bdf5291449", "subject_acf4281442"]})
    # Call data_to_pd
    gen3_metadata_parser.data_to_pd()
    # Verify conversion
    assert test_key in gen3_metadata_parser.data_store_pd
    pd.testing.assert_frame_equal(gen3_metadata_parser.data_store_pd[test_key], expected_df)


@patch("requests.get")
def test_fetch_data_pd(mock_get, gen3_metadata_parser, fake_api_key):
    """Test fetch_data for successful API response."""
    fake_response = {"data": [{"id": 1, "name": "test"}]}
    mock_get.return_value.status_code = 200
    mock_get.return_value.json.return_value = fake_response

    program_name = "test_program"
    project_code = "test_project"
    node_label = "subjects"

    with patch("builtins.open", mock_open(read_data=json.dumps(fake_api_key))):
        result = gen3_metadata_parser.fetch_data_pd(program_name, project_code, node_label)
        key = f"{program_name}/{project_code}/{node_label}"
        assert key in gen3_metadata_parser.data_store
        assert isinstance(result, pd.DataFrame)
        assert result.equals(pd.DataFrame(fake_response['data']))


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
