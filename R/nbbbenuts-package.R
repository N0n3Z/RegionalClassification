#' @keywords internal
"_PACKAGE"

## usethis namespace: start
#' @import data.table
#' @importFrom rlang abort warn inform
#' @importFrom stats na.omit setNames
#' @importFrom utils head
## usethis namespace: end
NULL

utils::globalVariables(c(
  # data.table special symbols
  ".", "N",
  # schema v2 column names of the persisted tables (see SCHEMA_V1_TO_V2)
  "classification_from", "classification_to", "label_fr", "label_nl",
  "version", "version_from", "version_to",
  "code_nis_municipality", "code_nis_district", "code_nis_province",
  "code_nis_region", "code_nis_country", "code_postal",
  "code_nuts_municipality_2021", "code_nuts_district_2021",
  "code_nuts_province_2021", "code_nuts_region_2021", "code_nuts_country",
  "code_nuts_district_2027", "code_nuts_province_2027",
  "code_nuts_region_2027", "code_nuts_country_2027",
  "code_nbb_district_2021",
  "label_nis_municipality_fr", "label_nis_district_fr",
  "label_nis_province_fr", "label_nis_region_fr",
  "label_nuts_district_2021_fr",
  # list_available_conversions / get_conversion_matrix result columns
  "perimeter_relation", "executable", "effectively_simple",
  # data.table working columns (03_convert.R, 07_diagnose.R, 07_split_ambiguous.R)
  ".n_to", ".prio", "value", "mass",
  # raw source column names (uppercase, from Statbel/Eurostat files)
  "CD_LAU", "CD_LVL", "CD_LVL_SUP", "CD_MUNTY_REFNIS",
  "C_BASE_CODE_ARCA", "C_OVER_CLIST_ARCA", "C_OVER_CODE_ARCA",
  "DT_VLDT_STOP", "DT_VLDT_STRT",
  "TX_DESCR_FR", "TX_DESCR_NL",
  "Y_BASE_CLIST_ARCA",
  # build-time (source-oriented) column names used via data.table NSE
  "cd_arr", "cd_arr_internal",
  "cd_commune", "cd_commune_2025", "cd_commune_nis",
  "cd_nis_country",
  "cd_nuts", "cd_nuts0", "cd_nuts0_2027",
  "cd_nuts1", "cd_nuts1_2027", "cd_nuts2", "cd_nuts2_2027",
  "cd_nuts3", "cd_nuts3_2027", "cd_nuts_lau", "cd_nuts_parent",
  "cd_postal", "cd_prov_candidate", "cd_province",
  "cd_refnis", "cd_refnis_2019", "cd_refnis_before2019",
  "cd_refnis_new", "cd_refnis_old", "cd_region",
  "classification", "code", "code_from", "code_to",
  "distance", "from",
  "label_input", "is_confident", "is_simple", "is_valid_commune",
  "level", "match_pct", "n_occurrences",
  "nature", "nis_version", "notes",
  "rate", "ref_code", "ref_name", "ref_name_norm", "relation",
  "split_weight", "status", "to",
  "tx_arr_fr", "tx_arr_nl", "tx_commune_fr", "tx_commune_nl",
  "tx_descr_fr", "tx_descr_nl",
  "tx_nuts3_fr", "tx_nuts3_nl",
  "tx_postal_name_fr", "tx_postal_name_nl",
  "tx_prov_fr", "tx_prov_nl",
  "tx_region_fr", "tx_region_nl",
  "unknown_pct", "weight",
  # data.table working columns used in .compose_via_handlers and add_nuts2021_columns_2025
  ".k", ".nxt", ".ord", "cur", "n_nuts3_distinct",
  # data.table working columns used in rebase_series / split_ambiguous
  ".old_code", ".target_code",
  # used in get_crosswalk and get_label via data.table NSE
  "label", "w"
))
