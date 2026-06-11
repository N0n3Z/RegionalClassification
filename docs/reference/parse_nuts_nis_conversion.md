# Parse the NUTS-NIS conversion file

Parse the NUTS-NIS conversion file

## Usage

``` r
parse_nuts_nis_conversion(conv_dt, reference_date = NULL)
```

## Arguments

- conv_dt:

  data.table from CONVERSION_NIS2019_NUTS2021.xlsx

- reference_date:

  Date to filter validity. NULL = use current (max DT_VLDT_STOP). Use
  as.Date("2018-12-31") for pre-2019 historical NUTS assignments.

## Value

list with NUTS hierarchy and commune-level mapping
