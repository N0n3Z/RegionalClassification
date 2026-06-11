# Complete districts dataset – NIS 2019

One row per Belgian arrondissement (district) in the NIS 2019
classification (44 arrondissements), with fictional socio-economic
indicators. Includes arrondissement 63000 (Verviers), the canonical
ambiguous case that spans two NUTS3 regions (BE335 and BE336).

## Usage

``` r
rc_full_districts_2019
```

## Format

A \`data.table\` with 44 rows and 5 columns:

- cd_arr:

  Integer. NIS 2019 arrondissement code.

- population:

  Integer. Resident population (fictional, 5 000–600 000).

- emplois:

  Integer. Number of jobs (fictional).

- masse_sal:

  Numeric. Total wage bill in EUR (fictional).

- taux_activite:

  Numeric. Activity rate, 0–1 (fictional).

## See also

\[split_ambiguous()\], \[rc_arrondissements_2019\]

## Examples

``` r
data(rc_full_districts_2019)
head(rc_full_districts_2019)
#>    cd_arr population emplois   masse_sal taux_activite
#>    <char>      <int>   <int>       <num>         <num>
#> 1:  11000     466596  245615  8449901851         0.797
#> 2:  12000     355028  133742 10329694477         0.554
#> 3:  13000     558654  296625 12698625731         0.630
#> 4:  20000     117582   51581  3408366225         0.702
#> 5:  21000     164324   61487  4706877812         0.754
#> 6:  23000     333540  136570  9573150712         0.700

# \donttest{
  master_data <- load_master_data()
#> Master data loaded from 'C:/Users/Dell/AppData/Local/Temp/RtmpYb6NDx/temp_libpath1f90279e2a23/nbbbenuts/extdata': 583 communes NIS 2019, 567 NIS 2025, 589 NIS BEFORE_2019
  # Verviers (63000) spans BE335 and BE336 -- requires split_ambiguous()
  split_ambiguous(rc_full_districts_2019, "cd_arr",
                  value_cols = "emplois",
                  from = "NIS_DISTRICT_2019",
                  to   = "NUTS_DISTRICT_2021", master_data)
#> Warning: 1 code(s) could not be converted (no match found)
#> split_ambiguous: 44 unique code(s), 1 ambiguous (63000).
#>   Using default weights from registry.
#>   Code 63000 split into:
#>     BE335  weight=0.8570  (values redistributed)
#>     BE336  weight=0.1430  (values redistributed)
#>   Result: 45 rows (input: 44, +1 from splits).
#>     cd_arr population   emplois   masse_sal taux_activite cd_nuts3_2021
#>     <char>      <int>     <num>       <num>         <num>        <char>
#>  1:  11000     466596 245615.00  8449901851         0.797         BE211
#>  2:  12000     355028 133742.00 10329694477         0.554         BE212
#>  3:  13000     558654 296625.00 12698625731         0.630         BE213
#>  4:  20000     117582  51581.00  3408366225         0.702          <NA>
#>  5:  21000     164324  61487.00  4706877812         0.754         BE100
#>  6:  23000     333540 136570.00  9573150712         0.700         BE241
#>  7:  24000     363456 188299.00  9709251784         0.679         BE242
#>  8:  25000     367589 130830.00 11480323719         0.680         BE310
#>  9:  31000      87481  34599.00  2354900314         0.658         BE251
#> 10:  32000     487262 215953.00 10846569200         0.779         BE252
#> 11:  33000     322941 150993.00  6067351526         0.640         BE253
#> 12:  34000     186179  92913.00  4915572289         0.628         BE254
#> 13:  35000     123238  63876.00  3228827211         0.603         BE255
#> 14:  36000     336405 172964.00  8076380191         0.673         BE256
#> 15:  37000     392539 191511.00  9562447822         0.778         BE257
#> 16:  38000     379226 172936.00 10820920170         0.753         BE258
#> 17:  41000     293568 131907.00  7372544769         0.734         BE231
#> 18:  42000      93889  51052.00  2096510974         0.644         BE232
#> 19:  43000     555884 254405.00 16340884721         0.678         BE233
#> 20:  44000      57965  27623.00  1255722832         0.675         BE234
#> 21:  45000     376555 206186.00 11660720452         0.584         BE235
#> 22:  46000     461669 162271.00 12468731641         0.663         BE236
#> 23:  51000     209152 111879.00  4937476454         0.628         BE32A
#> 24:  52000     485725 260807.00 11668734995         0.733         BE32B
#> 25:  53000      29340  13227.00   641118594         0.757         BE323
#> 26:  55000     378904 148121.00  8054063393         0.686         BE32C
#> 27:  56000     198576  84362.00  4692419287         0.590         BE32D
#> 28:  57000     491447 206438.00 12292455631         0.607         BE328
#> 29:  58000     170950  92902.00  4945412382         0.621         BE329
#> 30:  61000     498084 226134.00 13835075159         0.597         BE331
#> 31:  62000     525326 240160.00 12786023388         0.746         BE332
#> 32:  64000     407395 196075.00  9261625462         0.712         BE334
#> 33:  71000     322978 130025.00  6889246582         0.559         BE224
#> 34:  72000     170607  90585.00  4215242224         0.619         BE225
#> 35:  73000     473901 227744.00 13074644933         0.699         BE223
#> 36:  81000     356135 143868.00 10958179275         0.788         BE341
#> 37:  82000     134740  47442.00  2661970142         0.579         BE342
#> 38:  83000     334247 139154.00  6852273112         0.579         BE343
#> 39:  84000     128404  59100.00  3112320980         0.708         BE344
#> 40:  85000     379282 159388.00  8834168448         0.780         BE345
#> 41:  91000     579727 282124.00 13829337013         0.796         BE351
#> 42:  92000     232907 107976.00  4666852508         0.748         BE352
#> 43:  93000     315492 145025.00  9967295541         0.798         BE353
#> 44:  63000     534566 181144.95 12778531825         0.666         BE335
#> 45:  63000     534566  30226.05 12778531825         0.666         BE336
#>     cd_arr population   emplois   masse_sal taux_activite cd_nuts3_2021
#>     <char>      <int>     <num>       <num>         <num>        <char>
# }
```
