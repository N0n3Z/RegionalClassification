library(data.table)

# NIS BEFORE_2019 communes inherit their NUTS 2021 / NBB codes from their NIS
# 2019 successor. Reading the NIS->NUTS file at a 2018 reference date used to
# return NUTS 2016 codes (BE221, BE321, ...) for the 87 Hainaut/Limburg
# communes recoded in 2019, and pre-2019 LAU codes for the merged communes.

md_b19 <- load_master_data()
xw_b19 <- md_b19$crosswalks

test_that("BEFORE_2019 -> NUTS_DISTRICT_2021 only yields valid NUTS 2021 codes", {
  to_codes <- xw_b19[classification_from == CLS_NIS_MUNICIPALITY_BEFORE_2019 &
                     classification_to == CLS_NUTS_DISTRICT_2021, code_to]
  valid <- md_b19$entities[classification == CLS_NUTS_DISTRICT_2021, code]
  expect_length(setdiff(to_codes, valid), 0L)
})

test_that("BEFORE_2019 -> NUTS_DISTRICT_2021 equals the path via NIS 2019", {
  hop1 <- xw_b19[classification_from == CLS_NIS_MUNICIPALITY_BEFORE_2019 &
                 classification_to == CLS_NIS_MUNICIPALITY_2019, .(code_from, code_2019 = code_to)]
  hop2 <- xw_b19[classification_from == CLS_NIS_MUNICIPALITY_2019 &
                 classification_to == CLS_NUTS_DISTRICT_2021, .(code_2019 = code_from, via = code_to)]
  direct <- xw_b19[classification_from == CLS_NIS_MUNICIPALITY_BEFORE_2019 &
                   classification_to == CLS_NUTS_DISTRICT_2021, .(code_from, direct = code_to)]
  cmp <- merge(merge(hop1, hop2, by = "code_2019"), direct, by = "code_from")
  expect_equal(nrow(cmp), nrow(direct))
  expect_identical(cmp$direct, cmp$via)
})

test_that("recoded and merged BEFORE_2019 communes get their 2021 codes", {
  m <- wide_view(md_b19, version = VER_BEFORE_2019)
  # Mouscron: 54007 -> 57096 in 2019, NUTS3 BE328 (not the NUTS 2016 BE324)
  expect_identical(m[code_nis_municipality == "54007", code_nuts_district_2021], "BE328")
  expect_identical(m[code_nis_municipality == "54007", code_nuts_municipality_2021], "57096")
  # Puurs: merged into Puurs-Sint-Amands (12041) in 2019
  expect_identical(m[code_nis_municipality == "12030", code_nuts_municipality_2021], "12041")
  expect_false(anyNA(m$code_nbb_district_2021))
})
