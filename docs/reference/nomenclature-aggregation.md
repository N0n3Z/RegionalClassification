# Aggregation links between nomenclatures

`nomenclature_children()` returns the finer level(s) a nomenclature is
the direct aggregation of (e.g. a district aggregates municipalities).
`nomenclature_parents()` returns the coarser level(s) that aggregate it
(e.g. a municipality is aggregated by a district; a district is
aggregated by BOTH a province and a region).

## Usage

``` r
nomenclature_children(x)

nomenclature_parents(x)
```

## Arguments

- x:

  A `nomenclature` object (or a valid identifier).

## Value

A list of `nomenclature` objects (possibly empty).

## Details

The aggregation structure is a DAG, not a tree: a NIS district has two
parents (province and region), and `NUTS_COUNTRY` aggregates both the
2021 and 2027 NUTS region levels. Province -\> region is deliberately
not an aggregation (province 20000 "Brabant" spans three regions).

## Examples

``` r
nomenclature_children(nomenclature("NIS", "district", "2019"))  # municipality
#> [[1]]
#> <nomenclature: NIS / municipality / 2019>
#> 
nomenclature_parents(nomenclature("NIS", "district", "2019"))   # province + region
#> [[1]]
#> <nomenclature: NIS / province / 2019>
#> 
#> [[2]]
#> <nomenclature: NIS / region / 2019>
#> 
```
