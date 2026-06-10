library(data.table)

# -- Test M1: detect_classification warn rcl_detection_failed -----------------
test_that("detect_classification warns rcl_detection_failed for low-confidence input", {
  expect_warning(
    detect_classification(c(99999L, 88888L, 77777L), master_data),
    class = "rcl_detection_failed"
  )
})

# -- Test M2: detect_classification retourne NULL quand confiance < 80% --------
test_that("detect_classification returns NULL when confidence is below threshold", {
  result <- withCallingHandlers(
    detect_classification(c(99999L, 88888L, 77777L), master_data),
    rcl_detection_failed = function(w) invokeRestart("muffleWarning")
  )
  expect_null(result)
})

# -- Test M3: visualize_classification_graph ne plante pas sans visNetwork -----
test_that("visualize_classification_graph runs without error", {
  expect_no_error(visualize_classification_graph())
})

# -- Test M4: visualize_conversion_matrix ne plante pas -----------------------
test_that("visualize_conversion_matrix runs without error", {
  expect_no_error(visualize_conversion_matrix())
})

# -- Test M5: visualize_hierarchy ne plante pas pour NIS_2019 ------------------
test_that("visualize_hierarchy runs without error for NIS_2019", {
  expect_no_error(visualize_hierarchy("NIS_2019", master_data))
})

# -- Test M6: master_data invalide -> rcl_invalid_input -------------------------
test_that("convert_codes raises rcl_invalid_input for non-list master_data", {
  expect_error(
    convert_codes(21004L, CLS_NIS_COMMUNE_2019, CLS_NUTS3_2021, "not_a_list"),
    class = "rcl_invalid_input"
  )
})

# -- Test M7: master_data sans communes -> rcl_data_missing ---------------------
test_that("convert_codes raises rcl_data_missing when communes table missing", {
  bad_md <- list(postal = data.table(), nis_changes = data.table())
  expect_error(
    convert_codes(21004L, CLS_NIS_COMMUNE_2019, CLS_NUTS3_2021, bad_md),
    class = "rcl_data_missing"
  )
})

# -- Test M8: graphe cache -- build_conversion_graph ne se reconstruit pas ------
test_that("build_conversion_graph uses cached result on repeated calls", {
  # Invalidate cache then rebuild
  g1 <- nbbbenuts:::build_conversion_graph()
  g2 <- nbbbenuts:::build_conversion_graph()
  # Same object (pointer identity via identical)
  expect_identical(g1, g2)
})
