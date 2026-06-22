# Auto-detect geographic classification from a vector of codes

Matches the supplied codes against known reference sets from master_data
and returns the classification with the highest match rate (\>= 80%).
Returns NULL when no confident match is found.

## Usage

``` r
detect_classification(codes, master_data)
```

## Arguments

- codes:

  Vector of codes (character or integer/numeric)

- master_data:

  Output from build_master_table()

## Value

Character classification identifier, or NULL if no confident match.

## Examples

``` r
# \donttest{
  master_data <- load_master_data()
#> Master data loaded from 'C:/Users/Dell/AppData/Local/Temp/RtmpQNI466/temp_libpath2a8447f11d6b/nbbbenuts/extdata': 581 communes NIS 2019, 565 NIS 2025, 589 NIS BEFORE_2019
  detect_classification(c(21004L, 11002L, 62063L), master_data)  # "NIS_MUNICIPALITY_2019"
#> [1] "NIS_MUNICIPALITY_2019"
  detect_classification(c("BE100", "BE211"),        master_data)  # "NUTS_DISTRICT_2021"
#> [1] "NUTS_DISTRICT_2021"
  detect_classification(c(1000L, 2000L),            master_data)  # "POSTAL"
#> [1] "POSTAL"
# }
```
