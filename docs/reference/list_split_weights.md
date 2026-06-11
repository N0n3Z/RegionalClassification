# List all registered split weights

List all registered split weights

## Usage

``` r
list_split_weights()
```

## Value

data.table with columns (from, to, variable), or invisible NULL when
empty

## Examples

``` r
# \donttest{
  list_split_weights()  # returns NULL or data.table of registered weights
#>                 from                 to   variable
#>               <char>             <char>     <char>
#> 1: NIS_DISTRICT_2019 NUTS_DISTRICT_2021 population
# }
```
