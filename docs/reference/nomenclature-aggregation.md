# Aggregation links between nomenclatures

`nomenclature_children()` returns the finer level(s) a nomenclature is
the direct aggregation of (e.g. a district aggregates municipalities; a
region aggregates provinces). `nomenclature_parents()` returns the
coarser level(s) that aggregate it (e.g. a municipality is aggregated by
a district; a district by a province; a province by a region).

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

NIS levels form a strict hierarchy
`region -> province -> arrondissement -> municipality`: every NIS
province nests in exactly one region since the 1995 Brabant split
(Brussels is modelled as a pseudo-province). The structure is still a
DAG, not a tree: `NUTS_COUNTRY` aggregates both the 2021 and 2027 NUTS
region levels, and `NIS_COUNTRY` aggregates all three NIS region
versions.

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
```
