library(data.table)

# -- Test D1: check mode -- COMPLETE status -------------------------------------
test_that("diagnose_classification check mode returns COMPLETE for full coverage", {
  all_nuts3 <- nbbbenuts:::.list_codes_for(CLS_NUTS_DISTRICT_2021, master_data)
  dt <- data.table(nuts3 = all_nuts3, val = seq_along(all_nuts3))
  result <- diagnose_classification(dt, "nuts3", master_data,
                                    classification = CLS_NUTS_DISTRICT_2021,
                                    verbose = FALSE)
  expect_equal(result$mode, "check")
  expect_equal(result$status, "COMPLETE")
  expect_equal(result$n_missing, 0L)
  expect_equal(result$n_unknown, 0L)
  expect_equal(result$coverage_rate, 1)
})

# -- Test D2: check mode -- INCOMPLETE status -----------------------------------
test_that("diagnose_classification detects missing codes", {
  dt <- data.table(nuts3 = c("BE100", "BE211"), val = 1:2)
  result <- diagnose_classification(dt, "nuts3", master_data,
                                    classification = CLS_NUTS_DISTRICT_2021,
                                    verbose = FALSE)
  expect_equal(result$status, "INCOMPLETE")
  expect_gt(result$n_missing, 0L)
  expect_equal(result$n_unknown, 0L)
  expect_true(result$coverage_rate < 1)
})

# -- Test D3: check mode -- COMPLETE_WITH_UNKNOWNS ------------------------------
test_that("diagnose_classification detects unknown codes", {
  all_nuts3 <- nbbbenuts:::.list_codes_for(CLS_NUTS_DISTRICT_2021, master_data)
  dt <- data.table(nuts3 = c(all_nuts3, "ZZZZ"), val = seq_along(c(all_nuts3, "ZZZZ")))
  result <- diagnose_classification(dt, "nuts3", master_data,
                                    classification = CLS_NUTS_DISTRICT_2021,
                                    verbose = FALSE)
  expect_equal(result$n_unknown, 1L)
  expect_equal(result$status, "COMPLETE_WITH_UNKNOWNS")
})

# -- Test D4: check mode -- duplicate codes detected ----------------------------
test_that("diagnose_classification counts duplicate codes", {
  dt <- data.table(nuts3 = c("BE100", "BE100", "BE211"), val = 1:3)
  result <- diagnose_classification(dt, "nuts3", master_data,
                                    classification = CLS_NUTS_DISTRICT_2021,
                                    verbose = FALSE)
  expect_equal(result$n_duplicates, 1L)
})

# -- Test D5: check mode -- rcl_invalid_classification for unknown id -----------
test_that("diagnose_classification errors for unknown classification identifier", {
  dt <- data.table(code = "BE100", val = 1)
  expect_error(
    diagnose_classification(dt, "code", master_data,
                            classification = "MAUVAISE_CLASSIF"),
    class = "rcl_invalid_classification"
  )
})

# -- Test D6: check mode -- rcl_invalid_input for missing column ----------------
test_that("diagnose_classification errors when code column not found", {
  dt <- data.table(x = "BE100", val = 1)
  expect_error(
    diagnose_classification(dt, "INEXISTANT", master_data,
                            classification = CLS_NUTS_DISTRICT_2021),
    class = "rcl_invalid_input"
  )
})

# -- Test D7: detect mode -- recommends the best matching classification ---------
test_that("diagnose_classification detect mode recommends correct classification", {
  all_nuts3 <- nbbbenuts:::.list_codes_for(CLS_NUTS_DISTRICT_2021, master_data)
  dt <- data.table(nuts3 = head(all_nuts3, 20), val = 1:20)
  result <- diagnose_classification(dt, "nuts3", master_data, verbose = FALSE)
  expect_equal(result$mode, "detect")
  expect_equal(result$recommendation, CLS_NUTS_DISTRICT_2021)
  expect_true(is.data.table(result$candidates))
})

# -- Test D8: now covers all VALID_CLASSIFICATIONS (no NULL ref for any) --------
test_that("diagnose_classification covers every VALID_CLASSIFICATION", {
  skip_if(is.null(master_data$communes))

  for (cls in VALID_CLASSIFICATIONS) {
    ref <- nbbbenuts:::.get_reference_codes(cls, master_data)
    expect_false(
      is.null(ref),
      label = sprintf(".get_reference_codes('%s') should not return NULL", cls)
    )
    expect_true(
      nrow(ref) > 0L,
      label = sprintf(".get_reference_codes('%s') should return non-empty table", cls)
    )
  }
})

# -- Test D9: check mode works for NIS classifications previously unsupported ---
test_that("diagnose_classification works for NUTS_PROVINCE_2021", {
  dt <- data.table(code = c("BE10", "BE21"), val = 1:2)
  result <- diagnose_classification(dt, "code", master_data,
                                    classification = CLS_NUTS_PROVINCE_2021,
                                    verbose = FALSE)
  expect_equal(result$mode, "check")
  expect_true(result$n_in_dataset >= 2L)
})

test_that("diagnose_classification works for NIS_DISTRICT_BEFORE_2019", {
  all_arr <- nbbbenuts:::.list_codes_for(CLS_NIS_DISTRICT_BEFORE_2019, master_data)
  dt <- data.table(code = head(all_arr, 5), val = 1:5)
  result <- diagnose_classification(dt, "code", master_data,
                                    classification = CLS_NIS_DISTRICT_BEFORE_2019,
                                    verbose = FALSE)
  expect_equal(result$mode, "check")
  expect_equal(result$n_in_dataset, 5L)
})

# -- M6: detect and diagnose(detect mode) agree on ties, shared ranking --------
test_that("diagnose(detect mode) recommendation matches detect_classification on a tie", {
  # Stable communes present in both 2019 and 2025 tie at match_pct = 100 for
  # several classifications. Both ranking paths must resolve the tie the same way
  # (via the shared classification priority), not diverge.
  codes <- c(21004L, 21001L, 21015L)
  dt    <- data.table(cd = codes)

  det <- suppressWarnings(detect_classification(codes, master_data))
  dg  <- suppressMessages(
    diagnose_classification(dt, "cd", master_data, verbose = FALSE)
  )
  expect_equal(dg$recommendation, det)
  expect_equal(dg$recommendation, CLS_NIS_MUNICIPALITY_2019)
})
