# ==============================================================================
# 11_wide_view.R -- Wide tables rebuilt from the long model (v3.0.0)
# ==============================================================================
# The canonical master data is the long model: `entities` (one row per code of
# each classification) and `crosswalks` (one row per code link of each
# single-hop conversion). The wide tables `municipalities`, `postal` and
# `nis_changes` are build-time intermediates that are no longer persisted;
# wide_view() reconstructs them, cell for cell, from the long model.
#
# The reconstruction mirrors the build rules of 02_build_master_table.R:
#   - NIS 2019 rows read every column through a direct crosswalk;
#   - NIS BEFORE_2019 rows inherit the NUTS 2021 / NBB columns of their NIS
#     2019 successor;
#   - NIS 2025 rows aggregate the NUTS 2021 / NBB columns of their constituent
#     2019 communes (value kept when all constituents agree, LAU only for a
#     single constituent), as add_nuts2021_columns_2025() does;
#   - NUTS 2027 columns are carried by NIS 2025 rows only, the NUTS district
#     labels by NIS 2019 / BEFORE_2019 rows only.
# tests/testthat/test-wide-view.R guards the equivalence against the golden
# wide tables of the 2.0.0 snapshot.
# ==============================================================================

#' Code links of one crosswalk hop
#'
#' Returns `data.table(code_from, code_to)` for the `(from, to)` hop of
#' `master_data$crosswalks`, without the rows whose `code_to` is `NA`.
#' @noRd
.links <- function(from, to, master_data) {
  master_data$crosswalks[classification_from == from & classification_to == to &
                         !is.na(code_to), .(code_from, code_to)]
}

#' Codes and labels of one classification
#'
#' Returns `data.table(code, label_fr, label_nl)` from `master_data$entities`.
#' @noRd
.entities_of <- function(id, master_data) {
  master_data$entities[classification == id, .(code, label_fr, label_nl)]
}

#' Look up the single target code of each source code
#'
#' Left-joins `codes` on the `(from, to)` hop. Used on N:1 hops only; aborts
#' if a source code has several targets so a graph change cannot silently
#' duplicate rows of a wide view.
#' @noRd
.lookup_code <- function(codes, from, to, master_data) {
  l <- .links(from, to, master_data)
  if (anyDuplicated(l$code_from))
    abort(sprintf("wide_view(): %s -> %s is not N:1.", from, to), class = "rcl_internal")
  l$code_to[match(codes, l$code_from)]
}

#' Look up the label of each code of one classification
#' @noRd
.lookup_label <- function(codes, id, master_data, lang) {
  ent <- .entities_of(id, master_data)
  ent[[paste0("label_", lang)]][match(codes, ent$code)]
}

#' NIS hierarchy columns of the NIS municipalities of one version
#' @noRd
.wide_nis_part <- function(version, master_data) {
  mun <- sprintf("NIS_MUNICIPALITY_%s", version)
  ent <- .entities_of(mun, master_data)
  dt  <- data.table(
    version                   = version,
    code_nis_municipality     = ent$code,
    label_nis_municipality_fr = ent$label_fr,
    label_nis_municipality_nl = ent$label_nl
  )
  for (level in c("district", "province", "region")) {
    id    <- sprintf("NIS_%s_%s", toupper(level), version)
    codes <- .lookup_code(dt$code_nis_municipality, mun, id, master_data)
    set(dt, j = paste0("code_nis_", level), value = codes)
    set(dt, j = sprintf("label_nis_%s_fr", level), value = .lookup_label(codes, id, master_data, "fr"))
    set(dt, j = sprintf("label_nis_%s_nl", level), value = .lookup_label(codes, id, master_data, "nl"))
  }
  set(dt, j = "code_nis_country",
      value = .lookup_code(dt$code_nis_region, sprintf("NIS_REGION_%s", version),
                           CLS_NIS_COUNTRY, master_data))
  dt
}

