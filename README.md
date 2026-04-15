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

### Filtering by data release

`fetch_all_metadata` accepts a `data_release` argument that filters each node's records by release. The **default is `"latest"`** — each node is inspected for a `data_release_date` field and only records matching the max ISO date are returned. The selected version and date are logged per node.

```python
# Default: per node, keep records with the max data_release_date
result = fetch_all_metadata(key_file, "program1", "project1")
# node 'subject': selected data_release_date=2024-06-01 data_release='v2.3' (123/22494 records)
# node 'demographic': selected data_release_date=2024-06-01 data_release='v2.3' (123/22494 records)
# ...

# Pin to a specific release (exact, case-sensitive match on data_release field)
result = fetch_all_metadata(key_file, "program1", "project1", data_release="v2.3")

# Disable filtering — return every record, no filter logs
result = fetch_all_metadata(key_file, "program1", "project1", data_release=None)
```

Behavior per node:

| `data_release` value | Behavior                                                                                                     |
| -------------------- | ------------------------------------------------------------------------------------------------------------ |
| `"latest"` (default) | Keep records with the max `data_release_date` (ISO 8601). Log the selected date and version.                |
| any other string     | Keep records where `data_release` equals that string exactly. Log the selected version and date.            |
| `None`               | No filtering. No filter log lines emitted.                                                                  |

Nodes that have neither a `data_release` nor a `data_release_date` field (for example lookup/link nodes like `program` or `project`) are passed through unchanged, with an info log noting they were not filtered. Unparseable ISO dates in `"latest"` mode are skipped with a warning.

The same `data_release` argument is also available on `Gen3MetadataParser.fetch_data` and `fetch_data_json` for single-node fetches.

### Logging and error handling

`fetch_all_metadata` prints per-node progress to stdout by default (`verbose=True`). If you want richer diagnostic output — filter decisions, authentication steps, `debug` messages — call `configure_logging()` once in your REPL or notebook to attach a stderr handler to the `gen3_metadata` logger:

```python
import logging
import gen3_metadata

gen3_metadata.configure_logging()              # INFO by default
# gen3_metadata.configure_logging(logging.DEBUG)  # or more verbose
```

Each module logs under its own `gen3_metadata.<module>` name, so you can filter with standard `logging` machinery.

Network calls inside `fetch_all_metadata` are timeout-guarded (30s per request) and wrapped with friendly error messages. A VPN/connectivity failure produces a clean one-liner instead of a urllib3 traceback:

```
fetch_all_metadata: starting for program1/CDAH
fetch_all_metadata: fetching data dictionary from cad.staging.biocommons.org.au...
RuntimeError: Could not reach cad.staging.biocommons.org.au to fetch the Gen3
data dictionary. Check VPN / network connectivity. Underlying error: ...
```

Individual nodes that time out or return an HTTP error during the fetch loop are logged and skipped; the overall call completes with a final summary of which nodes succeeded and which failed.

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

# Default: filters to latest data_release_date
json_data = parser.fetch_data_json("program1", "project1", node_label="medical_history")
json_data  # {'data': [...]}

# Pin to a specific release, or pass data_release=None to disable filtering
json_data = parser.fetch_data_json(
    "program1", "project1", node_label="medical_history", data_release="v2.3"
)

