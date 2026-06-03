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

  .validate_master_data(master_data)

  input_dt <- data.table(code_from = codes)

  # Normalize classification identifiers
  from_norm <- normalize_classification_id(from)
  to_norm <- normalize_classification_id(to)

  # Route to appropriate conversion function
  result <- route_conversion(input_dt, from_norm, to_norm, master_data)

  return(result)
}

#' @noRd
normalize_classification_id <- function(class_id) {
  id <- toupper(trimws(class_id))
  if (id %in% VALID_CLASSIFICATIONS) return(id)
  abort(
    sprintf(
      paste0(
        "Classification '%s' is not recognised.\n",
        "Valid identifiers (case-insensitive):\n  %s\n",
        "See ?classification_reference."
      ),
      class_id,
      paste(sort(VALID_CLASSIFICATIONS), collapse = ", ")
    ),
    class = "rcl_invalid_classification",
    classification = class_id,
    valid = VALID_CLASSIFICATIONS
  )
}

# ------------------------------------------------------------------------------
# Single-hop handler factories
# ------------------------------------------------------------------------------
# The vast majority of conversions are a single column lookup in the communes
# master, filtered to one NIS version. These factories capture that pattern so
# each route entry below is a one-line declaration of (version, from, to) rather
# than a copy-pasted closure body. Adding a future NIS/NUTS version becomes a
# matter of adding declarations, not rewriting bodies.

# NIS-commune-keyed hop: coerce input to integer, look up `to_col` in the
# communes master for one NIS version.
.master_hop <- function(version, from_col, to_col) {
  force(version); force(from_col); force(to_col)
  function(i, md) {
    convert_via_master(i, md$communes[nis_version == version], from_col, to_col)
  }
}

# Same as .master_hop but sources the NIS BEFORE_2019 slice, erroring clearly
# (via .get_master_b19) when that optional data is not loaded.
.b19_hop <- function(from_col, to_col) {
  force(from_col); force(to_col)
  function(i, md) {
    m <- .get_master_b19(md)
    convert_via_master(i, m, from_col, to_col)
  }
}

# Distinct-pair lookup inside the communes master, for non-commune keys (e.g.
# province->region, NUTS hierarchy hops). `version = NULL` uses all rows.
# `drop_na` removes rows whose "to" or "from" column is NA before building the
# lookup (mirrors the explicit !is.na(...) filters of the original handlers).
.master_pair_hop <- function(version, from_col, to_col,
                             drop_na = c("none", "to", "from")) {
  force(version); force(from_col); force(to_col)
  drop_na <- match.arg(drop_na)
  function(i, md) {
    sub <- if (is.null(version)) md$communes else md$communes[nis_version == version]
    if (drop_na == "to")   sub <- sub[!is.na(get(to_col))]
    if (drop_na == "from") sub <- sub[!is.na(get(from_col))]
    lkp <- unique(sub[, .SD, .SDcols = c(from_col, to_col)])
    convert_via_lookup(i, lkp, from_col, to_col)
  }
}

