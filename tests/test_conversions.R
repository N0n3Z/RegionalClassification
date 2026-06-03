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

  # --- Test 10: NIS Commune 2019 -> NUTS3 2027 ---
  test_count <- test_count + 1
  cat("--- Test 10: NIS Commune 2019 -> NUTS3 2027 ---\n")
  tryCatch({
    # Antwerpen (11002 -> BE261), Gent (44021 -> BE274), Bruxelles (21004 -> BE100 unchanged)
    sample_data <- data.table(
      commune_code = c(21004L, 11002L, 44021L, 62063L, 63079L),
      commune_name = c("Bruxelles", "Antwerpen", "Gent", "Liege", "Verviers")
    )
    result <- convert_codes(sample_data$commune_code, "NIS_COMMUNE_2019",
                            "NUTS3_2027", master_data)
    cat("  Input codes:", paste(sample_data$commune_code, collapse = ", "), "\n")
    cat("  Output NUTS3 2027:", paste(result$code_to, collapse = ", "), "\n")
    # Bruxelles -> BE100, Antwerpen -> BE261, Gent -> BE274, Liege -> BE332, Verviers -> BE335
    stopifnot(result[code_from == 21004L]$code_to == "BE100")   # unchanged
    stopifnot(result[code_from == 11002L]$code_to == "BE261")   # BE211 -> BE261
    stopifnot(result[code_from == 44021L]$code_to == "BE274")   # BE234 -> BE274
    cat("  PASS\n\n")
    pass_count <- pass_count + 1
    results[["test_10"]] <- list(status = "PASS", result = result)
  }, error = function(e) {
    cat(sprintf("  FAIL: %s\n\n", e$message))
    results[["test_10"]] <<- list(status = "FAIL", error = e$message)
  })

  # --- Test 11: NUTS3 2021 <-> NUTS3 2027 roundtrip ---
  test_count <- test_count + 1
  cat("--- Test 11: NUTS3 2021 -> NUTS3 2027 -> NUTS3 2021 roundtrip ---\n")
  tryCatch({
    nuts3_2021 <- c("BE100", "BE211", "BE223", "BE224", "BE225", "BE231", "BE335")
    result_2027 <- convert_codes(nuts3_2021, "NUTS3_2021", "NUTS3_2027", master_data)
    cat("  NUTS3 2021:", paste(nuts3_2021, collapse = ", "), "\n")
    cat("  NUTS3 2027:", paste(result_2027$code_to, collapse = ", "), "\n")
    # Expected: BE100, BE261, BE226, BE227, BE225, BE271, BE335
    stopifnot(result_2027[code_from == "BE211"]$code_to == "BE261")
    stopifnot(result_2027[code_from == "BE223"]$code_to == "BE226")
    stopifnot(result_2027[code_from == "BE225"]$code_to == "BE225")  # unchanged
    stopifnot(result_2027[code_from == "BE231"]$code_to == "BE271")
    stopifnot(result_2027[code_from == "BE335"]$code_to == "BE335")  # unchanged

    # Reverse
    result_back <- convert_codes(result_2027$code_to, "NUTS3_2027", "NUTS3_2021", master_data)
    cat("  Back to 2021:", paste(result_back$code_to, collapse = ", "), "\n")
    # Compare in original order (merge may reorder rows)
    roundtrip <- result_back$code_to[match(result_2027$code_to, result_back$code_from)]
    stopifnot(all(roundtrip == nuts3_2021))
    cat("  PASS\n\n")
    pass_count <- pass_count + 1
    results[["test_11"]] <- list(status = "PASS", result = result_2027)
  }, error = function(e) {
    cat(sprintf("  FAIL: %s\n\n", e$message))
    results[["test_11"]] <<- list(status = "FAIL", error = e$message)
  })

  # --- Test 12: diagnose_classification() check mode ---
  test_count <- test_count + 1
  cat("--- Test 12: diagnose_classification() - check mode ---\n")
  tryCatch({
    # Full NUTS3_2021 dataset -> COMPLETE
    nuts3_codes <- unique(master_data$communes[nis_version == "2019" & !is.na(cd_nuts3), cd_nuts3])
    nuts3_full <- data.table(
      nuts3 = nuts3_codes,
      val   = seq_along(nuts3_codes)
    )
    r_full <- diagnose_classification(nuts3_full, "nuts3", master_data,
                                       classification = "NUTS3_2021", verbose = FALSE)
    stopifnot(r_full$status == "COMPLETE")
    stopifnot(r_full$classification_type == "NUTS3")
    stopifnot(r_full$version == "2021")
    stopifnot(r_full$n_missing == 0L)
    cat("  Full NUTS3_2021: COMPLETE, type=NUTS3, version=2021\n")

    # Partial dataset -> INCOMPLETE, missing codes detected
    nuts3_partial <- data.table(nuts3 = c("BE100", "BE211", "BE332"), val = 1:3)
    r_part <- diagnose_classification(nuts3_partial, "nuts3", master_data,
                                       classification = "NUTS3_2021", verbose = FALSE)
    stopifnot(r_part$status == "INCOMPLETE")
    stopifnot(r_part$n_missing == 44L - 3L)
    stopifnot("BE211" %in% r_part$missing_codes$code == FALSE)  # BE211 IS in dataset
    stopifnot(r_part$n_in_dataset == 3L)
    cat(sprintf("  Partial (3/44): INCOMPLETE, %d missing codes\n", r_part$n_missing))

    # Dataset with unknown code
    nuts3_unk <- data.table(nuts3 = c("BE100", "BE999"), val = 1:2)
    r_unk <- diagnose_classification(nuts3_unk, "nuts3", master_data,
                                      classification = "NUTS3_2021", verbose = FALSE)
    stopifnot(r_unk$n_unknown == 1L)
    stopifnot("BE999" %in% r_unk$unknown_codes$code)
    cat("  Unknown code BE999 correctly detected\n")

    cat("  PASS\n\n")
    pass_count <- pass_count + 1
    results[["test_12"]] <- list(status = "PASS")
  }, error = function(e) {
    cat(sprintf("  FAIL: %s\n\n", e$message))
    results[["test_12"]] <<- list(status = "FAIL", error = e$message)
  })

  # --- Test 13: diagnose_classification() detect mode + split_ambiguous() ---
  test_count <- test_count + 1
  cat("--- Test 13: detect mode + split_ambiguous() ---\n")
  tryCatch({
    # Detect mode on NIS_COMMUNE_2019 data
    comm_dt <- data.table(code = master_data$communes[nis_version == "2019", cd_commune])
    r_det <- diagnose_classification(comm_dt, "code", master_data, verbose = FALSE)
    stopifnot(r_det$mode == "detect")
    stopifnot(r_det$recommendation == "NIS_COMMUNE_2019")
    stopifnot(r_det$classification_type == "NIS_COMMUNE")
    stopifnot(r_det$version == "2019")
    cat(sprintf("  Auto-detected: %s (v%s)\n",
                r_det$classification_type, r_det$version))

    # split_ambiguous: Verviers 63000 -> NUTS3_2021 with additive weights
    arr_data <- data.table(
      arr_code   = c(11000L, 62000L, 63000L),
      total_wage = c(5e9, 3e9, 1e9),
      avg_salary = c(2900, 2700, 2400)
    )
    wts <- data.table(
      code_from = c(63000L, 63000L),
      code_to   = c("BE335", "BE336"),
      weight    = c(0.857, 0.143)
    )
    r_split <- split_ambiguous(arr_data, "arr_code",
                               value_cols  = "total_wage",
                               from        = "NIS_ARRONDISSEMENT_2019",
                               to          = "NUTS3_2021",
                               master_data = master_data,
                               weights     = wts,
                               value_type  = "additive",
                               verbose     = FALSE)
    stopifnot(nrow(r_split) == 4L)                          # 63000 split into 2
    stopifnot(abs(sum(r_split$total_wage) - 9e9) < 1)       # totals preserved
    verviers_rows <- r_split[cd_nuts3_2021 %in% c("BE335", "BE336")]
    stopifnot(nrow(verviers_rows) == 2L)
    stopifnot(abs(verviers_rows[cd_nuts3_2021 == "BE335", total_wage] - 857e6) < 1e3)
    cat("  split_ambiguous: 3 rows -> 4, total preserved, BE335=857M, BE336=143M\n")

    cat("  PASS\n\n")
    pass_count <- pass_count + 1
    results[["test_13"]] <- list(status = "PASS")
  }, error = function(e) {
    cat(sprintf("  FAIL: %s\n\n", e$message))
    results[["test_13"]] <<- list(status = "FAIL", error = e$message)
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
