# ==============================================================================
# R/data.R — Documentation of bundled sample datasets
# ==============================================================================

#' Sample communes — NIS 2019
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
#'   \item{taux_activite}{Numeric. Activity rate, 0–1 (fictional).}
#' }
#' @examples
#' data(rc_communes_2019)
#' head(rc_communes_2019)
#'
#' \donttest{
#'   master_data <- load_master_data()
#'   convert_dataset(rc_communes_2019, "cd_commune",
#'                   to = "NUTS3_2021", master_data)
#' }
"rc_communes_2019"


#' Sample communes — NIS 2025
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
#'   \item{taux_activite}{Numeric. Activity rate, 0–1 (fictional).}
#' }
#' @examples
#' data(rc_communes_2025)
#' head(rc_communes_2025)
#'
#' \donttest{
#'   master_data <- load_master_data()
#'   convert_dataset(rc_communes_2025, "cd_commune",
#'                   from = "NIS_COMMUNE_2025", to = "NUTS3_2027", master_data)
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
#'                   from = "POSTAL", to = "NIS_COMMUNE_2019", master_data)
#' }
"rc_postal"


#' Sample arrondissements — NIS 2019
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
#'     from       = "NIS_ARRONDISSEMENT_2019",
#'     to         = "NUTS3_2021",
#'     master_data
#'   )
#' }
"rc_arrondissements_2019"


#' Sample NUTS3 regions — 2021 classification
#'
#' A dataset of 10 Belgian NUTS3 regions (2021 classification) with fictional
#' macroeconomic indicators. Includes BE335 and BE336 (the two Verviers
#' sub-regions) to demonstrate NUTS 2021 → NUTS 2027 conversions.
#'
#' @format A `data.table` with 10 rows and 5 columns:
#' \describe{
#'   \item{cd_nuts3}{Character. NUTS3 2021 code (e.g. "BE100").}
#'   \item{nom_fr}{Character. French name of the NUTS3 region.}
#'   \item{gdp_mio_eur}{Numeric. GDP in millions of EUR (fictional).}
#'   \item{emplois}{Integer. Number of jobs (fictional).}
#'   \item{taux_chomage}{Numeric. Unemployment rate, 0–1 (fictional).}
#' }
#' @examples
#' data(rc_nuts3_2021)
#' head(rc_nuts3_2021)
#'
#' \donttest{
#'   master_data <- load_master_data()
#'
#'   # Aggregate NUTS3 2021 to NUTS2 2021
#'   # Note: NUTS3_2021 and NUTS3_2027 cover different geographic areas;
#'   # there is no direct conversion between them (see ?classification_reference).
#'   convert_dataset(rc_nuts3_2021, "cd_nuts3",
#'                   from = "NUTS3_2021", to = "NUTS2_2021", master_data)
#' }
"rc_nuts3_2021"
