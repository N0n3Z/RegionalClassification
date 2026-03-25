# ==============================================================================
# 03_convert.R - Conversion functions between classifications
# ==============================================================================

library(data.table)

#' Convert codes from one classification to another
#'
#' This is the main conversion function. It automatically determines the
#' conversion path and applies the necessary transformations.
#'
#' @param codes Vector of codes to convert
#' @param from Source classification (e.g., "NIS_COMMUNE_2019", "POSTAL", "NUTS3_2021")
#' @param to Target classification (e.g., "NUTS3_2021", "NIS_COMMUNE_2025")
#' @param master_data Output from build_master_table()
#' @param allow_ambiguous Logical. If FALSE (default), raises error on M:N conversions.
#'   If TRUE, returns all possible mappings.
#' @return data.table with columns: code_from, code_to (and optionally notes)
convert_codes <- function(codes, from, to, master_data,
                          allow_ambiguous = FALSE) {

  # Validate inputs
  path_info <- check_conversion_path(from, to)

  if (!path_info$is_simple && !allow_ambiguous) {
    stop(sprintf(
      paste0("Conversion from '%s' to '%s' is NOT a simple (direct) conversion.\n",
             "Reason: %s\n",
             "Use allow_ambiguous = TRUE to force conversion with all possible mappings."),
      from, to, path_info$explanation
    ))
  }

  # Perform conversion
  result <- execute_conversion(codes, from, to, master_data)

  return(result)
}

#' Execute the actual conversion between two classifications
#'
#' @param codes Vector of codes
#' @param from Source classification identifier
#' @param to Target classification identifier
#' @param master_data Output from build_master_table()
#' @return data.table with code_from, code_to, and metadata
execute_conversion <- function(codes, from, to, master_data) {

  input_dt <- data.table(code_from = codes)

  # Normalize classification identifiers
  from_norm <- normalize_classification_id(from)
  to_norm <- normalize_classification_id(to)

  # Route to appropriate conversion function
  result <- route_conversion(input_dt, from_norm, to_norm, master_data)

  return(result)
}

#' Normalize classification identifiers to standard format
#'
#' @param class_id User-supplied classification identifier
#' @return Normalized identifier
normalize_classification_id <- function(class_id) {
  # Convert to uppercase and standardize
  id <- toupper(trimws(class_id))

  # Common aliases
  aliases <- list(
    "NIS_COMMUNE_BEFORE_2019"       = "NIS_COMMUNE_BEFORE_2019",
    "NIS_COM_BEFORE_2019"           = "NIS_COMMUNE_BEFORE_2019",
    "NIS_ARRONDISSEMENT_BEFORE_2019" = "NIS_ARRONDISSEMENT_BEFORE_2019",
    "NIS_ARR_BEFORE_2019"           = "NIS_ARRONDISSEMENT_BEFORE_2019",
    "NIS_PROVINCE_BEFORE_2019"      = "NIS_PROVINCE_BEFORE_2019",
    "NIS_REGION_BEFORE_2019"        = "NIS_REGION_BEFORE_2019",
    "NIS_COMMUNE_2019" = "NIS_COMMUNE_2019",
    "NIS_COM_2019" = "NIS_COMMUNE_2019",
    "COMMUNE_2019" = "NIS_COMMUNE_2019",
    "NIS_COMMUNE_2025" = "NIS_COMMUNE_2025",
    "NIS_COM_2025" = "NIS_COMMUNE_2025",
    "COMMUNE_2025" = "NIS_COMMUNE_2025",
    "NIS_ARRONDISSEMENT_2019" = "NIS_ARRONDISSEMENT_2019",
    "NIS_ARR_2019" = "NIS_ARRONDISSEMENT_2019",
    "NIS_ARRONDISSEMENT_2025" = "NIS_ARRONDISSEMENT_2025",
    "NIS_ARR_2025" = "NIS_ARRONDISSEMENT_2025",
    "NIS_PROVINCE_2019" = "NIS_PROVINCE_2019",
    "NIS_PROVINCE_2025" = "NIS_PROVINCE_2025",
    "NIS_REGION_2019" = "NIS_REGION_2019",
    "NIS_REGION_2025" = "NIS_REGION_2025",
    "NUTS3_2021" = "NUTS3_2021",
    "NUTS_2021" = "NUTS3_2021",
    "NUTS2_2021" = "NUTS2_2021",
    "NUTS1_2021" = "NUTS1_2021",
    "NUTS0" = "NUTS0",
    "NUTS3_2027" = "NUTS3_2027",
    "NUTS_2027" = "NUTS3_2027",
    "NUTS2_2027" = "NUTS2_2027",
    "NUTS1_2027" = "NUTS1_2027",
    "NUTS_LAU_2027" = "NUTS_LAU_2027",
    "NUTS_LAU_2021" = "NUTS_LAU_2021",
    "LAU_2021" = "NUTS_LAU_2021",
    "POSTAL" = "POSTAL",
    "CODE_POSTAL" = "POSTAL",
    "CP" = "POSTAL",
    "INTERNAL" = "INTERNAL_ARRONDISSEMENT",
    "INTERNAL_ARRONDISSEMENT" = "INTERNAL_ARRONDISSEMENT",
    "INTERNAL_ARR" = "INTERNAL_ARRONDISSEMENT",
    "INTERNE" = "INTERNAL_ARRONDISSEMENT"
  )

  if (id %in% names(aliases)) {
    return(aliases[[id]])
  }

  # If no alias found, return as-is
  return(id)
}

