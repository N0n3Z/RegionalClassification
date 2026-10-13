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
#' @return Named list with the two tables of the long model:
#'   \describe{
#'     \item{entities}{One row per code of each classification:
#'       \code{classification}, \code{code}, \code{label_fr}, \code{label_nl}.}
#'     \item{crosswalks}{One row per code link of each single-hop conversion:
#'       \code{classification_from}, \code{classification_to},
#'       \code{code_from}, \code{code_to}, \code{relation}, \code{nature}.}
#'   }
#'   The wide tables of nbbbenuts 2.x (\code{municipalities}, \code{postal},
#'   \code{nis_changes}) are no longer part of the master data; rebuild them
#'   with [wide_view()]. Wide-table files left in an older snapshot directory
#'   are ignored. A snapshot written before nbbbenuts 2.0.0
#'   (\code{classification_id}, \code{from_id} columns) is migrated on load
#'   with a warning of class \code{rcl_legacy_schema}.
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
      result[nm] <- list(NULL)
      next
    }
    result[[nm]] <- readRDS(path)
  }

  result <- .migrate_schema_v1(result)

  if (!is.null(result$entities)) {
    n_mun <- result$entities[, .N, by = classification]
    n_of  <- function(v) n_mun[classification == sprintf("NIS_MUNICIPALITY_%s", v), sum(N)]
    message(sprintf(
      "Master data loaded from '%s': %d communes NIS 2019, %d NIS 2025, %d NIS BEFORE_2019",
      dir, n_of(VER_2019), n_of(VER_2025), n_of(VER_BEFORE_2019)
    ))
  } else {
    message(sprintf("Master data loaded from '%s' (some tables missing -- run rebuild_master_data())", dir))
  }

  return(result)
}

#' Migrate a schema v1 master_data object to schema v2 (internal)
#'
#' Snapshots written before nbbbenuts 2.0.0 use the v1 table and column names
#' (\code{communes}, \code{cd_commune}, \code{nis_version}, \code{from_id}, ...).
#' This renames them via \code{SCHEMA_V1_TO_V2} / \code{SCHEMA_V1_TABLE_RENAMES},
#' drops \code{SCHEMA_V1_DROPPED_COLS}, derives \code{nis_changes$version_to}, and
#' signals one warning of class \code{rcl_legacy_schema}. A v2 object is returned
#' unchanged (no warning). The input tables are copied, never modified in place.
#'
#' @param md Named list of master tables (as read by \code{load_master_data()}).
#' @return The same list, in schema v2.
#' @noRd
.migrate_schema_v1 <- function(md) {
  is_v1_table <- any(names(SCHEMA_V1_TABLE_RENAMES) %in% names(Filter(Negate(is.null), md)))
  is_v1_col   <- any(vapply(names(SCHEMA_V1_TO_V2), function(tbl) {
    dt <- md[[tbl]]
    if (is.null(dt) && tbl %in% SCHEMA_V1_TABLE_RENAMES)
      dt <- md[[names(SCHEMA_V1_TABLE_RENAMES)[match(tbl, SCHEMA_V1_TABLE_RENAMES)]]]
    !is.null(dt) && any(names(SCHEMA_V1_TO_V2[[tbl]]) %in% names(dt))
  }, logical(1L)))
  if (!is_v1_table && !is_v1_col) return(md)

  for (old in names(SCHEMA_V1_TABLE_RENAMES)) {
    new <- SCHEMA_V1_TABLE_RENAMES[[old]]
    if (!is.null(md[[old]]) && is.null(md[[new]])) md[[new]] <- md[[old]]
    md[old] <- NULL
  }

  for (tbl in names(SCHEMA_V1_TO_V2)) {
    if (is.null(md[[tbl]])) next
    dt <- copy(md[[tbl]])
    .rename_to_schema_v2(dt, tbl)
    drop <- intersect(SCHEMA_V1_DROPPED_COLS[[tbl]], names(dt))
    if (length(drop) > 0L) dt[, (drop) := NULL]
    md[[tbl]] <- dt
  }

  nc <- md$nis_changes
  if (!is.null(nc) && !"version_to" %in% names(nc))
    nc[, version_to := unname(NIS_CHANGE_VERSION_TO[version_from])]

  warn(
    paste0("master_data uses the schema v1 table/column names (nbbbenuts < 2.0.0); ",
           "migrated to schema v2 in memory. Re-save it with save_master_tables() ",
           "to silence this warning."),
    class = "rcl_legacy_schema"
  )
  md
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
  return(invisible(master_data[MASTER_FLAT_TABLES]))
}
