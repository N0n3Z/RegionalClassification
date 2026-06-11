# Convert codes from one classification to another

This is the main conversion function. It automatically determines the
conversion path and applies the necessary transformations.

## Usage

``` r
convert_codes(codes, from, to, master_data, allow_ambiguous = FALSE)
```

## Arguments

- codes:

  Vector of codes to convert

- from:

  Source classification (e.g., "NIS_MUNICIPALITY_2019", "POSTAL",
  "NUTS_DISTRICT_2021")

- to:

  Target classification (e.g., "NUTS_DISTRICT_2021",
  "NIS_MUNICIPALITY_2025")

- master_data:

  Output from build_master_table()

- allow_ambiguous:

  Logical. If FALSE (default), raises error on M:N conversions. If TRUE,
  returns all possible mappings.

## Value

data.table with columns `code_from`, `code_to`, `nature`. `nature` is
`NA` for most conversions; for NIS temporal conversions (2019
\\\leftrightarrow\\ 2025 / BEFORE_2019 \\\to\\ 2019) it carries the
change reason: `"UNCHANGED"`, `"FUSION"`, `"CHANGE_DSTR"`, or
`"CHANGE_PROV"`.

## Examples

``` r
# \donttest{
  master_data <- load_master_data()
#> Master data loaded from 'C:/Users/Dell/AppData/Local/Temp/RtmpYb6NDx/temp_libpath1f90279e2a23/nbbbenuts/extdata': 583 communes NIS 2019, 567 NIS 2025, 589 NIS BEFORE_2019

  # NIS communes -> NUTS3 2021
  convert_codes(c(21004L, 11002L, 62063L),
                "NIS_MUNICIPALITY_2019", "NUTS_DISTRICT_2021", master_data)
#>    code_from code_to nature
#>        <int>  <char> <char>
#> 1:     11002   BE211 RECODE
#> 2:     21004   BE100 RECODE
#> 3:     62063   BE332 RECODE

  # Postal codes -> NIS communes
  convert_codes(c(1000L, 2000L, 4000L), "POSTAL", "NIS_MUNICIPALITY_2019", master_data)
#>    code_from code_to nature
#>        <int>   <int> <char>
#> 1:      1000   21004 RECODE
#> 2:      2000   11002 RECODE
#> 3:      4000   62063 RECODE

  # NIS communes -> NUTS3 2027
  convert_codes(c(21004L, 11002L), "NIS_MUNICIPALITY_2019", "NUTS_DISTRICT_2027", master_data)
#>    code_from code_to nature
#>        <int>  <char> <char>
#> 1:     21004   BE100   <NA>
#> 2:     11002   BE261   <NA>

  # Ambiguous conversion (Verviers arrondissement spans two NUTS3 regions)
  convert_codes(63000L, "NIS_DISTRICT_2019", "NUTS_DISTRICT_2021",
                master_data, allow_ambiguous = TRUE)
#>    code_from code_to  nature
#>        <int>  <char>  <char>
#> 1:     63000   BE335 OVERLAP
#> 2:     63000   BE336 OVERLAP
# }
```
