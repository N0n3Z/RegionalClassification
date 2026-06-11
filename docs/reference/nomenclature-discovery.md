# Levels / versions available for a system

Levels / versions available for a system

## Usage

``` r
nomenclature_levels(system)

nomenclature_versions(system)
```

## Arguments

- system:

  Classification system ("NIS", "NUTS", "POSTAL", "NBB").

## Value

A character vector (`nomenclature_versions` may contain `NA` for
unversioned systems).

## Examples

``` r
nomenclature_levels("NIS")
#> [1] "municipality" "district"     "province"     "region"       "country"     
nomenclature_versions("NUTS")
#> [1] "2021" NA     "2027"
```
