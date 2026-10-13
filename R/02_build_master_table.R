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

#' Validate a per-version municipalities sub-table against the expected schema
#'
#' Guards the unified municipalities table against silent column drift before
#' the version sub-tables are stacked. See MASTER_MUNICIPALITY_CORE_COLS /
#' MASTER_MUNICIPALITY_KNOWN_COLS in 00_config.R.
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
# M8). .validate_municipality_schema() covers only `municipalities`; the other
# saved tables (postal, nis_changes, crosswalks) are checked with this helper.
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

#' @param tbl   A per-version municipalities data.table (schema v2 names)
#' @param label Human-readable version label used in error messages
#' @return Invisibly TRUE; aborts with class \code{rcl_schema_error} otherwise
#' @noRd
.validate_municipality_schema <- function(tbl, label) {
  cols <- names(tbl)

  missing <- setdiff(MASTER_MUNICIPALITY_CORE_COLS, cols)
  if (length(missing) > 0L) {
    abort(
      sprintf("municipalities sub-table '%s' is missing required column(s): %s",
              label, paste(missing, collapse = ", ")),
      class = "rcl_schema_error", label = label, missing = missing
    )
  }

  unknown <- setdiff(cols, MASTER_MUNICIPALITY_KNOWN_COLS)
  if (length(unknown) > 0L) {
    abort(
      sprintf(paste0("municipalities sub-table '%s' has unexpected column(s): %s\n",
                     "If intended, add them to SCHEMA_V1_TO_V2$municipalities in 00_config.R."),
              label, paste(unknown, collapse = ", ")),
      class = "rcl_schema_error", label = label, unknown = unknown
    )
  }

  invisible(TRUE)
}

# Rename a build-time (v1-named) table to the schema v2 column names, in place.
# Single rename point shared with .migrate_schema_v1() (08_load_prebuilt.R); see
# SCHEMA_V1_TO_V2 in 00_config.R. Columns absent from `dt` are skipped.
.rename_to_schema_v2 <- function(dt, table) {
  map <- SCHEMA_V1_TO_V2[[table]]
  setnames(dt, names(map), unname(map), skip_absent = TRUE)
  invisible(dt)
}