# Dispatch table: maps "FROM__TO" to a handler function(input_dt, md).
# Defined at package level so it is built once at load time. Each handler
# receives input_dt (data.table with code_from) and md (master data) and returns
# a data.table(code_from, code_to). Multi-hop conversions are composed
# automatically from these single hops by route_conversion() / .compose_via_handlers().
.ROUTE_TABLE <- list(

  # --- POSTAL -> NIS (direct) ---
  "POSTAL__NIS_COMMUNE_2019" = function(i, md)
    convert_via_lookup(i, md$postal[nis_version == "2019"], "cd_postal", "cd_commune_nis"),
  "POSTAL__NIS_COMMUNE_2025" = function(i, md)
    convert_via_lookup(i, md$postal[nis_version == "2025"], "cd_postal", "cd_commune_nis"),

  # --- NIS_COMMUNE_2019 -> * ---
  "NIS_COMMUNE_2019__NIS_ARRONDISSEMENT_2019" = .master_hop("2019", "cd_commune", "cd_arr"),
  "NIS_COMMUNE_2019__NIS_PROVINCE_2019"       = .master_hop("2019", "cd_commune", "cd_province"),
  "NIS_COMMUNE_2019__NIS_REGION_2019"         = .master_hop("2019", "cd_commune", "cd_region"),
  "NIS_COMMUNE_2019__NUTS_LAU_2021"           = .master_hop("2019", "cd_commune", "cd_nuts_lau"),
  "NIS_COMMUNE_2019__NUTS3_2021"              = .master_hop("2019", "cd_commune", "cd_nuts3"),
  "NIS_COMMUNE_2019__NUTS2_2021"              = .master_hop("2019", "cd_commune", "cd_nuts2"),
  "NIS_COMMUNE_2019__NUTS1_2021"              = .master_hop("2019", "cd_commune", "cd_nuts1"),
  "NIS_COMMUNE_2019__NUTS0" = function(i, md)
    data.table(code_from = i$code_from, code_to = "BE"),
  "NIS_COMMUNE_2019__NUTS3_2027"              = .master_hop("2019", "cd_commune", "cd_nuts3_2027"),
  "NIS_COMMUNE_2019__NUTS2_2027"              = .master_hop("2019", "cd_commune", "cd_nuts2_2027"),
  "NIS_COMMUNE_2019__NUTS1_2027"              = .master_hop("2019", "cd_commune", "cd_nuts1_2027"),
  "NIS_COMMUNE_2019__INTERNAL_ARRONDISSEMENT" = .master_hop("2019", "cd_commune", "cd_arr_internal"),
  "NIS_COMMUNE_2019__NIS_COMMUNE_2025" = function(i, md) {
    convert_nis2019_to_nis2025(i, md)
  },

  # --- NIS_COMMUNE_BEFORE_2019 -> * ---
  "NIS_COMMUNE_BEFORE_2019__NIS_ARRONDISSEMENT_BEFORE_2019" = .b19_hop("cd_commune", "cd_arr"),
  "NIS_COMMUNE_BEFORE_2019__NIS_PROVINCE_BEFORE_2019"       = .b19_hop("cd_commune", "cd_province"),
  "NIS_COMMUNE_BEFORE_2019__NIS_REGION_BEFORE_2019"         = .b19_hop("cd_commune", "cd_region"),
  "NIS_COMMUNE_BEFORE_2019__NUTS3_2021"                     = .b19_hop("cd_commune", "cd_nuts3"),
  "NIS_COMMUNE_BEFORE_2019__NUTS2_2021"                     = .b19_hop("cd_commune", "cd_nuts2"),
  "NIS_COMMUNE_BEFORE_2019__NUTS3_2027"                     = .b19_hop("cd_commune", "cd_nuts3_2027"),
  "NIS_COMMUNE_BEFORE_2019__INTERNAL_ARRONDISSEMENT"        = .b19_hop("cd_commune", "cd_arr_internal"),
  "NIS_COMMUNE_BEFORE_2019__NIS_COMMUNE_2019" = function(i, md) {
    convert_nis_before2019_to_nis2019(i, md)
  },

  # --- NIS_COMMUNE_2025 -> * ---
  "NIS_COMMUNE_2025__NIS_ARRONDISSEMENT_2025" = .master_hop("2025", "cd_commune", "cd_arr"),
  "NIS_COMMUNE_2025__NIS_PROVINCE_2025"       = .master_hop("2025", "cd_commune", "cd_province"),
  "NIS_COMMUNE_2025__NIS_REGION_2025"         = .master_hop("2025", "cd_commune", "cd_region"),
  "NIS_COMMUNE_2025__NIS_COMMUNE_2019" = function(i, md) {
    convert_nis2025_to_nis2019(i, md)
  },
  "NIS_COMMUNE_2025__NUTS3_2027" = function(i, md) {
    .route_nis2025_nuts2027(i, "NUTS3_2027", md)
  },
  "NIS_COMMUNE_2025__NUTS2_2027" = function(i, md) {
    .route_nis2025_nuts2027(i, "NUTS2_2027", md)
  },
  "NIS_COMMUNE_2025__NUTS1_2027" = function(i, md) {
    .route_nis2025_nuts2027(i, "NUTS1_2027", md)
  },

  # --- NIS ARRONDISSEMENT -> * ---
  "NIS_ARRONDISSEMENT_2019__NUTS3_2021" = function(i, md) {
    convert_arr_to_nuts3(i, md$communes[nis_version == "2019"])
  },
  "NIS_ARRONDISSEMENT_2019__INTERNAL_ARRONDISSEMENT" = function(i, md) {
    convert_arr_to_internal(i, md$communes[nis_version == "2019"])
  },
  "NIS_ARRONDISSEMENT_2019__NIS_PROVINCE_2019" = function(i, md) {
    arr_prov <- unique(md$communes[nis_version == "2019", .(cd_arr, cd_province)])
    convert_via_lookup(i, arr_prov, "cd_arr", "cd_province")
  },
  "NIS_ARRONDISSEMENT_2025__NIS_PROVINCE_2025" = function(i, md) {
    arr_prov <- unique(md$communes[nis_version == "2025", .(cd_arr, cd_province)])
    convert_via_lookup(i, arr_prov, "cd_arr", "cd_province")
  },
  "NIS_ARRONDISSEMENT_BEFORE_2019__NIS_PROVINCE_BEFORE_2019" = function(i, md) {
    m <- .get_master_b19(md)
    convert_via_lookup(i, unique(m[, .(cd_arr, cd_province)]), "cd_arr", "cd_province")
  },

  # --- NIS PROVINCE -> NIS REGION ---
  # (Simple per the conversion graph, but previously had no executable handler.)
  "NIS_PROVINCE_2019__NIS_REGION_2019"               = .master_pair_hop("2019", "cd_province", "cd_region"),
  "NIS_PROVINCE_2025__NIS_REGION_2025"               = .master_pair_hop("2025", "cd_province", "cd_region"),
  "NIS_PROVINCE_BEFORE_2019__NIS_REGION_BEFORE_2019" = function(i, md) {
    m <- .get_master_b19(md)
    convert_via_lookup(i, unique(m[, .(cd_province, cd_region)]), "cd_province", "cd_region")
  },

  # --- NUTS3_2021 -> * ---
  "NUTS3_2021__NUTS2_2021"              = .master_pair_hop("2019", "cd_nuts3", "cd_nuts2"),
  "NUTS3_2021__INTERNAL_ARRONDISSEMENT" = .master_pair_hop("2019", "cd_nuts3", "cd_arr_internal", "to"),
  "NUTS3_2021__NIS_ARRONDISSEMENT_2019" = .master_pair_hop("2019", "cd_nuts3", "cd_arr", "from"),
  "NUTS3_2021__NUTS3_2027" = function(i, md) {
    nuts3_map <- NUTS2021_TO_NUTS2027[nchar(nuts_2021) == 5]
    result <- merge(i, nuts3_map, by.x = "code_from", by.y = "nuts_2021", all.x = TRUE)
    setnames(result, "nuts_2027", "code_to")
    result[is.na(code_to), code_to := code_from]
    result[, .(code_from, code_to)]
  },

  # --- NUTS upward aggregation (2021) ---
  # (Simple per the conversion graph, but previously had no executable handler;
  #  this is what made convert_codes(<NUTS3>, ..., "NUTS1_2021") fail the parity
  #  with check_conversion_path().)
  "NUTS2_2021__NUTS1_2021" = .master_pair_hop("2019", "cd_nuts2", "cd_nuts1", "to"),
  "NUTS1_2021__NUTS0"      = .master_pair_hop("2019", "cd_nuts1", "cd_nuts0", "to"),

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
  "INTERNAL_ARRONDISSEMENT__NUTS3_2021" = .master_pair_hop("2019", "cd_arr_internal", "cd_nuts3", "from"),
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
  "NUTS3_2027__NUTS2_2027" = .master_pair_hop(NULL, "cd_nuts3_2027", "cd_nuts2_2027", "from"),

  # --- NUTS upward aggregation (2027) ---
  "NUTS2_2027__NUTS1_2027" = .master_pair_hop(NULL, "cd_nuts2_2027", "cd_nuts1_2027", "from"),
  "NUTS1_2027__NUTS0"      = .master_pair_hop(NULL, "cd_nuts1_2027", "cd_nuts0_2027", "from")
)

