# ==============================================================================
# 04_fuzzy_match.R - Fuzzy matching of geographic entity names
# ==============================================================================


#' Match entity names to classification codes using fuzzy matching
#'
#' Supports matching commune names, postal code names, and arrondissement names.
#'
#' @param names Character vector of names to match
#' @param target_classification Target classification to match against.
#'   One of: "NIS_COMMUNE_2019", "NIS_COMMUNE_2025", "POSTAL",
#'   "NIS_ARRONDISSEMENT_2019", "NIS_ARRONDISSEMENT_2025", "NUTS3_2021"
#' @param master_data Output from build_master_table()
#' @param max_dist Maximum string distance for fuzzy matching (default 0.1 = 10\%)
#' @param method Matching method: "osa" (default), "lv", "dl", "hamming",
#'   "lcs", "qgram", "cosine", "jaccard", "jw", "soundex"
#' @param language Preferred language for matching: "fr", "nl", or "both" (default)
#' @return data.table with input_name, matched_name, matched_code, distance, language
#' @examples
#' \donttest{
#'   master_data <- load_master_data()
#'
#'   # Match misspelled commune names
#'   fuzzy_match_names(c("Bruxeles", "Antwerpn", "Liege"),
#'                     "NIS_COMMUNE_2019", master_data)
#'
#'   # Match with looser threshold, prefer French names
#'   fuzzy_match_names(c("Bxl", "Anv"), "NIS_COMMUNE_2019", master_data,
#'                     max_dist = 0.5, language = "fr")
#' }
#' @export
fuzzy_match_names <- function(names, target_classification, master_data,
                              max_dist = 0.1, method = "jw",
                              language = "both") {

  target <- normalize_classification_id(target_classification)

  if (!requireNamespace("stringdist", quietly = TRUE)) {
    abort(
      "Package 'stringdist' is required for fuzzy matching. Install with: install.packages('stringdist')",
      class = "rcl_missing_package"
    )
  }

  # Build reference table based on target
  ref <- build_name_reference(target, master_data, language)

  if (nrow(ref) == 0) {
    abort(
      sprintf("No reference names found for classification '%s'", target),
      class = "rcl_invalid_input", classification = target
    )
  }

  # Perform matching
  results <- rbindlist(lapply(names, function(nm) {
    match_single_name(nm, ref, max_dist = max_dist, method = method)
  }))

  return(results)
}

