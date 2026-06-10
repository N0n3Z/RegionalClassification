# ==============================================================================
# 09_query.R - Reference code lookup, label retrieval, and crosswalk tables
# ==============================================================================


#' List all valid codes for a classification
#'
#' Thin wrapper over .node_reference_codes() returning a character vector.
#' @noRd
.list_codes_for <- function(classification, master_data) {
  ref <- .node_reference_codes(classification, master_data)
  if (is.null(ref)) return(character(0))
  as.character(ref$code)
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
#'   validate_codes(c(21004L, 99999L, 11002L), "NIS_MUNICIPALITY_2019", master_data)
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
#'   get_label(c(21004L, 11002L), "NIS_MUNICIPALITY_2019", master_data)
#'   get_label(c("BE100", "BE211"), "NUTS_DISTRICT_2021", master_data, lang = "nl")
#' }
#' @export
get_label <- function(codes, classification, master_data, lang = c("fr", "nl")) {
  lang <- match.arg(lang)
  cls  <- normalize_classification_id(classification)
  .validate_master_data(master_data)

  meta      <- .node_label_meta(cls)
  label_col <- if (lang == "fr") meta$fr else meta$nl

  input <- data.table(code = as.character(codes))

  if (is.na(label_col)) {
    input[, label := NA_character_]
    return(input)
  }

  # Phase 3: prefer entities table (built at snapshot time, always available
  # after load_master_data()).  Fallback to communes/postal for legacy or
  # rebuild contexts where entities is not yet populated.
  if (!is.null(master_data$entities)) {
    name_col <- if (lang == "fr") "name_fr" else "name_nl"
    ent  <- master_data$entities[classification_id == cls]
    ref  <- unique(ent[!is.na(get(name_col)), .(code, label = get(name_col))])
    return(ref[input, on = "code"])
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
#' @param weights Logical (default `FALSE`). When `TRUE`, a `weight` column is
#'   added. Unambiguous codes receive `weight = 1`. Ambiguous (1:N) codes use
#'   population weights from the session registry (see
#'   [register_split_weights()]) when available, otherwise equal weights.
#' @return A `data.table` with columns named after `from` and `to`. When
#'   `weights = TRUE`, an additional numeric `weight` column is included.
#' @examples
#' \donttest{
#'   master_data <- load_master_data()
#'   get_crosswalk("NIS_MUNICIPALITY_2019", "NUTS_DISTRICT_2021", master_data)
#'   get_crosswalk("POSTAL", "NIS_MUNICIPALITY_2019", master_data)
#'
#'   # With weights for the ambiguous Verviers split
#'   get_crosswalk("NIS_DISTRICT_2019", "NUTS_DISTRICT_2021", master_data,
#'                 weights = TRUE)
#' }
#' @export
get_crosswalk <- function(from, to, master_data, weights = FALSE) {
  from_norm <- normalize_classification_id(from)
  to_norm   <- normalize_classification_id(to)
  .validate_master_data(master_data)

  all_codes <- .list_codes_for(from_norm, master_data)
  result    <- suppressWarnings(
    convert_codes(all_codes, from_norm, to_norm, master_data,
                  allow_ambiguous = TRUE)
  )[, .(code_from, code_to)]   # nature is internal; crosswalk only needs code pairs

  if (weights) {
    result[, weight := 1.0]

    n_per  <- result[!is.na(code_to), .N, by = code_from]
    ambig  <- n_per[N > 1L, code_from]

    if (length(ambig) > 0L) {
      # Equal weights as baseline for ambiguous codes
      result[code_from %in% ambig, weight := 1 / .N, by = code_from]

      # Override with registered population weights when available
      reg <- get_split_weights(from_norm, to_norm, variable = "population")
      if (!is.null(reg)) {
        wdt <- reg[, .(code_from = as.character(code_from),
                       code_to   = as.character(code_to),
                       w         = as.numeric(weight))]
        result[, code_from := as.character(code_from)]
        result[, code_to   := as.character(code_to)]
        result <- merge(result, wdt, by = c("code_from", "code_to"), all.x = TRUE)
        result[!is.na(w), weight := w]
        result[, w := NULL]
      }
    }
  }

  setnames(result, c("code_from", "code_to"), c(from_norm, to_norm))
  if (weights) setcolorder(result, c(from_norm, to_norm, "weight"))
  result
}