#' Route conversion to the appropriate handler
#'
#' Looks up the "FROM__TO" key in .ROUTE_TABLE for a direct single-hop handler.
#' When no direct handler exists, composes existing single-hop handlers along a
#' path in the handler graph (.compose_via_handlers). This keeps execution in
#' lock-step with what check_conversion_path() declares reachable: there is a
#' single source of truth for topology (the graph), and execution covers every
#' multi-hop path the graph supports without a hand-written handler per pair.
#'
#' @param input_dt data.table with code_from column
#' @param from Normalized source classification
#' @param to Normalized target classification
#' @param md Master data (output from build_master_table)
#' @return data.table with code_from, code_to
route_conversion <- function(input_dt, from, to, md) {

  if (from == to) return(input_dt[, .(code_from, code_to = code_from)])

  input_dt <- copy(input_dt)
  input_dt[, code_from := .node_coerce(code_from, from)]

  handler <- .ROUTE_TABLE[[paste0(from, "__", to)]]
  if (!is.null(handler)) return(handler(input_dt, md))

  composed <- .compose_via_handlers(copy(input_dt), from, to, md)
  if (!is.null(composed)) return(composed)

  abort(
    sprintf("No conversion route from '%s' to '%s'. Use list_available_conversions() to see all supported paths.",
            from, to),
    class = "rcl_no_route", from = from, to = to
  )
}

