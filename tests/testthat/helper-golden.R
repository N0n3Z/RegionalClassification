# ==============================================================================
# helper-golden.R  --  Golden fixture generator for the crosswalks refactor
# ==============================================================================
# NOT executed automatically by the testthat runner (no test_that() blocks).
# Run gen_golden() ONCE with the current engine to capture reference output,
# then commit tests/testthat/fixtures/golden_crosswalks.rds.
# The golden test (test-crosswalks-golden.R) loads that fixture and asserts
# the engine still reproduces it -- trivially green in P0/P1, a real guard in P2+.
#
# Phase 2 note: .ROUTE_TABLE has been removed; gen_golden() now iterates the
# unique (from_id, to_id) pairs present in md$crosswalks instead.
# ==============================================================================

#' Generate and save the golden crosswalks fixture
#'
#' Captures (code_from, code_to, nature) for every directly-executable hop
#' derived from the crosswalks table, plus a small set of representative
#' multi-hop pairs.
#' @noRd
gen_golden <- function() {
  md   <- load_master_data()
  # Derive edge keys from the crosswalks table (Phase 2: .ROUTE_TABLE removed)
  keys <- unique(md$crosswalks[, paste0(from_id, "__", to_id)])

  # --- Per-hop golden (one block per crosswalk edge) ---
  per_edge <- rbindlist(lapply(keys, function(key) {
    parts <- strsplit(key, "__", fixed = TRUE)[[1]]
    from  <- parts[1L]
    to    <- parts[2L]
    src   <- nbbbenuts:::.list_codes_for(from, md)
    if (length(src) == 0L) {
      message(sprintf("  SKIP  %s  (no source codes)", key))
      return(NULL)
    }
    r <- suppressWarnings(suppressMessages(
      convert_codes(src, from, to, md, allow_ambiguous = TRUE)
    ))
    data.table(
      from_id   = from,
      to_id     = to,
      code_from = as.character(r$code_from),
      code_to   = as.character(r$code_to),
      nature    = r$nature
    )
  }), use.names = TRUE, fill = TRUE)

  # --- Multi-hop golden (representative composed paths) ---
  multihop_pairs <- list(
    c(CLS_POSTAL,                    CLS_NUTS3_2027),
    c(CLS_NUTS3_2021,                CLS_NUTS0),
    c(CLS_NIS_COMMUNE_2019,          CLS_NUTS3_2027),
    c(CLS_INTERNAL_ARRONDISSEMENT,   CLS_NUTS2_2021),
    c(CLS_NUTS_LAU_2021,             CLS_NIS_REGION_2019)
  )

  multihop <- rbindlist(lapply(multihop_pairs, function(pair) {
    from <- pair[1L]
    to   <- pair[2L]
    src  <- nbbbenuts:::.list_codes_for(from, md)
    if (length(src) == 0L) {
      message(sprintf("  SKIP multihop  %s -> %s  (no source codes)", from, to))
      return(NULL)
    }
    r <- suppressWarnings(suppressMessages(
      convert_codes(src, from, to, md, allow_ambiguous = TRUE)
    ))
    data.table(
      from_id   = from,
      to_id     = to,
      code_from = as.character(r$code_from),
      code_to   = as.character(r$code_to),
      nature    = r$nature
    )
  }), use.names = TRUE, fill = TRUE)

  fixture  <- list(per_edge = per_edge, multihop = multihop)
  out_path <- "tests/testthat/fixtures/golden_crosswalks.rds"
  saveRDS(fixture, out_path)
  message(sprintf(
    "Golden fixture saved: %d per-edge rows, %d multihop rows -> %s",
    nrow(per_edge), nrow(multihop), out_path
  ))
  invisible(fixture)
}
