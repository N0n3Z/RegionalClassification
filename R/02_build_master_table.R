# ==============================================================================
# 02_build_master_table.R - Build the combined master classification table
# ==============================================================================


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
      abort(
        sprintf("%s: cannot find column for '%s' (pattern: %s). Available columns: %s",
                label, role, pattern, paste(names(dt), collapse = ", ")),
        class = "rcl_invalid_input"
      )
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

#' Validate a per-version communes sub-table against the expected schema
#'
#' Guards the unified communes table against silent column drift before the
#' version sub-tables are stacked. See MASTER_COMMUNE_CORE_COLS /
#' MASTER_COMMUNE_KNOWN_COLS in 00_config.R.
#'
#' @param tbl   A per-version communes data.table
#' @param label Human-readable version label used in error messages
#' @return Invisibly TRUE; aborts with class \code{rcl_schema_error} otherwise
#' @noRd
.validate_commune_schema <- function(tbl, label) {
  cols <- names(tbl)

  missing <- setdiff(MASTER_COMMUNE_CORE_COLS, cols)
  if (length(missing) > 0L) {
    abort(
      sprintf("communes sub-table '%s' is missing required column(s): %s",
              label, paste(missing, collapse = ", ")),
      class = "rcl_schema_error", label = label, missing = missing
    )
  }

  unknown <- setdiff(cols, MASTER_COMMUNE_KNOWN_COLS)
  if (length(unknown) > 0L) {
    abort(
      sprintf(paste0("communes sub-table '%s' has unexpected column(s): %s\n",
                     "If intended, add them to MASTER_COMMUNE_KNOWN_COLS in 00_config.R."),
              label, paste(unknown, collapse = ", ")),
      class = "rcl_schema_error", label = label, unknown = unknown
    )
  }

  invisible(TRUE)
}

