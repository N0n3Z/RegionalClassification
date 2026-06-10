# ==============================================================================
# 00b_registry.R  -  Single-source-of-truth classification node registry
# ==============================================================================
# CLASSIFICATION_NODES is the one place that records, per node id:
#   system, level, version, code_type, source_table, version_filter,
#   code_col, label_fr_col, label_nl_col, distinct, detectable, aggregates
#
# Everything that currently duplicates this knowledge (LABEL_META,
# .list_codes_for, .get_reference_codes, .parse_classification_id, the
# detect_classification refs list) will be rewired to read from here in
# subsequent phases.  Phase 0 is purely additive: no existing code is changed.
# ==============================================================================


# ------------------------------------------------------------------------------
# Registry
# ------------------------------------------------------------------------------

#' Classification node registry
#'
#' Named list with one entry per valid classification identifier (the 22 nodes
#' that also appear in `VALID_CLASSIFICATIONS`).  Each entry carries:
#'
#' \describe{
#'   \item{system}{One of `"NIS"`, `"NUTS"`, `"POSTAL"`, `"INTERNAL"`.}
#'   \item{level}{Granularity within the system (e.g. `"commune"`, `"nuts3"`).}
#'   \item{version}{Classification version string, or `NA_character_` when not
#'     versioned (POSTAL, INTERNAL, NUTS_COUNTRY).}
#'   \item{code_type}{Physical storage type: `"integer"` or `"character"`.}
#'   \item{source_table}{Which master table holds the codes: `"communes"` or
#'     `"postal"`.}
#'   \item{version_filter}{The `nis_version` value used to slice the source
#'     table.}
#'   \item{code_col}{Column name of the code in the source table.}
#'   \item{label_fr_col}{Column name of the French label, or `NA_character_`
#'     when unavailable.}
#'   \item{label_nl_col}{Column name of the Dutch label, or `NA_character_`
#'     when unavailable.}
#'   \item{distinct}{`TRUE` when the reference set requires
#'     `unique(na.omit(...))` (aggregated levels); `FALSE` for base-level
#'     entities where every row is already a distinct code.}
#'   \item{detectable}{`TRUE` for classifications included in the
#'     `detect_classification()` integer matching loop.}
#'   \item{aggregates}{Character vector of the node id(s) this node is the direct
#'     aggregation of (the finer level it groups). `character(0)` for base/leaf
#'     levels. The aggregation graph is a DAG, not a tree: an arrondissement is
#'     aggregated by BOTH a province and a region, and `NUTS_COUNTRY` aggregates both
#'     `NUTS_REGION_2021` and `NUTS_REGION_2027`. Province -> region is deliberately NOT an
#'     aggregation (province 20000 Brabant spans 3 regions); a region aggregates
#'     arrondissements directly. Used by `nomenclature_children()` /
#'     `nomenclature_parents()` and validated against the conversion graph.}
#' }
#'
#' @export
CLASSIFICATION_NODES <- list(

  # ---- NIS BEFORE_2019 -------------------------------------------------------
  NIS_MUNICIPALITY_BEFORE_2019 = list(
    system = "NIS",  level = "commune",         version = VER_BEFORE_2019,
    code_type = "integer",   source_table = "communes",
    version_filter = VER_BEFORE_2019, code_col = "cd_commune",
    label_fr_col = "tx_commune_fr",  label_nl_col = "tx_commune_nl",
    distinct = FALSE, detectable = TRUE,
    aggregates = character(0)
  ),
  NIS_DISTRICT_BEFORE_2019 = list(
    system = "NIS",  level = "arrondissement",  version = VER_BEFORE_2019,
    code_type = "integer",   source_table = "communes",
    version_filter = VER_BEFORE_2019, code_col = "cd_arr",
    label_fr_col = "tx_arr_fr",      label_nl_col = "tx_arr_nl",
    distinct = TRUE,  detectable = FALSE,
    aggregates = "NIS_MUNICIPALITY_BEFORE_2019"
  ),
  NIS_PROVINCE_BEFORE_2019 = list(
    system = "NIS",  level = "province",         version = VER_BEFORE_2019,
    code_type = "integer",   source_table = "communes",
    version_filter = VER_BEFORE_2019, code_col = "cd_province",
    label_fr_col = "tx_prov_fr",     label_nl_col = "tx_prov_nl",
    distinct = TRUE,  detectable = FALSE,
    aggregates = "NIS_DISTRICT_BEFORE_2019"
  ),
  NIS_REGION_BEFORE_2019 = list(
    system = "NIS",  level = "region",           version = VER_BEFORE_2019,
    code_type = "integer",   source_table = "communes",
    version_filter = VER_BEFORE_2019, code_col = "cd_region",
    label_fr_col = "tx_region_fr",   label_nl_col = "tx_region_nl",
    distinct = TRUE,  detectable = FALSE,
    aggregates = "NIS_DISTRICT_BEFORE_2019"
  ),

  # ---- NIS 2019 --------------------------------------------------------------
  NIS_MUNICIPALITY_2019 = list(
    system = "NIS",  level = "commune",         version = VER_2019,
    code_type = "integer",   source_table = "communes",
    version_filter = VER_2019, code_col = "cd_commune",
    label_fr_col = "tx_commune_fr",  label_nl_col = "tx_commune_nl",
    distinct = FALSE, detectable = TRUE,
    aggregates = character(0)
  ),
  NIS_DISTRICT_2019 = list(
    system = "NIS",  level = "arrondissement",  version = VER_2019,
    code_type = "integer",   source_table = "communes",
    version_filter = VER_2019, code_col = "cd_arr",
    label_fr_col = "tx_arr_fr",      label_nl_col = "tx_arr_nl",
    distinct = TRUE,  detectable = TRUE,
    aggregates = "NIS_MUNICIPALITY_2019"
  ),
  NIS_PROVINCE_2019 = list(
    system = "NIS",  level = "province",         version = VER_2019,
    code_type = "integer",   source_table = "communes",
    version_filter = VER_2019, code_col = "cd_province",
    label_fr_col = "tx_prov_fr",     label_nl_col = "tx_prov_nl",
    distinct = TRUE,  detectable = TRUE,
    aggregates = "NIS_DISTRICT_2019"
  ),
  NIS_REGION_2019 = list(
    system = "NIS",  level = "region",           version = VER_2019,
    code_type = "integer",   source_table = "communes",
    version_filter = VER_2019, code_col = "cd_region",
    label_fr_col = "tx_region_fr",   label_nl_col = "tx_region_nl",
    distinct = TRUE,  detectable = TRUE,
    aggregates = "NIS_DISTRICT_2019"
  ),

  # ---- NIS 2025 --------------------------------------------------------------
  NIS_MUNICIPALITY_2025 = list(
    system = "NIS",  level = "commune",         version = VER_2025,
    code_type = "integer",   source_table = "communes",
    version_filter = VER_2025, code_col = "cd_commune",
    label_fr_col = "tx_commune_fr",  label_nl_col = "tx_commune_nl",
    distinct = FALSE, detectable = TRUE,
    aggregates = character(0)
  ),
  NIS_DISTRICT_2025 = list(
    system = "NIS",  level = "arrondissement",  version = VER_2025,
    code_type = "integer",   source_table = "communes",
    version_filter = VER_2025, code_col = "cd_arr",
    label_fr_col = "tx_arr_fr",      label_nl_col = "tx_arr_nl",
    distinct = TRUE,  detectable = FALSE,
    aggregates = "NIS_MUNICIPALITY_2025"
  ),
  NIS_PROVINCE_2025 = list(
    system = "NIS",  level = "province",         version = VER_2025,
    code_type = "integer",   source_table = "communes",
    version_filter = VER_2025, code_col = "cd_province",
    label_fr_col = "tx_prov_fr",     label_nl_col = "tx_prov_nl",
    distinct = TRUE,  detectable = FALSE,
    aggregates = "NIS_DISTRICT_2025"
  ),
  NIS_REGION_2025 = list(
    system = "NIS",  level = "region",           version = VER_2025,
    code_type = "integer",   source_table = "communes",
    version_filter = VER_2025, code_col = "cd_region",
    label_fr_col = "tx_region_fr",   label_nl_col = "tx_region_nl",
    distinct = TRUE,  detectable = FALSE,
    aggregates = "NIS_DISTRICT_2025"
  ),

  # ---- NUTS 2021 -------------------------------------------------------------
  # version_filter = VER_2019: NIS 2019 communes carry the 2021 NUTS columns.
  #
  # NUTS_LAU_2021 (Local Administrative Units): in Belgium, LAU 2021 codes are
  # in bijection with NIS 2019 commune codes -- same geographic entities, same
  # perimeter, with cd_nuts_lau == as.character(cd_commune) for all mapped
  # communes; 2 communes are absent from the Eurostat LAU file (cd_nuts_lau NA).
  # Labels are borrowed from the commune (tx_commune_fr / tx_commune_nl).
  # Kept as a distinct node because LAU is the formal lowest level of the
  # Eurostat NUTS hierarchy (LAU < NUTS3 < NUTS2 < NUTS1 < NUTS_COUNTRY); removing it
  # would break the hierarchy and the NIS_MUNICIPALITY_2019 -> NUTS_DISTRICT_2021 path.
  NUTS_LAU_2021 = list(
    system = "NUTS", level = "lau",   version = VER_NUTS_2021,
    code_type = "character", source_table = "communes",
    version_filter = VER_2019, code_col = "cd_nuts_lau",
    label_fr_col = "tx_commune_fr",  label_nl_col = "tx_commune_nl",
    distinct = TRUE,  detectable = FALSE,
    aggregates = character(0)
  ),
  NUTS_DISTRICT_2021 = list(
    system = "NUTS", level = "nuts3", version = VER_NUTS_2021,
    code_type = "character", source_table = "communes",
    version_filter = VER_2019, code_col = "cd_nuts3",
    label_fr_col = "tx_nuts3_fr",    label_nl_col = "tx_nuts3_nl",
    distinct = TRUE,  detectable = FALSE,
    aggregates = "NUTS_LAU_2021"
  ),
  NUTS_PROVINCE_2021 = list(
    system = "NUTS", level = "nuts2", version = VER_NUTS_2021,
    code_type = "character", source_table = "communes",
    version_filter = VER_2019, code_col = "cd_nuts2",
    label_fr_col = NA_character_,    label_nl_col = NA_character_,
    distinct = TRUE,  detectable = FALSE,
    aggregates = "NUTS_DISTRICT_2021"
  ),
  NUTS_REGION_2021 = list(
    system = "NUTS", level = "nuts1", version = VER_NUTS_2021,
    code_type = "character", source_table = "communes",
    version_filter = VER_2019, code_col = "cd_nuts1",
    label_fr_col = NA_character_,    label_nl_col = NA_character_,
    distinct = TRUE,  detectable = FALSE,
    aggregates = "NUTS_PROVINCE_2021"
  ),
  NUTS_COUNTRY = list(
    system = "NUTS", level = "nuts0", version = NA_character_,
    code_type = "character", source_table = "communes",
    version_filter = VER_2019, code_col = "cd_nuts0",
    label_fr_col = NA_character_,    label_nl_col = NA_character_,
    distinct = TRUE,  detectable = FALSE,
    aggregates = c("NUTS_REGION_2021", "NUTS_REGION_2027")
  ),

  # ---- NUTS 2027 -------------------------------------------------------------
  # version_filter = VER_2025: NIS 2025 communes carry the 2027 NUTS columns.
  NUTS_DISTRICT_2027 = list(
    system = "NUTS", level = "nuts3", version = VER_NUTS_2027,
    code_type = "character", source_table = "communes",
    version_filter = VER_2025, code_col = "cd_nuts3_2027",
    label_fr_col = NA_character_,    label_nl_col = NA_character_,
    distinct = TRUE,  detectable = FALSE,
    aggregates = character(0)
  ),
  NUTS_PROVINCE_2027 = list(
    system = "NUTS", level = "nuts2", version = VER_NUTS_2027,
    code_type = "character", source_table = "communes",
    version_filter = VER_2025, code_col = "cd_nuts2_2027",
    label_fr_col = NA_character_,    label_nl_col = NA_character_,
    distinct = TRUE,  detectable = FALSE,
    aggregates = "NUTS_DISTRICT_2027"
  ),
  NUTS_REGION_2027 = list(
    system = "NUTS", level = "nuts1", version = VER_NUTS_2027,
    code_type = "character", source_table = "communes",
    version_filter = VER_2025, code_col = "cd_nuts1_2027",
    label_fr_col = NA_character_,    label_nl_col = NA_character_,
    distinct = TRUE,  detectable = FALSE,
    aggregates = "NUTS_PROVINCE_2027"
  ),

  # ---- POSTAL ----------------------------------------------------------------
  POSTAL = list(
    system = "POSTAL", level = "postal", version = NA_character_,
    code_type = "integer",   source_table = "postal",
    version_filter = VER_2019, code_col = "cd_postal",
    label_fr_col = "tx_postal_name_fr", label_nl_col = "tx_postal_name_nl",
    distinct = FALSE, detectable = TRUE,
    aggregates = character(0)
  ),

  # ---- INTERNAL --------------------------------------------------------------
  # cd_arr_internal is stored as character ("21", "22", ..., "65", "66") in RDS.
  NBB_DISTRICT_2021 = list(
    system = "INTERNAL", level = "arrondissement", version = VER_NUTS_2021,
    code_type = "character", source_table = "communes",
    version_filter = VER_2019, code_col = "cd_arr_internal",
    label_fr_col = "tx_arr_fr",      label_nl_col = "tx_arr_nl",
    distinct = TRUE,  detectable = TRUE,
    aggregates = character(0)
  )
)


