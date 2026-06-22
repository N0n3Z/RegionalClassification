# Build a full correspondence table between two classifications

Returns every (from, to) pair that exists in the reference data. For
simple (N:1 or 1:1) conversions every source code appears exactly once;
for ambiguous (M:N) conversions a source code may appear in multiple
rows.

## Usage

``` r
get_crosswalk(from, to, master_data, weights = FALSE)
```

## Arguments

- from:

  Source classification identifier (see \[classification_reference\]).

- to:

  Target classification identifier.

- master_data:

  Output from \[load_master_data()\].

- weights:

  Logical (default \`FALSE\`). When \`TRUE\`, a \`weight\` column is
  added. Unambiguous codes receive \`weight = 1\`. Ambiguous (1:N) codes
  use population weights from the session registry (see
  \[register_split_weights()\]) when available, otherwise equal weights.

## Value

A \`data.table\` with columns named after \`from\` and \`to\`. When
\`weights = TRUE\`, an additional numeric \`weight\` column is included.

## Examples

``` r
# \donttest{
  master_data <- load_master_data()
#> Master data loaded from 'C:/Users/Dell/AppData/Local/Temp/RtmpMFZPCn/temp_libpath168c5fac3201/nbbbenuts/extdata': 581 communes NIS 2019, 565 NIS 2025, 589 NIS BEFORE_2019
  get_crosswalk("NIS_MUNICIPALITY_2019", "NUTS_DISTRICT_2021", master_data)
#>      NIS_MUNICIPALITY_2019 NUTS_DISTRICT_2021
#>                      <int>             <char>
#>   1:                 11001              BE211
#>   2:                 11002              BE211
#>   3:                 11004              BE211
#>   4:                 11005              BE211
#>   5:                 11007              BE211
#>  ---                                         
#> 577:                 93018              BE353
#> 578:                 93022              BE353
#> 579:                 93056              BE353
#> 580:                 93088              BE353
#> 581:                 93090              BE353
  get_crosswalk("POSTAL", "NIS_MUNICIPALITY_2019", master_data)
#>       POSTAL NIS_MUNICIPALITY_2019
#>        <int>                 <int>
#>    1:   1000                 21004
#>    2:   1020                 21004
#>    3:   1030                 21015
#>    4:   1040                 21005
#>    5:   1050                 21009
#>   ---                             
#> 1145:   9982                 43014
#> 1146:   9988                 43014
#> 1147:   9990                 43010
#> 1148:   9991                 43010
#> 1149:   9992                 43010

  # With weights for the ambiguous Verviers split
  get_crosswalk("NIS_DISTRICT_2019", "NUTS_DISTRICT_2021", master_data,
                weights = TRUE)
#> Index: <NIS_DISTRICT_2019>
#>     NIS_DISTRICT_2019 NUTS_DISTRICT_2021 weight
#>                 <int>             <char>  <num>
#>  1:             11000              BE211    1.0
#>  2:             12000              BE212    1.0
#>  3:             13000              BE213    1.0
#>  4:             21000              BE100    1.0
#>  5:             23000              BE241    1.0
#>  6:             24000              BE242    1.0
#>  7:             25000              BE310    1.0
#>  8:             31000              BE251    1.0
#>  9:             32000              BE252    1.0
#> 10:             33000              BE253    1.0
#> 11:             34000              BE254    1.0
#> 12:             35000              BE255    1.0
#> 13:             36000              BE256    1.0
#> 14:             37000              BE257    1.0
#> 15:             38000              BE258    1.0
#> 16:             41000              BE231    1.0
#> 17:             42000              BE232    1.0
#> 18:             43000              BE233    1.0
#> 19:             44000              BE234    1.0
#> 20:             45000              BE235    1.0
#> 21:             46000              BE236    1.0
#> 22:             51000              BE32A    1.0
#> 23:             52000              BE32B    1.0
#> 24:             53000              BE323    1.0
#> 25:             55000              BE32C    1.0
#> 26:             56000              BE32D    1.0
#> 27:             57000              BE328    1.0
#> 28:             58000              BE329    1.0
#> 29:             61000              BE331    1.0
#> 30:             62000              BE332    1.0
#> 31:             63000              BE335    0.5
#> 32:             63000              BE336    0.5
#> 33:             64000              BE334    1.0
#> 34:             71000              BE224    1.0
#> 35:             72000              BE225    1.0
#> 36:             73000              BE223    1.0
#> 37:             81000              BE341    1.0
#> 38:             82000              BE342    1.0
#> 39:             83000              BE343    1.0
#> 40:             84000              BE344    1.0
#> 41:             85000              BE345    1.0
#> 42:             91000              BE351    1.0
#> 43:             92000              BE352    1.0
#> 44:             93000              BE353    1.0
#>     NIS_DISTRICT_2019 NUTS_DISTRICT_2021 weight
#>                 <int>             <char>  <num>
# }
```
