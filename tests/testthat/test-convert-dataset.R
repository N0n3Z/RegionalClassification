library(data.table)

# ── Test CD1: conversion simple NIS_COMMUNE_2019 -> NUTS3_2021 ────────────────
test_that("convert_dataset adds target column correctly", {
  dt <- data.table(cd_commune = c(21004L, 11002L, 62063L), value = 1:3)
  result <- convert_dataset(dt, "cd_commune", to = "NUTS3_2021", master_data)
  expect_true(is.data.table(result))
  expect_true("cd_nuts3_2021" %in% names(result) || any(grepl("nuts3", names(result), ignore.case = TRUE)))
  expect_equal(nrow(result), 3L)
})

# ── Test CD2: auto-détection de la classification source ──────────────────────
test_that("convert_dataset auto-detects from when omitted", {
  dt <- data.table(cd_commune = c(21004L, 11002L), pop = c(100L, 200L))
  expect_no_error(
    convert_dataset(dt, "cd_commune", to = "NUTS3_2021", master_data)
  )
})

# ── Test CD3: erreur rcl_invalid_input si colonne absente ─────────────────────
test_that("convert_dataset raises rcl_invalid_input for missing column", {
  dt <- data.table(x = 1:3)
  expect_error(
    convert_dataset(dt, "nonexistent_col", to = "NUTS3_2021", master_data),
    class = "rcl_invalid_input"
  )
})

# ── Test CD4: erreur rcl_invalid_input si dt n'est pas un data.frame ──────────
test_that("convert_dataset raises rcl_invalid_input for non-data.frame input", {
  expect_error(
    convert_dataset("not_a_table", "col", to = "NUTS3_2021", master_data),
    class = "rcl_invalid_input"
  )
})

# ── Test CD5: conversion POSTAL -> NIS_COMMUNE_2019 ───────────────────────────
test_that("convert_dataset works for POSTAL -> NIS_COMMUNE_2019", {
  dt <- data.table(cp = c(1000L, 2000L, 4000L))
  result <- convert_dataset(dt, "cp", from = "POSTAL",
                            to = "NIS_COMMUNE_2019", master_data)
  expect_equal(nrow(result), 3L)
  expect_true(any(grepl("nis|commune", names(result), ignore.case = TRUE)))
})

# ── Test CD6: données inchangées (colonnes supplémentaires préservées) ─────────
test_that("convert_dataset preserves all original columns", {
  dt <- data.table(cd_commune = c(21004L, 11002L), pop = c(100L, 200L),
                   income = c(30000.0, 28000.0))
  result <- convert_dataset(dt, "cd_commune", to = "NUTS3_2021", master_data)
  expect_true(all(c("pop", "income") %in% names(result)))
})
