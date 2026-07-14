library(data.table)

# -- Test 1: NIS Commune 2019 -> NUTS3 2021 -----------------------------------
test_that("NIS_MUNICIPALITY_2019 converts to NUTS_DISTRICT_2021", {
  codes  <- c(21001L, 11002L, 62003L, 92045L, 63079L)
  result <- convert_codes(codes, CLS_NIS_MUNICIPALITY_2019, CLS_NUTS_DISTRICT_2021, master_data)
  expect_equal(nrow(result), 5L)
  expect_true(all(!is.na(result$code_to)))
})

# -- Test 2: NIS Commune 2025 -> NIS Arrondissement 2025 ----------------------
test_that("NIS_MUNICIPALITY_2025 converts to NIS_DISTRICT_2025", {
  codes  <- c(21001L, 11002L, 44086L, 71071L)
  result <- convert_codes(codes, CLS_NIS_MUNICIPALITY_2025, CLS_NIS_DISTRICT_2025, master_data)
  expect_equal(nrow(result), 4L)
  expect_true(all(!is.na(result$code_to)))
})

# -- Test 3: Code Postal -> NIS Commune 2019 ----------------------------------
test_that("POSTAL converts to NIS_MUNICIPALITY_2019", {
  codes  <- c(1000L, 2000L, 4000L, 5000L, 7000L)
  result <- convert_codes(codes, CLS_POSTAL, CLS_NIS_MUNICIPALITY_2019, master_data)
  expect_equal(nrow(result), 5L)
  expect_true(all(!is.na(result$code_to)))
})

# -- Test 4: NIS Arrondissement 2025 -> NIS Province 2025 ---------------------
test_that("NIS_DISTRICT_2025 converts to NIS_PROVINCE_2025", {
  codes  <- c(11000L, 21000L, 51000L, 62000L, 91000L)
  result <- convert_codes(codes, CLS_NIS_DISTRICT_2025, CLS_NIS_PROVINCE_2025, master_data)
  expect_equal(nrow(result), 5L)
  expect_true(all(!is.na(result$code_to)))
})

# -- Test 5: Ambiguous conversion (Verviers arrondissement) -------------------
test_that("Verviers arrondissement is blocked without allow_ambiguous", {
  codes <- c(11000L, 62000L, 63000L)
  expect_error(
    convert_codes(codes, CLS_NIS_DISTRICT_2019, CLS_NUTS_DISTRICT_2021, master_data,
                  allow_ambiguous = FALSE)
  )
})

test_that("Verviers produces 2 NUTS3 rows with allow_ambiguous = TRUE", {
  codes  <- c(11000L, 62000L, 63000L)
  result <- convert_codes(codes, CLS_NIS_DISTRICT_2019, CLS_NUTS_DISTRICT_2021,
                          master_data, allow_ambiguous = TRUE)
  expect_equal(nrow(result[code_from == 63000L]), 2L)
})

# -- Test 6: NUTS3 2021 -> Internal Arrondissement ----------------------------
test_that("NUTS_DISTRICT_2021 converts to NBB_DISTRICT_2021", {
  codes  <- c("BE100", "BE211", "BE335", "BE336", "BE351")
  result <- convert_codes(codes, CLS_NUTS_DISTRICT_2021, CLS_NBB_DISTRICT_2021, master_data)
  expect_equal(nrow(result), 5L)
  expect_true(all(!is.na(result$code_to)))
})

# -- Test 7: Fuzzy match - postal code names -----------------------------------
test_that("fuzzy_match_names works for POSTAL", {
  skip_if_not_installed("stringdist")
  names  <- c("Bruxelles", "Anvers", "Liege", "Namur", "Gand")
  result <- fuzzy_match_names(names, CLS_POSTAL, master_data, max_dist = 0.3, language = "fr")
  expect_gte(nrow(result), length(names))
})

# -- Test 8: Fuzzy match - NIS Commune 2019 names -----------------------------
test_that("fuzzy_match_names handles misspelled NIS_MUNICIPALITY_2019 names", {
  skip_if_not_installed("stringdist")
  names  <- c("Anderlecht", "Bruxeles", "Antwerpn", "Liege", "Vervirs")
  result <- fuzzy_match_names(names, CLS_NIS_MUNICIPALITY_2019, master_data,
                              max_dist = 0.3, language = "both")
  expect_gte(nrow(result), length(names))
})

