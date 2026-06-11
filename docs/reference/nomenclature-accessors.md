# Nomenclature components

Extract the system, level or version of a `nomenclature`.

## Usage

``` r
nom_system(x)

nom_level(x)

nom_version(x)
```

## Arguments

- x:

  A `nomenclature` object.

## Value

A length-one character vector (`nom_version` returns `NA_character_` for
unversioned systems).

## Examples

``` r
n <- nomenclature("NIS", "municipality", "2019")
nom_system(n)
#> [1] "NIS"
nom_level(n)
#> [1] "municipality"
nom_version(n)
#> [1] "2019"
```
