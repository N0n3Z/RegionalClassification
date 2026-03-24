# ==============================================================================
# tests/test_conversions.R - Sample tests with fictitious data
# ==============================================================================
# Each test creates fictitious data in a specific classification, converts it,
# and validates the result.
# ==============================================================================

library(data.table)

#' Run all sample tests
#'
#' @param master_data Output from build_master_table()
#' @return list of test results
run_all_tests <- function(master_data) {

  cat("\n")
  cat("================================================================\n")
  cat("  RUNNING SAMPLE CONVERSION TESTS\n")
  cat("================================================================\n\n")

  results <- list()
  test_count <- 0
  pass_count <- 0

  # --- Test 1: NIS Commune 2019 ---
  test_count <- test_count + 1
  cat("--- Test 1: NIS Commune 2019 -> NUTS3 2021 ---\n")
  tryCatch({
    sample_data <- data.table(
      commune_code = c(21001L, 11002L, 62003L, 92045L, 63079L),
      commune_name = c("Anderlecht", "Antwerpen", "Ans", "Namur-Floreffe", "Verviers"),
      value = c(100, 200, 150, 80, 120)
    )
    result <- convert_codes(sample_data$commune_code, "NIS_COMMUNE_2019",
                            "NUTS3_2021", master_data)
    cat("  Input codes:", paste(sample_data$commune_code, collapse = ", "), "\n")
    cat("  Output NUTS3:", paste(result$code_to, collapse = ", "), "\n")
    stopifnot(nrow(result) == 5)
    stopifnot(all(!is.na(result$code_to)))
    cat("  PASS\n\n")
    pass_count <- pass_count + 1
    results[["test_1"]] <- list(status = "PASS", result = result)
  }, error = function(e) {
    cat(sprintf("  FAIL: %s\n\n", e$message))
    results[["test_1"]] <<- list(status = "FAIL", error = e$message)
  })

  # --- Test 2: NIS Commune 2025 -> NIS Arrondissement 2025 ---
  test_count <- test_count + 1
  cat("--- Test 2: NIS Commune 2025 -> NIS Arrondissement 2025 ---\n")
  tryCatch({
    # Use some known 2025 commune codes (including fused communes)
    sample_data <- data.table(
      commune_code = c(21001L, 11002L, 44086L, 71071L),
      value = c(50, 75, 120, 90)
    )
    result <- convert_codes(sample_data$commune_code, "NIS_COMMUNE_2025",
                            "NIS_ARRONDISSEMENT_2025", master_data)
    cat("  Input codes:", paste(sample_data$commune_code, collapse = ", "), "\n")
    cat("  Output arr:", paste(result$code_to, collapse = ", "), "\n")
    stopifnot(nrow(result) == 4)
    cat("  PASS\n\n")
    pass_count <- pass_count + 1
    results[["test_2"]] <- list(status = "PASS", result = result)
  }, error = function(e) {
    cat(sprintf("  FAIL: %s\n\n", e$message))
    results[["test_2"]] <<- list(status = "FAIL", error = e$message)
  })

  # --- Test 3: Code Postal -> NIS Commune 2019 ---
  test_count <- test_count + 1
  cat("--- Test 3: Code Postal -> NIS Commune 2019 ---\n")
  tryCatch({
    sample_data <- data.table(
      postal_code = c(1000L, 2000L, 4000L, 5000L, 7000L),
      value = c(300, 250, 180, 90, 210)
    )
    result <- convert_codes(sample_data$postal_code, "POSTAL",
                            "NIS_COMMUNE_2019", master_data)
    cat("  Input postal:", paste(sample_data$postal_code, collapse = ", "), "\n")
    cat("  Output NIS:", paste(result$code_to, collapse = ", "), "\n")
    stopifnot(nrow(result) == 5)
    cat("  PASS\n\n")
    pass_count <- pass_count + 1
    results[["test_3"]] <- list(status = "PASS", result = result)
  }, error = function(e) {
    cat(sprintf("  FAIL: %s\n\n", e$message))
    results[["test_3"]] <<- list(status = "FAIL", error = e$message)
  })

  # --- Test 4: NIS Arrondissement 2025 -> NIS Province 2025 ---
  test_count <- test_count + 1
  cat("--- Test 4: NIS Arrondissement 2025 -> NIS Province 2025 ---\n")
  tryCatch({
    sample_data <- data.table(
      arr_code = c(11000L, 21000L, 51000L, 62000L, 91000L),
      value = c(400, 350, 200, 175, 125)
    )
    result <- convert_codes(sample_data$arr_code, "NIS_ARRONDISSEMENT_2025",
                            "NIS_PROVINCE_2025", master_data)
    cat("  Input arr:", paste(sample_data$arr_code, collapse = ", "), "\n")
    cat("  Output province:", paste(result$code_to, collapse = ", "), "\n")
    stopifnot(nrow(result) == 5)
    cat("  PASS\n\n")
    pass_count <- pass_count + 1
    results[["test_4"]] <- list(status = "PASS", result = result)
  }, error = function(e) {
    cat(sprintf("  FAIL: %s\n\n", e$message))
    results[["test_4"]] <<- list(status = "FAIL", error = e$message)
  })

  # --- Test 5: NIS Arrondissement 2019 -> NUTS3 2021 (ambiguous - Verviers) ---
  test_count <- test_count + 1
  cat("--- Test 5: NIS Arrondissement 2019 -> NUTS3 2021 (ambiguous!) ---\n")
  tryCatch({
    sample_data <- data.table(
      arr_code = c(11000L, 62000L, 63000L),  # 63000 = Verviers (ambiguous!)
      value = c(500, 300, 150)
    )
    # Should FAIL without allow_ambiguous
    error_caught <- FALSE
    tryCatch({
      convert_codes(sample_data$arr_code, "NIS_ARRONDISSEMENT_2019",
                    "NUTS3_2021", master_data, allow_ambiguous = FALSE)
    }, error = function(e) {
      cat("  Correctly blocked simple conversion (Verviers ambiguity)\n")
      cat(sprintf("  Error message: %s\n", substr(e$message, 1, 120)))
      error_caught <<- TRUE
    })
    stopifnot(error_caught)

    # Should SUCCEED with allow_ambiguous
    result <- convert_codes(sample_data$arr_code, "NIS_ARRONDISSEMENT_2019",
                            "NUTS3_2021", master_data, allow_ambiguous = TRUE)
    cat("  With allow_ambiguous=TRUE:\n")
    cat("  Input arr:", paste(result$code_from, collapse = ", "), "\n")
    cat("  Output NUTS3:", paste(result$code_to, collapse = ", "), "\n")
    # Verviers (63000) should produce 2 rows (BE335, BE336)
    n_verviers <- nrow(result[code_from == 63000L])
    cat(sprintf("  Verviers (63000) produced %d mappings\n", n_verviers))
    stopifnot(n_verviers == 2)
    cat("  PASS\n\n")
    pass_count <- pass_count + 1
    results[["test_5"]] <- list(status = "PASS", result = result)
  }, error = function(e) {
    cat(sprintf("  FAIL: %s\n\n", e$message))
    results[["test_5"]] <<- list(status = "FAIL", error = e$message)
  })

  # --- Test 6: NUTS3 2021 -> Internal Arrondissement ---
  test_count <- test_count + 1
  cat("--- Test 6: NUTS3 2021 -> Internal Arrondissement ---\n")
  tryCatch({
    sample_data <- data.table(
      nuts3_code = c("BE100", "BE211", "BE335", "BE336", "BE351"),
      value = c(1000, 800, 200, 50, 400)
    )
    result <- convert_codes(sample_data$nuts3_code, "NUTS3_2021",
                            "INTERNAL_ARRONDISSEMENT", master_data)
    cat("  Input NUTS3:", paste(sample_data$nuts3_code, collapse = ", "), "\n")
    cat("  Output internal:", paste(result$code_to, collapse = ", "), "\n")
    # BE335 -> 65, BE336 -> 66
    stopifnot(nrow(result) == 5)
    cat("  PASS\n\n")
    pass_count <- pass_count + 1
    results[["test_6"]] <- list(status = "PASS", result = result)
  }, error = function(e) {
    cat(sprintf("  FAIL: %s\n\n", e$message))
    results[["test_6"]] <<- list(status = "FAIL", error = e$message)
  })

  # --- Test 7: Fuzzy match - Postal code names ---
  test_count <- test_count + 1
  cat("--- Test 7: Fuzzy match - Postal code names ---\n")
  tryCatch({
    sample_names <- c("Bruxelles", "Anvers", "Liege", "Namur", "Gand")
    result <- fuzzy_match_names(sample_names, "POSTAL", master_data,
                                max_dist = 0.3, language = "fr")
    cat("  Input names:", paste(sample_names, collapse = ", "), "\n")
    cat("  Matched codes:", paste(result$matched_code, collapse = ", "), "\n")
    cat("  Distances:", paste(round(result$distance, 3), collapse = ", "), "\n")
    stopifnot(nrow(result) >= length(sample_names))
    cat("  PASS\n\n")
    pass_count <- pass_count + 1
    results[["test_7"]] <- list(status = "PASS", result = result)
  }, error = function(e) {
    cat(sprintf("  FAIL: %s\n\n", e$message))
    results[["test_7"]] <<- list(status = "FAIL", error = e$message)
  })

  # --- Test 8: Fuzzy match - NIS Commune 2019 names ---
  test_count <- test_count + 1
  cat("--- Test 8: Fuzzy match - NIS Commune 2019 names ---\n")
  tryCatch({
    # Deliberately misspelled or informal names
    sample_names <- c("Anderlecht", "Bruxeles", "Antwerpn", "Liege", "Vervirs")
    result <- fuzzy_match_names(sample_names, "NIS_COMMUNE_2019", master_data,
                                max_dist = 0.3, language = "both")
    cat("  Input names:", paste(sample_names, collapse = ", "), "\n")
    for (i in seq_len(nrow(result))) {
      cat(sprintf("    '%s' -> '%s' (code: %s, dist: %.3f, lang: %s, confident: %s)\n",
                  result$input_name[i], result$matched_name[i],
                  result$matched_code[i], result$distance[i],
                  result$language[i], result$is_confident[i]))
    }
    stopifnot(nrow(result) >= length(sample_names))
    cat("  PASS\n\n")
    pass_count <- pass_count + 1
    results[["test_8"]] <- list(status = "PASS", result = result)
  }, error = function(e) {
    cat(sprintf("  FAIL: %s\n\n", e$message))
    results[["test_8"]] <<- list(status = "FAIL", error = e$message)
  })

  # --- Test 9: Fuzzy match - NIS Commune 2025 names ---
  test_count <- test_count + 1
  cat("--- Test 9: Fuzzy match - NIS Commune 2025 names ---\n")
  tryCatch({
    sample_names <- c("Anderlecht", "Gent", "Hasselt", "Charleroi")
    result <- fuzzy_match_names(sample_names, "NIS_COMMUNE_2025", master_data,
                                max_dist = 0.3, language = "both")
    cat("  Input names:", paste(sample_names, collapse = ", "), "\n")
    for (i in seq_len(nrow(result))) {
      cat(sprintf("    '%s' -> '%s' (code: %s, dist: %.3f)\n",
                  result$input_name[i], result$matched_name[i],
                  result$matched_code[i], result$distance[i]))
    }
    stopifnot(nrow(result) >= length(sample_names))
    cat("  PASS\n\n")
    pass_count <- pass_count + 1
    results[["test_9"]] <- list(status = "PASS", result = result)
  }, error = function(e) {
    cat(sprintf("  FAIL: %s\n\n", e$message))
    results[["test_9"]] <<- list(status = "FAIL", error = e$message)
  })

  # --- Summary ---
  cat("================================================================\n")
  cat(sprintf("  RESULTS: %d/%d tests passed\n", pass_count, test_count))
  cat("================================================================\n\n")

  return(invisible(results))
}

