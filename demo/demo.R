# ==============================================================================
# demo.R -- Complete demonstration of the nbbbenuts package
#
# This script illustrates every public function of the package.
# Run it section by section in RStudio or from the command line:
#   Rscript demo/demo.R
# ==============================================================================

library(nbbbenuts)
library(data.table)


# ==============================================================================
# 0. Load the reference data
# ==============================================================================

master_data <- load_master_data()
# > Master data loaded from '.../inst/extdata':
# > 581 communes NIS 2019, 565 NIS 2025, 589 NIS BEFORE_2019


# ==============================================================================
# 1. Available classifications
# ==============================================================================

# List every canonical identifier (23 in total)
get_all_classification_nodes()

# Matrix of possible conversions
get_conversion_matrix()

# Conversion paths with perimeter semantics
print_conversion_check("NIS_MUNICIPALITY_2019", "NUTS_DISTRICT_2021")
# Simple conversion: YES
# Perimeter-preserving: YES
# Perimeter relations: identity -> nesting
# Path: NIS_MUNICIPALITY_2019 -> NUTS_MUNICIPALITY_2021 -> NUTS_DISTRICT_2021

print_conversion_check("NIS_DISTRICT_2019", "NUTS_DISTRICT_2021")
# Simple conversion: NO
# Perimeter-preserving: NO (straddle)
# Verviers district (63000) straddles BE335 + BE336

print_conversion_check("NIS_MUNICIPALITY_2025", "NUTS_DISTRICT_2021")
# Simple conversion: NO  (3 mergers straddle the NUTS3 boundaries)
# Perimeter-preserving: NO (straddle)

# Quick test: does the conversion preserve perimeters?
is_perimeter_preserving("NIS_MUNICIPALITY_2019", "NUTS_DISTRICT_2021")   # TRUE
is_perimeter_preserving("NIS_MUNICIPALITY_2025", "NUTS_DISTRICT_2021")   # FALSE (1:N mergers)
is_perimeter_preserving("NIS_MUNICIPALITY_2019", "NIS_MUNICIPALITY_2025")  # TRUE (temporal)

# --- TOPOLOGICAL vs EFFECTIVE simplicity (data-aware) --------------------------
# When master_data is passed, check_conversion_path exposes two extra fields:
#   executable          -- can the engine actually execute the route?
#   effectively_simple  -- is the route N:1/1:1 ON THE DATA? (an aggregation that
#                          crosses an overlap edge but re-converges to a single
#                          target per source is "effectively simple")
r <- check_conversion_path("NIS_DISTRICT_2019", "NUTS_PROVINCE_2021", master_data)
r$is_simple            # FALSE: the path crosses the 1:N Verviers edge (topological)
r$effectively_simple   # TRUE : BE335 and BE336 both nest in BE33 -> 1 target
r$executable           # TRUE

# The full matrix with these two data-aware columns:
get_conversion_matrix(master_data)[is_simple == FALSE & effectively_simple == TRUE]
# -> the deterministic aggregations convert_codes() accepts without allow_ambiguous

# All available conversions with their perimeter semantics
la <- list_available_conversions()
# Columns: from, to, relation, perimeter_relation, notes
la[perimeter_relation == "temporal"]   # conversions between NIS versions
la[perimeter_relation == "overlap"]    # 1:N (straddling; no M:N edge currently)
la[perimeter_relation == "nesting"]    # pure N:1 aggregations
la[perimeter_relation == "identity"]   # 1:1 correspondences

# Full documentation of the identifiers
# ?classification_reference


# ==============================================================================
# 2. Code conversion -- convert_codes()
# ==============================================================================

# --- 2a. NIS 2019 communes -> NUTS3 2021 ----------------------------------------
convert_codes(
  c(21004L, 11002L, 44021L, 62063L),
  from = "NIS_MUNICIPALITY_2019",
  to   = "NUTS_DISTRICT_2021",
  master_data
)
#    code_from  code_to  nature
# 1:     21004   BE100   RECODE   (Brussels-Capital)
# 2:     11002   BE211   RECODE   (Antwerp district)
# 3:     44021   BE234   RECODE   (Ghent district)
# 4:     62063   BE332   RECODE   (Liege district)

