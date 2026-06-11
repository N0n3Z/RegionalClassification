# ==============================================================================
# R/data.R -- Documentation of bundled sample datasets
# ==============================================================================

#' Sample communes -- NIS 2019
#'
#' A small representative dataset of 12 Belgian communes using NIS 2019 codes,
#' with fictional but realistic socio-economic indicators. Useful for testing
#' and demonstrating `convert_codes()`, `convert_dataset()`, and
#' `diagnose_classification()`.
#'
#' @format A `data.table` with 12 rows and 7 columns:
#' \describe{
#'   \item{cd_commune}{Integer. NIS 2019 commune code.}
#'   \item{nom_fr}{Character. French name of the commune.}
#'   \item{nom_nl}{Character. Dutch name of the commune.}
#'   \item{population}{Integer. Resident population (fictional).}
#'   \item{emplois}{Integer. Number of jobs (fictional).}
#'   \item{masse_sal}{Numeric. Total wage bill in EUR (fictional).}
#'   \item{taux_activite}{Numeric. Activity rate, 0--1 (fictional).}
#' }
#' @examples
#' data(rc_communes_2019)
#' head(rc_communes_2019)
#'
#' \donttest{
#'   master_data <- load_master_data()
#'   convert_dataset(rc_communes_2019, "cd_commune",
#'                   to = "NUTS_DISTRICT_2021", master_data)
#' }
"rc_communes_2019"


#' Sample communes -- NIS 2025
#'
#' A small representative dataset of 10 Belgian communes using NIS 2025 codes,
#' with fictional but realistic socio-economic indicators.
#'
#' @format A `data.table` with 10 rows and 7 columns:
#' \describe{
#'   \item{cd_commune}{Integer. NIS 2025 commune code.}
#'   \item{nom_fr}{Character. French name of the commune.}
#'   \item{nom_nl}{Character. Dutch name of the commune.}
#'   \item{population}{Integer. Resident population (fictional).}
#'   \item{emplois}{Integer. Number of jobs (fictional).}
#'   \item{masse_sal}{Numeric. Total wage bill in EUR (fictional).}
#'   \item{taux_activite}{Numeric. Activity rate, 0--1 (fictional).}
#' }
#' @examples
#' data(rc_communes_2025)
#' head(rc_communes_2025)
#'
#' \donttest{
#'   master_data <- load_master_data()
#'   convert_dataset(rc_communes_2025, "cd_commune",
#'                   from = "NIS_MUNICIPALITY_2025", to = "NUTS_DISTRICT_2027", master_data)
#' }
"rc_communes_2025"


#' Sample postal codes
#'
#' A small dataset of 12 Belgian postal codes with fictional socio-economic
#' indicators. Useful for demonstrating postal-code conversions.
#'
#' @format A `data.table` with 12 rows and 4 columns:
#' \describe{
#'   \item{cd_postal}{Integer. Belgian postal code.}
#'   \item{nom_fr}{Character. French locality name.}
#'   \item{population}{Integer. Resident population (fictional).}
#'   \item{revenu_moy}{Numeric. Average income in EUR (fictional).}
#' }
#' @examples
#' data(rc_postal)
#' head(rc_postal)
#'
#' \donttest{
#'   master_data <- load_master_data()
#'   convert_dataset(rc_postal, "cd_postal",
#'                   from = "POSTAL", to = "NIS_MUNICIPALITY_2019", master_data)
#' }
"rc_postal"


#' Sample arrondissements -- NIS 2019
#'
#' A dataset of 8 Belgian arrondissements using NIS 2019 codes. Includes
#' arrondissement 63000 (Verviers), which maps to two NUTS3 regions (BE335 and
#' BE336), making it the key test case for `split_ambiguous()`.
#'
#' @format A `data.table` with 8 rows and 5 columns:
#' \describe{
#'   \item{cd_arr}{Integer. NIS 2019 arrondissement code.}
#'   \item{nom_fr}{Character. French name of the arrondissement.}
#'   \item{emplois}{Integer. Number of jobs (fictional).}
#'   \item{masse_sal}{Numeric. Total wage bill in EUR (fictional).}
#'   \item{population}{Integer. Resident population (fictional).}
#' }
#' @examples
#' data(rc_arrondissements_2019)
#' head(rc_arrondissements_2019)
#'
#' \donttest{
#'   master_data <- load_master_data()
#'
#'   # Verviers (63000) is ambiguous: spans BE335 and BE336
#'   split_ambiguous(
#'     dt         = rc_arrondissements_2019,
#'     code_col   = "cd_arr",
#'     value_cols = c("emplois", "masse_sal"),
#'     from       = "NIS_DISTRICT_2019",
#'     to         = "NUTS_DISTRICT_2021",
#'     master_data
#'   )
#' }
"rc_arrondissements_2019"


