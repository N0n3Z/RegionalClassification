# Print a human-readable conversion path check

Print a human-readable conversion path check

## Usage

``` r
print_conversion_check(from, to)
```

## Arguments

- from:

  Source classification

- to:

  Target classification

## Value

Invisible path check result (prints to console)

## Examples

``` r
print_conversion_check("NIS_MUNICIPALITY_2019", "NUTS_DISTRICT_2021")
#> === Conversion Path Check ===
#> From: NIS_MUNICIPALITY_2019
#> To:   NUTS_DISTRICT_2021
#> Simple conversion: YES
#> Perimeter-preserving: YES
#> Perimeter relations: identity -> nesting
#> 
#> Simple conversion possible from 'NIS_MUNICIPALITY_2019' to 'NUTS_DISTRICT_2021'.
#> Path: NIS_MUNICIPALITY_2019 -> NUTS_MUNICIPALITY_2021 -> NUTS_DISTRICT_2021
#> Relationships: 1:1, N:1
print_conversion_check("NIS_DISTRICT_2019", "NUTS_DISTRICT_2021")
#> === Conversion Path Check ===
#> From: NIS_DISTRICT_2019
#> To:   NUTS_DISTRICT_2021
#> Simple conversion: NO
#> Perimeter-preserving: NO (straddle)
#> Perimeter relations: overlap
#> 
#> Conversion from 'NIS_DISTRICT_2019' to 'NUTS_DISTRICT_2021' is NOT simple (has ambiguous steps).
#> Path: NIS_DISTRICT_2019 -> NUTS_DISTRICT_2021
#> Relationships: 1:N
#> Problematic step(s):
#>   - NIS_DISTRICT_2019 -> NUTS_DISTRICT_2021: relationship is 1:N
#>     Verviers (63000) maps to BE335 (francophone) AND BE336 (germanophone). All other arrondissements are 1:1.  Overall: 1:N (not M:N). Reverse NUTS3->arrondissement is N:1 (simple).
print_conversion_check("POSTAL", "NUTS_DISTRICT_2027")
#> === Conversion Path Check ===
#> From: POSTAL
#> To:   NUTS_DISTRICT_2027
#> Simple conversion: YES
#> Perimeter-preserving: YES
#> Perimeter relations: nesting
#> 
#> Simple conversion possible from 'POSTAL' to 'NUTS_DISTRICT_2027'.
#> Path: POSTAL -> NUTS_DISTRICT_2027
#> Relationships: N:1
```