#' Route conversion to the appropriate handler
#'
#' @param input_dt data.table with code_from column
#' @param from Normalized source classification
#' @param to Normalized target classification
#' @param md Master data (output from build_master_table)
#' @return data.table with code_from, code_to
route_conversion <- function(input_dt, from, to, md) {

  # --- POSTAL conversions ---
  if (from == "POSTAL" && to == "NIS_COMMUNE_2019") {
    return(convert_via_lookup(input_dt, md$postal_to_nis2019,
                              "cd_postal", "cd_commune_nis"))
  }
  if (from == "POSTAL" && to == "NIS_COMMUNE_2025") {
    return(convert_via_lookup(input_dt, md$postal_to_nis2025,
                              "cd_postal", "cd_commune_nis"))
  }

  # POSTAL to any NIS level via commune
  if (from == "POSTAL" && grepl("^NIS_", to)) {
    # First convert postal -> commune, then commune -> target
    postal_to_comm <- convert_via_lookup(input_dt, md$postal_to_nis2019,
                                          "cd_postal", "cd_commune_nis")
    if (to == "NIS_COMMUNE_2019") return(postal_to_comm)

    intermediate <- data.table(code_from = postal_to_comm$code_to)
    next_result <- route_conversion(intermediate, "NIS_COMMUNE_2019", to, md)
    return(merge(postal_to_comm, next_result,
                 by.x = "code_to", by.y = "code_from",
                 suffixes = c("_intermediate", ""))[
      , .(code_from, code_to = code_to.y)])
  }

  # POSTAL to NUTS
  if (from == "POSTAL" && grepl("^NUTS", to)) {
    postal_to_comm <- convert_via_lookup(input_dt, md$postal_to_nis2019,
                                          "cd_postal", "cd_commune_nis")
    intermediate <- data.table(code_from = postal_to_comm$code_to)
    next_result <- route_conversion(intermediate, "NIS_COMMUNE_2019", to, md)
    return(data.table(
      code_from = postal_to_comm$code_from,
      code_to = next_result$code_to[match(postal_to_comm$code_to,
                                           next_result$code_from)]
    ))
  }

  # POSTAL to INTERNAL
  if (from == "POSTAL" && to == "INTERNAL_ARRONDISSEMENT") {
    postal_to_nuts3 <- route_conversion(input_dt, "POSTAL", "NUTS3_2021", md)
    intermediate <- data.table(code_from = postal_to_nuts3$code_to)
    nuts3_to_int <- route_conversion(intermediate, "NUTS3_2021",
                                      "INTERNAL_ARRONDISSEMENT", md)
    return(data.table(
      code_from = postal_to_nuts3$code_from,
      code_to = nuts3_to_int$code_to[match(postal_to_nuts3$code_to,
                                            nuts3_to_int$code_from)]
    ))
  }

  # --- NIS COMMUNE 2019 conversions ---
  if (from == "NIS_COMMUNE_2019") {
    master <- md$master_nis2019_nuts2021
    input_dt[, code_from := as.integer(code_from)]

    if (to == "NIS_ARRONDISSEMENT_2019") {
      return(convert_via_master(input_dt, master, "cd_commune", "cd_arr"))
    }
    if (to == "NIS_PROVINCE_2019") {
      return(convert_via_master(input_dt, master, "cd_commune", "cd_province"))
    }
    if (to == "NIS_REGION_2019") {
      return(convert_via_master(input_dt, master, "cd_commune", "cd_region"))
    }
    if (to == "NUTS_LAU_2021") {
      return(convert_via_master(input_dt, master, "cd_commune", "cd_nuts_lau"))
    }
    if (to == "NUTS3_2021") {
      return(convert_via_master(input_dt, master, "cd_commune", "cd_nuts3"))
    }
    if (to == "NUTS2_2021") {
      return(convert_via_master(input_dt, master, "cd_commune", "cd_nuts2"))
    }
    if (to == "NUTS1_2021") {
      return(convert_via_master(input_dt, master, "cd_commune", "cd_nuts1"))
    }
    if (to == "NUTS0") {
      return(data.table(code_from = input_dt$code_from, code_to = "BE"))
    }
    if (to == "NUTS3_2027") {
      return(convert_via_master(input_dt, master, "cd_commune", "cd_nuts3_2027"))
    }
    if (to == "NUTS2_2027") {
      return(convert_via_master(input_dt, master, "cd_commune", "cd_nuts2_2027"))
    }
    if (to == "NUTS1_2027") {
      return(convert_via_master(input_dt, master, "cd_commune", "cd_nuts1_2027"))
    }
    if (to == "INTERNAL_ARRONDISSEMENT") {
      return(convert_via_master(input_dt, master, "cd_commune", "cd_arr_internal"))
    }
    if (to == "NIS_COMMUNE_2025") {
      return(convert_nis2019_to_nis2025(input_dt, md))
    }
  }

  # --- NIS COMMUNE BEFORE_2019 conversions ---
  if (from == "NIS_COMMUNE_BEFORE_2019") {
    if (is.null(md$master_before2019)) {
      stop("NIS BEFORE_2019 data not loaded. Ensure REFNIS_BEFORE_2019.xls is in data/raw/ and reload.")
    }
    master_b19 <- md$master_before2019
    input_dt[, code_from := as.integer(code_from)]

    if (to == "NIS_ARRONDISSEMENT_BEFORE_2019") {
      return(convert_via_master(input_dt, master_b19, "cd_commune", "cd_arr"))
    }
    if (to == "NIS_PROVINCE_BEFORE_2019") {
      return(convert_via_master(input_dt, master_b19, "cd_commune", "cd_province"))
    }
    if (to == "NIS_REGION_BEFORE_2019") {
      return(convert_via_master(input_dt, master_b19, "cd_commune", "cd_region"))
    }
    if (to == "NUTS3_2021") {
      return(convert_via_master(input_dt, master_b19, "cd_commune", "cd_nuts3"))
    }
    if (to == "NUTS2_2021") {
      return(convert_via_master(input_dt, master_b19, "cd_commune", "cd_nuts2"))
    }
    if (to == "NUTS3_2027") {
      return(convert_via_master(input_dt, master_b19, "cd_commune", "cd_nuts3_2027"))
    }
    if (to == "INTERNAL_ARRONDISSEMENT") {
      return(convert_via_master(input_dt, master_b19, "cd_commune", "cd_arr_internal"))
    }
    if (to == "NIS_COMMUNE_2019") {
      return(convert_nis_before2019_to_nis2019(input_dt, md))
    }
  }

  # --- NIS COMMUNE 2025 -> NUTS 2027 (requires CONVERSION_NIS2025_NUTS2027.xlsx) ---
  if (from == "NIS_COMMUNE_2025" && grepl("^NUTS.*2027$", to)) {
    if (is.null(md$comm2025_to_nuts2027)) {
      stop(paste0(
        "Conversion NIS_COMMUNE_2025 -> ", to, " requires the file ",
        "'CONVERSION_NIS2025_NUTS2027.xlsx' in data/raw/.\n",
        "File not yet available. Once provided, drop it in data/raw/ and reload."
      ))
    }
    if (to == "NUTS3_2027") {
      return(convert_via_lookup(input_dt, md$comm2025_to_nuts2027,
                                "cd_commune_2025", "cd_nuts3_2027"))
    }
    if (to %in% c("NUTS2_2027", "NUTS1_2027")) {
      nuts3 <- route_conversion(input_dt, "NIS_COMMUNE_2025", "NUTS3_2027", md)
      intermediate <- data.table(code_from = nuts3$code_to)
      upper <- route_conversion(intermediate, "NUTS3_2027", to, md)
      return(data.table(
        code_from = nuts3$code_from,
        code_to   = upper$code_to[match(nuts3$code_to, upper$code_from)]
      ))
    }
  }

  # --- NIS COMMUNE 2025 conversions ---
  if (from == "NIS_COMMUNE_2025") {
    comm_2025 <- md$communes_nis2025
    input_dt[, code_from := as.integer(code_from)]

    if (to == "NIS_ARRONDISSEMENT_2025") {
      return(convert_via_master(input_dt, comm_2025, "cd_commune", "cd_arr"))
    }
    if (to == "NIS_PROVINCE_2025") {
      return(convert_via_master(input_dt, comm_2025, "cd_commune", "cd_province"))
    }
    if (to == "NIS_REGION_2025") {
      return(convert_via_master(input_dt, comm_2025, "cd_commune", "cd_region"))
    }
    if (to == "NIS_COMMUNE_2019") {
      return(convert_nis2025_to_nis2019(input_dt, md))
    }
  }

  # --- NIS ARRONDISSEMENT conversions ---
  if (from == "NIS_ARRONDISSEMENT_2019") {
    input_dt[, code_from := as.integer(code_from)]
    master <- md$master_nis2019_nuts2021

    if (to == "NUTS3_2021") {
      # This is the M:N case (Verviers)
      return(convert_arr_to_nuts3(input_dt, master))
    }
    if (to == "INTERNAL_ARRONDISSEMENT") {
      return(convert_arr_to_internal(input_dt, master))
    }
    if (to == "NIS_PROVINCE_2019") {
      # Get first commune in each arrondissement, then get province
      arr_prov <- unique(master[, .(cd_arr, cd_province)])
      return(convert_via_lookup(input_dt, arr_prov, "cd_arr", "cd_province"))
    }
  }

  if (from == "NIS_ARRONDISSEMENT_2025") {
    input_dt[, code_from := as.integer(code_from)]
    comm_2025 <- md$communes_nis2025

    if (to == "NIS_PROVINCE_2025") {
      arr_prov <- unique(comm_2025[, .(cd_arr, cd_province)])
      return(convert_via_lookup(input_dt, arr_prov, "cd_arr", "cd_province"))
    }
  }

  # --- NUTS conversions ---
  if (from == "NUTS3_2021") {
    if (to == "NUTS2_2021") {
      nuts3_ref <- md$nuts3_ref_2021
      master <- md$master_nis2019_nuts2021
      nuts3_to_nuts2 <- unique(master[, .(cd_nuts3, cd_nuts2)])
      return(convert_via_lookup(input_dt, nuts3_to_nuts2, "cd_nuts3", "cd_nuts2"))
    }
    if (to == "INTERNAL_ARRONDISSEMENT") {
      return(convert_via_lookup(input_dt, md$nuts_to_internal,
                                "cd_nuts3", "cd_arr_internal"))
    }
    if (to == "NIS_ARRONDISSEMENT_2019") {
      nuts3_ref <- md$nuts3_ref_2021
      return(convert_via_lookup(input_dt, nuts3_ref, "cd_nuts3", "cd_refnis_arr"))
    }
  }

  if (from == "NUTS_LAU_2021") {
    if (to == "NIS_COMMUNE_2019") {
      nuts_comm <- md$nuts_hierarchy_2021$communes
      return(convert_via_lookup(input_dt, nuts_comm, "cd_nuts_lau", "cd_refnis"))
    }
    if (to == "NUTS3_2021") {
      nuts_comm <- md$nuts_hierarchy_2021$communes
      return(convert_via_lookup(input_dt, nuts_comm, "cd_nuts_lau", "cd_nuts3"))
    }
  }

  # --- INTERNAL conversions ---
  if (from == "INTERNAL_ARRONDISSEMENT") {
    if (to == "NUTS3_2021") {
      return(convert_via_lookup(input_dt, md$nuts_to_internal,
                                "cd_arr_internal", "cd_nuts3"))
    }
    if (to == "NUTS3_2027") {
      nuts3_2021 <- route_conversion(input_dt, "INTERNAL_ARRONDISSEMENT", "NUTS3_2021", md)
      intermediate <- data.table(code_from = nuts3_2021$code_to)
      nuts3_2027 <- route_conversion(intermediate, "NUTS3_2021", "NUTS3_2027", md)
      return(data.table(
        code_from = nuts3_2021$code_from,
        code_to = nuts3_2027$code_to[match(nuts3_2021$code_to, nuts3_2027$code_from)]
      ))
    }
  }

  # --- NUTS 2021 <-> NUTS 2027 ---
  if (from == "NUTS3_2021" && to == "NUTS3_2027") {
    nuts3_map <- NUTS2021_TO_NUTS2027[nchar(nuts_2021) == 5]
    result <- merge(input_dt, nuts3_map, by.x = "code_from", by.y = "nuts_2021", all.x = TRUE)
    setnames(result, "nuts_2027", "code_to")
    result[is.na(code_to), code_to := code_from]
    return(result[, .(code_from, code_to)])
  }

  if (from == "NUTS3_2027" && to == "NUTS3_2021") {
    nuts3_map <- NUTS2021_TO_NUTS2027[nchar(nuts_2021) == 5]
    input_dt[, .row_order := .I]
    result <- merge(input_dt, nuts3_map, by.x = "code_from", by.y = "nuts_2027", all.x = TRUE)
    setnames(result, "nuts_2021", "code_to")
    result[is.na(code_to), code_to := code_from]
    setorder(result, .row_order)
    result[, .row_order := NULL]
    return(result[, .(code_from, code_to)])
  }

  if (from == "NUTS3_2027" && to == "INTERNAL_ARRONDISSEMENT") {
    # NUTS3_2027 -> NUTS3_2021 -> INTERNAL
    nuts3_2021 <- route_conversion(input_dt, "NUTS3_2027", "NUTS3_2021", md)
    intermediate <- data.table(code_from = nuts3_2021$code_to)
    internal <- route_conversion(intermediate, "NUTS3_2021", "INTERNAL_ARRONDISSEMENT", md)
    return(data.table(
      code_from = nuts3_2021$code_from,
      code_to = internal$code_to[match(nuts3_2021$code_to, internal$code_from)]
    ))
  }

  if (from == "NUTS3_2027" && to == "NUTS2_2027") {
    nuts3_ref <- md$nuts3_ref_2027
    return(convert_via_lookup(input_dt, nuts3_ref, "cd_nuts3_2027", "cd_nuts2_2027"))
  }

  if (from == "NUTS2_2027" && to == "NUTS1_2027") {
    nuts3_ref <- md$nuts3_ref_2027
    return(convert_via_lookup(input_dt, unique(nuts3_ref[, .(cd_nuts2_2027, cd_nuts1_2027)]),
                              "cd_nuts2_2027", "cd_nuts1_2027"))
  }

  stop(sprintf("No conversion route implemented from '%s' to '%s'.\n%s",
               from, to,
               "Use list_available_conversions() to see supported conversions."))
}