# --- 2b. Postal codes -> NIS communes -------------------------------------------
convert_codes(c(1000L, 2000L, 4000L), "POSTAL", "NIS_MUNICIPALITY_2019", master_data)
#    code_from  code_to  nature
# 1:      1000    21004   RECODE  (Brussels)
# 2:      2000    11002   RECODE  (Antwerp)
# 3:      4000    62063   RECODE  (Liege)

# --- 2c. NIS commune -> every geographic level --------------------------------
commune <- 11002L  # Antwerp

convert_codes(commune, "NIS_MUNICIPALITY_2019", "NIS_DISTRICT_2019", master_data)
convert_codes(commune, "NIS_MUNICIPALITY_2019", "NIS_PROVINCE_2019",       master_data)
convert_codes(commune, "NIS_MUNICIPALITY_2019", "NIS_REGION_2019",         master_data)
convert_codes(commune, "NIS_MUNICIPALITY_2019", "NUTS_DISTRICT_2021",              master_data)
convert_codes(commune, "NIS_MUNICIPALITY_2019", "NUTS_PROVINCE_2021",              master_data)
convert_codes(commune, "NIS_MUNICIPALITY_2019", "NUTS_REGION_2021",              master_data)
convert_codes(commune, "NIS_MUNICIPALITY_2019", "NUTS_COUNTRY",                   master_data)
convert_codes(commune, "NIS_MUNICIPALITY_2019", "NBB_DISTRICT_2021", master_data)

# --- 2c-bis. Province -> region: N:1 nesting (split of Brabant) -----------------
# Since the 1995 split, each province belongs to exactly one region: no ambiguity,
# no need for allow_ambiguous. The former unified province of Brabant (20000) no
# longer exists -> Flemish Brabant (20001) / Walloon Brabant (20002).
# Brussels-Capital has no statutory province: it is assigned a pseudo-province
# equal to its region code (4000).
convert_codes(c(10000L, 20001L, 20002L, 4000L),
              "NIS_PROVINCE_2019", "NIS_REGION_2019", master_data)
#    code_from  code_to  nature
# 1:    10000     2000   RECODE  (Antwerp         -> Flemish)
# 2:    20001     2000   RECODE  (Flemish Brabant -> Flemish)
# 3:    20002     3000   RECODE  (Walloon Brabant -> Walloon)
# 4:     4000     4000   RECODE  (Brussels        -> Brussels, pseudo-province)

# --- 2d. Conversions between NIS versions (nature column) ----------------------
#
# Temporal conversions carry a 'nature' column:
#   UNCHANGED   -- code unchanged in both versions (551 communes)
#   FUSION      -- one or more 2019 communes merged into one 2025 code (27)
#   CHANGE_DSTR -- commune moved to another district (2 communes)
#   CHANGE_PROV -- commune moved to another province (1 commune)

# NIS 2019 -> NIS 2025: commune mergers
convert_codes(c(11002L, 11007L), "NIS_MUNICIPALITY_2019", "NIS_MUNICIPALITY_2025", master_data)
#    code_from  code_to  nature
# 1:     11002    11002   UNCHANGED
# 2:     11007    11002   FUSION   (Borgerhout merged into Antwerp)

# NIS 2019 -> NIS 2025: CHANGE_DSTR (commune 44045 -> different district)
convert_codes(44045L, "NIS_MUNICIPALITY_2019", "NIS_MUNICIPALITY_2025", master_data)
#    code_from  code_to       nature
# 1:     44045    46029  CHANGE_DSTR

# NIS 2019 -> NIS 2025: CHANGE_PROV (commune 11056 -> different province)
convert_codes(11056L, "NIS_MUNICIPALITY_2019", "NIS_MUNICIPALITY_2025", master_data)
#    code_from  code_to       nature
# 1:     11056    46030  CHANGE_PROV

# NIS 2025 -> NIS 2019: decomposition (returns several rows for mergers)
convert_codes(11002L, "NIS_MUNICIPALITY_2025", "NIS_MUNICIPALITY_2019", master_data,
              allow_ambiguous = TRUE)
#    code_from  code_to  nature
# 1:     11002    11002   UNCHANGED
# 2:     11002    11007   FUSION

# The nature is symmetric on the reverse path (CHANGE_PROV preserved)
convert_codes(46030L, "NIS_MUNICIPALITY_2025", "NIS_MUNICIPALITY_2019", master_data,
              allow_ambiguous = TRUE)
