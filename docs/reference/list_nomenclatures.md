# List available nomenclatures

List available nomenclatures

## Usage

``` r
list_nomenclatures(system = NULL)
```

## Arguments

- system:

  Optional system filter ("NIS", "NUTS", "POSTAL", "NBB").

## Value

A list of `nomenclature` objects.

## Examples

``` r
list_nomenclatures("NIS")
#> [[1]]
#> <nomenclature: NIS / municipality / BEFORE_2019>
#> 
#> [[2]]
#> <nomenclature: NIS / district / BEFORE_2019>
#> 
#> [[3]]
#> <nomenclature: NIS / province / BEFORE_2019>
#> 
#> [[4]]
#> <nomenclature: NIS / region / BEFORE_2019>
#> 
#> [[5]]
#> <nomenclature: NIS / municipality / 2019>
#> 
#> [[6]]
#> <nomenclature: NIS / district / 2019>
#> 
#> [[7]]
#> <nomenclature: NIS / province / 2019>
#> 
#> [[8]]
#> <nomenclature: NIS / region / 2019>
#> 
#> [[9]]
#> <nomenclature: NIS / municipality / 2025>
#> 
#> [[10]]
#> <nomenclature: NIS / district / 2025>
#> 
#> [[11]]
#> <nomenclature: NIS / province / 2025>
#> 
#> [[12]]
#> <nomenclature: NIS / region / 2025>
#> 
#> [[13]]
#> <nomenclature: NIS / country>
#> 
```
