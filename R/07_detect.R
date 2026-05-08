# ==============================================================================
# 07_detect.R - Auto-detection of geographic classifications
# ==============================================================================

#' Auto-detect geographic classification from a vector of codes
#'
#' Matches the supplied codes against known reference sets from master_data
#' and returns the classification with the highest match rate (>= 80\%).
#' Returns NULL when no confident match is found.
#'
#' @param codes     Vector of codes (character or integer/numeric)
#' @param master_data Output from build_master_table()
#' @return Character classification identifier, or NULL if no confident match.
#' @examples
#' \donttest{
#'   master_data <- load_master_data()
#'   detect_classification(c(21004L, 11002L, 62063L), master_data)  # "NIS_COMMUNE_2019"
#'   detect_classification(c("BE100", "BE211"),        master_data)  # "NUTS3_2021"
#'   detect_classification(c(1000L, 2000L),            master_data)  # "POSTAL"
#' }
detect_classification <- function(codes, master_data) {

  codes_sample <- unique(na.omit(codes))
  if (length(codes_sample) == 0) return(NULL)
  # Use at most 50 values for speed
  codes_sample <- codes_sample[seq_len(min(50L, length(codes_sample)))]
  codes_chr    <- as.character(codes_sample)

  # --- Type-based pre-filter ---
  all_char <- all(grepl("^[A-Za-z]", codes_chr))
  all_int  <- all(grepl("^[0-9]+$",  codes_chr))

  if (all_char) {
    # NUTS codes: "BE" + 2/3/5 chars
    if      (all(nchar(codes_chr) == 5)) return("NUTS3_2021")
    else if (all(nchar(codes_chr) == 4)) return("NUTS2_2021")
    else if (all(nchar(codes_chr) <= 3)) return("NUTS1_2021")
    return(NULL)
  }

  if (!all_int) return(NULL)   # mixed or unknown

  # --- Integer codes: match against reference sets ---
  comm19 <- master_data$communes[nis_version == "2019"]
  comm25 <- master_data$communes[nis_version == "2025"]
  refs <- list(
    NIS_COMMUNE_2019        = as.character(comm19$cd_commune),
    NIS_COMMUNE_2025        = as.character(comm25$cd_commune),
    NIS_ARRONDISSEMENT_2019 = as.character(unique(comm19$cd_arr)),
    NIS_PROVINCE_2019       = as.character(unique(comm19$cd_province)),
    NIS_REGION_2019         = as.character(unique(comm19$cd_region)),
    POSTAL                  = as.character(master_data$postal[nis_version == "2019", cd_postal]),
    INTERNAL_ARRONDISSEMENT = as.character(unique(comm19[!is.na(cd_arr_internal), cd_arr_internal]))
  )

  comm_b19 <- master_data$communes[nis_version == "BEFORE_2019"]
  if (nrow(comm_b19) > 0L) {
    refs[["NIS_COMMUNE_BEFORE_2019"]] <- as.character(comm_b19$cd_commune)
  }

  rates <- vapply(refs, function(ref) mean(codes_chr %in% ref, na.rm = TRUE),
                  numeric(1))
  rates_dt <- data.table(classification = names(rates), rate = rates)[order(-rate)]

  best <- rates_dt[1]
  if (best$rate < 0.8) {
    message(sprintf(
      "Best match: %s (%.0f%%). Cannot auto-detect with confidence.",
      best$classification, best$rate * 100
    ))
    return(NULL)
  }

  # Disambiguate when multiple NIS commune versions match equally well.
  # Strategy: prefer the version that contains codes UNIQUE to it.
  # - BEFORE_2019 if any input code exists only in BEFORE_2019 (pre-fusion communes)
  # - NIS_2025    if any input code exists only in NIS_2025
  # - NIS_2019    as the stable default when codes exist in multiple versions
  nis_comm_candidates <- intersect(
    c("NIS_COMMUNE_BEFORE_2019", "NIS_COMMUNE_2019", "NIS_COMMUNE_2025"),
    rates_dt[rate >= best$rate * 0.95, classification]
  )

  if (length(nis_comm_candidates) > 1) {
    ref2019 <- refs[["NIS_COMMUNE_2019"]]
    ref2025 <- refs[["NIS_COMMUNE_2025"]]
    refb19  <- if ("NIS_COMMUNE_BEFORE_2019" %in% names(refs))
                 refs[["NIS_COMMUNE_BEFORE_2019"]] else character(0)

    has_before2019_only <- any(codes_chr %in% setdiff(refb19, ref2019))
    has_2025_only       <- any(codes_chr %in% setdiff(ref2025, ref2019))

    if      (has_before2019_only) return("NIS_COMMUNE_BEFORE_2019")
    else if (has_2025_only)       return("NIS_COMMUNE_2025")
    else                          return("NIS_COMMUNE_2019")
  }

  # Fallback priority for other ties
  close <- rates_dt[rate >= best$rate * 0.95]
  if (nrow(close) > 1) {
    priority <- c("NIS_COMMUNE_2019", "NIS_COMMUNE_2025", "NIS_COMMUNE_BEFORE_2019",
                  "NIS_ARRONDISSEMENT_2019", "NIS_PROVINCE_2019", "NIS_REGION_2019",
                  "POSTAL", "INTERNAL_ARRONDISSEMENT")
    for (p in priority) {
      if (p %in% close$classification) return(p)
    }
  }

  return(best$classification)
}
