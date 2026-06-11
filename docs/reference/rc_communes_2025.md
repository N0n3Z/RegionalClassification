# Sample communes – NIS 2025

A small representative dataset of 10 Belgian communes using NIS 2025
codes, with fictional but realistic socio-economic indicators.

## Usage

``` r
rc_communes_2025
```

## Format

A \`data.table\` with 10 rows and 7 columns:

- cd_commune:

  Integer. NIS 2025 commune code.

- nom_fr:

  Character. French name of the commune.

- nom_nl:

  Character. Dutch name of the commune.

- population:

  Integer. Resident population (fictional).

- emplois:

  Integer. Number of jobs (fictional).

- masse_sal:

  Numeric. Total wage bill in EUR (fictional).

- taux_activite:

  Numeric. Activity rate, 0–1 (fictional).

## Examples

``` r
data(rc_communes_2025)
head(rc_communes_2025)
#>    cd_commune    nom_fr    nom_nl population emplois masse_sal taux_activite
#>         <int>    <char>    <char>      <int>   <int>     <num>         <num>
#> 1:      21004 Bruxelles   Brussel     186000  855000  2.85e+10          0.67
#> 2:      11002    Anvers Antwerpen     533000  323000  1.02e+10          0.65
#> 3:      44021      Gand      Gent     267000  182000  5.60e+09          0.66
#> 4:      62063     Liege      Luik     198000  121000  3.85e+09          0.62
#> 5:      63079  Verviers  Verviers      56000   28500  8.70e+08          0.58
#> 6:      25015  Waterloo  Waterloo      31000   18500  5.60e+08          0.70

# \donttest{
  master_data <- load_master_data()
#> Master data loaded from 'C:/Users/Dell/AppData/Local/Temp/RtmpYb6NDx/temp_libpath1f90279e2a23/nbbbenuts/extdata': 583 communes NIS 2019, 567 NIS 2025, 589 NIS BEFORE_2019
  convert_dataset(rc_communes_2025, "cd_commune",
                  from = "NIS_MUNICIPALITY_2025", to = "NUTS_DISTRICT_2027", master_data)
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
#> Warning: 1 code(s) could not be converted (no match found)
#> Warning: 1 code(s) in 'cd_commune' could not be converted to 'NUTS_DISTRICT_2027' (no match).
#>   -> Column 'cd_nuts3_2027' added: 9 converted, 1 NA.
#>     cd_commune cd_nuts3_2027            nom_fr            nom_nl population
#>          <int>        <char>            <char>            <char>      <int>
#>  1:      21004         BE100         Bruxelles           Brussel     186000
#>  2:      11002         BE261            Anvers         Antwerpen     533000
#>  3:      44021         BE274              Gand              Gent     267000
#>  4:      62063         BE332             Liege              Luik     198000
#>  5:      63079         BE335          Verviers          Verviers      56000
#>  6:      25015         BE310          Waterloo          Waterloo      31000
#>  7:      31005         BE251            Bruges            Brugge     121000
#>  8:      52011         BE32B         Charleroi         Charleroi     201000
#>  9:      71022          <NA>           Hasselt           Hasselt      81000
#> 10:      85007         BE345 Marche-en-Famenne Marche-en-Famenne      17800
#>     emplois masse_sal taux_activite
#>       <int>     <num>         <num>
#>  1:  855000  2.85e+10          0.67
#>  2:  323000  1.02e+10          0.65
#>  3:  182000  5.60e+09          0.66
#>  4:  121000  3.85e+09          0.62
#>  5:   28500  8.70e+08          0.58
#>  6:   18500  5.60e+08          0.70
#>  7:   71000  2.15e+09          0.64
#>  8:  111000  3.25e+09          0.60
#>  9:   46000  1.32e+09          0.65
#> 10:    9200  2.80e+08          0.55
# }
```
