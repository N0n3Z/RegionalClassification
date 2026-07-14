library(data.table)

# ==============================================================================
# test-load-data.R -- unit tests for the validity-date filter (audit C3)
# ==============================================================================
# .filter_nuts_at_date() is the single selector of the "current" NUTS table for
# the whole 2019 master. Silently emptying a level here (max() over an NA, or a
# coverage-losing filter) would corrupt every downstream conversion, so it is
# guarded and tested directly on synthetic slices.
# ==============================================================================

flt <- function(...) nbbbenuts:::.filter_nuts_at_date(...)

mk <- function(stop_chr, start_chr = "2000-01-01") {
  data.table(
    id           = seq_along(stop_chr),
    DT_VLDT_STRT = as.POSIXct(start_chr, tz = "UTC"),
    DT_VLDT_STOP = as.POSIXct(stop_chr,  tz = "UTC")
  )
}

test_that("current (NULL) keeps the latest-stop rows, drops expired (sentinel encoding)", {
  dt  <- mk(c("2019-01-01", "9999-12-31", "9999-12-31", "2019-01-01"))
  out <- flt(dt, NULL)
  expect_equal(nrow(out), 2L)
  expect_setequal(out$id, c(2L, 3L))
})

test_that("current (NULL) treats NA stop as open-ended and keeps it", {
  # Mixed: one NA (open), one far-future, one expired. NA must survive; max()
  # must not be wiped by the NA (na.rm).
  dt  <- mk(c(NA, "9999-12-31", "2019-01-01"))
  out <- flt(dt, NULL)
  expect_true(1L %in% out$id)   # NA-open kept
  expect_true(2L %in% out$id)   # far-future kept
  expect_false(3L %in% out$id)  # expired dropped
})

test_that("current (NULL) with all-NA stops keeps every row (all open-ended)", {
  dt  <- mk(c(NA, NA, NA))
  out <- flt(dt, NULL)
  expect_equal(nrow(out), 3L)
})

test_that("reference_date keeps rows valid at that instant", {
  dt  <- mk(c("2019-01-01", "9999-12-31"), start_chr = c("2000-01-01", "2019-01-01"))
  # At 2018-06-30: row 1 valid (start<=date<stop), row 2 not yet (starts 2019).
  out <- flt(dt, as.Date("2018-06-30"))
  expect_equal(out$id, 1L)
  # At 2020-06-30: row 2 valid, row 1 expired.
  out2 <- flt(dt, as.Date("2020-06-30"))
  expect_equal(out2$id, 2L)
})

test_that("empty input returns empty without error", {
  dt <- mk(character(0))
  expect_equal(nrow(flt(dt, NULL)), 0L)
})

test_that("a non-empty level filtered to zero rows raises rcl_empty_level", {
  dt <- mk(c("2019-01-01", "2019-01-01"))
  # A reference date after every stop leaves no valid row -> loud failure.
  expect_error(flt(dt, as.Date("2030-01-01")), class = "rcl_empty_level")
})
