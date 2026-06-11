# ==============================================================================
# classifications.R - Reference documentation for classification identifiers
# ==============================================================================

#' Classification identifier conventions
#'
#' @description
#' All functions that accept a classification name (`from`, `to`, `classification`,
#' etc.) use a **single string** identifier -- not two separate `system`/`version`
#' parameters. Identifiers are **case-insensitive** (converted to uppercase
#' internally) but must match a canonical name exactly; unrecognised identifiers
#' raise an error of class `rcl_invalid_classification`.
#'
#' ## Naming pattern
#'
#' Canonical identifiers follow the pattern `SYSTEM_LEVEL_VERSION`:
#'
#' | Part      | Examples                                                       |
#' |-----------|----------------------------------------------------------------|
#' | SYSTEM    | `NIS`, `NUTS`, `POSTAL`, `NBB`                                 |
#' | LEVEL     | `MUNICIPALITY`, `DISTRICT`, `PROVINCE`, `REGION`, `COUNTRY`, `LAU` |
#' | VERSION   | `2019`, `2025`, `2021`, `2027`, `BEFORE_2019`                  |
#'
#' When the level is unambiguous (`POSTAL` has only one level, `NUTS_COUNTRY` has no
#' version variants), the extra parts are omitted.
#'
#' ## NIS classifications (Statbel)
#'
#' | Canonical identifier             | Description                     |
#' |----------------------------------|---------------------------------|
#' | `NIS_MUNICIPALITY_BEFORE_2019`        | Communes before 2019 fusions    |
#' | `NIS_DISTRICT_BEFORE_2019` | Arrondissements (pre-2019)      |
#' | `NIS_PROVINCE_BEFORE_2019`       | Provinces (pre-2019)            |
#' | `NIS_REGION_BEFORE_2019`         | Regions (pre-2019)              |
#' | `NIS_MUNICIPALITY_2019`               | Communes (2019 version)         |
#' | `NIS_DISTRICT_2019`        | Arrondissements (2019)          |
#' | `NIS_PROVINCE_2019`              | Provinces (2019)                |
#' | `NIS_REGION_2019`                | Regions (2019)                  |
#' | `NIS_MUNICIPALITY_2025`               | Communes (2025 version)         |
#' | `NIS_DISTRICT_2025`        | Arrondissements (2025)          |
#' | `NIS_PROVINCE_2025`              | Provinces (2025)                |
#' | `NIS_REGION_2025`                | Regions (2025)                  |
#' | `NIS_COUNTRY`                    | Country level (Belgium, NIS code 1000) -- version-invariant |
#'
#' ## NUTS classifications (Eurostat)
#'
#' | Canonical identifier | Description                            |
#' |----------------------|----------------------------------------|
#' | `NUTS_MUNICIPALITY_2021`      | Local Administrative Units (2021) -- in Belgium, bijection 1:1 with `NIS_MUNICIPALITY_2019` (same territory, Eurostat coding) |
#' | `NUTS_DISTRICT_2021`         | NUTS level 3 (2021)                    |
#' | `NUTS_PROVINCE_2021`         | NUTS level 2 (2021)                    |
#' | `NUTS_REGION_2021`         | NUTS level 1 (2021)                    |
#' | `NUTS_COUNTRY`              | Country level (BE) -- version-invariant |
#' | `NUTS_DISTRICT_2027`         | NUTS level 3 (2027)                    |
#' | `NUTS_PROVINCE_2027`         | NUTS level 2 (2027)                    |
#' | `NUTS_REGION_2027`         | NUTS level 1 (2027)                    |
#'
#' ## Other classifications
#'
#' | Canonical identifier     | Description                                          |
#' |--------------------------|------------------------------------------------------|
#' | `POSTAL`                 | Belgian postal codes (bpost)                         |
#' | `NBB_DISTRICT_2021`| 2-digit internal code; Verviers split: 65=FR, 66=DE  |
#'
#' ## Available conversions
#'
#' The table below lists all supported conversion paths. **Simple** ((y)) means a
#' deterministic N:1 or 1:1 mapping; **Ambiguous** ((!)) means a M:N mapping that
#' requires weighted splitting (use [split_ambiguous_weights()]).
#'
#' | From                          | To                               | Type   |
#' |-------------------------------|----------------------------------|--------|
#' | `NIS_MUNICIPALITY_BEFORE_2019`     | `NIS_DISTRICT_BEFORE_2019` | (y) N:1  |
#' | `NIS_MUNICIPALITY_BEFORE_2019`     | `NIS_REGION_BEFORE_2019`         | (y) N:1  |
#' | `NIS_DISTRICT_BEFORE_2019` | `NIS_PROVINCE_BEFORE_2019`    | (y) N:1  |
#' | `NIS_PROVINCE_BEFORE_2019`    | `NIS_REGION_BEFORE_2019`         | (!) M:N  |
#' | `NIS_MUNICIPALITY_BEFORE_2019`     | `NIS_MUNICIPALITY_2019`               | (y) N:1  |
#' | `NIS_MUNICIPALITY_BEFORE_2019`     | `NUTS_DISTRICT_2021`                     | (y) N:1  |
#' | `NIS_MUNICIPALITY_BEFORE_2019`     | `NUTS_DISTRICT_2027`                     | (y) N:1  |
#' | `NIS_MUNICIPALITY_2019`            | `NIS_DISTRICT_2019`        | (y) N:1  |
#' | `NIS_MUNICIPALITY_2019`            | `NIS_REGION_2019`                | (y) N:1  |
#' | `NIS_DISTRICT_2019`     | `NIS_PROVINCE_2019`              | (y) N:1  |
#' | `NIS_PROVINCE_2019`           | `NIS_REGION_2019`                | (!) M:N  |
#' | `NIS_MUNICIPALITY_2019`            | `NIS_MUNICIPALITY_2025`               | (y) N:1  |
#' | `NIS_MUNICIPALITY_2019`            | `NUTS_MUNICIPALITY_2021`                  | (y) 1:1  |
#' | `NIS_MUNICIPALITY_2019`            | `NUTS_DISTRICT_2027`                     | (y) N:1  |
#' | `NIS_DISTRICT_2019`     | `NUTS_DISTRICT_2021`                     | (!) 1:N  |
#' | `NIS_DISTRICT_2019`     | `NBB_DISTRICT_2021`        | (!) 1:N  |
#' | `NIS_MUNICIPALITY_2025`            | `NIS_DISTRICT_2025`        | (y) N:1  |
#' | `NIS_MUNICIPALITY_2025`            | `NIS_REGION_2025`                | (y) N:1  |
#' | `NIS_DISTRICT_2025`     | `NIS_PROVINCE_2025`              | (y) N:1  |
#' | `NIS_PROVINCE_2025`           | `NIS_REGION_2025`                | (!) M:N  |
#' | `NIS_REGION_BEFORE_2019`      | `NIS_COUNTRY`                    | (y) N:1  |
#' | `NIS_REGION_2019`             | `NIS_COUNTRY`                    | (y) N:1  |
#' | `NIS_REGION_2025`             | `NIS_COUNTRY`                    | (y) N:1  |
#' | `NIS_MUNICIPALITY_2025`            | `NUTS_DISTRICT_2027`                     | (y) N:1  |
#' | `NIS_MUNICIPALITY_2025`            | `NUTS_PROVINCE_2027`                     | (y) N:1  |
#' | `NIS_MUNICIPALITY_2025`            | `NUTS_REGION_2027`                     | (y) N:1  |
#' | `NUTS_MUNICIPALITY_2021`               | `NUTS_DISTRICT_2021`                     | (y) N:1  |
#' | `NUTS_DISTRICT_2021`                  | `NUTS_PROVINCE_2021`                     | (y) N:1  |
#' | `NUTS_PROVINCE_2021`                  | `NUTS_REGION_2021`                     | (y) N:1  |
#' | `NUTS_REGION_2021`                  | `NUTS_COUNTRY`                          | (y) N:1  |
#' | `NUTS_DISTRICT_2027`                  | `NUTS_PROVINCE_2027`                     | (y) N:1  |
#' | `NUTS_PROVINCE_2027`                  | `NUTS_REGION_2027`                     | (y) N:1  |
#' | `NUTS_REGION_2027`                  | `NUTS_COUNTRY`                          | (y) N:1  |
#' | `NUTS_DISTRICT_2021`                  | `NBB_DISTRICT_2021`        | (y) 1:1  |
#' | `POSTAL`                      | `NIS_MUNICIPALITY_2019`               | (y) N:1  |
#' | `POSTAL`                      | `NIS_MUNICIPALITY_2025`               | (y) N:1  |
#' | `POSTAL`                      | `NUTS_DISTRICT_2027`                     | (y) N:1  |
#'
#' **Note on NUTS_DISTRICT_2021 <-> NUTS_DISTRICT_2027:** there is **no direct conversion** between
#' these two NUTS3 versions. Three Belgian communes changed province between 2019
#' and 2025, shifting their NUTS3 region. The correct path is always via NIS
#' municipalities: `NUTS_DISTRICT_2021` -> `NIS_MUNICIPALITY_2025` -> `NUTS_DISTRICT_2027`
#' (ambiguous, requires `allow_ambiguous = TRUE`).
#'
#' **Note on province -> region:** Province 20000 (Brabant) spans the Brussels,
#' Flemish and Walloon regions, making province -> region M:N. Use municipality-level
#' paths (`NIS_MUNICIPALITY_* -> NIS_REGION_*`) for unambiguous region lookups.
#'
#' **Note on NIS_DISTRICT -> NUTS_DISTRICT/NBB_DISTRICT:** Only Verviers (63000) maps to
#' two targets (1:N). The reverse NUTS_DISTRICT -> NIS_DISTRICT is N:1 (simple).
#'
#' **Note on NUTS level naming (Belgium-specific):** In this package NUTS_PROVINCE
#' corresponds to NUTS2 and NUTS_REGION to NUTS1 — terminology chosen to match the
#' Belgian administrative vocabulary. These names are not universal NUTS conventions.
#'
#' Multi-step paths (e.g. `POSTAL` -> `NIS_REGION_2019`) are resolved
#' automatically by chaining the edges above.
#'
#' ## Quick reference
#'
#' ```r
#' # List all valid identifiers programmatically:
#' sort(nbbbenuts:::VALID_CLASSIFICATIONS)
#'
#' # Check whether a conversion path exists and whether it is simple:
#' check_conversion_path("NIS_MUNICIPALITY_2019", "NUTS_DISTRICT_2021")
#'
#' # See the full conversion graph interactively:
#' visualize_classification_graph()
#'
#' # See the full feasibility matrix:
#' visualize_conversion_matrix()
#' ```
#'
#' @name classification_reference
#' @aliases classification_conventions classification_identifiers
NULL
