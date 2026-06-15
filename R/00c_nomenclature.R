# ==============================================================================
# 00c_nomenclature.R  -  Structured `nomenclature` object (programmatic API)
# ==============================================================================
# A `nomenclature` bundles (system, level, version) and resolves to the single
# canonical node id used internally by the engine (e.g. "NIS_MUNICIPALITY_2019").
# It is an ADDITIVE layer: string identifiers keep working everywhere. The object
# enables dynamic/programmatic construction (loop over versions/levels) and
# explicit intra-system aggregation links (commune -> arrondissement -> ...).
#
# Source order: this file loads after 00b_registry.R, so CLASSIFICATION_NODES /
# .node() are available.
# ==============================================================================


# ------------------------------------------------------------------------------
# (system, level, version) -> id index, built once from the registry
# ------------------------------------------------------------------------------
.nom_index <- local({
  cache <- NULL
  function() {
    if (!is.null(cache)) return(cache)
    ids <- names(CLASSIFICATION_NODES)
    cache <<- data.frame(
      id      = ids,
      system  = vapply(CLASSIFICATION_NODES, function(n) n$system, ""),
      level   = vapply(CLASSIFICATION_NODES, function(n) n$level, ""),
      version = vapply(CLASSIFICATION_NODES, function(n) {
        v <- n$version
        if (is.null(v) || (length(v) == 1L && is.na(v))) NA_character_ else as.character(v)
      }, ""),
      stringsAsFactors = FALSE,
      row.names = NULL
    )
    cache
  }
})

.na_disp <- function(x) if (is.null(x) || is.na(x)) "<any>" else x

.format_valid_combos <- function() {
  idx <- .nom_index()
  paste(sprintf("  %-26s (system=%s, level=%s, version=%s)",
                idx$id, idx$system, idx$level,
                ifelse(is.na(idx$version), "-", idx$version)),
        collapse = "\n")
}

# Resolve a (system, level, version) triplet to a single canonical id.
# level / version may be NA_character_ ("any"); resolution must be unambiguous.
.resolve_triplet <- function(system, level, version) {
  idx  <- .nom_index()
  keep <- idx$system == system
  if (!is.na(level)   && nzchar(level))   keep <- keep & !is.na(idx$level)   & idx$level   == level
  if (!is.na(version) && nzchar(version)) keep <- keep & !is.na(idx$version) & idx$version == version
  hits <- idx$id[keep]

  if (length(hits) == 1L) return(hits)

  if (length(hits) == 0L) {
    abort(
      sprintf(paste0("No classification matches system='%s', level='%s', version='%s'.\n",
                     "Valid nomenclatures:\n%s"),
              system, .na_disp(level), .na_disp(version), .format_valid_combos()),
      class = "rcl_invalid_classification",
      system = system, level = level, version = version
    )
  }

  abort(
    sprintf(paste0("Ambiguous nomenclature: system='%s', level='%s', version='%s' ",
                   "matches %d nodes (%s).\nSpecify `level` and/or `version`."),
            system, .na_disp(level), .na_disp(version),
            length(hits), paste(hits, collapse = ", ")),
    class = "rcl_invalid_classification",
    system = system, level = level, version = version, matches = hits
  )
}

# Low-level constructor (no validation; id already resolved).
.new_nomenclature <- function(system, level, version, id) {
  structure(
    list(system  = system,
         level   = level,
         version = if (is.null(version)) NA_character_ else version,
         id      = id),
    class = "nomenclature"
  )
}


# ------------------------------------------------------------------------------
# Public constructor + predicate
# ------------------------------------------------------------------------------