#    code_from  code_to       nature
# ...           11056   CHANGE_PROV   (the matching row)

# NIS BEFORE_2019 -> NIS 2019
convert_codes(c(55022L, 56011L), "NIS_MUNICIPALITY_BEFORE_2019", "NIS_MUNICIPALITY_2019",
              master_data)

# --- 2e. NUTS 2027 (EU Regulation 2026/195) -----------------------------------
convert_codes(
  c(21004L, 11002L, 44021L),
  "NIS_MUNICIPALITY_2019", "NUTS_DISTRICT_2027",
  master_data
)
# 21004 -> BE100  (Brussels, unchanged)
# 11002 -> BE261  (Antwerp: BE211 -> BE261)
# 44021 -> BE274  (Ghent  : BE234 -> BE274)

# NUTS3 2021 -> NUTS3 2027: direct 1:N edge (allow_ambiguous required).
# Most codes -> 1 target; BE211 -> {BE261, BE276} because commune 11056 changed
# province between 2019 and 2025.
convert_codes(c("BE100", "BE211"), "NUTS_DISTRICT_2021", "NUTS_DISTRICT_2027",
              master_data, allow_ambiguous = TRUE)
#    code_from  code_to  nature
# 1:     BE100    BE100   RECODE
# 2:     BE211    BE261   OVERLAP
# 3:     BE211    BE276   OVERLAP
# -> To spread an aggregated value across the ambiguous targets, use weights:
#    register_split_weights("NUTS_DISTRICT_2021","NUTS_DISTRICT_2027", tpl) + split_ambiguous(...).
# -> If you have the communes, convert them directly to 2027 (exact, no weights).

# Reverse direction 2027 -> 2021: no direct edge (expected error)
tryCatch(
  convert_codes("BE261", "NUTS_DISTRICT_2027", "NUTS_DISTRICT_2021", master_data),
  error = function(e) message("Reverse direction not direct: ", conditionMessage(e))
)

# --- 2f. Ambiguous conversion -- Verviers district (1:N) ------------------------
# Verviers -> NUTS3 is a TRUE split (BE335 != BE336): blocked by default.
tryCatch(
  convert_codes(63000L, "NIS_DISTRICT_2019", "NUTS_DISTRICT_2021", master_data),
  error = function(e) message("Expected error: ", conditionMessage(e))
)

# Force all possible correspondences
convert_codes(63000L, "NIS_DISTRICT_2019", "NUTS_DISTRICT_2021",
              master_data, allow_ambiguous = TRUE)
#    code_from  code_to  nature
# 1:     63000   BE335   OVERLAP  (Verviers district, French-speaking)
# 2:     63000   BE336   OVERLAP  (Verviers district, German-speaking)

# --- 2g. Deterministic aggregation -- NO allow_ambiguous needed -----------------
# Even though the path crosses the 1:N Verviers edge, aggregating to a coarser
# level where BE335 and BE336 re-converge (province BE33, region BE3, country BE)
# is deterministic: the data-aware gate allows it directly (audit M2).
convert_codes(63000L, "NIS_DISTRICT_2019", "NUTS_PROVINCE_2021", master_data)
#    code_from  code_to  nature
# 1:     63000    BE33   RECODE   (a single target -> no ambiguity)

convert_codes(63000L, "NIS_DISTRICT_2019", "NUTS_COUNTRY", master_data)
#    code_from  code_to  nature
# 1:     63000      BE   RECODE


# ==============================================================================
# 3. Dataset conversion -- convert_dataset()
# ==============================================================================

dt <- data.table(
  cd_commune = c(21004L, 11002L, 44021L, 62063L),
  pop        = c(180000L, 530000L, 260000L, 200000L)
)

# Auto-detect the source classification + add a NUTS3 column
convert_dataset(dt, "cd_commune",
                from = "NIS_MUNICIPALITY_2019",
                to   = "NUTS_DISTRICT_2021",
                master_data)
# Adds the 'cd_nuts3_2021' column.

# Full conversion: communes -> NUTS3 -> NIS districts
dt2 <- copy(dt)
convert_dataset(dt2, "cd_commune", from = "NIS_MUNICIPALITY_2019",
                to = "NIS_DISTRICT_2019", master_data)


