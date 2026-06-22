# Sample communes – NIS 2019

A small representative dataset of 12 Belgian communes using NIS 2019
codes, with fictional but realistic socio-economic indicators. Useful
for testing and demonstrating \`convert_codes()\`,
\`convert_dataset()\`, and \`diagnose_classification()\`.

## Usage

``` r
rc_communes_2019
```

## Format

A \`data.table\` with 12 rows and 7 columns:

- cd_commune:

  Integer. NIS 2019 commune code.

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
data(rc_communes_2019)
head(rc_communes_2019)
#>    cd_commune    nom_fr    nom_nl population emplois masse_sal taux_activite
#>         <int>    <char>    <char>      <int>   <int>     <num>         <num>
#> 1:      21004 Bruxelles   Brussel     185103  850000   2.8e+10          0.67
#> 2:      11002    Anvers Antwerpen     530504  320000   1.0e+10          0.65
#> 3:      44021      Gand      Gent     265086  180000   5.5e+09          0.66
#> 4:      62063     Liege      Luik     197355  120000   3.8e+09          0.62
#> 5:      63079  Verviers  Verviers      55698   28000   8.5e+08          0.58
#> 6:      25015  Waterloo  Waterloo      30784   18000   5.5e+08          0.70

# \donttest{
  master_data <- load_master_data()
#> Master data loaded from 'C:/Users/Dell/AppData/Local/Temp/Rtmp6rbXw4/temp_libpath26b420df5361/nbbbenuts/extdata': 581 communes NIS 2019, 565 NIS 2025, 589 NIS BEFORE_2019
  convert_dataset(rc_communes_2019, "cd_commune",
                  to = "NUTS_DISTRICT_2021", master_data)
#> Auto-detecting source classification for 'cd_commune'...
#>   Detected: NIS_MUNICIPALITY_2019
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
#>   -> Column 'cd_nuts3_2021' added: 12 converted, 0 NA.
#>     cd_commune cd_nuts3_2021            nom_fr            nom_nl population
#>          <int>        <char>            <char>            <char>      <int>
#>  1:      21004         BE100         Bruxelles           Brussel     185103
#>  2:      11002         BE211            Anvers         Antwerpen     530504
#>  3:      44021         BE234              Gand              Gent     265086
#>  4:      62063         BE332             Liege              Luik     197355
#>  5:      63079         BE335          Verviers          Verviers      55698
#>  6:      25015         BE310          Waterloo          Waterloo      30784
#>  7:      31005         BE251            Bruges            Brugge     120000
#>  8:      52011         BE32B         Charleroi         Charleroi     200000
#>  9:      71022         BE224           Hasselt           Hasselt      80000
#> 10:      85007         BE345 Marche-en-Famenne Marche-en-Famenne      17500
#> 11:      23016         BE241           Enghien           Edingen      12500
#> 12:      57081         BE328          Mouscron         Moeskroen      58000
#>     emplois masse_sal taux_activite
#>       <int>     <num>         <num>
#>  1:  850000   2.8e+10          0.67
#>  2:  320000   1.0e+10          0.65
#>  3:  180000   5.5e+09          0.66
#>  4:  120000   3.8e+09          0.62
#>  5:   28000   8.5e+08          0.58
#>  6:   18000   5.5e+08          0.70
#>  7:   70000   2.1e+09          0.64
#>  8:  110000   3.2e+09          0.60
#>  9:   45000   1.3e+09          0.65
#> 10:    9000   2.7e+08          0.55
#> 11:    6000   1.8e+08          0.63
#> 12:   30000   9.0e+08          0.61
# }
```
