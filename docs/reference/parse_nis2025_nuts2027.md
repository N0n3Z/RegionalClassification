# Parse NIS 2025 -\> NUTS 2027 conversion file

Called only when CONVERSION_NIS2025_NUTS2027.xlsx is present in
data/raw/. Column names are configured in
FILE_MAPPING\$CONVERSION_NIS2025_NUTS2027.

## Usage

``` r
parse_nis2025_nuts2027(
  conv_dt,
  col_nis = FILE_MAPPING$CONVERSION_NIS2025_NUTS2027$col_nis,
  col_nuts3 = FILE_MAPPING$CONVERSION_NIS2025_NUTS2027$col_nuts3
)
```

## Arguments

- conv_dt:

  data.table from CONVERSION_NIS2025_NUTS2027.xlsx

- col_nis:

  Name of the NIS 2025 commune code column

- col_nuts3:

  Name of the NUTS3 2027 code column

## Value

data.table with columns cd_commune_2025 (integer) and cd_nuts3_2027
(character)
