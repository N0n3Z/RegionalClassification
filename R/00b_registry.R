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
#' Named list with one entry per valid classification identifier (the 23 nodes
#' that also appear in `VALID_CLASSIFICATIONS`).  Each entry carries:
#'
#' \describe{
#'   \item{system}{One of `"NIS"`, `"NUTS"`, `"POSTAL"`, `"NBB"`.}
#'   \item{level}{Granularity within the system (e.g. `"municipality"`, `"district"`, `"province"`, `"country"`).}
#'   \item{version}{Classification version string, or `NA_character_` when not
#'     versioned (POSTAL, NUTS_COUNTRY).}
#'   \item{code_type}{Physical storage type: `"integer"` or `"character"`.}
#'   \item{source_table}{Which master table holds the codes: `"municipalities"`
#'     or `"postal"`.}
#'   \item{version_filter}{The `version` value used to slice the source
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
#'     levels. NIS levels form a strict hierarchy
#'     `region -> province -> arrondissement -> municipality` (each NIS province
#'     nests in exactly one region since the 1995 Brabant split, with Brussels
#'     modelled as a pseudo-province). The graph is still a DAG, not a tree:
#'     `NUTS_COUNTRY` aggregates both `NUTS_REGION_2021` and `NUTS_REGION_2027`, and
#'     `NIS_COUNTRY` aggregates all three NIS region versions. Used by
#'     `nomenclature_children()` / `nomenclature_parents()`.}
#' }
#'
#' @export
CLASSIFICATION_NODES <- list(

  # ---- NIS BEFORE_2019 -------------------------------------------------------
  NIS_MUNICIPALITY_BEFORE_2019 = list(
    system = "NIS",  level = "municipality",         version = VER_BEFORE_2019,
    code_type = "character", source_table = "municipalities",
    version_filter = VER_BEFORE_2019, code_col = "code_nis_municipality",
    label_fr_col = "label_nis_municipality_fr",  label_nl_col = "label_nis_municipality_nl",
    distinct = FALSE, detectable = TRUE,
    aggregates = character(0)
  ),
  NIS_DISTRICT_BEFORE_2019 = list(
    system = "NIS",  level = "district",  version = VER_BEFORE_2019,
    code_type = "character", source_table = "municipalities",
    version_filter = VER_BEFORE_2019, code_col = "code_nis_district",
    label_fr_col = "label_nis_district_fr",      label_nl_col = "label_nis_district_nl",
    distinct = TRUE,  detectable = FALSE,
    aggregates = "NIS_MUNICIPALITY_BEFORE_2019"
  ),
  NIS_PROVINCE_BEFORE_2019 = list(
    system = "NIS",  level = "province",         version = VER_BEFORE_2019,
    code_type = "character", source_table = "municipalities",
    version_filter = VER_BEFORE_2019, code_col = "code_nis_province",
    label_fr_col = "label_nis_province_fr",     label_nl_col = "label_nis_province_nl",
    distinct = TRUE,  detectable = FALSE,
    aggregates = "NIS_DISTRICT_BEFORE_2019"
  ),
  NIS_REGION_BEFORE_2019 = list(
    system = "NIS",  level = "region",           version = VER_BEFORE_2019,
    code_type = "character", source_table = "municipalities",
    version_filter = VER_BEFORE_2019, code_col = "code_nis_region",
    label_fr_col = "label_nis_region_fr",   label_nl_col = "label_nis_region_nl",
    distinct = TRUE,  detectable = FALSE,
    aggregates = "NIS_PROVINCE_BEFORE_2019"
  ),

  # ---- NIS 2019 --------------------------------------------------------------
  NIS_MUNICIPALITY_2019 = list(
    system = "NIS",  level = "municipality",         version = VER_2019,
    code_type = "character", source_table = "municipalities",
    version_filter = VER_2019, code_col = "code_nis_municipality",
    label_fr_col = "label_nis_municipality_fr",  label_nl_col = "label_nis_municipality_nl",
    distinct = FALSE, detectable = TRUE,
    aggregates = character(0)
  ),
  NIS_DISTRICT_2019 = list(
    system = "NIS",  level = "district",  version = VER_2019,
    code_type = "character", source_table = "municipalities",
    version_filter = VER_2019, code_col = "code_nis_district",
    label_fr_col = "label_nis_district_fr",      label_nl_col = "label_nis_district_nl",
    distinct = TRUE,  detectable = TRUE,
    aggregates = "NIS_MUNICIPALITY_2019"
  ),
  NIS_PROVINCE_2019 = list(
    system = "NIS",  level = "province",         version = VER_2019,
    code_type = "character", source_table = "municipalities",
    version_filter = VER_2019, code_col = "code_nis_province",
    label_fr_col = "label_nis_province_fr",     label_nl_col = "label_nis_province_nl",
    distinct = TRUE,  detectable = TRUE,
    aggregates = "NIS_DISTRICT_2019"
  ),
  NIS_REGION_2019 = list(
    system = "NIS",  level = "region",           version = VER_2019,
    code_type = "character", source_table = "municipalities",
    version_filter = VER_2019, code_col = "code_nis_region",
    label_fr_col = "label_nis_region_fr",   label_nl_col = "label_nis_region_nl",
    distinct = TRUE,  detectable = TRUE,
    aggregates = "NIS_PROVINCE_2019"
  ),

  # ---- NIS 2025 --------------------------------------------------------------
  NIS_MUNICIPALITY_2025 = list(
    system = "NIS",  level = "municipality",         version = VER_2025,
    code_type = "character", source_table = "municipalities",
    version_filter = VER_2025, code_col = "code_nis_municipality",
    label_fr_col = "label_nis_municipality_fr",  label_nl_col = "label_nis_municipality_nl",
    distinct = FALSE, detectable = TRUE,
    aggregates = character(0)
  ),
  NIS_DISTRICT_2025 = list(
    system = "NIS",  level = "district",  version = VER_2025,
    code_type = "character", source_table = "municipalities",
    version_filter = VER_2025, code_col = "code_nis_district",
    label_fr_col = "label_nis_district_fr",      label_nl_col = "label_nis_district_nl",
    distinct = TRUE,  detectable = FALSE,
    aggregates = "NIS_MUNICIPALITY_2025"
  ),
  NIS_PROVINCE_2025 = list(
    system = "NIS",  level = "province",         version = VER_2025,
    code_type = "character", source_table = "municipalities",
    version_filter = VER_2025, code_col = "code_nis_province",
    label_fr_col = "label_nis_province_fr",     label_nl_col = "label_nis_province_nl",
    distinct = TRUE,  detectable = FALSE,
    aggregates = "NIS_DISTRICT_2025"
  ),
  NIS_REGION_2025 = list(
    system = "NIS",  level = "region",           version = VER_2025,
    code_type = "character", source_table = "municipalities",
    version_filter = VER_2025, code_col = "code_nis_region",
    label_fr_col = "label_nis_region_fr",   label_nl_col = "label_nis_region_nl",
    distinct = TRUE,  detectable = FALSE,
    aggregates = "NIS_PROVINCE_2025"
  ),

  # ---- NIS country ------------------------------------------------------------
  # NIS code for Belgium as a whole: 01000 in Statbel source (REFNIS type "REALM").
  # Stored as the character string "1000" (the leading zero of the 5-digit display
  # is dropped, matching the historical integer representation 1000L; kept as "1000"
  # rather than "01000" so it aligns with every other stored code).
  # Unversioned: Belgium's identity code does not change across NIS versions.
  # Synthetic column code_nis_country = "1000" added to the municipalities table.
  NIS_COUNTRY = list(
    system = "NIS",  level = "country",          version = NA_character_,
    code_type = "character", source_table = "municipalities",
    version_filter = VER_2019, code_col = "code_nis_country",
    label_fr_col = NA_character_,    label_nl_col = NA_character_,
    distinct = TRUE,  detectable = FALSE,
    aggregates = c("NIS_REGION_BEFORE_2019", "NIS_REGION_2019", "NIS_REGION_2025")
  ),

  # ---- NUTS 2021 -------------------------------------------------------------
  # version_filter = VER_2019: NIS 2019 communes carry the 2021 NUTS columns.
  #
  # NUTS_MUNICIPALITY_2021 (Eurostat LAU -- Local Administrative Units): in Belgium,
  # LAU 2021 codes are in bijection with NIS 2019 commune codes -- same geographic
  # entities, same perimeter, with code_nuts_municipality_2021 == code_nis_municipality
  # for all mapped communes; 2 communes are absent from the Eurostat LAU file (NA).
  # Labels are borrowed from the NIS municipality (label_nis_municipality_fr / _nl).
  # Kept as a distinct node because LAU is the formal lowest level of the
  # Eurostat NUTS hierarchy (LAU < NUTS3 < NUTS2 < NUTS1 < NUTS_COUNTRY); removing it
  # would break the hierarchy and the NIS_MUNICIPALITY_2019 -> NUTS_DISTRICT_2021 path.
  NUTS_MUNICIPALITY_2021 = list(
    system = "NUTS", level = "municipality", version = VER_NUTS_2021,
    code_type = "character", source_table = "municipalities",
    version_filter = VER_2019, code_col = "code_nuts_municipality_2021",
    label_fr_col = "label_nis_municipality_fr",  label_nl_col = "label_nis_municipality_nl",
    distinct = TRUE,  detectable = FALSE,
    aggregates = character(0)
  ),
  NUTS_DISTRICT_2021 = list(
    system = "NUTS", level = "district", version = VER_NUTS_2021,
    code_type = "character", source_table = "municipalities",
    version_filter = VER_2019, code_col = "code_nuts_district_2021",
    label_fr_col = "label_nuts_district_2021_fr",    label_nl_col = "label_nuts_district_2021_nl",
    distinct = TRUE,  detectable = FALSE,
    aggregates = "NUTS_MUNICIPALITY_2021"
  ),
  NUTS_PROVINCE_2021 = list(
    system = "NUTS", level = "province", version = VER_NUTS_2021,
    code_type = "character", source_table = "municipalities",
    version_filter = VER_2019, code_col = "code_nuts_province_2021",
    label_fr_col = NA_character_,    label_nl_col = NA_character_,
    distinct = TRUE,  detectable = FALSE,
    aggregates = "NUTS_DISTRICT_2021"
  ),
  NUTS_REGION_2021 = list(
    system = "NUTS", level = "region", version = VER_NUTS_2021,
    code_type = "character", source_table = "municipalities",
    version_filter = VER_2019, code_col = "code_nuts_region_2021",
    label_fr_col = NA_character_,    label_nl_col = NA_character_,
    distinct = TRUE,  detectable = FALSE,
    aggregates = "NUTS_PROVINCE_2021"
  ),
  NUTS_COUNTRY = list(
    system = "NUTS", level = "country", version = NA_character_,
    code_type = "character", source_table = "municipalities",
    version_filter = VER_2019, code_col = "code_nuts_country",
    label_fr_col = NA_character_,    label_nl_col = NA_character_,
    distinct = TRUE,  detectable = FALSE,
    aggregates = c("NUTS_REGION_2021", "NUTS_REGION_2027")
  ),

  # ---- NUTS 2027 -------------------------------------------------------------
  # version_filter = VER_2025: NIS 2025 communes carry the 2027 NUTS columns.
  NUTS_DISTRICT_2027 = list(
    system = "NUTS", level = "district", version = VER_NUTS_2027,
    code_type = "character", source_table = "municipalities",
    version_filter = VER_2025, code_col = "code_nuts_district_2027",
    label_fr_col = NA_character_,    label_nl_col = NA_character_,
    distinct = TRUE,  detectable = FALSE,
    aggregates = character(0)
  ),
  NUTS_PROVINCE_2027 = list(
    system = "NUTS", level = "province", version = VER_NUTS_2027,
    code_type = "character", source_table = "municipalities",
    version_filter = VER_2025, code_col = "code_nuts_province_2027",
    label_fr_col = NA_character_,    label_nl_col = NA_character_,
    distinct = TRUE,  detectable = FALSE,
    aggregates = "NUTS_DISTRICT_2027"
  ),
  NUTS_REGION_2027 = list(
    system = "NUTS", level = "region", version = VER_NUTS_2027,
    code_type = "character", source_table = "municipalities",
    version_filter = VER_2025, code_col = "code_nuts_region_2027",
    label_fr_col = NA_character_,    label_nl_col = NA_character_,
    distinct = TRUE,  detectable = FALSE,
    aggregates = "NUTS_PROVINCE_2027"
  ),

  # ---- POSTAL ----------------------------------------------------------------
  POSTAL = list(
    system = "POSTAL", level = "postal", version = NA_character_,
    code_type = "character", source_table = "postal",
    version_filter = VER_2019, code_col = "code_postal",
    label_fr_col = "label_postal_fr", label_nl_col = "label_postal_nl",
    distinct = FALSE, detectable = TRUE,
    aggregates = character(0)
  ),

  # ---- NBB internal -----------------------------------------------------------
  # code_nbb_district_2021 is stored as character ("21", "22", ..., "65", "66").
  NBB_DISTRICT_2021 = list(
    system = "NBB", level = "district", version = VER_NUTS_2021,
    code_type = "character", source_table = "municipalities",
    version_filter = VER_2019, code_col = "code_nbb_district_2021",
    label_fr_col = "label_nis_district_fr",      label_nl_col = "label_nis_district_nl",
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

#' Schema v2 code column name derived from a node id
#'
#' Implements the naming rule of SCHEMA_V1_TO_V2 (R/00_config.R): `code_` +
#' the lower-cased node id, without the NIS version (carried by the row's
#' `version` column). NUTS / NBB ids keep their version. The registry still
#' spells `code_col` out explicitly; tests/testthat/test-schema.R checks that the
#' two agree.
#' @noRd
.node_code_col <- function(id) {
  n    <- .node(id)
  base <- tolower(id)
  if (n$system == "NIS" && !is.na(n$version))
    base <- sub(paste0("_", tolower(n$version), "$"), "", base)
  paste0("code_", base)
}

#' Code storage type for a classification node
#' @noRd
.node_code_type <- function(id) .node(id)[["code_type"]]

#' Canonicalise a code vector to its stored string form.
#'
#' Every code is stored as character (v1.2.0). Purely numeric codes are round-
#' tripped through integer so leading-zero input matches the stored form -- most
#' importantly the Statbel country code, written "01000" but stored "1000". Codes
#' containing letters (NUTS "BE100") are left untouched. NA is preserved.
#' @noRd
.canon_codes <- function(codes) {
  ch  <- as.character(codes)
  num <- !is.na(ch) & grepl("^[0-9]+$", ch)
  ch[num] <- as.character(as.integer(ch[num]))
  ch
}

#' Coerce a code vector to the canonical storage type for `id`
#'
#' All nodes are character (v1.2.0); coercion also canonicalises leading zeros
#' via .canon_codes() so integer input and zero-padded forms map to the stored
#' code. Integer input therefore stays permissive (21004L -> "21004").
#' @noRd
.node_coerce <- function(codes, id) {
  .node_code_type(id)          # validates `id` and preserves the code_type contract
  .canon_codes(codes)
}

#' Reference code table for a classification
#'
#' Returns a `data.table(code, label_fr, label_nl)` for the requested node.
#' Returns `NULL` when no data is available (e.g. BEFORE_2019 slice not loaded).
#'
#' Prefers `master_data$entities` when available (single normalised table built
#' at snapshot time).  Falls back to reading `master_data$municipalities` /
#' `master_data$postal` directly when entities is NULL -- this covers
#' `build_master_table()` (entities not yet built).
#' @noRd
.node_reference_codes <- function(id, master_data) {
  # -- Fast path: entities table -------------------------------------------------
  if (!is.null(master_data$entities)) {
    ent <- master_data$entities[classification == id]
    if (nrow(ent) == 0L) return(NULL)
    return(ent[, .(code, label_fr, label_nl)])
  }

  # -- Fallback: read from municipalities / postal directly ----------------------
  n     <- .node(id)
  tbl   <- master_data[[n$source_table]]
  slice <- tbl[get("version") == n$version_filter]
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
  result[, label_fr := if (has_fr) sub[[fr_col]] else NA_character_]
  result[, label_nl := if (has_nl) sub[[nl_col]] else NA_character_]
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
#' function: `NIS_*_BEFORE_2019`, `NIS_DISTRICT/PROVINCE/REGION_2025`,
#' and `NUTS_COUNTRY` now return correct values instead of the fallback default.
#' @noRd
.node_parse <- function(id) {
  n    <- .node(id)
  type <- sub("_(2019|2025|2021|2027|BEFORE_2019)$", "", id)
  list(type = type, version = n$version)
}
