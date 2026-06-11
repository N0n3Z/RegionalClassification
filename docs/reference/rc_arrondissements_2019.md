# Sample arrondissements – NIS 2019

A dataset of 8 Belgian arrondissements using NIS 2019 codes. Includes
arrondissement 63000 (Verviers), which maps to two NUTS3 regions (BE335
and BE336), making it the key test case for \`split_ambiguous()\`.

## Usage

``` r
rc_arrondissements_2019
```

## Format

A \`data.table\` with 8 rows and 5 columns:

- cd_arr:

  Integer. NIS 2019 arrondissement code.

- nom_fr:

  Character. French name of the arrondissement.

- emplois:

  Integer. Number of jobs (fictional).

- masse_sal:

  Numeric. Total wage bill in EUR (fictional).

- population:

  Integer. Resident population (fictional).

## Examples

``` r
data(rc_arrondissements_2019)
head(rc_arrondissements_2019)
#>    cd_arr                  nom_fr emplois masse_sal population
#>     <int>                  <char>   <int>     <num>      <int>
#> 1:  11000             Arr. Anvers  620000   1.9e+10     970000
#> 2:  12000            Arr. Malines  150000   4.5e+09     360000
#> 3:  21000 Arr. Bruxelles-Capitale  850000   2.8e+10    1220000
#> 4:  44000               Arr. Gand  280000   8.5e+09     810000
#> 5:  62000              Arr. Liege  180000   5.5e+09     600000
#> 6:  63000           Arr. Verviers   65000   2.0e+09     275000

# \donttest{
  master_data <- load_master_data()
#> Master data loaded from 'C:/Users/Dell/AppData/Local/Temp/RtmpYb6NDx/temp_libpath1f90279e2a23/nbbbenuts/extdata': 583 communes NIS 2019, 567 NIS 2025, 589 NIS BEFORE_2019

  # Verviers (63000) is ambiguous: spans BE335 and BE336
  split_ambiguous(
    dt         = rc_arrondissements_2019,
    code_col   = "cd_arr",
    value_cols = c("emplois", "masse_sal"),
    from       = "NIS_DISTRICT_2019",
    to         = "NUTS_DISTRICT_2021",
    master_data
  )
#> split_ambiguous: 8 unique code(s), 1 ambiguous (63000).
#>   Using default weights from registry.
#>   Code 63000 split into:
#>     BE335  weight=0.8570  (values redistributed)
#>     BE336  weight=0.1430  (values redistributed)
#>   Result: 9 rows (input: 8, +1 from splits).
#>    cd_arr                  nom_fr emplois masse_sal population cd_nuts3_2021
#>     <int>                  <char>   <num>     <num>      <int>        <char>
#> 1:  11000             Arr. Anvers  620000 1.900e+10     970000         BE211
#> 2:  12000            Arr. Malines  150000 4.500e+09     360000         BE212
#> 3:  21000 Arr. Bruxelles-Capitale  850000 2.800e+10    1220000         BE100
#> 4:  44000               Arr. Gand  280000 8.500e+09     810000         BE234
#> 5:  62000              Arr. Liege  180000 5.500e+09     600000         BE332
#> 6:  52000          Arr. Charleroi  150000 4.500e+09     430000         BE32B
#> 7:  71000            Arr. Hasselt   90000 2.700e+09     290000         BE224
#> 8:  63000           Arr. Verviers   55705 1.714e+09     275000         BE335
#> 9:  63000           Arr. Verviers    9295 2.860e+08     275000         BE336
# }
```
