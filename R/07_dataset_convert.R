# ==============================================================================
# 07_dataset_convert.R - Dataset-level conversion and ambiguous split functions
# ==============================================================================

library(data.table)

# ==============================================================================
# 1. convert_dataset()
# ==============================================================================

#' Convert a geographic code column in a dataset
#'
#' High-level wrapper around convert_codes() that operates directly on a
#' data.table. Optionally auto-detects the source classification by matching
#' the column values against known code sets in master_data.
#'
#' @param dt         data.table (or data.frame, coerced automatically)
#' @param code_col   Name of the column containing source codes
#' @param to         Target classification (e.g. "NUTS3_2021")
#' @param master_data Output from build_master_table()
#' @param from       Source classification. NULL = auto-detect from values.
#' @param target_col Name of the new column to create. NULL = auto-generated.
#' @param keep_code  Keep the original code_col? Default TRUE.
#' @param verbose    Print conversion path info? Default TRUE.
#' @param allow_ambiguous Allow M:N conversions? Default FALSE.
#'   Use split_ambiguous() for weighted M:N handling.
#' @param na_action  "warn" (default): warn on unmatched codes and keep NAs;
#'                   "keep": silently keep NAs;
#'                   "drop": remove rows with unmatched codes.
#' @return data.table with target_col added after code_col.
#'   For M:N conversions, may return more rows than input.
#'
#' @examples
#' \dontrun{
#'   salaries <- data.table(commune = c(21004L, 11002L, 44021L), avg_salary = c(3200, 2900, 2700))
#'
#'   # Explicit source
#'   convert_dataset(salaries, "commune", "NUTS3_2021", master_data,
#'                   from = "NIS_COMMUNE_2019")
#'
#'   # Auto-detect source
#'   convert_dataset(salaries, "commune", "NUTS3_2021", master_data)
#' }
convert_dataset <- function(
  dt,
  code_col,
  to,
  master_data,
  from            = NULL,
  target_col      = NULL,
  keep_code       = TRUE,
  verbose         = TRUE,
  allow_ambiguous = FALSE,
  na_action       = c("warn", "keep", "drop")
) {
  na_action <- match.arg(na_action)

  if (!is.data.table(dt)) dt <- as.data.table(dt)
  dt <- copy(dt)

  if (!code_col %in% names(dt)) {
    stop(sprintf("Column '%s' not found in dataset. Available: %s",
                 code_col, paste(names(dt), collapse = ", ")))
  }

  # --- Auto-detect source classification ---
  if (is.null(from)) {
    if (verbose) message("Auto-detecting source classification for '", code_col, "'...")
    from <- detect_classification(dt[[code_col]], master_data)
    if (is.null(from)) {
      stop(sprintf(
        paste0("Could not auto-detect classification for column '%s'.\n",
               "Please specify 'from' explicitly."),
        code_col
      ))
    }
    if (verbose) message(sprintf("  Detected: %s", from))
  }

  from_norm <- normalize_classification_id(from)
  to_norm   <- normalize_classification_id(to)

  # --- Default target column name ---
  if (is.null(target_col)) {
    target_col <- default_col_name(to_norm)
  }

  # --- Check conversion path ---
  path_info <- check_conversion_path(from_norm, to_norm)
  if (verbose) print_conversion_check(from_norm, to_norm)

  if (!path_info$is_simple && !allow_ambiguous) {
    stop(sprintf(
      paste0("Conversion '%s' -> '%s' is NOT simple.\n",
             "Reason: %s\n",
             "Use allow_ambiguous = TRUE or split_ambiguous() for weighted splitting."),
      from_norm, to_norm, path_info$explanation
    ))
  }

  # --- Run conversion ---
  codes  <- dt[[code_col]]
  result <- convert_codes(codes, from_norm, to_norm, master_data,
                          allow_ambiguous = allow_ambiguous)

  # --- M:N case: result has more rows than input ---
  if (nrow(result) > length(codes)) {
    if (verbose) {
      message(sprintf(
        "  M:N conversion: %d input rows -> %d output rows (some codes have multiple targets).",
        nrow(dt), nrow(result)
      ))
    }
    result_merged <- merge(dt, result, by.x = code_col, by.y = "code_from",
                           all.x = TRUE, allow.cartesian = TRUE)
    setnames(result_merged, "code_to", target_col)
    if (na_action == "drop") result_merged <- result_merged[!is.na(get(target_col))]
    if (!keep_code) result_merged[, (code_col) := NULL]
    return(result_merged)
  }

  # --- 1:1 case ---
  dt[, (target_col) := result$code_to[match(codes, result$code_from)]]

  # Handle NAs
  n_na_input  <- sum(is.na(codes))
  n_na_output <- sum(is.na(dt[[target_col]]))
  n_unmatched <- n_na_output - n_na_input

  if (n_unmatched > 0) {
    msg <- sprintf("%d code(s) in '%s' could not be converted to '%s' (no match).",
                   n_unmatched, code_col, to_norm)
    if      (na_action == "warn") warning(msg)
    else if (na_action == "drop") {
      if (verbose) message(sprintf("  Dropping %d unmatched rows.", n_unmatched))
      dt <- dt[!is.na(get(target_col))]
    }
  }

  if (!keep_code) {
    dt[, (code_col) := NULL]
  } else {
    # Place target_col immediately after code_col
    cols      <- names(dt)
    idx       <- which(cols == code_col)
    new_order <- c(cols[seq_len(idx)],
                   target_col,
                   setdiff(cols[(idx + 1):length(cols)], target_col))
    setcolorder(dt, new_order)
  }

  if (verbose) {
    n_ok   <- sum(!is.na(dt[[target_col]]))
    n_miss <- nrow(dt) - n_ok
    message(sprintf("  -> Column '%s' added: %d converted, %d NA.",
                    target_col, n_ok, n_miss))
  }

  return(dt)
}


