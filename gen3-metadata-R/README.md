<h1 align="center">
gen3metadata R tool
</h1>

<p align="center">
<i>User friendly tools for downloading and manipulating gen3 metadata</i>
</p>

<div align="center">

<a href="https://www.r-project.org/"><img src="https://img.shields.io/badge/r-%23276DC3.svg?style=for-the-badge&amp;logo=r&amp;logoColor=white" alt="R"/></a>
<a href="https://www.biocommons.org.au/"><img src="https://img.shields.io/badge/Australian BioCommons-%23276DC3?style=for-the-badge" alt="Australian BioCommons"/></a>
<a href="https://www.baker.edu.au/"><img src="https://img.shields.io/badge/Baker Institute-%23276DC3?style=for-the-badge" alt="Baker Institute"/></a>
<br>

<p align="center">
<i>Love our work? Visit our <a href="https://metabolomics.baker.edu.au/">WebPortal</a>.</i>
</p>

</div>


## Installation

You can install the gen3metadata R tool from
[GitHub](https://github.com/) with:

``` r
if (!require("devtools")) install.packages("devtools")
devtools::install_github("AustralianBioCommons/gen3-metadata", subdir = "gen3metadata-R", ref = "feature/R-package")
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

## Example

This is a basic example to authenticate and load some data.
You will need a credential file (stored in `key_file_path` in this example).

``` r
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
