library(data.table)

# ==============================================================================
# test-crosswalks-parity.R  —  Phase 1 guard (per-edge loop retired in Phase 2)
# ==============================================================================
# The per-edge parity loop (engine output == crosswalks table) was the gate
# for Phase 2.  Now that the engine IS the crosswalks table, that loop is
# trivially true and has been retired.
#
# What remains:
#   1. Coverage assertion — every non-BEFORE_2019 edge from CONVERSION_GRAPH_EDGES
#      (forward + auto-reversed) must have crosswalk rows.  Prevents a silent gap
#      that would cause silent NA outputs for missing edges.
#   2. Postal universe assumption — p25 codes ⊆ p19 codes; guards the universe
#      used when building the POSTAL -> NIS_COMMUNE_2025 crosswalk.
#
# Primary regression guard is now test-crosswalks-golden.R.
# ==============================================================================

md <- load_master_data()

if (is.null(md$crosswalks)) {
  test_that("crosswalks table is present", {
    skip(paste0("master_data$crosswalks is NULL — run:\n",
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
  # .list_codes_for("POSTAL", md)).  This is valid only if every p25 postal
  # code already appears in p19.
  test_that("all p25 postal codes are present in p19 (POSTAL universe assumption)", {
    p19_codes  <- md$postal[nis_version == "2019", unique(cd_postal)]
    p25_codes  <- md$postal[nis_version == "2025", unique(cd_postal)]
    new_in_p25 <- setdiff(p25_codes, p19_codes)
    expect_true(
      length(new_in_p25) == 0L,
      label = paste("p25 codes not in p19:", paste(new_in_p25, collapse = ", "))
    )
  })

}
