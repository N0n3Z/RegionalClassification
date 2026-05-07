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
#' @param max_dist Maximum string distance for fuzzy matching (default 0.1 = 10%)
#' @param method Matching method: "osa" (default), "lv", "dl", "hamming",
#'   "lcs", "qgram", "cosine", "jaccard", "jw", "soundex"
#' @param language Preferred language for matching: "fr", "nl", or "both" (default)
#' @return data.table with input_name, matched_name, matched_code, distance, language
fuzzy_match_names <- function(names, target_classification, master_data,
                              max_dist = 0.1, method = "jw",
                              language = "both") {

  target <- normalize_classification_id(target_classification)

  # Build reference table based on target
  ref <- build_name_reference(target, master_data, language)

  if (nrow(ref) == 0) {
    stop(sprintf("No reference names found for classification '%s'", target))
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
    comm <- md$communes_nis2019
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
    comm <- md$communes_nis2025
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
    # Use postal names from both NIS versions (they should be the same)
    postal <- md$postal_to_nis2019
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
    comm <- md$communes_nis2019
    arr <- unique(comm[!is.na(tx_arr_fr), .(ref_code = cd_arr, tx_arr_fr, tx_arr_nl)])
    if (language %in% c("fr", "both")) {
      ref_list[["fr"]] <- arr[, .(ref_name = tx_arr_fr, ref_code, ref_language = "fr")]
    }
    if (language %in% c("nl", "both")) {
      ref_list[["nl"]] <- arr[!is.na(tx_arr_nl),
                               .(ref_name = tx_arr_nl, ref_code, ref_language = "nl")]
    }
  } else if (target == "NIS_ARRONDISSEMENT_2025") {
    comm <- md$communes_nis2025
    arr <- unique(comm[!is.na(tx_arr_fr), .(ref_code = cd_arr, tx_arr_fr, tx_arr_nl)])
    if (language %in% c("fr", "both")) {
      ref_list[["fr"]] <- arr[, .(ref_name = tx_arr_fr, ref_code, ref_language = "fr")]
    }
    if (language %in% c("nl", "both")) {
      ref_list[["nl"]] <- arr[!is.na(tx_arr_nl),
                               .(ref_name = tx_arr_nl, ref_code, ref_language = "nl")]
    }
  } else if (target == "NUTS3_2021") {
    nuts3 <- md$nuts3_ref_2021
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
    stop(sprintf("Fuzzy matching not supported for classification '%s'", target))
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

  # Remove accents
  n <- iconv(n, from = "UTF-8", to = "ASCII//TRANSLIT")

  # Remove common prefixes for arrondissements
  n <- gsub("^arrondissement\\s+(de\\s+|d'|van\\s+)", "", n)

  # Remove special characters but keep spaces and hyphens
  n <- gsub("[^a-z0-9 -]", "", n)

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

  if (length(all_results) == 0) {
    warning("No matches found in any classification")
    return(data.table())
  }

  combined <- rbindlist(all_results, use.names = TRUE, fill = TRUE)

  # For each input name, find the best match across all classifications
  best <- combined[, .SD[which.min(distance)], by = input_name]

  return(best)
}