#' Sample NUTS3 regions -- 2021 classification
#'
#' A dataset of 10 Belgian NUTS3 regions (2021 classification) with fictional
#' macroeconomic indicators. Includes BE335 and BE336 (the two Verviers
#' sub-regions) to demonstrate NUTS 2021 -> NUTS 2027 conversions.
#'
#' @format A `data.table` with 10 rows and 5 columns:
#' \describe{
#'   \item{cd_nuts3}{Character. NUTS3 2021 code (e.g. "BE100").}
#'   \item{nom_fr}{Character. French name of the NUTS3 region.}
#'   \item{gdp_mio_eur}{Numeric. GDP in millions of EUR (fictional).}
#'   \item{emplois}{Integer. Number of jobs (fictional).}
#'   \item{taux_chomage}{Numeric. Unemployment rate, 0--1 (fictional).}
#' }
#' @examples
#' data(rc_nuts3_2021)
#' head(rc_nuts3_2021)
#'
#' \donttest{
#'   master_data <- load_master_data()
#'
#'   # Aggregate NUTS3 2021 to NUTS2 2021
#'   # Note: NUTS_DISTRICT_2021 and NUTS_DISTRICT_2027 cover different geographic areas;
#'   # there is no direct conversion between them (see ?classification_reference).
#'   convert_dataset(rc_nuts3_2021, "cd_nuts3",
#'                   from = "NUTS_DISTRICT_2021", to = "NUTS_PROVINCE_2021", master_data)
#' }
"rc_nuts3_2021"


# ==============================================================================
# Complete reference datasets (one row per geographic unit)
# ==============================================================================

#' Complete communes dataset -- NIS 2019
#'
#' One row per Belgian commune in the NIS 2019 classification (583 communes),
#' with fictional but realistically-scaled socio-economic indicators. Designed
#' for full-coverage conversion demonstrations and benchmark testing.
#'
#' @format A `data.table` with 583 rows and 5 columns:
#' \describe{
#'   \item{cd_commune}{Integer. NIS 2019 commune code.}
#'   \item{population}{Integer. Resident population (fictional, 200--180 000).}
#'   \item{emplois}{Integer. Number of jobs (fictional, ~35--55 \% of population).}
#'   \item{masse_sal}{Numeric. Total wage bill in EUR (fictional).}
#'   \item{taux_activite}{Numeric. Activity rate, 0--1 (fictional).}
#' }
#' @seealso [rc_full_municipalities_2025], [rc_dirty_municipalities_2019],
#'   [diagnose_classification()], [convert_dataset()]
#' @examples
#' data(rc_full_municipalities_2019)
#' head(rc_full_municipalities_2019)
#'
#' \donttest{
#'   master_data <- load_master_data()
#'   convert_dataset(rc_full_municipalities_2019, "cd_commune",
#'                   from = "NIS_MUNICIPALITY_2019",
#'                   to   = "NUTS_DISTRICT_2021", master_data)
#' }
"rc_full_municipalities_2019"


#' Complete communes dataset -- NIS 2025
#'
#' One row per Belgian commune in the NIS 2025 classification (567 communes),
#' with fictional but realistically-scaled socio-economic indicators.
#'
#' @format A `data.table` with 567 rows and 5 columns:
#' \describe{
#'   \item{cd_commune}{Integer. NIS 2025 commune code.}
#'   \item{population}{Integer. Resident population (fictional, 200--180 000).}
#'   \item{emplois}{Integer. Number of jobs (fictional).}
#'   \item{masse_sal}{Numeric. Total wage bill in EUR (fictional).}
#'   \item{taux_activite}{Numeric. Activity rate, 0--1 (fictional).}
#' }
#' @seealso [rc_full_municipalities_2019], [rc_dirty_municipalities_2019]
#' @examples
#' data(rc_full_municipalities_2025)
#' head(rc_full_municipalities_2025)
#'
#' \donttest{
#'   master_data <- load_master_data()
#'   convert_dataset(rc_full_municipalities_2025, "cd_commune",
#'                   from = "NIS_MUNICIPALITY_2025",
#'                   to   = "NUTS_DISTRICT_2027", master_data)
#' }
"rc_full_municipalities_2025"


