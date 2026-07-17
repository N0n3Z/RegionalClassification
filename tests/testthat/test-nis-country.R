library(data.table)

# ==============================================================================
# test-nis-country.R  --  Behavioural tests for the NIS_COUNTRY node
# ==============================================================================
# NIS_COUNTRY represents Belgium as a whole (NIS code 1000 / Statbel 01000).
# It is unversioned and aggregates all three NIS_REGION versions.
# ==============================================================================

# -- Registry / nomenclature ---------------------------------------------------

test_that("NIS_COUNTRY is in CLASSIFICATION_NODES and has correct metadata", {
  n <- CLASSIFICATION_NODES[[CLS_NIS_COUNTRY]]
  expect_equal(n$system,     "NIS")
  expect_equal(n$level,      "country")
  expect_true(is.na(n$version))
  expect_equal(n$code_type,  "character")
  expect_equal(n$code_col,   "cd_nis_country")
})

test_that("nomenclature('NIS', 'country') resolves to NIS_COUNTRY", {
  nom <- nomenclature("NIS", "country")
  expect_true(is_nomenclature(nom))
  expect_equal(as.character(nom), CLS_NIS_COUNTRY)
})

test_that("nomenclature_children(NIS_COUNTRY) returns the three NIS_REGION nodes", {
  kids <- nomenclature_children(nomenclature("NIS", "country"))
  ids  <- vapply(kids, as.character, "")
  expect_setequal(ids, c(CLS_NIS_REGION_BEFORE_2019,
                         CLS_NIS_REGION_2019,
                         CLS_NIS_REGION_2025))
})

test_that("nomenclature_parents(NIS_REGION_2019) includes NIS_COUNTRY", {
  parents <- nomenclature_parents(nomenclature("NIS", "region", "2019"))
  ids     <- vapply(parents, as.character, "")
  expect_true(CLS_NIS_COUNTRY %in% ids)
})

# -- Conversion ----------------------------------------------------------------

test_that("NIS_REGION_2019 -> NIS_COUNTRY returns \"1000\" for all three regions", {
  regions <- c(NIS_REGION_FLEMISH, NIS_REGION_WALLOON, NIS_REGION_BRUSSELS)
  result  <- convert_codes(regions, CLS_NIS_REGION_2019, CLS_NIS_COUNTRY, master_data)
  expect_equal(nrow(result), 3L)
  expect_true(all(result$code_to == "1000"))
  expect_type(result$code_to, "character")
})

test_that("NIS_REGION_2025 -> NIS_COUNTRY returns \"1000\"", {
  regions <- c(NIS_REGION_FLEMISH, NIS_REGION_WALLOON, NIS_REGION_BRUSSELS)
  result  <- convert_codes(regions, CLS_NIS_REGION_2025, CLS_NIS_COUNTRY, master_data)
  expect_true(all(result$code_to == "1000"))
})

test_that("NIS_REGION_BEFORE_2019 -> NIS_COUNTRY returns 1000L", {
  regions <- c(NIS_REGION_FLEMISH, NIS_REGION_WALLOON, NIS_REGION_BRUSSELS)
  result  <- convert_codes(regions, CLS_NIS_REGION_BEFORE_2019, CLS_NIS_COUNTRY, master_data)
  expect_true(all(result$code_to == 1000L))
})

# -- Perimeter semantics -------------------------------------------------------

test_that("NIS_REGION_2019 -> NIS_COUNTRY is perimeter-preserving (N:1 nesting)", {
  expect_true(is_perimeter_preserving(CLS_NIS_REGION_2019, CLS_NIS_COUNTRY))
})

test_that("NIS_MUNICIPALITY_2019 -> NIS_COUNTRY path is simple", {
  chk <- check_conversion_path(CLS_NIS_MUNICIPALITY_2019, CLS_NIS_COUNTRY)
  expect_true(chk$is_simple)
})

# -- Leading-zero alias: "01000" (Statbel form) matches stored "1000" (v2.0.0) -

test_that("country accepts the zero-padded '01000' form as an alias of '1000'", {
  master_data <- load_master_data()
  # validate_codes against a specified classification is unambiguous.
  res <- validate_codes(c("01000", "1000"), CLS_NIS_COUNTRY, master_data)
  expect_true(all(res$is_valid))
  # the canonical form is returned (leading zero stripped to match the stored code)
  expect_equal(res$code, c("1000", "1000"))
  # .canon_codes() strips the pad for numeric codes and leaves NUTS codes intact
  expect_equal(nbbbenuts:::.canon_codes(c("01000", "21004", "BE100", NA)),
               c("1000", "21004", "BE100", NA))
})
