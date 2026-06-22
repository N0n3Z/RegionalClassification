# Sample postal codes

A small dataset of 12 Belgian postal codes with fictional socio-economic
indicators. Useful for demonstrating postal-code conversions.

## Usage

``` r
rc_postal
```

## Format

A \`data.table\` with 12 rows and 4 columns:

- cd_postal:

  Integer. Belgian postal code.

- nom_fr:

  Character. French locality name.

- population:

  Integer. Resident population (fictional).

- revenu_moy:

  Numeric. Average income in EUR (fictional).

## Examples

``` r
data(rc_postal)
head(rc_postal)
#>    cd_postal    nom_fr population revenu_moy
#>        <int>    <char>      <int>      <num>
#> 1:      1000 Bruxelles      22000      28500
#> 2:      2000    Anvers      50000      27000
#> 3:      9000      Gand      80000      26500
#> 4:      4000     Liege      55000      24000
#> 5:      4800  Verviers      15000      23000
#> 6:      1410  Waterloo      30000      32000

# \donttest{
  master_data <- load_master_data()
#> Master data loaded from 'C:/Users/Dell/AppData/Local/Temp/RtmpQNI466/temp_libpath2a8447f11d6b/nbbbenuts/extdata': 581 communes NIS 2019, 565 NIS 2025, 589 NIS BEFORE_2019
  convert_dataset(rc_postal, "cd_postal",
                  from = "POSTAL", to = "NIS_MUNICIPALITY_2019", master_data)
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
#>   -> Column 'cd_nis2019' added: 12 converted, 0 NA.
#>     cd_postal cd_nis2019            nom_fr population revenu_moy
#>         <int>      <int>            <char>      <int>      <num>
#>  1:      1000      21004         Bruxelles      22000      28500
#>  2:      2000      11002            Anvers      50000      27000
#>  3:      9000      44021              Gand      80000      26500
#>  4:      4000      62063             Liege      55000      24000
#>  5:      4800      63079          Verviers      15000      23000
#>  6:      1410      25110          Waterloo      30000      32000
#>  7:      8000      31005            Bruges      45000      25000
#>  8:      6000      52011         Charleroi      70000      22000
#>  9:      3500      71022           Hasselt      35000      26000
#> 10:      6900      83034 Marche-en-Famenne       8000      21000
#> 11:      5000      92094             Namur      40000      25500
#> 12:      7000      53053              Mons      36000      23500
# }
```
