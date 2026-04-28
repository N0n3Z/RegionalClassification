# ==============================================================================
# 02_build_master_table.R - Build the combined master classification table
# ==============================================================================

library(data.table)

#' Extract and standardise a postal code mapping table (internal)
#'
#' Uses pattern-matching to find the four needed columns, with explicit
#' error messages if a column cannot be found.
#'
#' @param dt   data.table from a postal conversion file
#' @param label File name used in error messages
#' @return data.table(cd_postal, cd_commune_nis, tx_postal_name_fr, tx_postal_name_nl)
.extract_postal_map <- function(dt, label = "postal file") {
  .find_col <- function(pattern, role) {
    col <- grep(pattern, names(dt), value = TRUE, ignore.case = TRUE)[1]
    if (is.na(col)) {
      stop(sprintf(
        "%s: cannot find column for '%s' (pattern: %s). Available columns: %s",
        label, role, pattern, paste(names(dt), collapse = ", ")
      ))
    }
    col
  }
  col_postal  <- .find_col("TERRITORIAL_CODE_POSTAL",        "postal code")
  col_nis     <- .find_col("TERRITORIAL_CODE_NIS|TERRITORIAL_CODE_INS", "NIS commune code")
  col_name_fr <- .find_col("NAME_FR",                        "French name")
  col_name_nl <- .find_col("NAME_NL",                        "Dutch name")

  result <- dt[, .SD, .SDcols = c(col_postal, col_nis, col_name_fr, col_name_nl)]
  setnames(result, c("cd_postal", "cd_commune_nis", "tx_postal_name_fr", "tx_postal_name_nl"))
  result[, cd_commune_nis := as.integer(cd_commune_nis)]
  result[, cd_postal      := as.integer(cd_postal)]
  result
}

