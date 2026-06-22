# Dirty communes dataset – NIS 2019 (with deliberate data-quality issues)

A purposely-flawed dataset based on NIS 2019 commune codes, designed to
showcase \`diagnose_classification()\`, \`validate_codes()\`, and
\`detect_classification()\`. Contains four categories of issues:

## Usage

``` r
rc_dirty_municipalities_2019
```

## Format

A \`data.table\` with 319 rows and 5 columns:

- cd_commune:

  Integer. NIS commune code (may be NA or from NIS 2025).

- population:

  Integer. Resident population (fictional; may be NA).

- emplois:

  Integer. Number of jobs (fictional).

- masse_sal:

  Numeric. Total wage bill in EUR (fictional).

- taux_activite:

  Numeric. Activity rate, 0–1 (fictional).

## Details

1\. \*\*Duplicate rows\*\* – 5 communes appear twice. 2.
\*\*Wrong-version codes\*\* – 4 codes that exist in NIS 2025 but not in
2019 (codes introduced by post-2019 mergers). 3. \*\*NA code\*\* – 2
rows with \`NA\` in the code column. 4. \*\*NA value\*\* – 8 rows with
\`NA\` in the \`population\` column.

Rows are shuffled so the issues are not clustered at the end.

## See also

\[rc_full_municipalities_2019\], \[diagnose_classification()\],
\[validate_codes()\], \[detect_classification()\]

## Examples

``` r
data(rc_dirty_municipalities_2019)

# \donttest{
  master_data <- load_master_data()
#> Master data loaded from 'C:/Users/Dell/AppData/Local/Temp/Rtmp6rbXw4/temp_libpath26b420df5361/nbbbenuts/extdata': 581 communes NIS 2019, 565 NIS 2025, 589 NIS BEFORE_2019

  # Auto-detect and diagnose the classification
  diagnose_classification(rc_dirty_municipalities_2019, "cd_commune", master_data)
#> 
#> ================================================================
#>   CLASSIFICATION AUTO-DETECTION
#> ================================================================
#>   Dataset : 319 rows  |  column 'cd_commune'
#> 
#>   Classification            Version        Match%    Cover%  Unknown%
#>   ------------------------------------------------------------------
#>   NIS_MUNICIPALITY          2019            98.0%     51.3%      2.0% <-- best
#>   NUTS_MUNICIPALITY         2021            98.0%     51.3%      2.0%
#>   NIS_MUNICIPALITY          BEFORE_2019     94.7%     48.9%      5.3%
#>   NIS_MUNICIPALITY          2025            93.4%     50.3%      6.6%
#>   NIS_PROVINCE              2019             0.7%     18.2%     99.3%
#>   NIS_PROVINCE              2025             0.7%     18.2%     99.3%
#>   NIS_PROVINCE              BEFORE_2019      0.7%     18.2%     99.3%
#>   NBB_DISTRICT              2021             0.0%      0.0%    100.0%
#> 
#> ----------------------------------------------------------------
#>   Recommendation
#>     Classification : NIS_MUNICIPALITY
#>     Version        : 2019
#>     Identifier     : NIS_MUNICIPALITY_2019
#>     Coverage       : 298 / 581 codes present (51.3%)
#>     Missing codes  : 11004, 11007, 11008, 11016, 11018 ... (+278 more)
#> ================================================================
#> 

  # Check which codes are unknown in NIS 2019
  validate_codes(rc_dirty_municipalities_2019$cd_commune,
                 "NIS_MUNICIPALITY_2019", master_data)
#>        code is_valid
#>      <char>   <lgcl>
#>   1:  24014     TRUE
#>   2:  73083     TRUE
#>   3:  57097     TRUE
#>   4:  61012     TRUE
#>   5:  25121     TRUE
#>  ---                
#> 315:  13031     TRUE
#> 316:  34023     TRUE
#> 317:  13040     TRUE
#> 318:  11009     TRUE
#> 319:  84059     TRUE
# }
```
