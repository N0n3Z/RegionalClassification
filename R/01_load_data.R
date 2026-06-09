# ==============================================================================
# 01_load_data.R - Load and parse all raw input data files
# ==============================================================================


#' Load all raw data files and return a named list of data.tables
#'
#' @param data_dir Path to the raw data directory
#' @param file_mapping The FILE_MAPPING configuration from 00_config.R
#' @return Named list of data.tables
#' @export
load_all_raw_data <- function(data_dir = get_raw_data_path(),
                              file_mapping = FILE_MAPPING) {

  raw_data <- list()

  for (name in names(file_mapping)) {
    fm <- file_mapping[[name]]
    filepath <- file.path(data_dir, fm$filename)

    if (!file.exists(filepath)) {
      warn(sprintf("File not found: %s (skipping %s)", filepath, name),
           class = "rcl_data_missing")
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
#' @keywords internal
load_single_file <- function(filepath, sheet = NULL, filter_spec = NULL) {

  ext <- tolower(tools::file_ext(filepath))

  dt <- switch(ext,
    "xlsx" = {
      if (is.null(sheet)) {
        as.data.table(readxl::read_excel(filepath))
      } else {
        as.data.table(readxl::read_excel(filepath, sheet = sheet))
      }
    },
    "xls" = {
      if (is.null(sheet)) {
        as.data.table(readxl::read_excel(filepath))
      } else {
        as.data.table(readxl::read_excel(filepath, sheet = sheet))
      }
    },
    "csv" = {
      fread(filepath)
    },
    abort(sprintf("Unsupported file extension: %s", ext),
          class = "rcl_invalid_input")
  )

  # Apply filter if specified
  if (!is.null(filter_spec)) {
    col <- filter_spec$column
    val <- filter_spec$value
    if (col %in% names(dt)) {
      dt <- dt[get(col) == val]
      message(sprintf("  -> Filtered on %s == %s: %d rows remaining", col, val, nrow(dt)))
    } else {
      warn(sprintf("Filter column '%s' not found in data", col),
           class = "rcl_invalid_input")
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
#' @param lang_col Optional column distinguishing language variants (NULL = ignore)
#' @return list of data.tables: communes, arrondissements, provinces, regions
#' @noRd
parse_refnis_hierarchy <- function(refnis_dt,
                                   code_col = "Code INS",
                                   name_fr_col = "Entit\u00e9s administratives",
                                   name_nl_col = "Administratieve eenheden",
                                   lang_col = NULL) {

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
  if (!is.null(lang_col) && lang_col %in% names(dt)) {
    dt[, is_valid_commune := !is.na(get(lang_col))]
  } else {
    dt[, is_valid_commune := TRUE]
  }

  dt[, level := fcase(
    cd_refnis == 1000L, "pays",
    cd_refnis < 10000L & cd_refnis %% 1000L == 0L, "region",
    cd_refnis >= 10000L & cd_refnis %% 10000L == 0L, "province",
    cd_refnis >= 10000L & cd_refnis %% 1000L == 0L, "arrondissement",
    cd_refnis >= 10000L & cd_refnis %% 1000L != 0L & is_valid_commune, "commune",
    default = "unknown"
  )]
  dt[, is_valid_commune := NULL]

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

  # Add region to provinces using the centralised lookup table (see 00_config.R).
  # Brabant (digit 2) stays NA; resolved per-commune in build_nis_commune_table().
  provs <- result$provinces
  digit_key <- as.character(provs$cd_refnis %/% 10000L)
  provs[, cd_region := NIS_PROV_DIGIT_TO_REGION[digit_key]]
  result$provinces <- provs

  return(result)
}

#' Parse the NUTS-NIS conversion file
#'
#' @param conv_dt data.table from CONVERSION_NIS2019_NUTS2021.xlsx
#' @param reference_date Date to filter validity. NULL = use current (max DT_VLDT_STOP).
#'   Use as.Date("2018-12-31") for pre-2019 historical NUTS assignments.
#' @return list with NUTS hierarchy and commune-level mapping
#' @keywords internal
parse_nuts_nis_conversion <- function(conv_dt, reference_date = NULL) {

  dt <- copy(conv_dt)

  # Filter to entries valid at a given reference date.
  # When reference_date is NULL, keep only the most recent entries (current).
  # When reference_date is provided, keep entries where:
  #   DT_VLDT_STRT <= reference_date < DT_VLDT_STOP
  filter_at_date <- function(sub_dt, ref_date) {
    if (is.null(ref_date)) {
      max_stop <- max(sub_dt$DT_VLDT_STOP)
      sub_dt[DT_VLDT_STOP == max_stop]
    } else {
      ref_posix <- as.POSIXct(as.character(ref_date), tz = "UTC")
      sub_dt[DT_VLDT_STRT <= ref_posix & DT_VLDT_STOP > ref_posix]
    }
  }

  # Split by level (filtering each to entries valid at reference_date)
  nuts_hierarchy <- list(
    regions     = filter_at_date(dt[CD_LVL == 1], reference_date)[,
                    .(cd_nuts = CD_LAU, cd_refnis = CD_MUNTY_REFNIS,
                      tx_descr_fr = TX_DESCR_FR, tx_descr_nl = TX_DESCR_NL)],
    provinces   = filter_at_date(dt[CD_LVL == 2], reference_date)[,
                    .(cd_nuts = CD_LAU, cd_refnis = CD_MUNTY_REFNIS,
                      tx_descr_fr = TX_DESCR_FR, tx_descr_nl = TX_DESCR_NL,
                      cd_nuts_parent = CD_LVL_SUP)],
    arrondissements = filter_at_date(dt[CD_LVL == 3], reference_date)[,
                        .(cd_nuts = CD_LAU, cd_refnis = CD_MUNTY_REFNIS,
                          tx_descr_fr = TX_DESCR_FR, tx_descr_nl = TX_DESCR_NL,
                          cd_nuts_parent = CD_LVL_SUP)],
    communes    = filter_at_date(dt[CD_LVL == 4], reference_date)[,
                    .(cd_nuts_lau = CD_LAU, cd_refnis = CD_MUNTY_REFNIS,
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
#' @keywords internal
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
#' @keywords internal
parse_nis2025_nuts2027 <- function(conv_dt,
                                   col_nis   = FILE_MAPPING$CONVERSION_NIS2025_NUTS2027$col_nis,
                                   col_nuts3 = FILE_MAPPING$CONVERSION_NIS2025_NUTS2027$col_nuts3) {

  dt <- copy(conv_dt)

  if (!col_nis %in% names(dt)) {
    abort(
      sprintf("Column '%s' not found in CONVERSION_NIS2025_NUTS2027. Available: %s\n%s",
              col_nis, paste(names(dt), collapse = ", "),
              "Update FILE_MAPPING$CONVERSION_NIS2025_NUTS2027$col_nis in 00_config.R."),
      class = "rcl_invalid_input"
    )
  }
  if (!col_nuts3 %in% names(dt)) {
    abort(
      sprintf("Column '%s' not found in CONVERSION_NIS2025_NUTS2027. Available: %s\n%s",
              col_nuts3, paste(names(dt), collapse = ", "),
              "Update FILE_MAPPING$CONVERSION_NIS2025_NUTS2027$col_nuts3 in 00_config.R."),
      class = "rcl_invalid_input"
    )
  }

  result <- dt[, .(cd_commune_2025 = as.integer(get(col_nis)),
                   cd_nuts3_2027   = as.character(get(col_nuts3)))]
  result <- unique(result[!is.na(cd_commune_2025) & !is.na(cd_nuts3_2027)])

  message(sprintf("  -> NIS2025->NUTS2027 mapping: %d communes", nrow(result)))
  return(result)
}

#' Parse NIS BEFORE_2019 -> NIS 2019 change table (optional file)
#'
#' @param change_dt data.table from REFNIS_CHANGE_BEFORE2019.xlsx
#' @param col_old Name of old NIS code column
#' @param col_new Name of new NIS code column
#' @return data.table with cd_refnis_before2019 (integer) and cd_refnis_2019 (integer)
#' @keywords internal
parse_refnis_change_before2019 <- function(
    change_dt,
    col_old = FILE_MAPPING$REFNIS_CHANGE_BEFORE2019$col_nis_old,
    col_new = FILE_MAPPING$REFNIS_CHANGE_BEFORE2019$col_nis_new) {

  dt <- copy(change_dt)

  for (col in c(col_old, col_new)) {
    if (!col %in% names(dt)) {
      abort(
        sprintf("Column '%s' not found in REFNIS_CHANGE_BEFORE2019. Available: %s\n%s",
                col, paste(names(dt), collapse = ", "),
                sprintf("Update FILE_MAPPING$REFNIS_CHANGE_BEFORE2019$%s in 00_config.R.",
                        ifelse(col == col_old, "col_nis_old", "col_nis_new"))),
        class = "rcl_invalid_input"
      )
    }
  }

  result <- dt[, .(cd_refnis_before2019 = as.integer(get(col_old)),
                   cd_refnis_2019       = as.integer(get(col_new)))]
  result <- unique(result[!is.na(cd_refnis_before2019) & !is.na(cd_refnis_2019)])
  message(sprintf("  -> NIS BEFORE_2019->2019 changes: %d entries", nrow(result)))
  return(result)
}

#' Parse NIS change table
#'
#' @param change_dt data.table from REFNIS_CHANGE_2025.xlsx
#' @return data.table with standardized change information
#' @keywords internal
parse_nis_changes <- function(change_dt) {

  dt <- copy(change_dt)

  # Rename by matching known source column names (case-insensitive).
  # The file may contain a typo variant (NUT_VERSION_OLD vs NUTS_VERSION_OLD)
  # and the order could change -- so we rename by name, not by position.
  required <- c(CD_REFNIS_OLD = "cd_refnis_old",
                CD_REFNIS_NEW = "cd_refnis_new",
                NATURE        = "nature")
  optional <- c(NIS_VERSION_OLD  = "nis_version_old",
                NIS_VERSION_NEW  = "nis_version_new",
                NUTS_VERSION_OLD = "nuts_version_old",
                NUT_VERSION_OLD  = "nuts_version_old",   # known typo variant
                CD_NUTS_OLD      = "cd_nuts_old",
                CD_NUTS_NEW      = "cd_nuts_new")

  col_map <- c(required, optional)
  cols_present <- names(dt)[toupper(names(dt)) %in% toupper(names(col_map))]
  for (old in cols_present) {
    new <- col_map[match(toupper(old), toupper(names(col_map)))]
    if (!is.na(new) && old != new && !new %in% names(dt))
      setnames(dt, old, new)
  }

  missing_req <- setdiff(unname(required), names(dt))
  if (length(missing_req) > 0) {
    abort(
      sprintf("REFNIS_CHANGE_2025: required column(s) not found: %s\nAvailable: %s",
              paste(missing_req, collapse = ", "), paste(names(change_dt), collapse = ", ")),
      class = "rcl_invalid_input"
    )
  }

  dt[, cd_refnis_old := as.integer(cd_refnis_old)]
  dt[, cd_refnis_new := as.integer(cd_refnis_new)]

  return(dt)
}