#' Build the master classification table from all loaded data
#'
#' Creates a comprehensive table at commune level linking all classifications.
#'
#' @param raw_data Named list of data.tables from load_all_raw_data()
#' @return list with master_table and auxiliary tables
build_master_table <- function(raw_data) {

  message("Building master classification table...")

  # --- 1. Parse all source data ---
  nis_2019 <- parse_refnis_hierarchy(raw_data$REFNIS_2019)
  nis_2025 <- parse_refnis_hierarchy(raw_data$REFNIS_2025)
  nuts_nis <- parse_nuts_nis_conversion(raw_data$CONVERSION_NIS2019_NUTS2021)
  nuts_arr <- parse_nuts_arrondissement(raw_data$NUTS_ARRONDISSEMENT)
  nis_changes <- parse_nis_changes(raw_data$REFNIS_CHANGE)

  # --- 2. Build NIS 2019 commune table with full hierarchy ---
  comm_2019 <- build_nis_commune_table(nis_2019, version = "2019")

  # --- 3. Build NIS 2025 commune table with full hierarchy ---
  comm_2025 <- build_nis_commune_table(nis_2025, version = "2025")

  # --- 4. Add NUTS 2021 to NIS 2019 communes ---
  nuts_comm <- nuts_nis$communes[, .(cd_refnis, cd_nuts_lau = cd_nuts_lau, cd_nuts3)]

  # Add NUTS2, NUTS1, NUTS0 from NUTS hierarchy
  nuts_arr_2021 <- nuts_nis$arrondissements[, .(cd_nuts3 = cd_nuts, cd_nuts2 = cd_nuts_parent)]
  nuts_prov_2021 <- nuts_nis$provinces[, .(cd_nuts2 = cd_nuts, cd_nuts1 = cd_nuts_parent)]

  nuts_comm <- merge(nuts_comm, nuts_arr_2021, by = "cd_nuts3", all.x = TRUE)
  nuts_comm <- merge(nuts_comm, nuts_prov_2021, by = "cd_nuts2", all.x = TRUE)
  nuts_comm[, cd_nuts0 := "BE"]

  # Merge NUTS into NIS 2019
  master_2019 <- merge(comm_2019, nuts_comm,
                        by.x = "cd_commune", by.y = "cd_refnis",
                        all.x = TRUE)

  # --- 5. Add internal arrondissement code ---
  if ("2021" %in% names(nuts_arr)) {
    internal_map <- nuts_arr[["2021"]]
  } else if ("2016" %in% names(nuts_arr)) {
    internal_map <- nuts_arr[["2016"]]
  } else {
    internal_map <- data.table(cd_nuts3 = character(), cd_arr_internal = character())
  }
  master_2019 <- merge(master_2019, internal_map, by = "cd_nuts3", all.x = TRUE)

  # --- 5b. Add NUTS 2027 codes (derived from NUTS 2021, EU regulation 2026/195) ---
  master_2019 <- add_nuts2027_columns(master_2019)

  # --- 5c. Build NIS BEFORE_2019 commune table (if file available) ---
  # Placed here so internal_map is already defined (step 5).
  comm_before2019 <- NULL
  master_before2019 <- NULL
  nis_change_before2019 <- NULL

  if (!is.null(raw_data$REFNIS_BEFORE_2019)) {
    nis_before2019 <- parse_refnis_hierarchy(raw_data$REFNIS_BEFORE_2019,
                                              lang_col = "Langue")
    comm_before2019 <- build_nis_commune_table(nis_before2019, version = "BEFORE_2019")

    # Historical NUTS assignments (filter at 2018-12-31)
    nuts_nis_pre2019 <- parse_nuts_nis_conversion(
      raw_data$CONVERSION_NIS2019_NUTS2021,
      reference_date = as.Date("2018-12-31")
    )
    nuts_comm_pre2019 <- nuts_nis_pre2019$communes[, .(cd_refnis, cd_nuts_lau, cd_nuts3)]
    nuts_arr_pre2019  <- nuts_nis_pre2019$arrondissements[, .(cd_nuts3 = cd_nuts,
                                                               cd_nuts2 = cd_nuts_parent)]
    nuts_prov_pre2019 <- nuts_nis_pre2019$provinces[, .(cd_nuts2 = cd_nuts,
                                                         cd_nuts1 = cd_nuts_parent)]

    nuts_comm_pre2019 <- merge(nuts_comm_pre2019, nuts_arr_pre2019, by = "cd_nuts3", all.x = TRUE)
    nuts_comm_pre2019 <- merge(nuts_comm_pre2019, nuts_prov_pre2019, by = "cd_nuts2", all.x = TRUE)
    nuts_comm_pre2019[, cd_nuts0 := "BE"]

    master_before2019 <- merge(comm_before2019, nuts_comm_pre2019,
                                by.x = "cd_commune", by.y = "cd_refnis",
                                all.x = TRUE)
    master_before2019 <- add_nuts2027_columns(master_before2019)
    master_before2019 <- merge(master_before2019, internal_map, by = "cd_nuts3", all.x = TRUE)

    message(sprintf("  NIS BEFORE_2019: %d communes", nrow(comm_before2019)))

    if (!is.null(raw_data$REFNIS_CHANGE_BEFORE2019)) {
      nis_change_before2019 <- parse_refnis_change_before2019(raw_data$REFNIS_CHANGE_BEFORE2019)
    }
  }

  # --- 6. Add postal codes (NIS 2019) ---
  postal_2019    <- raw_data$CONVERSION_POSTAL_NIS2019
  postal_map_2019 <- .extract_postal_map(postal_2019, label = "CONVERSION_POSTAL_NIS2019")

  # --- 7. Add postal codes (NIS 2025) ---
  postal_2025    <- raw_data$CONVERSION_POSTAL_NIS2025
  postal_map_2025 <- .extract_postal_map(postal_2025, label = "CONVERSION_POSTAL_NIS2025")

  # --- 7b. Build NIS 2025 -> NUTS 2027 mapping ---
  # Uses the same hierarchical format as CONVERSION_NIS2019_NUTS2021.xlsx.
  # parse_nuts_nis_conversion() with no reference_date keeps only current entries
  # (DT_VLDT_STOP = max), which gives NUTS 2027 codes for NIS 2025 communes.
  comm2025_to_nuts2027 <- NULL
  nuts2027_nis_parsed  <- NULL
  if (!is.null(raw_data$CONVERSION_NIS2025_NUTS2027)) {
    nuts2027_nis_parsed  <- parse_nuts_nis_conversion(raw_data$CONVERSION_NIS2025_NUTS2027)
    comm2025_to_nuts2027 <- nuts2027_nis_parsed$communes[,
      .(cd_commune_2025 = cd_refnis, cd_nuts3_2027 = cd_nuts3)
    ]
    message(sprintf("  NIS 2025 -> NUTS 2027: %d communes mapped", nrow(comm2025_to_nuts2027)))
  }

  # --- 8. Build NIS change mapping ---
  nis_change_map <- nis_changes[, .(cd_refnis_old, cd_refnis_new, nature)]

  # --- 9. Build NUTS arrondissement reference tables ---
  nuts3_ref_2021 <- nuts_nis$arrondissements[, .(cd_nuts3 = cd_nuts,
                                                   cd_refnis_arr = cd_refnis,
                                                   tx_nuts3_fr = tx_descr_fr,
                                                   tx_nuts3_nl = tx_descr_nl)]
  nuts3_ref_2021[, cd_refnis_arr := as.integer(cd_refnis_arr)]

  # --- 10. Assemble result ---
  result <- list(
    # Main tables
    master_nis2019_nuts2021 = master_2019,
    communes_nis2019 = comm_2019,
    communes_nis2025 = comm_2025,

    # Postal mappings
    postal_to_nis2019 = postal_map_2019,
    postal_to_nis2025 = postal_map_2025,

    # NIS change mapping
    nis_changes = nis_change_map,

    # NUTS references
    nuts3_ref_2021 = nuts3_ref_2021,
    comm2025_to_nuts2027 = comm2025_to_nuts2027,
    nuts3_ref_2027 = {
      # Use official NUTS 2027 names when available, otherwise derive from NUTS 2021
      if (!is.null(nuts2027_nis_parsed)) {
        arr_2027 <- nuts2027_nis_parsed$arrondissements
        unique(arr_2027[, .(cd_nuts3_2027 = cd_nuts,
                            cd_nuts2_2027 = cd_nuts_parent,
                            tx_nuts3_fr   = tx_descr_fr,
                            tx_nuts3_nl   = tx_descr_nl)])
      } else {
        unique(master_2019[!is.na(cd_nuts3_2027),
                           .(cd_nuts3_2027, cd_nuts2_2027, cd_nuts1_2027)])
      }
    },
    nuts_to_internal = internal_map,

    # NIS BEFORE_2019 tables (NULL if REFNIS_BEFORE_2019.xls not available)
    communes_nis_before2019  = comm_before2019,
    master_before2019        = master_before2019,
    nis_change_before2019    = nis_change_before2019,

    # Parsed hierarchies
    nis_hierarchy_2019 = nis_2019,
    nis_hierarchy_2025 = nis_2025,
    nuts_hierarchy_2021 = nuts_nis,
    nuts_arrondissement_mapping = nuts_arr
  )

  message(sprintf("Master table built: %d communes NIS 2019, %d communes NIS 2025",
                  nrow(comm_2019), nrow(comm_2025)))
  message(sprintf("  Postal codes NIS 2019: %d, NIS 2025: %d",
                  nrow(postal_map_2019), nrow(postal_map_2025)))
  message(sprintf("  NIS changes 2019->2025: %d entries", nrow(nis_change_map)))

  return(result)
}

