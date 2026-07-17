library(data.table)

# -- Test E1: convert_codes avec vecteur vide ----------------------------------
test_that("convert_codes returns empty data.table for empty input", {
  result <- convert_codes(integer(0), CLS_NIS_MUNICIPALITY_2019, CLS_NUTS_DISTRICT_2021, master_data)
  expect_true(is.data.table(result))
  expect_equal(nrow(result), 0L)
})

# -- Test E2: convert_codes avec tous NA ---------------------------------------
test_that("convert_codes handles all-NA input gracefully", {
  # All-NA input has no match by design: the rcl_unmatched_codes warning is expected.
  # Note: expect_warning(class=) in testthat <3.3 returns the condition, not the value.
  # Separate the warning assertion from the result capture to stay compatible.
  expect_warning(
    convert_codes(c(NA_integer_, NA_integer_), CLS_NIS_MUNICIPALITY_2019, CLS_NUTS_DISTRICT_2021,
                  master_data),
    class = "rcl_unmatched_codes"
  )
  result <- suppressWarnings(
    convert_codes(c(NA_integer_, NA_integer_), CLS_NIS_MUNICIPALITY_2019, CLS_NUTS_DISTRICT_2021,
                  master_data)
  )
  expect_true(is.data.table(result))
  expect_true("code_from" %in% names(result))
  expect_true("code_to"   %in% names(result))
})

# -- Test E3: convert_codes avec codes inconnus -> NA dans code_to --------------
test_that("convert_codes returns NA in code_to for unknown codes", {
  # Unknown codes have no match by design: the rcl_unmatched_codes warning is expected.
  expect_warning(
    convert_codes(c(99999L, 88888L), CLS_NIS_MUNICIPALITY_2019, CLS_NUTS_DISTRICT_2021, master_data),
    class = "rcl_unmatched_codes"
  )
  result <- suppressWarnings(
    convert_codes(c(99999L, 88888L), CLS_NIS_MUNICIPALITY_2019, CLS_NUTS_DISTRICT_2021, master_data)
  )
  expect_true(is.data.table(result))
  expect_true(all(is.na(result$code_to)))
})

# -- Test E4: coercition integer/character transparente ------------------------
test_that("convert_codes accepts both integer and character codes", {
  r_int  <- convert_codes(21004L,       CLS_NIS_MUNICIPALITY_2019, CLS_NUTS_DISTRICT_2021, master_data)
  r_chr  <- convert_codes("21004",      CLS_NIS_MUNICIPALITY_2019, CLS_NUTS_DISTRICT_2021, master_data)
  # Both must resolve to the same NUTS3
  expect_equal(as.character(r_int$code_to), as.character(r_chr$code_to))
})

# -- Test E5: detect_classification vecteur vide -> NULL -----------------------
test_that("detect_classification returns NULL for empty input", {
  expect_null(detect_classification(integer(0), master_data))
})

# -- Test E6: detect_classification tout NA -> NULL ----------------------------
test_that("detect_classification returns NULL for all-NA input", {
  expect_null(detect_classification(c(NA_integer_, NA_integer_), master_data))
})

# -- Test E7: detect_classification codes NUTS3 -------------------------------
test_that("detect_classification identifies NUTS_DISTRICT_2021 for 5-char BE codes", {
  result <- detect_classification(c("BE100", "BE211", "BE335"), master_data)
  expect_equal(result, CLS_NUTS_DISTRICT_2021)
})

# -- Test E8: detect_classification codes NIS_MUNICIPALITY_2019 --------------------
test_that("detect_classification identifies NIS_MUNICIPALITY_2019 for known commune codes", {
  result <- detect_classification(c(21004L, 11002L, 62063L), master_data)
  expect_equal(result, CLS_NIS_MUNICIPALITY_2019)
})

