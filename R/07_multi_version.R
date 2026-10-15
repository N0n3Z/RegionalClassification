# ==============================================================================
# 07_multi_version.R - Convert a code column that mixes several versions
# ==============================================================================

#' Convert a code column that mixes several classification versions
#'
#' Some datasets mix codes of several versions in one column, e.g. NIS
#' municipality codes that are mostly 2019 but include a few 2025 or
#' BEFORE_2019 codes. `convert_multi_version()` converts every code to `to` once
#' per candidate source version in `from`, independently, and reports where the
#' versions disagree or where no version knows the code.
#'
#' For each version in `from` a column is added with the result of treating
#' the code as a code of that version (`NA` when the code does not exist in
#' that version). A final column keeps, row by row, the first non-missing
#' value in the order of `from` (most recent version first by default). An
#' ambiguous conversion (one code with several targets, e.g. NIS 2025 commune
#' 46029 -> NUTS3 2021 BE234 and BE236) keeps the row and joins the sorted
#' candidates with `sep` (`"BE234+BE236"`); weight them afterwards with
#' [split_ambiguous()] if needed.
#'
#' @param dt A `data.table` or `data.frame`. It is not modified.
#' @param code_col Name of the column holding the codes.
#' @param to Target classification identifier (see [classification_reference]).
#' @param master_data Output from [load_master_data()].
#' @param from Candidate source classifications, in priority order. Defaults to
#'   the three NIS municipality versions, most recent first.
#' @param target_col Name of the final column. Defaults to
#'   `code_<lower-cased to>` (e.g. `code_nis_region_2019`).
#' @param sep Separator used to join the candidates of an ambiguous conversion.
#' @return A `data.table`: the rows and columns of `dt`, in the same order,
#'   followed by
#'   \describe{
#'     \item{one column per version in `from`}{named
#'       `<target_col>_from_<version>` (e.g. `code_nis_region_2019_from_2025`),
#'       or `<target_col>_from_<lower-cased id>` when two entries of `from`
#'       share a version.}
#'     \item{`target_col`}{the first non-missing value of those columns, in
#'       the order of `from`.}
#'     \item{`conflict`}{`TRUE` when the non-missing version columns of the row
#'       hold different values.}
#'     \item{`no_match`}{`TRUE` when every version column of the row is
#'       missing (unknown code in all versions, or missing code).}
#'     \item{`ambiguous`}{`TRUE` when at least one version column of the row
#'       holds several candidates.}
#'   }
#' @seealso [convert_dataset()] for a column with a single known version,
#'   [rebase_series()] when the version is known per period.
#' @examples
#' \donttest{
#'   master_data <- load_master_data()
#'   dt <- data.table::data.table(
#'     commune = c("21004", "46029", "54007", "99999"),
#'     value   = 1:4
#'   )
#'   # 46029 only exists in 2025, 54007 only before 2019, 99999 nowhere
#'   res <- convert_multi_version(dt, "commune", "NIS_REGION_2019", master_data)
#'   res
#'   res[conflict | no_match]
#' }
#' @export
convert_multi_version <- function(
  dt,
  code_col,
  to,
  master_data,
  from       = c(CLS_NIS_MUNICIPALITY_2025, CLS_NIS_MUNICIPALITY_2019,
                 CLS_NIS_MUNICIPALITY_BEFORE_2019),
  target_col = NULL,
  sep        = "+"
) {
  .validate_master_data(master_data)
  out <- if (is.data.table(dt)) copy(dt) else as.data.table(dt)

  if (!is.character(code_col) || length(code_col) != 1L || !code_col %in% names(out))
    abort(sprintf("Column '%s' not found in dataset. Available: %s",
                  paste(code_col, collapse = ", "), paste(names(out), collapse = ", ")),
          class = "rcl_invalid_input")
  if (length(from) == 0L)
    abort("`from` must list at least one source classification.", class = "rcl_invalid_input")

  to_norm   <- normalize_classification_id(to)
  from_norm <- vapply(from, normalize_classification_id, character(1L), USE.NAMES = FALSE)
  if (anyDuplicated(from_norm))
    abort(sprintf("`from` lists a classification twice: %s",
                  paste(unique(from_norm[duplicated(from_norm)]), collapse = ", ")),
          class = "rcl_invalid_input")
  if (!is.character(sep) || length(sep) != 1L || !nzchar(sep))
    abort("`sep` must be a non-empty string.", class = "rcl_invalid_input")
  # Check every route before converting anything: a version that cannot reach
  # `to` must fail loudly, not leave a silently empty column.
  no_route <- from_norm[!vapply(from_norm, .route_is_executable, logical(1L),
                                to = to_norm, md = master_data)]
  if (length(no_route) > 0L)
    abort(sprintf(paste0("No conversion route to '%s' from: %s. ",
                         "Drop them from `from` (see list_available_conversions())."),
                  to_norm, paste(no_route, collapse = ", ")),
          class = "rcl_no_route", from = no_route, to = to_norm)

  if (is.null(target_col)) target_col <- default_col_name(to_norm)
  versions <- vapply(from_norm, function(id) {
    v <- CLASSIFICATION_NODES[[id]]$version
    if (is.null(v) || is.na(v)) NA_character_ else v
  }, character(1L))
  suffix <- if (!anyNA(versions) && !anyDuplicated(versions)) tolower(versions) else tolower(from_norm)
  version_cols <- paste0(target_col, "_from_", suffix)

  new_cols <- c(version_cols, target_col, "conflict", "no_match", "ambiguous")
  clash <- intersect(new_cols, names(out))
  if (length(clash) > 0L)
    abort(sprintf("Column(s) already present in the dataset: %s. Rename them or set `target_col`.",
                  paste(clash, collapse = ", ")),
          class = "rcl_invalid_input")

  # Work on the distinct codes, then spread the results back onto the rows.
  raw_codes <- out[[code_col]]
  key   <- as.character(raw_codes)
  ucode <- unique(raw_codes)
  res   <- data.table(.key = as.character(ucode))
  for (i in seq_along(from_norm)) {
    set(res, j = version_cols[i],
        value = .convert_one_version(ucode, from_norm[i], to_norm, master_data, sep))
  }
  vals <- res[, version_cols, with = FALSE]
  n_distinct <- if (nrow(res) == 0L) integer(0) else
    apply(as.matrix(vals), 1L, function(x) length(unique(x[!is.na(x)])))
  set(res, j = target_col, value = do.call(fcoalesce, unname(as.list(vals))))
  set(res, j = "conflict",  value = n_distinct > 1L)
  set(res, j = "no_match",  value = n_distinct == 0L)
  set(res, j = "ambiguous", value = Reduce(`|`, lapply(vals, function(x)
    !is.na(x) & grepl(sep, x, fixed = TRUE))))

  idx <- match(key, res$.key)
  for (col in new_cols) set(out, j = col, value = res[[col]][idx])
  out[]
}

#' Convert codes as codes of one source version, one value per input code
#'
#' Codes that do not exist in `from` (per `entities`) give `NA`; the
#' candidates of an ambiguous conversion are sorted and joined with `sep`.
#' @noRd
.convert_one_version <- function(codes, from, to, master_data, sep) {
  canon <- .node_coerce(codes, from)
  known <- unique(canon[!is.na(canon) & canon %in% .entities_of(from, master_data)$code])
  result <- rep(NA_character_, length(canon))
  if (length(known) == 0L) return(result)

  conv <- suppressWarnings(
    convert_codes(known, from, to, master_data, allow_ambiguous = TRUE))
  conv <- conv[!is.na(code_to),
               .(code_to = paste(sort(unique(as.character(code_to))), collapse = sep)),
               by = code_from]
  result[] <- conv$code_to[match(canon, as.character(conv$code_from))]
  result
}
