# Retrieve registered split weights

Retrieve registered split weights

## Usage

``` r
get_split_weights(from, to, variable = "population")
```

## Arguments

- from:

  Source classification

- to:

  Target classification

- variable:

  Weighting variable name (default: "population")

## Value

data.table(code_from, code_to, weight) or NULL if not registered

## Examples

``` r
# \donttest{
  library(data.table)
#> 
#> Attaching package: 'data.table'
#> The following object is masked from 'package:base':
#> 
#>     %notin%
  register_split_weights(
    "NIS_DISTRICT_2019", "NUTS_DISTRICT_2021",
    data.table(code_from = c(63000L, 63000L),
               code_to   = c("BE335", "BE336"),
               weight    = c(0.857, 0.143))
  )
#>   Registered split weights: NIS_DISTRICT_2019 -> NUTS_DISTRICT_2021 [variable: population, 2 entries]
  get_split_weights("NIS_DISTRICT_2019", "NUTS_DISTRICT_2021")
#>    code_from code_to weight
#>        <int>  <char>  <num>
#> 1:     63000   BE335  0.857
#> 2:     63000   BE336  0.143
# }
```
