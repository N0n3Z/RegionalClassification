# ==============================================================================
# 08_load_prebuilt.R - Load pre-built master table from bundled RDS files
# ==============================================================================

#' Resolve the directory containing the pre-built RDS files
#'
#' Tries system.file() first (installed package or devtools::load_all()),
#' then falls back to inst/extdata/ relative to the project root for the
#' source("main.R") workflow.
#'
#' @return Character path to the extdata directory
#' @noRd
.get_prebuilt_dir <- function() {
  pkg_dir <- tryCatch(
    system.file("extdata", package = "nbbbenuts", mustWork = FALSE),
    error = function(e) ""
  )
  if (nchar(pkg_dir) > 0 && dir.exists(pkg_dir)) return(pkg_dir)

  local_dir <- if (requireNamespace("here", quietly = TRUE)) {
    here::here("inst", "extdata")
  } else {
    file.path("inst", "extdata")
  }
  local_dir
}

#' Load the pre-built master table from bundled RDS files
#'
#' This is the default and fast way to initialise the package.
#' No raw source files are required.  All R types (integer, character, etc.)
#' are preserved exactly as serialised by save_master_tables().
#'
#' @param dir  Path to the directory containing the RDS files.
#'             Defaults to the package extdata directory.
#' @return Named list identical in structure to the output of build_master_table().
#'         The four intermediate hierarchy lists are set to NULL as they are not
#'         needed at runtime.
#' @examples
#' \donttest{
#'   master_data <- load_master_data()
#'   # master_data now contains all lookup tables, ready for convert_codes() etc.
#' }
#' @export
load_master_data <- function(dir = .get_prebuilt_dir()) {

  if (!dir.exists(dir)) {
    abort(
      sprintf(paste0("Pre-built data directory not found: '%s'.\n",
                     "Run rebuild_master_data() once to generate it from the raw source files."),
              dir),
      class = "rcl_data_missing", dir = dir
    )
  }

  result <- vector("list", length(MASTER_FLAT_TABLES))
  names(result) <- MASTER_FLAT_TABLES

  for (nm in MASTER_FLAT_TABLES) {
    path <- file.path(dir, paste0(nm, ".rds"))
    if (!file.exists(path)) {
      message(sprintf("  [load_master_data] '%s.rds' not found -- setting to NULL", nm))
      result[[nm]] <- NULL
      next
    }
    result[[nm]] <- readRDS(path)
  }

  # Hierarchy lists -- not persisted, not needed at runtime
  result$nis_hierarchy_2019          <- NULL
  result$nis_hierarchy_2025          <- NULL
  result$nuts_hierarchy_2021         <- NULL
  result$nuts_arrondissement_mapping <- NULL

  if (!is.null(result$communes)) {
    message(sprintf(
      "Master data loaded from '%s': %d communes NIS 2019, %d NIS 2025, %d NIS BEFORE_2019",
      dir,
      nrow(result$communes[nis_version == VER_2019]),
      nrow(result$communes[nis_version == VER_2025]),
      nrow(result$communes[nis_version == VER_BEFORE_2019])
    ))
  } else {
    message(sprintf("Master data loaded from '%s' (some tables missing -- run rebuild_master_data())", dir))
  }

  return(result)
}

#' Rebuild the master table from raw source files and save as RDS
#'
#' Call this only when the source files change. Requires all raw XLSX/XLS/CSV
#' files in data/raw/ to be present, as well as the readxl package.
#'
#' @param raw_dir   Path to the raw data directory. Defaults to data/raw/.
#' @param out_dir   Path where RDS files will be written.
#'                  Defaults to inst/extdata/ (accessible after package install).
#' @return master_data list (same as load_master_data() output), invisibly
#' @examples
#' \dontrun{
#'   # Only needed when raw source files in data/raw/ change
#'   master_data <- rebuild_master_data()
#' }
#' @export
rebuild_master_data <- function(raw_dir = get_raw_data_path(),
                                out_dir = get_processed_data_path()) {

  if (!requireNamespace("readxl", quietly = TRUE)) {
    abort(
      "Package 'readxl' is required to rebuild from raw files. Install it with: install.packages('readxl')",
      class = "rcl_missing_package"
    )
  }

  message("=== Rebuilding master data from raw files ===")
  raw_data    <- load_all_raw_data(raw_dir)
  master_data <- build_master_table(raw_data)
  save_master_tables(master_data, out_dir)
  message(sprintf("=== Rebuild complete. Files saved to '%s' ===", out_dir))
  return(invisible(master_data))
}