# ==============================================================================
# 4. Code validation -- validate_codes()
# ==============================================================================

validate_codes(c(21004L, 99999L, 11002L), "NIS_MUNICIPALITY_2019", master_data)
#      code  is_valid
# 1:  21004      TRUE
# 2:  99999     FALSE
# 3:  11002      TRUE

validate_codes(c("1000", "9999"), "POSTAL", master_data)
validate_codes(c("BE100", "ZZZZ"), "NUTS_DISTRICT_2021", master_data)
validate_codes(c("21", "99"),      "NBB_DISTRICT_2021", master_data)


# ==============================================================================
# 5. Official names -- get_label()
# ==============================================================================

# French names
get_label(c(21004L, 11002L, 62063L), "NIS_MUNICIPALITY_2019", master_data, lang = "fr")
#      code      label
# 1:  21004  Bruxelles
# 2:  11002      Anvers
# 3:  62063      Liege

# Dutch names
get_label(c(21004L, 11002L), "NIS_MUNICIPALITY_2019", master_data, lang = "nl")

# NUTS3
get_label(c("BE100", "BE211", "BE332"), "NUTS_DISTRICT_2021", master_data, lang = "fr")

# Postal codes
get_label(c(1000L, 2000L), "POSTAL", master_data, lang = "fr")

# Unknown code -> NA
get_label(c(21004L, 99999L), "NIS_MUNICIPALITY_2019", master_data)


# ==============================================================================
# 6. Crosswalk table -- get_crosswalk()
# ==============================================================================

# Full commune -> NUTS3 crosswalk
cw <- get_crosswalk("NIS_MUNICIPALITY_2019", "NUTS_DISTRICT_2021", master_data)
head(cw)

# Postal -> commune crosswalk (N:1)
get_crosswalk("POSTAL", "NIS_MUNICIPALITY_2019", master_data)

# With a weight column -- useful for ambiguous pairs
get_crosswalk("NIS_DISTRICT_2019", "NUTS_DISTRICT_2021", master_data, weights = TRUE)
# ...
# 63000   BE335   0.5   (equal weights by default)
# 63000   BE336   0.5

# With registered custom weights (see section 8).
# NB: 0.60/0.40 are FICTITIOUS illustrative values -- not official weights.
register_split_weights(
  "NIS_DISTRICT_2019", "NUTS_DISTRICT_2021",
  data.table(code_from = c(63000L, 63000L),
             code_to   = c("BE335", "BE336"),
             weight    = c(0.60, 0.40))
)
get_crosswalk("NIS_DISTRICT_2019", "NUTS_DISTRICT_2021", master_data, weights = TRUE)
# 63000   BE335   0.60
# 63000   BE336   0.40
clear_split_weights()


# ==============================================================================
# 7. Coverage diagnostics -- diagnose_classification()
# ==============================================================================

# --- 7a. Verification mode (classification supplied) ---------------------------
nuts3_data <- data.table(
  nuts3 = c("BE100", "BE211", "BE332"),
  value = c(100, 200, 150)
)

diagnose_classification(nuts3_data, "nuts3", master_data,
                        classification = "NUTS_DISTRICT_2021")
# Prints: coverage, missing codes, unknown codes, duplicates

# The invisible result holds the structured details
diag <- diagnose_classification(nuts3_data, "nuts3", master_data,
                                classification = "NUTS_DISTRICT_2021", verbose = FALSE)
diag$coverage_rate   # fraction of reference codes present
diag$status          # "COMPLETE", "INCOMPLETE", "COMPLETE_WITH_UNKNOWNS", ...
diag$missing_codes   # data.table of absent codes
diag$unknown_codes   # data.table of unrecognised codes

# --- 7b. Auto-detection mode (classification = NULL) ---------------------------
diagnose_classification(nuts3_data, "nuts3", master_data)
# Ranks every classification by match rate

# --- 7c. Direct detection -- detect_classification() ---------------------------
# Returns the single most likely identifier (>= 80% match).
detect_classification(c(21004L, 11002L, 62063L), master_data)  # "NIS_MUNICIPALITY_2019"
detect_classification(c("BE100", "BE211"),        master_data)  # "NUTS_DISTRICT_2021"
detect_classification(c("BE261", "BE262"),        master_data)  # "NUTS_DISTRICT_2027" (2027 vintage)
detect_classification("BE",                       master_data)  # "NUTS_COUNTRY"
detect_classification(c(1000L, 2000L),            master_data)  # "POSTAL"