# ------------------------------------------------------------------------------
# Internal accessors  (the ONLY readers of CLASSIFICATION_NODES at runtime)
# ------------------------------------------------------------------------------

#' Retrieve one registry entry, aborting on unknown id
#' @noRd
.node <- function(id) {
  n <- CLASSIFICATION_NODES[[id]]
  if (is.null(n))
    abort(
      sprintf(
        paste0(
          "Classification '%s' is not recognised.\n",
          "Valid identifiers (case-insensitive):\n  %s\n",
          "See ?classification_reference."
        ),
        id,
        paste(sort(names(CLASSIFICATION_NODES)), collapse = ", ")
      ),
      class        = "rcl_invalid_classification",
      classification = id,
      valid        = names(CLASSIFICATION_NODES)
    )
  n
}

#' Code storage type for a classification node
#' @noRd
.node_code_type <- function(id) .node(id)[["code_type"]]

#' Coerce a code vector to the canonical storage type for `id`
#' @noRd
.node_coerce <- function(codes, id) {
  if (.node_code_type(id) == "integer") as.integer(codes)
  else                                   as.character(codes)
}

#' Reference code table for a classification
#'
#' Returns a `data.table(code, name_fr, name_nl)` for the requested node.
#' Returns `NULL` when no data is available (e.g. BEFORE_2019 slice not loaded).
#'
#' Phase 3: prefers `master_data$entities` when available (single normalised
#' table built at snapshot time).  Falls back to reading `master_data$communes`
#' / `master_data$postal` directly when entities is NULL -- this covers
#' `rebuild_master_data()` (entities not yet built) and legacy master_data
#' objects that pre-date the entities table.
#'
#' Replaces `.list_codes_for()` (R/09_query.R) and
#' `.get_reference_codes()` (R/07_diagnose.R).
#' @noRd
.node_reference_codes <- function(id, master_data) {
  # -- Phase 3 fast path: entities table -----------------------------------------
  if (!is.null(master_data$entities)) {
    ent <- master_data$entities[classification_id == id]
    if (nrow(ent) == 0L) return(NULL)
    return(ent[, .(code, name_fr, name_nl)])
  }

  # -- Fallback: read from communes / postal directly ----------------------------
  # Used when entities has not yet been built (rebuild_master_data() context) or
  # when loading a master_data object that pre-dates the entities table.
  n     <- .node(id)
  tbl   <- if (n$source_table == "communes") master_data$communes
           else                               master_data$postal
  slice <- tbl[get("nis_version") == n$version_filter]
  if (nrow(slice) == 0L) return(NULL)

  cc     <- n$code_col
  fr_col <- n$label_fr_col
  nl_col <- n$label_nl_col
  has_fr <- !is.na(fr_col)
  has_nl <- !is.na(nl_col)

  keep <- c(cc, if (has_fr) fr_col, if (has_nl) nl_col)

  if (n$distinct) {
    sub <- unique(slice[!is.na(get(cc)), .SD, .SDcols = keep])
  } else {
    sub <- slice[, .SD, .SDcols = keep]
  }

  result <- data.table(code = as.character(sub[[cc]]))
  result[, name_fr := if (has_fr) sub[[fr_col]] else NA_character_]
  result[, name_nl := if (has_nl) sub[[nl_col]] else NA_character_]
  result
}

#' Label metadata compatible with the legacy .LABEL_META[[id]] structure
#'
#' Returns `list(ver, code, fr, nl, src)` -- a drop-in replacement for
#' accessing `.LABEL_META[[id]]` in R/09_query.R.
#' @noRd
.node_label_meta <- function(id) {
  n <- .node(id)
  list(
    ver  = n$version_filter,
    code = n$code_col,
    fr   = n$label_fr_col,
    nl   = n$label_nl_col,
    src  = n$source_table
  )
}

#' Parse a classification id into type + version
#'
#' Returns `list(type, version)` matching the format produced by the legacy
#' `.parse_classification_id()` in R/07_diagnose.R.  Fixes the gaps in that
#' function: `NIS_*_BEFORE_2019`, `NIS_ARRONDISSEMENT/PROVINCE/REGION_2025`,
#' and `NUTS_COUNTRY` now return correct values instead of the fallback default.
#' @noRd
.node_parse <- function(id) {
  n    <- .node(id)
  type <- sub("_(2019|2025|2021|2027|BEFORE_2019)$", "", id)
  list(type = type, version = n$version)
}
