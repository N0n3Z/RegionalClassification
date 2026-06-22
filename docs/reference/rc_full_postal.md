# Complete postal codes dataset

One row per Belgian postal code (1 149 codes), with fictional
socio-economic indicators. Useful for full-coverage postal-code
conversion and diagnostic testing.

## Usage

``` r
rc_full_postal
```

## Format

A \`data.table\` with 1 149 rows and 5 columns:

- cd_postal:

  Integer. Belgian postal code.

- population:

  Integer. Resident population (fictional, 50–80 000).

- emplois:

  Integer. Number of jobs (fictional).

- masse_sal:

  Numeric. Total wage bill in EUR (fictional).

- taux_activite:

  Numeric. Activity rate, 0–1 (fictional).

## See also

\[rc_postal\], \[convert_dataset()\]

## Examples

``` r
data(rc_full_postal)
head(rc_full_postal)
#>    cd_postal population emplois  masse_sal taux_activite
#>       <char>      <int>   <int>      <num>         <num>
#> 1:      1000      43637   19900  860950427         0.678
#> 2:      1020      59655   26333 1608131814         0.705
#> 3:      1030      54482   27881 1203453542         0.746
#> 4:      1040      34541   14856 1039684442         0.592
#> 5:      1050      64954   29693 1471350431         0.741
#> 6:      1060      71947   34612 1508444892         0.556

# \donttest{
  master_data <- load_master_data()
#> Master data loaded from 'C:/Users/Dell/AppData/Local/Temp/Rtmp6rbXw4/temp_libpath26b420df5361/nbbbenuts/extdata': 581 communes NIS 2019, 565 NIS 2025, 589 NIS BEFORE_2019
  convert_dataset(rc_full_postal, "cd_postal",
                  from = "POSTAL",
                  to   = "NIS_MUNICIPALITY_2019", master_data)
#> === Conversion Path Check ===
#> From: POSTAL
#> To:   NIS_MUNICIPALITY_2019
#> Simple conversion: YES
#> Perimeter-preserving: YES
#> Perimeter relations: nesting
#> 
#> Simple conversion possible from 'POSTAL' to 'NIS_MUNICIPALITY_2019'.
#> Path: POSTAL -> NIS_MUNICIPALITY_2019
#> Relationships: N:1
#>   -> Column 'cd_nis2019' added: 1149 converted, 0 NA.
#>       cd_postal cd_nis2019 population emplois  masse_sal taux_activite
#>          <char>      <int>      <int>   <int>      <num>         <num>
#>    1:      1000      21004      43637   19900  860950427         0.678
#>    2:      1020      21004      59655   26333 1608131814         0.705
#>    3:      1030      21015      54482   27881 1203453542         0.746
#>    4:      1040      21005      34541   14856 1039684442         0.592
#>    5:      1050      21009      64954   29693 1471350431         0.741
#>   ---                                                                 
#> 1145:      9982      43014      26684    9852  561476681         0.715
#> 1146:      9988      43014      52664   23577 1303886191         0.575
#> 1147:      9990      43010      45309   16714 1304208813         0.677
#> 1148:      9991      43010       8704    3269  237648921         0.783
#> 1149:      9992      43010      44492   18309  922524587         0.640
# }
```