# ==============================================================================
# 8. Weighted correspondences -- split_ambiguous() and the weight registry
# ==============================================================================
#
# The package SHIPS standard POPULATION weights (NIS 2019 communes, 2011-2024):
# variable = "population" works out of the box (see 8b). Without supplied weights,
# split_ambiguous() applies EQUAL weights by default.
# NB: the few HAND-WRITTEN weight values below (e.g. 0.60/0.40 for Verviers)
# remain illustrative examples -- for real weights, use variable = "population"
# or supply your own via commune_values.

# --- 8a. split_ambiguous() directly --------------------------------------------
arr_data <- data.table(
  arr_code   = c(11000L, 62000L, 63000L),
  total_wage = c(5e9, 3e9, 1e9),
  avg_salary = c(2900, 2700, 2400)
)

# Equal weights (default) -- additive variable
split_ambiguous(
  arr_data,
  code_col   = "arr_code",
  value_cols = c("total_wage"),
  from       = "NIS_DISTRICT_2019",
  to         = "NUTS_DISTRICT_2021",
  master_data,
  value_type = "additive"
)
# 63000 -> BE335 : total_wage * 0.5
# 63000 -> BE336 : total_wage * 0.5

# Ratio variable -- values unchanged in both targets
split_ambiguous(
  arr_data,
  code_col   = "arr_code",
  value_cols = "avg_salary",
  from       = "NIS_DISTRICT_2019",
  to         = "NUTS_DISTRICT_2021",
  master_data,
  value_type = "ratio"
)

# --- 8b. Weight template -- split_weights_template() ---------------------------
# By default: EQUAL weights.
tpl <- split_weights_template("NIS_DISTRICT_2019", "NUTS_DISTRICT_2021", master_data)
#    code_from  code_to  weight
# 1:     63000    BE335     0.5
# 2:     63000    BE336     0.5

# Shipped POPULATION weights (out of the box) -- most recent year by default:
tpl_pop <- split_weights_template("NIS_DISTRICT_2019", "NUTS_DISTRICT_2021",
                                  master_data, variable = "population")
#    code_from  code_to     weight
# 1:     63000    BE335   ~0.73     (actual French-speaking share)
# 2:     63000    BE336   ~0.27     (actual German-speaking share)

# Pick a reference year (period-consistent backcasting):
tpl_2015 <- split_weights_template("NIS_DISTRICT_2019", "NUTS_DISTRICT_2021",
                                   master_data, variable = "population", weight_year = 2015L)

# split_ambiguous / rebase_series accept weights = "population" directly:
split_ambiguous(arr_data, "arr_code", value_cols = "total_wage",
                from = "NIS_DISTRICT_2019", to = "NUTS_DISTRICT_2021",
                master_data, weights = "population", value_type = "additive")

# Or hand-written values (ILLUSTRATIVE -- not official):
tpl[code_from == "63000" & code_to == "BE335", weight := 0.60]
tpl[code_from == "63000" & code_to == "BE336", weight := 0.40]

# --- 8c. Register custom weights for reuse -------------------------------------
# NB: register under a DISTINCT name ("population_custom") so as not to shadow the
# shipped "population" standard.
register_split_weights(
  from       = "NIS_DISTRICT_2019",
  to         = "NUTS_DISTRICT_2021",
  weights_dt = tpl,
  variable   = "population_custom"
)

list_split_weights()
#           from            to           variable
# NIS_DISTRICT_2019  NUTS_DISTRICT_2021  population_custom

get_split_weights("NIS_DISTRICT_2019", "NUTS_DISTRICT_2021", variable = "population_custom")

clear_split_weights()


# ==============================================================================
# 9. Longitudinal rebasing -- rebase_series()
# ==============================================================================

# --- 9a. N:1 merger: communes that merge in 2025 -------------------------------
# Communes 11002 (Antwerp) and 11007 (Borgerhout) merged in NIS 2025.
panel <- data.table(
  year       = c(2022L, 2022L, 2022L, 2025L, 2025L),
  commune    = c(11002L, 11007L, 21004L, 11002L, 21004L),
  population = c(530000, 42000, 180000, 590000, 182000)
)

