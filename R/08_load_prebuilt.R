# ==============================================================================
# 08_load_prebuilt.R - Load pre-built master table from bundled CSV files
# ==============================================================================

library(data.table)

# Directory where the pre-built CSV files live (relative to project root)
.PREBUILT_DIR <- file.path("data", "processed")

# Names of all flat tables serialised as CSV
.PREBUILT_TABLES <- c(
  "master_nis2019_nuts2021",
  "communes_nis2019",
  "communes_nis2025",
  "postal_to_nis2019",
  "postal_to_nis2025",
  "nis_changes",
  "nuts3_ref_2021",
  "comm2025_to_nuts2027",
  "nuts3_ref_2027",
  "nuts_to_internal",
  "communes_nis_before2019",
  "master_before2019",
  "nis_change_before2019"
)

# Integer columns per table — needed because fread() reads everything as the
# most-permissive type and integer codes must stay integers for correct joins.
.INTEGER_COLS <- list(
  master_nis2019_nuts2021  = c("cd_commune", "cd_arr", "cd_arr_2digit",
                                "cd_province", "cd_region"),
  communes_nis2019         = c("cd_commune", "cd_arr", "cd_arr_2digit",
                                "cd_province", "cd_region"),
  communes_nis2025         = c("cd_commune", "cd_arr", "cd_arr_2digit",
                                "cd_province", "cd_region"),
  communes_nis_before2019  = c("cd_commune", "cd_arr", "cd_arr_2digit",
                                "cd_province", "cd_region"),
  master_before2019        = c("cd_commune", "cd_arr", "cd_arr_2digit",
                                "cd_province", "cd_region"),
  postal_to_nis2019        = c("cd_postal", "cd_commune_nis"),
  postal_to_nis2025        = c("cd_postal", "cd_commune_nis"),
  nis_changes              = c("cd_refnis_old", "cd_refnis_new"),
  nuts3_ref_2021           = c("cd_refnis_arr"),
  comm2025_to_nuts2027     = c("cd_commune_2025"),
  nis_change_before2019    = c("cd_refnis_old", "cd_refnis_new")
)

#' Load the pre-built master table from bundled CSV files
#'
#' This is the default and fast way to initialise the package.
#' No raw source files are required.
#'
#' @param dir  Path to the directory containing the CSV files.
#'             Defaults to \code{data/processed/} relative to the project root.
#' @return Named list identical in structure to the output of build_master_table().
#'         The four intermediate hierarchy lists (nis_hierarchy_*, nuts_hierarchy_*,
#'         nuts_arrondissement_mapping) are set to NULL as they are not needed at
#'         runtime.
load_master_data <- function(dir = .PREBUILT_DIR) {

  if (!dir.exists(dir)) {
    stop(sprintf(
      paste0("Pre-built data directory not found: '%s'.\n",
             "Run rebuild_master_data() once to generate it from the raw source files."),
      dir
    ))
  }

  result <- vector("list", length(.PREBUILT_TABLES))
  names(result) <- .PREBUILT_TABLES

  for (nm in .PREBUILT_TABLES) {
    path <- file.path(dir, paste0(nm, ".csv"))
    if (!file.exists(path)) {
      message(sprintf("  [load_master_data] '%s.csv' not found — setting to NULL", nm))
      result[[nm]] <- NULL
      next
    }
    dt <- fread(path, showProgress = FALSE)
    int_cols <- intersect(.INTEGER_COLS[[nm]], names(dt))
    for (col in int_cols) {
      set(dt, j = col, value = as.integer(dt[[col]]))
    }
    result[[nm]] <- dt
  }

  # Hierarchy lists — not persisted, not needed at runtime
  result$nis_hierarchy_2019         <- NULL
  result$nis_hierarchy_2025         <- NULL
  result$nuts_hierarchy_2021        <- NULL
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

#' Rebuild the master table from raw source files and save as CSV
#'
#' Call this only when the source files change. Requires all raw XLSX/XLS/CSV
#' files in data/raw/ to be present.
#'
#' @param raw_dir   Path to the raw data directory. Defaults to data/raw/.
#' @param out_dir   Path where CSV files will be written. Defaults to data/processed/.
#' @return master_data list (same as load_master_data() output)
rebuild_master_data <- function(raw_dir = get_raw_data_path(),
                                out_dir = .PREBUILT_DIR) {

  message("=== Rebuilding master data from raw files ===")
  raw_data    <- load_all_raw_data(raw_dir)
  master_data <- build_master_table(raw_data)
  save_master_tables(master_data, out_dir)
  message(sprintf("=== Rebuild complete. Files saved to '%s' ===", out_dir))
  return(invisible(master_data))
}
