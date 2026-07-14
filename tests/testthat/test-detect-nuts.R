library(data.table)

# ==============================================================================
# test-detect-nuts.R -- character-code detection (audit C5)
# ==============================================================================
# The character branch of detect_classification() used to hardcode the 2021
# vintage by nchar, so NUTS 2027 codes and the country code were mislabelled.
# It now matches against the real reference sets and disambiguates 2021 vs 2027
# by membership.
# ==============================================================================

det <- function(x) suppressWarnings(detect_classification(x, master_data))

test_that("NUTS3 2027-only codes are detected as NUTS_DISTRICT_2027, not 2021", {
  expect_equal(det("BE261"),               "NUTS_DISTRICT_2027")
  expect_equal(det(c("BE261", "BE262")),   "NUTS_DISTRICT_2027")
})

test_that("NUTS3 2021-only codes are still detected as NUTS_DISTRICT_2021", {
  expect_equal(det(c("BE211", "BE212")),          "NUTS_DISTRICT_2021")
  # Regression: the historical example (test E7) must keep resolving to 2021.
  expect_equal(det(c("BE100", "BE211", "BE335")), "NUTS_DISTRICT_2021")
})

test_that("country code BE is detected as NUTS_COUNTRY, not NUTS_REGION_2021", {
  expect_equal(det("BE"), "NUTS_COUNTRY")
})

test_that("province-level 2021 vs 2027 codes disambiguate by membership", {
  expect_equal(det("BE26"), "NUTS_PROVINCE_2027")  # exists only in 2027
  expect_equal(det("BE21"), "NUTS_PROVINCE_2021")  # exists only in 2021
})

test_that("codes shared between vintages fall back to the stable 2021 default", {
  # BE2 is the Flemish region in both 2021 and 2027 -> tie -> prefer 2021.
  expect_equal(det("BE2"), "NUTS_REGION_2021")
})

test_that("unknown character codes yield NULL (no false NUTS match)", {
  expect_null(det("ZZ999"))
  expect_null(det(c("XX1", "XX2")))
})
