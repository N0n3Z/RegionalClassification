library(data.table)

# Helper: arrondissement data where Verviers (63000) splits into BE335 + BE336
make_arr_panel <- function() {
  data.table(
    year = c(2022L, 2022L),
    arr  = c(63000L, 11000L),
    pop  = c(100000, 50000)
  )
}

# Helper: synthetic panel spanning 2022-2025 with communes 11002, 11007, 21004.
# In 2025, communes 11002 and 11007 merged into 11002 (NIS 2025).
make_panel <- function() {
  data.table(
    year      = c(2022L, 2022L, 2022L, 2025L, 2025L),
    commune   = c(11002L, 11007L, 21004L, 11002L, 21004L),
    population = c(18000, 8500, 180000, 28000, 185000)
  )
}

# ── Test R1: fusion N:1 — values are summed for merged communes ───────────────
test_that("rebase_series sums values for fused communes", {
  result <- rebase_series(
    make_panel(),
    period_col  = "year",
    code_col    = "commune",
    value_cols  = "population",
    version_map = list("NIS_COMMUNE_2019" = 2022L,
                       "NIS_COMMUNE_2025" = 2025L),
    to          = "NIS_COMMUNE_2025",
    master_data = master_data
  )
  expect_true(is.data.table(result))
  expect_equal(sort(names(result)), sort(c("year", "commune", "population")))
  # 11002 + 11007 in 2022 should sum to 26500
  expect_equal(result[year == 2022L & commune == "11002", population], 26500)
})

# ── Test R2: no-op conversion (from == to) ────────────────────────────────────
test_that("rebase_series returns data unchanged when source == target", {
  data <- data.table(year = 2025L, commune = 21004L, pop = 185000)
  result <- rebase_series(
    data,
    period_col  = "year",
    code_col    = "commune",
    value_cols  = "pop",
    version_map = list("NIS_COMMUNE_2025" = 2025L),
    to          = "NIS_COMMUNE_2025",
    master_data = master_data
  )
  expect_equal(nrow(result), 1L)
  expect_equal(result$pop, 185000)
})

# ── Test R3: 2025 data untouched, only 2022 data converted ───────────────────
test_that("rebase_series preserves 2025 values and only converts 2022 chunk", {
  result <- rebase_series(
    make_panel(),
    period_col  = "year",
    code_col    = "commune",
    value_cols  = "population",
    version_map = list("NIS_COMMUNE_2019" = 2022L,
                       "NIS_COMMUNE_2025" = 2025L),
    to          = "NIS_COMMUNE_2025",
    master_data = master_data
  )
  expect_equal(result[year == 2025L & commune == "11002", population], 28000)
  expect_equal(result[year == 2025L & commune == "21004", population], 185000)
})

# ── Test R4: multiple value columns aggregated independently ─────────────────
test_that("rebase_series aggregates multiple value columns", {
  data <- data.table(
    year    = c(2022L, 2022L),
    commune = c(11002L, 11007L),
    pop     = c(18000, 8500),
    empl    = c(5000, 2000)
  )
  result <- rebase_series(
    data,
    period_col  = "year",
    code_col    = "commune",
    value_cols  = c("pop", "empl"),
    version_map = list("NIS_COMMUNE_2019" = 2022L),
    to          = "NIS_COMMUNE_2025",
    master_data = master_data
  )
  expect_equal(result[commune == "11002", pop],  26500)
  expect_equal(result[commune == "11002", empl],  7000)
})

# ── Test R5: custom aggregation function ─────────────────────────────────────
test_that("rebase_series respects custom fun argument", {
  data <- data.table(
    year    = c(2022L, 2022L),
    commune = c(11002L, 11007L),
    rate    = c(0.4, 0.6)
  )
  result <- rebase_series(
    data,
    period_col  = "year",
    code_col    = "commune",
    value_cols  = "rate",
    version_map = list("NIS_COMMUNE_2019" = 2022L),
    to          = "NIS_COMMUNE_2025",
    master_data = master_data,
    fun         = mean
  )
  expect_equal(result[commune == "11002", rate], mean(c(0.4, 0.6)))
})

# ── Test R6: uncovered periods trigger a warning and are dropped ──────────────
test_that("rebase_series warns and drops uncovered periods", {
  data <- data.table(year = 2022:2023, commune = 21004L, pop = c(1, 2))
  expect_warning(
    result <- rebase_series(
      data,
      period_col  = "year",
      code_col    = "commune",
      value_cols  = "pop",
      version_map = list("NIS_COMMUNE_2019" = 2022L),
      to          = "NIS_COMMUNE_2025",
      master_data = master_data
    ),
    class = "rcl_missing_periods"
  )
  expect_equal(nrow(result), 1L)
  expect_equal(result$year, 2022L)
})

