# List all available conversion paths

Returns a data.table with one row per declared edge in
`CONVERSION_GRAPH_EDGES`. The `perimeter_relation` column summarises the
spatial semantics of each edge (see
[`is_perimeter_preserving`](https://n0n3z.github.io/regionalclassification/reference/is_perimeter_preserving.md)):

- temporal:

  Same system, different edition.

- identity:

  Exact 1:1 correspondence, no splitting.

- nesting:

  Many fine units aggregate into one coarser unit (N:1).

- overlap:

  A source unit straddles multiple target units (1:N / M:N).

## Usage

``` r
list_available_conversions()
```

## Value

data.table with columns `from`, `to`, `relation`, `perimeter_relation`,
`notes`.

## Examples

``` r
list_available_conversions()
#>                             from                       to relation
#>                           <char>                   <char>   <char>
#>  1: NIS_MUNICIPALITY_BEFORE_2019 NIS_DISTRICT_BEFORE_2019      N:1
#>  2: NIS_MUNICIPALITY_BEFORE_2019   NIS_REGION_BEFORE_2019      N:1
#>  3:     NIS_DISTRICT_BEFORE_2019 NIS_PROVINCE_BEFORE_2019      N:1
#>  4:     NIS_PROVINCE_BEFORE_2019   NIS_REGION_BEFORE_2019      N:1
#>  5: NIS_MUNICIPALITY_BEFORE_2019       NUTS_DISTRICT_2021      N:1
#>  6: NIS_MUNICIPALITY_BEFORE_2019       NUTS_DISTRICT_2027      N:1
#>  7: NIS_MUNICIPALITY_BEFORE_2019    NIS_MUNICIPALITY_2019      N:1
#>  8:        NIS_MUNICIPALITY_2019        NIS_DISTRICT_2019      N:1
#>  9:        NIS_MUNICIPALITY_2019          NIS_REGION_2019      N:1
#> 10:            NIS_DISTRICT_2019        NIS_PROVINCE_2019      N:1
#> 11:            NIS_PROVINCE_2019          NIS_REGION_2019      N:1
#> 12:        NIS_MUNICIPALITY_2025        NIS_DISTRICT_2025      N:1
#> 13:        NIS_MUNICIPALITY_2025          NIS_REGION_2025      N:1
#> 14:            NIS_DISTRICT_2025        NIS_PROVINCE_2025      N:1
#> 15:            NIS_PROVINCE_2025          NIS_REGION_2025      N:1
#> 16:       NIS_REGION_BEFORE_2019              NIS_COUNTRY      N:1
#> 17:              NIS_REGION_2019              NIS_COUNTRY      N:1
#> 18:              NIS_REGION_2025              NIS_COUNTRY      N:1
#> 19:        NIS_MUNICIPALITY_2019   NUTS_MUNICIPALITY_2021      1:1
#> 20:       NUTS_MUNICIPALITY_2021       NUTS_DISTRICT_2021      N:1
#> 21:           NUTS_DISTRICT_2021       NUTS_PROVINCE_2021      N:1
#> 22:           NUTS_PROVINCE_2021         NUTS_REGION_2021      N:1
#> 23:             NUTS_REGION_2021             NUTS_COUNTRY      N:1
#> 24:            NIS_DISTRICT_2019       NUTS_DISTRICT_2021      1:N
#> 25:                       POSTAL    NIS_MUNICIPALITY_2019      N:1
#> 26:                       POSTAL    NIS_MUNICIPALITY_2025      N:1
#> 27:        NIS_MUNICIPALITY_2019    NIS_MUNICIPALITY_2025      N:1
#> 28:           NUTS_DISTRICT_2021        NBB_DISTRICT_2021      1:1
#> 29:            NIS_DISTRICT_2019        NBB_DISTRICT_2021      1:N
#> 30:           NUTS_DISTRICT_2027       NUTS_PROVINCE_2027      N:1
#> 31:           NUTS_PROVINCE_2027         NUTS_REGION_2027      N:1
#> 32:             NUTS_REGION_2027             NUTS_COUNTRY      N:1
#> 33:        NIS_MUNICIPALITY_2019       NUTS_DISTRICT_2027      N:1
#> 34:                       POSTAL       NUTS_DISTRICT_2027      N:1
#> 35:        NIS_MUNICIPALITY_2025       NUTS_DISTRICT_2027      N:1
#> 36:        NIS_MUNICIPALITY_2025       NUTS_PROVINCE_2027      N:1
#> 37:        NIS_MUNICIPALITY_2025         NUTS_REGION_2027      N:1
#> 38:        NIS_MUNICIPALITY_2025       NUTS_DISTRICT_2021      1:N
#> 39:        NIS_MUNICIPALITY_2025        NBB_DISTRICT_2021      N:1
#>                             from                       to relation
#>                           <char>                   <char>   <char>
#>     perimeter_relation
#>                 <char>
#>  1:            nesting
#>  2:            nesting
#>  3:            nesting
#>  4:            nesting
#>  5:            nesting
#>  6:            nesting
#>  7:           temporal
#>  8:            nesting
#>  9:            nesting
#> 10:            nesting
#> 11:            nesting
#> 12:            nesting
#> 13:            nesting
#> 14:            nesting
#> 15:            nesting
#> 16:            nesting
#> 17:            nesting
#> 18:            nesting
#> 19:           identity
#> 20:            nesting
#> 21:            nesting
#> 22:            nesting
#> 23:            nesting
#> 24:            overlap
#> 25:            nesting
#> 26:            nesting
#> 27:           temporal
#> 28:           identity
#> 29:            overlap
#> 30:            nesting
#> 31:            nesting
#> 32:            nesting
#> 33:            nesting
#> 34:            nesting
#> 35:            nesting
#> 36:            nesting
#> 37:            nesting
#> 38:            overlap
#> 39:            nesting
#>     perimeter_relation
#>                 <char>
#>                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                notes
#>                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               <char>
#>  1:                                                                                                                                                                                                                                                                                                                                                                                                                                                                 Derived from commune code: first 2 digits * 1000
#>  2:                                                                                                                                                                                                                                                                                                                                                                                                                                          Each commune belongs to exactly one region (N:1, direct column lookup).
#>  3:                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    Derived from REFNIS hierarchy
#>  4:                                                                                                                                                                                                                                                                                                                    Each province nests in exactly one region (N:1). Vlaams-Brabant (20001)->Flanders, Brabant wallon (20002)->Wallonia, Brussels pseudo-province (4000)->Brussels. No province 20000 since 1995.
#>  5:                                                                                                                                                                                                                                                                                                                                                  Many communes share one NUTS3 (N:1); the reverse NUTS3 -> commune is ambiguous. Uses historical NUTS assignments (DT_VLDT_STOP = 2019-01-01 for changed codes).
#>  6:                                                                                                                                                                                                                                                                             N:1 (same as BEFORE_2019->NUTS_DISTRICT_2021). Path: NIS_MUNICIPALITY_BEFORE_2019 -> NIS_MUNICIPALITY_2019 -> NIS_MUNICIPALITY_2025 -> NUTS_DISTRICT_2027. Uses the official REFNIS_2025-NUTS_2027 mapping, not a code-rename table.
#>  7:                                                                                                                                                                                                                                                                                                                                                            Unchanged communes: 1:1 (same code). Merged communes resolved via REFNIS_CHANGE_BEFORE2019.xlsx. N:1 forward (no splits); reverse is 1:N (ambiguous).
#>  8:                                                                                                                                                                                                                                                                                                                                                                                                                                                                 Derived from commune code: first 2 digits * 1000
#>  9:                                                                                                                                                                                                                                                                                                                                                                                                                                          Each commune belongs to exactly one region (N:1, direct column lookup).
#> 10:                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    Derived from REFNIS hierarchy
#> 11:                                                                                                                                                                                                                                                                                                                    Each province nests in exactly one region (N:1). Vlaams-Brabant (20001)->Flanders, Brabant wallon (20002)->Wallonia, Brussels pseudo-province (4000)->Brussels. No province 20000 since 1995.
#> 12:                                                                                                                                                                                                                                                                                                                                                                                                                                                                 Derived from commune code: first 2 digits * 1000
#> 13:                                                                                                                                                                                                                                                                                                                                                                                                                                          Each commune belongs to exactly one region (N:1, direct column lookup).
#> 14:                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    Derived from REFNIS hierarchy
#> 15:                                                                                                                                                                                                                                                                                                                    Each province nests in exactly one region (N:1). Vlaams-Brabant (20001)->Flanders, Brabant wallon (20002)->Wallonia, Brussels pseudo-province (4000)->Brussels. No province 20000 since 1995.
#> 16:                                                                                                                                                                                                                                                                                                                                                                                                                                                                 All regions aggregate to Belgium (NIS code 1000)
#> 17:                                                                                                                                                                                                                                                                                                                                                                                                                                                                 All regions aggregate to Belgium (NIS code 1000)
#> 18:                                                                                                                                                                                                                                                                                                                                                                                                                                                                 All regions aggregate to Belgium (NIS code 1000)
#> 19:                                                                                                                                                                                                                                                                                                                                                                                                                                                                          Direct 1:1 mapping from CONVERSION file
#> 20:                                                                                                                                                                                                                                                                                                                                                                                                                                                                           LAU to NUTS3 from CD_LVL_SUP hierarchy
#> 21:                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     Hierarchical
#> 22:                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     Hierarchical
#> 23:                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     Hierarchical
#> 24:                                                                                                                                                                                                                                                                                                                                Verviers (63000) maps to BE335 (francophone) AND BE336 (germanophone). All other arrondissements are 1:1.  Overall: 1:N (not M:N). Reverse NUTS3->arrondissement is N:1 (simple).
#> 25:                                                                                                                                                                                                                                                                                                                                                                                                                                                          Each postal code maps to one commune (KEEP_UNIQUE=TRUE)
#> 26:                                                                                                                                                                                                                                                                                                                                                                                                                                                          Each postal code maps to one commune (KEEP_UNIQUE=TRUE)
#> 27:                                                                                                                                                                                                                                                              Each 2019 commune maps to exactly one 2025 commune (N:1 forward). Fusions: multiple 2019 communes merge into one 2025 commune. District/province changes: commune keeps its code or gets a new one. Reverse (2025->2019) is 1:N for fused communes.
#> 28:                                                                                                                                                                                                                                                                                                                                                                                                           Direct mapping from NUTS3 to internal 2-digit code. Verviers is split: BE335->65 (FR), BE336->66 (DE).
#> 29:                                                                                                                                                                                                                                                                                                                                                                                                Verviers (63000) -> internal 65 (FR) + 66 (DE). All other arrondissements are 1:1.  Reverse INTERNAL->arr is N:1.
#> 30:                                                                                                                                                                                                                                                                                                                                                                                                                                                                  Hierarchical (first 4 chars of NUTS3 2027 code)
#> 31:                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     Hierarchical
#> 32:                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     Hierarchical
#> 33:                                                                                                                                                                                                                                                    Path: NIS_MUNICIPALITY_2019 -> NIS_MUNICIPALITY_2025 -> NUTS_DISTRICT_2027. Uses the official REFNIS_2025-NUTS_2027.xlsx mapping. NOT via a NUTS_DISTRICT_2021 code-rename table (would be wrong for 3 communes that changed province between 2019 and 2025).
#> 34:                                                                                                                                                                                                                                                                                                                                                                                                                               Via POSTAL -> NIS_MUNICIPALITY_2019 -> NIS_MUNICIPALITY_2025 -> NUTS_DISTRICT_2027
#> 35:                                                                                                                                                                                                                                                                                                                                                                                                                                             Direct mapping via REFNIS_2025-NUTS_2027.xlsx (hierarchical format).
#> 36:                                                                                                                                                                                                                                                                                                                                                                                                                                            Via NIS_MUNICIPALITY_2025 -> NUTS_DISTRICT_2027 -> NUTS_PROVINCE_2027
#> 37:                                                                                                                                                                                                                                                                                                                                                                                                                                              Via NIS_MUNICIPALITY_2025 -> NUTS_DISTRICT_2027 -> NUTS_REGION_2027
#> 38: 3 NIS 2025 communes (46029, 46030, 71072) fuse localities from different NUTS_DISTRICT_2021 regions; each maps to N NUTS3 targets (1:N). All other 564 communes are unambiguous (N:1). Use allow_ambiguous = TRUE; register weights via register_split_weights() for proportional splits. no_reverse = TRUE: the reverse NUTS_DISTRICT_2021 -> NIS_MUNICIPALITY_2025 is 1:N (many communes per NUTS3) and would create a spurious simple path NUTS_DISTRICT_2021 -> NIS_MUNICIPALITY_2025 -> NUTS_DISTRICT_2027.
#> 39:                                                                                                                                                                                                                                                                                                                                                                                cd_arr_internal backfilled onto 2025 master from constituent 2019 communes. Same uniqueness logic as NUTS_DISTRICT_2021 backfill.
#>                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                notes
#>                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               <char>
```
