library(data.table)

# ── Test 1: NIS Commune 2019 -> NUTS3 2021 ───────────────────────────────────
test_that("NIS_COMMUNE_2019 converts to NUTS3_2021", {
  codes  <- c(21001L, 11002L, 62003L, 92045L, 63079L)
  result <- convert_codes(codes, "NIS_COMMUNE_2019", "NUTS3_2021", master_data)
  expect_equal(nrow(result), 5L)
  expect_true(all(!is.na(result$code_to)))
})

# ── Test 2: NIS Commune 2025 -> NIS Arrondissement 2025 ──────────────────────
test_that("NIS_COMMUNE_2025 converts to NIS_ARRONDISSEMENT_2025", {
  codes  <- c(21001L, 11002L, 44086L, 71071L)
  result <- convert_codes(codes, "NIS_COMMUNE_2025", "NIS_ARRONDISSEMENT_2025", master_data)
  expect_equal(nrow(result), 4L)
  expect_true(all(!is.na(result$code_to)))
})

# ── Test 3: Code Postal -> NIS Commune 2019 ──────────────────────────────────
test_that("POSTAL converts to NIS_COMMUNE_2019", {
  codes  <- c(1000L, 2000L, 4000L, 5000L, 7000L)
  result <- convert_codes(codes, "POSTAL", "NIS_COMMUNE_2019", master_data)
  expect_equal(nrow(result), 5L)
  expect_true(all(!is.na(result$code_to)))
})

# ── Test 4: NIS Arrondissement 2025 -> NIS Province 2025 ─────────────────────
test_that("NIS_ARRONDISSEMENT_2025 converts to NIS_PROVINCE_2025", {
  codes  <- c(11000L, 21000L, 51000L, 62000L, 91000L)
  result <- convert_codes(codes, "NIS_ARRONDISSEMENT_2025", "NIS_PROVINCE_2025", master_data)
  expect_equal(nrow(result), 5L)
  expect_true(all(!is.na(result$code_to)))
})

# ── Test 5: Ambiguous conversion (Verviers arrondissement) ───────────────────
test_that("Verviers arrondissement is blocked without allow_ambiguous", {
  codes <- c(11000L, 62000L, 63000L)
  expect_error(
    convert_codes(codes, "NIS_ARRONDISSEMENT_2019", "NUTS3_2021", master_data,
                  allow_ambiguous = FALSE)
  )
})

test_that("Verviers produces 2 NUTS3 rows with allow_ambiguous = TRUE", {
  codes  <- c(11000L, 62000L, 63000L)
  result <- convert_codes(codes, "NIS_ARRONDISSEMENT_2019", "NUTS3_2021",
                          master_data, allow_ambiguous = TRUE)
  expect_equal(nrow(result[code_from == 63000L]), 2L)
})

# ── Test 6: NUTS3 2021 -> Internal Arrondissement ────────────────────────────
test_that("NUTS3_2021 converts to INTERNAL_ARRONDISSEMENT", {
  codes  <- c("BE100", "BE211", "BE335", "BE336", "BE351")
  result <- convert_codes(codes, "NUTS3_2021", "INTERNAL_ARRONDISSEMENT", master_data)
  expect_equal(nrow(result), 5L)
  expect_true(all(!is.na(result$code_to)))
})

# ── Test 7: Fuzzy match - postal code names ───────────────────────────────────
test_that("fuzzy_match_names works for POSTAL", {
  skip_if_not_installed("stringdist")
  names  <- c("Bruxelles", "Anvers", "Liege", "Namur", "Gand")
  result <- fuzzy_match_names(names, "POSTAL", master_data, max_dist = 0.3, language = "fr")
  expect_gte(nrow(result), length(names))
})

# ── Test 8: Fuzzy match - NIS Commune 2019 names ─────────────────────────────
test_that("fuzzy_match_names handles misspelled NIS_COMMUNE_2019 names", {
  skip_if_not_installed("stringdist")
  names  <- c("Anderlecht", "Bruxeles", "Antwerpn", "Liege", "Vervirs")
  result <- fuzzy_match_names(names, "NIS_COMMUNE_2019", master_data,
                              max_dist = 0.3, language = "both")
  expect_gte(nrow(result), length(names))
})

# ── Test 9: Fuzzy match - NIS Commune 2025 names ─────────────────────────────
test_that("fuzzy_match_names works for NIS_COMMUNE_2025", {
  skip_if_not_installed("stringdist")
  names  <- c("Anderlecht", "Gent", "Hasselt", "Charleroi")
  result <- fuzzy_match_names(names, "NIS_COMMUNE_2025", master_data,
                              max_dist = 0.3, language = "both")
  expect_gte(nrow(result), length(names))
})

