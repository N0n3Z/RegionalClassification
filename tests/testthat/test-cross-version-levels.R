library(data.table)

# Conversions of aggregated levels between versions and between NIS and NUTS
# (v3.0.0). Expectations come from the official Statbel / Eurostat lists:
# 2025: Moerbeke 44045 (arr. Gent -> Sint-Niklaas), Zwijndrecht 11056 (arr. and
# province Antwerpen -> Sint-Niklaas / Oost-Vlaanderen), Kortessem 73040
# (arr. Tongeren -> Hasselt). 2019: arr. Mouscron 54000 merged into
# Tournai-Mouscron 57000, arr. La Louviere 58000 created.

xv <- function(codes, from, to) {
  r <- suppressWarnings(convert_codes(codes, from, to, master_data, allow_ambiguous = TRUE))
  r <- r[, .(to = paste(sort(unique(code_to)), collapse = "+"),
             nature = paste(sort(unique(na.omit(nature))), collapse = "+")), by = code_from]
  r[match(as.character(codes), code_from)]
}

test_that("NIS districts 2025 <-> 2019", {
  r <- xv(c("46000", "71000", "21000", "63000"), CLS_NIS_DISTRICT_2025, CLS_NIS_DISTRICT_2019)
  expect_identical(r$to, c("11000+44000+46000", "71000+73000", "21000", "63000"))
  expect_identical(r$nature, c("CHANGE_DSTR", "CHANGE_DSTR", "UNCHANGED", "UNCHANGED"))
  r <- xv(c("11000", "44000", "73000", "21000"), CLS_NIS_DISTRICT_2019, CLS_NIS_DISTRICT_2025)
  expect_identical(r$to, c("11000+46000", "44000+46000", "71000+73000", "21000"))
  expect_error(convert_codes("46000", CLS_NIS_DISTRICT_2025, CLS_NIS_DISTRICT_2019, master_data),
               class = "rcl_ambiguous_conversion")
})

test_that("NIS districts BEFORE_2019 <-> 2019 (Hainaut reform)", {
  r <- xv(c("54000", "21000"), CLS_NIS_DISTRICT_BEFORE_2019, CLS_NIS_DISTRICT_2019)
  expect_identical(r$to, c("57000", "21000"))
  expect_identical(r$nature, c("CHANGE_DSTR", "UNCHANGED"))
  r <- xv("58000", CLS_NIS_DISTRICT_2019, CLS_NIS_DISTRICT_BEFORE_2019)
  expect_identical(r$to, "55000+56000")         # La Louviere, Binche, ... from Soignies and Thuin
  r <- xv("57000", CLS_NIS_DISTRICT_2019, CLS_NIS_DISTRICT_BEFORE_2019)
  expect_identical(r$to, "54000+57000")
})

test_that("NIS provinces and regions between versions", {
  r <- xv(c("40000", "10000", "60000"), CLS_NIS_PROVINCE_2025, CLS_NIS_PROVINCE_2019)
  expect_identical(r$to, c("10000+40000", "10000", "60000"))
  expect_identical(r$nature, c("CHANGE_PROV", "CHANGE_PROV", "UNCHANGED"))
  prov <- master_data$entities[classification == CLS_NIS_PROVINCE_2019, code]
  same <- convert_codes(prov, CLS_NIS_PROVINCE_BEFORE_2019, CLS_NIS_PROVINCE_2019, master_data)
  expect_identical(same$code_to, same$code_from)
  for (pair in list(c(CLS_NIS_REGION_2025, CLS_NIS_REGION_2019),
                    c(CLS_NIS_REGION_BEFORE_2019, CLS_NIS_REGION_2019))) {
    r <- convert_codes(c("2000", "3000", "4000"), pair[1], pair[2], master_data)
    expect_identical(r$code_to, c("2000", "3000", "4000"))
  }
})

test_that("NIS <-> NUTS at the same level", {
  p <- convert_codes(c("10000", "20001", "20002", "4000", "60000"),
                     CLS_NIS_PROVINCE_2019, CLS_NUTS_PROVINCE_2021, master_data)
  expect_identical(p$code_to, c("BE21", "BE24", "BE31", "BE10", "BE33"))
  r <- convert_codes(c("BE1", "BE2", "BE3"), CLS_NUTS_REGION_2021, CLS_NIS_REGION_2019, master_data)
  expect_identical(r$code_to, c("4000", "2000", "3000"))
  # 2025 provinces = NUTS2 2027 (Antwerpen and Oost-Vlaanderen renumbered)
  p27 <- convert_codes(c("10000", "40000"), CLS_NIS_PROVINCE_2025, CLS_NUTS_PROVINCE_2027, master_data)
  expect_identical(p27$code_to, c("BE26", "BE27"))
  expect_identical(convert_codes("1000", CLS_NIS_COUNTRY, CLS_NUTS_COUNTRY, master_data)$code_to, "BE")
})

