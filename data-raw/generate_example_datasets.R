# generate_example_datasets.R
# Run once with devtools::load_all('.') active to regenerate data/*.rda
# -------------------------------------------------------------------
library(data.table)
devtools::load_all(".")
set.seed(42)

ent <- master_data$entities

codes_for <- function(cls_id) {
  sort(unique(ent[classification_id == cls_id, code]))
}

# Fictitious socio-economic columns, scaled to a plausible population range
fake <- function(codes, pop_lo, pop_hi, code_col) {
  n   <- length(codes)
  pop <- as.integer(runif(n, pop_lo, pop_hi))
  dt  <- data.table(
    code          = codes,
    population    = pop,
    emplois       = as.integer(pop * runif(n, 0.35, 0.55)),
    masse_sal     = round(pop * runif(n, 18000, 32000), 0),
    taux_activite = round(runif(n, 0.55, 0.80), 3)
  )
  setnames(dt, "code", code_col)
  dt
}

# ---- Clean datasets ----------------------------------------------------------

rc_full_municipalities_2019 <- fake(
  codes_for("NIS_MUNICIPALITY_2019"), 200, 180000, "cd_commune")

rc_full_municipalities_2025 <- fake(
  codes_for("NIS_MUNICIPALITY_2025"), 200, 180000, "cd_commune")

rc_full_districts_2019 <- fake(
  codes_for("NIS_DISTRICT_2019"), 5000, 600000, "cd_arr")

rc_full_regions_2019 <- fake(
  codes_for("NIS_REGION_2019"), 500000, 3700000, "cd_region")

rc_full_nuts3_2021 <- fake(
  codes_for("NUTS_DISTRICT_2021"), 10000, 700000, "cd_nuts3")

rc_full_nuts3_2027 <- fake(
  codes_for("NUTS_DISTRICT_2027"), 10000, 700000, "cd_nuts3_2027")

rc_full_postal <- fake(
  codes_for("POSTAL"), 50, 80000, "cd_postal")

# ---- Dirty dataset -----------------------------------------------------------
# rc_dirty_municipalities_2019: NIS_MUNICIPALITY_2019 codes with deliberate issues
# to demonstrate diagnose_classification(), validate_codes(), detect_classification().

all_codes_2019 <- codes_for("NIS_MUNICIPALITY_2019")
all_codes_2025 <- codes_for("NIS_MUNICIPALITY_2025")
# codes that exist in 2025 but NOT in 2019 (new post-fusion codes)
new_2025_codes <- setdiff(all_codes_2025, all_codes_2019)

n_base <- 300L
base_codes <- sample(all_codes_2019, n_base)

pop_base <- as.integer(runif(n_base, 200, 180000))

dirty_base <- data.table(
  cd_commune    = base_codes,
  population    = pop_base,
  emplois       = as.integer(pop_base * runif(n_base, 0.35, 0.55)),
  masse_sal     = round(pop_base * runif(n_base, 18000, 32000), 0),
  taux_activite = round(runif(n_base, 0.55, 0.80), 3)
)

# Issue 1: duplicate rows (5 communes appear twice)
dupes <- dirty_base[sample(.N, 5)]
# Issue 2: codes from NIS 2025 that do not exist in 2019 (4 codes)
if (length(new_2025_codes) >= 4L) {
  alien_codes <- head(new_2025_codes, 4L)
} else {
  alien_codes <- head(new_2025_codes, length(new_2025_codes))
}
n_alien <- length(alien_codes)
pop_alien <- as.integer(runif(n_alien, 200, 50000))
aliens <- data.table(
  cd_commune    = alien_codes,
  population    = pop_alien,
  emplois       = as.integer(pop_alien * runif(n_alien, 0.35, 0.55)),
  masse_sal     = round(pop_alien * runif(n_alien, 18000, 32000), 0),
  taux_activite = round(runif(n_alien, 0.55, 0.80), 3)
)
# Issue 3: rows with NA code
na_rows <- data.table(
  cd_commune    = c(NA_integer_, NA_integer_),
  population    = c(5000L, 12000L),
  emplois       = c(1800L, 4500L),
  masse_sal     = c(95e6, 220e6),
  taux_activite = c(0.62, 0.71)
)
# Issue 4: rows with NA value only
na_val_rows <- dirty_base[sample(.N, 8), .(cd_commune, population = NA_integer_,
                                            emplois, masse_sal, taux_activite)]

rc_dirty_municipalities_2019 <- rbindlist(
  list(dirty_base, dupes, aliens, na_rows, na_val_rows),
  use.names = TRUE, fill = FALSE
)
# shuffle rows so issues are not at the end
rc_dirty_municipalities_2019 <- rc_dirty_municipalities_2019[sample(.N)]

# ---- Save --------------------------------------------------------------------
usethis::use_data(
  rc_full_municipalities_2019,
  rc_full_municipalities_2025,
  rc_full_districts_2019,
  rc_full_regions_2019,
  rc_full_nuts3_2021,
  rc_full_nuts3_2027,
  rc_full_postal,
  rc_dirty_municipalities_2019,
  overwrite = TRUE
)

cat("\nDataset sizes:\n")
for (nm in c("rc_full_municipalities_2019", "rc_full_municipalities_2025",
             "rc_full_districts_2019", "rc_full_regions_2019",
             "rc_full_nuts3_2021", "rc_full_nuts3_2027",
             "rc_full_postal", "rc_dirty_municipalities_2019")) {
  dt <- get(nm)
  cat(sprintf("  %-38s %d rows x %d cols\n", nm, nrow(dt), ncol(dt)))
}
