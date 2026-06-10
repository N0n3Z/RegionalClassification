library(data.table)

# -- Setup : poids Verviers (indicatifs) ---------------------------------------
VERVIERS_WEIGHTS <- data.table(
  code_from = c(63000L, 63000L),
  code_to   = c("BE335", "BE336"),
  weight    = c(0.857, 0.143)
)

# -- Test SR1: register puis get retourne la meme table ------------------------
test_that("register_split_weights / get_split_weights round-trip", {
  clear_split_weights()
  register_split_weights(CLS_NIS_ARRONDISSEMENT_2019, CLS_NUTS3_2021, VERVIERS_WEIGHTS)
  retrieved <- get_split_weights(CLS_NIS_ARRONDISSEMENT_2019, CLS_NUTS3_2021)
  expect_true(is.data.table(retrieved))
  expect_equal(nrow(retrieved), 2L)
  expect_equal(sort(retrieved$code_to), c("BE335", "BE336"))
  clear_split_weights()
})

# -- Test SR2: get retourne NULL si pas enregistre -----------------------------
test_that("get_split_weights returns NULL when not registered", {
  clear_split_weights()
  expect_null(get_split_weights(CLS_NIS_ARRONDISSEMENT_2019, CLS_NUTS3_2021))
})

# -- Test SR3: list_split_weights retourne une data.table apres enregistrement -
test_that("list_split_weights returns data.table with from/to/variable", {
  clear_split_weights()
  register_split_weights(CLS_NIS_ARRONDISSEMENT_2019, CLS_NUTS3_2021, VERVIERS_WEIGHTS,
                         variable = "population")
  lst <- list_split_weights()
  expect_true(is.data.table(lst))
  expect_true(all(c("from", "to", "variable") %in% names(lst)))
  expect_equal(nrow(lst), 1L)
  clear_split_weights()
})

# -- Test SR4: list_split_weights retourne NULL invisible si vide --------------
test_that("list_split_weights returns invisible NULL when empty", {
  clear_split_weights()
  result <- suppressMessages(list_split_weights())
  expect_null(result)
})

# -- Test SR5: clear_split_weights vide le registre ---------------------------
test_that("clear_split_weights removes all registered weights", {
  register_split_weights(CLS_NIS_ARRONDISSEMENT_2019, CLS_NUTS3_2021, VERVIERS_WEIGHTS)
  clear_split_weights()
  expect_null(get_split_weights(CLS_NIS_ARRONDISSEMENT_2019, CLS_NUTS3_2021))
})

# -- Test SR6: plusieurs variables pour la meme paire -------------------------
test_that("register_split_weights supports multiple variables per pair", {
  clear_split_weights()
  register_split_weights(CLS_NIS_ARRONDISSEMENT_2019, CLS_NUTS3_2021,
                         VERVIERS_WEIGHTS, variable = "population")
  register_split_weights(CLS_NIS_ARRONDISSEMENT_2019, CLS_NUTS3_2021,
                         VERVIERS_WEIGHTS, variable = "employment")
  lst <- list_split_weights()
  expect_equal(nrow(lst), 2L)
  expect_true(all(c("population", "employment") %in% lst$variable))
  clear_split_weights()
})

# -- Test SR7: split_ambiguous avec poids enregistres -------------------------
test_that("split_ambiguous uses registered weights when weights=NULL", {
  clear_split_weights()
  register_split_weights(CLS_NIS_ARRONDISSEMENT_2019, CLS_NUTS3_2021, VERVIERS_WEIGHTS)

  dt <- data.table(arr_code = c(11000L, 63000L), total_wage = c(5e9, 1e9))
  result <- suppressMessages(
    split_ambiguous(dt, "arr_code",
                    value_cols  = "total_wage",
                    from        = CLS_NIS_ARRONDISSEMENT_2019,
                    to          = CLS_NUTS3_2021,
                    master_data,
                    value_type  = "additive",
                    verbose     = FALSE)
  )
  expect_true(nrow(result) == 3L)   # 1 simple + 2 split
  verviers_rows <- result[arr_code == 63000L]
  expect_equal(nrow(verviers_rows), 2L)
  expect_equal(sum(verviers_rows$total_wage), 1e9, tolerance = 1)
  clear_split_weights()
})

# -- Test SR8: erreur rcl_invalid_input si weights_dt manque des colonnes ------
test_that("register_split_weights raises rcl_invalid_input for bad weights_dt", {
  expect_error(
    register_split_weights(CLS_NIS_ARRONDISSEMENT_2019, CLS_NUTS3_2021,
                           data.table(a = 1, b = 2)),
    class = "rcl_invalid_input"
  )
})

# -- Test SR9: list_available_conversions retourne une data.table --------------
test_that("list_available_conversions returns a data.table with expected columns", {
  result <- list_available_conversions()
  expect_true(is.data.table(result))
  # Phase 4a: also includes perimeter_relation column
  expect_true(all(c("from", "to", "relation", "perimeter_relation") %in% names(result)))
  expect_gt(nrow(result), 10L)
})

# -- Phase 4c: primitive overlap-edge anchoring --------------------------------

# Test SR10: weights registered for a primitive overlap edge are found when the
# user converts via a longer path that traverses that same edge.
test_that("split_ambiguous finds weights anchored to primitive overlap edge", {
  clear_split_weights()

  # Register weights for the primitive overlap edge (NIS_ARR_2019 -> NUTS3_2021)
  register_split_weights(
    CLS_NIS_ARRONDISSEMENT_2019, CLS_NUTS3_2021,
    VERVIERS_WEIGHTS,
    variable = "population"
  )

  # Build a tiny dataset using NIS_ARR_2019 codes
  dt <- data.table(arr_code = c(63000L), total_wage = c(1e9))

  # split_ambiguous on NIS_ARR_2019 -> NUTS3_2021 directly -- should use registry
  result_direct <- suppressMessages(
    split_ambiguous(dt, "arr_code",
                    value_cols  = "total_wage",
                    from        = CLS_NIS_ARRONDISSEMENT_2019,
                    to          = CLS_NUTS3_2021,
                    master_data,
                    weights     = "population",
                    value_type  = "additive",
                    verbose     = FALSE)
  )
  expect_equal(nrow(result_direct), 2L)
  # Verviers wage should be split 0.857 / 0.143 (not 0.5 / 0.5)
  be335_wage <- result_direct[cd_nuts3_2021 == "BE335", total_wage]
  expect_equal(be335_wage, 1e9 * 0.857, tolerance = 1)

  clear_split_weights()
})

# Test SR11: without any weights registered, split_ambiguous falls back to
# equal weights even when primitive overlap anchoring is attempted.
test_that("split_ambiguous falls back to equal weights when no registry entry exists", {
  clear_split_weights()

  dt <- data.table(arr_code = c(63000L), total_wage = c(1e9))
  result <- suppressWarnings(suppressMessages(
    split_ambiguous(dt, "arr_code",
                    value_cols  = "total_wage",
                    from        = CLS_NIS_ARRONDISSEMENT_2019,
                    to          = CLS_NUTS3_2021,
                    master_data,
                    weights     = "population",  # requested but not registered
                    value_type  = "additive",
                    verbose     = FALSE)
  ))
  # Equal weights: each row gets 0.5 * 1e9
  expect_equal(nrow(result), 2L)
  be335_wage <- result[cd_nuts3_2021 == "BE335", total_wage]
  expect_equal(be335_wage, 5e8, tolerance = 1)

  clear_split_weights()
})