result_n1 <- rebase_series(
  panel,
  period_col  = "year",
  code_col    = "commune",
  value_cols  = "population",
  version_map = list(
    "NIS_MUNICIPALITY_2019" = 2022L,
    "NIS_MUNICIPALITY_2025" = 2025L
  ),
  to          = "NIS_MUNICIPALITY_2025",
  master_data = master_data
)
# 2022: commune 11002 -> 530000 + 42000 = 572000 (merged)
# 2025: data unchanged (already in NIS 2025)

# --- 9b. Ratio variable -- aggregation with the mean --------------------------
panel_rates <- data.table(
  year    = c(2022L, 2022L),
  commune = c(11002L, 11007L),
  taux_emploi = c(0.62, 0.58)
)

result_ratio <- rebase_series(
  panel_rates,
  period_col  = "year",
  code_col    = "commune",
  value_cols  = "taux_emploi",
  version_map = list("NIS_MUNICIPALITY_2019" = 2022L),
  to          = "NIS_MUNICIPALITY_2025",
  master_data = master_data,
  fun         = mean,
  value_type  = "ratio"
)
# commune 11002: rate = mean(0.62, 0.58) = 0.60

# --- 9c. 1:N split: district-level data to NUTS3 ------------------------------
arr_panel <- data.table(
  year    = c(2020L, 2021L, 2020L, 2021L),
  arr     = c(63000L, 63000L, 11000L, 11000L),
  emplois = c(120000, 122000, 310000, 315000)
)

# split = "population" (default) uses the shipped POPULATION STANDARD -- no weight
# registration needed.
result_1n <- rebase_series(
  arr_panel,
  period_col  = "year",
  code_col    = "arr",
  value_cols  = "emplois",
  version_map = list("NIS_DISTRICT_2019" = 2020:2021),
  to          = "NUTS_DISTRICT_2021",
  master_data = master_data
  # split = "population" is the default value
)
# Verviers 120000 split by actual population shares:
# BE335 ~ 120000 * 0.73 ; BE336 ~ 120000 * 0.27

# Passing CUSTOM weights directly (one-off use without the registry):
tpl2 <- split_weights_template("NIS_DISTRICT_2019", "NUTS_DISTRICT_2021", master_data)
tpl2[code_from == "63000" & code_to == "BE335", weight := 0.60]   # fictitious values
tpl2[code_from == "63000" & code_to == "BE336", weight := 0.40]
result_direct <- rebase_series(
  arr_panel,
  period_col  = "year",
  code_col    = "arr",
  value_cols  = "emplois",
  version_map = list("NIS_DISTRICT_2019" = 2020:2021),
  to          = "NUTS_DISTRICT_2021",
  master_data = master_data,
  split       = tpl2
)

# --- 9d. Uncovered periods -- rcl_missing_periods warning ----------------------
data_mixed <- data.table(year = 2022:2024, commune = 21004L, pop = c(1, 2, 3))
withCallingHandlers(
  rebase_series(
    data_mixed,
    period_col  = "year",
    code_col    = "commune",
    value_cols  = "pop",
    version_map = list("NIS_MUNICIPALITY_2019" = 2022L),
    to          = "NIS_MUNICIPALITY_2025",
    master_data = master_data
  ),
  rcl_missing_periods = function(w) {
    message("Skipped periods: ", conditionMessage(w))
    invokeRestart("muffleWarning")
  }
)


# ==============================================================================
# 10. Complete example datasets
# ==============================================================================
#
# /!\ IMPORTANT: these datasets are provided FOR DEMONSTRATION AND TESTING ONLY.
#     The socio-economic columns (population, emplois, masse_sal, taux_activite,
#     ...) are PURELY FICTITIOUS randomly generated values -- they are NOT real
#     statistics. Never use them for real analysis; load your own data.
#
# The package includes eight ready-to-use datasets:
#
#   Clean datasets (one row per geographic unit):
#     rc_full_municipalities_2019  -- 581 NIS 2019 communes
#     rc_full_municipalities_2025  -- 565 NIS 2025 communes
#     rc_full_districts_2019       -- 43 NIS 2019 districts
#     rc_full_regions_2019         -- 3 NIS 2019 regions
#     rc_full_nuts3_2021           -- 44 NUTS3 2021 regions
#     rc_full_nuts3_2027           -- 44 NUTS3 2027 regions
#     rc_full_postal               -- 1,149 postal codes
#
#   Dirty dataset (to test the diagnostics):
#     rc_dirty_municipalities_2019 -- 319 rows with duplicates, unknown codes,
#                                     NA values and codes from another version

