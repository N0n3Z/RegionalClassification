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
#'   detect_classification(c(21004L, 11002L, 62063L), master_data)  # "NIS_MUNICIPALITY_2019"
#'   detect_classification(c("BE100", "BE211"),        master_data)  # "NUTS_DISTRICT_2021"
#'   detect_classification(c(1000L, 2000L),            master_data)  # "POSTAL"
#' }
#' @export
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
    # NUTS codes ("BE..."): match against the REAL reference sets rather than
    # guessing by nchar (audit C5). The old nchar rule always returned the 2021
    # vintage, so a NUTS3 2027 code (e.g. "BE261", which exists only in 2027) was
    # mislabelled NUTS_DISTRICT_2021 and "BE" (country) became NUTS_REGION_2021.
    # LAU codes (NUTS_MUNICIPALITY_2021) are numeric strings and never reach this
    # branch, so only the "BE"-prefixed nodes are candidates here.
    nuts_ids <- c("NUTS_COUNTRY",
                  "NUTS_REGION_2021", "NUTS_PROVINCE_2021", "NUTS_DISTRICT_2021",
                  "NUTS_REGION_2027", "NUTS_PROVINCE_2027", "NUTS_DISTRICT_2027")
    nrefs <- lapply(stats::setNames(nuts_ids, nuts_ids), function(id) {
      ref <- .node_reference_codes(id, master_data)
      if (is.null(ref)) NULL else as.character(ref$code)
    })
    nrefs <- Filter(Negate(is.null), nrefs)
    if (length(nrefs) == 0L) return(NULL)

    nrates   <- vapply(nrefs, function(ref) mean(codes_chr %in% ref), numeric(1))
    nrates_dt <- data.table(classification = names(nrates), rate = nrates)[order(-rate)]
    best      <- nrates_dt[1]

    if (best$rate < 0.8) {
      warn(
        sprintf("Cannot auto-detect classification with confidence (best match: %s at %.0f%%).",
                best$classification, best$rate * 100),
        class = "rcl_detection_failed",
        best_match = best$classification, best_rate = best$rate
      )
      return(NULL)
    }

    # Disambiguate ties -- chiefly the same-level 2021 vs 2027 pair. Prefer the
    # vintage that holds codes UNIQUE to it (2021 and 2027 NUTS3 codes are largely
    # disjoint for changed regions); on a pure tie (all codes shared) fall back to
    # a stable priority favouring the 2021 vintage.
    close <- nrates_dt[rate >= best$rate * 0.95, classification]
    if (length(close) > 1L) {
      excl <- vapply(close, function(id) {
        others <- unlist(nrefs[setdiff(close, id)], use.names = FALSE)
        sum(codes_chr %in% nrefs[[id]] & !(codes_chr %in% others))
      }, integer(1))
      if (max(excl) > 0L) return(close[which.max(excl)])
      priority <- c("NUTS_COUNTRY",
                    "NUTS_DISTRICT_2021", "NUTS_PROVINCE_2021", "NUTS_REGION_2021",
                    "NUTS_DISTRICT_2027", "NUTS_PROVINCE_2027", "NUTS_REGION_2027")
      for (p in priority) if (p %in% close) return(p)
    }
    return(best$classification)
  }

  if (!all_int) return(NULL)   # mixed or unknown

  # --- Integer codes: match against reference sets ---
  # Build refs from the registry (detectable=TRUE nodes only) to keep the
  # heuristic identical to the original hand-coded list.
  detectable_ids <- names(Filter(function(n) isTRUE(n$detectable), CLASSIFICATION_NODES))
  refs <- lapply(stats::setNames(detectable_ids, detectable_ids), function(id) {
    ref <- .node_reference_codes(id, master_data)
    if (is.null(ref)) return(NULL)
    as.character(ref$code)
  })
  refs <- Filter(Negate(is.null), refs)

  rates <- vapply(refs, function(ref) mean(codes_chr %in% ref, na.rm = TRUE),
                  numeric(1))
  rates_dt <- data.table(classification = names(rates), rate = rates)[order(-rate)]

  best <- rates_dt[1]
  if (best$rate < 0.8) {
    warn(
      sprintf("Cannot auto-detect classification with confidence (best match: %s at %.0f%%).",
              best$classification, best$rate * 100),
      class      = "rcl_detection_failed",
      best_match = best$classification,
      best_rate  = best$rate
    )
    return(NULL)
  }

  # Disambiguate when multiple NIS commune versions match equally well.
  # Strategy: prefer the version that contains codes UNIQUE to it.
  # - BEFORE_2019 if any input code exists only in BEFORE_2019 (pre-fusion communes)
  # - NIS_2025    if any input code exists only in NIS_2025
  # - NIS_2019    as the stable default when codes exist in multiple versions
  nis_comm_candidates <- intersect(
    c("NIS_MUNICIPALITY_BEFORE_2019", "NIS_MUNICIPALITY_2019", "NIS_MUNICIPALITY_2025"),
    rates_dt[rate >= best$rate * 0.95, classification]
  )

  if (length(nis_comm_candidates) > 1) {
    ref2019 <- refs[["NIS_MUNICIPALITY_2019"]]
    ref2025 <- refs[["NIS_MUNICIPALITY_2025"]]
    refb19  <- if ("NIS_MUNICIPALITY_BEFORE_2019" %in% names(refs))
                 refs[["NIS_MUNICIPALITY_BEFORE_2019"]] else character(0)

    has_before2019_only <- any(codes_chr %in% setdiff(refb19, ref2019))
    has_2025_only       <- any(codes_chr %in% setdiff(ref2025, ref2019))

    if      (has_before2019_only) return("NIS_MUNICIPALITY_BEFORE_2019")
    else if (has_2025_only)       return("NIS_MUNICIPALITY_2025")
    else                          return("NIS_MUNICIPALITY_2019")
  }

  # Fallback priority for other ties
  close <- rates_dt[rate >= best$rate * 0.95]
  if (nrow(close) > 1) {
    priority <- c("NIS_MUNICIPALITY_2019", "NIS_MUNICIPALITY_2025", "NIS_MUNICIPALITY_BEFORE_2019",
                  "NIS_DISTRICT_2019", "NIS_PROVINCE_2019", "NIS_REGION_2019",
                  "POSTAL", "NBB_DISTRICT_2021")
    for (p in priority) {
      if (p %in% close$classification) return(p)
    }
  }

  return(best$classification)
}
