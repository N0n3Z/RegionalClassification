# ==============================================================================
# build_standard_weights.R
# ------------------------------------------------------------------------------
# Builds inst/extdata/standard_weight_values.rds : the SHIPPED standard
# commune-level weighting variables consumed by
#   split_weights_template(from, to, master_data, variable = "population")
#
# Approach (C): the package ships POPULATION as the standard weighting variable;
# any other variable (employment, area, ...) is supplied by the user at call time
# via `commune_values =` (no shipped data needed for those).
#
# Output schema: data.table(variable chr, code chr, value num)
#   variable = "population"
#   code     = NIS 2019 commune code (character)  <-- the weighting "vintage"
#   value    = inhabitants
#
# The weighting vintage is NIS 2019 communes: it is the finest common refinement
# of every current ambiguous edge (NUTS3 2021<->2027, Verviers arr->NUTS3,
# NIS 2025->NUTS3 2021). split_weights_template() maps each 2019 commune to its
# `from` and `to` code and aggregates the values.
# ==============================================================================

library(data.table)
# library(readxl)   # uncomment if the source is an .xlsx

# --- 1. Read the raw population per NIS 2019 commune --------------------------
# EXPECTED: a Statbel commune-level population table for the 2019 commune
# perimeter, with a commune-code column and a population column.
# Drop the raw file under data/raw/ and adapt the two lines below.
#
#   pop <- as.data.table(readxl::read_excel("data/raw/POPULATION_2019.xlsx"))
#   pop <- pop[, .(code = as.character(CD_REFNIS), value = as.numeric(POPULATION))]
#
stop("Fill in the raw population read above before running this script.")

# --- 2. Assemble the standard weights table ----------------------------------
# One block per shipped standard variable. Add more later if desired.
standard_weight_values <- rbindlist(list(
  data.table(variable = "population", code = pop$code, value = pop$value)
))

# --- 3. Sanity checks --------------------------------------------------------
# Every NIS 2019 commune should have a population value, else some ambiguous
# code_from could get an all-zero mass and fall back to equal weights.
# devtools::load_all(".")
# md <- load_master_data()
# comm19 <- as.character(md$communes[nis_version == VER_2019, cd_commune])
# missing <- setdiff(comm19, standard_weight_values[variable == "population", code])
# if (length(missing)) warning(sprintf("%d 2019 communes without population", length(missing)))

# --- 4. Persist --------------------------------------------------------------
saveRDS(standard_weight_values, "inst/extdata/standard_weight_values.rds")
message("Wrote inst/extdata/standard_weight_values.rds (",
        nrow(standard_weight_values), " rows).")
