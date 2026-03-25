# ==============================================================================
# 01_load_data.R - Load and parse all raw input data files
# ==============================================================================

library(data.table)
library(readxl)

#' Load all raw data files and return a named list of data.tables
#'
#' @param data_dir Path to the raw data directory
#' @param file_mapping The FILE_MAPPING configuration from 00_config.R
#' @return Named list of data.tables
load_all_raw_data <- function(data_dir = get_raw_data_path(),
                              file_mapping = FILE_MAPPING) {

  raw_data <- list()

  for (name in names(file_mapping)) {
    fm <- file_mapping[[name]]
    filepath <- file.path(data_dir, fm$filename)

    if (!file.exists(filepath)) {
      warning(sprintf("File not found: %s (skipping %s)", filepath, name))
      next
    }

    message(sprintf("Loading %s from %s ...", name, fm$filename))
    dt <- load_single_file(filepath, sheet = fm$sheet, filter_spec = fm$filter)
    raw_data[[name]] <- dt
    message(sprintf("  -> %d rows, %d columns", nrow(dt), ncol(dt)))
  }

  return(raw_data)
}

#' Load a single data file (xlsx, xls, or csv)
#'
#' @param filepath Full path to file
#' @param sheet Sheet name for Excel files (NULL for default)
#' @param filter_spec List with 'column' and 'value' for filtering, or NULL
#' @return data.table
load_single_file <- function(filepath, sheet = NULL, filter_spec = NULL) {

  ext <- tolower(tools::file_ext(filepath))

  dt <- switch(ext,
    "xlsx" = {
      if (is.null(sheet)) {
        as.data.table(read_excel(filepath))
      } else {
        as.data.table(read_excel(filepath, sheet = sheet))
      }
    },
    "xls" = {
      if (is.null(sheet)) {
        as.data.table(read_excel(filepath))
      } else {
        as.data.table(read_excel(filepath, sheet = sheet))
      }
    },
    "csv" = {
      fread(filepath)
    },
    stop(sprintf("Unsupported file extension: %s", ext))
  )

  # Apply filter if specified
  if (!is.null(filter_spec)) {
    col <- filter_spec$column
    val <- filter_spec$value
    if (col %in% names(dt)) {
      dt <- dt[get(col) == val]
      message(sprintf("  -> Filtered on %s == %s: %d rows remaining", col, val, nrow(dt)))
    } else {
      warning(sprintf("Filter column '%s' not found in data", col))
    }
  }

  return(dt)
}