#' Convert using a lookup table
#'
#' @param input_dt data.table with code_from
#' @param lookup_dt Lookup data.table
#' @param from_col Column in lookup matching code_from
#' @param to_col Column in lookup to return
#' @return data.table with code_from, code_to
convert_via_lookup <- function(input_dt, lookup_dt, from_col, to_col) {

  input_dt <- copy(input_dt)

  # Ensure matching types
  if (is.numeric(lookup_dt[[from_col]]) && is.character(input_dt$code_from)) {
    input_dt[, code_from := as.integer(code_from)]
  }
  if (is.character(lookup_dt[[from_col]]) && is.numeric(input_dt$code_from)) {
    input_dt[, code_from := as.character(code_from)]
  }

  result <- merge(input_dt, lookup_dt[, .SD, .SDcols = c(from_col, to_col)],
                  by.x = "code_from", by.y = from_col, all.x = TRUE)
  setnames(result, to_col, "code_to")

  # Warn about unmatched codes
  n_na <- sum(is.na(result$code_to))
  if (n_na > 0) {
    warning(sprintf("%d code(s) could not be converted (no match found)", n_na))
  }

  return(result[, .(code_from, code_to)])
}

#' Convert using master table columns
#'
#' @param input_dt data.table with code_from (integer)
#' @param master Master data.table
#' @param from_col Column to match against
#' @param to_col Column to return
#' @return data.table with code_from, code_to
convert_via_master <- function(input_dt, master, from_col, to_col) {

  lookup <- unique(master[, .SD, .SDcols = c(from_col, to_col)])
  result <- merge(input_dt, lookup, by.x = "code_from", by.y = from_col, all.x = TRUE)
  setnames(result, to_col, "code_to")

  n_na <- sum(is.na(result$code_to))
  if (n_na > 0) {
    warning(sprintf("%d code(s) could not be converted (no match found)", n_na))
  }

  return(result[, .(code_from, code_to)])
}

