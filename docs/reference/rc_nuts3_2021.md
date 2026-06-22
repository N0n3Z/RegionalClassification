# Sample NUTS3 regions – 2021 classification

A dataset of 10 Belgian NUTS3 regions (2021 classification) with
fictional macroeconomic indicators. Includes BE335 and BE336 (the two
Verviers sub-regions) to demonstrate NUTS 2021 -\> NUTS 2027
conversions.

## Usage

``` r
rc_nuts3_2021
```

## Format

A \`data.table\` with 10 rows and 5 columns:

- cd_nuts3:

  Character. NUTS3 2021 code (e.g. "BE100").

- nom_fr:

  Character. French name of the NUTS3 region.

- gdp_mio_eur:

  Numeric. GDP in millions of EUR (fictional).

- emplois:

  Integer. Number of jobs (fictional).

- taux_chomage:

  Numeric. Unemployment rate, 0–1 (fictional).

## Examples

``` r
data(rc_nuts3_2021)
head(rc_nuts3_2021)
#>    cd_nuts3             nom_fr gdp_mio_eur emplois taux_chomage
#>      <char>             <char>       <num>   <int>        <num>
#> 1:    BE100 Bruxelles-Capitale       85000  850000        0.147
#> 2:    BE211        Arr. Anvers       32000  310000        0.072
#> 3:    BE212       Arr. Malines        9000  145000        0.048
#> 4:    BE213      Arr. Turnhout        8500  130000        0.052
#> 5:    BE231          Arr. Gand       24000  270000        0.055
#> 6:    BE332         Arr. Liege       18000  175000        0.098

# \donttest{
  master_data <- load_master_data()
#> Master data loaded from 'C:/Users/Dell/AppData/Local/Temp/RtmpMFZPCn/temp_libpath168c5fac3201/nbbbenuts/extdata': 581 communes NIS 2019, 565 NIS 2025, 589 NIS BEFORE_2019

  # Aggregate NUTS3 2021 to NUTS2 2021
  # Note: NUTS_DISTRICT_2021 and NUTS_DISTRICT_2027 cover different geographic areas;
  # there is no direct conversion between them (see ?classification_reference).
  convert_dataset(rc_nuts3_2021, "cd_nuts3",
                  from = "NUTS_DISTRICT_2021", to = "NUTS_PROVINCE_2021", master_data)
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
#>   -> Column 'cd_nuts2_2021' added: 10 converted, 0 NA.
#>     cd_nuts3 cd_nuts2_2021             nom_fr gdp_mio_eur emplois taux_chomage
#>       <char>        <char>             <char>       <num>   <int>        <num>
#>  1:    BE100          BE10 Bruxelles-Capitale       85000  850000        0.147
#>  2:    BE211          BE21        Arr. Anvers       32000  310000        0.072
#>  3:    BE212          BE21       Arr. Malines        9000  145000        0.048
#>  4:    BE213          BE21      Arr. Turnhout        8500  130000        0.052
#>  5:    BE231          BE23          Arr. Gand       24000  270000        0.055
#>  6:    BE332          BE33         Arr. Liege       18000  175000        0.098
#>  7:    BE335          BE33   Arr. Verviers FR        5800   62000        0.082
#>  8:    BE336          BE33   Arr. Verviers DE        1200   13000        0.065
#>  9:    BE351          BE35        Arr. Dinant        3500   48000        0.070
#> 10:    BE352          BE35         Arr. Namur        9500  120000        0.080
# }
```