# Convert integer/numeric code columns (cd_* / code*) of a flat table to
# character, in place. Codes are identifiers, not quantities: as of v1.2.0 every
# classification code is stored and returned as character (see
# CLASSIFICATION_NODES$code_type and .node_coerce, R/00b_registry.R). This runs at
# the END of build_master_table so the integer arithmetic used to DERIVE codes
# (REFNIS level classification by modulo, arrondissement %/% 1000L) has already happened.
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
#' Creates the unified flat tables: \code{municipalities} (all NIS versions),
#' \code{postal} (both postal mappings), \code{nis_changes} (all NIS version
#' transitions), \code{entities} and \code{crosswalks}. Column names follow the
#' schema v2 convention (see \code{SCHEMA_V1_TO_V2} in \file{R/00_config.R}).
#'
#' @param raw_data Named list of data.tables from load_all_raw_data()
#' @return list with the five unified flat tables plus build-time hierarchy
#'   intermediates. Only \code{entities} and \code{crosswalks} are persisted by
#'   [save_master_tables()]; the wide tables are build-time intermediates.
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

    if (!is.null(raw_data$REFNIS_CHANGE_BEFORE2019)) {
      nis_change_before2019 <- parse_refnis_change_before2019(raw_data$REFNIS_CHANGE_BEFORE2019)
    }

    # NUTS 2021 / NBB columns are inherited from the NIS 2019 commune each
    # BEFORE_2019 commune maps to (N:1 via REFNIS_CHANGE_BEFORE2019, identity
    # otherwise). Reading CONVERSION_NIS2019_NUTS2021 at a 2018 reference date
    # instead returned the NUTS 2016 codes (BE221, BE321, ...) and the pre-2019
    # LAU codes for the 87 Hainaut/Limburg communes recoded in 2019.
    before_to_2019 <- data.table(cd_commune = comm_before2019$cd_commune)
    before_to_2019[, cd_commune_2019 := cd_commune]
    if (!is.null(nis_change_before2019))
      before_to_2019[nis_change_before2019, on = .(cd_commune = cd_refnis_before2019),
                     cd_commune_2019 := i.cd_refnis_2019]
    inherited_cols <- c("cd_nuts_lau", "cd_nuts3", "cd_nuts2", "cd_nuts1", "cd_nuts0",
                        "cd_nis_country", "cd_arr_internal", "tx_nuts3_fr", "tx_nuts3_nl")
    nuts_from_2019 <- master_2019[, c("cd_commune", intersect(inherited_cols, names(master_2019))),
                                  with = FALSE]
    setnames(nuts_from_2019, "cd_commune", "cd_commune_2019")
    before_to_2019 <- merge(before_to_2019, nuts_from_2019, by = "cd_commune_2019", all.x = TRUE)
    unmapped <- before_to_2019[is.na(cd_nuts3), cd_commune]
    if (length(unmapped) > 0L)
      warn(sprintf(paste0("%d NIS BEFORE_2019 commune(s) have no NIS 2019 successor with a ",
                          "NUTS_DISTRICT_2021 code; NUTS columns set to NA for: %s"),
                   length(unmapped), paste(sort(unmapped), collapse = ", ")),
           class = "rcl_ambiguous_backfill")
    before_to_2019[, cd_commune_2019 := NULL]

    master_before2019 <- merge(comm_before2019, before_to_2019, by = "cd_commune", all.x = TRUE)

    message(sprintf("  NIS BEFORE_2019: %d communes", nrow(comm_before2019)))
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

  # --- 8. NIS change mapping (2019 -> 2025), schema v2 names ---
  nis_change_map <- nis_changes[, .(code_from = cd_refnis_old, code_to = cd_refnis_new, nature)]
  nis_change_map[, `:=`(version_from = VER_2019, version_to = VER_2025)]

  # --- 9. Unify into three flat tables ---

  # municipalities: NIS 2019 + BEFORE_2019 + 2025
  # The per-version sub-tables are built with source-oriented (v1) names; rename
  # them to schema v2 here, then validate each before stacking, so a
  # renamed/dropped column fails loudly instead of being silently NA-filled by
  # rbindlist(fill=TRUE).
  .rename_to_schema_v2(master_2019, "municipalities")
  .validate_municipality_schema(master_2019, "NIS 2019")
  if (!is.null(master_before2019)) {
    .rename_to_schema_v2(master_before2019, "municipalities")
    .validate_municipality_schema(master_before2019, "NIS BEFORE_2019")
  }
  .rename_to_schema_v2(master_2025, "municipalities")
  .validate_municipality_schema(master_2025, "NIS 2025")

  municipalities_list <- list(master_2019)
  if (!is.null(master_before2019)) municipalities_list <- c(municipalities_list, list(master_before2019))
  municipalities_list <- c(municipalities_list, list(master_2025))
  # unique() collapses fully-identical duplicate rows; the assertion then catches
  # genuine key conflicts (same municipality+version carrying different attributes),
  # so a duplicated source refresh fails loudly instead of multiplying through
  # merges downstream (audit M7).
  municipalities_unified <- unique(rbindlist(municipalities_list, use.names = TRUE, fill = TRUE))
  .assert_unique_keys(municipalities_unified, c("code_nis_municipality", "version"),
                      "municipalities (code_nis_municipality, version)")
  # Canonical column order: version, NIS hierarchy, NUTS 2021/2027, NBB.
  setcolorder(municipalities_unified,
              intersect(c("version", setdiff(MASTER_MUNICIPALITY_KNOWN_COLS, "version")),
                        names(municipalities_unified)))

  # postal: NIS 2019 + NIS 2025
  postal_unified <- rbindlist(list(postal_map_2019, postal_map_2025), use.names = TRUE)
  .rename_to_schema_v2(postal_unified, "postal")

  # nis_changes: 2019->2025 + BEFORE_2019->2019
  nis_changes_unified <- unique(copy(nis_change_map))
  if (!is.null(nis_change_before2019)) {
    before2019_std <- data.table(
      code_from    = nis_change_before2019$cd_refnis_before2019,
      code_to      = nis_change_before2019$cd_refnis_2019,
      nature       = nis_change_before2019$nature,   # from source NATURE, not hardcoded
      version_from = VER_BEFORE_2019,
      version_to   = VER_2019
    )
    nis_changes_unified <- unique(rbindlist(list(nis_changes_unified, before2019_std),
                                     use.names = TRUE))
  }
  .assert_unique_keys(nis_changes_unified, c("version_from", "code_from"),
                      "nis_changes (version_from, code_from)")

  # RDS-contract column guards for the saved tables beyond municipalities (audit M8).
  .assert_cols(postal_unified,
               c("code_postal", "code_nis_municipality", "version"), "postal")
  .assert_cols(nis_changes_unified,
               c("code_from", "code_to", "nature", "version_from", "version_to"), "nis_changes")

  # --- 9b. Build normalised entities + crosswalks tables ---
  message("  Building entities table...")
  entities   <- build_entities_table(municipalities_unified, postal_unified)
  message("  Building crosswalks table...")
  crosswalks <- build_crosswalks(municipalities_unified, postal_unified, nis_changes_unified)
  .assert_cols(crosswalks,
               c("classification_from", "classification_to", "code_from", "code_to", "nature"),
               "crosswalks")

  # --- 9c. Stringify NIS/POSTAL code columns (v1.2.0) ---
  # entities$code and crosswalks$code_from/code_to are already character (they
  # stack mixed NIS/NUTS codes at build time), so only the three flat NIS/POSTAL
  # tables carry integer code columns that must be converted for the all-character
  # contract. See .stringify_code_columns() above.
  .stringify_code_columns(municipalities_unified)
  .stringify_code_columns(postal_unified)
  .stringify_code_columns(nis_changes_unified)

  # --- 10. Assemble result ---
  result <- list(
    # Five unified flat tables (saved to RDS by save_master_tables)
    municipalities = municipalities_unified,
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
#' @return data.table with commune info and parent codes, using the
#'   source-oriented (v1) build-time names; renamed to schema v2 by
#'   \code{build_master_table()}.
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

  # Add version tag
  communes[, nis_version := version]

  # Reorder columns
  desired_cols <- c("cd_commune", "tx_commune_fr", "tx_commune_nl",
                    "cd_arr", "tx_arr_fr", "tx_arr_nl",
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
#' - Changed communes (in the 2019 -> 2025 changes from parse_nis_changes()):
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
#'   least \code{cd_refnis_old} and \code{cd_refnis_new} columns (build-time
#'   names; the persisted \code{nis_changes} table is assembled later, in step 8
#'   of \code{build_master_table}).
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
               "code_nuts_district_2021 set to NA for: %s"),
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
               "NUTS_DISTRICT_2021; code_nuts_district_2021 set to NA for: %s"),
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
  message(sprintf("  NIS 2025 -> NUTS 2021: %d/%d municipalities with a NUTS_DISTRICT_2021 code (%d ambiguous)",
                  n_nuts3, nrow(result), nrow(ambig)))

  result
}

