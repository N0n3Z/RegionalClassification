# ==============================================================================
# build_standard_weights.R
# ------------------------------------------------------------------------------
# Builds inst/extdata/standard_weight_values.rds : the SHIPPED standard
# commune-level weighting variables consumed by
#   split_weights_template(from, to, master_data,
#                          variable = "population",
#                          weight_vintage = "NIS_MUNICIPALITY_2019",
#                          weight_year = <year or NULL for most recent>)
#
# Approach (C): the package ships POPULATION as the standard weighting variable;
# any other variable (employment, area, ...) is supplied by the user at call time
# via `commune_values =` (no shipped data needed for those).
#
# Output schema: data.table(variable chr, vintage chr, year int, code chr, value num)
#   variable = "population"
#   vintage  = commune classification the codes belong to (weighting refinement)
#   year     = reference year of the population figures (multiple years shipped)
#   code     = commune code in `vintage`  (character)
#   value    = inhabitants
#
# split_weights_template() maps each `vintage` commune to its `from` and `to`
# code and aggregates the values into per-edge weights. Weights are ratios, so
# the absolute level per year matters little; the year dimension lets a caller
# pick period-consistent weights (e.g. for historical retropolation).
# ==============================================================================

library(data.table)
library(readxl)

# --- 1. Read the raw population tables ----------------------------------------
# Each source is a long table (YEAR, CD_REFNIS, TOTAL, CLASSIFICATION) for one
# commune vintage. Add more blocks (e.g. a NIS_MUNICIPALITY_BEFORE_2019 file for
# historical retropolation) by appending to `sources` below.
sources <- list(
  list(
    file    = "data/raw/POPULATION_2011_2024_NIS2019.xlsx",
    vintage = "NIS_MUNICIPALITY_2019"
  )
  # , list(file = "data/raw/POPULATION_..._NIS_BEFORE2019.xlsx",
  #        vintage = "NIS_MUNICIPALITY_BEFORE_2019")
)

read_pop <- function(src) {
  dt <- as.data.table(readxl::read_excel(src$file))
  # Tolerate minor header variations; expect YEAR / CD_REFNIS / TOTAL.
  setnames(dt,
           old = c(grep("^YEAR$",  names(dt), ignore.case = TRUE, value = TRUE)[1],
                   grep("REFNIS|INS", names(dt), ignore.case = TRUE, value = TRUE)[1],
                   grep("TOTAL|POP",  names(dt), ignore.case = TRUE, value = TRUE)[1]),
           new = c("year", "code", "value"))
  data.table(
    variable = "population",
    vintage  = src$vintage,
    year     = as.integer(dt$year),
    code     = as.character(dt$code),
    value    = as.numeric(dt$value)
  )
}

standard_weight_values <- rbindlist(lapply(sources, read_pop), use.names = TRUE)

# --- 2. Sanity checks ---------------------------------------------------------
stopifnot(
  all(c("variable", "vintage", "year", "code", "value") %in% names(standard_weight_values)),
  standard_weight_values[, !anyNA(year) && !anyNA(value) && all(nzchar(code))]
)
# Every commune of each shipped vintage should have a value for every year, else
# some ambiguous code_from could get an all-zero mass and fall back to equal
# weights. Verify against the master table.
devtools::load_all(".", quiet = TRUE)
md <- load_master_data()
vintage_master <- c(
  NIS_MUNICIPALITY_2019        = VER_2019,
  NIS_MUNICIPALITY_BEFORE_2019 = VER_BEFORE_2019
)
for (v in unique(standard_weight_values$vintage)) {
  comm <- as.character(unique(md$communes[nis_version == vintage_master[[v]], cd_commune]))
  for (y in sort(unique(standard_weight_values[vintage == v, year]))) {
    have <- standard_weight_values[vintage == v & year == y, code]
    miss <- setdiff(comm, have)
    if (length(miss))
      warning(sprintf("%s %d: %d commune(s) without population: %s",
                      v, y, length(miss), paste(head(miss, 5), collapse = ", ")))
  }
}

# --- 3. Persist ---------------------------------------------------------------
saveRDS(standard_weight_values, "inst/extdata/standard_weight_values.rds")
message(sprintf(
  "Wrote inst/extdata/standard_weight_values.rds (%d rows; vintages: %s; years: %s).",
  nrow(standard_weight_values),
  paste(unique(standard_weight_values$vintage), collapse = ", "),
  paste(range(standard_weight_values$year), collapse = "-")
))
