# Build a split weights template for an ambiguous conversion pair

Returns a \`data.table(code_from, code_to, weight)\` pre-filled with
equal weights for every ambiguous (1:N) code in the \`from -\> to\`
conversion. Edit the \`weight\` column and pass the result to
\[register_split_weights()\] or directly to the \`split\` argument of
\[rebase_series()\].

## Usage

``` r
split_weights_template(from, to, master_data)
```

## Arguments

- from:

  Source classification identifier (see \[classification_reference\]).

- to:

  Target classification identifier.

- master_data:

  Output from \[load_master_data()\].

## Value

A \`data.table\` with columns \`code_from\` (character), \`code_to\`
(character), and \`weight\` (numeric, equal weights summing to 1 per
\`code_from\`). Returns an empty table (with a message) when no
ambiguous codes exist for the pair.

## Details

Only codes that actually produce multiple target codes appear in the
template; unambiguous (1:1 or N:1) codes are omitted since they never
need splitting.

## See also

\[register_split_weights()\], \[rebase_series()\], \[split_ambiguous()\]

## Examples

``` r
# \donttest{
  master_data <- load_master_data()
#> Master data loaded from 'C:/Users/Dell/AppData/Local/Temp/RtmpMFZPCn/temp_libpath168c5fac3201/nbbbenuts/extdata': 581 communes NIS 2019, 565 NIS 2025, 589 NIS BEFORE_2019

  # 1. Inspect the template -- equal weights are the starting point
  tpl <- split_weights_template(
    "NIS_DISTRICT_2019", "NUTS_DISTRICT_2021", master_data
  )
  #    code_from code_to weight
  # 1:     63000   BE335    0.5
  # 2:     63000   BE336    0.5

  # 2. Replace equal weights with population-based values
  #    (Verviers: ~85.7 % francophone / ~14.3 % germanophone)
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

  # 3a. Register for repeated use
  register_split_weights(
    "NIS_DISTRICT_2019", "NUTS_DISTRICT_2021", tpl, variable = "population"
  )
#>   Registered split weights: NIS_DISTRICT_2019 -> NUTS_DISTRICT_2021 [variable: population, 2 entries]

  # 3b. Or pass directly to split_ambiguous
  arr_data <- data.table::data.table(
    year = c(2020L, 2021L), arr = c(63000L, 63000L), emploi = c(120000, 122000)
  )
  split_ambiguous(arr_data, "arr", value_cols = "emploi",
                  from = "NIS_DISTRICT_2019", to = "NUTS_DISTRICT_2021",
                  master_data = master_data, weights = tpl, verbose = FALSE)
#>     year   arr emploi cd_nuts3_2021
#>    <int> <int>  <num>        <char>
#> 1:  2020 63000 102840         BE335
#> 2:  2021 63000 104554         BE335
#> 3:  2020 63000  17160         BE336
#> 4:  2021 63000  17446         BE336
# }
```
