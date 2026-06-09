# ==============================================================================
# 07_diagnose.R - Classification diagnostic tools
# ==============================================================================


#' Diagnose geographic code coverage against a classification
#'
#' Two modes:
#'
#' **Check mode** (`classification` supplied): verifies that the codes in
#' `code_col` are aligned with the given classification. Reports missing codes
#' (reference codes absent from the dataset), unknown codes (dataset codes not
#' in the reference), and duplicates.
#'
#' **Detect mode** (`classification = NULL`): ranks all known classifications
#' by how well they match the dataset codes and recommends the closest one.
#'
#' @param dt             data.table (or data.frame)
#' @param code_col       Name of the column containing geographic codes
#' @param master_data    Output from build_master_table()
#' @param classification Classification identifier (e.g. "NUTS3_2021"), or
#'   NULL to auto-rank all candidates.
#' @param verbose        Print a formatted diagnostic report? Default TRUE.
#' @return Invisibly, a list with diagnostic details (see Value section).
#'
#' @section Value (check mode):
#' \describe{
#'   \item{mode}{"check"}
#'   \item{classification}{Normalised classification identifier}
#'   \item{n_reference}{Total codes in the reference set}
#'   \item{n_in_dataset}{Reference codes found in the dataset}
#'   \item{n_missing}{Reference codes absent from the dataset}
#'   \item{n_unknown}{Dataset codes not in the reference}
#'   \item{n_duplicates}{Codes appearing more than once}
#'   \item{coverage_rate}{n_in_dataset / n_reference}
#'   \item{status}{"COMPLETE", "INCOMPLETE", or "INCOMPLETE_WITH_UNKNOWNS"}
#'   \item{missing_codes}{data.table of missing codes with labels}
#'   \item{unknown_codes}{data.table of unrecognised codes}
#'   \item{duplicate_codes}{data.table of duplicated codes with counts}
#' }
#'
#' @section Value (detect mode):
#' \describe{
#'   \item{mode}{"detect"}
#'   \item{recommendation}{Best-matching classification}
#'   \item{candidates}{data.table ranking all classifications}
#'   \item{detail}{Full check-mode result for the top candidate}
#' }
#'
#' @examples
#' \donttest{
#'   # Check mode
#'   nuts3_data <- data.table(nuts3 = c("BE100","BE211","BE332"), val = 1:3)
#'   diagnose_classification(nuts3_data, "nuts3", master_data,
#'                           classification = "NUTS3_2021")
#'
#'   # Detect mode
#'   diagnose_classification(nuts3_data, "nuts3", master_data)
#' }
#' @export
diagnose_classification <- function(
  dt,
  code_col,
  master_data,
  classification = NULL,
  verbose        = TRUE
) {
  if (!is.data.table(dt)) dt <- as.data.table(dt)

  if (!code_col %in% names(dt)) {
    abort(sprintf("Column '%s' not found. Available: %s",
                  code_col, paste(names(dt), collapse = ", ")),
          class = "rcl_invalid_input")
  }

  dataset_codes <- as.character(unique(na.omit(dt[[code_col]])))
  all_codes_chr <- as.character(dt[[code_col]])

  # ------------------------------------------------------------------
  # DETECT MODE
  # ------------------------------------------------------------------
  if (is.null(classification)) {
    return(.diagnose_detect(dt, code_col, dataset_codes, all_codes_chr,
                             master_data, verbose))
  }

  # ------------------------------------------------------------------
  # CHECK MODE
  # ------------------------------------------------------------------
  norm <- normalize_classification_id(classification)
  ref  <- .get_reference_codes(norm, master_data)

  if (is.null(ref)) {
    abort(sprintf("No reference set available for '%s'. Supported: %s",
                  norm, paste(.supported_classifications(), collapse = ", ")),
          class = "rcl_invalid_input")
  }

  ref_codes <- as.character(ref$code)

  missing_codes   <- setdiff(ref_codes, dataset_codes)
  unknown_codes   <- setdiff(dataset_codes, ref_codes)
  dup_counts      <- table(all_codes_chr[all_codes_chr %in% ref_codes])
  duplicate_codes <- names(dup_counts[dup_counts > 1])

  n_ref   <- length(ref_codes)
  n_match <- length(intersect(dataset_codes, ref_codes))
  n_miss  <- length(missing_codes)
  n_unk   <- length(unknown_codes)
  n_dup   <- length(duplicate_codes)
  cov     <- if (n_ref > 0) n_match / n_ref else NA_real_

  status <- if (n_miss == 0 && n_unk == 0) "COMPLETE"
            else if (n_miss > 0 && n_unk > 0) "INCOMPLETE_WITH_UNKNOWNS"
            else if (n_miss > 0)               "INCOMPLETE"
            else                               "COMPLETE_WITH_UNKNOWNS"

  # Build annotated tables
  missing_dt   <- .annotate_codes(missing_codes,   ref)
  unknown_dt   <- .annotate_codes(unknown_codes,   ref)
  duplicate_dt <- .annotate_codes(duplicate_codes, ref)
  if (nrow(duplicate_dt) > 0) {
    dup_n <- as.integer(dup_counts[duplicate_codes])
    duplicate_dt[, n_occurrences := dup_n]
  }

  parsed <- .parse_classification_id(norm)

  result <- list(
    mode                = "check",
    classification      = norm,
    classification_type = parsed$type,
    version             = parsed$version,
    n_reference         = n_ref,
    n_in_dataset        = n_match,
    n_missing           = n_miss,
    n_unknown           = n_unk,
    n_duplicates        = n_dup,
    coverage_rate       = cov,
    status              = status,
    missing_codes       = missing_dt,
    unknown_codes       = unknown_dt,
    duplicate_codes     = duplicate_dt
  )

  if (verbose) .print_check(result, code_col, nrow(dt))

  return(invisible(result))
}


