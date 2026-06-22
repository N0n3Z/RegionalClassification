# Identify codes from names (convenience wrapper)

Identify codes from names (convenience wrapper)

## Usage

``` r
identify_from_names(
  names,
  master_data,
  possible_classifications = c("POSTAL", "NIS_MUNICIPALITY_2019",
    "NIS_MUNICIPALITY_2025", "NIS_DISTRICT_2019", "NUTS_DISTRICT_2021"),
  max_dist = 0.1,
  language = "both"
)
```

## Arguments

- names:

  Character vector of entity names

- master_data:

  Master data from build_master_table()

- possible_classifications:

  Vector of classifications to try (default: all supported)

- max_dist:

  Maximum distance threshold

- language:

  Preferred language

## Value

data.table with results including the best-matching classification

## Examples

``` r
# \donttest{
  master_data <- load_master_data()
#> Master data loaded from 'C:/Users/Dell/AppData/Local/Temp/RtmpMFZPCn/temp_libpath168c5fac3201/nbbbenuts/extdata': 581 communes NIS 2019, 565 NIS 2025, 589 NIS BEFORE_2019
  identify_from_names(c("Bruxelles", "Antwerpen", "Gent", "Liege"), master_data)
#> Index: <is_confident>
#>    input_name matched_name matched_code distance language is_confident
#>        <char>       <char>       <char>    <num>   <char>       <lgcl>
#> 1:  Bruxelles    Bruxelles         1000        0       fr         TRUE
#> 2:  Antwerpen    Antwerpen         2000        0       nl         TRUE
#> 3:       Gent         Gent         9000        0       nl         TRUE
#> 4:      Liege        Liège         4000        0       fr         TRUE
#>    classification
#>            <char>
#> 1:         POSTAL
#> 2:         POSTAL
#> 3:         POSTAL
#> 4:         POSTAL
# }
```