#' Build a reference table of names and codes for a given classification
#'
#' @param target Normalized classification identifier
#' @param md Master data
#' @param language "fr", "nl", or "both"
#' @return data.table with ref_name, ref_code, ref_language
build_name_reference <- function(target, md, language = "both") {

  ref_list <- list()

  if (target == "NIS_COMMUNE_2019") {
    comm <- md$communes[nis_version == "2019"]
    if (language %in% c("fr", "both")) {
      ref_list[["fr"]] <- comm[!is.na(tx_commune_fr),
                                .(ref_name = tx_commune_fr, ref_code = cd_commune,
                                  ref_language = "fr")]
    }
    if (language %in% c("nl", "both")) {
      ref_list[["nl"]] <- comm[!is.na(tx_commune_nl),
                                .(ref_name = tx_commune_nl, ref_code = cd_commune,
                                  ref_language = "nl")]
    }
  } else if (target == "NIS_COMMUNE_2025") {
    comm <- md$communes[nis_version == "2025"]
    if (language %in% c("fr", "both")) {
      ref_list[["fr"]] <- comm[!is.na(tx_commune_fr),
                                .(ref_name = tx_commune_fr, ref_code = cd_commune,
                                  ref_language = "fr")]
    }
    if (language %in% c("nl", "both")) {
      ref_list[["nl"]] <- comm[!is.na(tx_commune_nl),
                                .(ref_name = tx_commune_nl, ref_code = cd_commune,
                                  ref_language = "nl")]
    }
  } else if (target == "POSTAL") {
    postal <- md$postal[nis_version == "2019"]
    if (language %in% c("fr", "both")) {
      ref_list[["fr"]] <- postal[!is.na(tx_postal_name_fr),
                                  .(ref_name = tx_postal_name_fr, ref_code = cd_postal,
                                    ref_language = "fr")]
    }
    if (language %in% c("nl", "both")) {
      ref_list[["nl"]] <- postal[!is.na(tx_postal_name_nl),
                                  .(ref_name = tx_postal_name_nl, ref_code = cd_postal,
                                    ref_language = "nl")]
    }
  } else if (target == "NIS_ARRONDISSEMENT_2019") {
    comm <- md$communes[nis_version == "2019"]
    arr <- unique(comm[!is.na(tx_arr_fr), .(ref_code = cd_arr, tx_arr_fr, tx_arr_nl)])
    if (language %in% c("fr", "both")) {
      ref_list[["fr"]] <- arr[, .(ref_name = tx_arr_fr, ref_code, ref_language = "fr")]
    }
    if (language %in% c("nl", "both")) {
      ref_list[["nl"]] <- arr[!is.na(tx_arr_nl),
                               .(ref_name = tx_arr_nl, ref_code, ref_language = "nl")]
    }
  } else if (target == "NIS_ARRONDISSEMENT_2025") {
    comm <- md$communes[nis_version == "2025"]
    arr <- unique(comm[!is.na(tx_arr_fr), .(ref_code = cd_arr, tx_arr_fr, tx_arr_nl)])
    if (language %in% c("fr", "both")) {
      ref_list[["fr"]] <- arr[, .(ref_name = tx_arr_fr, ref_code, ref_language = "fr")]
    }
    if (language %in% c("nl", "both")) {
      ref_list[["nl"]] <- arr[!is.na(tx_arr_nl),
                               .(ref_name = tx_arr_nl, ref_code, ref_language = "nl")]
    }
  } else if (target == "NUTS3_2021") {
    nuts3 <- unique(md$communes[nis_version == "2019" & !is.na(cd_nuts3),
                                 .(cd_nuts3, tx_nuts3_fr, tx_nuts3_nl)])
    if (language %in% c("fr", "both")) {
      ref_list[["fr"]] <- nuts3[!is.na(tx_nuts3_fr),
                                 .(ref_name = tx_nuts3_fr, ref_code = cd_nuts3,
                                   ref_language = "fr")]
    }
    if (language %in% c("nl", "both")) {
      ref_list[["nl"]] <- nuts3[!is.na(tx_nuts3_nl),
                                 .(ref_name = tx_nuts3_nl, ref_code = cd_nuts3,
                                   ref_language = "nl")]
    }
  } else {
    abort(
      sprintf("Fuzzy matching not supported for classification '%s'", target),
      class = "rcl_invalid_input", classification = target
    )
  }

  ref <- rbindlist(ref_list, use.names = TRUE)
  # Normalize reference names for matching
  ref[, ref_name_norm := normalize_name(ref_name)]
  ref <- unique(ref)

  return(ref)
}

#' Match a single name against a reference table
#'
#' @param name Input name to match
#' @param ref Reference data.table from build_name_reference()
#' @param max_dist Maximum relative distance
#' @param method String distance method
#' @return data.table with match results
match_single_name <- function(name, ref, max_dist = 0.1, method = "jw") {

  name_norm <- normalize_name(name)

  # Calculate string distances
  distances <- stringdist::stringdist(name_norm, ref$ref_name_norm, method = method)

  # Find best match(es)
  min_dist <- min(distances)
  best_idx <- which(distances == min_dist)

  if (min_dist > max_dist) {
    # Try with more relaxed matching
    # Return best match with a warning flag
    best <- ref[best_idx[1]]
    return(data.table(
      input_name = name,
      matched_name = best$ref_name,
      matched_code = best$ref_code,
      distance = min_dist,
      language = best$ref_language,
      is_confident = FALSE
    ))
  }

  # Return all matches at minimum distance
  best <- ref[best_idx]
  return(data.table(
    input_name = name,
    matched_name = best$ref_name,
    matched_code = best$ref_code,
    distance = min_dist,
    language = best$ref_language,
    is_confident = TRUE
  ))
}