# -- Test 9: Fuzzy match - NIS Commune 2025 names -----------------------------
test_that("fuzzy_match_names works for NIS_MUNICIPALITY_2025", {
  skip_if_not_installed("stringdist")
  names  <- c("Anderlecht", "Gent", "Hasselt", "Charleroi")
  result <- fuzzy_match_names(names, CLS_NIS_MUNICIPALITY_2025, master_data,
                              max_dist = 0.3, language = "both")
  expect_gte(nrow(result), length(names))
})

# -- Test 10: NIS Commune 2019 -> NUTS3 2027 ----------------------------------
test_that("NIS_MUNICIPALITY_2019 converts to NUTS_DISTRICT_2027 with correct remapping", {
  codes  <- c(21004L, 11002L, 44021L, 62063L, 63079L)
  result <- convert_codes(codes, CLS_NIS_MUNICIPALITY_2019, CLS_NUTS_DISTRICT_2027, master_data)
  expect_equal(result[code_from == 21004L]$code_to, "BE100")   # Brussels unchanged
  expect_equal(result[code_from == 11002L]$code_to, "BE261")   # BE211 -> BE261
  expect_equal(result[code_from == 44021L]$code_to, "BE274")   # BE234 -> BE274
})

# -- Test 11: NUTS_DISTRICT_2021 -> NUTS_DISTRICT_2027 direct 1:N edge (forward only) -----
test_that("NUTS_DISTRICT_2021 -> NUTS_DISTRICT_2027 is a direct 1:N edge requiring allow_ambiguous", {
  # A direct derived edge exists (forward only), built by chaining through communes.
  # Most 2021 NUTS3 -> 1 2027 code; the 3 cross-province fusions make a few 2021 codes
  # map to 2 (e.g. BE211 -> {BE261, BE276}), so the conversion is 1:N (not simple).
  # NOTE: BE211/BE261/BE276 are the documented example; confirm against the rebuilt
  # crosswalk (the anti-drift test in test-crosswalks-parity.R pins the real set).
  r <- check_conversion_path(CLS_NUTS_DISTRICT_2021, CLS_NUTS_DISTRICT_2027)
  expect_false(r[["is_simple"]])

  # Without allow_ambiguous: blocked by the 1:N gate.
  expect_error(
    convert_codes("BE211", CLS_NUTS_DISTRICT_2021, CLS_NUTS_DISTRICT_2027, master_data),
    class = "rcl_ambiguous_conversion"
  )

  # With allow_ambiguous: forward succeeds. Unchanged code -> 1 row; BE211 -> 2 rows.
  res <- convert_codes(c("BE100", "BE211"), CLS_NUTS_DISTRICT_2021, CLS_NUTS_DISTRICT_2027,
                       master_data, allow_ambiguous = TRUE)
  expect_equal(nrow(res[code_from == "BE100"]), 1L)
  expect_equal(nrow(res[code_from == "BE211"]), 2L)
  expect_setequal(res[code_from == "BE211"]$code_to, c("BE261", "BE276"))
  expect_true(all(!is.na(res$code_to)))

  # Reverse 2027 -> 2021 is a non-executable de-aggregation (no crosswalk, and the
  # forward aggregate edge is no_reverse): convert_codes() now fails with a clear
  # rcl_no_route dead-end rather than the old contradictory rcl_ambiguous advice
  # that would die at execution anyway (C1). allow_ambiguous cannot rescue it.
  expect_error(
    convert_codes("BE261", CLS_NUTS_DISTRICT_2027, CLS_NUTS_DISTRICT_2021, master_data),
    class = "rcl_no_route"
  )
  expect_error(
    convert_codes("BE261", CLS_NUTS_DISTRICT_2027, CLS_NUTS_DISTRICT_2021,
                  master_data, allow_ambiguous = TRUE),
    class = "rcl_no_route"
  )
})