# Mutable cache (filled after namespace lock) for the handler-edge adjacency.
.route_cache <- new.env(parent = emptyenv())

# Adjacency list of directly-executable single hops, derived from the keys of
# .ROUTE_TABLE ("A__B" => edge A -> B). Classification ids never contain the
# "__" separator, so splitting on it yields exactly two nodes.
.handler_graph <- function() {
  if (exists("graph", envir = .route_cache, inherits = FALSE))
    return(get("graph", envir = .route_cache))
  g <- list()
  for (key in names(.ROUTE_TABLE)) {
    parts <- strsplit(key, "__", fixed = TRUE)[[1]]
    g[[parts[1]]] <- c(g[[parts[1]]], parts[2])
  }
  assign("graph", g, envir = .route_cache)
  g
}

# Shortest path between two classifications using only executable single hops
# (BFS over the handler graph). Returns a character vector of nodes, or NULL.
# Because it only ever traverses edges that have a handler, every hop of the
# returned path is guaranteed executable.
.handler_path <- function(from, to) {
  g <- .handler_graph()
  if (is.null(g[[from]])) return(NULL)
  queue   <- list(list(node = from, path = from))
  visited <- from
  while (length(queue) > 0) {
    cur   <- queue[[1]]; queue <- queue[-1]
    for (nb in g[[cur$node]]) {
      if (nb == to) return(c(cur$path, nb))
      if (!nb %in% visited) {
        visited <- c(visited, nb)
        queue[[length(queue) + 1L]] <- list(node = nb, path = c(cur$path, nb))
      }
    }
  }
  NULL
}

# TRUE if `from` -> `to` is executable (identity, direct handler, or composable
# path). Used by the test suite to assert parity with check_conversion_path():
# every conversion the graph reports as simple must be executable here.
.route_is_executable <- function(from, to) {
  if (from == to) return(TRUE)
  if (!is.null(.ROUTE_TABLE[[paste0(from, "__", to)]])) return(TRUE)
  !is.null(.handler_path(from, to))
}

# Compose single-hop handlers along the handler-graph path from `from` to `to`.
# Joins by code value (not position), so M:N hops fan out correctly and input
# order is restored at the end. Returns data.table(code_from, code_to) or NULL.
.compose_via_handlers <- function(input_dt, from, to, md) {
  path <- .handler_path(from, to)
  if (is.null(path) || length(path) < 2L) return(NULL)

  mapping <- data.table(.ord = seq_len(nrow(input_dt)),
                        code_from = input_dt$code_from,
                        cur       = input_dt$code_from)

  for (k in seq_len(length(path) - 1L)) {
    handler <- .ROUTE_TABLE[[paste0(path[k], "__", path[k + 1L])]]
    hop_input <- data.table(code_from = .node_coerce(unique(mapping$cur), path[k]))
    hop     <- handler(hop_input, md)
    hop     <- hop[, .(.k = as.character(code_from), .nxt = code_to)]
    mapping[, .k := as.character(cur)]
    mapping <- merge(mapping, hop, by = ".k", all.x = TRUE, allow.cartesian = TRUE)
    mapping[, cur := .nxt]
    mapping[, c(".k", ".nxt") := NULL]
  }

  setorder(mapping, .ord)
  mapping[, .(code_from, code_to = cur)]
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

.validate_master_data <- function(master_data) {
  if (!is.list(master_data))
    abort("master_data must be a list produced by load_master_data() or build_master_table().",
          class = "rcl_invalid_input")
  missing <- setdiff(c("communes", "postal", "nis_changes"), names(master_data))
  if (length(missing) > 0)
    abort(
      sprintf("master_data is missing required tables: %s. Run load_master_data() to rebuild.",
              paste(missing, collapse = ", ")),
      class = "rcl_data_missing", tables = missing
    )
  if (is.null(master_data$communes) || nrow(master_data$communes) == 0L)
    abort("master_data$communes is empty. Run load_master_data() to rebuild.",
          class = "rcl_data_missing")
}