#' Build a commune-level table with full NIS hierarchy for a given version
#'
#' @param nis_parsed Output from parse_refnis_hierarchy()
#' @param version "2019" or "2025"
#' @return data.table with commune info and parent codes
build_nis_commune_table <- function(nis_parsed, version) {

  communes <- copy(nis_parsed$communes)
  setnames(communes, "cd_refnis", "cd_commune")
  setnames(communes, "tx_descr_fr", "tx_commune_fr")
  setnames(communes, "tx_descr_nl", "tx_commune_nl")

  # cd_arr is already computed by parse_refnis_hierarchy
  # Add arrondissement names
  arr <- nis_parsed$arrondissements[, .(cd_arr = cd_refnis,
                                         tx_arr_fr = tx_descr_fr,
                                         tx_arr_nl = tx_descr_nl,
                                         cd_prov_candidate)]
  communes <- merge(communes, arr, by = "cd_arr", all.x = TRUE)

  # Add province
  prov <- nis_parsed$provinces[, .(cd_prov = cd_refnis,
                                    tx_prov_fr = tx_descr_fr,
                                    tx_prov_nl = tx_descr_nl,
                                    cd_region)]
  communes <- merge(communes, prov, by.x = "cd_prov_candidate", by.y = "cd_prov", all.x = TRUE)
  setnames(communes, "cd_prov_candidate", "cd_province")

  # Add region
  reg <- nis_parsed$regions[, .(cd_region = cd_refnis,
                                 tx_region_fr = tx_descr_fr,
                                 tx_region_nl = tx_descr_nl)]
  communes <- merge(communes, reg, by = "cd_region", all.x = TRUE)

  # Handle Brussels: arrondissement 21000 has no province 20000
  # Brussels communes should have region = 4000
  communes[cd_arr == 21000L & is.na(cd_region), cd_region := 4000L]
  if (nrow(communes[cd_arr == 21000L & is.na(tx_region_fr)]) > 0) {
    bxl_reg <- nis_parsed$regions[cd_refnis == 4000L]
    if (nrow(bxl_reg) > 0) {
      communes[cd_arr == 21000L & is.na(tx_region_fr),
               `:=`(tx_region_fr = bxl_reg$tx_descr_fr,
                    tx_region_nl = bxl_reg$tx_descr_nl)]
    }
  }

  # Add 2-digit arrondissement code (for internal classification link)
  communes[, cd_arr_2digit := cd_arr %/% 1000L]

  # Add version tag
  communes[, nis_version := version]

  # Reorder columns
  desired_cols <- c("cd_commune", "tx_commune_fr", "tx_commune_nl",
                    "cd_arr", "tx_arr_fr", "tx_arr_nl", "cd_arr_2digit",
                    "cd_province", "tx_prov_fr", "tx_prov_nl",
                    "cd_region", "tx_region_fr", "tx_region_nl",
                    "nis_version")
  existing_cols <- intersect(desired_cols, names(communes))
  setcolorder(communes, existing_cols)

  return(communes)
}