# --- 10a. Full conversion of a clean dataset -----------------------------------
data(rc_full_municipalities_2019)

convert_dataset(rc_full_municipalities_2019, "cd_commune",
                from = "NIS_MUNICIPALITY_2019",
                to   = "NUTS_DISTRICT_2021",
                master_data)

# --- 10b. NUTS3 2021 -> NUTS2 2021 --------------------------------------------
data(rc_full_nuts3_2021)

convert_dataset(rc_full_nuts3_2021, "cd_nuts3",
                from = "NUTS_DISTRICT_2021",
                to   = "NUTS_PROVINCE_2021",
                master_data)

# --- 10c. Postal codes -> NIS 2019 communes ------------------------------------
data(rc_full_postal)

convert_dataset(rc_full_postal, "cd_postal",
                from = "POSTAL",
                to   = "NIS_MUNICIPALITY_2019",
                master_data)

# --- 10d. Diagnosing the dirty dataset ----------------------------------------
data(rc_dirty_municipalities_2019)

# Verification against NIS_MUNICIPALITY_2019
diagnose_classification(rc_dirty_municipalities_2019, "cd_commune", master_data,
                        classification = "NIS_MUNICIPALITY_2019")
# Reports: duplicates, unknown codes (2025 version), NA codes

# Precise validation
val <- validate_codes(rc_dirty_municipalities_2019$cd_commune,
                      "NIS_MUNICIPALITY_2019", master_data)
val[is_valid == FALSE]

# Auto-detect the best classification
diagnose_classification(rc_dirty_municipalities_2019, "cd_commune", master_data)


# ==============================================================================
# 11. Fuzzy name matching -- fuzzy_match_names()
# ==============================================================================

fuzzy_match_names(
  names    = c("Bruxeles", "Antwerpn", "Liege", "Naemur", "Vervirs"),
  target   = "NIS_MUNICIPALITY_2019",
  master_data,
  max_dist = 0.3,
  language = "both"
)
#   input_name  matched_name  matched_code  distance  is_confident
#   Bruxeles    Bruxelles        21004       0.037      TRUE
#   Antwerpn    Antwerpen        11002       0.037      TRUE
#   Liege       Liege            62063       0.150      TRUE
#   Naemur      Namur            92094       0.167      TRUE
#   Vervirs     Verviers         63079       0.042      TRUE


# ==============================================================================
# 12. Visualisation (requires visNetwork)
# ==============================================================================

# Graph of the relations between classifications
visualize_classification_graph()

# Conversion matrix
visualize_conversion_matrix()

# NIS 2019 hierarchy
visualize_hierarchy("NIS_2019", master_data)


# ==============================================================================
# 13. Utilities
# ==============================================================================

# Detailed conversion path with perimeter semantics
check_conversion_path("POSTAL", "NUTS_DISTRICT_2021")
# $is_simple          TRUE
# $path               "POSTAL -> NIS_MUNICIPALITY_2019 -> NUTS_MUNICIPALITY_2021 -> NUTS_DISTRICT_2021"
# $perimeter_status   "preserving"
# $straddle_free      TRUE

check_conversion_path("NIS_MUNICIPALITY_2025", "NUTS_DISTRICT_2021")
# $is_simple          FALSE
# $perimeter_status   "crossing"
# $straddle_free      FALSE

# Passing master_data also yields executable + effectively_simple:
check_conversion_path("NIS_MUNICIPALITY_2025", "NUTS_DISTRICT_2021", master_data)
# $is_simple           FALSE
# $executable          TRUE
# $effectively_simple  FALSE   (3 mergers -> true 1:N ambiguity)

# DECLARED but NON-executable route: the engine does not invert edges.
tryCatch(
  convert_codes("BE261", "NUTS_DISTRICT_2027", "NIS_MUNICIPALITY_2025", master_data),
  rcl_no_route = function(e) message("Non-executable route: ", conditionMessage(e))
)

# Rebuild the snapshot from the raw files (if data/raw/ is available)
# master_data <- rebuild_master_data()
