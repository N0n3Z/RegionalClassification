# Complete NUTS3 dataset – 2027 classification

One row per Belgian NUTS3 region in the 2027 classification (44 regions,
per EU Regulation 2026/195), with fictional macroeconomic indicators.

## Usage

``` r
rc_full_nuts3_2027
```

## Format

A \`data.table\` with 44 rows and 5 columns:

- cd_nuts3_2027:

  Character. NUTS3 2027 code (e.g. \`"BE100"\`).

- population:

  Integer. Resident population (fictional, 10 000–700 000).

- emplois:

  Integer. Number of jobs (fictional).

- masse_sal:

  Numeric. Total wage bill in EUR (fictional).

- taux_activite:

  Numeric. Activity rate, 0–1 (fictional).

## See also

\[rc_full_nuts3_2021\]

## Examples

``` r
data(rc_full_nuts3_2027)
head(rc_full_nuts3_2027)
#>    cd_nuts3_2027 population emplois   masse_sal taux_activite
#>           <char>      <int>   <int>       <num>         <num>
#> 1:         BE100     662487  327538 20951512029         0.702
#> 2:         BE225     454196  161197 11914282192         0.651
#> 3:         BE226     571589  256445 11533326017         0.583
#> 4:         BE227     150118   57108  3094260752         0.778
#> 5:         BE241      54535   26310  1382990453         0.784
#> 6:         BE242      64536   22940  1793993561         0.617

# \donttest{
  master_data <- load_master_data()
#> Master data loaded from 'C:/Users/Dell/AppData/Local/Temp/Rtmp6rbXw4/temp_libpath26b420df5361/nbbbenuts/extdata': 581 communes NIS 2019, 565 NIS 2025, 589 NIS BEFORE_2019
  convert_dataset(rc_full_nuts3_2027, "cd_nuts3_2027",
                  from = "NUTS_DISTRICT_2027",
                  to   = "NUTS_PROVINCE_2027", master_data)
#> === Conversion Path Check ===
#> From: NUTS_DISTRICT_2027
#> To:   NUTS_PROVINCE_2027
#> Simple conversion: YES
#> Perimeter-preserving: YES
#> Perimeter relations: nesting
#> 
#> Simple conversion possible from 'NUTS_DISTRICT_2027' to 'NUTS_PROVINCE_2027'.
#> Path: NUTS_DISTRICT_2027 -> NUTS_PROVINCE_2027
#> Relationships: N:1
#>   -> Column 'cd_nuts2_2027' added: 44 converted, 0 NA.
#>     cd_nuts3_2027 cd_nuts2_2027 population emplois   masse_sal taux_activite
#>            <char>        <char>      <int>   <int>       <num>         <num>
#>  1:         BE100          BE10     662487  327538 20951512029         0.702
#>  2:         BE225          BE22     454196  161197 11914282192         0.651
#>  3:         BE226          BE22     571589  256445 11533326017         0.583
#>  4:         BE227          BE22     150118   57108  3094260752         0.778
#>  5:         BE241          BE24      54535   26310  1382990453         0.784
#>  6:         BE242          BE24      64536   22940  1793993561         0.617
#>  7:         BE251          BE25     558478  283523 14558323311         0.560
#>  8:         BE252          BE25     695627  246765 15963530646         0.701
#>  9:         BE253          BE25     453431  226870  8222960935         0.597
#> 10:         BE254          BE25     399715  157460  7845171819         0.734
#> 11:         BE255          BE25      73209   38871  1689304762         0.578
#> 12:         BE256          BE25     147598   53425  4162324471         0.744
#> 13:         BE257          BE25     451888  160808 12154752103         0.680
#> 14:         BE258          BE25     688619  263073 15645461728         0.571
#> 15:         BE261          BE26     571708  272695 10309434054         0.628
#> 16:         BE262          BE26     606462  332176 17921172745         0.618
#> 17:         BE263          BE26     120292   55610  3248993447         0.798
#> 18:         BE271          BE27     353610  152218  6754950871         0.640
#> 19:         BE272          BE27     491864  193962 11522855228         0.675
#> 20:         BE273          BE27     558894  298367 11084258557         0.785
#> 21:         BE274          BE27      84712   33473  2320625034         0.777
#> 22:         BE275          BE27     397184  141964  8855409968         0.731
#> 23:         BE276          BE27     494276  242190 14180422220         0.749
#> 24:         BE310          BE31     241895  101655  6940114061         0.617
#> 25:         BE323          BE32     122327   51649  3782187172         0.738
#> 26:         BE328          BE32     253435  102673  6178353697         0.685
#> 27:         BE329          BE32     253951  109063  4734508013         0.724
#> 28:         BE32A          BE32     312216  171096  8507663437         0.699
#> 29:         BE32B          BE32     112649   55062  2842472062         0.702
#> 30:         BE32C          BE32     128644   53420  2695525600         0.616
#> 31:         BE32D          BE32     532542  279427 11549447297         0.609
#> 32:         BE331          BE33     347533  171721  6404185759         0.704
#> 33:         BE332          BE33     315375  172234  7937384712         0.641
#> 34:         BE334          BE33     693728  351112 18681632082         0.766
#> 35:         BE335          BE33     486755  246230 11818756174         0.720
#> 36:         BE336          BE33      47122   22087  1103914688         0.778
#> 37:         BE341          BE34     514730  280770 10128571668         0.552
#> 38:         BE342          BE34     397057  161378 12533470194         0.734
#> 39:         BE343          BE34     353749  187362  6542776347         0.558
#> 40:         BE344          BE34     590331  296864 14003692110         0.623
#> 41:         BE345          BE34     329914  157080 10478775589         0.634
#> 42:         BE351          BE35     147248   75082  4393360139         0.726
#> 43:         BE352          BE35     462230  217274  8919919697         0.558
#> 44:         BE353          BE35     691236  271137 14975633608         0.763
#>     cd_nuts3_2027 cd_nuts2_2027 population emplois   masse_sal taux_activite
#>            <char>        <char>      <int>   <int>       <num>         <num>
# }
```
