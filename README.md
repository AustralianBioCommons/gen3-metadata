# gen3-metadata
User friendly tools for downloading and manipulating gen3 metadata

## Python Installation
```bash
git clone https://github.com/AustralianBioCommons/gen3-metadata.git
bash build.sh
```

## Usage Example
- Notebook can be found in the `example_notebook.ipynb` file
- Make sure to select .venv as the kernel in the notebook

```python
from gen3_metadata.gen3_metadata_parser import Gen3MetadataParser

# Initialise
key_file = "path/to/credentials.json"
gen3metadata = Gen3MetadataParser(key_file)

# Authenticate
gen3metadata.authenticate()

# Fetching data and returning as dataframe
program_name = "program1"
project_code = "project1"
node_label="medical_history"
pd_data = gen3metadata.fetch_data_pd(program_name, project_code, node_label=node_label)
pd_data

# Fetching data and returning as json
json_data = gen3metadata.fetch_data_json(program_name, project_code, node_label=node_label)
json_data
```


## Running Tests

The tests are written using the `pytest` framework. 

```bash
pytest -vv tests/
```

---

# Installation of the R version of gen3-metadata

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

``` r
# Load the library
library("gen3metadata")

# Set the path to the credentials file
key_file_path <- "path/to/credentials.json"

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
