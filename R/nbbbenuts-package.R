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
  # raw source column names (uppercase, from Statbel/Eurostat files)
  "CD_LAU", "CD_LVL", "CD_LVL_SUP", "CD_MUNTY_REFNIS",
  "C_BASE_CODE_ARCA", "C_OVER_CLIST_ARCA", "C_OVER_CODE_ARCA",
  "DT_VLDT_STOP", "DT_VLDT_STRT",
  "TX_DESCR_FR", "TX_DESCR_NL",
  "Y_BASE_CLIST_ARCA",
  # internal column names used via data.table NSE
  "cd_arr", "cd_arr_2digit", "cd_arr_internal",
  "cd_commune", "cd_commune_2025", "cd_commune_nis",
  "cd_nuts", "cd_nuts0", "cd_nuts0_2027",
  "cd_nuts1", "cd_nuts1_2027", "cd_nuts2", "cd_nuts2_2027",
  "cd_nuts3", "cd_nuts3_2027", "cd_nuts_lau", "cd_nuts_parent",
  "cd_postal", "cd_prov_candidate", "cd_province",
  "cd_refnis", "cd_refnis_2019", "cd_refnis_before2019",
  "cd_refnis_new", "cd_refnis_old", "cd_region",
  "classification", "code", "code_from", "code_to",
  "distance", "from", "from_version",
  "input_name", "is_confident", "is_simple", "is_valid_commune",
  "level", "match_pct", "n_mappings", "n_occurrences",
  "name_fr", "name_nl", "nature", "nis_version", "notes", "nuts_2021",
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