#' Complete districts dataset -- NIS 2019
#'
#' One row per Belgian arrondissement (district) in the NIS 2019 classification
#' (44 arrondissements), with fictional socio-economic indicators. Includes
#' arrondissement 63000 (Verviers), the canonical ambiguous case that spans two
#' NUTS3 regions (BE335 and BE336).
#'
#' @format A `data.table` with 44 rows and 5 columns:
#' \describe{
#'   \item{cd_arr}{Integer. NIS 2019 arrondissement code.}
#'   \item{population}{Integer. Resident population (fictional, 5 000--600 000).}
#'   \item{emplois}{Integer. Number of jobs (fictional).}
#'   \item{masse_sal}{Numeric. Total wage bill in EUR (fictional).}
#'   \item{taux_activite}{Numeric. Activity rate, 0--1 (fictional).}
#' }
#' @seealso [split_ambiguous()], [rc_arrondissements_2019]
#' @examples
#' data(rc_full_districts_2019)
#' head(rc_full_districts_2019)
#'
#' \donttest{
#'   master_data <- load_master_data()
#'   # Verviers (63000) spans BE335 and BE336 -- requires split_ambiguous()
#'   split_ambiguous(rc_full_districts_2019, "cd_arr",
#'                   value_cols = "emplois",
#'                   from = "NIS_DISTRICT_2019",
#'                   to   = "NUTS_DISTRICT_2021", master_data)
#' }
"rc_full_districts_2019"


#' Complete regions dataset -- NIS 2019
#'
#' One row per Belgian region in the NIS 2019 classification (3 regions:
#' Flemish, Walloon, Brussels-Capital), with fictional socio-economic indicators.
#'
#' @format A `data.table` with 3 rows and 5 columns:
#' \describe{
#'   \item{cd_region}{Integer. NIS 2019 region code (2000, 3000, 4000).}
#'   \item{population}{Integer. Resident population (fictional, 500 000--3 700 000).}
#'   \item{emplois}{Integer. Number of jobs (fictional).}
#'   \item{masse_sal}{Numeric. Total wage bill in EUR (fictional).}
#'   \item{taux_activite}{Numeric. Activity rate, 0--1 (fictional).}
#' }
#' @examples
#' data(rc_full_regions_2019)
#' rc_full_regions_2019
"rc_full_regions_2019"


#' Complete NUTS3 dataset -- 2021 classification
#'
#' One row per Belgian NUTS3 region in the 2021 classification (44 regions),
#' with fictional macroeconomic indicators. Covers all regions including BE335
#' and BE336 (the two Verviers sub-regions).
#'
#' @format A `data.table` with 44 rows and 5 columns:
#' \describe{
#'   \item{cd_nuts3}{Character. NUTS3 2021 code (e.g. `"BE100"`).}
#'   \item{population}{Integer. Resident population (fictional, 10 000--700 000).}
#'   \item{emplois}{Integer. Number of jobs (fictional).}
#'   \item{masse_sal}{Numeric. Total wage bill in EUR (fictional).}
#'   \item{taux_activite}{Numeric. Activity rate, 0--1 (fictional).}
#' }
#' @seealso [rc_full_nuts3_2027], [rc_nuts3_2021]
#' @examples
#' data(rc_full_nuts3_2021)
#' head(rc_full_nuts3_2021)
#'
#' \donttest{
#'   master_data <- load_master_data()
#'   convert_dataset(rc_full_nuts3_2021, "cd_nuts3",
#'                   from = "NUTS_DISTRICT_2021",
#'                   to   = "NUTS_PROVINCE_2021", master_data)
#' }
"rc_full_nuts3_2021"


