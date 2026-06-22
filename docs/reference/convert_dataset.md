# Convert a geographic code column in a dataset

High-level wrapper around convert_codes() that operates directly on a
data.table. Optionally auto-detects the source classification by
matching the column values against known code sets in master_data.

## Usage

``` r
convert_dataset(
  dt,
  code_col,
  to,
  master_data,
  from = NULL,
  target_col = NULL,
  keep_code = TRUE,
  verbose = TRUE,
  allow_ambiguous = FALSE,
  na_action = c("warn", "keep", "drop")
)
```

## Arguments

- dt:

  data.table (or data.frame, coerced automatically)

- code_col:

  Name of the column containing source codes

- to:

  Target classification (e.g. "NUTS_DISTRICT_2021")

- master_data:

  Output from build_master_table()

- from:

  Source classification. NULL = auto-detect from values.

- target_col:

  Name of the new column to create. NULL = auto-generated.

- keep_code:

  Keep the original code_col? Default TRUE.

- verbose:

  Print conversion path info? Default TRUE.

- allow_ambiguous:

  Allow M:N conversions? Default FALSE. Use split_ambiguous() for
  weighted M:N handling.

- na_action:

  "warn" (default): warn on unmatched codes and keep NAs; "keep":
  silently keep NAs; "drop": remove rows with unmatched codes.

## Value

data.table with target_col added after code_col. For M:N conversions,
may return more rows than input.

## Examples

``` r
# \donttest{
  master_data <- load_master_data()
#> Master data loaded from 'C:/Users/Dell/AppData/Local/Temp/RtmpMFZPCn/temp_libpath168c5fac3201/nbbbenuts/extdata': 581 communes NIS 2019, 565 NIS 2025, 589 NIS BEFORE_2019
  salaries <- data.table::data.table(
    commune = c(21004L, 11002L, 44021L), avg_salary = c(3200, 2900, 2700))

  # Explicit source
  convert_dataset(salaries, "commune", "NUTS_DISTRICT_2021", master_data,
                  from = "NIS_MUNICIPALITY_2019")
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
#>   -> Column 'cd_nuts3_2021' added: 3 converted, 0 NA.
#>    commune cd_nuts3_2021 avg_salary
#>      <int>        <char>      <num>
#> 1:   21004         BE100       3200
#> 2:   11002         BE211       2900
#> 3:   44021         BE234       2700

  # Auto-detect source
  convert_dataset(salaries, "commune", "NUTS_DISTRICT_2021", master_data)
#> Auto-detecting source classification for 'commune'...
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
#>   -> Column 'cd_nuts3_2021' added: 3 converted, 0 NA.
#>    commune cd_nuts3_2021 avg_salary
#>      <int>        <char>      <num>
#> 1:   21004         BE100       3200
#> 2:   11002         BE211       2900
#> 3:   44021         BE234       2700
# }
```