#' Parse REFNIS file into structured hierarchy
#'
#' Extracts communes, arrondissements, provinces, and regions from
#' the REFNIS reference table based on code patterns.
#'
#' @param refnis_dt data.table from REFNIS file
#' @param code_col Name of the code column
#' @param name_fr_col Name of the French name column
#' @param name_nl_col Name of the Dutch name column
#' @return list of data.tables: communes, arrondissements, provinces, regions
parse_refnis_hierarchy <- function(refnis_dt,
                                   code_col = "Code INS",
                                   name_fr_col = "Entit\u00e9s administratives",
                                   name_nl_col = "Administratieve eenheden") {

  dt <- copy(refnis_dt)

  # Standardize column names
  setnames(dt, code_col, "cd_refnis", skip_absent = TRUE)
  setnames(dt, name_fr_col, "tx_descr_fr", skip_absent = TRUE)
  setnames(dt, name_nl_col, "tx_descr_nl", skip_absent = TRUE)

  # Ensure numeric code
  dt[, cd_refnis := as.integer(cd_refnis)]

  # Classify by code pattern:
  # 1000 = national
  # x000 (4-digit, ends in 000) = region
  # x0000 (5-digit, ends in 0000) = province
  # xy000 (5-digit, ends in 000 but not 0000) = arrondissement
  # xyzzz (5-digit, doesn't end in 000) = commune
  dt[, level := fcase(
    cd_refnis == 1000L, "pays",
    cd_refnis < 10000L & cd_refnis %% 1000L == 0L, "region",
    cd_refnis >= 10000L & cd_refnis %% 10000L == 0L, "province",
    cd_refnis >= 10000L & cd_refnis %% 1000L == 0L, "arrondissement",
    cd_refnis >= 10000L & cd_refnis %% 1000L != 0L, "commune",
    default = "unknown"
  )]

  # Derive parent codes
  dt[level == "commune", cd_arr := (cd_refnis %/% 1000L) * 1000L]

  # Build result
  result <- list(
    communes = dt[level == "commune",
                  .(cd_refnis, tx_descr_fr, tx_descr_nl, cd_arr)],
    arrondissements = dt[level == "arrondissement",
                         .(cd_refnis, tx_descr_fr, tx_descr_nl)],
    provinces = dt[level == "province",
                   .(cd_refnis, tx_descr_fr, tx_descr_nl)],
    regions = dt[level == "region",
                 .(cd_refnis, tx_descr_fr, tx_descr_nl)],
    pays = dt[level == "pays",
              .(cd_refnis, tx_descr_fr, tx_descr_nl)],
    all = dt
  )

  # Add province to arrondissements by matching against province codes
  provinces <- result$provinces[, .(cd_prov = cd_refnis, tx_prov_fr = tx_descr_fr)]
  arr <- result$arrondissements
  arr[, cd_prov_candidate := (cd_refnis %/% 10000L) * 10000L]

  # Special case: Brussels (21000) has no province 20000 per se
  # We need to find the actual province from the hierarchy
  arr <- merge(arr, provinces, by.x = "cd_prov_candidate", by.y = "cd_prov",
               all.x = TRUE)
  setnames(arr, "tx_prov_fr", "tx_province_fr")

  # For arrondissements without matching province (Brussels),
  # derive region directly
  result$arrondissements <- arr

  # Add region to provinces
  provs <- result$provinces
  provs[, cd_region := fcase(
    cd_refnis %/% 10000L == 1L, 4000L,  # Brussels (province 10000 doesn't exist)
    cd_refnis %/% 10000L == 2L, 2000L,  # Flanders: 20000, 30000, 40000, 70000
    cd_refnis %/% 10000L == 3L, 2000L,
    cd_refnis %/% 10000L == 4L, 2000L,
    cd_refnis %/% 10000L == 7L, 2000L,
    cd_refnis %/% 10000L == 5L, 3000L,  # Wallonia: 50000, 60000, 80000, 90000
    cd_refnis %/% 10000L == 6L, 3000L,
    cd_refnis %/% 10000L == 8L, 3000L,
    cd_refnis %/% 10000L == 9L, 3000L,
    default = NA_integer_
  )]
  result$provinces <- provs

  return(result)
}

#' Parse the NUTS-NIS conversion file
#'
#' @param conv_dt data.table from CONVERSION_NIS2019_NUTS2021.xlsx
#' @return list with NUTS hierarchy and commune-level mapping
parse_nuts_nis_conversion <- function(conv_dt) {

  dt <- copy(conv_dt)

  # For commune-level rows (CD_LVL == 4), keep only currently valid entries.
  # Some communes have multiple rows with different validity periods (e.g. Limburg
  # communes had NUTS3 codes BE221/BE222 until 2019-01-01, then BE224/BE225).
  # Keeping all rows would introduce duplicates in the master table.
  dt_comm <- dt[CD_LVL == 4 & DT_VLDT_STOP == max(dt[CD_LVL == 4, DT_VLDT_STOP])]

  # Split by level
  nuts_hierarchy <- list(
    regions     = dt[CD_LVL == 1, .(cd_nuts = CD_LAU, cd_refnis = CD_MUNTY_REFNIS,
                                     tx_descr_fr = TX_DESCR_FR, tx_descr_nl = TX_DESCR_NL)],
    provinces   = dt[CD_LVL == 2, .(cd_nuts = CD_LAU, cd_refnis = CD_MUNTY_REFNIS,
                                     tx_descr_fr = TX_DESCR_FR, tx_descr_nl = TX_DESCR_NL,
                                     cd_nuts_parent = CD_LVL_SUP)],
    arrondissements = dt[CD_LVL == 3, .(cd_nuts = CD_LAU, cd_refnis = CD_MUNTY_REFNIS,
                                         tx_descr_fr = TX_DESCR_FR, tx_descr_nl = TX_DESCR_NL,
                                         cd_nuts_parent = CD_LVL_SUP)],
    communes    = dt_comm[, .(cd_nuts_lau = CD_LAU, cd_refnis = CD_MUNTY_REFNIS,
                               tx_descr_fr = TX_DESCR_FR, tx_descr_nl = TX_DESCR_NL,
                               cd_nuts3 = CD_LVL_SUP)]
  )

  # Ensure cd_refnis is integer in communes
  nuts_hierarchy$communes[, cd_refnis := as.integer(cd_refnis)]

  return(nuts_hierarchy)
}

