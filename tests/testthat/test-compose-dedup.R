library(data.table)

# ==============================================================================
# test-compose-dedup.R -- multi-hop composition dedup (audit M1)
# ==============================================================================
# A fan-out hop followed by a re-merging hop can map one source to the SAME
# target via several intermediates (Verviers 63000 -> {BE335, BE336} -> BE33).
# Those duplicate (code_from, code_to) rows must be collapsed, or split_ambiguous
# treats a non-ambiguous target as ambiguous and halves the value.
# ==============================================================================

test_that("Verviers arrondissement -> NUTS_PROVINCE_2021 yields a single BE33 row", {
  r <- suppressWarnings(
    convert_codes(63000L, CLS_NIS_DISTRICT_2019, CLS_NUTS_PROVINCE_2021,
                  master_data, allow_ambiguous = TRUE)
  )
  expect_equal(nrow(r), 1L)
  expect_equal(r$code_to, "BE33")
})

test_that("split_ambiguous does not double-count a re-merging path", {
  dat <- data.table(arr = 63000L, value = 100)
  sp  <- suppressWarnings(
    split_ambiguous(dat, "arr", value_cols = "value",
                    from = CLS_NIS_DISTRICT_2019, to = CLS_NUTS_PROVINCE_2021,
                    master_data = master_data, value_type = "additive")
  )
  expect_equal(nrow(sp), 1L)
  expect_equal(sp$value, 100)
})

test_that("a genuinely repeated input still yields one row per occurrence", {
  r <- suppressWarnings(
    convert_codes(c(63000L, 63000L), CLS_NIS_DISTRICT_2019, CLS_NUTS_PROVINCE_2021,
                  master_data, allow_ambiguous = TRUE)
  )
  expect_equal(nrow(r), 2L)
  expect_true(all(r$code_to == "BE33"))
})

test_that("a true M:N fan-out keeps its distinct targets (no over-dedup)", {
  # Verviers -> NUTS3 is genuinely 1:N: BE335 (FR) and BE336 (DE) are distinct.
  r <- suppressWarnings(
    convert_codes(63000L, CLS_NIS_DISTRICT_2019, CLS_NUTS_DISTRICT_2021,
                  master_data, allow_ambiguous = TRUE)
  )
  expect_equal(nrow(r), 2L)
  expect_setequal(r$code_to, c("BE335", "BE336"))
})