#' Derive NUTS 2027 columns from existing NUTS 2021 columns in master table
#'
#' Applies the remapping defined in NUTS2021_TO_NUTS2027 (00_config.R).
#' Codes not listed in the mapping are carried over unchanged.
#'
#' @param master data.table with cd_nuts3, cd_nuts2, cd_nuts1, cd_nuts0 columns
#' @return data.table with added cd_nuts3_2027, cd_nuts2_2027, cd_nuts1_2027
add_nuts2027_columns <- function(master) {

  master <- copy(master)

  nuts3_map <- NUTS2021_TO_NUTS2027[nchar(nuts_2021) == 5]
  nuts2_map <- NUTS2021_TO_NUTS2027[nchar(nuts_2021) == 4]

  # NUTS3
  master <- merge(master, nuts3_map, by.x = "cd_nuts3", by.y = "nuts_2021", all.x = TRUE)
  setnames(master, "nuts_2027", "cd_nuts3_2027")
  master[is.na(cd_nuts3_2027), cd_nuts3_2027 := cd_nuts3]

  # NUTS2
  master <- merge(master, nuts2_map, by.x = "cd_nuts2", by.y = "nuts_2021", all.x = TRUE)
  setnames(master, "nuts_2027", "cd_nuts2_2027")
  master[is.na(cd_nuts2_2027), cd_nuts2_2027 := cd_nuts2]

  # NUTS1 and NUTS0 are unchanged for Belgium
  master[, cd_nuts1_2027 := cd_nuts1]
  master[, cd_nuts0_2027 := cd_nuts0]

  return(master)
}

#' Save master table and all auxiliary tables to processed directory
#'
#' Saves every flat data.table in master_data as an RDS file, preserving all
#' R types exactly.  Call this after build_master_table() to update the
#' pre-built snapshot used by load_master_data().
#'
#' @param master_data Output from build_master_table()
#' @param output_dir  Path to output directory (default: data/processed/)
save_master_tables <- function(master_data, output_dir = get_processed_data_path()) {

  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  for (tbl_name in MASTER_FLAT_TABLES) {
    tbl <- master_data[[tbl_name]]
    if (is.null(tbl)) {
      message(sprintf("  SKIP  %s  (NULL)", tbl_name))
      next
    }
    filepath <- file.path(output_dir, paste0(tbl_name, ".rds"))
    saveRDS(tbl, filepath)
    message(sprintf("  SAVED %s -> %s  (%d rows)", tbl_name, filepath, nrow(tbl)))
  }
}
