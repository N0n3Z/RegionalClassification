# Extract and standardise a postal code mapping table (internal)

Uses pattern-matching to find the four needed columns, with explicit
error messages if a column cannot be found.

## Usage

``` r
.extract_postal_map(dt, label = "postal file")
```

## Arguments

- dt:

  data.table from a postal conversion file

- label:

  File name used in error messages

## Value

data.table(cd_postal, cd_commune_nis, tx_postal_name_fr,
tx_postal_name_nl)