test_that("NUTS_DISTRICT_2021 -> NUTS_DISTRICT_2027 supports weighted splitting", {
  library(data.table)
  emp_data <- data.table(nuts3 = c("BE100", "BE211"),
                         emp   = c(1000, 500))
  wts <- data.table(code_from = c("BE211", "BE211"),
                    code_to   = c("BE261", "BE276"),
                    weight    = c(0.8, 0.2))
  r <- split_ambiguous(emp_data, "nuts3",
                       value_cols  = "emp",
                       from        = CLS_NUTS_DISTRICT_2021,
                       to          = CLS_NUTS_DISTRICT_2027,
                       master_data = master_data,
                       weights     = wts,
                       value_type  = "additive",
                       verbose     = FALSE)
  # BE100 -> 1 row (unchanged); BE211 -> 2 rows split 0.8 / 0.2; total preserved.
  expect_equal(nrow(r), 3L)
  expect_lt(abs(sum(r$emp) - 1500), 1e-6)
  expect_lt(abs(r[cd_nuts3_2027 == "BE261", emp] - 400), 1e-6)
  expect_lt(abs(r[cd_nuts3_2027 == "BE276", emp] - 100), 1e-6)
})

# -- Test 12: diagnose_classification() -- check mode --------------------------
test_that("diagnose_classification check mode: full dataset is COMPLETE", {
  nuts3_codes <- unique(master_data$communes[nis_version == VER_2019 & !is.na(cd_nuts3), cd_nuts3])
  dt_full <- data.table(nuts3 = nuts3_codes, val = seq_along(nuts3_codes))
  r <- diagnose_classification(dt_full, "nuts3", master_data,
                               classification = CLS_NUTS_DISTRICT_2021, verbose = FALSE)
  expect_equal(r$status, "COMPLETE")
  expect_equal(r$classification_type, "NUTS_DISTRICT")
  expect_equal(r$version, "2021")
  expect_equal(r$n_missing, 0L)
})

test_that("diagnose_classification check mode: partial dataset is INCOMPLETE", {
  dt_partial <- data.table(nuts3 = c("BE100", "BE211", "BE332"), val = 1:3)
  r <- diagnose_classification(dt_partial, "nuts3", master_data,
                               classification = CLS_NUTS_DISTRICT_2021, verbose = FALSE)
  expect_equal(r$status, "INCOMPLETE")
  expect_equal(r$n_missing, 44L - 3L)
  expect_equal(r$n_in_dataset, 3L)
  expect_false("BE211" %in% r$missing_codes$code)
})

test_that("diagnose_classification check mode: unknown codes detected", {
  dt_unk <- data.table(nuts3 = c("BE100", "BE999"), val = 1:2)
  r <- diagnose_classification(dt_unk, "nuts3", master_data,
                               classification = CLS_NUTS_DISTRICT_2021, verbose = FALSE)
  expect_equal(r$n_unknown, 1L)
  expect_true("BE999" %in% r$unknown_codes$code)
})

# -- Test 13: diagnose_classification() detect mode + split_ambiguous() --------
test_that("diagnose_classification auto-detects NIS_MUNICIPALITY_2019", {
  comm_dt <- data.table(code = master_data$communes[nis_version == VER_2019, cd_commune])
  r <- diagnose_classification(comm_dt, "code", master_data, verbose = FALSE)
  expect_equal(r$mode, "detect")
  expect_equal(r$recommendation, CLS_NIS_MUNICIPALITY_2019)
  expect_equal(r$classification_type, "NIS_MUNICIPALITY")
  expect_equal(r$version, "2019")
})

