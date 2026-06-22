# Rebase a longitudinal dataset to a single classification version

Converts a panel dataset that spans multiple classification versions
onto a single target version.

## Usage

``` r
rebase_series(
  data,
  period_col,
  code_col,
  value_cols,
  version_map,
  to,
  master_data,
  fun = sum,
  split = "population",
  value_type = c("additive", "ratio")
)
```

## Arguments

- data:

  A \`data.frame\` or \`data.table\`.

- period_col:

  Name of the period column (e.g. \`"year"\`).

- code_col:

  Name of the geographic code column.

- value_cols:

  Character vector of value column names to aggregate.

- version_map:

  Named list mapping each source classification identifier to the vector
  of period values where it applies. Every period present in \`data\`
  should be covered; uncovered periods are dropped with a warning.
  Example: “\`r list( "NIS_MUNICIPALITY_2019" = 2010:2024,
  "NIS_MUNICIPALITY_2025" = 2025:2030 ) “\`

- to:

  Target classification identifier (see \[classification_reference\]).

- master_data:

  Output from \[load_master_data()\].

- fun:

  Aggregation function applied when multiple source codes map to the
  same target code within a period (default: \`sum\`). For ratio
  variables (rates, averages) use \`mean\` and set \`value_type =
  "ratio"\`.

- split:

  How to handle 1:N split codes. One of:

  \`"population"\` (default)

  :   Use population weights registered via
      \[register_split_weights()\]. Falls back to equal weights with a
      warning if none are registered for the conversion pair.

  Any other character string

  :   Use the named variable from the \[register_split_weights()\]
      registry (e.g. \`"employment"\`).

  \`data.table\` with columns \`code_from\`, \`code_to\`, \`weight\`

  :   Explicit weights (see \[register_split_weights()\]).

  \`NULL\`

  :   Replicate values without distribution (old behaviour). A warning
      of class \`rcl_ambiguous_split\` is emitted.

- value_type:

  \`"additive"\` (default) or \`"ratio"\`. Additive variables (totals,
  counts) are multiplied by split weights. Ratio variables (rates,
  averages) are kept unchanged during splits; for N:1 merges, supply an
  appropriate \`fun\` (e.g. \`mean\`).

## Value

A \`data.table\` with columns \`period_col\`, \`code_col\`, and
\`value_cols\`, with all codes expressed in the \`to\` classification.

## Details

\*\*Merges (N:1)\*\* – several old codes map to one new code (e.g. two
2019 communes fused into one 2025 commune): values are aggregated with
\`fun\`.

\*\*Splits (1:N)\*\* – one old code maps to several new codes (e.g.
arrondissement Verviers 63000 -\> NUTS3 BE335 + BE336): values are
distributed proportionally according to \`split\`. Register weights with
\[register_split_weights()\] before calling this function when
population weights are needed.

The output only contains \`period_col\`, \`code_col\`, and
\`value_cols\`. Re-add labels afterwards with \[get_label()\] or a join.

## Warnings

- \`rcl_missing_periods\`:

  Some periods in \`data\` are not covered by \`version_map\` and will
  be dropped.

- \`rcl_unmatched_codes\`:

  Some codes have no mapping to the target classification and will be
  dropped; also emitted when a requested weight variable is not
  registered (falls back to equal weights).

- \`rcl_ambiguous_split\`:

  \`split = NULL\` and 1:N codes found: values are replicated. Pass
  \`split = "population"\` to distribute instead.

## See also

\[register_split_weights()\], \[split_ambiguous()\],
\[classification_reference\]

## Examples

``` r
# \donttest{
  master_data <- load_master_data()
#> Master data loaded from 'C:/Users/Dell/AppData/Local/Temp/Rtmp6rbXw4/temp_libpath26b420df5361/nbbbenuts/extdata': 581 communes NIS 2019, 565 NIS 2025, 589 NIS BEFORE_2019

  # Communes 11002 and 11007 merged into 11002 in NIS 2025
  panel <- data.table::data.table(
    year      = c(2022L, 2022L, 2022L, 2025L, 2025L),
    commune   = c(11002L, 11007L, 21004L, 11002L, 21004L),
    population = c(18000, 8500, 180000, 28000, 185000)
  )

  # Rebase to NIS 2025 -- pre-2025 values for 11002+11007 are summed
  rebase_series(
    panel,
    period_col  = "year",
    code_col    = "commune",
    value_cols  = "population",
    version_map = list("NIS_MUNICIPALITY_2019" = 2022L,
                       "NIS_MUNICIPALITY_2025" = 2025L),
    to          = "NIS_MUNICIPALITY_2025",
    master_data = master_data
  )
#>     year commune population
#>    <int>   <int>      <num>
#> 1:  2022   11002      26500
#> 2:  2022   21004     180000
#> 3:  2025   11002      28000
#> 4:  2025   21004     185000

  # -- Custom weights for a 1:N split ----------------------------------------
  # Arrondissement Verviers (63000) splits into two NUTS3 regions.
  # Use split_weights_template() to get the right structure, then fill in
  # your own weights before passing them to rebase_series().

  arr_data <- data.table::data.table(
    year  = c(2020L, 2021L),
    arr   = c(63000L, 63000L),
    emploi = c(120000, 122000)
  )

  # Step 1: get the template (equal weights, correct structure)
  tpl <- split_weights_template(
    "NIS_DISTRICT_2019", "NUTS_DISTRICT_2021", master_data
  )

  # Step 2: replace with population-based weights
  tpl[code_from == "63000" & code_to == "BE335", weight := 0.857]
#> Index: <code_to__code_from>
#>    code_from code_to weight
#>       <char>  <char>  <num>
#> 1:     63000   BE335  0.857
#> 2:     63000   BE336  0.500
  tpl[code_from == "63000" & code_to == "BE336", weight := 0.143]
#> Index: <code_to__code_from>
#>    code_from code_to weight
#>       <char>  <char>  <num>
#> 1:     63000   BE335  0.857
#> 2:     63000   BE336  0.143

  # Step 3a: pass weights directly (one-off use)
  rebase_series(
    arr_data,
    period_col  = "year",
    code_col    = "arr",
    value_cols  = "emploi",
    version_map = list("NIS_DISTRICT_2019" = 2020:2021),
    to          = "NUTS_DISTRICT_2021",
    master_data = master_data,
    split       = tpl
  )
#>     year    arr emploi
#>    <int> <char>  <num>
#> 1:  2020  BE335 102840
#> 2:  2021  BE335 104554
#> 3:  2020  BE336  17160
#> 4:  2021  BE336  17446

  # Step 3b: register for repeated use across the session
  register_split_weights(
    "NIS_DISTRICT_2019", "NUTS_DISTRICT_2021", tpl, variable = "population"
  )
#>   Registered split weights: NIS_DISTRICT_2019 -> NUTS_DISTRICT_2021 [variable: population, 2 entries]
  rebase_series(
    arr_data,
    period_col  = "year",
    code_col    = "arr",
    value_cols  = "emploi",
    version_map = list("NIS_DISTRICT_2019" = 2020:2021),
    to          = "NUTS_DISTRICT_2021",
    master_data = master_data
    # split = "population" is the default
  )
#>     year    arr emploi
#>    <int> <char>  <num>
#> 1:  2020  BE335 102840
#> 2:  2021  BE335 104554
#> 3:  2020  BE336  17160
#> 4:  2021  BE336  17446
# }
```
