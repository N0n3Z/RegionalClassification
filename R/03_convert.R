# ==============================================================================
# 03_convert.R - Conversion functions between classifications
# ==============================================================================


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
#' @examples
#' \donttest{
#'   master_data <- load_master_data()
#'
#'   # NIS communes -> NUTS3 2021
#'   convert_codes(c(21004L, 11002L, 62063L),
#'                 "NIS_COMMUNE_2019", "NUTS3_2021", master_data)
#'
#'   # Postal codes -> NIS communes
#'   convert_codes(c(1000L, 2000L, 4000L), "POSTAL", "NIS_COMMUNE_2019", master_data)
#'
#'   # NIS communes -> NUTS3 2027
#'   convert_codes(c(21004L, 11002L), "NIS_COMMUNE_2019", "NUTS3_2027", master_data)
#'
#'   # Ambiguous conversion (Verviers arrondissement spans two NUTS3 regions)
#'   convert_codes(63000L, "NIS_ARRONDISSEMENT_2019", "NUTS3_2021",
#'                 master_data, allow_ambiguous = TRUE)
#' }
#' @export
convert_codes <- function(codes, from, to, master_data,
                          allow_ambiguous = FALSE) {

  # Validate inputs
  path_info <- check_conversion_path(from, to)

  if (is.null(path_info$path) && !isTRUE(path_info$is_simple)) {
    abort(
      sprintf("No conversion route from '%s' to '%s'. Use list_available_conversions() to see all supported paths.",
              from, to),
      class = "rcl_no_route", from = from, to = to
    )
  }

  if (!path_info$is_simple && !allow_ambiguous) {
    abort(
      sprintf(paste0("Conversion from '%s' to '%s' is NOT a simple (direct) conversion.\n",
                     "Use allow_ambiguous = TRUE to force conversion with all possible mappings."),
              from, to),
      class = "rcl_ambiguous_conversion",
      from = from, to = to, explanation = path_info$explanation
    )
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

# Dispatch table: maps "FROM__TO" to a handler function(input_dt, md).
# Defined at package level so it is built once at load time.
# Each handler receives input_dt (data.table with code_from) and md (master data).
.ROUTE_TABLE <- list(

  # --- POSTAL -> NIS (direct) ---
  "POSTAL__NIS_COMMUNE_2019" = function(i, md)
    convert_via_lookup(i, md$postal[nis_version == "2019"], "cd_postal", "cd_commune_nis"),

  "POSTAL__NIS_COMMUNE_2025" = function(i, md)
    convert_via_lookup(i, md$postal[nis_version == "2025"], "cd_postal", "cd_commune_nis"),

  # --- NIS_COMMUNE_2019 -> * ---
  "NIS_COMMUNE_2019__NIS_ARRONDISSEMENT_2019" = function(i, md) {
    i[, code_from := as.integer(code_from)]
    convert_via_master(i, md$communes[nis_version == "2019"], "cd_commune", "cd_arr")
  },
  "NIS_COMMUNE_2019__NIS_PROVINCE_2019" = function(i, md) {
    i[, code_from := as.integer(code_from)]
    convert_via_master(i, md$communes[nis_version == "2019"], "cd_commune", "cd_province")
  },
  "NIS_COMMUNE_2019__NIS_REGION_2019" = function(i, md) {
    i[, code_from := as.integer(code_from)]
    convert_via_master(i, md$communes[nis_version == "2019"], "cd_commune", "cd_region")
  },
  "NIS_COMMUNE_2019__NUTS_LAU_2021" = function(i, md) {
    i[, code_from := as.integer(code_from)]
    convert_via_master(i, md$communes[nis_version == "2019"], "cd_commune", "cd_nuts_lau")
  },
  "NIS_COMMUNE_2019__NUTS3_2021" = function(i, md) {
    i[, code_from := as.integer(code_from)]
    convert_via_master(i, md$communes[nis_version == "2019"], "cd_commune", "cd_nuts3")
  },
  "NIS_COMMUNE_2019__NUTS2_2021" = function(i, md) {
    i[, code_from := as.integer(code_from)]
    convert_via_master(i, md$communes[nis_version == "2019"], "cd_commune", "cd_nuts2")
  },
  "NIS_COMMUNE_2019__NUTS1_2021" = function(i, md) {
    i[, code_from := as.integer(code_from)]
    convert_via_master(i, md$communes[nis_version == "2019"], "cd_commune", "cd_nuts1")
  },
  "NIS_COMMUNE_2019__NUTS0" = function(i, md)
    data.table(code_from = i$code_from, code_to = "BE"),
  "NIS_COMMUNE_2019__NUTS3_2027" = function(i, md) {
    i[, code_from := as.integer(code_from)]
    convert_via_master(i, md$communes[nis_version == "2019"], "cd_commune", "cd_nuts3_2027")
  },
  "NIS_COMMUNE_2019__NUTS2_2027" = function(i, md) {
    i[, code_from := as.integer(code_from)]
    convert_via_master(i, md$communes[nis_version == "2019"], "cd_commune", "cd_nuts2_2027")
  },
  "NIS_COMMUNE_2019__NUTS1_2027" = function(i, md) {
    i[, code_from := as.integer(code_from)]
    convert_via_master(i, md$communes[nis_version == "2019"], "cd_commune", "cd_nuts1_2027")
  },
  "NIS_COMMUNE_2019__INTERNAL_ARRONDISSEMENT" = function(i, md) {
    i[, code_from := as.integer(code_from)]
    convert_via_master(i, md$communes[nis_version == "2019"], "cd_commune", "cd_arr_internal")
  },
  "NIS_COMMUNE_2019__NIS_COMMUNE_2025" = function(i, md) {
    i[, code_from := as.integer(code_from)]
    convert_nis2019_to_nis2025(i, md)
  },

  # --- NIS_COMMUNE_BEFORE_2019 -> * ---
  "NIS_COMMUNE_BEFORE_2019__NIS_ARRONDISSEMENT_BEFORE_2019" = function(i, md) {
    m <- .get_master_b19(md); i[, code_from := as.integer(code_from)]
    convert_via_master(i, m, "cd_commune", "cd_arr")
  },
  "NIS_COMMUNE_BEFORE_2019__NIS_PROVINCE_BEFORE_2019" = function(i, md) {
    m <- .get_master_b19(md); i[, code_from := as.integer(code_from)]
    convert_via_master(i, m, "cd_commune", "cd_province")
  },
  "NIS_COMMUNE_BEFORE_2019__NIS_REGION_BEFORE_2019" = function(i, md) {
    m <- .get_master_b19(md); i[, code_from := as.integer(code_from)]
    convert_via_master(i, m, "cd_commune", "cd_region")
  },
  "NIS_COMMUNE_BEFORE_2019__NUTS3_2021" = function(i, md) {
    m <- .get_master_b19(md); i[, code_from := as.integer(code_from)]
    convert_via_master(i, m, "cd_commune", "cd_nuts3")
  },
  "NIS_COMMUNE_BEFORE_2019__NUTS2_2021" = function(i, md) {
    m <- .get_master_b19(md); i[, code_from := as.integer(code_from)]
    convert_via_master(i, m, "cd_commune", "cd_nuts2")
  },
  "NIS_COMMUNE_BEFORE_2019__NUTS3_2027" = function(i, md) {
    m <- .get_master_b19(md); i[, code_from := as.integer(code_from)]
    convert_via_master(i, m, "cd_commune", "cd_nuts3_2027")
  },
  "NIS_COMMUNE_BEFORE_2019__INTERNAL_ARRONDISSEMENT" = function(i, md) {
    m <- .get_master_b19(md); i[, code_from := as.integer(code_from)]
    convert_via_master(i, m, "cd_commune", "cd_arr_internal")
  },
  "NIS_COMMUNE_BEFORE_2019__NIS_COMMUNE_2019" = function(i, md) {
    i[, code_from := as.integer(code_from)]
    convert_nis_before2019_to_nis2019(i, md)
  },

  # --- NIS_COMMUNE_2025 -> * ---
  "NIS_COMMUNE_2025__NIS_ARRONDISSEMENT_2025" = function(i, md) {
    i[, code_from := as.integer(code_from)]
    convert_via_master(i, md$communes[nis_version == "2025"], "cd_commune", "cd_arr")
  },
  "NIS_COMMUNE_2025__NIS_PROVINCE_2025" = function(i, md) {
    i[, code_from := as.integer(code_from)]
    convert_via_master(i, md$communes[nis_version == "2025"], "cd_commune", "cd_province")
  },
  "NIS_COMMUNE_2025__NIS_REGION_2025" = function(i, md) {
    i[, code_from := as.integer(code_from)]
    convert_via_master(i, md$communes[nis_version == "2025"], "cd_commune", "cd_region")
  },
  "NIS_COMMUNE_2025__NIS_COMMUNE_2019" = function(i, md) {
    i[, code_from := as.integer(code_from)]
    convert_nis2025_to_nis2019(i, md)
  },
  "NIS_COMMUNE_2025__NUTS3_2027" = function(i, md) {
    i[, code_from := as.integer(code_from)]
    .route_nis2025_nuts2027(i, "NUTS3_2027", md)
  },
  "NIS_COMMUNE_2025__NUTS2_2027" = function(i, md) {
    i[, code_from := as.integer(code_from)]
    .route_nis2025_nuts2027(i, "NUTS2_2027", md)
  },
  "NIS_COMMUNE_2025__NUTS1_2027" = function(i, md) {
    i[, code_from := as.integer(code_from)]
    .route_nis2025_nuts2027(i, "NUTS1_2027", md)
  },

  # --- NIS ARRONDISSEMENT -> * ---
  "NIS_ARRONDISSEMENT_2019__NUTS3_2021" = function(i, md) {
    i[, code_from := as.integer(code_from)]
    convert_arr_to_nuts3(i, md$communes[nis_version == "2019"])
  },
  "NIS_ARRONDISSEMENT_2019__INTERNAL_ARRONDISSEMENT" = function(i, md) {
    i[, code_from := as.integer(code_from)]
    convert_arr_to_internal(i, md$communes[nis_version == "2019"])
  },
  "NIS_ARRONDISSEMENT_2019__NIS_PROVINCE_2019" = function(i, md) {
    i[, code_from := as.integer(code_from)]
    arr_prov <- unique(md$communes[nis_version == "2019", .(cd_arr, cd_province)])
    convert_via_lookup(i, arr_prov, "cd_arr", "cd_province")
  },
  "NIS_ARRONDISSEMENT_2025__NIS_PROVINCE_2025" = function(i, md) {
    i[, code_from := as.integer(code_from)]
    arr_prov <- unique(md$communes[nis_version == "2025", .(cd_arr, cd_province)])
    convert_via_lookup(i, arr_prov, "cd_arr", "cd_province")
  },

  # --- NUTS3_2021 -> * ---
  "NUTS3_2021__NUTS2_2021" = function(i, md) {
    lkp <- unique(md$communes[nis_version == "2019", .(cd_nuts3, cd_nuts2)])
    convert_via_lookup(i, lkp, "cd_nuts3", "cd_nuts2")
  },
  "NUTS3_2021__INTERNAL_ARRONDISSEMENT" = function(i, md) {
    lkp <- unique(md$communes[nis_version == "2019" & !is.na(cd_arr_internal),
                               .(cd_nuts3, cd_arr_internal)])
    convert_via_lookup(i, lkp, "cd_nuts3", "cd_arr_internal")
  },
  "NUTS3_2021__NIS_ARRONDISSEMENT_2019" = function(i, md) {
    lkp <- unique(md$communes[nis_version == "2019" & !is.na(cd_nuts3), .(cd_nuts3, cd_arr)])
    convert_via_lookup(i, lkp, "cd_nuts3", "cd_arr")
  },
  "NUTS3_2021__NUTS3_2027" = function(i, md) {
    nuts3_map <- NUTS2021_TO_NUTS2027[nchar(nuts_2021) == 5]
    result <- merge(i, nuts3_map, by.x = "code_from", by.y = "nuts_2021", all.x = TRUE)
    setnames(result, "nuts_2027", "code_to")
    result[is.na(code_to), code_to := code_from]
    result[, .(code_from, code_to)]
  },

  # --- NUTS_LAU_2021 -> * ---
  "NUTS_LAU_2021__NIS_COMMUNE_2019" = function(i, md) {
    lkp <- md$communes[nis_version == "2019", .(cd_nuts_lau, cd_refnis = cd_commune)]
    convert_via_lookup(i, lkp, "cd_nuts_lau", "cd_refnis")
  },
  "NUTS_LAU_2021__NUTS3_2021" = function(i, md) {
    lkp <- md$communes[nis_version == "2019", .(cd_nuts_lau, cd_nuts3)]
    convert_via_lookup(i, lkp, "cd_nuts_lau", "cd_nuts3")
  },

  # --- INTERNAL_ARRONDISSEMENT -> * ---
  "INTERNAL_ARRONDISSEMENT__NUTS3_2021" = function(i, md) {
    lkp <- unique(md$communes[nis_version == "2019" & !is.na(cd_arr_internal),
                               .(cd_nuts3, cd_arr_internal)])
    convert_via_lookup(i, lkp, "cd_arr_internal", "cd_nuts3")
  },
  "INTERNAL_ARRONDISSEMENT__NUTS3_2027" = function(i, md) {
    r21 <- route_conversion(i, "INTERNAL_ARRONDISSEMENT", "NUTS3_2021", md)
    r27 <- route_conversion(data.table(code_from = r21$code_to), "NUTS3_2021", "NUTS3_2027", md)
    data.table(code_from = r21$code_from,
               code_to   = r27$code_to[match(r21$code_to, r27$code_from)])
  },

  # --- NUTS3_2027 -> * ---
  "NUTS3_2027__NUTS3_2021" = function(i, md) {
    nuts3_map <- NUTS2021_TO_NUTS2027[nchar(nuts_2021) == 5]
    i[, .row_order := .I]
    result <- merge(i, nuts3_map, by.x = "code_from", by.y = "nuts_2027", all.x = TRUE)
    setnames(result, "nuts_2021", "code_to")
    result[is.na(code_to), code_to := code_from]
    setorder(result, .row_order)
    result[, .row_order := NULL]
    result[, .(code_from, code_to)]
  },
  "NUTS3_2027__INTERNAL_ARRONDISSEMENT" = function(i, md) {
    r21 <- route_conversion(i, "NUTS3_2027", "NUTS3_2021", md)
    ri  <- route_conversion(data.table(code_from = r21$code_to),
                            "NUTS3_2021", "INTERNAL_ARRONDISSEMENT", md)
    data.table(code_from = r21$code_from,
               code_to   = ri$code_to[match(r21$code_to, ri$code_from)])
  },
  "NUTS3_2027__NUTS2_2027" = function(i, md) {
    lkp <- unique(md$communes[!is.na(cd_nuts3_2027), .(cd_nuts3_2027, cd_nuts2_2027)])
    convert_via_lookup(i, lkp, "cd_nuts3_2027", "cd_nuts2_2027")
  },

  # --- NUTS2_2027 -> * ---
  "NUTS2_2027__NUTS1_2027" = function(i, md) {
    lkp <- unique(md$communes[!is.na(cd_nuts2_2027), .(cd_nuts2_2027, cd_nuts1_2027)])
    convert_via_lookup(i, lkp, "cd_nuts2_2027", "cd_nuts1_2027")
  }
)

#' Route conversion to the appropriate handler
#'
#' Looks up the "FROM__TO" key in .ROUTE_TABLE. For POSTAL multi-hop and
#' NIS_COMMUNE_2025->NUTS2027 multi-hop, falls back to chained helpers.
#'
#' @param input_dt data.table with code_from column
#' @param from Normalized source classification
#' @param to Normalized target classification
#' @param md Master data (output from build_master_table)
#' @return data.table with code_from, code_to
route_conversion <- function(input_dt, from, to, md) {

  if (from == to) return(input_dt[, .(code_from, code_to = code_from)])

  key     <- paste0(from, "__", to)
  handler <- .ROUTE_TABLE[[key]]

  if (!is.null(handler)) return(handler(copy(input_dt), md))

  # --- Multi-hop: POSTAL -> any NIS/NUTS/INTERNAL via NIS_COMMUNE_2019 ---
  if (from == "POSTAL" && (grepl("^NIS_", to) || grepl("^NUTS", to) ||
                           to == "INTERNAL_ARRONDISSEMENT")) {
    p2c <- convert_via_lookup(copy(input_dt), md$postal[nis_version == "2019"],
                              "cd_postal", "cd_commune_nis")
    if (to == "NIS_COMMUNE_2019") return(p2c)
    nxt <- route_conversion(data.table(code_from = p2c$code_to), "NIS_COMMUNE_2019", to, md)
    return(data.table(code_from = p2c$code_from,
                      code_to   = nxt$code_to[match(p2c$code_to, nxt$code_from)]))
  }

  abort(
    sprintf("No conversion route from '%s' to '%s'. Use list_available_conversions() to see all supported paths.",
            from, to),
    class = "rcl_no_route", from = from, to = to
  )
}

# Helper: retrieve NIS BEFORE_2019 master table, erroring clearly if absent
.get_master_b19 <- function(md) {
  m <- md$communes[nis_version == "BEFORE_2019"]
  if (nrow(m) == 0L)
    abort("NIS BEFORE_2019 data not loaded. Ensure REFNIS_BEFORE_2019.xls is in data/raw/ and reload.",
          class = "rcl_data_missing")
  m
}

# Helper: NIS_COMMUNE_2025 -> NUTS 2027 (direct or chained via NUTS3)
.route_nis2025_nuts2027 <- function(input_dt, to, md) {
  comm2025_nuts <- md$communes[nis_version == "2025" & !is.na(cd_nuts3_2027),
                                .(cd_commune, cd_nuts3_2027)]
  if (nrow(comm2025_nuts) == 0L)
    abort(
      sprintf(paste0("Conversion NIS_COMMUNE_2025 -> %s requires 'REFNIS_2025-NUTS_2027.xlsx'",
                     " in data/raw/.\nDrop the file there and run rebuild_master_data()."), to),
      class = "rcl_data_missing"
    )
  if (to == "NUTS3_2027")
    return(convert_via_lookup(input_dt, comm2025_nuts, "cd_commune", "cd_nuts3_2027"))
  # NUTS2 or NUTS1: chain via NUTS3
  nuts3 <- convert_via_lookup(input_dt, comm2025_nuts, "cd_commune", "cd_nuts3_2027")
  upper <- route_conversion(data.table(code_from = nuts3$code_to), "NUTS3_2027", to, md)
  data.table(code_from = nuts3$code_from,
             code_to   = upper$code_to[match(nuts3$code_to, upper$code_from)])
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
    warn(sprintf("%d code(s) could not be converted (no match found)", n_na),
         class = "rcl_unmatched_codes")
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
    warn(sprintf("%d code(s) could not be converted (no match found)", n_na),
         class = "rcl_unmatched_codes")
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

  changes <- md$nis_changes[from_version == "2019"]

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

  changes <- md$nis_changes[from_version == "2019"]

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
  comm_2019_codes <- md$communes[nis_version == "2019",    cd_commune]
  comm_b19_codes  <- md$communes[nis_version == "BEFORE_2019", cd_commune]

  result <- copy(input_dt)
  result[, code_to := NA_integer_]
  result[, nature  := NA_character_]

  # Unchanged codes (exist in both versions)
  unchanged <- intersect(comm_b19_codes, comm_2019_codes)
  result[code_from %in% unchanged, `:=`(code_to = code_from, nature = "UNCHANGED")]

  # Merged codes: use change table if available
  merged_codes <- setdiff(comm_b19_codes, comm_2019_codes)
  if (length(merged_codes) > 0 && any(result$code_from %in% merged_codes)) {
    b19_changes <- md$nis_changes[from_version == "BEFORE_2019"]
    if (nrow(b19_changes) > 0) {
      unresolved <- result[is.na(code_to) & code_from %in% merged_codes]
      resolved <- merge(unresolved[, .(code_from)],
                        b19_changes[, .(cd_refnis_old, cd_refnis_new)],
                        by.x = "code_from", by.y = "cd_refnis_old", all.x = TRUE)
      resolved[!is.na(cd_refnis_new), `:=`(code_to = cd_refnis_new, nature = "FUSION")]
      resolved[, cd_refnis_new := NULL]
      result <- rbind(result[!(code_from %in% merged_codes) | !is.na(code_to)], resolved)
    } else {
      n_merged_input <- sum(result$code_from %in% merged_codes, na.rm = TRUE)
      if (n_merged_input > 0) {
        warn(
          sprintf(paste0("%d code(s) are merged communes with no NIS 2019 equivalent. ",
                         "Provide REFNIS_CHANGE_BEFORE2019.xlsx in data/raw/ for full mapping."),
                  n_merged_input),
          class = "rcl_data_missing"
        )
      }
    }
  }

  return(result[, .(code_from, code_to, nature)])
}

#' List all available conversion paths
#'
#' @return data.table describing available conversions
#' @examples
#' list_available_conversions()
#' @export
list_available_conversions <- function() {
  edges <- rbindlist(lapply(CONVERSION_GRAPH_EDGES, as.data.table))
  edges[, .(from, to, relation, notes)]
}
