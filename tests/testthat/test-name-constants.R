library(data.table)

# ==============================================================================
# test-name-constants.R -- CLS_* / VER_* constant coherence guards
# ==============================================================================
# Ensures that the constants declared in R/00_config.R stay in sync with
# the runtime registry (CLASSIFICATION_NODES) and the actual data.
# Any mismatch here means a constant was renamed without updating the registry
# or vice versa.
# ==============================================================================

md <- load_master_data()

test_that("CLS_ALL exactly matches names(CLASSIFICATION_NODES)", {
  expect_setequal(CLS_ALL, names(CLASSIFICATION_NODES))
})

test_that("CLS_ALL has no duplicates", {
  expect_equal(length(CLS_ALL), length(unique(CLS_ALL)))
})

test_that("CLS_ALL has 23 entries (one per supported classification node)", {
  expect_equal(length(CLS_ALL), 23L)
})

test_that("VER_BEFORE_2019 appears in communes data", {
  expect_true(VER_BEFORE_2019 %in% md$communes$nis_version)
})

test_that("VER_2019 appears in communes data", {
  expect_true(VER_2019 %in% md$communes$nis_version)
})

test_that("VER_2025 appears in communes data", {
  expect_true(VER_2025 %in% md$communes$nis_version)
})

test_that("all CLS_* values are recognized by normalize_classification_id()", {
  for (cls in CLS_ALL) {
    expect_equal(
      normalize_classification_id(cls), cls,
      label = paste("normalize_classification_id(", cls, ")")
    )
  }
})