#' Create a classification nomenclature object
#'
#' Builds a structured handle for a classification, identified by its
#' \code{system} (NIS, NUTS, POSTAL, NBB), \code{level} (municipality,
#' district, province, region, country, postal) and \code{version}
#' (e.g. "2019", "2025", "BEFORE_2019", "2021", "2027"). The triplet must
#' resolve to exactly one known classification.
#'
#' \code{level} and/or \code{version} may be omitted when the remaining
#' components are unambiguous (e.g. \code{nomenclature("POSTAL")},
#' \code{nomenclature("NUTS", "country")}).
#'
#' This object is the recommended way to work programmatically (loop over
#' versions/levels) and to navigate aggregation links
#' (\code{\link{nomenclature_children}}, \code{\link{nomenclature_parents}}).
#' Plain string identifiers (e.g. \code{"NIS_MUNICIPALITY_2019"}) remain accepted by
#' all functions.
#'
#' @param system Classification system: "NIS", "NUTS", "POSTAL", "NBB"
#'   (case-insensitive). Passing an existing \code{nomenclature} returns it
#'   unchanged.
#' @param level Granularity within the system (case-insensitive), or \code{NULL}.
#' @param version Version string or number, or \code{NULL} for unversioned
#'   systems.
#' @return An object of class \code{nomenclature}.
#' @examples
#' nomenclature("NIS", "municipality", "2019")
#' nomenclature("NUTS", "district", 2021)
#' nomenclature("POSTAL")
#' # Dynamic construction:
#' lapply(c("2019", "2025"), function(v) nomenclature("NIS", "municipality", v))
#' @export
nomenclature <- function(system, level = NULL, version = NULL) {
  if (is_nomenclature(system)) return(system)
  if (missing(system) || is.null(system) || !nzchar(trimws(as.character(system)[1])))
    abort("`system` is required (e.g. 'NIS', 'NUTS', 'POSTAL', 'NBB').",
          class = "rcl_invalid_classification")

  system  <- toupper(trimws(as.character(system)))
  level   <- if (is.null(level))   NA_character_ else tolower(trimws(as.character(level)))
  version <- if (is.null(version)) NA_character_ else trimws(as.character(version))

  id <- .resolve_triplet(system, level, version)
  n  <- .node(id)
  .new_nomenclature(n$system, n$level,
                    if (is.null(n$version)) NA_character_ else n$version, id)
}

#' Test whether an object is a nomenclature
#'
#' @param x Any object.
#' @return \code{TRUE} if \code{x} is a \code{nomenclature}, else \code{FALSE}.
#' @export
is_nomenclature <- function(x) inherits(x, "nomenclature")


# ------------------------------------------------------------------------------
# id <-> object bridges (the boundary used by the engine)
# ------------------------------------------------------------------------------

# Object/string -> canonical id. Accepts a nomenclature (preferred) or a string
# identifier (back-compatible). Aborts with rcl_invalid_classification otherwise.
# @noRd
.nom_to_id <- function(x) {
  if (is_nomenclature(x)) return(x$id)
  id <- toupper(trimws(as.character(x)))
  if (length(id) == 1L && !is.na(id) && id %in% names(CLASSIFICATION_NODES))
    return(id)
  abort(
    sprintf(
      paste0("Classification '%s' is not recognised.\n",
             "Pass a nomenclature() object or a valid identifier. Valid identifiers:\n  %s"),
      paste(as.character(x), collapse = ", "),
      paste(sort(names(CLASSIFICATION_NODES)), collapse = ", ")
    ),
    class = "rcl_invalid_classification",
    classification = x, valid = names(CLASSIFICATION_NODES)
  )
}

# Canonical id -> nomenclature object.
# @noRd
.id_to_nom <- function(id) {
  n <- .node(id)
  .new_nomenclature(n$system, n$level,
                    if (is.null(n$version)) NA_character_ else n$version, id)
}


# ------------------------------------------------------------------------------
# Accessors
# ------------------------------------------------------------------------------

#' Nomenclature components
#'
#' Extract the system, level or version of a \code{nomenclature}.
#'
#' @param x A \code{nomenclature} object.
#' @return A length-one character vector (\code{nom_version} returns
#'   \code{NA_character_} for unversioned systems).
#' @name nomenclature-accessors
#' @examples
#' n <- nomenclature("NIS", "municipality", "2019")
#' nom_system(n)
#' nom_level(n)
#' nom_version(n)
#' @export
nom_system <- function(x) {
  if (!is_nomenclature(x)) x <- .id_to_nom(.nom_to_id(x))
  x$system
}

#' @rdname nomenclature-accessors
#' @export
nom_level <- function(x) {
  if (!is_nomenclature(x)) x <- .id_to_nom(.nom_to_id(x))
  x$level
}

#' @rdname nomenclature-accessors
#' @export
nom_version <- function(x) {
  if (!is_nomenclature(x)) x <- .id_to_nom(.nom_to_id(x))
  x$version
}


