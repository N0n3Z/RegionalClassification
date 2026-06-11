# Create a classification nomenclature object

Builds a structured handle for a classification, identified by its
`system` (NIS, NUTS, POSTAL, NBB), `level` (municipality, district,
province, region, country, postal) and `version` (e.g. "2019", "2025",
"BEFORE_2019", "2021", "2027"). The triplet must resolve to exactly one
known classification.

## Usage

``` r
nomenclature(system, level = NULL, version = NULL)
```

## Arguments

- system:

  Classification system: "NIS", "NUTS", "POSTAL", "NBB"
  (case-insensitive). Passing an existing `nomenclature` returns it
  unchanged.

- level:

  Granularity within the system (case-insensitive), or `NULL`.

- version:

  Version string or number, or `NULL` for unversioned systems.

## Value

An object of class `nomenclature`.

## Details

`level` and/or `version` may be omitted when the remaining components
are unambiguous (e.g. `nomenclature("POSTAL")`,
`nomenclature("NUTS", "country")`).

This object is the recommended way to work programmatically (loop over
versions/levels) and to navigate aggregation links
([`nomenclature_children`](https://n0n3z.github.io/regionalclassification/reference/nomenclature-aggregation.md),
[`nomenclature_parents`](https://n0n3z.github.io/regionalclassification/reference/nomenclature-aggregation.md)).
Plain string identifiers (e.g. `"NIS_MUNICIPALITY_2019"`) remain
accepted by all functions.

## Examples

``` r
nomenclature("NIS", "municipality", "2019")
#> <nomenclature: NIS / municipality / 2019>
nomenclature("NUTS", "district", 2021)
#> <nomenclature: NUTS / district / 2021>
nomenclature("POSTAL")
#> <nomenclature: POSTAL / postal>
# Dynamic construction:
lapply(c("2019", "2025"), function(v) nomenclature("NIS", "municipality", v))
#> [[1]]
#> <nomenclature: NIS / municipality / 2019>
#> 
#> [[2]]
#> <nomenclature: NIS / municipality / 2025>
#> 
```
