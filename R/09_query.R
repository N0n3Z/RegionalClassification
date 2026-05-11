# ==============================================================================
# 09_query.R - Reference code lookup, label retrieval, and crosswalk tables
# ==============================================================================


# Metadata for label lookups: code column and name columns per classification.
# ver  : nis_version filter (communes / postal tables)
# code : column holding the classification code
# fr   : French name column (NA_character_ = not available)
# nl   : Dutch name column (NA_character_ = not available)
# src  : "communes" or "postal"
.LABEL_META <- list(
  NIS_COMMUNE_2019               = list(ver = "2019",        code = "cd_commune",    fr = "tx_commune_fr",     nl = "tx_commune_nl",     src = "communes"),
  NIS_COMMUNE_2025               = list(ver = "2025",        code = "cd_commune",    fr = "tx_commune_fr",     nl = "tx_commune_nl",     src = "communes"),
  NIS_COMMUNE_BEFORE_2019        = list(ver = "BEFORE_2019", code = "cd_commune",    fr = "tx_commune_fr",     nl = "tx_commune_nl",     src = "communes"),
  NIS_ARRONDISSEMENT_2019        = list(ver = "2019",        code = "cd_arr",        fr = "tx_arr_fr",         nl = "tx_arr_nl",         src = "communes"),
  NIS_ARRONDISSEMENT_2025        = list(ver = "2025",        code = "cd_arr",        fr = "tx_arr_fr",         nl = "tx_arr_nl",         src = "communes"),
  NIS_ARRONDISSEMENT_BEFORE_2019 = list(ver = "BEFORE_2019", code = "cd_arr",       fr = "tx_arr_fr",         nl = "tx_arr_nl",         src = "communes"),
  NIS_PROVINCE_2019              = list(ver = "2019",        code = "cd_province",   fr = "tx_prov_fr",        nl = "tx_prov_nl",        src = "communes"),
  NIS_PROVINCE_2025              = list(ver = "2025",        code = "cd_province",   fr = "tx_prov_fr",        nl = "tx_prov_nl",        src = "communes"),
  NIS_PROVINCE_BEFORE_2019       = list(ver = "BEFORE_2019", code = "cd_province",  fr = "tx_prov_fr",        nl = "tx_prov_nl",        src = "communes"),
  NIS_REGION_2019                = list(ver = "2019",        code = "cd_region",     fr = "tx_region_fr",      nl = "tx_region_nl",      src = "communes"),
  NIS_REGION_2025                = list(ver = "2025",        code = "cd_region",     fr = "tx_region_fr",      nl = "tx_region_nl",      src = "communes"),
  NIS_REGION_BEFORE_2019         = list(ver = "BEFORE_2019", code = "cd_region",    fr = "tx_region_fr",      nl = "tx_region_nl",      src = "communes"),
  NUTS_LAU_2021                  = list(ver = "2019",        code = "cd_nuts_lau",   fr = "tx_commune_fr",     nl = "tx_commune_nl",     src = "communes"),
  NUTS3_2021                     = list(ver = "2019",        code = "cd_nuts3",      fr = "tx_nuts3_fr",       nl = "tx_nuts3_nl",       src = "communes"),
  NUTS2_2021                     = list(ver = "2019",        code = "cd_nuts2",      fr = NA_character_,       nl = NA_character_,       src = "communes"),
  NUTS1_2021                     = list(ver = "2019",        code = "cd_nuts1",      fr = NA_character_,       nl = NA_character_,       src = "communes"),
  NUTS0                          = list(ver = "2019",        code = "cd_nuts0",      fr = NA_character_,       nl = NA_character_,       src = "communes"),
  NUTS3_2027                     = list(ver = "2025",        code = "cd_nuts3_2027", fr = NA_character_,       nl = NA_character_,       src = "communes"),
  NUTS2_2027                     = list(ver = "2025",        code = "cd_nuts2_2027", fr = NA_character_,       nl = NA_character_,       src = "communes"),
  NUTS1_2027                     = list(ver = "2025",        code = "cd_nuts1_2027", fr = NA_character_,       nl = NA_character_,       src = "communes"),
  POSTAL                         = list(ver = "2019",        code = "cd_postal",     fr = "tx_postal_name_fr", nl = "tx_postal_name_nl", src = "postal"),
  INTERNAL_ARRONDISSEMENT        = list(ver = "2019",        code = "cd_arr_internal", fr = "tx_arr_fr",       nl = "tx_arr_nl",         src = "communes")
)