#' Normalize a geographic name for fuzzy matching
#'
#' Removes accents, converts to lowercase, removes common prefixes, etc.
#'
#' @param name Character string
#' @return Normalized string
normalize_name <- function(name) {
  n <- tolower(trimws(name))

  # rawToChar(as.raw(...)) builds UTF-8 byte patterns that work in any locale.
  # useBytes=TRUE matches byte sequences directly, avoiding encoding mismatch errors.
  .s <- function(bytes, rep, s) gsub(rawToChar(as.raw(bytes)), rep, s, fixed = TRUE, useBytes = TRUE)

  n <- .s(c(0xC3,0xA0),"a",n); n <- .s(c(0xC3,0xA1),"a",n)  # a-grave, a-acute
  n <- .s(c(0xC3,0xA2),"a",n); n <- .s(c(0xC3,0xA3),"a",n)  # a-circ,  a-tilde
  n <- .s(c(0xC3,0xA4),"a",n); n <- .s(c(0xC3,0xA5),"a",n)  # a-uml,   a-ring
  n <- .s(c(0xC3,0xA8),"e",n); n <- .s(c(0xC3,0xA9),"e",n)  # e-grave, e-acute
  n <- .s(c(0xC3,0xAA),"e",n); n <- .s(c(0xC3,0xAB),"e",n)  # e-circ,  e-uml
  n <- .s(c(0xC3,0xAC),"i",n); n <- .s(c(0xC3,0xAD),"i",n)  # i-grave, i-acute
  n <- .s(c(0xC3,0xAE),"i",n); n <- .s(c(0xC3,0xAF),"i",n)  # i-circ,  i-uml
  n <- .s(c(0xC3,0xB2),"o",n); n <- .s(c(0xC3,0xB3),"o",n)  # o-grave, o-acute
  n <- .s(c(0xC3,0xB4),"o",n); n <- .s(c(0xC3,0xB5),"o",n)  # o-circ,  o-tilde
  n <- .s(c(0xC3,0xB6),"o",n)                                # o-uml
  n <- .s(c(0xC3,0xB9),"u",n); n <- .s(c(0xC3,0xBA),"u",n)  # u-grave, u-acute
  n <- .s(c(0xC3,0xBB),"u",n); n <- .s(c(0xC3,0xBC),"u",n)  # u-circ,  u-uml
  n <- .s(c(0xC3,0xA7),"c",n)                                # c-cedilla
  n <- .s(c(0xC3,0xB1),"n",n)                                # n-tilde
  n <- .s(c(0xC5,0x93),"oe",n)                               # oe-ligature
  n <- .s(c(0xC3,0xA6),"ae",n)                               # ae-ligature

  # Remove arrondissement prefix (ASCII-safe after accent stripping above)
  n <- gsub("^arrondissement\\s+(de\\s+|d'|van\\s+)", "", n, useBytes = TRUE)

  # Strip remaining non-ASCII bytes and special characters
  n <- gsub("[^a-z0-9 -]", "", n, useBytes = TRUE)

  # Normalize multiple spaces
  n <- gsub("\\s+", " ", n)

  return(n)
}

#' Identify codes from names (convenience wrapper)
#'
#' @param names Character vector of entity names
#' @param master_data Master data from build_master_table()
#' @param possible_classifications Vector of classifications to try
#'   (default: all supported)
#' @param max_dist Maximum distance threshold
#' @param language Preferred language
#' @return data.table with results including the best-matching classification
#' @examples
#' \donttest{
#'   master_data <- load_master_data()
#'   identify_from_names(c("Bruxelles", "Antwerpen", "Gent", "Liège"), master_data)
#' }
#' @export
identify_from_names <- function(names, master_data,
                                possible_classifications = c(
                                  "POSTAL", "NIS_COMMUNE_2019", "NIS_COMMUNE_2025",
                                  "NIS_ARRONDISSEMENT_2019", "NUTS3_2021"
                                ),
                                max_dist = 0.1,
                                language = "both") {

  all_results <- list()

  for (cls in possible_classifications) {
    tryCatch({
      res <- fuzzy_match_names(names, cls, master_data,
                               max_dist = max_dist, language = language)
      res[, classification := cls]
      all_results[[cls]] <- res
    }, error = function(e) {
      # Skip classifications that error
    })
  }

  combined <- if (length(all_results) > 0)
    rbindlist(all_results, use.names = TRUE, fill = TRUE)
  else
    data.table()

  if (nrow(combined) == 0) {
    warn("No matches found in any classification.", class = "rcl_unmatched_codes")
    return(data.table())
  }

  # For each input name, pick the best (lowest-distance) match across all classifications
  best <- combined[, .SD[which.min(distance)], by = input_name]

  unmatched <- best[is_confident == FALSE, input_name]
  if (length(unmatched) > 0) {
    warn(
      sprintf("No confident match found for: %s", paste(unmatched, collapse = ", ")),
      class = "rcl_unmatched_codes"
    )
  }

  return(best)
}
