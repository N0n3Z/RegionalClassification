# Complete communes dataset – NIS 2025

One row per Belgian commune in the NIS 2025 classification (567
communes), with fictional but realistically-scaled socio-economic
indicators.

## Usage

``` r
rc_full_municipalities_2025
```

## Format

A \`data.table\` with 567 rows and 5 columns:

- cd_commune:

  Integer. NIS 2025 commune code.

- population:

  Integer. Resident population (fictional, 200–180 000).

- emplois:

  Integer. Number of jobs (fictional).

- masse_sal:

  Numeric. Total wage bill in EUR (fictional).

- taux_activite:

  Numeric. Activity rate, 0–1 (fictional).

## See also

\[rc_full_municipalities_2019\], \[rc_dirty_municipalities_2019\]

## Examples

``` r
data(rc_full_municipalities_2025)
head(rc_full_municipalities_2025)
#>    cd_commune population emplois  masse_sal taux_activite
#>        <char>      <int>   <int>      <num>         <num>
#> 1:      11001       5079    2513   92482279         0.779
#> 2:      11002      63372   29142 1967800245         0.783
#> 3:      11004      38257   15279  790911974         0.685
#> 4:      11005      56683   22313 1790372856         0.711
#> 5:      11008      50982   24385 1170598776         0.565
#> 6:      11009      53090   28357 1648584182         0.654

# \donttest{
  master_data <- load_master_data()
#> Master data loaded from 'C:/Users/Dell/AppData/Local/Temp/RtmpMFZPCn/temp_libpath168c5fac3201/nbbbenuts/extdata': 581 communes NIS 2019, 565 NIS 2025, 589 NIS BEFORE_2019
  convert_dataset(rc_full_municipalities_2025, "cd_commune",
                  from = "NIS_MUNICIPALITY_2025",
                  to   = "NUTS_DISTRICT_2027", master_data)
#> === Conversion Path Check ===
#> From: NIS_MUNICIPALITY_2025
#> To:   NUTS_DISTRICT_2027
#> Simple conversion: YES
#> Perimeter-preserving: YES
#> Perimeter relations: nesting
#> 
#> Simple conversion possible from 'NIS_MUNICIPALITY_2025' to 'NUTS_DISTRICT_2027'.
#> Path: NIS_MUNICIPALITY_2025 -> NUTS_DISTRICT_2027
#> Relationships: N:1
#> Warning: 2 code(s) could not be converted (no match found)
#> Warning: 2 code(s) in 'cd_commune' could not be converted to 'NUTS_DISTRICT_2027' (no match).
#>   -> Column 'cd_nuts3_2027' added: 565 converted, 2 NA.
#>      cd_commune cd_nuts3_2027 population emplois  masse_sal taux_activite
#>          <char>        <char>      <int>   <int>      <num>         <num>
#>   1:      11001         BE261       5079    2513   92482279         0.779
#>   2:      11002         BE261      63372   29142 1967800245         0.783
#>   3:      11004         BE261      38257   15279  790911974         0.685
#>   4:      11005         BE261      56683   22313 1790372856         0.711
#>   5:      11008         BE261      50982   24385 1170598776         0.565
#>  ---                                                                     
#> 563:      93018         BE353      98552   53709 2410081985         0.634
#> 564:      93022         BE353     128180   56452 3112127758         0.588
#> 565:      93056         BE353      79402   28561 2334210402         0.745
#> 566:      93088         BE353      96767   37752 2974197286         0.776
#> 567:      93090         BE353     139137   51624 4280263390         0.682
# }
```