#' Parse the NUTS-Arrondissement internal mapping
#'
#' @param nuts_arr_dt data.table from NUTS_ARRONDISSEMENT.csv
#' @return list of data.tables by NUTS version year
parse_nuts_arrondissement <- function(nuts_arr_dt) {

  dt <- copy(nuts_arr_dt)

  # Filter to ARROND rows only
  dt_arrond <- dt[C_OVER_CLIST_ARCA == "ARROND"]

  # Split by year
  years <- unique(dt_arrond$Y_BASE_CLIST_ARCA)
  result <- list()

  for (y in years) {
    sub <- dt_arrond[Y_BASE_CLIST_ARCA == y,
                     .(cd_nuts3 = C_BASE_CODE_ARCA,
                       cd_arr_internal = C_OVER_CODE_ARCA)]
    # Determine NUTS version label from year
    nuts_version <- as.character(y)
    result[[nuts_version]] <- sub
  }

  # Also extract NUTS hierarchy from this file
  for (y in years) {
    nuts_version <- as.character(y)
    hier <- dt[Y_BASE_CLIST_ARCA == y & C_OVER_CLIST_ARCA %in% c("NUTS0", "NUTS1", "NUTS2"),
               .(cd_nuts3 = C_BASE_CODE_ARCA,
                 nuts_level = C_OVER_CLIST_ARCA,
                 cd_nuts_parent = C_OVER_CODE_ARCA)]
    result[[paste0(nuts_version, "_hierarchy")]] <- hier
  }

  return(result)
}

#' Parse NIS 2025 -> NUTS 2027 conversion file
#'
#' Called only when CONVERSION_NIS2025_NUTS2027.xlsx is present in data/raw/.
#' Column names are configured in FILE_MAPPING$CONVERSION_NIS2025_NUTS2027.
#'
#' @param conv_dt data.table from CONVERSION_NIS2025_NUTS2027.xlsx
#' @param col_nis  Name of the NIS 2025 commune code column
#' @param col_nuts3 Name of the NUTS3 2027 code column
#' @return data.table with columns cd_commune_2025 (integer) and cd_nuts3_2027 (character)
parse_nis2025_nuts2027 <- function(conv_dt,
                                   col_nis   = FILE_MAPPING$CONVERSION_NIS2025_NUTS2027$col_nis,
                                   col_nuts3 = FILE_MAPPING$CONVERSION_NIS2025_NUTS2027$col_nuts3) {

  dt <- copy(conv_dt)

  if (!col_nis %in% names(dt)) {
    stop(sprintf(
      "Column '%s' not found in CONVERSION_NIS2025_NUTS2027. Available: %s\n%s",
      col_nis, paste(names(dt), collapse = ", "),
      "Update FILE_MAPPING$CONVERSION_NIS2025_NUTS2027$col_nis in 00_config.R."
    ))
  }
  if (!col_nuts3 %in% names(dt)) {
    stop(sprintf(
      "Column '%s' not found in CONVERSION_NIS2025_NUTS2027. Available: %s\n%s",
      col_nuts3, paste(names(dt), collapse = ", "),
      "Update FILE_MAPPING$CONVERSION_NIS2025_NUTS2027$col_nuts3 in 00_config.R."
    ))
  }

  result <- dt[, .(cd_commune_2025 = as.integer(get(col_nis)),
                   cd_nuts3_2027   = as.character(get(col_nuts3)))]
  result <- unique(result[!is.na(cd_commune_2025) & !is.na(cd_nuts3_2027)])

  message(sprintf("  -> NIS2025->NUTS2027 mapping: %d communes", nrow(result)))
  return(result)
}

#' Parse NIS change table
#'
#' @param change_dt data.table from REFNIS_CHANGE_2025.xlsx
#' @return data.table with standardized change information
parse_nis_changes <- function(change_dt) {

  dt <- copy(change_dt)

  setnames(dt, c("nis_version_old", "nis_version_new",
                 "nuts_version_old", "nuts_version_new",
                 "cd_refnis_old", "cd_refnis_new",
                 "cd_nuts_old", "cd_nuts_new", "nature"))

  dt[, cd_refnis_old := as.integer(cd_refnis_old)]
  dt[, cd_refnis_new := as.integer(cd_refnis_new)]

  return(dt)
}
