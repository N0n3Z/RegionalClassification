# Complete regions dataset – NIS 2019

One row per Belgian region in the NIS 2019 classification (3 regions:
Flemish, Walloon, Brussels-Capital), with fictional socio-economic
indicators.

## Usage

``` r
rc_full_regions_2019
```

## Format

A \`data.table\` with 3 rows and 5 columns:

- cd_region:

  Integer. NIS 2019 region code (2000, 3000, 4000).

- population:

  Integer. Resident population (fictional, 500 000–3 700 000).

- emplois:

  Integer. Number of jobs (fictional).

- masse_sal:

  Numeric. Total wage bill in EUR (fictional).

- taux_activite:

  Numeric. Activity rate, 0–1 (fictional).

## Examples

``` r
data(rc_full_regions_2019)
rc_full_regions_2019
#>    cd_region population emplois   masse_sal taux_activite
#>       <char>      <int>   <int>       <num>         <num>
#> 1:      2000     557508  208591 11707572296         0.654
#> 2:      3000    2352116 1194141 75056847935         0.563
#> 3:      4000    2501850 1305505 62397209811         0.796
```