#' Save the long-model master tables to the processed directory
#'
#' Saves \code{entities} and \code{crosswalks} (\code{MASTER_FLAT_TABLES}) as
#' RDS files, preserving all R types exactly. The wide build intermediates
#' (\code{municipalities}, \code{postal}, \code{nis_changes}) are not saved
#' since nbbbenuts 3.0.0; [wide_view()] rebuilds them. Call this after
#' build_master_table() to update the pre-built snapshot used by
#' load_master_data().
#'
#' @param master_data Output from build_master_table() or load_master_data()
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
#' Returns a \code{data.table(classification chr, code chr, label_fr chr,
#' label_nl chr)} -- one row per known code for each classification node.
#' Uses \code{.node_reference_codes()} so the logic stays in one place.
#'
#' @param municipalities Unified municipalities data.table (all versions stacked)
#' @param postal         Unified postal data.table
#' @return data.table with columns classification, code, label_fr, label_nl
#' @noRd
build_entities_table <- function(municipalities, postal) {
  md_tmp <- list(municipalities = municipalities, postal = postal)
  rbindlist(
    lapply(names(CLASSIFICATION_NODES), function(id) {
      rc <- .node_reference_codes(id, md_tmp)
      if (is.null(rc)) return(NULL)
      rc[, `:=`(classification = id, code = as.character(code))]
      rc[, .(classification, code, label_fr, label_nl)]
    }),
    use.names = TRUE, fill = FALSE
  )
}


