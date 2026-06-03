library(data.table)

# ── Test F1: classe d'erreur pour classification non supportée ────────────────
test_that("fuzzy_match_names throws rcl_invalid_classification for unknown classification", {
  expect_error(
    fuzzy_match_names("Bruxelles", "UNKNOWN_CLASSIFICATION", master_data),
    class = "rcl_invalid_classification"
  )
})

# ── Test F2: normalize_name supprime les accents et les préfixes ──────────────
test_that("normalize_name strips accents and arrondissement prefix", {
  expect_equal(nbbbenuts:::normalize_name("Liège"),    "liege")
  expect_equal(nbbbenuts:::normalize_name("Bruxelles"), "bruxelles")
  expect_equal(nbbbenuts:::normalize_name("Arrondissement de Liège"), "liege")
  expect_equal(nbbbenuts:::normalize_name("arrondissement d'Anvers"), "anvers")
})

# ── Test F3: correspondance exacte retourne distance = 0 ─────────────────────
test_that("fuzzy_match_names exact match returns distance 0", {
  skip_if_not_installed("stringdist")
  result <- fuzzy_match_names("Anderlecht", "NIS_COMMUNE_2019", master_data,
                               max_dist = 0.1, language = "fr")
  expect_equal(nrow(result), 1L)
  expect_equal(result$distance, 0)
  expect_true(result$is_confident)
})

# ── Test F4: résultat même pour faute d'orthographe ──────────────────────────
test_that("fuzzy_match_names matches misspelled names below threshold", {
  skip_if_not_installed("stringdist")
  result <- fuzzy_match_names(c("Bruxeles", "Antwerpn"), "NIS_COMMUNE_2019", master_data,
                               max_dist = 0.3, language = "both")
  expect_equal(nrow(result), 2L)
})

# ── Test F5: identify_from_names retourne une ligne par input ─────────────────
test_that("identify_from_names returns one best match per input name", {
  skip_if_not_installed("stringdist")
  result <- identify_from_names(c("Bruxelles", "Gent"), master_data, max_dist = 0.1)
  expect_equal(nrow(result), 2L)
  expect_true("classification" %in% names(result))
})

# ── Test F6: résultat NIS_COMMUNE_2025 ───────────────────────────────────────
test_that("fuzzy_match_names works for NIS_COMMUNE_2025", {
  skip_if_not_installed("stringdist")
  result <- fuzzy_match_names(c("Gent", "Hasselt"), "NIS_COMMUNE_2025", master_data,
                               max_dist = 0.1, language = "nl")
  expect_equal(nrow(result), 2L)
  expect_true(all(result$is_confident))
})

# ── Test F7: warn rcl_unmatched_codes quand aucune classification trouvée ─────
test_that("identify_from_names warns rcl_unmatched_codes when no match in any classification", {
  skip_if_not_installed("stringdist")
  # Use a completely nonsensical name with tight threshold
  expect_warning(
    identify_from_names("xzqy999", master_data,
                        possible_classifications = "NIS_COMMUNE_2019",
                        max_dist = 0.01),
    class = "rcl_unmatched_codes"
  )
})
