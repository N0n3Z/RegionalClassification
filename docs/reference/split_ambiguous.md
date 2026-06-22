# Handle M:N conversions on a dataset using weighted splits

When converting between classifications where some codes map to multiple
targets (e.g. arrondissement Verviers 63000 -\> NUTS3 BE335 + BE336),
this function distributes value columns proportionally using supplied or
registered weights.

## Usage

``` r
split_ambiguous(
  dt,
  code_col,
  value_cols,
  from,
  to,
  master_data,
  weights = NULL,
  value_type = c("additive", "ratio"),
  target_col = NULL,
  normalize = TRUE,
  add_weight_col = FALSE,
  verbose = TRUE
)
```

## Arguments

- dt:

  data.table with data to convert

- code_col:

  Name of the column containing source codes

- value_cols:

  Character vector of column names to redistribute. For
  value_type="additive": multiplied by weight (totals, counts, sums).
  For value_type="ratio": kept unchanged (rates, averages, indices).

- from:

  Source classification

- to:

  Target classification

- master_data:

  Output from build_master_table()

- weights:

  How to weight the split. One of: - NULL (default): use registry if
  available, otherwise equal weights - data.table with columns
  (code_from, code_to, weight) - character: name of a registered
  variable ("population", "employment", ...)

- value_type:

  "additive" or "ratio". See value_cols.

- target_col:

  Name of the new target code column. NULL = auto-generated.

- normalize:

  Normalize weights to sum to 1 per code_from? Default TRUE.

- add_weight_col:

  Add a 'split_weight' column to the result? Default FALSE.

- verbose:

  Print split summary? Default TRUE.

## Value

data.table. Ambiguous codes produce multiple rows; unambiguous codes
produce one row each.

## Examples

``` r
# \donttest{
  master_data <- load_master_data()
#> Master data loaded from 'C:/Users/Dell/AppData/Local/Temp/RtmpMFZPCn/temp_libpath168c5fac3201/nbbbenuts/extdata': 581 communes NIS 2019, 565 NIS 2025, 589 NIS BEFORE_2019
  arr_salaries <- data.table::data.table(
    arr_code   = c(11000L, 62000L, 63000L),   # 63000 = Verviers (ambiguous)
    total_wage = c(5e9, 3e9, 1e9),
    avg_salary = c(2900, 2700, 2400)
  )

  # Equal weights (default)
  split_ambiguous(arr_salaries, "arr_code",
                  value_cols = c("total_wage", "avg_salary"),
                  from = "NIS_DISTRICT_2019", to = "NUTS_DISTRICT_2021",
                  master_data,
                  value_type = "additive")
#> split_ambiguous: 3 unique code(s), 1 ambiguous (63000).
#>   Using default weights from registry.
#>   Code 63000 split into:
#>     BE335  weight=0.8570  (values redistributed)
#>     BE336  weight=0.1430  (values redistributed)
#>   Result: 4 rows (input: 3, +1 from splits).
#>    arr_code total_wage avg_salary cd_nuts3_2021
#>       <int>      <num>      <num>        <char>
#> 1:    11000   5.00e+09     2900.0         BE211
#> 2:    62000   3.00e+09     2700.0         BE332
#> 3:    63000   8.57e+08     2056.8         BE335
#> 4:    63000   1.43e+08      343.2         BE336

  # Manual population weights for Verviers
  weights <- data.table::data.table(
    code_from = c(63000L, 63000L),
    code_to   = c("BE335", "BE336"),
    weight    = c(0.857, 0.143)
  )
  split_ambiguous(arr_salaries, "arr_code",
                  value_cols = "total_wage",
                  from = "NIS_DISTRICT_2019", to = "NUTS_DISTRICT_2021",
                  master_data,
                  weights    = weights,
                  value_type = "additive")
#> split_ambiguous: 3 unique code(s), 1 ambiguous (63000).
#>   Code 63000 split into:
#>     BE335  weight=0.8570  (values redistributed)
#>     BE336  weight=0.1430  (values redistributed)
#>   Result: 4 rows (input: 3, +1 from splits).
#>    arr_code total_wage avg_salary cd_nuts3_2021
#>       <int>      <num>      <num>        <char>
#> 1:    11000   5.00e+09       2900         BE211
#> 2:    62000   3.00e+09       2700         BE332
#> 3:    63000   8.57e+08       2400         BE335
#> 4:    63000   1.43e+08       2400         BE336
# }
```
