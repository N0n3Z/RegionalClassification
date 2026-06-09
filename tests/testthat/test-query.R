library(data.table)

# -- validate_codes ------------------------------------------------------------

test_that("validate_codes returns TRUE for known codes, FALSE for unknowns", {
  result <- validate_codes(c(21004L, 99999L, 11002L), "NIS_COMMUNE_2019", master_data)
  expect_true(is.data.table(result))
  expect_equal(names(result), c("code", "is_valid"))
  expect_equal(result$is_valid, c(TRUE, FALSE, TRUE))
})

test_that("validate_codes returns data.table with character codes", {
  result <- validate_codes(c("1000", "9999"), "POSTAL", master_data)
  expect_true(is.character(result$code))
  expect_true(result[code == "1000", is_valid])
  expect_false(result[code == "9999", is_valid])
})

test_that("validate_codes errors for invalid classification", {
  expect_error(
    validate_codes(21004L, "MAUVAISE_CLASSIFICATION", master_data),
    class = "rcl_invalid_classification"
  )
})

test_that("validate_codes works for NUTS3_2021", {
  result <- validate_codes(c("BE100", "ZZZZ"), "NUTS3_2021", master_data)
  expect_true(result[code == "BE100", is_valid])
  expect_false(result[code == "ZZZZ", is_valid])
})

test_that("validate_codes works for INTERNAL_ARRONDISSEMENT", {
  result <- validate_codes(c("21", "99"), "INTERNAL_ARRONDISSEMENT", master_data)
  expect_true(result[code == "21",  is_valid])
  expect_false(result[code == "99", is_valid])
})


# -- get_label -----------------------------------------------------------------

test_that("get_label returns French names for NIS_COMMUNE_2019", {
  result <- get_label(c(21004L, 11002L), "NIS_COMMUNE_2019", master_data, lang = "fr")
  expect_true(is.data.table(result))
  expect_equal(names(result), c("code", "label"))
  expect_equal(result[code == "21004", label], "Bruxelles")
  expect_equal(result[code == "11002", label], "Anvers")
})

test_that("get_label returns Dutch names when lang = 'nl'", {
  result <- get_label(21004L, "NIS_COMMUNE_2019", master_data, lang = "nl")
  expect_equal(result$label, "Brussel")
})

test_that("get_label returns NA for NUTS2 (no names in data)", {
  result <- get_label(c("BE10", "BE21"), "NUTS2_2021", master_data)
  expect_equal(nrow(result), 2L)
  expect_true(all(is.na(result$label)))
})

test_that("get_label returns NA for unknown code", {
  result <- get_label(c(21004L, 99999L), "NIS_COMMUNE_2019", master_data)
  expect_false(is.na(result[code == "21004", label]))
  expect_true(is.na(result[code == "99999", label]))
})

test_that("get_label works for NUTS3_2021", {
  result <- get_label("BE100", "NUTS3_2021", master_data, lang = "fr")
  expect_false(is.na(result$label))
})

test_that("get_label works for POSTAL", {
  result <- get_label(1000L, "POSTAL", master_data, lang = "fr")
  expect_equal(result$label, "Bruxelles")
})


# -- get_crosswalk -------------------------------------------------------------

test_that("get_crosswalk returns a data.table with named columns", {
  result <- get_crosswalk("NIS_COMMUNE_2019", "NUTS3_2021", master_data)
  expect_true(is.data.table(result))
  expect_true("NIS_COMMUNE_2019" %in% names(result))
  expect_true("NUTS3_2021"       %in% names(result))
})

test_that("get_crosswalk covers all source codes", {
  result <- get_crosswalk("NIS_COMMUNE_2019", "NUTS3_2021", master_data)
  all_2019 <- nbbbenuts:::.list_codes_for("NIS_COMMUNE_2019", master_data)
  # Every source code is represented (some may map to NA if no NUTS available)
  expect_true(all(all_2019 %in% result$NIS_COMMUNE_2019))
})

test_that("get_crosswalk for POSTAL -> NIS_COMMUNE_2019 is N:1", {
  result <- get_crosswalk("POSTAL", "NIS_COMMUNE_2019", master_data)
  # Each postal code appears exactly once (N:1)
  expect_equal(nrow(result), uniqueN(result$POSTAL))
})

test_that("get_crosswalk errors for invalid classification", {
  expect_error(
    get_crosswalk("NIS_COMMUNE_2019", "INCONNU", master_data),
    class = "rcl_invalid_classification"
  )
})

# -- get_crosswalk with weights ------------------------------------------------

test_that("get_crosswalk weights=TRUE adds weight column with value 1 for simple pair", {
  result <- get_crosswalk("NIS_COMMUNE_2019", "NUTS3_2021", master_data, weights = TRUE)
  expect_true("weight" %in% names(result))
  expect_true(all(result$weight == 1, na.rm = TRUE))
})

test_that("get_crosswalk weights=TRUE uses equal weights for ambiguous pair", {
  clear_split_weights()
  result <- get_crosswalk("NIS_ARRONDISSEMENT_2019", "NUTS3_2021", master_data, weights = TRUE)
  expect_true("weight" %in% names(result))
  verviers <- result[NIS_ARRONDISSEMENT_2019 == "63000"]
  expect_equal(nrow(verviers), 2L)
  expect_equal(sum(verviers$weight), 1, tolerance = 1e-9)
  expect_equal(verviers$weight[1], 0.5, tolerance = 1e-9)
})

test_that("get_crosswalk weights=TRUE uses registered weights when available", {
  clear_split_weights()
  register_split_weights(
    "NIS_ARRONDISSEMENT_2019", "NUTS3_2021",
    data.table(code_from = c(63000L, 63000L),
               code_to   = c("BE335", "BE336"),
               weight    = c(0.857, 0.143))
  )
  result <- get_crosswalk("NIS_ARRONDISSEMENT_2019", "NUTS3_2021", master_data, weights = TRUE)
  verviers <- result[NIS_ARRONDISSEMENT_2019 == "63000"]
  expect_equal(verviers[NUTS3_2021 == "BE335", weight], 0.857, tolerance = 1e-9)
  expect_equal(verviers[NUTS3_2021 == "BE336", weight], 0.143, tolerance = 1e-9)
  clear_split_weights()
})

test_that("get_crosswalk weights=FALSE produces no weight column", {
  result <- get_crosswalk("NIS_COMMUNE_2019", "NUTS3_2021", master_data, weights = FALSE)
  expect_false("weight" %in% names(result))
})
