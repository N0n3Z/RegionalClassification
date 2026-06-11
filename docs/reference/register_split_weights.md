# Register split weights for an ambiguous conversion

Stores a weighting table in the session registry for use by
split_ambiguous(). Multiple variables (population, employment, etc.) can
be registered for the same conversion pair.

## Usage

``` r
register_split_weights(from, to, weights_dt, variable = "population")
```

## Arguments

- from:

  Source classification

- to:

  Target classification

- weights_dt:

  data.table with columns: code_from, code_to, weight

- variable:

  Name of the weighting variable (default: "population")

## Value

Invisible NULL (called for side effect)

## Examples

``` r
# \donttest{
  # Register population-based Verviers split (indicative values)
  register_split_weights(
    from       = "NIS_DISTRICT_2019",
    to         = "NUTS_DISTRICT_2021",
    weights_dt = data.table::data.table(
      code_from = c(63000L, 63000L),
      code_to   = c("BE335", "BE336"),
      weight    = c(0.857, 0.143)
    ),
    variable   = "population"
  )
#>   Registered split weights: NIS_DISTRICT_2019 -> NUTS_DISTRICT_2021 [variable: population, 2 entries]
# }
```
