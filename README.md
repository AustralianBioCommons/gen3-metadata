# gen3-metadata
User friendly tools for downloading and manipulating gen3 metadata


## 1. Set up python venv
```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

## 2. Create config file 
```bash
echo credentials_path=\"/path/to/credentials.json\" > .env
```

## 3. Load library
```bash
pip install -e .
```


## Alternatively you can build using:
```bash
bash build.sh
```

# Usage

## 4. Run the notebook
- Notebook can be found in the `example_notebook.ipynb` file
- Make sure to select .venv as the kernel in the notebook


## 4. Usage Example

```python
import os
from gen3_metadata.parser import Gen3MetadataParser
from dotenv import load_dotenv

load_dotenv()
key_file = os.getenv('credentials_path')
# Set up credentials path
key_file = os.getenv('credentials_path')

# Initialize the Gen3MetadataParser
gen3metadata = Gen3MetadataParser(key_file)

# authenticate
gen3metadata.authenticate()

# Fetch data for different categories
gen3metadata.fetch_data("program1", "AusDiab_Simulated", "subject")
gen3metadata.fetch_data("program1", "AusDiab_Simulated", "demographic")
gen3metadata.fetch_data("program1", "AusDiab_Simulated", "medical_history")

# Convert fetched data to a pandas DataFrame
gen3metadata.data_to_pd()

# Print the keys of the data sets that have been fetched
print(gen3metadata.data_store.keys())

# Return a json of one of the datasets
gen3metadata.data_store["program1/AusDiab_Simulated/subject"]

# Return the pandas dataframe of one of the datasets
gen3metadata.data_store_pd["program1/AusDiab_Simulated/subject"]
```

The fetched data is stored in a dictionary within the `Gen3MetadataParser` instance.
Each category of data fetched is stored as a key-value pair in this dictionary,
where the key is the category name and the value is the corresponding data.
This allows for easy access and manipulation of the data after it has been fetched.




## 5. Running Tests

The tests are written using the `pytest` framework. 

```bash
pytest tests/
```




## Installation of the R version of gen3-metadata

You can install the gen3metadata R tool from
[GitHub](https://github.com/) with:

``` r
if (!require("devtools")) install.packages("devtools")
devtools::install_github("AustralianBioCommons/gen3-metadata", subdir = "gen3metadata-R")
```

The package depends on several other packages, which should hopefully be installed automatically.
If case this doesn't happen, run:
``` r
install.packages(c("httr", "jsonlite", "jose", "glue"))
```

Then all you need to do is load the package.

``` r
library("gen3metadata")
```

## Usage Example

This is a basic example to authenticate and load some data.
You will need a credential file (stored in `key_file_path` in this example).

``` r
# Load the library
library("gen3metadata")

# Create the Gen3 Metadata Parser object
gen3 <- Gen3MetadataParser(key_file_path)

# Authenticate the object
gen3 <- authenticate(gen3)

# Load some data
dat <- fetch_data(gen3,
                  program_name = "program1",
                  project_code = "AusDiab",
                  node_label = "subject")
```
