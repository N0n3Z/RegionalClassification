# Visualize the classification relationship graph

Creates an interactive network graph showing all classifications, their
versions, and the relationships between them. Green edges = simple (1:1
or N:1), red edges = ambiguous (M:N or 1:N).

## Usage

``` r
visualize_classification_graph(
  highlight_from = NULL,
  highlight_to = NULL,
  output_file = NULL
)
```

## Arguments

- highlight_from:

  Optional: highlight paths from this classification

- highlight_to:

  Optional: highlight paths to this classification

- output_file:

  Optional: save to HTML file

## Value

visNetwork object (if visNetwork is available), otherwise a text summary

## Examples

``` r
# \donttest{
  visualize_classification_graph()
#> Package 'visNetwork' not installed. Showing text representation.
#> 
#> ========================================================
#>   CLASSIFICATION GEOGRAPHIQUE - SCHEMA DES RELATIONS
#> ========================================================
#> 
#> --- NIS Hierarchy (2019 & 2025) ---
#>   Commune -> Arrondissement -> Province -> Region
#>   (N:1 a chaque etape)
#> 
#> --- NUTS Hierarchy (2021) ---
#>   LAU -> NUTS3 -> NUTS2 -> NUTS1 -> NUTS_COUNTRY
#>   (N:1 a chaque etape)
#> 
#> --- Cross-classification links ---
#>   [OK] NIS_MUNICIPALITY_BEFORE_2019 -> NUTS_DISTRICT_2021 (N:1)
#>   [OK] NIS_MUNICIPALITY_BEFORE_2019 -> NUTS_DISTRICT_2027 (N:1)
#>   [OK] NIS_MUNICIPALITY_2019 -> NUTS_MUNICIPALITY_2021 (1:1)
#>   [!!] NIS_DISTRICT_2019 -> NUTS_DISTRICT_2021 (1:N)
#>        Note: Verviers (63000) maps to BE335 (francophone) AND BE336 (germanophone). All other arrondissements are 1:1.  Overall: 1:N (not M:N). Reverse NUTS3->arrondissement is N:1 (simple).
#>   [OK] POSTAL -> NIS_MUNICIPALITY_2019 (N:1)
#>   [OK] POSTAL -> NIS_MUNICIPALITY_2025 (N:1)
#>   [OK] NUTS_DISTRICT_2021 -> NBB_DISTRICT_2021 (1:1)
#>   [!!] NIS_DISTRICT_2019 -> NBB_DISTRICT_2021 (1:N)
#>        Note: Verviers (63000) -> internal 65 (FR) + 66 (DE). All other arrondissements are 1:1.  Reverse INTERNAL->arr is N:1.
#>   [OK] NIS_MUNICIPALITY_2019 -> NUTS_DISTRICT_2027 (N:1)
#>   [OK] POSTAL -> NUTS_DISTRICT_2027 (N:1)
#>   [OK] NIS_MUNICIPALITY_2025 -> NUTS_DISTRICT_2027 (N:1)
#>   [OK] NIS_MUNICIPALITY_2025 -> NUTS_PROVINCE_2027 (N:1)
#>   [OK] NIS_MUNICIPALITY_2025 -> NUTS_REGION_2027 (N:1)
#>   [!!] NIS_MUNICIPALITY_2025 -> NUTS_DISTRICT_2021 (1:N)
#>        Note: 3 NIS 2025 communes (46029, 46030, 71072) fuse localities from different NUTS_DISTRICT_2021 regions; each maps to N NUTS3 targets (1:N). All other 564 communes are unambiguous (N:1). Use allow_ambiguous = TRUE; register weights via register_split_weights() for proportional splits. no_reverse = TRUE: the reverse NUTS_DISTRICT_2021 -> NIS_MUNICIPALITY_2025 is 1:N (many communes per NUTS3) and would create a spurious simple path NUTS_DISTRICT_2021 -> NIS_MUNICIPALITY_2025 -> NUTS_DISTRICT_2027.
#>   [OK] NIS_MUNICIPALITY_2025 -> NBB_DISTRICT_2021 (N:1)
#> 
#> --- Legende ---
#>   [OK] = Conversion simple (1:1 ou N:1)
#>   [!!] = Conversion ambigue (M:N ou 1:N) - necessite des choix
#> 
  visualize_classification_graph(highlight_from = "NIS_MUNICIPALITY_2019")
#> Package 'visNetwork' not installed. Showing text representation.
#> 
#> ========================================================
#>   CLASSIFICATION GEOGRAPHIQUE - SCHEMA DES RELATIONS
#> ========================================================
#> 
#> --- NIS Hierarchy (2019 & 2025) ---
#>   Commune -> Arrondissement -> Province -> Region
#>   (N:1 a chaque etape)
#> 
#> --- NUTS Hierarchy (2021) ---
#>   LAU -> NUTS3 -> NUTS2 -> NUTS1 -> NUTS_COUNTRY
#>   (N:1 a chaque etape)
#> 
#> --- Cross-classification links ---
#>   [OK] NIS_MUNICIPALITY_BEFORE_2019 -> NUTS_DISTRICT_2021 (N:1)
#>   [OK] NIS_MUNICIPALITY_BEFORE_2019 -> NUTS_DISTRICT_2027 (N:1)
#>   [OK] NIS_MUNICIPALITY_2019 -> NUTS_MUNICIPALITY_2021 (1:1)
#>   [!!] NIS_DISTRICT_2019 -> NUTS_DISTRICT_2021 (1:N)
#>        Note: Verviers (63000) maps to BE335 (francophone) AND BE336 (germanophone). All other arrondissements are 1:1.  Overall: 1:N (not M:N). Reverse NUTS3->arrondissement is N:1 (simple).
#>   [OK] POSTAL -> NIS_MUNICIPALITY_2019 (N:1)
#>   [OK] POSTAL -> NIS_MUNICIPALITY_2025 (N:1)
#>   [OK] NUTS_DISTRICT_2021 -> NBB_DISTRICT_2021 (1:1)
#>   [!!] NIS_DISTRICT_2019 -> NBB_DISTRICT_2021 (1:N)
#>        Note: Verviers (63000) -> internal 65 (FR) + 66 (DE). All other arrondissements are 1:1.  Reverse INTERNAL->arr is N:1.
#>   [OK] NIS_MUNICIPALITY_2019 -> NUTS_DISTRICT_2027 (N:1)
#>   [OK] POSTAL -> NUTS_DISTRICT_2027 (N:1)
#>   [OK] NIS_MUNICIPALITY_2025 -> NUTS_DISTRICT_2027 (N:1)
#>   [OK] NIS_MUNICIPALITY_2025 -> NUTS_PROVINCE_2027 (N:1)
#>   [OK] NIS_MUNICIPALITY_2025 -> NUTS_REGION_2027 (N:1)
#>   [!!] NIS_MUNICIPALITY_2025 -> NUTS_DISTRICT_2021 (1:N)
#>        Note: 3 NIS 2025 communes (46029, 46030, 71072) fuse localities from different NUTS_DISTRICT_2021 regions; each maps to N NUTS3 targets (1:N). All other 564 communes are unambiguous (N:1). Use allow_ambiguous = TRUE; register weights via register_split_weights() for proportional splits. no_reverse = TRUE: the reverse NUTS_DISTRICT_2021 -> NIS_MUNICIPALITY_2025 is 1:N (many communes per NUTS3) and would create a spurious simple path NUTS_DISTRICT_2021 -> NIS_MUNICIPALITY_2025 -> NUTS_DISTRICT_2027.
#>   [OK] NIS_MUNICIPALITY_2025 -> NBB_DISTRICT_2021 (N:1)
#> 
#> --- Legende ---
#>   [OK] = Conversion simple (1:1 ou N:1)
#>   [!!] = Conversion ambigue (M:N ou 1:N) - necessite des choix
#> 
  visualize_classification_graph(output_file = "classification_graph.html")
#> Package 'visNetwork' not installed. Showing text representation.
#> 
#> ========================================================
#>   CLASSIFICATION GEOGRAPHIQUE - SCHEMA DES RELATIONS
#> ========================================================
#> 
#> --- NIS Hierarchy (2019 & 2025) ---
#>   Commune -> Arrondissement -> Province -> Region
#>   (N:1 a chaque etape)
#> 
#> --- NUTS Hierarchy (2021) ---
#>   LAU -> NUTS3 -> NUTS2 -> NUTS1 -> NUTS_COUNTRY
#>   (N:1 a chaque etape)
#> 
#> --- Cross-classification links ---
#>   [OK] NIS_MUNICIPALITY_BEFORE_2019 -> NUTS_DISTRICT_2021 (N:1)
#>   [OK] NIS_MUNICIPALITY_BEFORE_2019 -> NUTS_DISTRICT_2027 (N:1)
#>   [OK] NIS_MUNICIPALITY_2019 -> NUTS_MUNICIPALITY_2021 (1:1)
#>   [!!] NIS_DISTRICT_2019 -> NUTS_DISTRICT_2021 (1:N)
#>        Note: Verviers (63000) maps to BE335 (francophone) AND BE336 (germanophone). All other arrondissements are 1:1.  Overall: 1:N (not M:N). Reverse NUTS3->arrondissement is N:1 (simple).
#>   [OK] POSTAL -> NIS_MUNICIPALITY_2019 (N:1)
#>   [OK] POSTAL -> NIS_MUNICIPALITY_2025 (N:1)
#>   [OK] NUTS_DISTRICT_2021 -> NBB_DISTRICT_2021 (1:1)
#>   [!!] NIS_DISTRICT_2019 -> NBB_DISTRICT_2021 (1:N)
#>        Note: Verviers (63000) -> internal 65 (FR) + 66 (DE). All other arrondissements are 1:1.  Reverse INTERNAL->arr is N:1.
#>   [OK] NIS_MUNICIPALITY_2019 -> NUTS_DISTRICT_2027 (N:1)
#>   [OK] POSTAL -> NUTS_DISTRICT_2027 (N:1)
#>   [OK] NIS_MUNICIPALITY_2025 -> NUTS_DISTRICT_2027 (N:1)
#>   [OK] NIS_MUNICIPALITY_2025 -> NUTS_PROVINCE_2027 (N:1)
#>   [OK] NIS_MUNICIPALITY_2025 -> NUTS_REGION_2027 (N:1)
#>   [!!] NIS_MUNICIPALITY_2025 -> NUTS_DISTRICT_2021 (1:N)
#>        Note: 3 NIS 2025 communes (46029, 46030, 71072) fuse localities from different NUTS_DISTRICT_2021 regions; each maps to N NUTS3 targets (1:N). All other 564 communes are unambiguous (N:1). Use allow_ambiguous = TRUE; register weights via register_split_weights() for proportional splits. no_reverse = TRUE: the reverse NUTS_DISTRICT_2021 -> NIS_MUNICIPALITY_2025 is 1:N (many communes per NUTS3) and would create a spurious simple path NUTS_DISTRICT_2021 -> NIS_MUNICIPALITY_2025 -> NUTS_DISTRICT_2027.
#>   [OK] NIS_MUNICIPALITY_2025 -> NBB_DISTRICT_2021 (N:1)
#> 
#> --- Legende ---
#>   [OK] = Conversion simple (1:1 ou N:1)
#>   [!!] = Conversion ambigue (M:N ou 1:N) - necessite des choix
#> 
# }
```