#' Convert NIS arrondissement to NUTS3 (handles Verviers M:N)
#'
#' @param input_dt data.table with code_from (integer arrondissement codes)
#' @param master Master table
#' @return data.table with code_from, code_to (may have multiple rows per input)
convert_arr_to_nuts3 <- function(input_dt, master) {

  arr_nuts3 <- unique(master[!is.na(cd_nuts3), .(cd_arr, cd_nuts3)])
  result <- merge(input_dt, arr_nuts3,
                  by.x = "code_from", by.y = "cd_arr", all.x = TRUE)
  setnames(result, "cd_nuts3", "code_to")

  # Add ambiguity flag
  result[, n_mappings := .N, by = code_from]
  if (any(result$n_mappings > 1)) {
    ambig <- unique(result[n_mappings > 1]$code_from)
    message(sprintf(
      "Note: %d arrondissement(s) have multiple NUTS3 mappings: %s",
      length(ambig), paste(ambig, collapse = ", ")
    ))
  }
  result[, n_mappings := NULL]

  return(result[, .(code_from, code_to)])
}

#' Convert NIS arrondissement to internal code (handles Verviers)
#'
#' @param input_dt data.table with code_from (integer arrondissement codes)
#' @param master Master table
#' @return data.table with code_from, code_to
convert_arr_to_internal <- function(input_dt, master) {

  arr_internal <- unique(master[!is.na(cd_arr_internal),
                                 .(cd_arr, cd_arr_internal)])
  result <- merge(input_dt, arr_internal,
                  by.x = "code_from", by.y = "cd_arr", all.x = TRUE)
  setnames(result, "cd_arr_internal", "code_to")

  result[, n_mappings := .N, by = code_from]
  if (any(result$n_mappings > 1)) {
    ambig <- unique(result[n_mappings > 1]$code_from)
    message(sprintf(
      paste0("Note: %d arrondissement(s) have multiple internal codes (Verviers split): %s\n",
             "  -> 65 = francophone, 66 = germanophone"),
      length(ambig), paste(ambig, collapse = ", ")
    ))
  }
  result[, n_mappings := NULL]

  return(result[, .(code_from, code_to)])
}