#' Test the conversion path checker
#'
#' @return invisible(NULL)
test_conversion_paths <- function() {

  cat("\n")
  cat("================================================================\n")
  cat("  TESTING CONVERSION PATH CHECKER\n")
  cat("================================================================\n\n")

  # Simple conversions (should be TRUE)
  simple_tests <- list(
    c("POSTAL", "NIS_COMMUNE_2019"),
    c("NIS_COMMUNE_2019", "NUTS3_2021"),
    c("NIS_COMMUNE_2019", "NIS_ARRONDISSEMENT_2019"),
    c("NUTS3_2021", "INTERNAL_ARRONDISSEMENT"),
    c("POSTAL", "NUTS3_2021")
  )

  for (test in simple_tests) {
    result <- check_conversion_path(test[1], test[2])
    status <- ifelse(result$is_simple, "OK", "UNEXPECTED")
    cat(sprintf("  [%s] %s -> %s: simple=%s\n",
                status, test[1], test[2], result$is_simple))
    if (!is.null(result$path)) {
      cat(sprintf("        Path: %s\n", paste(result$path, collapse = " -> ")))
    }
  }

  cat("\n")

  # Ambiguous conversions (should be FALSE)
  ambig_tests <- list(
    c("NIS_ARRONDISSEMENT_2019", "NUTS3_2021"),
    c("NIS_ARRONDISSEMENT_2019", "INTERNAL_ARRONDISSEMENT"),
    c("NIS_COMMUNE_2019", "NIS_COMMUNE_2025")
  )

  for (test in ambig_tests) {
    result <- check_conversion_path(test[1], test[2])
    status <- ifelse(!result$is_simple, "OK", "UNEXPECTED")
    cat(sprintf("  [%s] %s -> %s: simple=%s\n",
                status, test[1], test[2], result$is_simple))
    if (!result$is_simple && !is.null(result$path)) {
      cat(sprintf("        Reason: %s\n",
                  substr(result$explanation, 1, 150)))
    }
  }

  cat("\n")
  invisible(NULL)
}