# ------------------------------------------------------------------------------
# S3 methods
# ------------------------------------------------------------------------------

#' @export
format.nomenclature <- function(x, ...) {
  v <- if (is.na(x$version)) "" else paste0(" / ", x$version)
  sprintf("<nomenclature: %s / %s%s>", x$system, x$level, v)
}

#' @export
print.nomenclature <- function(x, ...) {
  cat(format(x), "\n", sep = "")
  invisible(x)
}

#' @export
as.character.nomenclature <- function(x, ...) x$id

#' @export
Ops.nomenclature <- function(e1, e2) {
  if (.Generic %in% c("==", "!=")) {
    res <- .nom_to_id(e1) == .nom_to_id(e2)
    if (.Generic == "!=") res <- !res
    return(res)
  }
  abort(sprintf("Operator '%s' is not supported for nomenclature objects.", .Generic),
        class = "rcl_invalid_input")
}


# ------------------------------------------------------------------------------
# Introspection (programmatic discovery)
# ------------------------------------------------------------------------------

#' List available nomenclatures
#'
#' @param system Optional system filter ("NIS", "NUTS", "POSTAL", "NBB").
#' @return A list of \code{nomenclature} objects.
#' @examples
#' list_nomenclatures("NIS")
#' @export
list_nomenclatures <- function(system = NULL) {
  ids <- names(CLASSIFICATION_NODES)
  if (!is.null(system)) {
    system <- toupper(trimws(system))
    ids <- ids[vapply(CLASSIFICATION_NODES[ids],
                      function(n) n$system == system, logical(1))]
  }
  lapply(ids, .id_to_nom)
}

#' Levels / versions available for a system
#'
#' @param system Classification system ("NIS", "NUTS", "POSTAL", "NBB").
#' @return A character vector (\code{nomenclature_versions} may contain
#'   \code{NA} for unversioned systems).
#' @name nomenclature-discovery
#' @examples
#' nomenclature_levels("NIS")
#' nomenclature_versions("NUTS")
#' @export
nomenclature_levels <- function(system) {
  system <- toupper(trimws(system))
  idx <- .nom_index()
  unique(idx$level[idx$system == system])
}

#' @rdname nomenclature-discovery
#' @export
nomenclature_versions <- function(system) {
  system <- toupper(trimws(system))
  idx <- .nom_index()
  unique(idx$version[idx$system == system])
}


# ------------------------------------------------------------------------------
# Aggregation links (intra-system hierarchy)
# ------------------------------------------------------------------------------

#' Aggregation links between nomenclatures
#'
#' \code{nomenclature_children()} returns the finer level(s) a nomenclature is
#' the direct aggregation of (e.g. a district aggregates municipalities).
#' \code{nomenclature_parents()} returns the coarser level(s) that aggregate it
#' (e.g. a municipality is aggregated by a district; a district is
#' aggregated by BOTH a province and a region).
#'
#' The aggregation structure is a DAG, not a tree: a NIS district has two
#' parents (province and region) because a region is modelled as aggregating
#' arrondissements directly, and \code{NUTS_COUNTRY} aggregates both the 2021 and
#' 2027 NUTS region levels. Note that province -> region is itself a clean N:1
#' nesting in the conversion graph (since the 1995 Brabant split every province
#' belongs to exactly one region; Brussels uses a pseudo-province).
#'
#' @param x A \code{nomenclature} object (or a valid identifier).
#' @return A list of \code{nomenclature} objects (possibly empty).
#' @name nomenclature-aggregation
#' @examples
#' nomenclature_children(nomenclature("NIS", "district", "2019"))  # municipality
#' nomenclature_parents(nomenclature("NIS", "district", "2019"))   # province + region
#' @export
nomenclature_children <- function(x) {
  id   <- .nom_to_id(x)
  kids <- .node(id)$aggregates
  lapply(kids, .id_to_nom)
}

#' @rdname nomenclature-aggregation
#' @export
nomenclature_parents <- function(x) {
  id      <- .nom_to_id(x)
  ids     <- names(CLASSIFICATION_NODES)
  is_par  <- vapply(CLASSIFICATION_NODES,
                    function(n) id %in% n$aggregates, logical(1))
  lapply(ids[is_par], .id_to_nom)
}