test_that("split_ambiguous splits Verviers correctly with additive weights", {
  arr_data <- data.table(
    arr_code   = c(11000L, 62000L, 63000L),
    total_wage = c(5e9, 3e9, 1e9),
    avg_salary = c(2900, 2700, 2400)
  )
  wts <- data.table(
    code_from = c(63000L, 63000L),
    code_to   = c("BE335", "BE336"),
    weight    = c(0.857, 0.143)
  )
  r <- split_ambiguous(arr_data, "arr_code",
                       value_cols  = "total_wage",
                       from        = CLS_NIS_DISTRICT_2019,
                       to          = CLS_NUTS_DISTRICT_2021,
                       master_data = master_data,
                       weights     = wts,
                       value_type  = "additive",
                       verbose     = FALSE)

  expect_equal(nrow(r), 4L)
  expect_lt(abs(sum(r$total_wage) - 9e9), 1)
  expect_equal(nrow(r[cd_nuts3_2021 %in% c("BE335", "BE336")]), 2L)
  expect_lt(abs(r[cd_nuts3_2021 == "BE335", total_wage] - 857e6), 1e3)
  expect_lt(abs(r[cd_nuts3_2021 == "BE336", total_wage] - 143e6), 1e3)
})

# -- Test 14: NIS_REGION conversion correctness (regression for province mapping bug) -
test_that("NIS_MUNICIPALITY_2019 -> NIS_REGION_2019 assigns regions correctly", {
  # Antwerp was previously mis-assigned to region 4000 (Brussels) due to a
  # fcase() error in parse_refnis_hierarchy() that mapped province 10000 to 4000.
  codes  <- c(11002L, 44021L, 21001L, 62063L, 23002L, 25005L)
  result <- convert_codes(codes, CLS_NIS_MUNICIPALITY_2019, CLS_NIS_REGION_2019, master_data)

  expect_equal(result[code_from == 11002L]$code_to, 2000L)  # Antwerp -> Flemish
  expect_equal(result[code_from == 44021L]$code_to, 2000L)  # Gent -> Flemish
  expect_equal(result[code_from == 21001L]$code_to, 4000L)  # Brussels -> Brussels
  expect_equal(result[code_from == 62063L]$code_to, 3000L)  # Liege -> Walloon
  expect_equal(result[code_from == 23002L]$code_to, 2000L)  # Flemish Brabant -> Flemish
  expect_equal(result[code_from == 25005L]$code_to, 3000L)  # Walloon Brabant -> Walloon
})

# -- Test 15: Uniform return schema (code_from, code_to, nature) --------------
test_that("convert_codes always returns exactly 3 columns: code_from, code_to, nature", {
  # Simple conversion: nature = "RECODE" (N:1 nesting, non-temporal)
  r_simple <- convert_codes(21004L, CLS_NIS_MUNICIPALITY_2019, CLS_NUTS_DISTRICT_2021, master_data)
  expect_equal(names(r_simple), c("code_from", "code_to", "nature"))
  expect_equal(r_simple$nature, "RECODE")

  # Identity (from == to): nature = "RECODE" (self-mapping, no information loss)
  r_id <- convert_codes("BE211", CLS_NUTS_DISTRICT_2021, CLS_NUTS_DISTRICT_2021, master_data)
  expect_equal(names(r_id), c("code_from", "code_to", "nature"))
  expect_equal(r_id$nature, "RECODE")

  # Multi-hop: nature = NA (composer drops it mid-chain)
  r_multi <- convert_codes("BE211", CLS_NUTS_DISTRICT_2021, CLS_NUTS_REGION_2021, master_data)
  expect_equal(names(r_multi), c("code_from", "code_to", "nature"))
  expect_true(is.na(r_multi$nature))
})

test_that("NIS temporal conversions carry correct nature values", {
  # 2019 -> 2025: unchanged communes get UNCHANGED
  r_unchanged <- convert_codes(21004L, CLS_NIS_MUNICIPALITY_2019, CLS_NIS_MUNICIPALITY_2025, master_data)
  expect_equal(r_unchanged$nature, "UNCHANGED")

  # 2025 -> 2019: ambiguous path requires allow_ambiguous; unchanged commune stays UNCHANGED
  r_rev <- convert_codes(21004L, CLS_NIS_MUNICIPALITY_2025, CLS_NIS_MUNICIPALITY_2019, master_data,
                         allow_ambiguous = TRUE)
  expect_equal(r_rev$nature, "UNCHANGED")
})

test_that("get_crosswalk does not expose the nature column", {
  cw <- get_crosswalk(CLS_NIS_MUNICIPALITY_2019, CLS_NUTS_DISTRICT_2021, master_data)
  expect_false("nature" %in% names(cw))
})

