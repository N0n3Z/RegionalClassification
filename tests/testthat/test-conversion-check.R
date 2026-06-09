library(data.table)

# -- Test CC1: chemin simple connu ---------------------------------------------
test_that("check_conversion_path NIS_COMMUNE_2019 -> NUTS3_2021 is simple", {
  r <- check_conversion_path("NIS_COMMUNE_2019", "NUTS3_2021")
  expect_true(r$is_simple)
  expect_true("NIS_COMMUNE_2019" %in% r$path)
  expect_true("NUTS3_2021" %in% r$path)
})

# -- Test CC2: chemin ambigu connu (Verviers) ----------------------------------
test_that("check_conversion_path NIS_ARRONDISSEMENT_2019 -> NUTS3_2021 is NOT simple", {
  r <- check_conversion_path("NIS_ARRONDISSEMENT_2019", "NUTS3_2021")
  expect_false(r$is_simple)
  expect_false(is.null(r$path))
})

# -- Test CC3: identite --------------------------------------------------------
test_that("check_conversion_path returns simple=TRUE for same classification", {
  r <- check_conversion_path("NUTS3_2021", "NUTS3_2021")
  expect_true(r$is_simple)
  expect_equal(r$relations, character(0))
})

# -- Test CC4: identifiant inconnu -> erreur rcl_invalid_classification ---------
test_that("check_conversion_path errors for unrecognised classification", {
  expect_error(
    check_conversion_path("POSTAL", "UNKNOWN_CLASSIFICATION_XYZ"),
    class = "rcl_invalid_classification"
  )
})

# -- Test CC5: get_all_classification_nodes retourne les noeuds attendus -------
test_that("get_all_classification_nodes includes expected nodes", {
  nodes <- get_all_classification_nodes()
  expect_true(is.character(nodes))
  expect_true("NIS_COMMUNE_2019" %in% nodes)
  expect_true("NUTS3_2021"       %in% nodes)
  expect_true("POSTAL"           %in% nodes)
  expect_true("NUTS3_2027"       %in% nodes)
})

# -- Test CC6: get_conversion_matrix dimensions --------------------------------
test_that("get_conversion_matrix returns a square-ish matrix with expected columns", {
  mat <- get_conversion_matrix()
  expect_true(is.data.table(mat))
  expect_true(all(c("from", "to", "is_simple", "relation_chain") %in% names(mat)))
  # Identity entries should be simple
  expect_true(all(mat[from == to, is_simple]))
})

# -- Test CC7: print_conversion_check ne retourne pas d'erreur ----------------
test_that("print_conversion_check prints without error", {
  expect_output(print_conversion_check("NIS_COMMUNE_2019", "NUTS3_2021"))
  expect_output(print_conversion_check("POSTAL", "NUTS3_2027"))
})

# -- Test CC8: identifiant non-canonique -> erreur rcl_invalid_classification --
test_that("check_conversion_path errors for non-canonical identifiers", {
  expect_error(check_conversion_path("NIS_COM_2019", "NUTS3_2021"),
               class = "rcl_invalid_classification")
  expect_error(check_conversion_path("NIS_COMMUNE_2019", "NUTS_2021"),
               class = "rcl_invalid_classification")
})

# -- Test CC9: rcl_ambiguous_conversion class ----------------------------------
test_that("convert_codes raises rcl_ambiguous_conversion with allow_ambiguous=FALSE", {
  expect_error(
    convert_codes(63000L, "NIS_ARRONDISSEMENT_2019", "NUTS3_2021", master_data,
                  allow_ambiguous = FALSE),
    class = "rcl_ambiguous_conversion"
  )
})

# -- Test CC10: rcl_ambiguous_conversion pour paire M:N -----------------------
test_that("convert_codes raises rcl_ambiguous_conversion for M:N pair", {
  # NIS_COMMUNE_2019 -> NIS_COMMUNE_BEFORE_2019 exists in the graph but is M:N (ambiguous)
  expect_error(
    convert_codes(21004L, "NIS_COMMUNE_2019", "NIS_COMMUNE_BEFORE_2019", master_data),
    class = "rcl_ambiguous_conversion"
  )
})

# -- Test CC11b: NIS_COMMUNE_2019 -> 2025 est simple (N:1 forward) -------------
test_that("NIS_COMMUNE_2019 -> NIS_COMMUNE_2025 is simple (N:1)", {
  r <- check_conversion_path("NIS_COMMUNE_2019", "NIS_COMMUNE_2025")
  expect_true(r[["is_simple"]])
  expect_equal(r[["relations"]], "N:1")
})

test_that("NIS_COMMUNE_2019 -> NIS_COMMUNE_2025 converts without allow_ambiguous", {
  # A stable commune (Anderlecht 21001) and a fusion constituent (21013 merged)
  result <- convert_codes(c(21001L, 21004L), "NIS_COMMUNE_2019", "NIS_COMMUNE_2025",
                           master_data)
  expect_true(is.data.table(result))
  expect_equal(nrow(result), 2L)
  expect_true(all(!is.na(result$code_to)))
})

test_that("NIS_COMMUNE_2025 -> NIS_COMMUNE_2019 is ambiguous (1:N reverse)", {
  r <- check_conversion_path("NIS_COMMUNE_2025", "NIS_COMMUNE_2019")
  expect_false(r[["is_simple"]])
  expect_equal(r[["relations"]], "1:N")
  # Raises error without allow_ambiguous
  expect_error(
    convert_codes(21001L, "NIS_COMMUNE_2025", "NIS_COMMUNE_2019", master_data),
    class = "rcl_ambiguous_conversion"
  )
})

# -- Test CC11: rcl_invalid_classification pour identifiant inconnu ------------
test_that("convert_codes raises rcl_invalid_classification for unknown identifier", {
  expect_error(
    convert_codes(1L, "NIS_COMMUNE_2019", "TOTALLY_UNKNOWN", master_data),
    class = "rcl_invalid_classification"
  )
})
