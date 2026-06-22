# Validate codes against a known classification

Checks whether each code in the input vector belongs to the set of known
codes for the specified classification. Useful for catching data quality
issues before a conversion.

## Usage

``` r
validate_codes(codes, classification, master_data)
```

## Arguments

- codes:

  Vector of codes to validate (coerced to character).

- classification:

  Canonical classification identifier (see
  \[classification_reference\]).

- master_data:

  Output from \[load_master_data()\].

## Value

A \`data.table\` with columns:

- code:

  Input code (character).

- is_valid:

  \`TRUE\` if the code exists in the reference set.

## Examples

``` r
# \donttest{
  master_data <- load_master_data()
#> Master data loaded from 'C:/Users/Dell/AppData/Local/Temp/Rtmp6rbXw4/temp_libpath26b420df5361/nbbbenuts/extdata': 581 communes NIS 2019, 565 NIS 2025, 589 NIS BEFORE_2019
  validate_codes(c(21004L, 99999L, 11002L), "NIS_MUNICIPALITY_2019", master_data)
#>      code is_valid
#>    <char>   <lgcl>
#> 1:  21004     TRUE
#> 2:  99999    FALSE
#> 3:  11002     TRUE
# }
```
