# gen3-metadata
User friendly tools for downloading and manipulating gen3 metadata.

## Python

### Installation
```bash
git clone https://github.com/AustralianBioCommons/gen3-metadata.git
bash build.sh
```

> A full usage notebook is available in `example_notebook.ipynb`. Make sure to select `.venv` as the kernel.

### Fetch all metadata

`fetch_all_metadata` is the primary entry point. It walks the data dictionary in dependency order and fetches data for every node, returning a dot-accessible object of JSON dicts. Call `.to_df()` on the result to get pandas DataFrames instead.

```python
from gen3_metadata.gen3_metadata_parser import fetch_all_metadata

key_file = "path/to/credentials.json"
result = fetch_all_metadata(key_file, "program1", "project1")

# Access each node as raw JSON
result.subject          # dict
result.demographic      # dict

# Or get DataFrames
dfs = result.to_df()
dfs.subject             # pandas DataFrame
dfs.demographic         # pandas DataFrame
```

### List nodes

`get_node_order` returns a topologically sorted list of node names from the data dictionary (parents before children).

```python
from gen3_metadata.gen3_metadata_parser import get_node_order

nodes = get_node_order("path/to/credentials.json")
# ['program', 'project', 'subject', 'sample', 'demographic', ...]
```

### Fetch a single node

If you only need one node, use `Gen3MetadataParser` + `fetch_data_json`. It returns the raw JSON response as a dict. Convert to a DataFrame yourself if you need one.

```python
import pandas as pd
from gen3_metadata.gen3_metadata_parser import Gen3MetadataParser

key_file = "path/to/credentials.json"
parser = Gen3MetadataParser(key_file)
parser.authenticate()

json_data = parser.fetch_data_json("program1", "project1", node_label="medical_history")
json_data  # {'data': [...]}

# Convert to DataFrame if desired:
df = pd.json_normalize(json_data["data"])
```

### Running Tests

```bash
pytest -vv tests/
```

---

## R

### Installation

``` r
if (!require("devtools")) install.packages("devtools")
devtools::install_github("AustralianBioCommons/gen3-metadata", subdir = "gen3metadata-R")
```

The package depends on several other packages, which should be installed automatically. If not:

``` r
install.packages(c("httr", "jsonlite", "jose", "glue", "reticulate"))
```

The `get_node_order` and `fetch_all_metadata` functions require the Python `gen3_metadata` package to be installed (they use `reticulate` to call Python under the hood).

``` r
library("gen3metadata")
```

### Fetch all metadata

`fetch_all_metadata` is the primary entry point. It walks the data dictionary in dependency order and fetches data for every node, returning a `metadata_collection` object where nodes are accessible via `$`. Call `to_df()` on it to get data.frames instead.

``` r
result <- fetch_all_metadata("path/to/credentials.json", "program1", "AusDiab")

# Access each node as raw JSON (nested list)
result$subject
result$demographic

# Or get data.frames
dfs <- to_df(result)
dfs$subject         # data.frame
dfs$demographic     # data.frame
```

### List nodes

`get_node_order` returns a topologically sorted character vector of node names from the data dictionary.

``` r
nodes <- get_node_order("path/to/credentials.json")
# [1] "program" "project" "subject" "sample" "demographic" ...
```

### Fetch a single node

If you only need one node, use `Gen3MetadataParser` + `fetch_data`. It returns the raw JSON data as a nested list. Convert to a data.frame yourself if you need one.

``` r
key_file_path <- "path/to/credentials.json"

gen3 <- Gen3MetadataParser(key_file_path)
gen3 <- authenticate(gen3)

data <- fetch_data(gen3,
                   program_name = "program1",
                   project_code = "AusDiab",
                   node_label = "subject")
# data is a list of records

# Convert to a data.frame if desired:
df <- do.call(rbind, lapply(data, as.data.frame))
```