#' List all valid codes for a classification
#'
#' @noRd
.list_codes_for <- function(classification, master_data) {
  com <- master_data$communes
  switch(classification,
    NIS_COMMUNE_2019               = as.character(com[nis_version == "2019",        cd_commune]),
    NIS_COMMUNE_2025               = as.character(com[nis_version == "2025",        cd_commune]),
    NIS_COMMUNE_BEFORE_2019        = as.character(com[nis_version == "BEFORE_2019", cd_commune]),
    NIS_ARRONDISSEMENT_2019        = as.character(na.omit(unique(com[nis_version == "2019",        cd_arr]))),
    NIS_ARRONDISSEMENT_2025        = as.character(na.omit(unique(com[nis_version == "2025",        cd_arr]))),
    NIS_ARRONDISSEMENT_BEFORE_2019 = as.character(na.omit(unique(com[nis_version == "BEFORE_2019", cd_arr]))),
    NIS_PROVINCE_2019              = as.character(na.omit(unique(com[nis_version == "2019",        cd_province]))),
    NIS_PROVINCE_2025              = as.character(na.omit(unique(com[nis_version == "2025",        cd_province]))),
    NIS_PROVINCE_BEFORE_2019       = as.character(na.omit(unique(com[nis_version == "BEFORE_2019", cd_province]))),
    NIS_REGION_2019                = as.character(na.omit(unique(com[nis_version == "2019",        cd_region]))),
    NIS_REGION_2025                = as.character(na.omit(unique(com[nis_version == "2025",        cd_region]))),
    NIS_REGION_BEFORE_2019         = as.character(na.omit(unique(com[nis_version == "BEFORE_2019", cd_region]))),
    NUTS_LAU_2021                  = as.character(na.omit(unique(com[nis_version == "2019", cd_nuts_lau]))),
    NUTS3_2021                     = as.character(na.omit(unique(com[nis_version == "2019", cd_nuts3]))),
    NUTS2_2021                     = as.character(na.omit(unique(com[nis_version == "2019", cd_nuts2]))),
    NUTS1_2021                     = as.character(na.omit(unique(com[nis_version == "2019", cd_nuts1]))),
    NUTS0                          = as.character(na.omit(unique(com[nis_version == "2019", cd_nuts0]))),
    NUTS3_2027                     = as.character(na.omit(unique(com[nis_version == "2025", cd_nuts3_2027]))),
    NUTS2_2027                     = as.character(na.omit(unique(com[nis_version == "2025", cd_nuts2_2027]))),
    NUTS1_2027                     = as.character(na.omit(unique(com[nis_version == "2025", cd_nuts1_2027]))),
    POSTAL                         = as.character(unique(master_data$postal[nis_version == "2019", cd_postal])),
    INTERNAL_ARRONDISSEMENT        = as.character(na.omit(unique(com[nis_version == "2019", cd_arr_internal])))
  )
}


#' Validate codes against a known classification
#'
#' Checks whether each code in the input vector belongs to the set of known
#' codes for the specified classification. Useful for catching data quality
#' issues before a conversion.
#'
#' @param codes Vector of codes to validate (coerced to character).
#' @param classification Canonical classification identifier (see
#'   [classification_reference]).
#' @param master_data Output from [load_master_data()].
#' @return A `data.table` with columns:
#'   \describe{
#'     \item{code}{Input code (character).}
#'     \item{is_valid}{`TRUE` if the code exists in the reference set.}
#'   }
#' @examples
#' \donttest{
#'   master_data <- load_master_data()
#'   validate_codes(c(21004L, 99999L, 11002L), "NIS_COMMUNE_2019", master_data)
#' }
#' @export
validate_codes <- function(codes, classification, master_data) {
  cls <- normalize_classification_id(classification)
  .validate_master_data(master_data)
  ref  <- .list_codes_for(cls, master_data)
  data.table(code = as.character(codes), is_valid = as.character(codes) %in% ref)
}


#' Get official names for classification codes
#'
#' Returns the French or Dutch official label for each code. Classifications
#' without a name in the master data (NUTS2/NUTS1 levels and NUTS 2027) return
#' `NA`.
#'
#' @param codes Vector of codes (coerced to character).
#' @param classification Canonical classification identifier (see
#'   [classification_reference]).
#' @param master_data Output from [load_master_data()].
#' @param lang `"fr"` (default) or `"nl"`.
#' @return A `data.table` with columns:
#'   \describe{
#'     \item{code}{Input code (character).}
#'     \item{label}{Official name, or `NA` if unavailable.}
#'   }
#' @examples
#' \donttest{
#'   master_data <- load_master_data()
#'   get_label(c(21004L, 11002L), "NIS_COMMUNE_2019", master_data)
#'   get_label(c("BE100", "BE211"), "NUTS3_2021", master_data, lang = "nl")
#' }
#' @export
get_label <- function(codes, classification, master_data, lang = c("fr", "nl")) {
  lang <- match.arg(lang)
  cls  <- normalize_classification_id(classification)
  .validate_master_data(master_data)

  meta      <- .LABEL_META[[cls]]
  label_col <- if (lang == "fr") meta$fr else meta$nl

  input <- data.table(code = as.character(codes))

  if (is.na(label_col)) {
    input[, label := NA_character_]
    return(input)
  }

  src <- if (meta$src == "communes") master_data$communes else master_data$postal
  src <- src[get("nis_version") == meta$ver]

  ref <- unique(src[, c(meta$code, label_col), with = FALSE])
  setnames(ref, c("code", "label"))
  ref[, code := as.character(code)]

  ref[input, on = "code"]
}


#' Build a full correspondence table between two classifications
#'
#' Returns every (from, to) pair that exists in the reference data. For simple
#' (N:1 or 1:1) conversions every source code appears exactly once; for
#' ambiguous (M:N) conversions a source code may appear in multiple rows.
#'
#' @param from Source classification identifier (see [classification_reference]).
#' @param to Target classification identifier.
#' @param master_data Output from [load_master_data()].
#' @return A `data.table` with two columns named after `from` and `to`
#'   respectively.
#' @examples
#' \donttest{
#'   master_data <- load_master_data()
#'   get_crosswalk("NIS_COMMUNE_2019", "NUTS3_2021", master_data)
#'   get_crosswalk("POSTAL", "NIS_COMMUNE_2019", master_data)
#' }
#' @export
get_crosswalk <- function(from, to, master_data) {
  from_norm <- normalize_classification_id(from)
  to_norm   <- normalize_classification_id(to)
  .validate_master_data(master_data)

  all_codes <- .list_codes_for(from_norm, master_data)
  result    <- suppressWarnings(
    convert_codes(all_codes, from_norm, to_norm, master_data,
                  allow_ambiguous = TRUE)
  )

  setnames(result, c("code_from", "code_to"), c(from_norm, to_norm))
  result
}
