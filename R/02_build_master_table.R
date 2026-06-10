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
  comm_2019 <- build_nis_commune_table(nis_2019, version = VER_2019)

  # --- 3. Build NIS 2025 commune table with full hierarchy ---
  comm_2025 <- build_nis_commune_table(nis_2025, version = VER_2025)

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
  if (VER_NUTS_2021 %in% names(nuts_arr)) {
    internal_map <- nuts_arr[[VER_NUTS_2021]]
  } else if ("2016" %in% names(nuts_arr)) {
    internal_map <- nuts_arr[["2016"]]
  } else {
    internal_map <- data.table(cd_nuts3 = character(), cd_arr_internal = character())
  }
  master_2019 <- merge(master_2019, internal_map, by = "cd_nuts3", all.x = TRUE)

  # --- 5b. Build NUTS3 2021 reference and embed names into master_2019 ---
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
    comm_before2019 <- build_nis_commune_table(nis_before2019, version = VER_BEFORE_2019)

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
  postal_map_2019[, nis_version := VER_2019]

  postal_map_2025 <- .extract_postal_map(raw_data$CONVERSION_POSTAL_NIS2025,
                                         label = "CONVERSION_POSTAL_NIS2025")
  postal_map_2025[, nis_version := VER_2025]

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

  # --- 7b. Backfill NUTS 2021 columns onto NIS 2025 master ---
  master_2025 <- add_nuts2021_columns_2025(master_2025, master_2019, nis_changes)

  # --- 8. NIS change mapping (2019 -> 2025) ---
  nis_change_map <- nis_changes[, .(cd_refnis_old, cd_refnis_new, nature)]
  nis_change_map[, from_version := VER_2019]

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
      from_version  = VER_BEFORE_2019
    )
    nis_changes_unified <- rbindlist(list(nis_changes_unified, before2019_std),
                                     use.names = TRUE)
  }

  # --- 9b. Build normalised entities + crosswalks tables (ADDITIVE) ---
  message("  Building entities table...")
  entities   <- build_entities_table(communes_unified, postal_unified)
  message("  Building crosswalks table...")
  crosswalks <- build_crosswalks(communes_unified, postal_unified, nis_changes_unified)

  # --- 10. Assemble result ---
  result <- list(
    # Five unified flat tables (saved to RDS by save_master_tables)
    communes    = communes_unified,
    postal      = postal_unified,
    nis_changes = nis_changes_unified,
    entities    = entities,
    crosswalks  = crosswalks,

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
  message(sprintf("  Entities: %d rows; Crosswalks: %d rows",
                  nrow(entities), nrow(crosswalks)))

  return(result)
}

#' Build a commune-level table with full NIS hierarchy for a given version
#'
#' @param nis_parsed Output from parse_refnis_hierarchy()
#' @param version "2019" or "2025"
#' @return data.table with commune info and parent codes
#' @keywords internal
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