#' Convert NIS 2019 communes to NIS 2025
#'
#' Handles fusions and district/province changes.
#'
#' @param input_dt data.table with code_from (integer NIS 2019 codes)
#' @param md Master data
#' @return data.table with code_from, code_to, change_nature
convert_nis2019_to_nis2025 <- function(input_dt, md) {

  changes <- md$nis_changes

  result <- merge(input_dt, changes[, .(cd_refnis_old, cd_refnis_new, nature)],
                  by.x = "code_from", by.y = "cd_refnis_old", all.x = TRUE)

  # Codes not in the change table are unchanged
  result[is.na(cd_refnis_new), cd_refnis_new := code_from]
  result[is.na(nature), nature := "UNCHANGED"]

  setnames(result, "cd_refnis_new", "code_to")

  return(result[, .(code_from, code_to, nature)])
}

#' Convert NIS 2025 communes to NIS 2019 (reverse mapping)
#'
#' Note: for fused communes, the 2025 code maps back to multiple 2019 codes.
#'
#' @param input_dt data.table with code_from (integer NIS 2025 codes)
#' @param md Master data
#' @return data.table with code_from, code_to, nature
convert_nis2025_to_nis2019 <- function(input_dt, md) {

  changes <- md$nis_changes

  result <- merge(input_dt, changes[, .(cd_refnis_old, cd_refnis_new, nature)],
                  by.x = "code_from", by.y = "cd_refnis_new", all.x = TRUE)

  # Unchanged codes
  result[is.na(cd_refnis_old), cd_refnis_old := code_from]
  result[is.na(nature), nature := "UNCHANGED"]

  setnames(result, "cd_refnis_old", "code_to")

  result[, n_mappings := .N, by = code_from]
  if (any(result$n_mappings > 1)) {
    message(sprintf(
      "%d NIS 2025 code(s) map to multiple NIS 2019 codes (fusions)",
      uniqueN(result[n_mappings > 1]$code_from)
    ))
  }
  result[, n_mappings := NULL]

  return(result[, .(code_from, code_to, nature)])
}

