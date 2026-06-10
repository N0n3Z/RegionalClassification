library(data.table)

# ==============================================================================
# test-lau-bijection.R -- NUTS_LAU_2021 <-> NIS_COMMUNE_2019 bijection guard
# ==============================================================================
# In Belgium, NUTS_LAU_2021 (Eurostat Local Administrative Units) is in
# near-bijection with NIS_COMMUNE_2019: same geographic entities, same codes
# (cd_nuts_lau == as.character(cd_commune) for all but one commune).
# These tests lock that guarantee so a future data rebuild that breaks it is
# caught immediately.
# ==============================================================================

md <- load_master_data()

test_that("NIS_COMMUNE_2019 -> NUTS_LAU_2021 is 1:1 (no commune maps to 2 LAU codes)", {
  communes <- .list_codes_for("NIS_COMMUNE_2019", md)
  r <- suppressWarnings(convert_codes(communes, "NIS_COMMUNE_2019", "NUTS_LAU_2021", md))
  dups <- r[!is.na(code_to), .N, by = code_from][N > 1L]
  expect_equal(nrow(dups), 0L,
    info = paste("Communes with multiple LAU targets:", paste(dups$code_from, collapse = ", ")))
})

test_that("NUTS_LAU_2021 -> NIS_COMMUNE_2019 is 1:1 (no LAU code maps to 2 communes)", {
  lau_codes <- .list_codes_for("NUTS_LAU_2021", md)
  r <- suppressWarnings(convert_codes(lau_codes, "NUTS_LAU_2021", "NIS_COMMUNE_2019", md))
  dups <- r[!is.na(code_to), .N, by = code_from][N > 1L]
  expect_equal(nrow(dups), 0L,
    info = paste("LAU codes with multiple commune targets:", paste(dups$code_from, collapse = ", ")))
})

test_that("LAU codes equal NIS codes cast to character for all mapped communes", {
  communes <- .list_codes_for("NIS_COMMUNE_2019", md)
  r <- suppressWarnings(convert_codes(communes, "NIS_COMMUNE_2019", "NUTS_LAU_2021", md))
  r_mapped <- r[!is.na(code_to)]
  n_equal  <- r_mapped[as.character(code_from) == code_to, .N]
  n_total  <- nrow(r_mapped)
  # All mapped communes have LAU code == NIS code (character)
  expect_equal(n_equal, n_total,
    label = sprintf("%d/%d LAU codes equal NIS code (character)", n_equal, n_total))
})

test_that("coverage: at most 2 NIS 2019 communes have no LAU code", {
  # 2 communes are absent from the Eurostat LAU 2021 file for Belgium
  communes <- .list_codes_for("NIS_COMMUNE_2019", md)
  r <- suppressWarnings(convert_codes(communes, "NIS_COMMUNE_2019", "NUTS_LAU_2021", md))
  n_na <- r[is.na(code_to), .N]
  expect_lte(n_na, 2L,
    label = sprintf("%d commune(s) without a LAU code", n_na))
})