# ------------------------------------------------------------------
# Detect mode internals
# ------------------------------------------------------------------

.diagnose_detect <- function(dt, code_col, dataset_codes, all_codes_chr,
                               master_data, verbose) {

  classifications <- .supported_classifications()

  rows <- rbindlist(lapply(classifications, function(cls) {
    ref <- .get_reference_codes(cls, master_data)
    if (is.null(ref)) return(NULL)

    parsed    <- .parse_classification_id(cls)
    ref_codes <- as.character(ref$code)
    n_ref     <- length(ref_codes)
    n_match   <- length(intersect(dataset_codes, ref_codes))
    n_miss    <- length(setdiff(ref_codes, dataset_codes))
    n_unk     <- length(setdiff(dataset_codes, ref_codes))
    match_pct <- if (length(dataset_codes) > 0) n_match / length(dataset_codes) else 0
    cov_pct   <- if (n_ref > 0) n_match / n_ref else 0
    unk_pct   <- if (length(dataset_codes) > 0) n_unk / length(dataset_codes) else 0

    data.table(
      classification      = cls,
      classification_type = parsed$type,
      version             = parsed$version,
      n_reference         = n_ref,
      n_matched           = n_match,
      n_missing           = n_miss,
      n_unknown           = n_unk,
      match_pct           = round(match_pct * 100, 1),
      coverage_pct        = round(cov_pct   * 100, 1),
      unknown_pct         = round(unk_pct   * 100, 1)
    )
  }))

  # Rank: primary = match_pct (desc), secondary = unknown_pct (asc)
  setorder(rows, -match_pct, unknown_pct)

  best        <- rows[1, classification]
  best_parsed <- .parse_classification_id(best)
  best_det    <- diagnose_classification(dt, code_col, master_data,
                                          classification = best, verbose = FALSE)

  result <- list(
    mode                = "detect",
    recommendation      = best,
    classification_type = best_parsed$type,
    version             = best_parsed$version,
    candidates          = rows,
    detail              = best_det
  )

  if (verbose) .print_detect(result, code_col, nrow(dt))

  return(invisible(result))
}


# ------------------------------------------------------------------
# Reference code sets
# ------------------------------------------------------------------

.get_reference_codes <- function(norm_classification, master_data) {
  .node_reference_codes(norm_classification, master_data)
}

.supported_classifications <- function() {
  sort(VALID_CLASSIFICATIONS)
}

.annotate_codes <- function(codes, ref) {
  if (length(codes) == 0) {
    return(data.table(code = character(0), name_fr = character(0),
                      name_nl = character(0)))
  }
  ref_sub <- ref[as.character(ref$code) %in% as.character(codes)]
  if (nrow(ref_sub) == 0) {
    return(data.table(code = codes, name_fr = NA_character_, name_nl = NA_character_))
  }
  # codes not in ref (truly unknown)
  not_in_ref <- setdiff(as.character(codes), as.character(ref_sub$code))
  extra <- if (length(not_in_ref) > 0)
    data.table(code = not_in_ref, name_fr = NA_character_, name_nl = NA_character_)
  else
    NULL
  result <- rbindlist(list(ref_sub[, .(code = as.character(code), name_fr, name_nl)],
                           extra), use.names = TRUE, fill = TRUE)
  result[order(code)]
}


# ------------------------------------------------------------------
# Print helpers
# ------------------------------------------------------------------