#' Build the master classification table from all loaded data
#'
#' Creates a unified table structure with three main data.tables:
#' \code{communes} (all NIS versions), \code{postal} (both postal mappings),
#' and \code{nis_changes} (all NIS version transitions).
#'
#' @param raw_data Named list of data.tables from load_all_raw_data()
#' @return list with three unified flat tables plus build-time hierarchy intermediates
#' @export
build_master_table <- function(raw_data) {

  message("Building master classification table...")

  # --- 1. Parse all source data ---
  nis_2019    <- parse_refnis_hierarchy(raw_data$REFNIS_2019)
  nis_2025    <- parse_refnis_hierarchy(raw_data$REFNIS_2025)
  nuts_nis    <- parse_nuts_nis_conversion(raw_data$CONVERSION_NIS2019_NUTS2021)
  nuts_arr    <- parse_nuts_arrondissement(raw_data$NUTS_ARRONDISSEMENT)
  nis_changes <- parse_nis_changes(raw_data$REFNIS_CHANGE)

  # --- 2. Build NIS 2019 commune table with full hierarchy ---
  comm_2019 <- build_nis_commune_table(nis_2019, version = "2019")

  # --- 3. Build NIS 2025 commune table with full hierarchy ---
  comm_2025 <- build_nis_commune_table(nis_2025, version = "2025")

  # --- 4. Add NUTS 2021 to NIS 2019 communes ---
  nuts_comm  <- nuts_nis$communes[, .(cd_refnis, cd_nuts_lau, cd_nuts3)]
  nuts_arr_2021  <- nuts_nis$arrondissements[, .(cd_nuts3 = cd_nuts, cd_nuts2 = cd_nuts_parent)]
  nuts_prov_2021 <- nuts_nis$provinces[, .(cd_nuts2 = cd_nuts, cd_nuts1 = cd_nuts_parent)]

  nuts_comm <- merge(nuts_comm, nuts_arr_2021, by = "cd_nuts3", all.x = TRUE)
  nuts_comm <- merge(nuts_comm, nuts_prov_2021, by = "cd_nuts2", all.x = TRUE)
  nuts_comm[, cd_nuts0 := "BE"]

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

  # --- 5b. Add NUTS 2027 codes for NIS 2019 (remapped from NUTS 2021) ---
  master_2019 <- add_nuts2027_columns(master_2019)

  # --- 5c. Build NUTS3 2021 reference and embed names into master_2019 ---
  nuts3_ref_2021 <- nuts_nis$arrondissements[, .(cd_nuts3 = cd_nuts,
                                                   tx_nuts3_fr = tx_descr_fr,
                                                   tx_nuts3_nl = tx_descr_nl)]
  master_2019 <- merge(master_2019, nuts3_ref_2021, by = "cd_nuts3", all.x = TRUE)

  # --- 5d. Build NIS BEFORE_2019 commune table (if file available) ---
  master_before2019     <- NULL
  nis_change_before2019 <- NULL

  if (!is.null(raw_data$REFNIS_BEFORE_2019)) {
    nis_before2019  <- parse_refnis_hierarchy(raw_data$REFNIS_BEFORE_2019,
                                              lang_col = "Langue")
    comm_before2019 <- build_nis_commune_table(nis_before2019, version = "BEFORE_2019")

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
    master_before2019 <- merge(master_before2019, nuts3_ref_2021, by = "cd_nuts3", all.x = TRUE)

    message(sprintf("  NIS BEFORE_2019: %d communes", nrow(comm_before2019)))

    if (!is.null(raw_data$REFNIS_CHANGE_BEFORE2019)) {
      nis_change_before2019 <- parse_refnis_change_before2019(raw_data$REFNIS_CHANGE_BEFORE2019)
    }
  }

  # --- 6. Postal codes ---
  postal_map_2019 <- .extract_postal_map(raw_data$CONVERSION_POSTAL_NIS2019,
                                         label = "CONVERSION_POSTAL_NIS2019")
  postal_map_2019[, nis_version := "2019"]

  postal_map_2025 <- .extract_postal_map(raw_data$CONVERSION_POSTAL_NIS2025,
                                         label = "CONVERSION_POSTAL_NIS2025")
  postal_map_2025[, nis_version := "2025"]

  # --- 7. Build NIS 2025 -> NUTS 2027 mapping and enrich comm_2025 ---
  nuts2027_nis_parsed <- NULL
  master_2025         <- copy(comm_2025)

  if (!is.null(raw_data$CONVERSION_NIS2025_NUTS2027)) {
    nuts2027_nis_parsed <- parse_nuts_nis_conversion(raw_data$CONVERSION_NIS2025_NUTS2027)

    comm2025_nuts27 <- nuts2027_nis_parsed$communes[, .(cd_commune = cd_refnis,
                                                        cd_nuts3_2027 = cd_nuts3)]
    nuts_arr_2027   <- nuts2027_nis_parsed$arrondissements[, .(cd_nuts3_2027 = cd_nuts,
                                                               cd_nuts2_2027 = cd_nuts_parent)]
    nuts_prov_2027  <- nuts2027_nis_parsed$provinces[, .(cd_nuts2_2027 = cd_nuts,
                                                         cd_nuts1_2027 = cd_nuts_parent)]

    comm2025_nuts27 <- merge(comm2025_nuts27, nuts_arr_2027, by = "cd_nuts3_2027", all.x = TRUE)
    comm2025_nuts27 <- merge(comm2025_nuts27, nuts_prov_2027, by = "cd_nuts2_2027", all.x = TRUE)
    comm2025_nuts27[, cd_nuts0_2027 := "BE"]

    master_2025 <- merge(comm_2025, comm2025_nuts27, by = "cd_commune", all.x = TRUE)
    message(sprintf("  NIS 2025 -> NUTS 2027: %d communes mapped", nrow(comm2025_nuts27)))
  }

  # --- 8. NIS change mapping (2019 -> 2025) ---
  nis_change_map <- nis_changes[, .(cd_refnis_old, cd_refnis_new, nature)]
  nis_change_map[, from_version := "2019"]

  # --- 9. Unify into three flat tables ---

  # communes: NIS 2019 + BEFORE_2019 + 2025
  # Validate each sub-table's schema before stacking, so a renamed/dropped column
  # fails loudly here instead of being silently NA-filled by rbindlist(fill=TRUE).
  .validate_commune_schema(master_2019, "NIS 2019")
  if (!is.null(master_before2019)) .validate_commune_schema(master_before2019, "NIS BEFORE_2019")
  .validate_commune_schema(master_2025, "NIS 2025")

  communes_list <- list(master_2019)
  if (!is.null(master_before2019)) communes_list <- c(communes_list, list(master_before2019))
  communes_list <- c(communes_list, list(master_2025))
  communes_unified <- rbindlist(communes_list, use.names = TRUE, fill = TRUE)

  # postal: NIS 2019 + NIS 2025
  postal_unified <- rbindlist(list(postal_map_2019, postal_map_2025), use.names = TRUE)

  # nis_changes: 2019->2025 + BEFORE_2019->2019
  nis_changes_unified <- copy(nis_change_map)
  if (!is.null(nis_change_before2019)) {
    before2019_std <- data.table(
      cd_refnis_old = nis_change_before2019$cd_refnis_before2019,
      cd_refnis_new = nis_change_before2019$cd_refnis_2019,
      nature        = "FUSION",
      from_version  = "BEFORE_2019"
    )
    nis_changes_unified <- rbindlist(list(nis_changes_unified, before2019_std),
                                     use.names = TRUE)
  }

  # --- 10. Assemble result ---
  result <- list(
    # Three unified flat tables (saved to RDS by save_master_tables)
    communes    = communes_unified,
    postal      = postal_unified,
    nis_changes = nis_changes_unified,

    # Build-time hierarchy intermediates (not saved, set to NULL by load_master_data)
    nis_hierarchy_2019          = nis_2019,
    nis_hierarchy_2025          = nis_2025,
    nuts_hierarchy_2021         = nuts_nis,
    nuts_arrondissement_mapping = nuts_arr
  )

  n_b19 <- if (!is.null(master_before2019)) nrow(master_before2019) else 0L
  message(sprintf(
    "Master table built: %d communes NIS 2019, %d NIS 2025, %d NIS BEFORE_2019",
    nrow(master_2019), nrow(master_2025), n_b19
  ))
  message(sprintf("  Postal: %d (NIS 2019) + %d (NIS 2025)",
                  nrow(postal_map_2019), nrow(postal_map_2025)))
  message(sprintf("  NIS changes: %d (2019->2025) + %d (BEFORE_2019->2019)",
                  nrow(nis_change_map),
                  if (!is.null(nis_change_before2019)) nrow(nis_change_before2019) else 0L))

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

  # Province 20000 (Brabant) spans all three regions; province->region is NA for it.
  # Resolve here by arrondissement using the constants defined in 00_config.R.
  bxl_reg <- nis_parsed$regions[cd_refnis == NIS_REGION_BRUSSELS]
  fl_reg  <- nis_parsed$regions[cd_refnis == NIS_REGION_FLEMISH]
  wa_reg  <- nis_parsed$regions[cd_refnis == NIS_REGION_WALLOON]

  communes[cd_arr == NIS_ARR_BRUSSELS     & is.na(cd_region), cd_region := NIS_REGION_BRUSSELS]
  communes[cd_arr %in% c(NIS_ARR_HAL_VILVORDE, NIS_ARR_LOUVAIN) & is.na(cd_region),
           cd_region := NIS_REGION_FLEMISH]
  communes[cd_arr == NIS_ARR_NIVELLES     & is.na(cd_region), cd_region := NIS_REGION_WALLOON]

  if (nrow(bxl_reg) > 0)
    communes[cd_region == NIS_REGION_BRUSSELS & is.na(tx_region_fr),
             `:=`(tx_region_fr = bxl_reg$tx_descr_fr, tx_region_nl = bxl_reg$tx_descr_nl)]
  if (nrow(fl_reg) > 0)
    communes[cd_region == NIS_REGION_FLEMISH  & is.na(tx_region_fr),
             `:=`(tx_region_fr = fl_reg$tx_descr_fr, tx_region_nl = fl_reg$tx_descr_nl)]
  if (nrow(wa_reg) > 0)
    communes[cd_region == NIS_REGION_WALLOON  & is.na(tx_region_fr),
             `:=`(tx_region_fr = wa_reg$tx_descr_fr, tx_region_nl = wa_reg$tx_descr_nl)]

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

#' Derive NUTS 2027 columns for NIS 2019 / BEFORE_2019 communes (build-time only)
#'
#' Applies the NUTS2021_TO_NUTS2027 code-rename table to add cd_nuts3_2027,
#' cd_nuts2_2027, cd_nuts1_2027 to the NIS 2019 and BEFORE_2019 master tables.
#'
#' **Known limitation:** three communes changed province between 2019 and 2025
#' (CHANGE_PROV/CHANGE_DSTR in nis_changes), shifting their NUTS3 region.  For
#' these communes the derived cd_nuts3_2027 value is WRONG.  The conversion
#' executor no longer reads this column: `NIS_COMMUNE_2019 → NUTS3_2027` is
#' routed via `NIS_COMMUNE_2025` (authoritative data).  Phase 4 of the
#' refactoring plan will rebuild the pre-computed snapshot with correct values.
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
#' @param output_dir  Path to output directory (default: inst/extdata/, via
#'   get_processed_data_path())
#' @return Invisible NULL (called for side effect)
#' @export
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
