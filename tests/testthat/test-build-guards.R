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