#' Complete NUTS3 dataset -- 2027 classification
#'
#' One row per Belgian NUTS3 region in the 2027 classification (44 regions,
#' per EU Regulation 2026/195), with fictional macroeconomic indicators.
#'
#' @format A `data.table` with 44 rows and 5 columns:
#' \describe{
#'   \item{cd_nuts3_2027}{Character. NUTS3 2027 code (e.g. `"BE100"`).}
#'   \item{population}{Integer. Resident population (fictional, 10 000--700 000).}
#'   \item{emplois}{Integer. Number of jobs (fictional).}
#'   \item{masse_sal}{Numeric. Total wage bill in EUR (fictional).}
#'   \item{taux_activite}{Numeric. Activity rate, 0--1 (fictional).}
#' }
#' @seealso [rc_full_nuts3_2021]
#' @examples
#' data(rc_full_nuts3_2027)
#' head(rc_full_nuts3_2027)
#'
#' \donttest{
#'   master_data <- load_master_data()
#'   convert_dataset(rc_full_nuts3_2027, "cd_nuts3_2027",
#'                   from = "NUTS_DISTRICT_2027",
#'                   to   = "NUTS_PROVINCE_2027", master_data)
#' }
"rc_full_nuts3_2027"


#' Complete postal codes dataset
#'
#' One row per Belgian postal code (1 149 codes), with fictional socio-economic
#' indicators. Useful for full-coverage postal-code conversion and diagnostic
#' testing.
#'
#' @format A `data.table` with 1 149 rows and 5 columns:
#' \describe{
#'   \item{cd_postal}{Integer. Belgian postal code.}
#'   \item{population}{Integer. Resident population (fictional, 50--80 000).}
#'   \item{emplois}{Integer. Number of jobs (fictional).}
#'   \item{masse_sal}{Numeric. Total wage bill in EUR (fictional).}
#'   \item{taux_activite}{Numeric. Activity rate, 0--1 (fictional).}
#' }
#' @seealso [rc_postal], [convert_dataset()]
#' @examples
#' data(rc_full_postal)
#' head(rc_full_postal)
#'
#' \donttest{
#'   master_data <- load_master_data()
#'   convert_dataset(rc_full_postal, "cd_postal",
#'                   from = "POSTAL",
#'                   to   = "NIS_MUNICIPALITY_2019", master_data)
#' }
"rc_full_postal"


#' Dirty communes dataset -- NIS 2019 (with deliberate data-quality issues)
#'
#' A purposely-flawed dataset based on NIS 2019 commune codes, designed to
#' showcase `diagnose_classification()`, `validate_codes()`, and
#' `detect_classification()`. Contains four categories of issues:
#'
#' 1. **Duplicate rows** -- 5 communes appear twice.
#' 2. **Wrong-version codes** -- 4 codes that exist in NIS 2025 but not in 2019
#'    (codes introduced by post-2019 mergers).
#' 3. **NA code** -- 2 rows with `NA` in the code column.
#' 4. **NA value** -- 8 rows with `NA` in the `population` column.
#'
#' Rows are shuffled so the issues are not clustered at the end.
#'
#' @format A `data.table` with 319 rows and 5 columns:
#' \describe{
#'   \item{cd_commune}{Integer. NIS commune code (may be NA or from NIS 2025).}
#'   \item{population}{Integer. Resident population (fictional; may be NA).}
#'   \item{emplois}{Integer. Number of jobs (fictional).}
#'   \item{masse_sal}{Numeric. Total wage bill in EUR (fictional).}
#'   \item{taux_activite}{Numeric. Activity rate, 0--1 (fictional).}
#' }
#' @seealso [rc_full_municipalities_2019], [diagnose_classification()],
#'   [validate_codes()], [detect_classification()]
#' @examples
#' data(rc_dirty_municipalities_2019)
#'
#' \donttest{
#'   master_data <- load_master_data()
#'
#'   # Auto-detect and diagnose the classification
#'   diagnose_classification(rc_dirty_municipalities_2019, "cd_commune", master_data)
#'
#'   # Check which codes are unknown in NIS 2019
#'   validate_codes(rc_dirty_municipalities_2019$cd_commune,
#'                  "NIS_MUNICIPALITY_2019", master_data)
#' }
"rc_dirty_municipalities_2019"