#' Build the crosswalks table from unified flat tables
#'
#' Produces one row per primitive code link for every directly-executable
#' single hop (one \code{(classification_from, classification_to)} edge):
#' \code{(classification_from, classification_to, code_from, code_to, relation, nature)}.
#' All codes are stored as \strong{character}; the engine re-coerces to the
#' canonical type on output via \code{.node_coerce()}.
#'
#' Key design decisions:
#' \itemize{
#'   \item Built from the already-assembled flat tables (municipalities, postal,
#'     nis_changes), NOT by calling the runtime engine -- so
#'     \code{rebuild_master_data()} remains functional after the handlers are
#'     removed in Phase 2.
#'   \item \code{NIS_MUNICIPALITY_2025 -> NUTS_DISTRICT_2021} replicates the
#'     \code{.convert_comm2025_to_nuts3_2021()} expansion logic directly.
#'   \item Temporal edges carry \code{nature} (UNCHANGED/FUSION/CHANGE_*);
#'     all others carry \code{NA_character_}.
#' }
#'
#' @param municipalities Unified municipalities data.table
#' @param postal     Unified postal data.table
#' @param nis_changes Unified nis_changes data.table
#' @return data.table with columns classification_from, classification_to,
#'   code_from, code_to, relation, nature
#' @noRd
build_crosswalks <- function(municipalities, postal, nis_changes) {

  # --- Version slices ---
  m19  <- municipalities[version == VER_2019]
  m25  <- municipalities[version == VER_2025]
  mb19 <- municipalities[version == VER_BEFORE_2019]
  has_b19 <- nrow(mb19) > 0L

  p19 <- postal[version == VER_2019]
  p25 <- postal[version == VER_2025]

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
      classification_from = from_id,
      classification_to   = to_id,
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
                                            p19$code_postal, p19$code_nis_municipality)

  # POSTAL -> NIS_MUNICIPALITY_2025: universe = p19 postal codes, which is the
  # same set that .list_codes_for("POSTAL", md) and the entities table use.
  # Assumption: p25 codes <= p19 codes (i.e. no new postal codes were
  # introduced in the 2025 mapping).  Left-join so codes in p19 but absent
  # from p25 appear with code_to = NA, matching engine behaviour.
  p25_map  <- unique(p25[, .(code_postal, code_nis_municipality)])
  # The POSTAL universe is p19's postal codes. Assert p25 introduces no NEW postal
  # code, otherwise it would be silently dropped from POSTAL -> NIS_2025 (audit M8).
  new_p25 <- setdiff(unique(p25_map$code_postal), unique(p19$code_postal))
  if (length(new_p25) > 0L)
    abort(sprintf(
      paste0("%d postal code(s) exist in the 2025 mapping but not in 2019 and would be ",
             "dropped from POSTAL -> NIS_MUNICIPALITY_2025: %s%s. Union the postal universes."),
      length(new_p25), paste(head(sort(new_p25), 5L), collapse = ", "),
      if (length(new_p25) > 5L) ", ..." else ""),
      class = "rcl_incomplete_universe")
  p25_full <- merge(data.table(code_postal = unique(p19$code_postal)),
                    p25_map, by = "code_postal", all.x = TRUE)
  xw[["POSTAL__NIS_MUNICIPALITY_2025"]] <- .xw("POSTAL", "NIS_MUNICIPALITY_2025",
                                            p25_full$code_postal, p25_full$code_nis_municipality)

  # ---- NIS_MUNICIPALITY_2019 -> * -----------------------------------------------
  xw[["NIS_MUNICIPALITY_2019__NIS_DISTRICT_2019"]] <- .pairs_xw(
    "NIS_MUNICIPALITY_2019", "NIS_DISTRICT_2019", m19, "code_nis_municipality", "code_nis_district")
  xw[["NIS_MUNICIPALITY_2019__NIS_PROVINCE_2019"]] <- .pairs_xw(
    "NIS_MUNICIPALITY_2019", "NIS_PROVINCE_2019",       m19, "code_nis_municipality", "code_nis_province")
  xw[["NIS_MUNICIPALITY_2019__NIS_REGION_2019"]] <- .pairs_xw(
    "NIS_MUNICIPALITY_2019", "NIS_REGION_2019",         m19, "code_nis_municipality", "code_nis_region")
  xw[["NIS_MUNICIPALITY_2019__NUTS_MUNICIPALITY_2021"]] <- .pairs_xw(
    "NIS_MUNICIPALITY_2019", "NUTS_MUNICIPALITY_2021",           m19, "code_nis_municipality", "code_nuts_municipality_2021")
  xw[["NIS_MUNICIPALITY_2019__NUTS_DISTRICT_2021"]] <- .pairs_xw(
    "NIS_MUNICIPALITY_2019", "NUTS_DISTRICT_2021",              m19, "code_nis_municipality", "code_nuts_district_2021")
  xw[["NIS_MUNICIPALITY_2019__NUTS_PROVINCE_2021"]] <- .pairs_xw(
    "NIS_MUNICIPALITY_2019", "NUTS_PROVINCE_2021",              m19, "code_nis_municipality", "code_nuts_province_2021")
  xw[["NIS_MUNICIPALITY_2019__NUTS_REGION_2021"]] <- .pairs_xw(
    "NIS_MUNICIPALITY_2019", "NUTS_REGION_2021",              m19, "code_nis_municipality", "code_nuts_region_2021")
  xw[["NIS_MUNICIPALITY_2019__NUTS_COUNTRY"]] <- .xw(
    "NIS_MUNICIPALITY_2019", "NUTS_COUNTRY",
    unique(m19$code_nis_municipality), rep("BE", uniqueN(m19$code_nis_municipality)))
  xw[["NIS_MUNICIPALITY_2019__NBB_DISTRICT_2021"]] <- .pairs_xw(
    "NIS_MUNICIPALITY_2019", "NBB_DISTRICT_2021", m19, "code_nis_municipality", "code_nbb_district_2021")

  # NIS_MUNICIPALITY_2019 -> NIS_MUNICIPALITY_2025 (temporal, with nature)
  ch19 <- nis_changes[version_from == VER_2019,
                       .(code_from, code_to, nature)]
  unchanged_19 <- setdiff(unique(m19$code_nis_municipality), ch19$code_from)
  full_19_25 <- rbindlist(list(
    ch19,
    data.table(code_from = unchanged_19,
               code_to = unchanged_19,
               nature        = "UNCHANGED")
  ), use.names = TRUE)

  # Orphaned 2025 communes (audit C4): a 2025 commune that is neither a change
  # TARGET nor an unchanged-2019 code has no 2019 lineage in REFNIS_CHANGE_2025.
  # The 2019->2025 forward domain is m19 (complete by construction), but the
  # REVERSE 2025->2019 crosswalk is keyed on the 2025 side, so such a commune
  # would silently vanish from it (no row -> engine returns nothing). Mirror the
  # BEFORE_2019 orphan handling: emit an explicit code_to = NA row (matching the
  # runtime engine) and warn, instead of dropping it silently.
  orphaned_25 <- setdiff(unique(m25$code_nis_municipality),
                         union(ch19$code_to, unchanged_19))
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
    full_19_25$code_from, full_19_25$code_to, full_19_25$nature)

  # ---- NIS_MUNICIPALITY_2025 -> * -----------------------------------------------
  xw[["NIS_MUNICIPALITY_2025__NIS_DISTRICT_2025"]] <- .pairs_xw(
    "NIS_MUNICIPALITY_2025", "NIS_DISTRICT_2025", m25, "code_nis_municipality", "code_nis_district")
  xw[["NIS_MUNICIPALITY_2025__NIS_PROVINCE_2025"]] <- .pairs_xw(
    "NIS_MUNICIPALITY_2025", "NIS_PROVINCE_2025",       m25, "code_nis_municipality", "code_nis_province")
  xw[["NIS_MUNICIPALITY_2025__NIS_REGION_2025"]] <- .pairs_xw(
    "NIS_MUNICIPALITY_2025", "NIS_REGION_2025",         m25, "code_nis_municipality", "code_nis_region")
  xw[["NIS_MUNICIPALITY_2025__NBB_DISTRICT_2021"]] <- .pairs_xw(
    "NIS_MUNICIPALITY_2025", "NBB_DISTRICT_2021", m25, "code_nis_municipality", "code_nbb_district_2021")

  # NIS_MUNICIPALITY_2025 -> NUTS_DISTRICT_2021 (1:N): 564 direct + 3 fusions via nis_changes
  direct_25_n3  <- unique(m25[!is.na(code_nuts_district_2021), .(code_nis_municipality, code_nuts_district_2021)])
  na25_communes <- m25[is.na(code_nuts_district_2021), unique(code_nis_municipality)]
  if (length(na25_communes) > 0L) {
    ch_for_na  <- nis_changes[version_from == VER_2019 & code_to %in% na25_communes,
                               .(code_from, code_to)]
    lkp19_n3   <- unique(m19[, .(code_nis_municipality, code_nuts_district_2021)])
    expanded25 <- merge(ch_for_na, lkp19_n3,
                        by.x = "code_from", by.y = "code_nis_municipality", all.x = TRUE)
    expanded25 <- unique(expanded25[!is.na(code_nuts_district_2021),
                                    .(code_nis_municipality = code_to, code_nuts_district_2021)])
    full_25_n3 <- rbindlist(list(direct_25_n3, expanded25), use.names = TRUE)
  } else {
    full_25_n3 <- direct_25_n3
  }
  xw[["NIS_MUNICIPALITY_2025__NUTS_DISTRICT_2021"]] <- .xw(
    "NIS_MUNICIPALITY_2025", "NUTS_DISTRICT_2021",
    full_25_n3$code_nis_municipality, full_25_n3$code_nuts_district_2021)

  # NIS_MUNICIPALITY_2025 -> NIS_MUNICIPALITY_2019 (reverse temporal, 1:N for fused
  # communes). Orphaned 2025 communes (no 2019 lineage, audit C4) get an explicit
  # code_to = NA row so they are not silently missing from the reverse crosswalk.
  rev_from   <- c(full_19_25$code_to, orphaned_25)
  rev_to     <- c(full_19_25$code_from, rep(NA_integer_,   length(orphaned_25)))
  rev_nature <- c(full_19_25$nature,        rep(NA_character_, length(orphaned_25)))
  xw[["NIS_MUNICIPALITY_2025__NIS_MUNICIPALITY_2019"]] <- .xw(
    "NIS_MUNICIPALITY_2025", "NIS_MUNICIPALITY_2019",
    rev_from, rev_to, rev_nature)

  # NIS_MUNICIPALITY_2025 -> NUTS 2027
  xw[["NIS_MUNICIPALITY_2025__NUTS_DISTRICT_2027"]] <- .pairs_xw(
    "NIS_MUNICIPALITY_2025", "NUTS_DISTRICT_2027", m25, "code_nis_municipality", "code_nuts_district_2027")
  xw[["NIS_MUNICIPALITY_2025__NUTS_PROVINCE_2027"]] <- .pairs_xw(
    "NIS_MUNICIPALITY_2025", "NUTS_PROVINCE_2027", m25, "code_nis_municipality", "code_nuts_province_2027")
  xw[["NIS_MUNICIPALITY_2025__NUTS_REGION_2027"]] <- .pairs_xw(
    "NIS_MUNICIPALITY_2025", "NUTS_REGION_2027", m25, "code_nis_municipality", "code_nuts_region_2027")

  # ---- NIS_DISTRICT_2019 -> * ----------------------------------------
  # Verviers (63000): 1:N for NUTS3 and INTERNAL (2 rows each)
  xw[["NIS_DISTRICT_2019__NUTS_DISTRICT_2021"]] <- .pairs_xw(
    "NIS_DISTRICT_2019", "NUTS_DISTRICT_2021",              m19, "code_nis_district", "code_nuts_district_2021")
  xw[["NIS_DISTRICT_2019__NBB_DISTRICT_2021"]] <- .pairs_xw(
    "NIS_DISTRICT_2019", "NBB_DISTRICT_2021", m19, "code_nis_district", "code_nbb_district_2021")
  xw[["NIS_DISTRICT_2019__NIS_PROVINCE_2019"]] <- .pairs_xw(
    "NIS_DISTRICT_2019", "NIS_PROVINCE_2019",       m19, "code_nis_district", "code_nis_province")

  # ---- NIS_DISTRICT_2025 -> * ----------------------------------------
  xw[["NIS_DISTRICT_2025__NIS_PROVINCE_2025"]] <- .pairs_xw(
    "NIS_DISTRICT_2025", "NIS_PROVINCE_2025",       m25, "code_nis_district", "code_nis_province")

  # ---- NIS_PROVINCE -> NIS_REGION (N:1: each province nests in one region) --
  xw[["NIS_PROVINCE_2019__NIS_REGION_2019"]] <- .pairs_xw(
    "NIS_PROVINCE_2019", "NIS_REGION_2019",       m19, "code_nis_province", "code_nis_region")
  xw[["NIS_PROVINCE_2025__NIS_REGION_2025"]] <- .pairs_xw(
    "NIS_PROVINCE_2025", "NIS_REGION_2025",       m25, "code_nis_province", "code_nis_region")

  # ---- NUTS 2021 hierarchy -------------------------------------------------
  xw[["NUTS_DISTRICT_2021__NUTS_PROVINCE_2021"]] <- .pairs_xw(
    "NUTS_DISTRICT_2021", "NUTS_PROVINCE_2021",              m19, "code_nuts_district_2021", "code_nuts_province_2021")
  xw[["NUTS_DISTRICT_2021__NBB_DISTRICT_2021"]] <- .pairs_xw(
    "NUTS_DISTRICT_2021", "NBB_DISTRICT_2021", m19, "code_nuts_district_2021", "code_nbb_district_2021")
  xw[["NUTS_DISTRICT_2021__NIS_DISTRICT_2019"]] <- .pairs_xw(
    "NUTS_DISTRICT_2021", "NIS_DISTRICT_2019", m19, "code_nuts_district_2021", "code_nis_district")
  xw[["NUTS_PROVINCE_2021__NUTS_REGION_2021"]] <- .pairs_xw(
    "NUTS_PROVINCE_2021", "NUTS_REGION_2021", m19, "code_nuts_province_2021", "code_nuts_region_2021")
  xw[["NUTS_REGION_2021__NUTS_COUNTRY"]] <- .pairs_xw(
    "NUTS_REGION_2021", "NUTS_COUNTRY",      m19, "code_nuts_region_2021", "code_nuts_country")

  # NUTS_MUNICIPALITY_2021 bidirectional
  xw[["NUTS_MUNICIPALITY_2021__NIS_MUNICIPALITY_2019"]] <- .pairs_xw(
    "NUTS_MUNICIPALITY_2021", "NIS_MUNICIPALITY_2019", m19, "code_nuts_municipality_2021", "code_nis_municipality")
  xw[["NUTS_MUNICIPALITY_2021__NUTS_DISTRICT_2021"]] <- .pairs_xw(
    "NUTS_MUNICIPALITY_2021", "NUTS_DISTRICT_2021",       m19, "code_nuts_municipality_2021", "code_nuts_district_2021")

  xw[["NBB_DISTRICT_2021__NUTS_DISTRICT_2021"]] <- .pairs_xw(
    "NBB_DISTRICT_2021", "NUTS_DISTRICT_2021", m19, "code_nbb_district_2021", "code_nuts_district_2021")

  # ---- NUTS 2027 hierarchy -------------------------------------------------
  xw[["NUTS_DISTRICT_2027__NUTS_PROVINCE_2027"]] <- .pairs_xw(
    "NUTS_DISTRICT_2027", "NUTS_PROVINCE_2027", m25, "code_nuts_district_2027", "code_nuts_province_2027")
  xw[["NUTS_PROVINCE_2027__NUTS_REGION_2027"]] <- .pairs_xw(
    "NUTS_PROVINCE_2027", "NUTS_REGION_2027", m25, "code_nuts_province_2027", "code_nuts_region_2027")
  xw[["NUTS_REGION_2027__NUTS_COUNTRY"]] <- .pairs_xw(
    "NUTS_REGION_2027", "NUTS_COUNTRY",      m25, "code_nuts_region_2027", "code_nuts_country_2027")

  # ---- NUTS_DISTRICT_2021 -> NUTS_DISTRICT_2027 (derived, 1:N) --------------
  # Chain at commune level over NIS 2019 (NUTS 2021 is keyed to the 2019 commune
  # perimeter): 2019 commune -> code_nuts_district_2021 (2021)  AND  -> 2025 commune -> code_nuts_district_2027.
  # The 3 cross-province fusion communes (46029, 46030, 71072) merge constituents
  # sitting in different 2021 NUTS3 regions, so a few 2021 NUTS3 codes acquire >1
  # 2027 target -> 1:N (e.g. BE211 -> {BE261, BE276}).
  # NB: build from m19 (NOT m25 alone) -- m25's backfilled code_nuts_district_2021 is NA for the
  # ambiguous communes, which would silently drop precisely the ambiguous pairs.
  ch19_n27 <- nis_changes[version_from == VER_2019, .(code_from, code_to)]
  link2025 <- merge(data.table(code_nis_municipality = unique(m19$code_nis_municipality)),
                    ch19_n27, by.x = "code_nis_municipality", by.y = "code_from", all.x = TRUE)
  link2025[is.na(code_to), code_to := code_nis_municipality]   # unchanged keep their code

  n3_2021 <- unique(m19[!is.na(code_nuts_district_2021),      .(code_nis_municipality, code_nuts_district_2021)])
  n3_2027 <- unique(m25[!is.na(code_nuts_district_2027), .(code_nis_municipality, code_nuts_district_2027)])

  chain <- merge(link2025, n3_2021, by = "code_nis_municipality", all.x = FALSE)
  chain <- merge(chain, n3_2027, by.x = "code_to", by.y = "code_nis_municipality", all.x = FALSE)
  pairs_21_27 <- unique(chain[!is.na(code_nuts_district_2021) & !is.na(code_nuts_district_2027),
                              .(code_nuts_district_2021, code_nuts_district_2027)])

  xw[["NUTS_DISTRICT_2021__NUTS_DISTRICT_2027"]] <- .xw(
    "NUTS_DISTRICT_2021", "NUTS_DISTRICT_2027",
    pairs_21_27$code_nuts_district_2021, pairs_21_27$code_nuts_district_2027)

  # NIS_MUNICIPALITY_2019 -> NUTS_DISTRICT_2027 (derived, N:1 for most; 1:N for the
  # 3 cross-province fusion zones whose NIS2019 constituents straddle NUTS2027 borders).
  # Reuses the same chain built above: code_nis_municipality (NIS2019) -> code_nuts_district_2027 (via NIS2025).
  # Storing this as a direct crosswalk hop prevents the BFS from routing through
  # NUTS_DISTRICT_2021 -> NUTS_DISTRICT_2027 (which would introduce spurious ambiguity
  # for communes that are in a 1:N NUTS2021 zone but have a unique NUTS2027 target).
  pairs_19_27 <- unique(chain[!is.na(code_nuts_district_2027), .(code_nis_municipality, code_nuts_district_2027)])
  xw[["NIS_MUNICIPALITY_2019__NUTS_DISTRICT_2027"]] <- .xw(
    "NIS_MUNICIPALITY_2019", "NUTS_DISTRICT_2027",
    as.character(pairs_19_27$code_nis_municipality), pairs_19_27$code_nuts_district_2027)

  # ---- NIS_REGION -> NIS_COUNTRY ----------------------------------------------
  xw[["NIS_REGION_2019__NIS_COUNTRY"]] <- .pairs_xw(
    "NIS_REGION_2019", "NIS_COUNTRY", m19, "code_nis_region", "code_nis_country")
  xw[["NIS_REGION_2025__NIS_COUNTRY"]] <- .pairs_xw(
    "NIS_REGION_2025", "NIS_COUNTRY", m25, "code_nis_region", "code_nis_country")

  # ---- NIS BEFORE_2019 (optional -- only when BEFORE_2019 slice is loaded) --
  if (has_b19) {
    ch_b19 <- nis_changes[version_from == VER_BEFORE_2019,
                           .(code_from, code_to, nature)]
    unchanged_b19 <- intersect(unique(mb19$code_nis_municipality), unique(m19$code_nis_municipality))

    # Orphaned: in BEFORE_2019 but neither in nis_changes nor in NIS 2019.
    # Engine returns code_to = NA for these; crosswalk must match.
    orphaned_b19 <- setdiff(unique(mb19$code_nis_municipality),
                             union(ch_b19$code_from, unchanged_b19))

    parts <- list(
      data.table(code_from = unchanged_b19,
                 code_to = unchanged_b19,
                 nature        = "UNCHANGED")
    )
    if (nrow(ch_b19) > 0L)    parts <- c(list(ch_b19), parts)
    if (length(orphaned_b19) > 0L) {
      parts <- c(parts, list(data.table(code_from = orphaned_b19,
                                        code_to = NA_integer_,
                                        nature        = NA_character_)))
    }
    full_b19_19 <- rbindlist(parts, use.names = TRUE)

    xw[["NIS_MUNICIPALITY_BEFORE_2019__NIS_MUNICIPALITY_2019"]] <- .xw(
      "NIS_MUNICIPALITY_BEFORE_2019", "NIS_MUNICIPALITY_2019",
      full_b19_19$code_from, full_b19_19$code_to, full_b19_19$nature)

    xw[["NIS_MUNICIPALITY_BEFORE_2019__NIS_DISTRICT_BEFORE_2019"]] <- .pairs_xw(
      "NIS_MUNICIPALITY_BEFORE_2019", "NIS_DISTRICT_BEFORE_2019",
      mb19, "code_nis_municipality", "code_nis_district")
    xw[["NIS_MUNICIPALITY_BEFORE_2019__NIS_PROVINCE_BEFORE_2019"]] <- .pairs_xw(
      "NIS_MUNICIPALITY_BEFORE_2019", "NIS_PROVINCE_BEFORE_2019",
      mb19, "code_nis_municipality", "code_nis_province")
    xw[["NIS_MUNICIPALITY_BEFORE_2019__NIS_REGION_BEFORE_2019"]] <- .pairs_xw(
      "NIS_MUNICIPALITY_BEFORE_2019", "NIS_REGION_BEFORE_2019",
      mb19, "code_nis_municipality", "code_nis_region")
    xw[["NIS_MUNICIPALITY_BEFORE_2019__NUTS_DISTRICT_2021"]] <- .pairs_xw(
      "NIS_MUNICIPALITY_BEFORE_2019", "NUTS_DISTRICT_2021",
      mb19, "code_nis_municipality", "code_nuts_district_2021")
    xw[["NIS_MUNICIPALITY_BEFORE_2019__NUTS_PROVINCE_2021"]] <- .pairs_xw(
      "NIS_MUNICIPALITY_BEFORE_2019", "NUTS_PROVINCE_2021",
      mb19, "code_nis_municipality", "code_nuts_province_2021")
    xw[["NIS_MUNICIPALITY_BEFORE_2019__NBB_DISTRICT_2021"]] <- .pairs_xw(
      "NIS_MUNICIPALITY_BEFORE_2019", "NBB_DISTRICT_2021",
      mb19, "code_nis_municipality", "code_nbb_district_2021")

    xw[["NIS_DISTRICT_BEFORE_2019__NIS_PROVINCE_BEFORE_2019"]] <- .pairs_xw(
      "NIS_DISTRICT_BEFORE_2019", "NIS_PROVINCE_BEFORE_2019",
      mb19, "code_nis_district", "code_nis_province")
    xw[["NIS_PROVINCE_BEFORE_2019__NIS_REGION_BEFORE_2019"]] <- .pairs_xw(
      "NIS_PROVINCE_BEFORE_2019", "NIS_REGION_BEFORE_2019",
      mb19, "code_nis_province", "code_nis_region")
    xw[["NIS_REGION_BEFORE_2019__NIS_COUNTRY"]] <- .pairs_xw(
      "NIS_REGION_BEFORE_2019", "NIS_COUNTRY", mb19, "code_nis_region", "code_nis_country")
  }

  rbindlist(Filter(Negate(is.null), xw), use.names = TRUE, fill = FALSE)
}
