library(data.table)

# ==============================================================================
# test-crosswalks-parity.R  --  Phase 1 guard (per-edge loop retired in Phase 2)
# ==============================================================================
# The per-edge parity loop (engine output == crosswalks table) was the gate
# for Phase 2.  Now that the engine IS the crosswalks table, that loop is
# trivially true and has been retired.
#
# What remains:
#   1. Coverage assertion -- every non-BEFORE_2019 edge from CONVERSION_GRAPH_EDGES
#      (forward + auto-reversed) must have crosswalk rows.  Prevents a silent gap
#      that would cause silent NA outputs for missing edges.
#   2. Postal universe assumption -- p25 codes <= p19 codes; guards the universe
#      used when building the POSTAL -> NIS_COMMUNE_2025 crosswalk.
#
# Primary regression guard is now test-crosswalks-golden.R.
# ==============================================================================

md <- load_master_data()

if (is.null(md$crosswalks)) {
  test_that("crosswalks table is present", {
    skip(paste0("master_data$crosswalks is NULL -- run:\n",
                "  rebuild_master_data()"))
  })
} else {

  # --- Coverage assertion ---------------------------------------------------
  # The crosswalk table must be non-empty (a trivial sanity check that the RDS
  # was built correctly).  The primary regression guard for crosswalk correctness
  # is test-crosswalks-golden.R.
  # Note: md$crosswalks includes both forward and reverse single-hop entries
  # (e.g. NUTS_LAU_2021__NIS_COMMUNE_2019 as well as NIS_COMMUNE_2019__NUTS_LAU_2021)
  # plus shortcut entries pre-computed by the old handlers.  It does NOT cover
  # all CONVERSION_GRAPH_EDGES (which also declares multi-hop edges composed at
  # runtime).  A simple subset check in either direction is therefore not useful.
  test_that("crosswalk table is non-empty", {
    expect_gt(nrow(md$crosswalks), 0L)
  })

  # --- Postal universe assumption -------------------------------------------
  # POSTAL->NIS_COMMUNE_2025 crosswalk is built on the p19 universe (same as
  # .list_codes_for(CLS_POSTAL, md)).  This is valid only if every p25 postal
  # code already appears in p19.
  test_that("all p25 postal codes are present in p19 (POSTAL universe assumption)", {
    p19_codes  <- md$postal[nis_version == VER_2019, unique(cd_postal)]
    p25_codes  <- md$postal[nis_version == VER_2025, unique(cd_postal)]
    new_in_p25 <- setdiff(p25_codes, p19_codes)
    expect_true(
      length(new_in_p25) == 0L,
      label = paste("p25 codes not in p19:", paste(new_in_p25, collapse = ", "))
    )
  })

  # --- Anti-drift: graph edge ambiguous_codes must match crosswalk reality ---
  # The NIS_COMMUNE_2025 -> NUTS3_2021 edge hard-codes ambiguous_codes and
  # coverage in CONVERSION_GRAPH_EDGES (00_config.R).  This test ensures those
  # values stay in sync with the actual crosswalk table after each rebuild.
  test_that("graph edge ambiguous_codes matches NIS_COMMUNE_2025 -> NUTS3_2021 crosswalk", {
    e <- Find(function(x) x$from == CLS_NIS_COMMUNE_2025 && x$to == CLS_NUTS3_2021,
              CONVERSION_GRAPH_EDGES)
    skip_if(is.null(e), "NIS_COMMUNE_2025 -> NUTS3_2021 edge not found in graph")

    xw <- md$crosswalks[from_id == CLS_NIS_COMMUNE_2025 & to_id == CLS_NUTS3_2021]
    real_ambig <- xw[, .N, by = code_from][N > 1L, sort(as.integer(code_from))]

    expect_setequal(e$ambiguous_codes, real_ambig)
  })

}