# NUTS 2021 / NBB columns of the NIS 2019 municipalities, keyed by the
# conversion-graph node each one is read from.
.WIDE_NUTS2021_NODES <- c(
  code_nuts_municipality_2021 = "NUTS_MUNICIPALITY_2021",
  code_nuts_district_2021     = "NUTS_DISTRICT_2021",
  code_nuts_province_2021     = "NUTS_PROVINCE_2021",
  code_nuts_region_2021       = "NUTS_REGION_2021",
  code_nuts_country           = "NUTS_COUNTRY",
  code_nbb_district_2021      = "NBB_DISTRICT_2021"
)

#' NUTS 2021 / NBB columns of the NIS 2019 municipalities
#' @noRd
.wide_nuts2021_2019 <- function(codes_2019, master_data) {
  dt <- data.table(code_nis_municipality = codes_2019)
  for (col in names(.WIDE_NUTS2021_NODES))
    set(dt, j = col, value = .lookup_code(codes_2019, CLS_NIS_MUNICIPALITY_2019,
                                          .WIDE_NUTS2021_NODES[[col]], master_data))
  dt
}

#' One version of the municipalities wide table
#' @noRd
.wide_municipalities <- function(version, master_data) {
  dt <- .wide_nis_part(version, master_data)
  if (nrow(dt) == 0L) return(dt)
  codes <- dt$code_nis_municipality

  if (version == VER_2019) {
    nuts <- .wide_nuts2021_2019(codes, master_data)
  } else if (version == VER_BEFORE_2019) {
    succ <- .lookup_code(codes, CLS_NIS_MUNICIPALITY_BEFORE_2019, CLS_NIS_MUNICIPALITY_2019, master_data)
    nuts <- .wide_nuts2021_2019(succ, master_data)
    nuts[, code_nis_municipality := codes]
  } else {
    # 2025: aggregate the constituent 2019 communes (add_nuts2021_columns_2025).
    cons <- .links(CLS_NIS_MUNICIPALITY_2025, CLS_NIS_MUNICIPALITY_2019, master_data)
    vals <- .wide_nuts2021_2019(cons$code_to, master_data)
    vals[, code_nis_municipality := cons$code_from]
    .uniq1 <- function(x) {
      u <- unique(x[!is.na(x)])
      if (length(u) == 1L) u else NA_character_
    }
    scalar <- setdiff(names(.WIDE_NUTS2021_NODES), "code_nuts_municipality_2021")
    nuts <- vals[, c(lapply(.SD, .uniq1),
                     list(code_nuts_municipality_2021 =
                            if (.N == 1L) code_nuts_municipality_2021 else NA_character_)),
                 by = code_nis_municipality, .SDcols = scalar]
    nuts <- nuts[match(codes, code_nis_municipality)]
    nuts[, code_nis_municipality := codes]
  }
  dt <- cbind(dt, nuts[, !"code_nis_municipality"])

  if (version == VER_2025) {
    for (lv in c("district", "province", "region"))
      set(dt, j = sprintf("code_nuts_%s_2027", lv),
          value = .lookup_code(codes, CLS_NIS_MUNICIPALITY_2025,
                               sprintf("NUTS_%s_2027", toupper(lv)), master_data))
    dt[, code_nuts_country_2027 := .lookup_code(code_nuts_region_2027, CLS_NUTS_REGION_2027,
                                                CLS_NUTS_COUNTRY, master_data)]
  } else {
    dt[, `:=`(
      label_nuts_district_2021_fr = .lookup_label(code_nuts_district_2021, CLS_NUTS_DISTRICT_2021, master_data, "fr"),
      label_nuts_district_2021_nl = .lookup_label(code_nuts_district_2021, CLS_NUTS_DISTRICT_2021, master_data, "nl")
    )]
  }
  dt
}

#' One version of the postal wide table
#' @noRd
.wide_postal <- function(version, master_data) {
  l <- .links(CLS_POSTAL, sprintf("NIS_MUNICIPALITY_%s", version), master_data)
  data.table(
    code_postal           = l$code_from,
    code_nis_municipality = l$code_to,
    label_postal_fr       = .lookup_label(l$code_from, CLS_POSTAL, master_data, "fr"),
    label_postal_nl       = .lookup_label(l$code_from, CLS_POSTAL, master_data, "nl"),
    version               = rep(version, nrow(l))
  )
}

