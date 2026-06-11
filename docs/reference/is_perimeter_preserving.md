# Test whether a conversion path is perimeter-preserving

A conversion is perimeter-preserving when no edge along the (shortest)
path has a \`1:N\` or \`M:N\` cardinality in the forward direction –
i.e. no source unit straddles two or more target units. Cardinality
takes precedence over temporal classification: a backward temporal edge
(e.g. 2025 -\> 2019) has \`1:N\` cardinality and is therefore NOT
perimeter-preserving.

## Usage

``` r
is_perimeter_preserving(from, to)
```

## Arguments

- from:

  Source classification identifier.

- to:

  Target classification identifier.

## Value

\`TRUE\` if all edges in the path are perimeter-preserving, \`FALSE\` if
any edge is an overlap (1:N / M:N), and \`NA\` if no conversion path
exists.

## Details

Typical results:

- `NIS_MUNICIPALITY_2019 -> NUTS_DISTRICT_2021`: \`TRUE\` (N:1, nesting)

- `NIS_MUNICIPALITY_2025 -> NUTS_DISTRICT_2021`: \`FALSE\` (1:N, fused
  communes straddle NUTS3 boundaries)

- `NIS_MUNICIPALITY_2019 -> NIS_MUNICIPALITY_2025`: \`TRUE\` (forward
  temporal, N:1)

- `NIS_MUNICIPALITY_2025 -> NIS_MUNICIPALITY_2019`: \`FALSE\` (backward
  temporal, 1:N)

## Examples

``` r
is_perimeter_preserving("NIS_MUNICIPALITY_2019", "NUTS_DISTRICT_2021")   # TRUE
#> [1] TRUE
is_perimeter_preserving("NIS_MUNICIPALITY_2025", "NUTS_DISTRICT_2021")   # FALSE
#> [1] FALSE
```
