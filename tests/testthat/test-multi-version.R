library(data.table)

mv_dt <- data.table(
  commune = c("21004", "46029", "54007", "99999", NA, "11002", "44021"),
  value   = 1:7
)
# 21004 Bruxelles   : same code in every version
# 46029 Lokeren     : 2025 only (Lokeren + Moerbeke)
# 54007 Mouscron    : BEFORE_2019 only (recoded 57096 in 2019)
# 99999             : unknown in every version
# 11002 Antwerpen   : 2019 and 2025 (2025 = Antwerpen + Borsbeek)

test_that("one column per version, a final column and the three flags", {
  res <- convert_multi_version(mv_dt, "commune", CLS_NIS_REGION_2019, master_data)
  expect_identical(names(res), c(
    "commune", "value",
    "code_nis_region_2019_from_2025", "code_nis_region_2019_from_2019",
    "code_nis_region_2019_from_before_2019", "code_nis_region_2019",
    "conflict", "no_match", "ambiguous"))
  expect_equal(nrow(res), nrow(mv_dt))
  expect_identical(res$commune, mv_dt$commune)        # row order and codes kept
  expect_identical(res$code_nis_region_2019_from_2025,
                   c("4000", "2000", NA, NA, NA, "2000", "2000"))
  expect_identical(res$code_nis_region_2019_from_2019,
                   c("4000", NA, NA, NA, NA, "2000", "2000"))
  expect_identical(res$code_nis_region_2019_from_before_2019,
                   c("4000", NA, "3000", NA, NA, "2000", "2000"))
  expect_identical(res$code_nis_region_2019, c("4000", "2000", "3000", NA, NA, "2000", "2000"))
  expect_identical(res$conflict,  rep(FALSE, 7L))
  expect_identical(res$no_match,  c(FALSE, FALSE, FALSE, TRUE, TRUE, FALSE, FALSE))
  expect_identical(res$ambiguous, rep(FALSE, 7L))
})

test_that("the input dataset is not modified", {
  before <- copy(mv_dt)
  convert_multi_version(mv_dt, "commune", CLS_NIS_REGION_2019, master_data)
  expect_identical(mv_dt, before)
})

test_that("ambiguous conversions are joined and flagged", {
  res <- convert_multi_version(mv_dt, "commune", CLS_NUTS_DISTRICT_2021, master_data)
  expect_identical(res[commune == "46029", code_nuts_district_2021], "BE234+BE236")
  expect_true(res[commune == "46029", ambiguous])
  expect_identical(res[commune == "54007", code_nuts_district_2021], "BE328")
  res2 <- convert_multi_version(mv_dt, "commune", CLS_NUTS_DISTRICT_2021, master_data, sep = " | ")
  expect_identical(res2[commune == "46029", code_nuts_district_2021], "BE234 | BE236")
})

test_that("versions that disagree are flagged as conflict", {
  # 11002 is Antwerpen in 2019 but Antwerpen + Borsbeek in 2025
  res <- convert_multi_version(mv_dt, "commune", CLS_NIS_MUNICIPALITY_2019, master_data)
  r <- res[commune == "11002"]
  expect_identical(r$code_nis_municipality_2019_from_2025, "11002+11007")
  expect_identical(r$code_nis_municipality_2019_from_2019, "11002")
  expect_true(r$conflict)
  expect_identical(r$code_nis_municipality_2019, "11002+11007")  # 2025 first by default
  expect_false(res[commune == "21004", conflict])
})

test_that("`from` sets the versions and their priority", {
  res <- convert_multi_version(mv_dt, "commune", CLS_NIS_MUNICIPALITY_2019, master_data,
                               from = c(CLS_NIS_MUNICIPALITY_2019, CLS_NIS_MUNICIPALITY_2025))
  expect_identical(grep("_from_", names(res), value = TRUE),
                   c("code_nis_municipality_2019_from_2019", "code_nis_municipality_2019_from_2025"))
  expect_identical(res[commune == "11002", code_nis_municipality_2019], "11002")
  expect_true(res[commune == "54007", no_match])      # BEFORE_2019 not requested
})

test_that("a version without route to the target aborts before converting", {
  # NIS districts have no cross-version edge: BEFORE_2019 districts cannot reach
  # the 2019 provinces.
  dt <- data.table(arr = c("63000", "54000"))
  expect_error(
    convert_multi_version(dt, "arr", CLS_NIS_PROVINCE_2019, master_data,
                          from = c(CLS_NIS_DISTRICT_2019, CLS_NIS_DISTRICT_BEFORE_2019)),
    class = "rcl_no_route", regexp = "NIS_DISTRICT_BEFORE_2019")
  res <- convert_multi_version(dt, "arr", CLS_NIS_PROVINCE_2019, master_data,
                               from = CLS_NIS_DISTRICT_2019)
  expect_identical(res$code_nis_province_2019, c("60000", NA))
  expect_identical(res$no_match, c(FALSE, TRUE))   # 54000 (arr. Mouscron) gone in 2019
})

test_that("integer codes, data.frame input and a custom target column", {
  res <- convert_multi_version(data.frame(c = c(21004L, 46029L)), "c", CLS_NIS_REGION_2019,
                               master_data, target_col = "region")
  expect_true(is.data.table(res))
  expect_identical(res$region, c("4000", "2000"))
  expect_true("region_from_2025" %in% names(res))
})

test_that("versions shared by two entries of `from` fall back to full ids", {
  res <- convert_multi_version(data.table(x = "BE100"), "x", CLS_NUTS_REGION_2021, master_data,
                               from = c(CLS_NUTS_DISTRICT_2021, CLS_NBB_DISTRICT_2021))
  expect_true(all(c("code_nuts_region_2021_from_nuts_district_2021",
                    "code_nuts_region_2021_from_nbb_district_2021") %in% names(res)))
  expect_identical(res$code_nuts_region_2021, "BE1")
})

test_that("invalid arguments abort with rcl_invalid_input", {
  expect_error(convert_multi_version(mv_dt, "nope", CLS_NIS_REGION_2019, master_data),
               class = "rcl_invalid_input")
  expect_error(convert_multi_version(mv_dt, "commune", CLS_NIS_REGION_2019, master_data,
                                     from = character(0)), class = "rcl_invalid_input")
  expect_error(convert_multi_version(mv_dt, "commune", CLS_NIS_REGION_2019, master_data,
                                     from = c(CLS_NIS_MUNICIPALITY_2019, CLS_NIS_MUNICIPALITY_2019)),
               class = "rcl_invalid_input")
  expect_error(convert_multi_version(mv_dt, "commune", CLS_NIS_REGION_2019, master_data, sep = ""),
               class = "rcl_invalid_input")
  clash <- copy(mv_dt)[, conflict := TRUE]
  expect_error(convert_multi_version(clash, "commune", CLS_NIS_REGION_2019, master_data),
               class = "rcl_invalid_input")
  expect_error(convert_multi_version(mv_dt, "commune", "NOT_A_CLASSIFICATION", master_data))
})