# Convert to DataFrame if desired:
df = pd.json_normalize(json_data["data"])
```

### Running Tests

```bash
pytest -vv tests/
```

---

## R

As of **v1.3.0** the R package is fully standalone — no Python interpreter, no `reticulate`, and no Python `gen3_metadata` package required. A single `devtools::install_github(...)` is all you need, which makes containerized RStudio deployments significantly simpler.

### Installation

Always-latest from `main`:

``` r
if (!require("devtools")) install.packages("devtools")
devtools::install_github("AustralianBioCommons/gen3-metadata", subdir = "gen3metadata-R")
```

Pinned to a specific release (recommended for reproducible environments such as Docker images):

``` r
if (!require("devtools")) install.packages("devtools")
devtools::install_github(
    "AustralianBioCommons/gen3-metadata",
    subdir = "gen3metadata-R",
    ref    = "v1.4.0"
)
```

CRAN dependencies are installed automatically with the package. If your environment requires installing them manually:

``` r
install.packages(c("httr", "jsonlite", "jose", "glue"))
```

#### In a Dockerfile (RStudio container)

Add a single layer to your image:

``` dockerfile
RUN R -e 'if (!require("devtools")) install.packages("devtools", repos="https://cloud.r-project.org"); \
          devtools::install_github("AustralianBioCommons/gen3-metadata", subdir = "gen3metadata-R", ref = "v1.4.0")'
```

No Python or `pip` step is required.

### Loading

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

### Filtering by data release

`fetch_all_metadata` accepts a `data_release` argument that mirrors the Python API. The **default is `"latest"`** — each node is inspected for a `data_release_date` field and only records matching the max ISO date are kept. The selected version and date are emitted per node via `message()`.

``` r
# Default: per node, keep records with the max data_release_date
result <- fetch_all_metadata("path/to/credentials.json", "program1", "AusDiab")
# node 'subject': selected data_release_date=2024-06-01 data_release='v2.3' (123/22494 records)
# node 'demographic': selected data_release_date=2024-06-01 data_release='v2.3' (123/22494 records)
# ...

# Pin to a specific release (exact, case-sensitive match on data_release field)
result <- fetch_all_metadata(
    "path/to/credentials.json", "program1", "AusDiab",
    data_release = "v2.3"
)

# Disable filtering — return every record, no filter messages
result <- fetch_all_metadata(
    "path/to/credentials.json", "program1", "AusDiab",
    data_release = NULL
)

# Suppress the per-node message output while keeping the filter active
result <- suppressMessages(
    fetch_all_metadata("path/to/credentials.json", "program1", "AusDiab")
)
```

Behavior per node:

| `data_release` value | Behavior                                                                                          |
| -------------------- | ------------------------------------------------------------------------------------------------- |
| `"latest"` (default) | Keep records with the max `data_release_date` (ISO 8601). Emit selected date and version.       |
| any other string     | Keep records where `data_release` equals that string exactly. Emit selected version and date.   |
| `NULL`               | No filtering. No filter messages emitted.                                                        |

Nodes that have neither a `data_release` nor a `data_release_date` field are passed through unchanged with a message. Unparseable ISO dates in `"latest"` mode are skipped with a warning.

The same `data_release` argument is also available on `fetch_data()` for single-node fetches.

### Progress messages and error handling

`fetch_all_metadata` emits per-node progress via `message()` (visible in interactive sessions and captured by knitr/RMarkdown by default). A DNS/VPN failure produces a clean `stop()` error rather than an `httr` traceback, e.g.:

```
fetch_all_metadata: starting for program1/AusDiab
fetch_all_metadata: fetching data dictionary...
Error: Could not fetch Gen3 data dictionary. Check VPN / network connectivity. Underlying error: ...
```

All network calls (authentication, dictionary fetch, per-node fetch) have a 30-second timeout, so a flaky network surfaces quickly instead of hanging indefinitely. To silence the progress output:

``` r
result <- suppressMessages(fetch_all_metadata(...))
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

# Default: filters to latest data_release_date
data <- fetch_data(gen3,
                   program_name = "program1",
                   project_code = "AusDiab",
                   node_label = "subject")

# Pin to a specific release, or pass data_release = NULL to disable filtering
data <- fetch_data(gen3,
                   program_name = "program1",
                   project_code = "AusDiab",
                   node_label = "subject",
                   data_release = "v2.3")

# data is a list of records

# Convert to a data.frame if desired:
df <- do.call(rbind, lapply(data, as.data.frame))
```
