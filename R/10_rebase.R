# ==============================================================================
# 10_rebase.R - Rebase longitudinal data across classification version changes
# ==============================================================================


#' Rebase a longitudinal dataset to a single classification version
#'
#' Converts a panel dataset that spans multiple classification versions onto a
#' single target version. For periods where codes were merged (N:1), values are
#' aggregated with `fun`. For periods already in the target version, rows are
#' kept as-is.
#'
#' The output only contains `period_col`, `code_col`, and `value_cols`. Any
#' other columns (labels, metadata) should be re-added afterwards using
#' [get_label()] or a join.
#'
#' @param data A `data.frame` or `data.table`.
#' @param period_col Name of the period column (e.g. `"year"`).
#' @param code_col Name of the geographic code column.
#' @param value_cols Character vector of value column names to aggregate.
#' @param version_map Named list mapping each source classification identifier
#'   to the vector of period values where it applies. Every period present in
#'   `data` must be covered; uncovered periods are dropped with a warning.
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
#'   same target code within a period (default: `sum`). The function receives a
#'   single numeric vector.
#' @return A `data.table` with columns `period_col`, `code_col`, and
#'   `value_cols`, with all codes expressed in the `to` classification.
#'
#' @section Warnings:
#' \describe{
#'   \item{`rcl_missing_periods`}{Some periods in `data` are not covered by
#'     `version_map` and will be dropped.}
#'   \item{`rcl_unmatched_codes`}{Some codes have no mapping to the target
#'     classification and will be dropped.}
#'   \item{`rcl_ambiguous_split`}{Some codes map to multiple target codes
#'     (1:N split). Values are replicated rather than distributed. Use
#'     [split_ambiguous_weights()] for proportional allocation.}
#' }
#'
#' @examples
#' \donttest{
#'   master_data <- load_master_data()
#'
#'   # Synthetic data spanning the 2019->2025 boundary
#'   data <- data.table::data.table(
#'     year      = rep(2020:2026, each = 3),
#'     commune   = rep(c(11002L, 11007L, 21004L), times = 7),
#'     population = c(18000, 8500, 180000,
#'                    18200, 8600, 181000,
#'                    18400, 8700, 182000,
#'                    18600, 8800, 183000,
#'                    18800, 8900, 184000,
#'                    # 2025: commune 11007 merged into 11002
#'                    28000, NA, 185000,
#'                    28500, NA, 186000)
#'   )
#'
#'   rebase_series(
#'     data,
#'     period_col  = "year",
#'     code_col    = "commune",
#'     value_cols  = "population",
#'     version_map = list("NIS_COMMUNE_2019" = 2020:2024,
#'                        "NIS_COMMUNE_2025" = 2025:2026),
#'     to          = "NIS_COMMUNE_2025",
#'     master_data = master_data
#'   )
#' }
#' @export
rebase_series <- function(data, period_col, code_col, value_cols,
                          version_map, to, master_data, fun = sum) {

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

    # No conversion needed when source == target
    if (from_cls == to_norm) return(chunk)

    # Retrieve mapping for unique codes in this chunk
    old_codes  <- unique(as.character(chunk[[code_col]]))
    mapping_dt <- suppressWarnings(
      convert_codes(old_codes, from_cls, to_norm, master_data, allow_ambiguous = TRUE)
    )
    mapping_dt[, code_from := as.character(code_from)]
    mapping_dt[, code_to   := as.character(code_to)]

    # Warn about 1:N splits (value replication, not distribution)
    splits <- mapping_dt[!is.na(code_to), .N, by = code_from][N > 1L]
    if (nrow(splits) > 0L)
      warn(
        sprintf(
          paste0(
            "%d code(s) map to multiple targets (%s -> %s): values will be ",
            "replicated, not distributed. Use split_ambiguous_weights() for ",
            "proportional allocation."
          ),
          nrow(splits), from_cls, to_norm
        ),
        class = "rcl_ambiguous_split"
      )

    # Join mapping onto chunk rows (allow M:N expansion via allow.cartesian)
    work <- copy(chunk)
    work[, .old_code := as.character(get(code_col))]

    result <- merge(work, mapping_dt,
                    by.x = ".old_code", by.y = "code_from",
                    all.x = TRUE, allow.cartesian = TRUE, sort = FALSE)

    # Warn and drop rows with no mapping
    n_unmatched <- sum(is.na(result[["code_to"]]))
    if (n_unmatched > 0L)
      warn(
        sprintf("%d row(s) with no mapping to %s will be dropped.", n_unmatched, to_norm),
        class = "rcl_unmatched_codes"
      )
    result <- result[!is.na(code_to)]

    set(result, j = code_col,   value = result[["code_to"]])
    result[, c(".old_code", "code_to") := NULL]
    result
  })

  chunks <- Filter(Negate(is.null), chunks)
  if (length(chunks) == 0L)
    return(data[0L, keep_cols, with = FALSE])

  combined <- rbindlist(chunks, use.names = TRUE, fill = TRUE)

  # Aggregate rows sharing the same (period, target code) — handles N:1 merges
  by_cols <- c(period_col, code_col)
  combined[, lapply(.SD, fun), by = by_cols, .SDcols = value_cols]
}
