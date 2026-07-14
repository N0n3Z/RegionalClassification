library(data.table)

# ==============================================================================
# test-build-guards.R -- build-time integrity guards (audit M7)
# ==============================================================================

test_that(".assert_unique_keys passes for unique keys and aborts on duplicates", {
  ok <- data.table(cd_commune = c(1L, 2L, 3L), nis_version = "2019", x = 1:3)
  expect_silent(nbbbenuts:::.assert_unique_keys(ok, c("cd_commune", "nis_version"), "ok"))

  dup <- data.table(cd_commune = c(1L, 1L, 2L), nis_version = "2019", x = 1:3)
  expect_error(
    nbbbenuts:::.assert_unique_keys(dup, c("cd_commune", "nis_version"), "dup"),
    class = "rcl_duplicate_keys"
  )
})

test_that("the shipped master tables satisfy the build uniqueness invariants", {
  # Guards that a future data refresh cannot silently reintroduce duplicate keys.
  expect_silent(
    nbbbenuts:::.assert_unique_keys(master_data$communes,
                                    c("cd_commune", "nis_version"), "communes")
  )
  expect_silent(
    nbbbenuts:::.assert_unique_keys(master_data$nis_changes,
                                    c("from_version", "cd_refnis_old"), "nis_changes")
  )
})

# -- M8: RDS-contract column guards -------------------------------------------
test_that(".assert_cols passes when columns present and aborts when missing", {
  dt <- data.table(a = 1, b = 2)
  expect_silent(nbbbenuts:::.assert_cols(dt, c("a", "b"), "dt"))
  expect_error(nbbbenuts:::.assert_cols(dt, c("a", "z"), "dt"),
               class = "rcl_schema_error")
})

test_that("the shipped saved tables carry their required columns", {
  nbbbenuts:::.assert_cols(master_data$postal,
                           c("cd_postal", "cd_commune_nis", "nis_version"), "postal")
  nbbbenuts:::.assert_cols(master_data$nis_changes,
                           c("cd_refnis_old", "cd_refnis_new", "nature", "from_version"),
                           "nis_changes")
  nbbbenuts:::.assert_cols(master_data$crosswalks,
                           c("from_id", "to_id", "code_from", "code_to", "nature"),
                           "crosswalks")
  succeed()
})

test_that("every POSTAL code resolves to NIS 2025 (no new-code drop, audit M8)", {
  # POSTAL universe = p19; a 2025-only postal code would be silently dropped.
  # The build asserts this, so here we just confirm the invariant holds in the
  # shipped data: every POSTAL source appears in the POSTAL -> NIS_2025 crosswalk.
  postal_src <- master_data$crosswalks[from_id == "POSTAL" & to_id == "NIS_MUNICIPALITY_2019",
                                       unique(code_from)]
  p25_src    <- master_data$crosswalks[from_id == "POSTAL" & to_id == "NIS_MUNICIPALITY_2025",
                                       unique(code_from)]
  expect_setequal(as.character(p25_src), as.character(postal_src))
})