test_that("convert_dataset does not expose the nature column", {
  library(data.table)
  dt <- data.table(commune = c(21004L, 11002L, 62063L), value = c(100, 200, 300))
  out <- convert_dataset(dt, "commune", CLS_NUTS_DISTRICT_2021, master_data,
                         from = CLS_NIS_MUNICIPALITY_2019, verbose = FALSE)
  expect_false("nature" %in% names(out))
})

# -- Tests Phase 4: NIS_MUNICIPALITY_2025 -> NUTS_DISTRICT_2021 / NBB_DISTRICT_2021 ---

test_that("NIS_MUNICIPALITY_2025 -> NUTS_DISTRICT_2021 is NOT simple (3 cross-NUTS3 fusions)", {
  r <- check_conversion_path(CLS_NIS_MUNICIPALITY_2025, CLS_NUTS_DISTRICT_2021)
  expect_false(r[["is_simple"]])
  # The ambiguous codes are surfaced explicitly
  expect_true(setequal(r[["ambiguous_codes"]], c(46029L, 46030L, 71072L)))
  expect_false(is.null(r[["coverage"]]))
})

test_that("NIS_MUNICIPALITY_2025 -> NUTS_DISTRICT_2021 requires allow_ambiguous = TRUE", {
  expect_error(
    convert_codes(c(21001L, 21004L), CLS_NIS_MUNICIPALITY_2025, CLS_NUTS_DISTRICT_2021, master_data),
    class = "rcl_ambiguous_conversion"
  )
})

test_that("NIS_MUNICIPALITY_2025 -> NUTS_DISTRICT_2021 converts unchanged communes correctly (allow_ambiguous)", {
  # Brussels communes 21001-21019 are unchanged between 2019 and 2025
  codes  <- c(21001L, 21004L, 11002L)
  result <- convert_codes(codes, CLS_NIS_MUNICIPALITY_2025, CLS_NUTS_DISTRICT_2021, master_data,
                          allow_ambiguous = TRUE)
  expect_equal(nrow(result), 3L)
  expect_equal(result[code_from == 21001L]$code_to, "BE100")
  expect_equal(result[code_from == 21004L]$code_to, "BE100")
  expect_true(all(!is.na(result$code_to)))
})

test_that("NIS_MUNICIPALITY_2025 -> NUTS_DISTRICT_2021: ambiguous fusions return multiple rows, no NA", {
  # These 3 communes fuse localities from different NUTS_DISTRICT_2021 regions.
  # Each should now produce > 1 row (one per constituent NUTS3 region).
  result <- convert_codes(c(46029L, 46030L, 71072L), CLS_NIS_MUNICIPALITY_2025, CLS_NUTS_DISTRICT_2021,
                          master_data, allow_ambiguous = TRUE)
  expect_gt(nrow(result[code_from == 46029L]), 1L)
  expect_gt(nrow(result[code_from == 46030L]), 1L)
  expect_gt(nrow(result[code_from == 71072L]), 1L)
  expect_true(all(!is.na(result$code_to)))
})

test_that("NIS_MUNICIPALITY_2025 -> NBB_DISTRICT_2021 is a simple conversion", {
  r <- check_conversion_path(CLS_NIS_MUNICIPALITY_2025, CLS_NBB_DISTRICT_2021)
  expect_true(r[["is_simple"]])
  result <- convert_codes(c(21001L, 11002L), CLS_NIS_MUNICIPALITY_2025, CLS_NBB_DISTRICT_2021,
                          master_data)
  expect_equal(nrow(result), 2L)
  expect_true(all(!is.na(result$code_to)))
})

test_that("NIS_MUNICIPALITY_2025 -> NUTS_PROVINCE_2021 is reachable (multi-hop via NUTS_DISTRICT_2021)", {
  result <- convert_codes(21001L, CLS_NIS_MUNICIPALITY_2025, CLS_NUTS_PROVINCE_2021, master_data,
                          allow_ambiguous = TRUE)
  expect_equal(nrow(result), 1L)
  expect_false(is.na(result$code_to))
})
