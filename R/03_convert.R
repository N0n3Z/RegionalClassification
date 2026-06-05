# ==============================================================================
# 03_convert.R - Conversion functions between classifications
# ==============================================================================
# Phase 2: engine now reads md$crosswalks for every single-hop lookup.
# All hand-coded handler closures (.ROUTE_TABLE, factory functions, and
# temporal/Type-D helpers) have been removed; conversion.R is now a thin
# dispatch layer over the crosswalks table produced by build_master_table().
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
#' @return data.table with columns \code{code_from}, \code{code_to}, \code{nature}.
#'   \code{nature} is \code{NA} for most conversions; for NIS temporal conversions
#'   (2019 \eqn{\leftrightarrow} 2025 / BEFORE_2019 \eqn{\to} 2019) it carries the
#'   change reason: \code{"UNCHANGED"}, \code{"FUSION"}, \code{"CHANGE_DSTR"}, or
#'   \code{"CHANGE_PROV"}.
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
#' @return data.table with columns \code{code_from}, \code{code_to}, \code{nature}
#'   (see \code{\link{convert_codes}}).
execute_conversion <- function(codes, from, to, master_data) {

  .validate_master_data(master_data)

  input_dt <- data.table(code_from = codes)

  # Normalize classification identifiers
  from_norm <- normalize_classification_id(from)
  to_norm   <- normalize_classification_id(to)

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
# Crosswalk-based hop executor (Phase 2 engine core)
# ------------------------------------------------------------------------------

# Generic single hop: looks up the (from_id, to_id) rows in md$crosswalks and
# joins input codes against them.  M:N edges (Verviers 1:N, Brabant M:N, the
# 3 cross-NUTS3 NIS 2025 fusions) are handled natively via allow.cartesian.
# Returns a data.table(code_from chr, code_to chr, nature chr) so that the
# caller can re-coerce to the canonical node type after the lookup.
.crosswalk_hop <- function(input_dt, from, to, md) {
  lkp <- md$crosswalks[from_id == from & to_id == to,
                        .(code_from, code_to, nature)]
  ic  <- data.table(code_from = as.character(input_dt$code_from))
  res <- merge(ic, lkp, by = "code_from", all.x = TRUE,
               allow.cartesian = TRUE)
  n_na <- sum(is.na(res$code_to))
  if (n_na > 0L)
    warn(sprintf("%d code(s) could not be converted (no match found)", n_na),
         class = "rcl_unmatched_codes")
  res[, .(code_from, code_to, nature)]
}

# Normalize to the canonical 3-column schema: (code_from, code_to, nature).
# Adds nature = NA_character_ if absent; enforces column order.
# Called at every return point of route_conversion().
#
# Phase 4b: when `from` and `to` are supplied, fills any remaining NA nature
# values according to the edge's perimeter semantics:
#   - identity / nesting (1:1 or N:1, non-temporal) → "RECODE"
#   - overlap (1:N or M:N)                          → "OVERLAP"
#   - temporal                                       → kept as-is (crosswalk
#       already carries UNCHANGED / FUSION / CHANGE_DSTR / CHANGE_PROV)
# Multi-hop paths are called *without* from/to so nature stays NA there.
.normalize_conversion_result <- function(dt, from = NULL, to = NULL) {
  if (!"nature" %in% names(dt)) dt[, nature := NA_character_]

  if (!is.null(from) && !is.null(to)) {
    if (from == to) {
      # Identity no-op: classify as RECODE (self-mapping, no information loss)
      dt[is.na(nature), nature := "RECODE"]
    } else {
      # Determine the perimeter semantics of the (from -> to) conversion.
      # check_conversion_path() is used (rather than a direct lookup in
      # CONVERSION_GRAPH_EDGES) because many crosswalk entries are shortcut /
      # composite edges (e.g. NIS_COMMUNE_2019 -> NUTS3_2021 is stored as a
      # single crosswalk hop but declared as two hops in CGE).  The graph BFS
      # result is cached by build_conversion_graph() so repeated calls are O(1).
      pc <- tryCatch(check_conversion_path(from, to), error = function(e) NULL)

      if (!is.null(pc) && !is.null(pc$perimeter_relations) &&
          length(pc$perimeter_relations) > 0L) {
        if (all(pc$perimeter_relations == "temporal")) {
          # Pure temporal path: crosswalk already holds UNCHANGED / FUSION /
          # CHANGE_DSTR / CHANGE_PROV — do not overwrite.
        } else if (isTRUE(pc$straddle_free)) {
          dt[is.na(nature), nature := "RECODE"]
        } else {
          dt[is.na(nature), nature := "OVERLAP"]
        }
      }
    }
  }

  setcolorder(dt, c("code_from", "code_to", "nature"))
  dt
}

#' Route conversion to the appropriate handler
#'
#' For a direct (from, to) edge present in md$crosswalks, performs a single
#' table lookup via .crosswalk_hop().  Otherwise, composes single-hop crosswalk
#' lookups along the shortest path in the crosswalk graph (.xw_path, built from
#' md$crosswalks so every hop is guaranteed to have rows).
#'
#' Output codes are re-coerced to the canonical type of each node
#' (.node_coerce, R/00b_registry.R) after the lookup, preserving the contract
#' that NIS codes are integer and NUTS codes are character.
#'
#' @param input_dt data.table with code_from column
#' @param from Normalized source classification
#' @param to Normalized target classification
#' @param md Master data (output from build_master_table)
#' @return data.table with code_from, code_to, nature
route_conversion <- function(input_dt, from, to, md) {

  if (from == to)
    return(.normalize_conversion_result(input_dt[, .(code_from, code_to = code_from)],
                                        from, to))

  input_dt <- copy(input_dt)
  input_dt[, code_from := .node_coerce(code_from, from)]

  # Direct hop: single crosswalk-table lookup
  if (!is.null(md$crosswalks) &&
      nrow(md$crosswalks[from_id == from & to_id == to]) > 0L) {
    res <- .crosswalk_hop(input_dt, from, to, md)
    res[, code_to   := .node_coerce(code_to,   to)]
    res[, code_from := .node_coerce(code_from, from)]
    return(.normalize_conversion_result(res, from, to))
  }

  # Multi-hop: compose single-hop crosswalk lookups along the crosswalk-graph path.
  # nature is intentionally NOT propagated across multi-hop paths (ill-defined
  # which hop's semantics should label the composite).
  composed <- .compose_via_handlers(copy(input_dt), from, to, md)
  if (!is.null(composed)) {
    composed[, code_to   := .node_coerce(code_to,   to)]
    composed[, code_from := .node_coerce(code_from, from)]
    return(.normalize_conversion_result(composed))
  }

  abort(
    sprintf("No conversion route from '%s' to '%s'. Use list_available_conversions() to see all supported paths.",
            from, to),
    class = "rcl_no_route", from = from, to = to
  )
}

# Mutable cache (filled after namespace lock) for the crosswalk-edge adjacency.
.route_cache <- new.env(parent = emptyenv())

# TRUE if `from` -> `to` is executable by the crosswalk engine: the identity, a
# direct crosswalk edge, or a multi-hop path composed entirely of crosswalk
# edges (.xw_path).  This is the EXECUTION predicate: it must mirror what
# route_conversion() can actually run, so the graph <-> executor parity test
# (test-route-parity.R) keeps its teeth.  Declared-graph reachability is a
# separate concern, handled by check_conversion_path() (05_conversion_check.R).
.route_is_executable <- function(from, to, md) {
  if (from == to) return(TRUE)
  !is.null(.xw_path(from, to, md))
}

# Adjacency list built exclusively from md$crosswalks unique (from_id, to_id)
# pairs.  Every edge in this graph is directly executable via .crosswalk_hop().
# Used by .compose_via_handlers() to find valid multi-hop execution paths.
# Cached per crosswalk row-count (invalidated when crosswalks are rebuilt).
.xw_graph <- function(md) {
  n   <- nrow(md$crosswalks)
  key <- paste0("xwg_", n)
  if (exists(key, envir = .route_cache, inherits = FALSE))
    return(get(key, envir = .route_cache))
  g    <- list()
  keys <- md$crosswalks[, unique(paste0(from_id, "__", to_id))]
  for (k in keys) {
    parts          <- strsplit(k, "__", fixed = TRUE)[[1]]
    g[[parts[1L]]] <- unique(c(g[[parts[1L]]], parts[2L]))
  }
  assign(key, g, envir = .route_cache)
  g
}

# Shortest path from `from` to `to` using only edges present in md$crosswalks
# (BFS).  Returns a character vector of nodes, or NULL if no path exists.
# Every hop in the returned path is guaranteed to have crosswalk rows.
.xw_path <- function(from, to, md) {
  g <- .xw_graph(md)
  if (is.null(g[[from]])) return(NULL)
  queue   <- list(list(node = from, path = from))
  visited <- from
  while (length(queue) > 0L) {
    cur   <- queue[[1L]]; queue <- queue[-1L]
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

# Compose single-hop crosswalk lookups along the crosswalk-graph path from
# `from` to `to`.  Uses .xw_path() (BFS over md$crosswalks edges) so that every
# hop in the path is guaranteed to have crosswalk rows — a path over the
# declared CONVERSION_GRAPH_EDGES could include composite edges absent from the
# crosswalk table.
# Joins by code value (not position) so M:N hops fan out correctly; input order
# is restored at the end.
# Returns data.table(code_from, code_to) — nature is not propagated across
# multi-hop paths; .normalize_conversion_result() will set it to NA.
.compose_via_handlers <- function(input_dt, from, to, md) {
  path <- .xw_path(from, to, md)
  if (is.null(path) || length(path) < 2L) return(NULL)

  mapping <- data.table(.ord     = seq_len(nrow(input_dt)),
                        code_from = input_dt$code_from,
                        cur       = input_dt$code_from)

  for (k in seq_len(length(path) - 1L)) {
    step_from <- path[k]
    step_to   <- path[k + 1L]
    hop_input <- data.table(code_from = .node_coerce(unique(mapping$cur), step_from))
    hop       <- .crosswalk_hop(hop_input, step_from, step_to, md)
    hop       <- hop[, .(.k = as.character(code_from), .nxt = code_to)]
    mapping[, .k := as.character(cur)]
    mapping   <- merge(mapping, hop, by = ".k", all.x = TRUE,
                       allow.cartesian = TRUE)
    mapping[, cur := .nxt]
    mapping[, c(".k", ".nxt") := NULL]
  }

  setorder(mapping, .ord)
  mapping[, .(code_from, code_to = cur)]
}

#' List all available conversion paths
#'
#' Returns a data.table with one row per declared edge in
#' \code{CONVERSION_GRAPH_EDGES}.  The \code{perimeter_relation} column
#' summarises the spatial semantics of each edge (see
#' \code{\link{is_perimeter_preserving}}):
#' \describe{
#'   \item{temporal}{Same system, different edition.}
#'   \item{identity}{Exact 1:1 correspondence, no splitting.}
#'   \item{nesting}{Many fine units aggregate into one coarser unit (N:1).}
#'   \item{overlap}{A source unit straddles multiple target units (1:N / M:N).}
#' }
#' @return data.table with columns \code{from}, \code{to}, \code{relation},
#'   \code{perimeter_relation}, \code{notes}.
#' @examples
#' list_available_conversions()
#' @export
list_available_conversions <- function() {
  # Build from scalar fields only — some edges carry vector fields (e.g.
  # ambiguous_codes) that rbindlist(as.data.table(e)) would expand into
  # multiple rows, misaligning the perimeter_relation vector.
  edges <- rbindlist(lapply(CONVERSION_GRAPH_EDGES, function(e) {
    data.table(
      from     = e$from,
      to       = e$to,
      relation = e$relation,
      notes    = if (!is.null(e$notes) && length(e$notes) == 1L) e$notes
                 else NA_character_
    )
  }), use.names = TRUE, fill = TRUE)
  prel <- vapply(CONVERSION_GRAPH_EDGES, .edge_perimeter_relation, character(1))
  edges[, perimeter_relation := prel]
  edges[, .(from, to, relation, perimeter_relation, notes)]
}

.validate_master_data <- function(master_data) {
  if (!is.list(master_data))
    abort("master_data must be a list produced by load_master_data() or build_master_table().",
          class = "rcl_invalid_input")
  missing <- setdiff(c("communes", "postal", "nis_changes"), names(master_data))
  if (length(missing) > 0L)
    abort(
      sprintf("master_data is missing required tables: %s. Run load_master_data() to rebuild.",
              paste(missing, collapse = ", ")),
      class = "rcl_data_missing", tables = missing
    )
  if (is.null(master_data$communes) || nrow(master_data$communes) == 0L)
    abort("master_data$communes is empty. Run load_master_data() to rebuild.",
          class = "rcl_data_missing")
  if (is.null(master_data$crosswalks))
    abort(paste0("master_data$crosswalks is required for conversion but is NULL.\n",
                 "Run rebuild_master_data() to regenerate it."),
          class = "rcl_data_missing")
}