test_that("NUTS 2027 -> 2021 and -> NIS", {
  r <- xv(c("BE26", "BE27"), CLS_NUTS_PROVINCE_2027, CLS_NUTS_PROVINCE_2021)
  expect_identical(r$to, c("BE21", "BE21+BE23"))
  r <- xv(c("BE21", "BE23"), CLS_NUTS_PROVINCE_2021, CLS_NUTS_PROVINCE_2027)
  expect_identical(r$to, c("BE26+BE27", "BE27"))
  # each NUTS3 2027 lies in one NIS 2025 district (simple conversion)
  n3 <- master_data$entities[classification == CLS_NUTS_DISTRICT_2027, code]
  d  <- convert_codes(n3, CLS_NUTS_DISTRICT_2027, CLS_NIS_DISTRICT_2025, master_data)
  expect_false(anyNA(d$code_to))
  expect_equal(nrow(d), length(n3))
})

test_that("existing commune-level precision is kept", {
  # Lokeren 2025 = Lokeren + Moerbeke: districts 46000 + 44000, not 11000
  expect_identical(xv("46029", CLS_NIS_MUNICIPALITY_2025, CLS_NIS_DISTRICT_2019)$to, "44000+46000")
  # an East Flanders commune that did not move stays in province 40000 only
  expect_identical(xv("44021", CLS_NIS_MUNICIPALITY_2025, CLS_NIS_PROVINCE_2019)$to, "40000")
})

test_that("population weights for the 2025 <-> 2019 district splits", {
  tpl <- split_weights_template(CLS_NIS_DISTRICT_2025, CLS_NIS_DISTRICT_2019, master_data,
                                variable = "population", weight_year = 2024L)
  w <- tpl[code_from == "46000"]
  expect_equal(sum(w$weight), 1)
  # share of Moerbeke (44045) in the 2025 district 46000, 2024 population
  pop <- nbbbenuts:::.standard_weight_values("population", CLS_NIS_MUNICIPALITY_2019, 2024L, master_data)
  d46 <- c(convert_codes(pop$code, CLS_NIS_MUNICIPALITY_2019, CLS_NIS_DISTRICT_2025, master_data)[
    code_to == "46000", code_from])
  expect_equal(w[code_to == "44000", weight],
               pop[code == "44045", value] / sum(pop[code %in% d46, value]))
})

test_that("convert_multi_version() handles districts of several versions", {
  dt <- data.table(arr = c("46000", "54000", "58000"))
  res <- convert_multi_version(dt, "arr", CLS_NIS_PROVINCE_2019, master_data,
                               from = c(CLS_NIS_DISTRICT_2025, CLS_NIS_DISTRICT_2019,
                                        CLS_NIS_DISTRICT_BEFORE_2019))
  expect_identical(res$code_nis_province_2019, c("10000+40000", "50000", "50000"))
  expect_identical(res$ambiguous, c(TRUE, FALSE, FALSE))
  expect_identical(res$conflict, c(TRUE, FALSE, FALSE))  # 46000 is 40000 in 2019 alone
})

test_that("BEFORE_2019 -> 2019 population weights: real shares, Oudsbergen blocked", {
  expect_warning(
    tpl <- split_weights_template(CLS_NIS_DISTRICT_BEFORE_2019, CLS_NIS_DISTRICT_2019, master_data,
                                  variable = "population", weight_year = 2019L),
    class = "rcl_weights_required")
  # Hainaut communes moved 1:1: their 2019 population gives the shares
  w55 <- tpl[code_from == "55000"]
  expect_equal(sum(w55$weight), 1)
  expect_gt(w55[code_to == "58000", weight], 0.4)     # La Louviere ~42 %
  # 71000: Opglabbeek went to 72000 but is merged into Oudsbergen (72042) in 2019
  expect_true(all(is.na(tpl[code_from == "71000", weight])))

  dt <- data.table(arr = c("55000", "52000"), v = c(300, 100))
  res <- split_ambiguous(dt, "arr", "v", CLS_NIS_DISTRICT_BEFORE_2019, CLS_NIS_DISTRICT_2019,
                         master_data, weights = "population", verbose = FALSE)
  expect_equal(sum(res$v), 400)
  expect_equal(nrow(res), 5L)

  dt71 <- data.table(arr = c("55000", "71000"), v = c(300, 100))
  expect_error(split_ambiguous(dt71, "arr", "v", CLS_NIS_DISTRICT_BEFORE_2019, CLS_NIS_DISTRICT_2019,
                               master_data, weights = "population", verbose = FALSE),
               class = "rcl_weights_required", regexp = "71000")
  own <- copy(tpl)[code_from == "71000", weight := c(0.97, 0.03)]
  res <- split_ambiguous(dt71, "arr", "v", CLS_NIS_DISTRICT_BEFORE_2019, CLS_NIS_DISTRICT_2019,
                         master_data, weights = own, verbose = FALSE)
  expect_equal(res[arr == "71000" & code_nis_district_2019 == "72000", v], 3)
})

test_that("postal 1020 (Laeken) reaches its 2025 district though it has no 2025 commune", {
  expect_true(is.na(convert_codes("1020", CLS_POSTAL, CLS_NIS_MUNICIPALITY_2025, master_data)$code_to))
  expect_identical(convert_codes("1020", CLS_POSTAL, CLS_NIS_DISTRICT_2025, master_data)$code_to, "21000")
})
