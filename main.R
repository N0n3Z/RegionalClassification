# ==============================================================================
# main.R - Entry point for the nbbbenuts package
# ==============================================================================
# By default, master_data is loaded instantly from pre-built CSV files in
# data/processed/.  The raw XLSX/XLS source files are NOT required for normal
# use.
#
# To rebuild the pre-built snapshot from the raw source files:
#   source("main.R")
#   master_data <- rebuild_master_data()   # requires data/raw/ files
# ==============================================================================

# --- Load dependencies ---
required_packages <- c("data.table", "here")
optional_packages <- c("readxl", "stringdist", "visNetwork", "ggplot2")

for (pkg in required_packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    stop(sprintf("Required package '%s' is not installed. Please run: install.packages('%s')",
                 pkg, pkg))
  }
  library(pkg, character.only = TRUE)
}

for (pkg in optional_packages) {
  if (requireNamespace(pkg, quietly = TRUE)) {
    library(pkg, character.only = TRUE)
  } else {
    if (pkg %in% c("readxl", "stringdist")) {
      message(sprintf(
        "Optional package '%s' not installed. Needed only for rebuild_master_data() / fuzzy matching.",
        pkg
      ))
    }
  }
}

# --- Source all modules ---
source(file.path("R", "00_config.R"))
source(file.path("R", "01_load_data.R"))
source(file.path("R", "02_build_master_table.R"))
source(file.path("R", "03_convert.R"))
source(file.path("R", "04_fuzzy_match.R"))
source(file.path("R", "05_conversion_check.R"))
source(file.path("R", "06_visualize.R"))
source(file.path("R", "07_dataset_convert.R"))
source(file.path("R", "08_load_prebuilt.R"))

# --- Load master data (fast path: pre-built CSV files) ---
message("=== nbbbenuts Package ===")
master_data <- load_master_data()

message("\n=== Package ready! ===")
message("Available functions:")
message("  convert_codes(codes, from, to, master_data)")
message("  check_conversion_path(from, to)")
message("  print_conversion_check(from, to)")
message("  fuzzy_match_names(names, target, master_data)")
message("  identify_from_names(names, master_data)")
message("  list_available_conversions()")
message("  visualize_classification_graph()")
message("  visualize_conversion_matrix()")
message("  visualize_hierarchy(classification, master_data)")
message("  diagnose_classification(dt, code_col, master_data, classification=NULL)")
message("  convert_dataset(dt, code_col, to, master_data, from=NULL)")
message("  split_ambiguous(dt, code_col, value_cols, from, to, master_data, weights=NULL)")
message("  register_split_weights(from, to, weights_dt, variable='population')")
message("  list_split_weights()")
message("")
message("To rebuild master_data from raw source files:")
message("  master_data <- rebuild_master_data()")
message("")
message("Example:")
message('  convert_codes(c(1000, 2000, 4000), "POSTAL", "NUTS3_2021", master_data)')
message('  print_conversion_check("NIS_ARRONDISSEMENT_2019", "NUTS3_2021")')
message('  fuzzy_match_names(c("Bruxeles", "Anvers"), "NIS_COMMUNE_2019", master_data)')
message("")

# --- Run tests if in test mode ---
if (exists("RUN_TESTS") && isTRUE(RUN_TESTS)) {
  source(file.path("tests", "test_conversions.R"))
  test_conversion_paths()
  run_all_tests(master_data)
}
