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
#' @noRd
.extract_postal_map <- function(dt, label = "postal file") {
  .find_col <- function(pattern, role) {
    cols <- grep(pattern, names(dt), value = TRUE, ignore.case = TRUE)
    if (length(cols) == 0L) {
      abort(
        sprintf("%s: cannot find column for '%s' (pattern: %s). Available columns: %s",
                label, role, pattern, paste(names(dt), collapse = ", ")),
        class = "rcl_invalid_input"
      )
    }
    # Require a UNIQUE match: taking the first grep hit could silently bind the
    # wrong column (e.g. SHORT_NAME_FR before NAME_FR) on a future file layout
    # (audit M8). Fail loudly instead.
    if (length(cols) > 1L) {
      abort(
        sprintf("%s: ambiguous column for '%s' (pattern: %s) matched %d columns: %s. Tighten the pattern.",
                label, role, pattern, length(cols), paste(cols, collapse = ", ")),
        class = "rcl_invalid_input"
      )
    }
    cols
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
# Assert that `keys` uniquely identify rows of `dt`; abort otherwise (audit M7).
# Run after unique() has collapsed fully-identical rows, so any remaining
# duplicate key signals conflicting attributes for the same entity -- a source
# data problem that must fail the build rather than silently multiply downstream.
#' @noRd
.assert_unique_keys <- function(dt, keys, label) {
  n_dup <- nrow(dt[, .N, by = keys][N > 1L])
  if (n_dup > 0L)
    abort(
      sprintf("Duplicate keys in %s: %d key(s) appear more than once. Check the source data.",
              label, n_dup),
      class = "rcl_duplicate_keys", label = label, n_duplicates = n_dup
    )
  invisible(dt)
}

# Assert a built table carries its required columns (RDS-contract guard, audit
# M8). .validate_commune_schema() covered only `communes`; the other saved tables
# (postal, nis_changes, crosswalks) were unchecked.
#' @noRd
.assert_cols <- function(dt, required, label) {
  missing <- setdiff(required, names(dt))
  if (length(missing) > 0L)
    abort(
      sprintf("%s is missing required column(s): %s. Available: %s",
              label, paste(missing, collapse = ", "), paste(names(dt), collapse = ", ")),
      class = "rcl_schema_error", label = label, missing = missing
    )
  invisible(dt)
}

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

# Convert integer/numeric code columns (cd_* / code*) of a flat table to
# character, in place. Codes are identifiers, not quantities: as of v1.2.0 every
# classification code is stored and returned as character (see
# CLASSIFICATION_NODES$code_type and .node_coerce, R/00b_registry.R). This runs at
# the END of build_master_table so the integer arithmetic used to DERIVE codes
# (cd_arr %/% 1000L, REFNIS level classification by modulo) has already happened.
# Already-character columns (NUTS "BE100", NBB "21") are left untouched, so the
# helper is safe to apply to any flat table. NA is preserved.
.stringify_code_columns <- function(dt) {
  if (is.null(dt)) return(invisible(dt))
  code_cols <- grep("^cd_|^code", names(dt), value = TRUE)
  for (col in code_cols) {
    if (is.numeric(dt[[col]]))
      set(dt, j = col, value = as.character(dt[[col]]))
  }
  invisible(dt)
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
  nuts_comm[, cd_nis_country := 1000L]

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
    nuts_comm_pre2019[, cd_nis_country := 1000L]

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
    comm2025_nuts27[, cd_nis_country := 1000L]

    master_2025 <- merge(comm_2025, comm2025_nuts27, by = "cd_commune", all.x = TRUE)
    message(sprintf("  NIS 2025 -> NUTS 2027: %d communes mapped", nrow(comm2025_nuts27)))
  }

  if (!"cd_nis_country" %in% names(master_2025))
    master_2025[, cd_nis_country := 1000L]

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
  # unique() collapses fully-identical duplicate rows; the assertion then catches
  # genuine key conflicts (same commune+version carrying different attributes),
  # so a duplicated source refresh fails loudly instead of multiplying through
  # merges downstream (audit M7).
  communes_unified <- unique(rbindlist(communes_list, use.names = TRUE, fill = TRUE))
  .assert_unique_keys(communes_unified, c("cd_commune", "nis_version"),
                      "communes (cd_commune, nis_version)")

  # postal: NIS 2019 + NIS 2025
  postal_unified <- rbindlist(list(postal_map_2019, postal_map_2025), use.names = TRUE)

  # nis_changes: 2019->2025 + BEFORE_2019->2019
  nis_changes_unified <- unique(copy(nis_change_map))
  if (!is.null(nis_change_before2019)) {
    before2019_std <- data.table(
      cd_refnis_old = nis_change_before2019$cd_refnis_before2019,
      cd_refnis_new = nis_change_before2019$cd_refnis_2019,
      nature        = nis_change_before2019$nature,   # from source NATURE, not hardcoded
      from_version  = VER_BEFORE_2019
    )
    nis_changes_unified <- unique(rbindlist(list(nis_changes_unified, before2019_std),
                                     use.names = TRUE))
  }
  .assert_unique_keys(nis_changes_unified, c("from_version", "cd_refnis_old"),
                      "nis_changes (from_version, cd_refnis_old)")

  # RDS-contract column guards for the saved tables beyond communes (audit M8).
  .assert_cols(postal_unified,
               c("cd_postal", "cd_commune_nis", "nis_version"), "postal")
  .assert_cols(nis_changes_unified,
               c("cd_refnis_old", "cd_refnis_new", "nature", "from_version"), "nis_changes")

  # --- 9b. Build normalised entities + crosswalks tables (ADDITIVE) ---
  message("  Building entities table...")
  entities   <- build_entities_table(communes_unified, postal_unified)
  message("  Building crosswalks table...")
  crosswalks <- build_crosswalks(communes_unified, postal_unified, nis_changes_unified)
  .assert_cols(crosswalks,
               c("from_id", "to_id", "code_from", "code_to", "nature"), "crosswalks")

  # --- 9c. Stringify NIS/POSTAL code columns (v1.2.0) ---
  # entities$code and crosswalks$code_from/code_to are already character (they
  # stack mixed NIS/NUTS codes at build time), so only the three flat NIS/POSTAL
  # tables carry integer code columns that must be converted for the all-character
  # contract. See .stringify_code_columns() above.
  .stringify_code_columns(communes_unified)
  .stringify_code_columns(postal_unified)
  .stringify_code_columns(nis_changes_unified)

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

  # Defensive fallback: since the 1995 Brabant split every province (incl. the
  # split Brabant provinces and the Brussels pseudo-province) carries a non-NA
  # cd_region from the province merge above, so the assignments below normally
  # do nothing.  They remain as a safety net to resolve region by arrondissement
  # should any commune ever arrive without a province-derived region.
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
#'   collect the NUTS_DISTRICT_2021 of all constituent 2019 communes and assign it
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
        paste0("%d NIS 2025 commune(s) fuse localities from multiple NUTS_DISTRICT_2021 regions; ",
               "cd_nuts3 set to NA for: %s"),
        nrow(ambig), paste(sort(ambig$cd_commune_2025), collapse = ", ")
      ),
      class = "rcl_ambiguous_backfill"
    )
  }

  # Warn for the mirror case: a changed commune whose constituents ALL lack a
  # known NUTS_DISTRICT_2021 (n_distinct == 0). cd_nuts3 is NA here too, but for a
  # different reason (no source, not conflict) -- surface it rather than dropping
  # it silently (audit, low-severity).
  missing_all <- agg[n_nuts3_distinct == 0L]
  if (nrow(missing_all) > 0L) {
    warn(
      sprintf(
        paste0("%d NIS 2025 commune(s) have no constituent 2019 commune with a known ",
               "NUTS_DISTRICT_2021; cd_nuts3 set to NA for: %s"),
        nrow(missing_all), paste(sort(missing_all$cd_commune_2025), collapse = ", ")
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
#'   \item \code{NIS_MUNICIPALITY_2025 -> NUTS_DISTRICT_2021} replicates the
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
  # POSTAL -> NIS_MUNICIPALITY_2019: all p19 postal codes (universe of POSTAL codes)
  xw[["POSTAL__NIS_MUNICIPALITY_2019"]] <- .xw("POSTAL", "NIS_MUNICIPALITY_2019",
                                            p19$cd_postal, p19$cd_commune_nis)

  # POSTAL -> NIS_MUNICIPALITY_2025: universe = p19 postal codes, which is the
  # same set that .list_codes_for("POSTAL", md) and the entities table use.
  # Assumption: p25 codes <= p19 codes (i.e. no new postal codes were
  # introduced in the 2025 mapping).  Left-join so codes in p19 but absent
  # from p25 appear with code_to = NA, matching engine behaviour.
  p25_map  <- unique(p25[, .(cd_postal, cd_commune_nis)])
  # The POSTAL universe is p19's postal codes. Assert p25 introduces no NEW postal
  # code, otherwise it would be silently dropped from POSTAL -> NIS_2025 (audit M8).
  new_p25 <- setdiff(unique(p25_map$cd_postal), unique(p19$cd_postal))
  if (length(new_p25) > 0L)
    abort(sprintf(
      paste0("%d postal code(s) exist in the 2025 mapping but not in 2019 and would be ",
             "dropped from POSTAL -> NIS_MUNICIPALITY_2025: %s%s. Union the postal universes."),
      length(new_p25), paste(head(sort(new_p25), 5L), collapse = ", "),
      if (length(new_p25) > 5L) ", ..." else ""),
      class = "rcl_incomplete_universe")
  p25_full <- merge(data.table(cd_postal = unique(p19$cd_postal)),
                    p25_map, by = "cd_postal", all.x = TRUE)
  xw[["POSTAL__NIS_MUNICIPALITY_2025"]] <- .xw("POSTAL", "NIS_MUNICIPALITY_2025",
                                            p25_full$cd_postal, p25_full$cd_commune_nis)

  # ---- NIS_MUNICIPALITY_2019 -> * -----------------------------------------------
  xw[["NIS_MUNICIPALITY_2019__NIS_DISTRICT_2019"]] <- .pairs_xw(
    "NIS_MUNICIPALITY_2019", "NIS_DISTRICT_2019", m19, "cd_commune", "cd_arr")
  xw[["NIS_MUNICIPALITY_2019__NIS_PROVINCE_2019"]] <- .pairs_xw(
    "NIS_MUNICIPALITY_2019", "NIS_PROVINCE_2019",       m19, "cd_commune", "cd_province")
  xw[["NIS_MUNICIPALITY_2019__NIS_REGION_2019"]] <- .pairs_xw(
    "NIS_MUNICIPALITY_2019", "NIS_REGION_2019",         m19, "cd_commune", "cd_region")
  xw[["NIS_MUNICIPALITY_2019__NUTS_MUNICIPALITY_2021"]] <- .pairs_xw(
    "NIS_MUNICIPALITY_2019", "NUTS_MUNICIPALITY_2021",           m19, "cd_commune", "cd_nuts_lau")
  xw[["NIS_MUNICIPALITY_2019__NUTS_DISTRICT_2021"]] <- .pairs_xw(
    "NIS_MUNICIPALITY_2019", "NUTS_DISTRICT_2021",              m19, "cd_commune", "cd_nuts3")
  xw[["NIS_MUNICIPALITY_2019__NUTS_PROVINCE_2021"]] <- .pairs_xw(
    "NIS_MUNICIPALITY_2019", "NUTS_PROVINCE_2021",              m19, "cd_commune", "cd_nuts2")
  xw[["NIS_MUNICIPALITY_2019__NUTS_REGION_2021"]] <- .pairs_xw(
    "NIS_MUNICIPALITY_2019", "NUTS_REGION_2021",              m19, "cd_commune", "cd_nuts1")
  xw[["NIS_MUNICIPALITY_2019__NUTS_COUNTRY"]] <- .xw(
    "NIS_MUNICIPALITY_2019", "NUTS_COUNTRY",
    unique(m19$cd_commune), rep("BE", uniqueN(m19$cd_commune)))
  xw[["NIS_MUNICIPALITY_2019__NBB_DISTRICT_2021"]] <- .pairs_xw(
    "NIS_MUNICIPALITY_2019", "NBB_DISTRICT_2021", m19, "cd_commune", "cd_arr_internal")

  # NIS_MUNICIPALITY_2019 -> NIS_MUNICIPALITY_2025 (temporal, with nature)
  ch19 <- nis_changes[from_version == VER_2019,
                       .(cd_refnis_old, cd_refnis_new, nature)]
  unchanged_19 <- setdiff(unique(m19$cd_commune), ch19$cd_refnis_old)
  full_19_25 <- rbindlist(list(
    ch19,
    data.table(cd_refnis_old = unchanged_19,
               cd_refnis_new = unchanged_19,
               nature        = "UNCHANGED")
  ), use.names = TRUE)

  # Orphaned 2025 communes (audit C4): a 2025 commune that is neither a change
  # TARGET nor an unchanged-2019 code has no 2019 lineage in REFNIS_CHANGE_2025.
  # The 2019->2025 forward domain is m19 (complete by construction), but the
  # REVERSE 2025->2019 crosswalk is keyed on the 2025 side, so such a commune
  # would silently vanish from it (no row -> engine returns nothing). Mirror the
  # BEFORE_2019 orphan handling: emit an explicit code_to = NA row (matching the
  # runtime engine) and warn, instead of dropping it silently.
  orphaned_25 <- setdiff(unique(m25$cd_commune),
                         union(ch19$cd_refnis_new, unchanged_19))
  if (length(orphaned_25) > 0L) {
    warn(
      sprintf(
        paste0("%d NIS 2025 commune(s) have no 2019 lineage in REFNIS_CHANGE_2025 ",
               "(absent from both change targets and the unchanged-2019 set); ",
               "reverse 2025->2019 code_to set to NA for: %s"),
        length(orphaned_25), paste(sort(orphaned_25), collapse = ", ")
      ),
      class = "rcl_orphaned_codes"
    )
  }

  xw[["NIS_MUNICIPALITY_2019__NIS_MUNICIPALITY_2025"]] <- .xw(
    "NIS_MUNICIPALITY_2019", "NIS_MUNICIPALITY_2025",
    full_19_25$cd_refnis_old, full_19_25$cd_refnis_new, full_19_25$nature)

  # ---- NIS_MUNICIPALITY_2025 -> * -----------------------------------------------
  xw[["NIS_MUNICIPALITY_2025__NIS_DISTRICT_2025"]] <- .pairs_xw(
    "NIS_MUNICIPALITY_2025", "NIS_DISTRICT_2025", m25, "cd_commune", "cd_arr")
  xw[["NIS_MUNICIPALITY_2025__NIS_PROVINCE_2025"]] <- .pairs_xw(
    "NIS_MUNICIPALITY_2025", "NIS_PROVINCE_2025",       m25, "cd_commune", "cd_province")
  xw[["NIS_MUNICIPALITY_2025__NIS_REGION_2025"]] <- .pairs_xw(
    "NIS_MUNICIPALITY_2025", "NIS_REGION_2025",         m25, "cd_commune", "cd_region")
  xw[["NIS_MUNICIPALITY_2025__NBB_DISTRICT_2021"]] <- .pairs_xw(
    "NIS_MUNICIPALITY_2025", "NBB_DISTRICT_2021", m25, "cd_commune", "cd_arr_internal")

  # NIS_MUNICIPALITY_2025 -> NUTS_DISTRICT_2021 (1:N): 564 direct + 3 fusions via nis_changes
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
  xw[["NIS_MUNICIPALITY_2025__NUTS_DISTRICT_2021"]] <- .xw(
    "NIS_MUNICIPALITY_2025", "NUTS_DISTRICT_2021",
    full_25_n3$cd_commune, full_25_n3$cd_nuts3)

  # NIS_MUNICIPALITY_2025 -> NIS_MUNICIPALITY_2019 (reverse temporal, 1:N for fused
  # communes). Orphaned 2025 communes (no 2019 lineage, audit C4) get an explicit
  # code_to = NA row so they are not silently missing from the reverse crosswalk.
  rev_from   <- c(full_19_25$cd_refnis_new, orphaned_25)
  rev_to     <- c(full_19_25$cd_refnis_old, rep(NA_integer_,   length(orphaned_25)))
  rev_nature <- c(full_19_25$nature,        rep(NA_character_, length(orphaned_25)))
  xw[["NIS_MUNICIPALITY_2025__NIS_MUNICIPALITY_2019"]] <- .xw(
    "NIS_MUNICIPALITY_2025", "NIS_MUNICIPALITY_2019",
    rev_from, rev_to, rev_nature)

  # NIS_MUNICIPALITY_2025 -> NUTS 2027
  xw[["NIS_MUNICIPALITY_2025__NUTS_DISTRICT_2027"]] <- .pairs_xw(
    "NIS_MUNICIPALITY_2025", "NUTS_DISTRICT_2027", m25, "cd_commune", "cd_nuts3_2027")
  xw[["NIS_MUNICIPALITY_2025__NUTS_PROVINCE_2027"]] <- .pairs_xw(
    "NIS_MUNICIPALITY_2025", "NUTS_PROVINCE_2027", m25, "cd_commune", "cd_nuts2_2027")
  xw[["NIS_MUNICIPALITY_2025__NUTS_REGION_2027"]] <- .pairs_xw(
    "NIS_MUNICIPALITY_2025", "NUTS_REGION_2027", m25, "cd_commune", "cd_nuts1_2027")

  # ---- NIS_DISTRICT_2019 -> * ----------------------------------------
  # Verviers (63000): 1:N for NUTS3 and INTERNAL (2 rows each)
  xw[["NIS_DISTRICT_2019__NUTS_DISTRICT_2021"]] <- .pairs_xw(
    "NIS_DISTRICT_2019", "NUTS_DISTRICT_2021",              m19, "cd_arr", "cd_nuts3")
  xw[["NIS_DISTRICT_2019__NBB_DISTRICT_2021"]] <- .pairs_xw(
    "NIS_DISTRICT_2019", "NBB_DISTRICT_2021", m19, "cd_arr", "cd_arr_internal")
  xw[["NIS_DISTRICT_2019__NIS_PROVINCE_2019"]] <- .pairs_xw(
    "NIS_DISTRICT_2019", "NIS_PROVINCE_2019",       m19, "cd_arr", "cd_province")

  # ---- NIS_DISTRICT_2025 -> * ----------------------------------------
  xw[["NIS_DISTRICT_2025__NIS_PROVINCE_2025"]] <- .pairs_xw(
    "NIS_DISTRICT_2025", "NIS_PROVINCE_2025",       m25, "cd_arr", "cd_province")

  # ---- NIS_PROVINCE -> NIS_REGION (N:1: each province nests in one region) --
  xw[["NIS_PROVINCE_2019__NIS_REGION_2019"]] <- .pairs_xw(
    "NIS_PROVINCE_2019", "NIS_REGION_2019",       m19, "cd_province", "cd_region")
  xw[["NIS_PROVINCE_2025__NIS_REGION_2025"]] <- .pairs_xw(
    "NIS_PROVINCE_2025", "NIS_REGION_2025",       m25, "cd_province", "cd_region")

  # ---- NUTS 2021 hierarchy -------------------------------------------------
  xw[["NUTS_DISTRICT_2021__NUTS_PROVINCE_2021"]] <- .pairs_xw(
    "NUTS_DISTRICT_2021", "NUTS_PROVINCE_2021",              m19, "cd_nuts3", "cd_nuts2")
  xw[["NUTS_DISTRICT_2021__NBB_DISTRICT_2021"]] <- .pairs_xw(
    "NUTS_DISTRICT_2021", "NBB_DISTRICT_2021", m19, "cd_nuts3", "cd_arr_internal")
  xw[["NUTS_DISTRICT_2021__NIS_DISTRICT_2019"]] <- .pairs_xw(
    "NUTS_DISTRICT_2021", "NIS_DISTRICT_2019", m19, "cd_nuts3", "cd_arr")
  xw[["NUTS_PROVINCE_2021__NUTS_REGION_2021"]] <- .pairs_xw(
    "NUTS_PROVINCE_2021", "NUTS_REGION_2021", m19, "cd_nuts2", "cd_nuts1")
  xw[["NUTS_REGION_2021__NUTS_COUNTRY"]] <- .pairs_xw(
    "NUTS_REGION_2021", "NUTS_COUNTRY",      m19, "cd_nuts1", "cd_nuts0")

  # NUTS_MUNICIPALITY_2021 bidirectional
  xw[["NUTS_MUNICIPALITY_2021__NIS_MUNICIPALITY_2019"]] <- .pairs_xw(
    "NUTS_MUNICIPALITY_2021", "NIS_MUNICIPALITY_2019", m19, "cd_nuts_lau", "cd_commune")
  xw[["NUTS_MUNICIPALITY_2021__NUTS_DISTRICT_2021"]] <- .pairs_xw(
    "NUTS_MUNICIPALITY_2021", "NUTS_DISTRICT_2021",       m19, "cd_nuts_lau", "cd_nuts3")

  xw[["NBB_DISTRICT_2021__NUTS_DISTRICT_2021"]] <- .pairs_xw(
    "NBB_DISTRICT_2021", "NUTS_DISTRICT_2021", m19, "cd_arr_internal", "cd_nuts3")

  # ---- NUTS 2027 hierarchy -------------------------------------------------
  xw[["NUTS_DISTRICT_2027__NUTS_PROVINCE_2027"]] <- .pairs_xw(
    "NUTS_DISTRICT_2027", "NUTS_PROVINCE_2027", m25, "cd_nuts3_2027", "cd_nuts2_2027")
  xw[["NUTS_PROVINCE_2027__NUTS_REGION_2027"]] <- .pairs_xw(
    "NUTS_PROVINCE_2027", "NUTS_REGION_2027", m25, "cd_nuts2_2027", "cd_nuts1_2027")
  xw[["NUTS_REGION_2027__NUTS_COUNTRY"]] <- .pairs_xw(
    "NUTS_REGION_2027", "NUTS_COUNTRY",      m25, "cd_nuts1_2027", "cd_nuts0_2027")

  # ---- NUTS_DISTRICT_2021 -> NUTS_DISTRICT_2027 (derived, 1:N) --------------
  # Chain at commune level over NIS 2019 (NUTS 2021 is keyed to the 2019 commune
  # perimeter): 2019 commune -> cd_nuts3 (2021)  AND  -> 2025 commune -> cd_nuts3_2027.
  # The 3 cross-province fusion communes (46029, 46030, 71072) merge constituents
  # sitting in different 2021 NUTS3 regions, so a few 2021 NUTS3 codes acquire >1
  # 2027 target -> 1:N (e.g. BE211 -> {BE261, BE276}).
  # NB: build from m19 (NOT m25 alone) -- m25's backfilled cd_nuts3 is NA for the
  # ambiguous communes, which would silently drop precisely the ambiguous pairs.
  ch19_n27 <- nis_changes[from_version == VER_2019, .(cd_refnis_old, cd_refnis_new)]
  link2025 <- merge(data.table(cd_commune = unique(m19$cd_commune)),
                    ch19_n27, by.x = "cd_commune", by.y = "cd_refnis_old", all.x = TRUE)
  link2025[is.na(cd_refnis_new), cd_refnis_new := cd_commune]   # unchanged keep their code

  n3_2021 <- unique(m19[!is.na(cd_nuts3),      .(cd_commune, cd_nuts3)])
  n3_2027 <- unique(m25[!is.na(cd_nuts3_2027), .(cd_commune, cd_nuts3_2027)])

  chain <- merge(link2025, n3_2021, by = "cd_commune", all.x = FALSE)
  chain <- merge(chain, n3_2027, by.x = "cd_refnis_new", by.y = "cd_commune", all.x = FALSE)
  pairs_21_27 <- unique(chain[!is.na(cd_nuts3) & !is.na(cd_nuts3_2027),
                              .(cd_nuts3, cd_nuts3_2027)])

  xw[["NUTS_DISTRICT_2021__NUTS_DISTRICT_2027"]] <- .xw(
    "NUTS_DISTRICT_2021", "NUTS_DISTRICT_2027",
    pairs_21_27$cd_nuts3, pairs_21_27$cd_nuts3_2027)

  # NIS_MUNICIPALITY_2019 -> NUTS_DISTRICT_2027 (derived, N:1 for most; 1:N for the
  # 3 cross-province fusion zones whose NIS2019 constituents straddle NUTS2027 borders).
  # Reuses the same chain built above: cd_commune (NIS2019) -> cd_nuts3_2027 (via NIS2025).
  # Storing this as a direct crosswalk hop prevents the BFS from routing through
  # NUTS_DISTRICT_2021 -> NUTS_DISTRICT_2027 (which would introduce spurious ambiguity
  # for communes that are in a 1:N NUTS2021 zone but have a unique NUTS2027 target).
  pairs_19_27 <- unique(chain[!is.na(cd_nuts3_2027), .(cd_commune, cd_nuts3_2027)])
  xw[["NIS_MUNICIPALITY_2019__NUTS_DISTRICT_2027"]] <- .xw(
    "NIS_MUNICIPALITY_2019", "NUTS_DISTRICT_2027",
    as.character(pairs_19_27$cd_commune), pairs_19_27$cd_nuts3_2027)

  # ---- NIS_REGION -> NIS_COUNTRY ----------------------------------------------
  xw[["NIS_REGION_2019__NIS_COUNTRY"]] <- .pairs_xw(
    "NIS_REGION_2019", "NIS_COUNTRY", m19, "cd_region", "cd_nis_country")
  xw[["NIS_REGION_2025__NIS_COUNTRY"]] <- .pairs_xw(
    "NIS_REGION_2025", "NIS_COUNTRY", m25, "cd_region", "cd_nis_country")

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

    xw[["NIS_MUNICIPALITY_BEFORE_2019__NIS_MUNICIPALITY_2019"]] <- .xw(
      "NIS_MUNICIPALITY_BEFORE_2019", "NIS_MUNICIPALITY_2019",
      full_b19_19$cd_refnis_old, full_b19_19$cd_refnis_new, full_b19_19$nature)

    xw[["NIS_MUNICIPALITY_BEFORE_2019__NIS_DISTRICT_BEFORE_2019"]] <- .pairs_xw(
      "NIS_MUNICIPALITY_BEFORE_2019", "NIS_DISTRICT_BEFORE_2019",
      mb19, "cd_commune", "cd_arr")
    xw[["NIS_MUNICIPALITY_BEFORE_2019__NIS_PROVINCE_BEFORE_2019"]] <- .pairs_xw(
      "NIS_MUNICIPALITY_BEFORE_2019", "NIS_PROVINCE_BEFORE_2019",
      mb19, "cd_commune", "cd_province")
    xw[["NIS_MUNICIPALITY_BEFORE_2019__NIS_REGION_BEFORE_2019"]] <- .pairs_xw(
      "NIS_MUNICIPALITY_BEFORE_2019", "NIS_REGION_BEFORE_2019",
      mb19, "cd_commune", "cd_region")
    xw[["NIS_MUNICIPALITY_BEFORE_2019__NUTS_DISTRICT_2021"]] <- .pairs_xw(
      "NIS_MUNICIPALITY_BEFORE_2019", "NUTS_DISTRICT_2021",
      mb19, "cd_commune", "cd_nuts3")
    xw[["NIS_MUNICIPALITY_BEFORE_2019__NUTS_PROVINCE_2021"]] <- .pairs_xw(
      "NIS_MUNICIPALITY_BEFORE_2019", "NUTS_PROVINCE_2021",
      mb19, "cd_commune", "cd_nuts2")
    xw[["NIS_MUNICIPALITY_BEFORE_2019__NBB_DISTRICT_2021"]] <- .pairs_xw(
      "NIS_MUNICIPALITY_BEFORE_2019", "NBB_DISTRICT_2021",
      mb19, "cd_commune", "cd_arr_internal")

    xw[["NIS_DISTRICT_BEFORE_2019__NIS_PROVINCE_BEFORE_2019"]] <- .pairs_xw(
      "NIS_DISTRICT_BEFORE_2019", "NIS_PROVINCE_BEFORE_2019",
      mb19, "cd_arr", "cd_province")
    xw[["NIS_PROVINCE_BEFORE_2019__NIS_REGION_BEFORE_2019"]] <- .pairs_xw(
      "NIS_PROVINCE_BEFORE_2019", "NIS_REGION_BEFORE_2019",
      mb19, "cd_province", "cd_region")
    xw[["NIS_REGION_BEFORE_2019__NIS_COUNTRY"]] <- .pairs_xw(
      "NIS_REGION_BEFORE_2019", "NIS_COUNTRY", mb19, "cd_region", "cd_nis_country")
  }

  rbindlist(Filter(Negate(is.null), xw), use.names = TRUE, fill = FALSE)
}