#' Convert NIS BEFORE_2019 communes to NIS 2019
#'
#' Unchanged communes: 1:1. Merged communes require REFNIS_CHANGE_BEFORE2019.xlsx.
#'
#' @param input_dt data.table with code_from (integer NIS BEFORE_2019 codes)
#' @param md Master data
#' @return data.table with code_from, code_to, nature
convert_nis_before2019_to_nis2019 <- function(input_dt, md) {

  # Communes present in both versions: 1:1 (same code)
  comm_2019_codes <- md$communes_nis2019$cd_commune
  comm_b19_codes  <- md$communes_nis_before2019$cd_commune

  result <- copy(input_dt)
  result[, code_to := NA_integer_]
  result[, nature  := NA_character_]

  # Unchanged codes (exist in both versions)
  unchanged <- intersect(comm_b19_codes, comm_2019_codes)
  result[code_from %in% unchanged, `:=`(code_to = code_from, nature = "UNCHANGED")]

  # Merged codes: use change table if available
  merged_codes <- setdiff(comm_b19_codes, comm_2019_codes)
  if (length(merged_codes) > 0 && any(result$code_from %in% merged_codes)) {
    if (!is.null(md$nis_change_before2019)) {
      changes <- md$nis_change_before2019
      unresolved <- result[is.na(code_to) & code_from %in% merged_codes]
      resolved <- merge(unresolved[, .(code_from)],
                        changes[, .(cd_refnis_before2019, cd_refnis_2019)],
                        by.x = "code_from", by.y = "cd_refnis_before2019", all.x = TRUE)
      resolved[!is.na(cd_refnis_2019), `:=`(code_to = cd_refnis_2019, nature = "FUSION")]
      resolved[, cd_refnis_2019 := NULL]
      result <- rbind(result[!(code_from %in% merged_codes) | !is.na(code_to)], resolved)
    } else {
      # Warn about unavailable mapping
      n_merged_input <- sum(result$code_from %in% merged_codes, na.rm = TRUE)
      if (n_merged_input > 0) {
        warning(sprintf(
          paste0("%d code(s) are merged communes with no NIS 2019 equivalent. ",
                 "Provide REFNIS_CHANGE_BEFORE2019.xlsx in data/raw/ for full mapping."),
          n_merged_input
        ))
      }
    }
  }

  return(result[, .(code_from, code_to, nature)])
}

#' List all available conversion paths
#'
#' @return data.table describing available conversions
list_available_conversions <- function() {
  edges <- rbindlist(lapply(CONVERSION_GRAPH_EDGES, as.data.table))
  edges[, .(from, to, relation, notes)]
}
