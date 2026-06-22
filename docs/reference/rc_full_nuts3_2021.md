# Complete NUTS3 dataset – 2021 classification

One row per Belgian NUTS3 region in the 2021 classification (44
regions), with fictional macroeconomic indicators. Covers all regions
including BE335 and BE336 (the two Verviers sub-regions).

## Usage

``` r
rc_full_nuts3_2021
```

## Format

A \`data.table\` with 44 rows and 5 columns:

- cd_nuts3:

  Character. NUTS3 2021 code (e.g. \`"BE100"\`).

- population:

  Integer. Resident population (fictional, 10 000–700 000).

- emplois:

  Integer. Number of jobs (fictional).

- masse_sal:

  Numeric. Total wage bill in EUR (fictional).

- taux_activite:

  Numeric. Activity rate, 0–1 (fictional).

## See also

\[rc_full_nuts3_2027\], \[rc_nuts3_2021\]

## Examples

``` r
data(rc_full_nuts3_2021)
head(rc_full_nuts3_2021)
#>    cd_nuts3 population emplois   masse_sal taux_activite
#>      <char>      <int>   <int>       <num>         <num>
#> 1:    BE100     135616   65267  3877043288         0.657
#> 2:    BE211     506505  266275 12556984988         0.565
#> 3:    BE212     392530  189582 12154059553         0.660
#> 4:    BE213     112374   46660  2768844690         0.753
#> 5:    BE223     428744  183377 12139889312         0.570
#> 6:    BE224     159411   57566  4481485463         0.622

# \donttest{
  master_data <- load_master_data()
#> Master data loaded from 'C:/Users/Dell/AppData/Local/Temp/RtmpMFZPCn/temp_libpath168c5fac3201/nbbbenuts/extdata': 581 communes NIS 2019, 565 NIS 2025, 589 NIS BEFORE_2019
  convert_dataset(rc_full_nuts3_2021, "cd_nuts3",
                  from = "NUTS_DISTRICT_2021",
                  to   = "NUTS_PROVINCE_2021", master_data)
#> === Conversion Path Check ===
#> From: NUTS_DISTRICT_2021
#> To:   NUTS_PROVINCE_2021
#> Simple conversion: YES
#> Perimeter-preserving: YES
#> Perimeter relations: nesting
#> 
#> Simple conversion possible from 'NUTS_DISTRICT_2021' to 'NUTS_PROVINCE_2021'.
#> Path: NUTS_DISTRICT_2021 -> NUTS_PROVINCE_2021
#> Relationships: N:1
#>   -> Column 'cd_nuts2_2021' added: 44 converted, 0 NA.
#>     cd_nuts3 cd_nuts2_2021 population emplois   masse_sal taux_activite
#>       <char>        <char>      <int>   <int>       <num>         <num>
#>  1:    BE100          BE10     135616   65267  3877043288         0.657
#>  2:    BE211          BE21     506505  266275 12556984988         0.565
#>  3:    BE212          BE21     392530  189582 12154059553         0.660
#>  4:    BE213          BE21     112374   46660  2768844690         0.753
#>  5:    BE223          BE22     428744  183377 12139889312         0.570
#>  6:    BE224          BE22     159411   57566  4481485463         0.622
#>  7:    BE225          BE22     334741  164698  8417821093         0.612
#>  8:    BE231          BE23     609009  248300 14330029416         0.676
#>  9:    BE232          BE23     161343   85413  4646210612         0.559
#> 10:    BE233          BE23     566092  294053 11342119666         0.578
#> 11:    BE234          BE23     509340  242289 13701987693         0.799
#> 12:    BE235          BE23     367941  183537  9034021228         0.786
#> 13:    BE236          BE23     636402  321751 13814394087         0.727
#> 14:    BE241          BE24      25872   14120   535013530         0.774
#> 15:    BE242          BE24     199042  105499  5898668717         0.674
#> 16:    BE251          BE25     322545  120894  6543093307         0.710
#> 17:    BE252          BE25     370546  200200  9602445410         0.557
#> 18:    BE253          BE25     335120  142532  8754965411         0.638
#> 19:    BE254          BE25     215401   88975  5343280259         0.649
#> 20:    BE255          BE25     116253   54419  2313853408         0.583
#> 21:    BE256          BE25     332755  139204  6821573772         0.749
#> 22:    BE257          BE25     455892  221662 11682001884         0.685
#> 23:    BE258          BE25     399061  169290 12068953236         0.745
#> 24:    BE310          BE31     497099  215691 13071358836         0.756
#> 25:    BE323          BE32     326932  170957  7479019486         0.719
#> 26:    BE328          BE32     223786  119461  7032563959         0.660
#> 27:    BE329          BE32     259358  128103  6340396564         0.780
#> 28:    BE32A          BE32     346217  176141  8761576390         0.747
#> 29:    BE32B          BE32     229930  118685  5712340556         0.559
#> 30:    BE32C          BE32     488202  244012 14411563094         0.795
#> 31:    BE32D          BE32     364369  172598  8993311333         0.584
#> 32:    BE331          BE33     505830  217305 15321413017         0.583
#> 33:    BE332          BE33     300116  128239  8388509940         0.673
#> 34:    BE334          BE33     107768   56783  3031880003         0.738
#> 35:    BE335          BE33     212215   77359  6245555090         0.690
#> 36:    BE336          BE33     486513  233164 11627115101         0.789
#> 37:    BE341          BE34     456462  163790 12716713659         0.624
#> 38:    BE342          BE34     337938  136280  7945708354         0.578
#> 39:    BE343          BE34     463187  252700  8795312244         0.771
#> 40:    BE344          BE34     164110   73993  4386398952         0.767
#> 41:    BE345          BE34     401635  180862  7274358449         0.555
#> 42:    BE351          BE35     681276  305547 18758706658         0.550
#> 43:    BE352          BE35     103447   50930  2379869518         0.589
#> 44:    BE353          BE35     513702  184370 13398294981         0.726
#>     cd_nuts3 cd_nuts2_2021 population emplois   masse_sal taux_activite
#>       <char>        <char>      <int>   <int>       <num>         <num>
# }
```
