# ==============================================================================
# 07_dataset_convert.R - Dataset-level geographic code conversion
# ==============================================================================



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
    abort(sprintf("Column '%s' not found in dataset. Available: %s",
                  code_col, paste(names(dt), collapse = ", ")),
          class = "rcl_invalid_input")
  }

  # --- Auto-detect source classification ---
  if (is.null(from)) {
    if (verbose) message("Auto-detecting source classification for '", code_col, "'...")
    from <- detect_classification(dt[[code_col]], master_data)
    if (is.null(from)) {
      abort(sprintf("Could not auto-detect classification for column '%s'. Specify 'from' explicitly.",
                    code_col),
            class = "rcl_detection_failed")
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
    abort(
      sprintf("Conversion '%s' -> '%s' is NOT simple. Use allow_ambiguous = TRUE or split_ambiguous() for weighted splitting.",
              from_norm, to_norm),
      class = "rcl_ambiguous_conversion", from = from_norm, to = to_norm,
      explanation = path_info$explanation
    )
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
    if      (na_action == "warn") warn(msg, class = "rcl_unmatched_codes")
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
# Internal helpers shared across 07_*.R files
# ==============================================================================


#' Default column name for a given classification
#' @param classification Classification identifier string
#' @return Character scalar: snake_case column name for the classification
#' @keywords internal
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
