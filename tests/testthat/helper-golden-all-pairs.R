# ==============================================================================
# helper-golden-all-pairs.R  --  Reference snapshot of EVERY executable conversion
# ==============================================================================
# NOT executed by the test runner (no test_that() blocks). Run
# gen_golden_all_pairs() ONCE, with the current engine, to capture
# convert_codes() over every source code of every executable (from, to) pair,
# then commit tests/testthat/fixtures/golden_all_pairs.rds.
#
# It is the safety net of the atom-based engine (docs/plans/engine-redesign.md):
# the new engine must reproduce these links exactly.
# ==============================================================================

#' @noRd
gen_golden_all_pairs <- function(out_path = "tests/testthat/fixtures/golden_all_pairs.rds") {
  md  <- load_master_data()
  ids <- names(CLASSIFICATION_NODES)
  res <- list()
  for (f in ids) for (t in ids) {
    if (f == t || !nbbbenuts:::.route_is_executable(f, t, md)) next
    src <- nbbbenuts:::.list_codes_for(f, md)
    r <- suppressWarnings(suppressMessages(
      convert_codes(src, f, t, md, allow_ambiguous = TRUE)))
    res[[paste(f, t, sep = "__")]] <- data.table(
      classification_from = f, classification_to = t,
      code_from = as.character(r$code_from), code_to = as.character(r$code_to),
      nature = r$nature)
  }
  out <- rbindlist(res)
  setorder(out, classification_from, classification_to, code_from, code_to)
  saveRDS(out, out_path, compress = "xz")
  message(sprintf("golden_all_pairs: %d pairs, %d rows -> %s",
                  length(res), nrow(out), out_path))
  invisible(out)
}