# ── Test 10: NIS Commune 2019 -> NUTS3 2027 ──────────────────────────────────
test_that("NIS_COMMUNE_2019 converts to NUTS3_2027 with correct remapping", {
  codes  <- c(21004L, 11002L, 44021L, 62063L, 63079L)
  result <- convert_codes(codes, "NIS_COMMUNE_2019", "NUTS3_2027", master_data)
  expect_equal(result[code_from == 21004L]$code_to, "BE100")   # Brussels unchanged
  expect_equal(result[code_from == 11002L]$code_to, "BE261")   # BE211 -> BE261
  expect_equal(result[code_from == 44021L]$code_to, "BE274")   # BE234 -> BE274
})

# ── Test 11: NUTS3_2021 <-> NUTS3_2027 direct conversion is NOT supported ─────
test_that("NUTS3_2021 -> NUTS3_2027 is not directly convertible (different perimeters)", {
  # NUTS3_2021 and NUTS3_2027 cover different geographic areas: 3 communes
  # changed province between 2019 and 2025, which shifted their NUTS3 region.
  # A pure code-rename table gives wrong results for those communes.
  # There is therefore no direct NUTS3_2021 <-> NUTS3_2027 conversion edge.
  r <- check_conversion_path("NUTS3_2021", "NUTS3_2027")
  expect_false(r[["is_simple"]])

  expect_error(
    convert_codes("BE211", "NUTS3_2021", "NUTS3_2027", master_data),
    class = "rcl_ambiguous_conversion"
  )
  expect_error(
    convert_codes("BE261", "NUTS3_2027", "NUTS3_2021", master_data),
    class = "rcl_ambiguous_conversion"
  )
})

# ── Test 12: diagnose_classification() — check mode ──────────────────────────
test_that("diagnose_classification check mode: full dataset is COMPLETE", {
  nuts3_codes <- unique(master_data$communes[nis_version == "2019" & !is.na(cd_nuts3), cd_nuts3])
  dt_full <- data.table(nuts3 = nuts3_codes, val = seq_along(nuts3_codes))
  r <- diagnose_classification(dt_full, "nuts3", master_data,
                               classification = "NUTS3_2021", verbose = FALSE)
  expect_equal(r$status, "COMPLETE")
  expect_equal(r$classification_type, "NUTS3")
  expect_equal(r$version, "2021")
  expect_equal(r$n_missing, 0L)
})

test_that("diagnose_classification check mode: partial dataset is INCOMPLETE", {
  dt_partial <- data.table(nuts3 = c("BE100", "BE211", "BE332"), val = 1:3)
  r <- diagnose_classification(dt_partial, "nuts3", master_data,
                               classification = "NUTS3_2021", verbose = FALSE)
  expect_equal(r$status, "INCOMPLETE")
  expect_equal(r$n_missing, 44L - 3L)
  expect_equal(r$n_in_dataset, 3L)
  expect_false("BE211" %in% r$missing_codes$code)
})

test_that("diagnose_classification check mode: unknown codes detected", {
  dt_unk <- data.table(nuts3 = c("BE100", "BE999"), val = 1:2)
  r <- diagnose_classification(dt_unk, "nuts3", master_data,
                               classification = "NUTS3_2021", verbose = FALSE)
  expect_equal(r$n_unknown, 1L)
  expect_true("BE999" %in% r$unknown_codes$code)
})

# ── Test 13: diagnose_classification() detect mode + split_ambiguous() ────────
test_that("diagnose_classification auto-detects NIS_COMMUNE_2019", {
  comm_dt <- data.table(code = master_data$communes[nis_version == "2019", cd_commune])
  r <- diagnose_classification(comm_dt, "code", master_data, verbose = FALSE)
  expect_equal(r$mode, "detect")
  expect_equal(r$recommendation, "NIS_COMMUNE_2019")
  expect_equal(r$classification_type, "NIS_COMMUNE")
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
                       from        = "NIS_ARRONDISSEMENT_2019",
                       to          = "NUTS3_2021",
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

# ── Test 14: NIS_REGION conversion correctness (regression for province mapping bug) ─
test_that("NIS_COMMUNE_2019 -> NIS_REGION_2019 assigns regions correctly", {
  # Antwerp was previously mis-assigned to region 4000 (Brussels) due to a
  # fcase() error in parse_refnis_hierarchy() that mapped province 10000 to 4000.
  codes  <- c(11002L, 44021L, 21001L, 62063L, 23002L, 25005L)
  result <- convert_codes(codes, "NIS_COMMUNE_2019", "NIS_REGION_2019", master_data)

  expect_equal(result[code_from == 11002L]$code_to, 2000L)  # Antwerp -> Flemish
  expect_equal(result[code_from == 44021L]$code_to, 2000L)  # Gent -> Flemish
  expect_equal(result[code_from == 21001L]$code_to, 4000L)  # Brussels -> Brussels
  expect_equal(result[code_from == 62063L]$code_to, 3000L)  # Liege -> Walloon
  expect_equal(result[code_from == 23002L]$code_to, 2000L)  # Flemish Brabant -> Flemish
  expect_equal(result[code_from == 25005L]$code_to, 3000L)  # Walloon Brabant -> Walloon
})
