# ==============================================================================
# classifications.R - Reference documentation for classification identifiers
# ==============================================================================

#' Classification identifier conventions
#'
#' @description
#' All functions that accept a classification name (`from`, `to`, `classification`,
#' etc.) use a **single string** identifier — not two separate `system`/`version`
#' parameters. Identifiers are **case-insensitive** (converted to uppercase
#' internally) but must match a canonical name exactly; unrecognised identifiers
#' raise an error of class `rcl_invalid_classification`.
#'
#' ## Naming pattern
#'
#' Canonical identifiers follow the pattern `SYSTEM_LEVEL_VERSION`:
#'
#' | Part      | Examples                                 |
#' |-----------|------------------------------------------|
#' | SYSTEM    | `NIS`, `NUTS`, `POSTAL`, `INTERNAL`      |
#' | LEVEL     | `COMMUNE`, `ARRONDISSEMENT`, `PROVINCE`, `REGION`, `LAU`, `3`, `2`, `1`, `0` |
#' | VERSION   | `2019`, `2025`, `2021`, `2027`, `BEFORE_2019` |
#'
#' When the level is unambiguous (`POSTAL` has only one level, `NUTS0` has no
#' version variants), the extra parts are omitted.
#'
#' ## NIS classifications (Statbel)
#'
#' | Canonical identifier             | Description                     |
#' |----------------------------------|---------------------------------|
#' | `NIS_COMMUNE_BEFORE_2019`        | Communes before 2019 fusions    |
#' | `NIS_ARRONDISSEMENT_BEFORE_2019` | Arrondissements (pre-2019)      |
#' | `NIS_PROVINCE_BEFORE_2019`       | Provinces (pre-2019)            |
#' | `NIS_REGION_BEFORE_2019`         | Regions (pre-2019)              |
#' | `NIS_COMMUNE_2019`               | Communes (2019 version)         |
#' | `NIS_ARRONDISSEMENT_2019`        | Arrondissements (2019)          |
#' | `NIS_PROVINCE_2019`              | Provinces (2019)                |
#' | `NIS_REGION_2019`                | Regions (2019)                  |
#' | `NIS_COMMUNE_2025`               | Communes (2025 version)         |
#' | `NIS_ARRONDISSEMENT_2025`        | Arrondissements (2025)          |
#' | `NIS_PROVINCE_2025`              | Provinces (2025)                |
#' | `NIS_REGION_2025`                | Regions (2025)                  |
#'
#' ## NUTS classifications (Eurostat)
#'
#' | Canonical identifier | Description                            |
#' |----------------------|----------------------------------------|
#' | `NUTS_LAU_2021`      | Local Administrative Units (2021)      |
#' | `NUTS3_2021`         | NUTS level 3 (2021)                    |
#' | `NUTS2_2021`         | NUTS level 2 (2021)                    |
#' | `NUTS1_2021`         | NUTS level 1 (2021)                    |
#' | `NUTS0`              | Country level (BE) — version-invariant |
#' | `NUTS3_2027`         | NUTS level 3 (2027)                    |
#' | `NUTS2_2027`         | NUTS level 2 (2027)                    |
#' | `NUTS1_2027`         | NUTS level 1 (2027)                    |
#'
#' ## Other classifications
#'
#' | Canonical identifier     | Description                                          |
#' |--------------------------|------------------------------------------------------|
#' | `POSTAL`                 | Belgian postal codes (bpost)                         |
#' | `INTERNAL_ARRONDISSEMENT`| 2-digit internal code; Verviers split: 65=FR, 66=DE  |
#'
#' ## Available conversions
#'
#' The table below lists all supported conversion paths. **Simple** (✓) means a
#' deterministic N:1 or 1:1 mapping; **Ambiguous** (⚠) means a M:N mapping that
#' requires weighted splitting (use [split_ambiguous_weights()]).
#'
#' | From                          | To                               | Type   |
#' |-------------------------------|----------------------------------|--------|
#' | `NIS_COMMUNE_BEFORE_2019`     | `NIS_ARRONDISSEMENT_BEFORE_2019` | ✓ N:1  |
#' | `NIS_COMMUNE_BEFORE_2019`     | `NIS_REGION_BEFORE_2019`         | ✓ N:1  |
#' | `NIS_ARRONDISSEMENT_BEFORE_2019` | `NIS_PROVINCE_BEFORE_2019`    | ✓ N:1  |
#' | `NIS_PROVINCE_BEFORE_2019`    | `NIS_REGION_BEFORE_2019`         | ⚠ M:N  |
#' | `NIS_COMMUNE_BEFORE_2019`     | `NIS_COMMUNE_2019`               | ✓ N:1  |
#' | `NIS_COMMUNE_BEFORE_2019`     | `NUTS3_2021`                     | ✓ N:1  |
#' | `NIS_COMMUNE_BEFORE_2019`     | `NUTS3_2027`                     | ✓ N:1  |
#' | `NIS_COMMUNE_2019`            | `NIS_ARRONDISSEMENT_2019`        | ✓ N:1  |
#' | `NIS_COMMUNE_2019`            | `NIS_REGION_2019`                | ✓ N:1  |
#' | `NIS_ARRONDISSEMENT_2019`     | `NIS_PROVINCE_2019`              | ✓ N:1  |
#' | `NIS_PROVINCE_2019`           | `NIS_REGION_2019`                | ⚠ M:N  |
#' | `NIS_COMMUNE_2019`            | `NIS_COMMUNE_2025`               | ✓ N:1  |
#' | `NIS_COMMUNE_2019`            | `NUTS_LAU_2021`                  | ✓ 1:1  |
#' | `NIS_COMMUNE_2019`            | `NUTS3_2027`                     | ✓ N:1  |
#' | `NIS_ARRONDISSEMENT_2019`     | `NUTS3_2021`                     | ⚠ 1:N  |
#' | `NIS_ARRONDISSEMENT_2019`     | `INTERNAL_ARRONDISSEMENT`        | ⚠ 1:N  |
#' | `NIS_COMMUNE_2025`            | `NIS_ARRONDISSEMENT_2025`        | ✓ N:1  |
#' | `NIS_COMMUNE_2025`            | `NIS_REGION_2025`                | ✓ N:1  |
#' | `NIS_ARRONDISSEMENT_2025`     | `NIS_PROVINCE_2025`              | ✓ N:1  |
#' | `NIS_PROVINCE_2025`           | `NIS_REGION_2025`                | ⚠ M:N  |
#' | `NIS_COMMUNE_2025`            | `NUTS3_2027`                     | ✓ N:1  |
#' | `NIS_COMMUNE_2025`            | `NUTS2_2027`                     | ✓ N:1  |
#' | `NIS_COMMUNE_2025`            | `NUTS1_2027`                     | ✓ N:1  |
#' | `NUTS_LAU_2021`               | `NUTS3_2021`                     | ✓ N:1  |
#' | `NUTS3_2021`                  | `NUTS2_2021`                     | ✓ N:1  |
#' | `NUTS2_2021`                  | `NUTS1_2021`                     | ✓ N:1  |
#' | `NUTS1_2021`                  | `NUTS0`                          | ✓ N:1  |
#' | `NUTS3_2027`                  | `NUTS2_2027`                     | ✓ N:1  |
#' | `NUTS2_2027`                  | `NUTS1_2027`                     | ✓ N:1  |
#' | `NUTS1_2027`                  | `NUTS0`                          | ✓ N:1  |
#' | `NUTS3_2021`                  | `INTERNAL_ARRONDISSEMENT`        | ✓ 1:1  |
#' | `POSTAL`                      | `NIS_COMMUNE_2019`               | ✓ N:1  |
#' | `POSTAL`                      | `NIS_COMMUNE_2025`               | ✓ N:1  |
#' | `POSTAL`                      | `NUTS3_2027`                     | ✓ N:1  |
#'
#' **Note on NUTS3_2021 ↔ NUTS3_2027:** there is **no direct conversion** between
#' these two NUTS3 versions. Three Belgian communes changed province between 2019
#' and 2025, shifting their NUTS3 region. The correct path is always via NIS
#' communes: `NUTS3_2021` → `NIS_COMMUNE` → `NIS_COMMUNE_2025` → `NUTS3_2027`
#' (ambiguous, requires `allow_ambiguous = TRUE`).
#'
#' **Note on province → region:** Province 20000 (Brabant) spans the Brussels,
#' Flemish and Walloon regions, making province → region M:N. Use commune-level
#' paths (`NIS_COMMUNE_* → NIS_REGION_*`) for unambiguous region lookups.
#'
#' **Note on arrondissement → NUTS3/INTERNAL:** Only Verviers (63000) maps to
#' two targets (1:N). The reverse NUTS3 → arrondissement is N:1 (simple).
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
#' check_conversion_path("NIS_COMMUNE_2019", "NUTS3_2021")
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