#' Backfill NUTS 2021 columns onto NIS 2025 communes (build-time only)
#'
#' Derives cd_nuts3, cd_nuts2, cd_nuts1, cd_nuts0, cd_nuts_lau, and
#' cd_arr_internal for NIS 2025 communes from the NIS 2019 master:
#' - Unchanged communes (same code in 2019 and 2025): copy directly.
#' - Changed communes (in nis_changes[from_version=="2019"]):
#'   collect the NUTS3_2021 of all constituent 2019 communes and assign it
#'   only if all constituents share the same NUTS3; else NA +
#'   rcl_ambiguous_backfill warning. cd_nuts_lau stays NA for fusions (LAU
#'   is a 1:1 commune identifier and is undefined after a merge).
#'
#' The 2025 master must already carry cd_nuts3_2027 etc. (added from the
#' NIS 2025 NUTS 2027 source file during the 2025 master build step).
#'
#' @param master_2025 data.table for NIS 2025 communes (from build_master_table)
#' @param master_2019 data.table for NIS 2019 communes (fully enriched)
#' @param nis_changes Raw output from \code{parse_nis_changes()} -- must have at
#'   least \code{cd_refnis_old} and \code{cd_refnis_new} columns. The
#'   \code{from_version} and \code{nature} columns are added later (step 8 of
#'   \code{build_master_table}) and must NOT be present yet.
#' @return data.table master_2025 with NUTS 2021 columns added in-place.
#'   Note: \code{cd_nuts2}, \code{cd_nuts1}, and \code{cd_nuts0} may be
#'   non-\code{NA} for communes where \code{cd_nuts3} is \code{NA} (cross-NUTS3
#'   fusions), because NUTS2/1/0 are coarser and all constituent 2019 communes
#'   may agree on the broader region even when their NUTS3 assignments differ.
#' @keywords internal
add_nuts2021_columns_2025 <- function(master_2025, master_2019, nis_changes) {

  nuts_cols <- c("cd_nuts3", "cd_nuts2", "cd_nuts1", "cd_nuts0",
                 "cd_nuts_lau", "cd_arr_internal")
  # nis_changes here is the raw 2019->2025 output from parse_nis_changes()
  # (from_version has not been added yet); select only the two code columns.
  changes   <- nis_changes[, .(cd_refnis_old, cd_refnis_new)]
  lkp_2019  <- unique(master_2019[, c("cd_commune", nuts_cols), with = FALSE])

  codes_2025    <- unique(master_2025$cd_commune)
  changed_codes <- unique(changes$cd_refnis_new)
  unchanged     <- setdiff(codes_2025, changed_codes)

  # --- Unchanged communes: direct lookup from 2019 master ---
  unch_lkp <- lkp_2019[cd_commune %in% unchanged]

  # --- Changed communes: expand via constituent 2019 codes, aggregate ---
  constituents <- merge(changes, lkp_2019, by.x = "cd_refnis_old", by.y = "cd_commune",
                        all.x = TRUE)

  # If all non-NA constituent values are identical -> return that value; else NA
  .uniq1 <- function(x) {
    u <- unique(na.omit(x))
    if (length(u) == 1L) u else NA_character_
  }

  # Aggregate scalar cols (not cd_nuts_lau which needs special logic)
  scalar_cols <- setdiff(nuts_cols, "cd_nuts_lau")
  agg <- constituents[, c(
    lapply(setNames(scalar_cols, scalar_cols), function(col) .uniq1(get(col))),
    list(n_nuts3_distinct = uniqueN(na.omit(cd_nuts3)))
  ), by = .(cd_commune_2025 = cd_refnis_new)]

  # cd_nuts_lau: only copy for 1:1 changes (single constituent)
  lau_singles <- constituents[, {
    if (.N == 1L) .(cd_nuts_lau = cd_nuts_lau) else .(cd_nuts_lau = NA_character_)
  }, by = .(cd_commune_2025 = cd_refnis_new)]
  agg <- merge(agg, lau_singles, by = "cd_commune_2025", all.x = TRUE)

  # Warn for ambiguous fusions (cross-NUTS3 mergers)
  ambig <- agg[n_nuts3_distinct > 1L]
  if (nrow(ambig) > 0L) {
    warn(
      sprintf(
        paste0("%d NIS 2025 commune(s) fuse localities from multiple NUTS3_2021 regions; ",
               "cd_nuts3 set to NA for: %s"),
        nrow(ambig), paste(sort(ambig$cd_commune_2025), collapse = ", ")
      ),
      class = "rcl_ambiguous_backfill"
    )
  }

  # --- Assemble full lookup: 2025 commune -> NUTS 2021 columns ---
  changed_lkp <- agg[, c("cd_commune_2025", nuts_cols), with = FALSE]
  setnames(changed_lkp, "cd_commune_2025", "cd_commune")

  lookup <- rbindlist(list(unch_lkp, changed_lkp), use.names = TRUE)

  # --- Merge back (merge() returns a new table; no need to copy first) ---
  result <- merge(master_2025, lookup, by = "cd_commune", all.x = TRUE)

  n_nuts3 <- sum(!is.na(result$cd_nuts3))
  message(sprintf("  NIS 2025 -> NUTS 2021: %d/%d communes with cd_nuts3 (%d ambiguous)",
                  n_nuts3, nrow(result), nrow(ambig)))

  result
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


# ==============================================================================
# Phase 1 additions: build_entities_table() + build_crosswalks()
# These are called from build_master_table() after the three unified flat
# tables are assembled.  They are also callable standalone (e.g. to regenerate
# entities.rds / crosswalks.rds from an existing load_master_data() snapshot
# without requiring the raw source files).
# ==============================================================================

#' Build the entities table from unified communes + postal tables
#'
#' Returns a \code{data.table(classification_id chr, code chr, name_fr chr,
#' name_nl chr)} -- one row per known code for each classification node.
#' Uses \code{.node_reference_codes()} so the logic stays in one place.
#'
#' @param communes Unified communes data.table (all nis_version values stacked)
#' @param postal   Unified postal data.table
#' @return data.table with columns classification_id, code, name_fr, name_nl
#' @noRd
build_entities_table <- function(communes, postal) {
  md_tmp <- list(communes = communes, postal = postal)
  rbindlist(
    lapply(names(CLASSIFICATION_NODES), function(id) {
      rc <- .node_reference_codes(id, md_tmp)
      if (is.null(rc)) return(NULL)
      rc[, `:=`(classification_id = id, code = as.character(code))]
      rc[, .(classification_id, code, name_fr, name_nl)]
    }),
    use.names = TRUE, fill = FALSE
  )
}


#' Build the crosswalks table from unified flat tables
#'
#' Produces one row per primitive code link for every directly-executable
#' single hop (one \code{(from_id, to_id)} edge):
#' \code{(from_id, to_id, code_from, code_to, relation, nature)}.
#' All codes are stored as \strong{character}; the engine re-coerces to the
#' canonical type on output via \code{.node_coerce()}.
#'
#' Key design decisions:
#' \itemize{
#'   \item Built from the already-assembled flat tables (communes, postal,
#'     nis_changes), NOT by calling the runtime engine -- so
#'     \code{rebuild_master_data()} remains functional after the handlers are
#'     removed in Phase 2.
#'   \item \code{NIS_COMMUNE_2025 -> NUTS3_2021} replicates the
#'     \code{.convert_comm2025_to_nuts3_2021()} expansion logic directly.
#'   \item Temporal edges carry \code{nature} (UNCHANGED/FUSION/CHANGE_*);
#'     all others carry \code{NA_character_}.
#' }
#'
#' @param communes   Unified communes data.table
#' @param postal     Unified postal data.table
#' @param nis_changes Unified nis_changes data.table
#' @return data.table with columns from_id, to_id, code_from, code_to,
#'   relation, nature
#' @noRd
build_crosswalks <- function(communes, postal, nis_changes) {

  # --- Version slices ---
  m19  <- communes[nis_version == VER_2019]
  m25  <- communes[nis_version == VER_2025]
  mb19 <- communes[nis_version == VER_BEFORE_2019]
  has_b19 <- nrow(mb19) > 0L

  p19 <- postal[nis_version == VER_2019]
  p25 <- postal[nis_version == VER_2025]

  # --- Relation lookup (forward + auto-reversed from CONVERSION_GRAPH_EDGES) ---
  .rel <- local({
    fwd <- lapply(CONVERSION_GRAPH_EDGES, function(e)
      list(from = e$from, to = e$to, rel = e$relation))
    rev_list <- lapply(CONVERSION_GRAPH_EDGES, function(e) {
      if (isTRUE(e$no_reverse)) return(NULL)
      rr <- switch(e$relation,
                   "1:1" = "1:1", "N:1" = "1:N", "1:N" = "N:1", "M:N" = "M:N",
                   NA_character_)
      list(from = e$to, to = e$from, rel = rr)
    })
    all_e <- c(fwd, Filter(Negate(is.null), rev_list))
    function(from_id, to_id) {
      for (e in all_e) if (e$from == from_id && e$to == to_id) return(e$rel)
      NA_character_
    }
  })

  # --- Low-level assembler ---
  .xw <- function(from_id, to_id, from_codes, to_codes, nature = NA_character_) {
    data.table(
      from_id   = from_id,
      to_id     = to_id,
      code_from = as.character(from_codes),
      code_to   = as.character(to_codes),
      relation  = .rel(from_id, to_id),
      nature    = as.character(nature)
    )
  }

  # Unique (from_col, to_col) pairs from a master slice.
  # Only drops rows where from_col is NA; rows with NA to_col are kept so
  # that unmappable source codes are represented in the crosswalk (parity
  # with the runtime engine which returns code_to = NA for such codes).
  .pairs_xw <- function(from_id, to_id, tbl, from_col, to_col) {
    p <- unique(tbl[!is.na(get(from_col)), .SD, .SDcols = c(from_col, to_col)])
    .xw(from_id, to_id, p[[from_col]], p[[to_col]])
  }

  xw <- list()

  # ---- POSTAL -> NIS -------------------------------------------------------
  # POSTAL -> NIS_COMMUNE_2019: all p19 postal codes (universe of POSTAL codes)
  xw[["POSTAL__NIS_COMMUNE_2019"]] <- .xw("POSTAL", "NIS_COMMUNE_2019",
                                            p19$cd_postal, p19$cd_commune_nis)

  # POSTAL -> NIS_COMMUNE_2025: universe = p19 postal codes, which is the
  # same set that .list_codes_for("POSTAL", md) and the entities table use.
  # Assumption: p25 codes <= p19 codes (i.e. no new postal codes were
  # introduced in the 2025 mapping).  Left-join so codes in p19 but absent
  # from p25 appear with code_to = NA, matching engine behaviour.
  p25_map  <- unique(p25[, .(cd_postal, cd_commune_nis)])
  p25_full <- merge(data.table(cd_postal = unique(p19$cd_postal)),
                    p25_map, by = "cd_postal", all.x = TRUE)
  xw[["POSTAL__NIS_COMMUNE_2025"]] <- .xw("POSTAL", "NIS_COMMUNE_2025",
                                            p25_full$cd_postal, p25_full$cd_commune_nis)

  # ---- NIS_COMMUNE_2019 -> * -----------------------------------------------
  xw[["NIS_COMMUNE_2019__NIS_ARRONDISSEMENT_2019"]] <- .pairs_xw(
    "NIS_COMMUNE_2019", "NIS_ARRONDISSEMENT_2019", m19, "cd_commune", "cd_arr")
  xw[["NIS_COMMUNE_2019__NIS_PROVINCE_2019"]] <- .pairs_xw(
    "NIS_COMMUNE_2019", "NIS_PROVINCE_2019",       m19, "cd_commune", "cd_province")
  xw[["NIS_COMMUNE_2019__NIS_REGION_2019"]] <- .pairs_xw(
    "NIS_COMMUNE_2019", "NIS_REGION_2019",         m19, "cd_commune", "cd_region")
  xw[["NIS_COMMUNE_2019__NUTS_LAU_2021"]] <- .pairs_xw(
    "NIS_COMMUNE_2019", "NUTS_LAU_2021",           m19, "cd_commune", "cd_nuts_lau")
  xw[["NIS_COMMUNE_2019__NUTS3_2021"]] <- .pairs_xw(
    "NIS_COMMUNE_2019", "NUTS3_2021",              m19, "cd_commune", "cd_nuts3")
  xw[["NIS_COMMUNE_2019__NUTS2_2021"]] <- .pairs_xw(
    "NIS_COMMUNE_2019", "NUTS2_2021",              m19, "cd_commune", "cd_nuts2")
  xw[["NIS_COMMUNE_2019__NUTS1_2021"]] <- .pairs_xw(
    "NIS_COMMUNE_2019", "NUTS1_2021",              m19, "cd_commune", "cd_nuts1")
  xw[["NIS_COMMUNE_2019__NUTS0"]] <- .xw(
    "NIS_COMMUNE_2019", "NUTS0",
    unique(m19$cd_commune), rep("BE", uniqueN(m19$cd_commune)))
  xw[["NIS_COMMUNE_2019__INTERNAL_ARRONDISSEMENT"]] <- .pairs_xw(
    "NIS_COMMUNE_2019", "INTERNAL_ARRONDISSEMENT", m19, "cd_commune", "cd_arr_internal")

  # NIS_COMMUNE_2019 -> NIS_COMMUNE_2025 (temporal, with nature)
  ch19 <- nis_changes[from_version == VER_2019,
                       .(cd_refnis_old, cd_refnis_new, nature)]
  unchanged_19 <- setdiff(unique(m19$cd_commune), ch19$cd_refnis_old)
  full_19_25 <- rbindlist(list(
    ch19,
    data.table(cd_refnis_old = unchanged_19,
               cd_refnis_new = unchanged_19,
               nature        = "UNCHANGED")
  ), use.names = TRUE)
  xw[["NIS_COMMUNE_2019__NIS_COMMUNE_2025"]] <- .xw(
    "NIS_COMMUNE_2019", "NIS_COMMUNE_2025",
    full_19_25$cd_refnis_old, full_19_25$cd_refnis_new, full_19_25$nature)

  # ---- NIS_COMMUNE_2025 -> * -----------------------------------------------
  xw[["NIS_COMMUNE_2025__NIS_ARRONDISSEMENT_2025"]] <- .pairs_xw(
    "NIS_COMMUNE_2025", "NIS_ARRONDISSEMENT_2025", m25, "cd_commune", "cd_arr")
  xw[["NIS_COMMUNE_2025__NIS_PROVINCE_2025"]] <- .pairs_xw(
    "NIS_COMMUNE_2025", "NIS_PROVINCE_2025",       m25, "cd_commune", "cd_province")
  xw[["NIS_COMMUNE_2025__NIS_REGION_2025"]] <- .pairs_xw(
    "NIS_COMMUNE_2025", "NIS_REGION_2025",         m25, "cd_commune", "cd_region")
  xw[["NIS_COMMUNE_2025__INTERNAL_ARRONDISSEMENT"]] <- .pairs_xw(
    "NIS_COMMUNE_2025", "INTERNAL_ARRONDISSEMENT", m25, "cd_commune", "cd_arr_internal")

  # NIS_COMMUNE_2025 -> NUTS3_2021 (1:N): 564 direct + 3 fusions via nis_changes
  direct_25_n3  <- unique(m25[!is.na(cd_nuts3), .(cd_commune, cd_nuts3)])
  na25_communes <- m25[is.na(cd_nuts3), unique(cd_commune)]
  if (length(na25_communes) > 0L) {
    ch_for_na  <- nis_changes[from_version == VER_2019 & cd_refnis_new %in% na25_communes,
                               .(cd_refnis_old, cd_refnis_new)]
    lkp19_n3   <- unique(m19[, .(cd_commune, cd_nuts3)])
    expanded25 <- merge(ch_for_na, lkp19_n3,
                        by.x = "cd_refnis_old", by.y = "cd_commune", all.x = TRUE)
    expanded25 <- unique(expanded25[!is.na(cd_nuts3),
                                    .(cd_commune = cd_refnis_new, cd_nuts3)])
    full_25_n3 <- rbindlist(list(direct_25_n3, expanded25), use.names = TRUE)
  } else {
    full_25_n3 <- direct_25_n3
  }
  xw[["NIS_COMMUNE_2025__NUTS3_2021"]] <- .xw(
    "NIS_COMMUNE_2025", "NUTS3_2021",
    full_25_n3$cd_commune, full_25_n3$cd_nuts3)

  # NIS_COMMUNE_2025 -> NIS_COMMUNE_2019 (reverse temporal, 1:N for fused communes)
  xw[["NIS_COMMUNE_2025__NIS_COMMUNE_2019"]] <- .xw(
    "NIS_COMMUNE_2025", "NIS_COMMUNE_2019",
    full_19_25$cd_refnis_new, full_19_25$cd_refnis_old, full_19_25$nature)

  # NIS_COMMUNE_2025 -> NUTS 2027
  xw[["NIS_COMMUNE_2025__NUTS3_2027"]] <- .pairs_xw(
    "NIS_COMMUNE_2025", "NUTS3_2027", m25, "cd_commune", "cd_nuts3_2027")
  xw[["NIS_COMMUNE_2025__NUTS2_2027"]] <- .pairs_xw(
    "NIS_COMMUNE_2025", "NUTS2_2027", m25, "cd_commune", "cd_nuts2_2027")
  xw[["NIS_COMMUNE_2025__NUTS1_2027"]] <- .pairs_xw(
    "NIS_COMMUNE_2025", "NUTS1_2027", m25, "cd_commune", "cd_nuts1_2027")

  # ---- NIS_ARRONDISSEMENT_2019 -> * ----------------------------------------
  # Verviers (63000): 1:N for NUTS3 and INTERNAL (2 rows each)
  xw[["NIS_ARRONDISSEMENT_2019__NUTS3_2021"]] <- .pairs_xw(
    "NIS_ARRONDISSEMENT_2019", "NUTS3_2021",              m19, "cd_arr", "cd_nuts3")
  xw[["NIS_ARRONDISSEMENT_2019__INTERNAL_ARRONDISSEMENT"]] <- .pairs_xw(
    "NIS_ARRONDISSEMENT_2019", "INTERNAL_ARRONDISSEMENT", m19, "cd_arr", "cd_arr_internal")
  xw[["NIS_ARRONDISSEMENT_2019__NIS_PROVINCE_2019"]] <- .pairs_xw(
    "NIS_ARRONDISSEMENT_2019", "NIS_PROVINCE_2019",       m19, "cd_arr", "cd_province")

  # ---- NIS_ARRONDISSEMENT_2025 -> * ----------------------------------------
  xw[["NIS_ARRONDISSEMENT_2025__NIS_PROVINCE_2025"]] <- .pairs_xw(
    "NIS_ARRONDISSEMENT_2025", "NIS_PROVINCE_2025",       m25, "cd_arr", "cd_province")

  # ---- NIS_PROVINCE -> NIS_REGION (M:N: Brabant 20000 spans 3 regions) -----
  xw[["NIS_PROVINCE_2019__NIS_REGION_2019"]] <- .pairs_xw(
    "NIS_PROVINCE_2019", "NIS_REGION_2019",       m19, "cd_province", "cd_region")
  xw[["NIS_PROVINCE_2025__NIS_REGION_2025"]] <- .pairs_xw(
    "NIS_PROVINCE_2025", "NIS_REGION_2025",       m25, "cd_province", "cd_region")

  # ---- NUTS 2021 hierarchy -------------------------------------------------
  xw[["NUTS3_2021__NUTS2_2021"]] <- .pairs_xw(
    "NUTS3_2021", "NUTS2_2021",              m19, "cd_nuts3", "cd_nuts2")
  xw[["NUTS3_2021__INTERNAL_ARRONDISSEMENT"]] <- .pairs_xw(
    "NUTS3_2021", "INTERNAL_ARRONDISSEMENT", m19, "cd_nuts3", "cd_arr_internal")
  xw[["NUTS3_2021__NIS_ARRONDISSEMENT_2019"]] <- .pairs_xw(
    "NUTS3_2021", "NIS_ARRONDISSEMENT_2019", m19, "cd_nuts3", "cd_arr")
  xw[["NUTS2_2021__NUTS1_2021"]] <- .pairs_xw(
    "NUTS2_2021", "NUTS1_2021", m19, "cd_nuts2", "cd_nuts1")
  xw[["NUTS1_2021__NUTS0"]] <- .pairs_xw(
    "NUTS1_2021", "NUTS0",      m19, "cd_nuts1", "cd_nuts0")

  # NUTS_LAU_2021 bidirectional
  xw[["NUTS_LAU_2021__NIS_COMMUNE_2019"]] <- .pairs_xw(
    "NUTS_LAU_2021", "NIS_COMMUNE_2019", m19, "cd_nuts_lau", "cd_commune")
  xw[["NUTS_LAU_2021__NUTS3_2021"]] <- .pairs_xw(
    "NUTS_LAU_2021", "NUTS3_2021",       m19, "cd_nuts_lau", "cd_nuts3")

  xw[["INTERNAL_ARRONDISSEMENT__NUTS3_2021"]] <- .pairs_xw(
    "INTERNAL_ARRONDISSEMENT", "NUTS3_2021", m19, "cd_arr_internal", "cd_nuts3")

  # ---- NUTS 2027 hierarchy -------------------------------------------------
  xw[["NUTS3_2027__NUTS2_2027"]] <- .pairs_xw(
    "NUTS3_2027", "NUTS2_2027", m25, "cd_nuts3_2027", "cd_nuts2_2027")
  xw[["NUTS2_2027__NUTS1_2027"]] <- .pairs_xw(
    "NUTS2_2027", "NUTS1_2027", m25, "cd_nuts2_2027", "cd_nuts1_2027")
  xw[["NUTS1_2027__NUTS0"]] <- .pairs_xw(
    "NUTS1_2027", "NUTS0",      m25, "cd_nuts1_2027", "cd_nuts0_2027")

  # ---- NIS BEFORE_2019 (optional -- only when BEFORE_2019 slice is loaded) --
  if (has_b19) {
    ch_b19 <- nis_changes[from_version == VER_BEFORE_2019,
                           .(cd_refnis_old, cd_refnis_new, nature)]
    unchanged_b19 <- intersect(unique(mb19$cd_commune), unique(m19$cd_commune))

    # Orphaned: in BEFORE_2019 but neither in nis_changes nor in NIS 2019.
    # Engine returns code_to = NA for these; crosswalk must match.
    orphaned_b19 <- setdiff(unique(mb19$cd_commune),
                             union(ch_b19$cd_refnis_old, unchanged_b19))

    parts <- list(
      data.table(cd_refnis_old = unchanged_b19,
                 cd_refnis_new = unchanged_b19,
                 nature        = "UNCHANGED")
    )
    if (nrow(ch_b19) > 0L)    parts <- c(list(ch_b19), parts)
    if (length(orphaned_b19) > 0L) {
      parts <- c(parts, list(data.table(cd_refnis_old = orphaned_b19,
                                        cd_refnis_new = NA_integer_,
                                        nature        = NA_character_)))
    }
    full_b19_19 <- rbindlist(parts, use.names = TRUE)

    xw[["NIS_COMMUNE_BEFORE_2019__NIS_COMMUNE_2019"]] <- .xw(
      "NIS_COMMUNE_BEFORE_2019", "NIS_COMMUNE_2019",
      full_b19_19$cd_refnis_old, full_b19_19$cd_refnis_new, full_b19_19$nature)

    xw[["NIS_COMMUNE_BEFORE_2019__NIS_ARRONDISSEMENT_BEFORE_2019"]] <- .pairs_xw(
      "NIS_COMMUNE_BEFORE_2019", "NIS_ARRONDISSEMENT_BEFORE_2019",
      mb19, "cd_commune", "cd_arr")
    xw[["NIS_COMMUNE_BEFORE_2019__NIS_PROVINCE_BEFORE_2019"]] <- .pairs_xw(
      "NIS_COMMUNE_BEFORE_2019", "NIS_PROVINCE_BEFORE_2019",
      mb19, "cd_commune", "cd_province")
    xw[["NIS_COMMUNE_BEFORE_2019__NIS_REGION_BEFORE_2019"]] <- .pairs_xw(
      "NIS_COMMUNE_BEFORE_2019", "NIS_REGION_BEFORE_2019",
      mb19, "cd_commune", "cd_region")
    xw[["NIS_COMMUNE_BEFORE_2019__NUTS3_2021"]] <- .pairs_xw(
      "NIS_COMMUNE_BEFORE_2019", "NUTS3_2021",
      mb19, "cd_commune", "cd_nuts3")
    xw[["NIS_COMMUNE_BEFORE_2019__NUTS2_2021"]] <- .pairs_xw(
      "NIS_COMMUNE_BEFORE_2019", "NUTS2_2021",
      mb19, "cd_commune", "cd_nuts2")
    xw[["NIS_COMMUNE_BEFORE_2019__INTERNAL_ARRONDISSEMENT"]] <- .pairs_xw(
      "NIS_COMMUNE_BEFORE_2019", "INTERNAL_ARRONDISSEMENT",
      mb19, "cd_commune", "cd_arr_internal")

    xw[["NIS_ARRONDISSEMENT_BEFORE_2019__NIS_PROVINCE_BEFORE_2019"]] <- .pairs_xw(
      "NIS_ARRONDISSEMENT_BEFORE_2019", "NIS_PROVINCE_BEFORE_2019",
      mb19, "cd_arr", "cd_province")
    xw[["NIS_PROVINCE_BEFORE_2019__NIS_REGION_BEFORE_2019"]] <- .pairs_xw(
      "NIS_PROVINCE_BEFORE_2019", "NIS_REGION_BEFORE_2019",
      mb19, "cd_province", "cd_region")
  }

  rbindlist(Filter(Negate(is.null), xw), use.names = TRUE, fill = FALSE)
}