# ==============================================================================
# 2. detect_classification()
# ==============================================================================

#' Auto-detect geographic classification from a vector of codes
#'
#' Matches the supplied codes against known reference sets from master_data
#' and returns the classification with the highest match rate (>= 80%).
#' Returns NULL when no confident match is found.
#'
#' @param codes     Vector of codes (character or integer/numeric)
#' @param master_data Output from build_master_table()
#' @return Character classification identifier, or NULL
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
  refs <- list(
    NIS_COMMUNE_2019        = as.character(master_data$communes_nis2019$cd_commune),
    NIS_COMMUNE_2025        = as.character(master_data$communes_nis2025$cd_commune),
    NIS_ARRONDISSEMENT_2019 = as.character(unique(master_data$master_nis2019_nuts2021$cd_arr)),
    NIS_PROVINCE_2019       = as.character(unique(master_data$master_nis2019_nuts2021$cd_province)),
    NIS_REGION_2019         = as.character(unique(master_data$master_nis2019_nuts2021$cd_region)),
    POSTAL                  = as.character(master_data$postal_to_nis2019$cd_postal),
    INTERNAL_ARRONDISSEMENT = as.character(master_data$nuts_to_internal$cd_arr_internal)
  )

  if (!is.null(master_data$communes_nis_before2019)) {
    refs[["NIS_COMMUNE_BEFORE_2019"]] <-
      as.character(master_data$communes_nis_before2019$cd_commune)
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
    refb19  <- if (!is.null(master_data$communes_nis_before2019))
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


# ==============================================================================
# 3. split_ambiguous()
# ==============================================================================

#' Handle M:N conversions on a dataset using weighted splits
#'
#' When converting between classifications where some codes map to multiple
#' targets (e.g. arrondissement Verviers 63000 -> NUTS3 BE335 + BE336), this
#' function distributes value columns proportionally using supplied or
#' registered weights.
#'
#' @param dt         data.table with data to convert
#' @param code_col   Name of the column containing source codes
#' @param value_cols Character vector of column names to redistribute.
#'   For value_type="additive": multiplied by weight (totals, counts, sums).
#'   For value_type="ratio": kept unchanged (rates, averages, indices).
#' @param from       Source classification
#' @param to         Target classification
#' @param master_data Output from build_master_table()
#' @param weights    How to weight the split. One of:
#'   - NULL (default): use registry if available, otherwise equal weights
#'   - data.table with columns (code_from, code_to, weight)
#'   - character: name of a registered variable ("population", "employment", ...)
#' @param value_type "additive" or "ratio". See value_cols.
#' @param target_col Name of the new target code column. NULL = auto-generated.
#' @param normalize  Normalize weights to sum to 1 per code_from? Default TRUE.
#' @param add_weight_col Add a 'split_weight' column to the result? Default FALSE.
#' @param verbose    Print split summary? Default TRUE.
#' @return data.table. Ambiguous codes produce multiple rows; unambiguous codes
#'   produce one row each.
#'
#' @examples
#' \dontrun{
#'   arr_salaries <- data.table(
#'     arr_code   = c(11000L, 62000L, 63000L),   # 63000 = Verviers (ambiguous)
#'     total_wage = c(5e9, 3e9, 1e9),
#'     avg_salary = c(2900, 2700, 2400)
#'   )
#'
#'   # Equal weights (default)
#'   split_ambiguous(arr_salaries, "arr_code",
#'                   value_cols = c("total_wage", "avg_salary"),
#'                   from = "NIS_ARRONDISSEMENT_2019", to = "NUTS3_2021",
#'                   master_data,
#'                   value_type = "additive")
#'
#'   # Manual population weights for Verviers
#'   weights <- data.table(
#'     code_from = c(63000L, 63000L),
#'     code_to   = c("BE335", "BE336"),
#'     weight    = c(0.857, 0.143)
#'   )
#'   split_ambiguous(arr_salaries, "arr_code",
#'                   value_cols = "total_wage",
#'                   from = "NIS_ARRONDISSEMENT_2019", to = "NUTS3_2021",
#'                   master_data,
#'                   weights    = weights,
#'                   value_type = "additive")
#' }
split_ambiguous <- function(
  dt,
  code_col,
  value_cols,
  from,
  to,
  master_data,
  weights         = NULL,
  value_type      = c("additive", "ratio"),
  target_col      = NULL,
  normalize       = TRUE,
  add_weight_col  = FALSE,
  verbose         = TRUE
) {
  value_type <- match.arg(value_type)

  if (!is.data.table(dt)) dt <- as.data.table(dt)
  dt <- copy(dt)

  if (!code_col %in% names(dt)) {
    stop(sprintf("Column '%s' not found in dt.", code_col))
  }
  missing_val <- setdiff(value_cols, names(dt))
  if (length(missing_val) > 0) {
    stop(sprintf("value_cols not found in dt: %s", paste(missing_val, collapse = ", ")))
  }

  from_norm <- normalize_classification_id(from)
  to_norm   <- normalize_classification_id(to)

  if (is.null(target_col)) {
    target_col <- default_col_name(to_norm)
  }

  # --- Get full mapping (M:N allowed) ---
  all_codes <- unique(na.omit(dt[[code_col]]))
  all_map   <- convert_codes(all_codes, from_norm, to_norm, master_data,
                              allow_ambiguous = TRUE)

  map_counts  <- all_map[, .N, by = code_from]
  ambig_codes <- map_counts[N > 1, code_from]
  simple_map  <- all_map[!code_from %in% ambig_codes]

  if (verbose) {
    message(sprintf(
      "split_ambiguous: %d unique code(s), %d ambiguous (%s).",
      length(all_codes), length(ambig_codes),
      if (length(ambig_codes) > 0) paste(ambig_codes, collapse = ", ") else "none"
    ))
  }

  # --- No ambiguous codes: direct conversion ---
  if (length(ambig_codes) == 0) {
    if (verbose) message("  No ambiguous codes. Applying direct conversion.")
    dt[, (target_col) := all_map$code_to[match(get(code_col), all_map$code_from)]]
    return(dt)
  }

  # --- Resolve weights ---
  resolved <- .resolve_weights(ambig_codes, all_map, from_norm, to_norm,
                                weights, normalize, verbose)

  # --- Simple rows (1:1) ---
  dt_simple <- dt[!get(code_col) %in% ambig_codes]
  dt_simple[, (target_col) := simple_map$code_to[match(get(code_col), simple_map$code_from)]]
  if (add_weight_col) dt_simple[, split_weight := 1]

  # --- Ambiguous rows (1:N) ---
  dt_ambig <- dt[get(code_col) %in% ambig_codes]

  split_parts <- lapply(ambig_codes, function(ac) {
    rows <- dt_ambig[get(code_col) == ac]
    wts  <- resolved[code_from == ac]

    expanded <- rbindlist(lapply(seq_len(nrow(wts)), function(i) {
      row_copy <- copy(rows)
      row_copy[, (target_col) := wts$code_to[i]]
      w <- wts$weight[i]

      if (value_type == "additive") {
        for (vc in value_cols) {
          row_copy[, (vc) := get(vc) * w]
        }
      }
      # value_type == "ratio": keep values unchanged

      if (add_weight_col) row_copy[, split_weight := w]
      row_copy
    }))

    if (verbose) {
      message(sprintf("  Code %s split into:", ac))
      for (i in seq_len(nrow(wts))) {
        value_note <- if (value_type == "additive") "values redistributed"
                      else "values unchanged (ratio)"
        message(sprintf("    %s  weight=%.4f  (%s)",
                        wts$code_to[i], wts$weight[i], value_note))
      }
    }

    expanded
  })

  dt_split <- rbindlist(split_parts, use.names = TRUE, fill = TRUE)

  # --- Combine ---
  result <- rbindlist(list(dt_simple, dt_split), use.names = TRUE, fill = TRUE)

  if (verbose) {
    message(sprintf("  Result: %d rows (input: %d, +%d from splits).",
                    nrow(result), nrow(dt), nrow(result) - nrow(dt)))
  }

  return(result)
}


# ==============================================================================
# 4. Split Weight Registry
# ==============================================================================

.split_weight_registry <- new.env(parent = emptyenv())

#' Register split weights for an ambiguous conversion
#'
#' Stores a weighting table in the session registry for use by split_ambiguous().
#' Multiple variables (population, employment, etc.) can be registered for the
#' same conversion pair.
#'
#' @param from       Source classification
#' @param to         Target classification
#' @param weights_dt data.table with columns: code_from, code_to, weight
#' @param variable   Name of the weighting variable (default: "population")
#'
#' @examples
#' \dontrun{
#'   # Register population-based Verviers split (indicative values)
#'   register_split_weights(
#'     from       = "NIS_ARRONDISSEMENT_2019",
#'     to         = "NUTS3_2021",
#'     weights_dt = data.table(
#'       code_from = c(63000L, 63000L),
#'       code_to   = c("BE335", "BE336"),
#'       weight    = c(0.857, 0.143)
#'     ),
#'     variable   = "population"
#'   )
#' }
register_split_weights <- function(from, to, weights_dt, variable = "population") {
  from_norm  <- normalize_classification_id(from)
  to_norm    <- normalize_classification_id(to)
  weights_dt <- as.data.table(weights_dt)

  required <- c("code_from", "code_to", "weight")
  missing  <- setdiff(required, names(weights_dt))
  if (length(missing) > 0) {
    stop(sprintf("weights_dt must have columns: %s (missing: %s)",
                 paste(required, collapse = ", "), paste(missing, collapse = ", ")))
  }

  key <- paste(from_norm, to_norm, variable, sep = "__")
  assign(key, weights_dt, envir = .split_weight_registry)
  message(sprintf("  Registered split weights: %s -> %s [variable: %s, %d entries]",
                  from_norm, to_norm, variable, nrow(weights_dt)))
  invisible(NULL)
}

#' Retrieve registered split weights
#'
#' @param from     Source classification
#' @param to       Target classification
#' @param variable Weighting variable name (default: "population")
#' @return data.table(code_from, code_to, weight) or NULL
get_split_weights <- function(from, to, variable = "population") {
  from_norm <- normalize_classification_id(from)
  to_norm   <- normalize_classification_id(to)
  key       <- paste(from_norm, to_norm, variable, sep = "__")
  if (exists(key, envir = .split_weight_registry)) {
    return(get(key, envir = .split_weight_registry))
  }
  NULL
}

#' List all registered split weights
#'
#' @return data.table with columns (from, to, variable) or NULL
list_split_weights <- function() {
  keys <- ls(.split_weight_registry)
  if (length(keys) == 0) {
    message("No split weights registered.")
    return(invisible(NULL))
  }
  parts <- strsplit(keys, "__")
  data.table(
    from     = vapply(parts, `[`, character(1), 1),
    to       = vapply(parts, `[`, character(1), 2),
    variable = vapply(parts, `[`, character(1), 3)
  )
}


# ==============================================================================
# Internal helpers
# ==============================================================================

#' Default column name for a given classification
default_col_name <- function(classification) {
  mapping <- c(
    NIS_COMMUNE_BEFORE_2019  = "cd_nis_before2019",
    NIS_COMMUNE_2019         = "cd_nis2019",
    NIS_COMMUNE_2025         = "cd_nis2025",
    NIS_ARRONDISSEMENT_2019  = "cd_arr2019",
    NIS_ARRONDISSEMENT_2025  = "cd_arr2025",
    NIS_PROVINCE_2019        = "cd_prov2019",
    NIS_PROVINCE_2025        = "cd_prov2025",
    NIS_REGION_2019          = "cd_reg2019",
    NIS_REGION_2025          = "cd_reg2025",
    NUTS3_2021               = "cd_nuts3_2021",
    NUTS3_2027               = "cd_nuts3_2027",
    NUTS2_2021               = "cd_nuts2_2021",
    NUTS2_2027               = "cd_nuts2_2027",
    NUTS1_2021               = "cd_nuts1_2021",
    NUTS1_2027               = "cd_nuts1_2027",
    NUTS_LAU_2021            = "cd_lau2021",
    POSTAL                   = "cd_postal",
    INTERNAL_ARRONDISSEMENT  = "cd_arr_internal"
  )
  if (classification %in% names(mapping)) return(mapping[[classification]])
  paste0("cd_", tolower(classification))
}

#' Resolve weights for ambiguous codes (internal)
#'
#' @return data.table(code_from, code_to, weight) for all ambiguous codes
.resolve_weights <- function(ambig_codes, all_map, from, to, weights, normalize, verbose) {

  # Equal-weight fallback
  equal_wts <- all_map[code_from %in% ambig_codes,
                        .(code_from, code_to, weight = 1 / .N), by = code_from][
                        , .(code_from, code_to, weight)]

  resolved <-
    if (is.null(weights)) {
      reg <- get_split_weights(from, to)
      if (!is.null(reg)) {
        if (verbose) message("  Using default weights from registry.")
        .merge_weights(equal_wts, reg)
      } else {
        if (verbose) message("  No weights provided. Using equal weights.")
        equal_wts
      }

    } else if (is.character(weights) && length(weights) == 1) {
      reg <- get_split_weights(from, to, variable = weights)
      if (is.null(reg)) {
        warning(sprintf(
          "Weight variable '%s' not found in registry for %s -> %s. Using equal weights.",
          weights, from, to
        ))
        equal_wts
      } else {
        if (verbose) message(sprintf("  Using '%s' weights from registry.", weights))
        .merge_weights(equal_wts, reg)
      }

    } else if (is.data.table(weights) || is.data.frame(weights)) {
      wdt      <- as.data.table(weights)
      required <- c("code_from", "code_to", "weight")
      missing  <- setdiff(required, names(wdt))
      if (length(missing) > 0) {
        stop(sprintf("weights must have columns: %s (missing: %s)",
                     paste(required, collapse = ", "), paste(missing, collapse = ", ")))
      }
      relevant   <- wdt[code_from %in% ambig_codes]
      uncovered  <- setdiff(ambig_codes, unique(relevant$code_from))
      if (length(uncovered) > 0) {
        warning(sprintf("Weights not provided for: %s. Using equal weights for these.",
                        paste(uncovered, collapse = ", ")))
      }
      rbindlist(list(relevant, equal_wts[code_from %in% uncovered]), use.names = TRUE)

    } else {
      stop("'weights' must be NULL, a character string, or a data.table(code_from, code_to, weight).")
    }

  if (normalize) {
    resolved[, weight := weight / sum(weight), by = code_from]
  }

  resolved
}

#' Merge user/registry weights back onto the full mapping skeleton (internal)
.merge_weights <- function(skeleton, reg) {
  result <- merge(skeleton[, .(code_from, code_to)], reg,
                  by = c("code_from", "code_to"), all.x = TRUE)
  result[is.na(weight), weight := 1 / .N, by = code_from]
  result
}
