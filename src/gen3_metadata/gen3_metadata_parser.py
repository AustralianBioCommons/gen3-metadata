import json
import requests
import pandas as pd
import jwt
import re
import logging


class Gen3MetadataParser:
    """
    A class to interact with Gen3 metadata API for fetching and processing data.
    """

    def __init__(self, key_file_path, logger=None):
        """
        Initializes the Gen3MetadataParser with API URL and key file path.

        Args:
            key_file_path (str): The file path to the JSON key file for authentication.
            logger (logging.Logger, optional): Logger instance to use. If None, uses default.
        """
        self.key_file_path = key_file_path
        self.headers = {}
        self.data_store = {}
        self.data_store_pd = {}
        if logger is None:
            self.logger = logging.getLogger("gen3_metadata")
        else:
            self.logger = logger
        self.logger.info(f"Initialized Gen3MetadataParser with key file: {key_file_path}")

    def _add_quotes_to_json(self, input_str):
        try:
            # Try parsing as-is
            self.logger.debug("Attempting to parse JSON as-is.")
            return json.loads(input_str)
        except json.JSONDecodeError:
            self.logger.warning("JSON decode failed, attempting to fix missing quotes in JSON.")
            # Add quotes around keys
            fixed = re.sub(r'([{,]\s*)(\w+)\s*:', r'\1"\2":', input_str)
            # Add quotes around simple string values (skip existing quoted values)
            fixed = re.sub(r':\s*([A-Za-z0-9._:@/-]+)(?=\s*[},])', r': "\1"', fixed)
            try:
                self.logger.debug("Trying to parse fixed JSON string.")
                return json.loads(fixed)
            except json.JSONDecodeError as e:
                self.logger.error(f"Could not fix JSON: {e}")
                raise ValueError(f"Could not fix JSON: {e}")

    def _load_api_key(self) -> dict:
        """
        Loads the API key from the specified JSON file.

        Returns:
            dict: The API key loaded from the JSON file.
        """
        try:
            self.logger.info(f"Loading API key from file: {self.key_file_path}")
            # Read the file as plain text
            with open(self.key_file_path, "r") as f:
                content = f.read()
            # If the content does not contain any double or single quotes, try to fix it
            if '"' not in content and "'" not in content:
                self.logger.warning("API key file appears to lack quotes, attempting to fix.")
                return self._add_quotes_to_json(content)

            # Read the file as JSON
            with open(self.key_file_path) as json_file:
                self.logger.debug("Parsing API key file as JSON.")
                return json.load(json_file)
        except FileNotFoundError as fnf_err:
            self.logger.error(f"File not found: {fnf_err}")
            print(f"File not found: {fnf_err}")
            raise
        except json.JSONDecodeError as json_err:
            self.logger.error(f"JSON decode error: {json_err}")
            print(f"JSON decode error: {json_err}")
            print("Please make sure the file contains valid JSON with quotes and proper formatting.")
            raise
        except Exception as err:
            self.logger.error(f"An unexpected error occurred while loading API key: {err}")
            print(f"An unexpected error occurred while loading API key: {err}")
            raise

    def _url_from_jwt(self, cred: dict) -> str:
        """
        Extracts the URL from a JSON Web Token (JWT) credential.

        Args:
            cred (dict): The JSON Web Token (JWT) credential.

        Returns:
            str: The extracted URL.
        """
        jwt_token = cred['api_key']
        self.logger.debug("Decoding JWT to extract API URL.")
        url = jwt.decode(jwt_token, options={"verify_signature": False}).get('iss', '').removesuffix("/user")
        self.logger.info(f"Extracted API URL from JWT: {url}")
        return url

    def authenticate(self) -> dict:
        """
        Authenticates with the Gen3 API using the loaded API key.

        Returns:
            dict: Headers containing the authorization token.
        """
        try:
            self.logger.info("Starting authentication process.")
            key = self._load_api_key()
            api_url = self._url_from_jwt(key)
            self.logger.info(f"Sending authentication request to: {api_url}/user/credentials/cdis/access_token")
            response = requests.post(
                f"{api_url}/user/credentials/cdis/access_token", json=key
            )
            self.logger.debug(f"Authentication response status code: {response.status_code}")
            response.raise_for_status()
            access_token = response.json()['access_token']
            self.headers = {'Authorization': f"bearer {access_token}"}
            self.logger.info(f"Authentication successful. Access token received. Status code: {response.status_code}")
            print(f"Authentication successful: {response.status_code}")
        except requests.exceptions.HTTPError as http_err:
            self.logger.error(
                f"HTTP error occurred during authentication: {http_err} - "
                f"Status Code: {getattr(http_err.response, 'status_code', 'N/A')}"
            )
            print(
                f"HTTP error occurred during authentication: {http_err} - "
                f"Status Code: {getattr(http_err.response, 'status_code', 'N/A')}"
            )
            raise
        except requests.exceptions.RequestException as req_err:
            self.logger.error(f"Request error occurred during authentication: {req_err}")
            print(f"Request error occurred during authentication: {req_err}")
            raise
        except KeyError as key_err:
            self.logger.error(
                f"Key error: {key_err} - The response may not contain 'access_token'"
            )
            print(
                f"Key error: {key_err} - The response may not contain 'access_token'"
            )
            raise
        except Exception as err:
            self.logger.error(f"An unexpected error occurred during authentication: {err}")
            print(f"An unexpected error occurred during authentication: {err}")
            raise

    def json_to_pd(self, json_data) -> pd.DataFrame:
        """
        Converts JSON data to a pandas DataFrame.

        Args:
            json_data (dict): The JSON data to convert.

        Returns:
            pandas.DataFrame: The converted pandas DataFrame.
        """
        self.logger.debug("Converting JSON data to pandas DataFrame.")
        return pd.json_normalize(json_data)

    def fetch_data(
        self, program_name, project_code, node_label, return_data=False, api_version="v0"
    ) -> dict:
        """
        Fetches data from the Gen3 API for a specific program, project, and node label.

        Args:
            program_name (str): The name of the program.
            project_code (str): The code of the project.
            node_label (str): The label of the node.
            return_data (bool, optional): Whether to return the fetched data.
                Defaults to False.
            api_version (str, optional): The version of the API to use.
                Defaults to "v0".

        Returns:
            dict or None: The fetched data if return_data is True, otherwise None.
        """
        try:
            self.logger.info(
                f"Fetching data for program: {program_name}, project: {project_code}, "
                f"node: {node_label}, API version: {api_version}"
            )
            creds = self._load_api_key()
            api_url = self._url_from_jwt(creds)
            url = (
                f"{api_url}/api/{api_version}/submission/{program_name}/{project_code}/"
                f"export/?node_label={node_label}&format=json"
            )
            self.logger.info(f"GET request to URL: {url}")
            response = requests.get(url, headers=self.headers)
            self.logger.info(f"Fetch data response status code: {response.status_code}")
            print(f"status code: {response.status_code}")
            response.raise_for_status()
            data = response.json()

            key = f"{program_name}/{project_code}/{node_label}"
            self.data_store[key] = data
            self.logger.info(f"Data for {key} has been fetched and stored in data_store.")

            if return_data:
                self.logger.debug(f"Returning fetched data for {key}.")
                return data
            else:
                self.logger.info(f"Data for {key} has been fetched and stored.")
                print(f"Data for {key} has been fetched and stored.")
        except requests.exceptions.HTTPError as http_err:
            self.logger.error(
                f"HTTP error occurred: {http_err} - "
                f"Status Code: {getattr(http_err.response, 'status_code', 'N/A')}"
            )
            print(
                f"HTTP error occurred: {http_err} - "
                f"Status Code: {getattr(http_err.response, 'status_code', 'N/A')}"
            )
            raise
        except Exception as err:
            self.logger.error(f"An error occurred while fetching data: {err}")
            print(f"An error occurred: {err}")
            raise

    def data_to_pd(self) -> None:
        """
        Converts all fetched JSON data in the data store to pandas DataFrames.
        """
        self.logger.info("Converting all fetched JSON data in data_store to pandas DataFrames.")
        for key, value in self.data_store.items():
            self.logger.info(f"Converting {key} to pandas dataframe...")
            print(f"Converting {key} to pandas dataframe...")
            try:
                self.data_store_pd[key] = self.json_to_pd(value['data'])
                self.logger.debug(f"Conversion successful for {key}.")
            except Exception as e:
                self.logger.error(f"Failed to convert {key} to pandas DataFrame: {e}")
                print(f"Failed to convert {key} to pandas DataFrame: {e}")
        self.logger.info("All available data converted to pandas DataFrames.")
        return

    def fetch_data_pd(self, program_name, project_code, node_label, api_version="v0"):
        """
        Fetches data from the Gen3 API for a specific program, project, and node label,
        and converts it to a pandas DataFrame.

        Args:
            program_name (str): The name of the program.
            project_code (str): The code of the project.
            node_label (str): The label of the node.
            api_version (str, optional): The version of the API to use.
                Defaults to "v0".
        """
        self.logger.info(
            f"Fetching data as pandas DataFrame for {program_name}/{project_code}/{node_label} "
            f"(API version: {api_version})"
        )
        data = self.fetch_data(program_name, project_code, node_label, api_version=api_version, return_data=True)
        try:
            df = self.json_to_pd(data['data'])
            self.logger.info(
                f"Successfully converted data to pandas DataFrame for "
                f"{program_name}/{project_code}/{node_label}"
            )
            return df
        except Exception as e:
            self.logger.error(f"Failed to convert fetched data to pandas DataFrame: {e}")
            print(f"Failed to convert fetched data to pandas DataFrame: {e}")
            raise

    def fetch_data_json(self, program_name, project_code, node_label, api_version="v0"):
        """
        Fetches data from the Gen3 API for a specific program, project, and node label.

        Args:
            program_name (str): The name of the program.
            project_code (str): The code of the project.
            node_label (str): The label of the node.
            api_version (str, optional): The version of the API to use.
                Defaults to "v0".
        """
        self.logger.info(
            f"Fetching data as JSON for {program_name}/{project_code}/{node_label} "
            f"(API version: {api_version})"
        )
        return self.fetch_data(program_name, project_code, node_label, api_version=api_version, return_data=True)
