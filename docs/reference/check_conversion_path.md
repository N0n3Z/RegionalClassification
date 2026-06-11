# Check if a simple (direct, unambiguous) conversion is possible

A conversion is "simple" if there exists a path where every edge has a
1:1 or N:1 relationship (no M:N or 1:N that would create ambiguity in
the target values).

## Usage

``` r
check_conversion_path(from, to)
```

## Arguments

- from:

  Source classification identifier.

- to:

  Target classification identifier.

## Value

A named list with the following fields:

- is_simple:

  Logical. `TRUE` if every edge in the path is 1:1 or N:1.

- path:

  Character vector of node identifiers along the shortest path, or
  `NULL` when no path exists.

- relations:

  Character vector of relationship types along the path (e.g. `"1:1"`,
  `"N:1"`).

- explanation:

  Human-readable description of why the path is simple or ambiguous.

- edges_used:

  List of edge objects (from `CONVERSION_GRAPH_EDGES`) for each hop in
  the path.

- perimeter_relations:

  Character vector – one entry per hop – with the perimeter semantic of
  that edge: `"temporal"`, `"identity"`, `"nesting"`, or `"overlap"`.
  Empty for the identity path (`from == to`).

- perimeter_status:

  `"preserving"` if no hop is `"overlap"`, `"crossing"` otherwise.

- straddle_free:

  Logical. `TRUE` when `perimeter_status` is `"preserving"`.

## See also

[`is_perimeter_preserving`](https://n0n3z.github.io/regionalclassification/reference/is_perimeter_preserving.md)
for a simple logical wrapper,
[`print_conversion_check`](https://n0n3z.github.io/regionalclassification/reference/print_conversion_check.md)
for a human-readable summary.

## Examples

``` r
# Simple, perimeter-preserving path
check_conversion_path("NIS_MUNICIPALITY_2019", "NUTS_DISTRICT_2021")
#> $is_simple
#> [1] TRUE
#> 
#> $path
#> [1] "NIS_MUNICIPALITY_2019"  "NUTS_MUNICIPALITY_2021" "NUTS_DISTRICT_2021"    
#> 
#> $relations
#> [1] "1:1" "N:1"
#> 
#> $explanation
#> [1] "Simple conversion possible from 'NIS_MUNICIPALITY_2019' to 'NUTS_DISTRICT_2021'.\nPath: NIS_MUNICIPALITY_2019 -> NUTS_MUNICIPALITY_2021 -> NUTS_DISTRICT_2021\nRelationships: 1:1, N:1"
#> 
#> $edges_used
#> $edges_used[[1]]
#> $edges_used[[1]]$from
#> [1] "NIS_MUNICIPALITY_2019"
#> 
#> $edges_used[[1]]$to
#> [1] "NUTS_MUNICIPALITY_2021"
#> 
#> $edges_used[[1]]$relation
#> [1] "1:1"
#> 
#> $edges_used[[1]]$via
#> [1] "CONVERSION_NIS2019_NUTS2021"
#> 
#> $edges_used[[1]]$notes
#> [1] "Direct 1:1 mapping from CONVERSION file"
#> 
#> 
#> $edges_used[[2]]
#> $edges_used[[2]]$from
#> [1] "NUTS_MUNICIPALITY_2021"
#> 
#> $edges_used[[2]]$to
#> [1] "NUTS_DISTRICT_2021"
#> 
#> $edges_used[[2]]$relation
#> [1] "N:1"
#> 
#> $edges_used[[2]]$via
#> [1] "CONVERSION_NIS2019_NUTS2021"
#> 
#> $edges_used[[2]]$notes
#> [1] "LAU to NUTS3 from CD_LVL_SUP hierarchy"
#> 
#> 
#> 
#> $ambiguous_codes
#> NULL
#> 
#> $coverage
#> NULL
#> 
#> $perimeter_relations
#> [1] "identity" "nesting" 
#> 
#> $perimeter_status
#> [1] "preserving"
#> 
#> $straddle_free
#> [1] TRUE
#> 

# Ambiguous path (Verviers splits two NUTS3 regions)
check_conversion_path("NIS_DISTRICT_2019", "NUTS_DISTRICT_2021")
#> $is_simple
#> [1] FALSE
#> 
#> $path
#> [1] "NIS_DISTRICT_2019"  "NUTS_DISTRICT_2021"
#> 
#> $relations
#> [1] "1:N"
#> 
#> $explanation
#> [1] "Conversion from 'NIS_DISTRICT_2019' to 'NUTS_DISTRICT_2021' is NOT simple (has ambiguous steps).\nPath: NIS_DISTRICT_2019 -> NUTS_DISTRICT_2021\nRelationships: 1:N\nProblematic step(s):\n  - NIS_DISTRICT_2019 -> NUTS_DISTRICT_2021: relationship is 1:N\n    Verviers (63000) maps to BE335 (francophone) AND BE336 (germanophone). All other arrondissements are 1:1.  Overall: 1:N (not M:N). Reverse NUTS3->arrondissement is N:1 (simple)."
#> 
#> $edges_used
#> $edges_used[[1]]
#> $edges_used[[1]]$from
#> [1] "NIS_DISTRICT_2019"
#> 
#> $edges_used[[1]]$to
#> [1] "NUTS_DISTRICT_2021"
#> 
#> $edges_used[[1]]$relation
#> [1] "1:N"
#> 
#> $edges_used[[1]]$via
#> [1] "CONVERSION_NIS2019_NUTS2021"
#> 
#> $edges_used[[1]]$notes
#> [1] "Verviers (63000) maps to BE335 (francophone) AND BE336 (germanophone). All other arrondissements are 1:1.  Overall: 1:N (not M:N). Reverse NUTS3->arrondissement is N:1 (simple)."
#> 
#> 
#> 
#> $ambiguous_codes
#> NULL
#> 
#> $coverage
#> NULL
#> 
#> $perimeter_relations
#> [1] "overlap"
#> 
#> $perimeter_status
#> [1] "crossing"
#> 
#> $straddle_free
#> [1] FALSE
#> 

# Multi-hop path via intermediate classification
check_conversion_path("POSTAL", "NUTS_DISTRICT_2027")
#> $is_simple
#> [1] TRUE
#> 
#> $path
#> [1] "POSTAL"             "NUTS_DISTRICT_2027"
#> 
#> $relations
#> [1] "N:1"
#> 
#> $explanation
#> [1] "Simple conversion possible from 'POSTAL' to 'NUTS_DISTRICT_2027'.\nPath: POSTAL -> NUTS_DISTRICT_2027\nRelationships: N:1"
#> 
#> $edges_used
#> $edges_used[[1]]
#> $edges_used[[1]]$from
#> [1] "POSTAL"
#> 
#> $edges_used[[1]]$to
#> [1] "NUTS_DISTRICT_2027"
#> 
#> $edges_used[[1]]$relation
#> [1] "N:1"
#> 
#> $edges_used[[1]]$via
#> [1] "derived"
#> 
#> $edges_used[[1]]$notes
#> [1] "Via POSTAL -> NIS_MUNICIPALITY_2019 -> NIS_MUNICIPALITY_2025 -> NUTS_DISTRICT_2027"
#> 
#> 
#> 
#> $ambiguous_codes
#> NULL
#> 
#> $coverage
#> NULL
#> 
#> $perimeter_relations
#> [1] "nesting"
#> 
#> $perimeter_status
#> [1] "preserving"
#> 
#> $straddle_free
#> [1] TRUE
#> 
```