#' One version of the nis_changes wide table (changes from `version`)
#' @noRd
.wide_nis_changes <- function(version, master_data) {
  to <- NIS_CHANGE_VERSION_TO[[version]]
  master_data$crosswalks[
    classification_from == sprintf("NIS_MUNICIPALITY_%s", version) &
    classification_to   == sprintf("NIS_MUNICIPALITY_%s", to) &
    !is.na(nature) & nature != "UNCHANGED",
    .(code_from, code_to, nature, version_from = version, version_to = to)]
}

#' Wide view of the master data
#'
#' Rebuilds one of the wide tables of the pre-3.0.0 master data from the long
#' model (`entities` + `crosswalks`) returned by [load_master_data()]. The
#' result is identical, cell for cell, to the table that versions 2.x
#' persisted; rows are sorted by version, then code.
#'
#' \describe{
#'   \item{`"municipalities"`}{One row per NIS municipality and version, with
#'     its NIS hierarchy (`code_nis_district`, `code_nis_province`,
#'     `code_nis_region`, `code_nis_country` and their `label_*_fr/_nl`), its
#'     NUTS 2021 codes and the NBB district (`code_nbb_district_2021`). NIS 2025
#'     rows also carry the NUTS 2027 codes; NIS 2019 and BEFORE_2019 rows the
#'     NUTS district labels.}
#'   \item{`"postal"`}{One row per postal code and NIS version:
#'     `code_postal`, `code_nis_municipality`, `label_postal_fr/_nl`, `version`.}
#'   \item{`"nis_changes"`}{One row per municipality code that changes between
#'     two NIS versions: `code_from`, `code_to`, `nature`, `version_from`,
#'     `version_to`.}
#' }
#'
#' @param master_data Output from [load_master_data()].
#' @param table Which wide table to rebuild: `"municipalities"` (default),
#'   `"postal"` or `"nis_changes"`.
#' @param version NIS version(s) to keep (`"2019"`, `"2025"`,
#'   `"BEFORE_2019"`); `NULL` (default) keeps every available version. For
#'   `"nis_changes"` it filters `version_from` (`"2019"` or `"BEFORE_2019"`).
#' @return A `data.table`; every code column is character.
#' @examples
#' \donttest{
#'   master_data <- load_master_data()
#'   wide_view(master_data, version = "2019")
#'   wide_view(master_data, "postal", version = "2025")
#'   wide_view(master_data, "nis_changes")
#' }
#' @export
wide_view <- function(master_data,
                      table   = c("municipalities", "postal", "nis_changes"),
                      version = NULL) {
  table <- match.arg(table)
  .validate_master_data(master_data)
  available <- switch(table,
    municipalities = c(VER_2019, VER_BEFORE_2019, VER_2025),
    postal         = c(VER_2019, VER_2025),
    nis_changes    = c(VER_2019, VER_BEFORE_2019)
  )
  if (is.null(version)) version <- available
  bad <- setdiff(version, available)
  if (length(bad) > 0L)
    abort(sprintf("version must be among %s for table '%s'; got: %s",
                  paste0('"', available, '"', collapse = ", "), table,
                  paste(bad, collapse = ", ")),
          class = "rcl_invalid_input")

  build <- switch(table,
    municipalities = .wide_municipalities,
    postal         = .wide_postal,
    nis_changes    = .wide_nis_changes
  )
  out <- rbindlist(lapply(version, build, master_data = master_data),
                   use.names = TRUE, fill = TRUE)
  if (table == "municipalities")
    setcolorder(out, intersect(c("version", setdiff(MASTER_MUNICIPALITY_KNOWN_COLS, "version")),
                               names(out)))
  key <- switch(table,
    municipalities = c("version", "code_nis_municipality"),
    postal         = c("version", "code_postal", "code_nis_municipality"),
    nis_changes    = c("version_from", "code_from", "code_to")
  )
  setorderv(out, key)
  out[]
}
