# ==============================================================================
# 08_load_prebuilt.R - Load pre-built master table from bundled RDS files
# ==============================================================================

library(data.table)

# Directory where the pre-built RDS files live (relative to project root)
.PREBUILT_DIR <- file.path("data", "processed")

#' Load the pre-built master table from bundled RDS files
#'
#' This is the default and fast way to initialise the package.
#' No raw source files are required.  All R types (integer, character, etc.)
#' are preserved exactly as serialised by save_master_tables().
#'
#' @param dir  Path to the directory containing the RDS files.
#'             Defaults to \code{data/processed/} relative to the project root.
#' @return Named list identical in structure to the output of build_master_table().
#'         The four intermediate hierarchy lists are set to NULL as they are not
#'         needed at runtime.
load_master_data <- function(dir = .PREBUILT_DIR) {

  if (!dir.exists(dir)) {
    stop(sprintf(
      paste0("Pre-built data directory not found: '%s'.\n",
             "Run rebuild_master_data() once to generate it from the raw source files."),
      dir
    ))
  }

  result <- vector("list", length(MASTER_FLAT_TABLES))
  names(result) <- MASTER_FLAT_TABLES

  for (nm in MASTER_FLAT_TABLES) {
    path <- file.path(dir, paste0(nm, ".rds"))
    if (!file.exists(path)) {
      message(sprintf("  [load_master_data] '%s.rds' not found — setting to NULL", nm))
      result[[nm]] <- NULL
      next
    }
    result[[nm]] <- readRDS(path)
  }

  # Hierarchy lists — not persisted, not needed at runtime
  result$nis_hierarchy_2019          <- NULL
  result$nis_hierarchy_2025          <- NULL
  result$nuts_hierarchy_2021         <- NULL
  result$nuts_arrondissement_mapping <- NULL

  message(sprintf(
    "Master data loaded from '%s': %d communes NIS 2019, %d communes NIS 2025, %d communes NIS BEFORE_2019",
    dir,
    nrow(result$communes_nis2019),
    nrow(result$communes_nis2025),
    nrow(result$communes_nis_before2019)
  ))

  return(result)
}

#' Rebuild the master table from raw source files and save as RDS
#'
#' Call this only when the source files change. Requires all raw XLSX/XLS/CSV
#' files in data/raw/ to be present.
#'
#' @param raw_dir   Path to the raw data directory. Defaults to data/raw/.
#' @param out_dir   Path where RDS files will be written. Defaults to data/processed/.
#' @return master_data list (same as load_master_data() output), invisibly
rebuild_master_data <- function(raw_dir = get_raw_data_path(),
                                out_dir = .PREBUILT_DIR) {

  message("=== Rebuilding master data from raw files ===")
  raw_data    <- load_all_raw_data(raw_dir)
  master_data <- build_master_table(raw_data)
  save_master_tables(master_data, out_dir)
  message(sprintf("=== Rebuild complete. Files saved to '%s' ===", out_dir))
  return(invisible(master_data))
}
