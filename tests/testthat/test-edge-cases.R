library(data.table)

# -- Test E1: convert_codes avec vecteur vide ----------------------------------
test_that("convert_codes returns empty data.table for empty input", {
  result <- convert_codes(integer(0), "NIS_COMMUNE_2019", "NUTS3_2021", master_data)
  expect_true(is.data.table(result))
  expect_equal(nrow(result), 0L)
})

# -- Test E2: convert_codes avec tous NA ---------------------------------------
test_that("convert_codes handles all-NA input gracefully", {
  # All-NA input has no match by design: the rcl_unmatched_codes warning is expected.
  # Note: expect_warning(class=) in testthat <3.3 returns the condition, not the value.
  # Separate the warning assertion from the result capture to stay compatible.
  expect_warning(
    convert_codes(c(NA_integer_, NA_integer_), "NIS_COMMUNE_2019", "NUTS3_2021",
                  master_data),
    class = "rcl_unmatched_codes"
  )
  result <- suppressWarnings(
    convert_codes(c(NA_integer_, NA_integer_), "NIS_COMMUNE_2019", "NUTS3_2021",
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
    convert_codes(c(99999L, 88888L), "NIS_COMMUNE_2019", "NUTS3_2021", master_data),
    class = "rcl_unmatched_codes"
  )
  result <- suppressWarnings(
    convert_codes(c(99999L, 88888L), "NIS_COMMUNE_2019", "NUTS3_2021", master_data)
  )
  expect_true(is.data.table(result))
  expect_true(all(is.na(result$code_to)))
})

# -- Test E4: coercition integer/character transparente ------------------------
test_that("convert_codes accepts both integer and character codes", {
  r_int  <- convert_codes(21004L,       "NIS_COMMUNE_2019", "NUTS3_2021", master_data)
  r_chr  <- convert_codes("21004",      "NIS_COMMUNE_2019", "NUTS3_2021", master_data)
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
test_that("detect_classification identifies NUTS3_2021 for 5-char BE codes", {
  result <- detect_classification(c("BE100", "BE211", "BE335"), master_data)
  expect_equal(result, "NUTS3_2021")
})

# -- Test E8: detect_classification codes NIS_COMMUNE_2019 --------------------
test_that("detect_classification identifies NIS_COMMUNE_2019 for known commune codes", {
  result <- detect_classification(c(21004L, 11002L, 62063L), master_data)
  expect_equal(result, "NIS_COMMUNE_2019")
})

# -- Test E9: convert_codes identite (from == to) -----------------------------
test_that("convert_codes identity conversion returns input unchanged", {
  codes  <- c("BE100", "BE211")
  result <- convert_codes(codes, "NUTS3_2021", "NUTS3_2021", master_data)
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
  expect_equal(nbbbenuts:::normalize_classification_id("NIS_COMMUNE_2019"),
               "NIS_COMMUNE_2019")
  expect_equal(nbbbenuts:::normalize_classification_id("nis_commune_2019"),
               "NIS_COMMUNE_2019")
  expect_equal(nbbbenuts:::normalize_classification_id("NUTS3_2021"),
               "NUTS3_2021")
  expect_equal(nbbbenuts:::normalize_classification_id("POSTAL"),
               "POSTAL")
})