# -- Test E9: convert_codes identite (from == to) -----------------------------
test_that("convert_codes identity conversion returns input unchanged", {
  codes  <- c("BE100", "BE211")
  result <- convert_codes(codes, CLS_NUTS_DISTRICT_2021, CLS_NUTS_DISTRICT_2021, master_data)
  expect_equal(as.character(result$code_from), codes)
  expect_equal(as.character(result$code_to),   codes)
})

# -- Test E10: identifiant invalide -> erreur rcl_invalid_classification --------
test_that("normalize_classification_id errors for unrecognised identifiers", {
  expect_error(nbbbenuts:::normalize_classification_id("NIS_COM_2019"),
               class = "rcl_invalid_classification")
  expect_error(nbbbenuts:::normalize_classification_id("NUTS_2021"),
               class = "rcl_invalid_classification")
  expect_error(nbbbenuts:::normalize_classification_id("CP"),
               class = "rcl_invalid_classification")
  expect_error(nbbbenuts:::normalize_classification_id("COMMUNE_2019"),
               class = "rcl_invalid_classification")
})

# -- Test E11: identifiants canoniques valides -> retournes tels quels ---------
test_that("normalize_classification_id accepts canonical identifiers", {
  expect_equal(nbbbenuts:::normalize_classification_id(CLS_NIS_MUNICIPALITY_2019),
               CLS_NIS_MUNICIPALITY_2019)
  expect_equal(nbbbenuts:::normalize_classification_id("nis_municipality_2019"),
               CLS_NIS_MUNICIPALITY_2019)
  expect_equal(nbbbenuts:::normalize_classification_id(CLS_NUTS_DISTRICT_2021),
               CLS_NUTS_DISTRICT_2021)
  expect_equal(nbbbenuts:::normalize_classification_id(CLS_POSTAL),
               CLS_POSTAL)
})

# ==============================================================================
# Collision 4000 : pseudo-province Bruxelles-Capitale
# ==============================================================================
# Code 4000 appears in three classifications simultaneously:
#   - NIS_PROVINCE_2019 (pseudo-province of Brussels-Capital, equal to region code)
#   - NIS_REGION_2019   (Brussels-Capital region)
#   - POSTAL            (postal code for Liege)
# These tests pin the expected behaviour so any future change is explicit.

# -- Test E12: detect_classification prefere NIS_PROVINCE_2019 pour 4000 ------
test_that("detect_classification resolves ambiguous code 4000 to NIS_PROVINCE_2019", {
  # NIS_PROVINCE_2019 is detectable=TRUE and wins the tie-break over
  # NIS_REGION_2019 (detectable=FALSE) and POSTAL.
  result <- detect_classification(4000L, master_data)
  expect_equal(result, CLS_NIS_PROVINCE_2019)
})

# -- Test E13: 4000 est valide dans les trois classifications ------------------
test_that("code 4000 is valid in NIS_PROVINCE_2019, NIS_REGION_2019, and POSTAL", {
  expect_true(validate_codes(4000L, CLS_NIS_PROVINCE_2019, master_data)$is_valid)
  expect_true(validate_codes(4000L, CLS_NIS_REGION_2019,   master_data)$is_valid)
  expect_true(validate_codes(4000L, CLS_POSTAL,            master_data)$is_valid)
})

# -- Test E14: province 4000 -> region 4000 (auto-correspondance N:1) ---------
test_that("NIS_PROVINCE_2019 4000 converts to NIS_REGION_2019 4000 (self-mapping)", {
  result <- convert_codes(4000L, CLS_NIS_PROVINCE_2019, CLS_NIS_REGION_2019, master_data)
  expect_equal(nrow(result), 1L)
  expect_equal(result$code_from, "4000")
  expect_equal(result$code_to,   "4000")
  # N:1 nesting: no allow_ambiguous needed
})

# -- Test E15: path province->region est simple (N:1, pas M:N) ----------------
test_that("NIS_PROVINCE_2019 -> NIS_REGION_2019 conversion path is simple (N:1)", {
  chk <- check_conversion_path(CLS_NIS_PROVINCE_2019, CLS_NIS_REGION_2019)
  expect_true(chk$is_simple)
})
