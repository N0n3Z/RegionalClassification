# Resolve the directory containing the pre-built RDS files

Tries system.file() first (installed package or devtools::load_all()),
then falls back to inst/extdata/ relative to the project root for the
source("main.R") workflow.

## Usage

``` r
.get_prebuilt_dir()
```

## Value

Character path to the extdata directory
