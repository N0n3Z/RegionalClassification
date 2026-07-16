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
  register_split_weights(CLS_NIS_DISTRICT_2019, CLS_NUTS_DISTRICT_2021, VERVIERS_WEIGHTS)
  retrieved <- get_split_weights(CLS_NIS_DISTRICT_2019, CLS_NUTS_DISTRICT_2021)
  expect_true(is.data.table(retrieved))
  expect_equal(nrow(retrieved), 2L)
  expect_equal(sort(retrieved$code_to), c("BE335", "BE336"))
  clear_split_weights()
})

# -- Test SR2: get retourne NULL si pas enregistre -----------------------------
test_that("get_split_weights returns NULL when not registered", {
  clear_split_weights()
  expect_null(get_split_weights(CLS_NIS_DISTRICT_2019, CLS_NUTS_DISTRICT_2021))
})

# -- Test SR3: list_split_weights retourne une data.table apres enregistrement -
test_that("list_split_weights returns data.table with from/to/variable", {
  clear_split_weights()
  register_split_weights(CLS_NIS_DISTRICT_2019, CLS_NUTS_DISTRICT_2021, VERVIERS_WEIGHTS,
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
  register_split_weights(CLS_NIS_DISTRICT_2019, CLS_NUTS_DISTRICT_2021, VERVIERS_WEIGHTS)
  clear_split_weights()
  expect_null(get_split_weights(CLS_NIS_DISTRICT_2019, CLS_NUTS_DISTRICT_2021))
})

# -- Test SR6: plusieurs variables pour la meme paire -------------------------
test_that("register_split_weights supports multiple variables per pair", {
  clear_split_weights()
  register_split_weights(CLS_NIS_DISTRICT_2019, CLS_NUTS_DISTRICT_2021,
                         VERVIERS_WEIGHTS, variable = "population")
  register_split_weights(CLS_NIS_DISTRICT_2019, CLS_NUTS_DISTRICT_2021,
                         VERVIERS_WEIGHTS, variable = "employment")
  lst <- list_split_weights()
  expect_equal(nrow(lst), 2L)
  expect_true(all(c("population", "employment") %in% lst$variable))
  clear_split_weights()
})

# -- Test SR7: split_ambiguous avec poids enregistres -------------------------
test_that("split_ambiguous uses registered weights when weights=NULL", {
  clear_split_weights()
  register_split_weights(CLS_NIS_DISTRICT_2019, CLS_NUTS_DISTRICT_2021, VERVIERS_WEIGHTS)

  dt <- data.table(arr_code = c(11000L, 63000L), total_wage = c(5e9, 1e9))
  result <- suppressMessages(
    split_ambiguous(dt, "arr_code",
                    value_cols  = "total_wage",
                    from        = CLS_NIS_DISTRICT_2019,
                    to          = CLS_NUTS_DISTRICT_2021,
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
    register_split_weights(CLS_NIS_DISTRICT_2019, CLS_NUTS_DISTRICT_2021,
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

  # Register weights for the primitive overlap edge (NIS_ARR_2019 -> NUTS_DISTRICT_2021)
  register_split_weights(
    CLS_NIS_DISTRICT_2019, CLS_NUTS_DISTRICT_2021,
    VERVIERS_WEIGHTS,
    variable = "population"
  )

  # Build a tiny dataset using NIS_ARR_2019 codes
  dt <- data.table(arr_code = c(63000L), total_wage = c(1e9))

  # split_ambiguous on NIS_ARR_2019 -> NUTS_DISTRICT_2021 directly -- should use registry
  result_direct <- suppressMessages(
    split_ambiguous(dt, "arr_code",
                    value_cols  = "total_wage",
                    from        = CLS_NIS_DISTRICT_2019,
                    to          = CLS_NUTS_DISTRICT_2021,
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
                    from        = CLS_NIS_DISTRICT_2019,
                    to          = CLS_NUTS_DISTRICT_2021,
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

# -- split_weights_template: variable / commune_values (single-variable) -------

test_that("split_weights_template default (no variable) returns equal weights", {
  tpl <- split_weights_template(CLS_NIS_DISTRICT_2019, CLS_NUTS_DISTRICT_2021, master_data)
  v <- tpl[code_from == "63000"]
  expect_setequal(v$code_to, c("BE335", "BE336"))
  expect_equal(v$weight, c(0.5, 0.5), tolerance = 1e-9)
})

test_that("split_weights_template computes weighted (non-equal) shares from commune_values", {
  # Verviers arr 63000 -> {BE335, BE336}. Weights = share of the supplied
  # commune-level variable, normalised per code_from. Uniform values -> the share
  # reflects the commune partition (not necessarily 0.5/0.5), and must sum to 1.
  comm19 <- as.character(master_data$communes[nis_version == VER_2019, cd_commune])
  cv  <- data.table(code = comm19, value = 1)
  tpl <- split_weights_template(CLS_NIS_DISTRICT_2019, CLS_NUTS_DISTRICT_2021,
                                master_data, commune_values = cv)
  v <- tpl[code_from == "63000"]
  expect_equal(nrow(v), 2L)
  expect_setequal(v$code_to, c("BE335", "BE336"))
  expect_lt(abs(sum(v$weight) - 1), 1e-9)        # normalised per code_from
  expect_true(all(v$weight > 0 & v$weight < 1))  # genuinely split, both targets > 0
})

test_that("split_weights_template errors for an unshipped standard variable", {
  expect_error(
    split_weights_template(CLS_NIS_DISTRICT_2019, CLS_NUTS_DISTRICT_2021,
                           master_data, variable = "does_not_exist_xyz"),
    class = "rcl_data_missing"
  )
})

# -- M3: zero weight sum must not produce NaN ---------------------------------
test_that("split_ambiguous falls back to equal weights when weights sum to zero", {
  # All-zero weights for a code_from would divide to NaN during normalisation.
  # It must instead fall back to equal weights (audit M3).
  dat <- data.table(arr = 63000L, value = 100)
  wts_zero <- data.table(code_from = c("63000", "63000"),
                         code_to   = c("BE335", "BE336"),
                         weight    = c(0, 0))
  r <- suppressWarnings(
    split_ambiguous(dat, "arr", value_cols = "value",
                    from = CLS_NIS_DISTRICT_2019, to = CLS_NUTS_DISTRICT_2021,
                    master_data = master_data, weights = wts_zero,
                    value_type = "additive")
  )
  expect_false(any(is.nan(r$value)))
  expect_false(anyNA(r$value))
  expect_equal(sum(r$value), 100)
  expect_equal(nrow(r), 2L)
  expect_equal(r$value, c(50, 50))  # equal split
})

# -- Coverage: weight NORMALISATION is actually exercised (audit blind spot) ---
# Previous tests all supplied weights that already summed to 1, so the
# normalisation step was a no-op everywhere. These use non-unit weights.
test_that("normalize = TRUE rescales non-unit weights and preserves the total", {
  dat <- data.table(arr = 63000L, val = 1000)
  wts <- data.table(code_from = c("63000", "63000"),
                    code_to   = c("BE335", "BE336"),
                    weight    = c(2, 3))          # sum = 5, not 1
  r <- suppressWarnings(
    split_ambiguous(dat, "arr", value_cols = "val", from = CLS_NIS_DISTRICT_2019,
                    to = CLS_NUTS_DISTRICT_2021, master_data = master_data,
                    weights = wts, value_type = "additive")   # normalize = TRUE default
  )
  setkey(r, cd_nuts3_2021)
  expect_equal(r[cd_nuts3_2021 == "BE335", val], 400)   # 2/5
  expect_equal(r[cd_nuts3_2021 == "BE336", val], 600)   # 3/5
  expect_equal(sum(r$val), 1000)                        # additive total preserved
})

test_that("normalize = FALSE applies raw weights (no rescaling)", {
  dat <- data.table(arr = 63000L, val = 1000)
  wts <- data.table(code_from = c("63000", "63000"),
                    code_to   = c("BE335", "BE336"),
                    weight    = c(2, 3))
  r <- suppressWarnings(
    split_ambiguous(dat, "arr", value_cols = "val", from = CLS_NIS_DISTRICT_2019,
                    to = CLS_NUTS_DISTRICT_2021, master_data = master_data,
                    weights = wts, value_type = "additive", normalize = FALSE)
  )
  setkey(r, cd_nuts3_2021)
  expect_equal(r[cd_nuts3_2021 == "BE335", val], 2000)  # 1000 * 2
  expect_equal(r[cd_nuts3_2021 == "BE336", val], 3000)  # 1000 * 3
})

test_that("additive split is sum-invariant with equal weights", {
  # No weights -> equal weights; the additive total must be conserved exactly.
  dat <- data.table(arr = c(63000L, 11000L), val = c(1000, 500))
  r <- suppressWarnings(
    split_ambiguous(dat, "arr", value_cols = "val", from = CLS_NIS_DISTRICT_2019,
                    to = CLS_NUTS_DISTRICT_2021, master_data = master_data,
                    value_type = "additive")
  )
  expect_equal(sum(r$val), 1500)   # 1000 (split across BE335/BE336) + 500
})

# -- Shipped standard population weights (variable = "population") -------------
test_that("population weights load, are non-equal, and sum to 1 per code_from", {
  tpl <- split_weights_template(CLS_NIS_DISTRICT_2019, CLS_NUTS_DISTRICT_2021,
                                master_data, variable = "population")
  v <- tpl[code_from == "63000"]
  expect_equal(nrow(v), 2L)
  expect_setequal(v$code_to, c("BE335", "BE336"))
  expect_lt(abs(sum(v$weight) - 1), 1e-9)
  expect_false(isTRUE(all.equal(v$weight, c(0.5, 0.5))))  # real shares, not equal
})

test_that("weight_year selects a shipped year (default = most recent)", {
  latest <- split_weights_template(CLS_NIS_DISTRICT_2019, CLS_NUTS_DISTRICT_2021,
                                   master_data, variable = "population")
  y2011  <- split_weights_template(CLS_NIS_DISTRICT_2019, CLS_NUTS_DISTRICT_2021,
                                   master_data, variable = "population", weight_year = 2011L)
  # Both valid distributions; the years differ so at least the Verviers share moves.
  w_latest <- latest[code_from == "63000" & code_to == "BE335", weight]
  w_2011   <- y2011[code_from == "63000" & code_to == "BE335", weight]
  expect_false(isTRUE(all.equal(w_latest, w_2011)))
})

test_that("an unshipped year raises rcl_data_missing", {
  expect_error(
    split_weights_template(CLS_NIS_DISTRICT_2019, CLS_NUTS_DISTRICT_2021,
                           master_data, variable = "population", weight_year = 1999L),
    class = "rcl_data_missing"
  )
})

test_that("split_ambiguous(weights = 'population') uses the shipped standard end-to-end", {
  dat <- data.table(arr = 63000L, emploi = 100000)
  r <- split_ambiguous(dat, "arr", value_cols = "emploi",
                       from = CLS_NIS_DISTRICT_2019, to = CLS_NUTS_DISTRICT_2021,
                       master_data = master_data, weights = "population",
                       value_type = "additive", verbose = FALSE)
  expect_equal(nrow(r), 2L)
  expect_equal(sum(r$emploi), 100000)                 # additive total preserved
  expect_gt(r[cd_nuts3_2021 == "BE335", emploi],      # francophone share is larger
            r[cd_nuts3_2021 == "BE336", emploi])
})

test_that("population weights also cover the NUTS3 2021->2027 aggregate edge", {
  tpl <- split_weights_template(CLS_NUTS_DISTRICT_2021, CLS_NUTS_DISTRICT_2027,
                                master_data, variable = "population")
  expect_gt(nrow(tpl), 0L)
  expect_true(all(abs(tpl[, sum(weight), by = code_from]$V1 - 1) < 1e-9))
})
