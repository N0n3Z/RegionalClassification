# Complete communes dataset – NIS 2019

One row per Belgian commune in the NIS 2019 classification (583
communes), with fictional but realistically-scaled socio-economic
indicators. Designed for full-coverage conversion demonstrations and
benchmark testing.

## Usage

``` r
rc_full_municipalities_2019
```

## Format

A \`data.table\` with 583 rows and 5 columns:

- cd_commune:

  Integer. NIS 2019 commune code.

- population:

  Integer. Resident population (fictional, 200–180 000).

- emplois:

  Integer. Number of jobs (fictional, ~35–55 % of population).

- masse_sal:

  Numeric. Total wage bill in EUR (fictional).

- taux_activite:

  Numeric. Activity rate, 0–1 (fictional).

## See also

\[rc_full_municipalities_2025\], \[rc_dirty_municipalities_2019\],
\[diagnose_classification()\], \[convert_dataset()\]

## Examples

``` r
data(rc_full_municipalities_2019)
head(rc_full_municipalities_2019)
#>    cd_commune population emplois  masse_sal taux_activite
#>        <char>      <int>   <int>      <num>         <num>
#> 1:      11001     164682   78897 3202138594         0.614
#> 2:      11002     168686   66067 3893919499         0.591
#> 3:      11004      51647   23040 1405231639         0.732
#> 4:      11005     149514   81829 3580943310         0.602
#> 5:      11007     115585   63412 2197351336         0.697
#> 6:      11008      93533   41168 2583379279         0.778

# \donttest{
  master_data <- load_master_data()
#> Master data loaded from 'C:/Users/Dell/AppData/Local/Temp/RtmpMFZPCn/temp_libpath168c5fac3201/nbbbenuts/extdata': 581 communes NIS 2019, 565 NIS 2025, 589 NIS BEFORE_2019
  convert_dataset(rc_full_municipalities_2019, "cd_commune",
                  from = "NIS_MUNICIPALITY_2019",
                  to   = "NUTS_DISTRICT_2021", master_data)
#> === Conversion Path Check ===
#> From: NIS_MUNICIPALITY_2019
#> To:   NUTS_DISTRICT_2021
#> Simple conversion: YES
#> Perimeter-preserving: YES
#> Perimeter relations: identity -> nesting
#> 
#> Simple conversion possible from 'NIS_MUNICIPALITY_2019' to 'NUTS_DISTRICT_2021'.
#> Path: NIS_MUNICIPALITY_2019 -> NUTS_MUNICIPALITY_2021 -> NUTS_DISTRICT_2021
#> Relationships: 1:1, N:1
#> Warning: 2 code(s) could not be converted (no match found)
#> Warning: 2 code(s) in 'cd_commune' could not be converted to 'NUTS_DISTRICT_2021' (no match).
#>   -> Column 'cd_nuts3_2021' added: 581 converted, 2 NA.
#>      cd_commune cd_nuts3_2021 population emplois  masse_sal taux_activite
#>          <char>        <char>      <int>   <int>      <num>         <num>
#>   1:      11001         BE211     164682   78897 3202138594         0.614
#>   2:      11002         BE211     168686   66067 3893919499         0.591
#>   3:      11004         BE211      51647   23040 1405231639         0.732
#>   4:      11005         BE211     149514   81829 3580943310         0.602
#>   5:      11007         BE211     115585   63412 2197351336         0.697
#>  ---                                                                     
#> 579:      93018         BE353     109489   47815 2840565149         0.741
#> 580:      93022         BE353     102783   42795 1944607182         0.709
#> 581:      93056         BE353      44404   19520 1071276680         0.788
#> 582:      93088         BE353     165530   59298 4261310867         0.647
#> 583:      93090         BE353     121064   48264 3094736164         0.612
# }
```