.print_check <- function(res, code_col, n_rows) {
  bar <- strrep("=", 64)
  ver_str <- if (!is.na(res$version)) res$version else "--"
  cat(sprintf("\n%s\n", bar))
  cat("  CLASSIFICATION DIAGNOSTIC\n")
  cat(sprintf("%s\n", bar))
  cat(sprintf("  Dataset        : %d rows  |  column '%s'\n", n_rows, code_col))
  cat(sprintf("  Classification : %s\n", res$classification_type))
  cat(sprintf("  Version        : %s\n", ver_str))
  cat(sprintf("  Reference      : %s  (%d codes)\n", res$classification, res$n_reference))
  cat(sprintf("%s\n", bar))

  # Coverage bar
  pct   <- round(res$coverage_rate * 100, 1)
  bar20 <- strrep("#", round(pct / 5))
  pad20 <- strrep("-", 20 - nchar(bar20))
  cat(sprintf("  Coverage   : %d / %d  [%s%s] %s%%\n",
              res$n_in_dataset, res$n_reference, bar20, pad20, pct))
  cat(sprintf("  Unknown    : %d code(s) in dataset not in reference\n", res$n_unknown))
  cat(sprintf("  Duplicates : %d code(s) appearing more than once\n\n", res$n_duplicates))

  # Missing codes
  if (res$n_missing > 0) {
    cat(sprintf("  Missing codes (%d) -- present in reference but absent from dataset:\n",
                res$n_missing))
    .print_code_table(res$missing_codes)
    cat("\n")
  }

  # Unknown codes
  if (res$n_unknown > 0) {
    cat(sprintf("  Unknown codes (%d) -- present in dataset but not in reference:\n",
                res$n_unknown))
    .print_code_table(res$unknown_codes)
    cat("\n")
  }

  # Duplicates
  if (res$n_duplicates > 0) {
    cat(sprintf("  Duplicate codes (%d):\n", res$n_duplicates))
    dup <- res$duplicate_codes
    for (i in seq_len(nrow(dup))) {
      cat(sprintf("    %-10s  n=%d  %s\n",
                  dup$code[i],
                  if ("n_occurrences" %in% names(dup)) dup$n_occurrences[i] else NA,
                  .fmt_names(dup$name_fr[i], dup$name_nl[i])))
    }
    cat("\n")
  }

  # Status
  status_label <- switch(res$status,
    COMPLETE                  = "OK  COMPLETE -- all reference codes present",
    INCOMPLETE                = "!!  INCOMPLETE -- missing reference codes",
    COMPLETE_WITH_UNKNOWNS    = "~~  COMPLETE (with unrecognised codes)",
    INCOMPLETE_WITH_UNKNOWNS  = "!!  INCOMPLETE + unrecognised codes"
  )
  cat(sprintf("  Status: %s\n", status_label))
  cat(sprintf("%s\n\n", bar))
}

.print_detect <- function(res, code_col, n_rows) {
  bar     <- strrep("=", 64)
  ver_str <- if (!is.na(res$version)) res$version else "--"

  cat(sprintf("\n%s\n", bar))
  cat("  CLASSIFICATION AUTO-DETECTION\n")
  cat(sprintf("%s\n", bar))
  cat(sprintf("  Dataset : %d rows  |  column '%s'\n\n", n_rows, code_col))

  # Candidates table
  top <- head(res$candidates, 8)
  cat(sprintf("  %-24s  %-12s  %7s  %8s  %8s\n",
              "Classification", "Version", "Match%", "Cover%", "Unknown%"))
  cat(sprintf("  %s\n", strrep("-", 66)))
  for (i in seq_len(nrow(top))) {
    marker  <- if (i == 1) " <-- best" else ""
    ver_col <- if (!is.na(top$version[i])) top$version[i] else "--"
    cat(sprintf("  %-24s  %-12s  %6.1f%%  %7.1f%%  %7.1f%%%s\n",
                top$classification_type[i],
                ver_col,
                top$match_pct[i],
                top$coverage_pct[i],
                top$unknown_pct[i],
                marker))
  }

  cat(sprintf("\n%s\n", strrep("-", 64)))
  cat(sprintf("  Recommendation\n"))
  cat(sprintf("    Classification : %s\n", res$classification_type))
  cat(sprintf("    Version        : %s\n", ver_str))
  cat(sprintf("    Identifier     : %s\n", res$recommendation))
  cat(sprintf("    Coverage       : %d / %d codes present (%.1f%%)\n",
              res$detail$n_in_dataset,
              res$detail$n_reference,
              res$detail$coverage_rate * 100))

  if (res$detail$n_missing > 0) {
    n_show        <- min(5L, res$detail$n_missing)
    miss          <- res$detail$missing_codes
    codes_preview <- paste(head(miss$code, n_show), collapse = ", ")
    suffix        <- if (res$detail$n_missing > n_show)
      sprintf(" ... (+%d more)", res$detail$n_missing - n_show) else ""
    cat(sprintf("    Missing codes  : %s%s\n", codes_preview, suffix))
  }
  cat(sprintf("%s\n\n", bar))
}

.print_code_table <- function(dt, max_rows = 20L) {
  show <- head(dt, max_rows)
  for (i in seq_len(nrow(show))) {
    cat(sprintf("    %-12s  %s\n",
                show$code[i],
                .fmt_names(show$name_fr[i], show$name_nl[i])))
  }
  if (nrow(dt) > max_rows) {
    cat(sprintf("    ... (%d more)\n", nrow(dt) - max_rows))
  }
}

.fmt_names <- function(fr, nl) {
  has_fr <- !is.na(fr) && nchar(fr) > 0
  has_nl <- !is.na(nl) && nchar(nl) > 0
  if      ( has_fr &&  has_nl && fr != nl) sprintf("%s / %s", fr, nl)
  else if ( has_fr &&  has_nl && fr == nl) fr
  else if ( has_fr && !has_nl)             fr
  else if (!has_fr &&  has_nl)             nl
  else                                     ""
}

#' @noRd
.parse_classification_id <- function(norm_id) .node_parse(norm_id)
