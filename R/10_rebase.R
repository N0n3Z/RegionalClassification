# ==============================================================================
# 10_rebase.R - Rebase longitudinal data across classification version changes
# ==============================================================================


#' Rebase a longitudinal dataset to a single classification version
#'
#' Converts a panel dataset that spans multiple classification versions onto a
#' single target version.
#'
#' **Merges (N:1)** — several old codes map to one new code (e.g. two 2019
#' communes fused into one 2025 commune): values are aggregated with `fun`.
#'
#' **Splits (1:N)** — one old code maps to several new codes (e.g. arrondissement
#' Verviers 63000 -> NUTS3 BE335 + BE336): values are distributed proportionally
#' according to `split`. Register weights with [register_split_weights()] before
#' calling this function when population weights are needed.
#'
#' The output only contains `period_col`, `code_col`, and `value_cols`. Re-add
#' labels afterwards with [get_label()] or a join.
#'
#' @param data A `data.frame` or `data.table`.
#' @param period_col Name of the period column (e.g. `"year"`).
#' @param code_col Name of the geographic code column.
#' @param value_cols Character vector of value column names to aggregate.
#' @param version_map Named list mapping each source classification identifier
#'   to the vector of period values where it applies. Every period present in
#'   `data` should be covered; uncovered periods are dropped with a warning.
#'   Example:
#'   ```r
#'   list(
#'     "NIS_COMMUNE_2019" = 2010:2024,
#'     "NIS_COMMUNE_2025" = 2025:2030
#'   )
#'   ```
#' @param to Target classification identifier (see [classification_reference]).
#' @param master_data Output from [load_master_data()].
#' @param fun Aggregation function applied when multiple source codes map to the
#'   same target code within a period (default: `sum`). For ratio variables
#'   (rates, averages) use `mean` and set `value_type = "ratio"`.
#' @param split How to handle 1:N split codes. One of:
#'   \describe{
#'     \item{`"population"` (default)}{Use population weights registered via
#'       [register_split_weights()]. Falls back to equal weights with a warning
#'       if none are registered for the conversion pair.}
#'     \item{Any other character string}{Use the named variable from the
#'       [register_split_weights()] registry (e.g. `"employment"`).}
#'     \item{`data.table` with columns `code_from`, `code_to`, `weight`}{
#'       Explicit weights (see [register_split_weights()]).}
#'     \item{`NULL`}{Replicate values without distribution (old behaviour).
#'       A warning of class `rcl_ambiguous_split` is emitted.}
#'   }
#' @param value_type `"additive"` (default) or `"ratio"`. Additive variables
#'   (totals, counts) are multiplied by split weights. Ratio variables (rates,
#'   averages) are kept unchanged during splits; for N:1 merges, supply an
#'   appropriate `fun` (e.g. `mean`).
#' @return A `data.table` with columns `period_col`, `code_col`, and
#'   `value_cols`, with all codes expressed in the `to` classification.
#'
#' @section Warnings:
#' \describe{
#'   \item{`rcl_missing_periods`}{Some periods in `data` are not covered by
#'     `version_map` and will be dropped.}
#'   \item{`rcl_unmatched_codes`}{Some codes have no mapping to the target
#'     classification and will be dropped; also emitted when a requested weight
#'     variable is not registered (falls back to equal weights).}
#'   \item{`rcl_ambiguous_split`}{`split = NULL` and 1:N codes found: values
#'     are replicated. Pass `split = "population"` to distribute instead.}
#' }
#'
#' @seealso [register_split_weights()], [split_ambiguous()],
#'   [classification_reference]
#'
#' @examples
#' \donttest{
#'   master_data <- load_master_data()
#'
#'   # Communes 11002 and 11007 merged into 11002 in NIS 2025
#'   panel <- data.table::data.table(
#'     year      = c(2022L, 2022L, 2022L, 2025L, 2025L),
#'     commune   = c(11002L, 11007L, 21004L, 11002L, 21004L),
#'     population = c(18000, 8500, 180000, 28000, 185000)
#'   )
#'
#'   # Rebase to NIS 2025 — pre-2025 values for 11002+11007 are summed
#'   rebase_series(
#'     panel,
#'     period_col  = "year",
#'     code_col    = "commune",
#'     value_cols  = "population",
#'     version_map = list("NIS_COMMUNE_2019" = 2022L,
#'                        "NIS_COMMUNE_2025" = 2025L),
#'     to          = "NIS_COMMUNE_2025",
#'     master_data = master_data
#'   )
#' }
#' @export
rebase_series <- function(data, period_col, code_col, value_cols,
                          version_map, to, master_data,
                          fun        = sum,
                          split      = "population",
                          value_type = c("additive", "ratio")) {

  value_type <- match.arg(value_type)
  data    <- as.data.table(data)
  to_norm <- normalize_classification_id(to)
  .validate_master_data(master_data)

  # --- Validate version_map ---
  if (!is.list(version_map) ||
      is.null(names(version_map)) ||
      any(nchar(names(version_map)) == 0L))
    abort(
      "version_map must be a named list mapping classification identifiers to period vectors.",
      class = "rcl_invalid_input"
    )

  norm_map <- setNames(
    version_map,
    vapply(names(version_map), normalize_classification_id, character(1L))
  )

  # --- Validate columns ---
  missing_cols <- setdiff(c(period_col, code_col, value_cols), names(data))
  if (length(missing_cols) > 0L)
    abort(
      sprintf("Column(s) not found in data: %s", paste(missing_cols, collapse = ", ")),
      class = "rcl_invalid_input"
    )

  if (!is.function(fun))
    abort("'fun' must be a function (e.g. sum, mean).", class = "rcl_invalid_input")

  if (value_type == "ratio" && identical(fun, sum))
    warn(
      "value_type = 'ratio' with fun = sum will give incorrect results for merged codes. Consider fun = mean.",
      class = "rcl_invalid_input"
    )

  # --- Warn about uncovered periods ---
  all_periods <- as.character(unique(data[[period_col]]))
  covered     <- as.character(unlist(norm_map, use.names = FALSE))
  uncovered   <- setdiff(all_periods, covered)
  if (length(uncovered) > 0L)
    warn(
      sprintf(
        "%d period(s) not covered by version_map will be dropped: %s%s",
        length(uncovered),
        paste(head(sort(uncovered), 5L), collapse = ", "),
        if (length(uncovered) > 5L) ", ..." else ""
      ),
      class = "rcl_missing_periods"
    )

  # --- Process each classification chunk ---
  keep_cols <- c(period_col, code_col, value_cols)

  chunks <- lapply(names(norm_map), function(from_cls) {
    periods <- as.character(norm_map[[from_cls]])
    chunk   <- data[as.character(get(period_col)) %in% periods,
                    keep_cols, with = FALSE]
    if (nrow(chunk) == 0L) return(NULL)
    if (from_cls == to_norm) return(chunk)

    # --- With split handling (proportional distribution for 1:N codes) ---
    if (!is.null(split)) {
      result <- split_ambiguous(
        dt             = copy(chunk),
        code_col       = code_col,
        value_cols     = value_cols,
        from           = from_cls,
        to             = to_norm,
        master_data    = master_data,
        weights        = split,
        value_type     = value_type,
        target_col     = ".target_code",
        normalize      = TRUE,
        add_weight_col = FALSE,
        verbose        = FALSE
      )

      n_unmatched <- sum(is.na(result[[".target_code"]]))
      if (n_unmatched > 0L)
        warn(
          sprintf("%d row(s) with no mapping to %s will be dropped.", n_unmatched, to_norm),
          class = "rcl_unmatched_codes"
        )
      result <- result[!is.na(result[[".target_code"]])]
      set(result, j = code_col, value = result[[".target_code"]])
      result[, .target_code := NULL]
      return(result[, keep_cols, with = FALSE])
    }

    # --- Without split handling: replicate 1:N codes with a warning ---
    old_codes  <- unique(as.character(chunk[[code_col]]))
    mapping_dt <- suppressWarnings(
      convert_codes(old_codes, from_cls, to_norm, master_data, allow_ambiguous = TRUE)
    )
    mapping_dt[, code_from := as.character(code_from)]
    mapping_dt[, code_to   := as.character(code_to)]

    splits <- mapping_dt[!is.na(code_to), .N, by = code_from][N > 1L]
    if (nrow(splits) > 0L)
      warn(
        sprintf(
          paste0(
            "%d code(s) map to multiple targets (%s -> %s): values are replicated. ",
            "Set split = \"population\" for proportional allocation."
          ),
          nrow(splits), from_cls, to_norm
        ),
        class = "rcl_ambiguous_split"
      )

    work <- copy(chunk)
    work[, .old_code := as.character(get(code_col))]
    result <- merge(work, mapping_dt,
                    by.x = ".old_code", by.y = "code_from",
                    all.x = TRUE, allow.cartesian = TRUE, sort = FALSE)

    n_unmatched <- sum(is.na(result[["code_to"]]))
    if (n_unmatched > 0L)
      warn(
        sprintf("%d row(s) with no mapping to %s will be dropped.", n_unmatched, to_norm),
        class = "rcl_unmatched_codes"
      )
    result <- result[!is.na(code_to)]
    set(result, j = code_col, value = result[["code_to"]])
    result[, c(".old_code", "code_to") := NULL]
    result
  })

  chunks <- Filter(Negate(is.null), chunks)
  if (length(chunks) == 0L)
    return(data[0L, keep_cols, with = FALSE])

  combined <- rbindlist(chunks, use.names = TRUE, fill = TRUE)

  # Aggregate rows sharing the same (period, target code):
  #   - N:1 merges  → summed (or fun) from multiple old codes
  #   - 1:N splits  → already distributed by split_ambiguous, each target appears once
  by_cols <- c(period_col, code_col)
  combined[, lapply(.SD, fun), by = by_cols, .SDcols = value_cols]
}
