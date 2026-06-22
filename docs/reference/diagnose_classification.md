# Diagnose geographic code coverage against a classification

Two modes:

## Usage

``` r
diagnose_classification(
  dt,
  code_col,
  master_data,
  classification = NULL,
  verbose = TRUE
)
```

## Arguments

- dt:

  data.table (or data.frame)

- code_col:

  Name of the column containing geographic codes

- master_data:

  Output from build_master_table()

- classification:

  Classification identifier (e.g. "NUTS_DISTRICT_2021"), or NULL to
  auto-rank all candidates.

- verbose:

  Print a formatted diagnostic report? Default TRUE.

## Value

Invisibly, a list with diagnostic details (see Value section).

## Details

\*\*Check mode\*\* (\`classification\` supplied): verifies that the
codes in \`code_col\` are aligned with the given classification. Reports
missing codes (reference codes absent from the dataset), unknown codes
(dataset codes not in the reference), and duplicates.

\*\*Detect mode\*\* (\`classification = NULL\`): ranks all known
classifications by how well they match the dataset codes and recommends
the closest one.

## Value (check mode)

- mode:

  "check"

- classification:

  Normalised classification identifier

- n_reference:

  Total codes in the reference set

- n_in_dataset:

  Reference codes found in the dataset

- n_missing:

  Reference codes absent from the dataset

- n_unknown:

  Dataset codes not in the reference

- n_duplicates:

  Codes appearing more than once

- coverage_rate:

  n_in_dataset / n_reference

- status:

  "COMPLETE", "INCOMPLETE", or "INCOMPLETE_WITH_UNKNOWNS"

- missing_codes:

  data.table of missing codes with labels

- unknown_codes:

  data.table of unrecognised codes

- duplicate_codes:

  data.table of duplicated codes with counts

## Value (detect mode)

- mode:

  "detect"

- recommendation:

  Best-matching classification

- candidates:

  data.table ranking all classifications

- detail:

  Full check-mode result for the top candidate

## Examples

``` r
# \donttest{
  master_data <- load_master_data()
#> Master data loaded from 'C:/Users/Dell/AppData/Local/Temp/Rtmp6rbXw4/temp_libpath26b420df5361/nbbbenuts/extdata': 581 communes NIS 2019, 565 NIS 2025, 589 NIS BEFORE_2019
  # Check mode
  nuts3_data <- data.table::data.table(nuts3 = c("BE100","BE211","BE332"), val = 1:3)
  diagnose_classification(nuts3_data, "nuts3", master_data,
                          classification = "NUTS_DISTRICT_2021")
#> 
#> ================================================================
#>   CLASSIFICATION DIAGNOSTIC
#> ================================================================
#>   Dataset        : 3 rows  |  column 'nuts3'
#>   Classification : NUTS_DISTRICT
#>   Version        : 2021
#>   Reference      : NUTS_DISTRICT_2021  (44 codes)
#> ================================================================
#>   Coverage   : 3 / 44  [#-------------------] 6.8%
#>   Unknown    : 0 code(s) in dataset not in reference
#>   Duplicates : 0 code(s) appearing more than once
#> 
#>   Missing codes (41) -- present in reference but absent from dataset:
#>     BE212         Arrondissement de Malines / Arrondissement Mechelen
#>     BE213         Arrondissement de Turnhout / Arrondissement Turnhout
#>     BE223         Arrondissement de Tongres / Arrondissement Tongeren
#>     BE224         Arrondissement de Hasselt / Arrondissement Hasselt
#>     BE225         Arrondissement de Maaseik / Arrondissement Maaseik
#>     BE231         Arrondissement d’Alost / Arrondissement Aalst
#>     BE232         Arrondissement de Termonde / Arrondissement Dendermonde
#>     BE233         Arrondissement d’Eeklo / Arrondissement Eeklo
#>     BE234         Arrondissement de Gand / Arrondissement Gent
#>     BE235         Arrondissement d’Audenarde / Arrondissement Oudenaarde
#>     BE236         Arrondissement de Saint-Nicolas / Arrondissement Sint-Niklaas
#>     BE241         Arrondissement de Hal-Vilvorde / Arrondissement Halle-Vilvoorde
#>     BE242         Arrondissement de Louvain / Arrondissement Leuven
#>     BE251         Arrondissement de Bruges / Arrondissement Brugge
#>     BE252         Arrondissement de Dixmude / Arrondissement Diksmuide
#>     BE253         Arrondissement d’Ypres / Arrondissement Ieper
#>     BE254         Arrondissement de Courtrai / Arrondissement Kortrijk
#>     BE255         Arrondissement d’Ostende / Arrondissement Oostende
#>     BE256         Arrondissement de Roulers / Arrondissement Roeselare
#>     BE257         Arrondissement de Tielt / Arrondissement Tielt
#>     ... (21 more)
#> 
#>   Status: !!  INCOMPLETE -- missing reference codes
#> ================================================================
#> 

  # Detect mode
  diagnose_classification(nuts3_data, "nuts3", master_data)
#> 
#> ================================================================
#>   CLASSIFICATION AUTO-DETECTION
#> ================================================================
#>   Dataset : 3 rows  |  column 'nuts3'
#> 
#>   Classification            Version        Match%    Cover%  Unknown%
#>   ------------------------------------------------------------------
#>   NUTS_DISTRICT             2021           100.0%      6.8%      0.0% <-- best
#>   NUTS_DISTRICT             2027            66.7%      4.5%     33.3%
#>   NBB_DISTRICT              2021             0.0%      0.0%    100.0%
#>   NIS_COUNTRY               --               0.0%      0.0%    100.0%
#>   NIS_DISTRICT              2019             0.0%      0.0%    100.0%
#>   NIS_DISTRICT              2025             0.0%      0.0%    100.0%
#>   NIS_DISTRICT              BEFORE_2019      0.0%      0.0%    100.0%
#>   NIS_MUNICIPALITY          2019             0.0%      0.0%    100.0%
#> 
#> ----------------------------------------------------------------
#>   Recommendation
#>     Classification : NUTS_DISTRICT
#>     Version        : 2021
#>     Identifier     : NUTS_DISTRICT_2021
#>     Coverage       : 3 / 44 codes present (6.8%)
#>     Missing codes  : BE212, BE213, BE223, BE224, BE225 ... (+36 more)
#> ================================================================
#> 
# }
```
