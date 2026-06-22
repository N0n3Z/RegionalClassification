# Get official names for classification codes

Returns the French or Dutch official label for each code.
Classifications without a name in the master data (NUTS2/NUTS1 levels
and NUTS 2027) return \`NA\`.

## Usage

``` r
get_label(codes, classification, master_data, lang = c("fr", "nl"))
```

## Arguments

- codes:

  Vector of codes (coerced to character).

- classification:

  Canonical classification identifier (see
  \[classification_reference\]).

- master_data:

  Output from \[load_master_data()\].

- lang:

  \`"fr"\` (default) or \`"nl"\`.

## Value

A \`data.table\` with columns:

- code:

  Input code (character).

- label:

  Official name, or \`NA\` if unavailable.

## Examples

``` r
# \donttest{
  master_data <- load_master_data()
#> Master data loaded from 'C:/Users/Dell/AppData/Local/Temp/Rtmp6rbXw4/temp_libpath26b420df5361/nbbbenuts/extdata': 581 communes NIS 2019, 565 NIS 2025, 589 NIS BEFORE_2019
  get_label(c(21004L, 11002L), "NIS_MUNICIPALITY_2019", master_data)
#>      code     label
#>    <char>    <char>
#> 1:  21004 Bruxelles
#> 2:  11002    Anvers
  get_label(c("BE100", "BE211"), "NUTS_DISTRICT_2021", master_data, lang = "nl")
#>      code                            label
#>    <char>                           <char>
#> 1:  BE100 Arrondissement Brussel-Hoofdstad
#> 2:  BE211         Arrondissement Antwerpen
# }
```