# ── Test R7: error for invalid classification ─────────────────────────────────
test_that("rebase_series errors for invalid classification in version_map", {
  data <- data.table(year = 2022L, commune = 21004L, pop = 1)
  expect_error(
    rebase_series(data, "year", "commune", "pop",
                  version_map = list("MAUVAISE_CLASSIF" = 2022L),
                  to = "NIS_COMMUNE_2025",
                  master_data = master_data),
    class = "rcl_invalid_classification"
  )
})

# ── Test R8: error for invalid column names ───────────────────────────────────
test_that("rebase_series errors when column not found in data", {
  data <- data.table(year = 2022L, commune = 21004L, pop = 1)
  expect_error(
    rebase_series(data, "year", "commune", "INEXISTANT",
                  version_map = list("NIS_COMMUNE_2019" = 2022L),
                  to = "NIS_COMMUNE_2025",
                  master_data = master_data),
    class = "rcl_invalid_input"
  )
})

# ── Test R9: split = NULL replicates values and emits rcl_ambiguous_split ─────
test_that("rebase_series with split=NULL replicates split values and warns", {
  expect_warning(
    result <- rebase_series(
      make_arr_panel(),
      period_col  = "year",
      code_col    = "arr",
      value_cols  = "pop",
      version_map = list("NIS_ARRONDISSEMENT_2019" = 2022L),
      to          = "NUTS3_2021",
      master_data = master_data,
      split       = NULL
    ),
    class = "rcl_ambiguous_split"
  )
  # Both targets receive the full original value (replicated)
  expect_equal(result[arr == "BE335", pop], 100000)
  expect_equal(result[arr == "BE336", pop], 100000)
})

# ── Test R10: split = "population" uses equal weights when none registered ────
test_that("rebase_series split='population' falls back to equal weights with warning", {
  clear_split_weights()
  expect_warning(
    result <- rebase_series(
      make_arr_panel(),
      period_col  = "year",
      code_col    = "arr",
      value_cols  = "pop",
      version_map = list("NIS_ARRONDISSEMENT_2019" = 2022L),
      to          = "NUTS3_2021",
      master_data = master_data,
      split       = "population"
    ),
    class = "rcl_unmatched_codes"
  )
  # Equal split: 100000 / 2 = 50000 each
  expect_equal(result[arr == "BE335", pop], 50000)
  expect_equal(result[arr == "BE336", pop], 50000)
})

# ── Test R11: split with registered population weights ────────────────────────
test_that("rebase_series uses registered population weights for splits", {
  clear_split_weights()
  register_split_weights(
    from       = "NIS_ARRONDISSEMENT_2019",
    to         = "NUTS3_2021",
    weights_dt = data.table(
      code_from = c(63000L, 63000L),
      code_to   = c("BE335", "BE336"),
      weight    = c(0.857, 0.143)
    ),
    variable = "population"
  )
  result <- rebase_series(
    make_arr_panel(),
    period_col  = "year",
    code_col    = "arr",
    value_cols  = "pop",
    version_map = list("NIS_ARRONDISSEMENT_2019" = 2022L),
    to          = "NUTS3_2021",
    master_data = master_data,
    split       = "population"
  )
  expect_equal(result[arr == "BE335", pop], 100000 * 0.857)
  expect_equal(result[arr == "BE336", pop], 100000 * 0.143)
  clear_split_weights()
})

# ── Test R12: split with explicit weight data.table ───────────────────────────
test_that("rebase_series accepts explicit weight data.table for splits", {
  w <- data.table(
    code_from = c(63000L, 63000L),
    code_to   = c("BE335", "BE336"),
    weight    = c(0.7, 0.3)
  )
  result <- rebase_series(
    make_arr_panel(),
    period_col  = "year",
    code_col    = "arr",
    value_cols  = "pop",
    version_map = list("NIS_ARRONDISSEMENT_2019" = 2022L),
    to          = "NUTS3_2021",
    master_data = master_data,
    split       = w
  )
  expect_equal(result[arr == "BE335", pop], 70000)
  expect_equal(result[arr == "BE336", pop], 30000)
})

# ── Test R13: output column order and types ───────────────────────────────────
test_that("rebase_series output contains exactly period, code, value columns", {
  result <- rebase_series(
    make_panel(),
    period_col  = "year",
    code_col    = "commune",
    value_cols  = "population",
    version_map = list("NIS_COMMUNE_2019" = 2022L,
                       "NIS_COMMUNE_2025" = 2025L),
    to          = "NIS_COMMUNE_2025",
    master_data = master_data
  )
  expect_equal(sort(names(result)), sort(c("year", "commune", "population")))
})
