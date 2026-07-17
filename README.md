# nbbbenuts

R package for converting Belgian geographic codes between classification systems and across time versions.

## Overview

Belgian administrative data uses multiple overlapping classification systems that change over time. This package provides a unified, graph-based interface to convert between them — with explicit handling of ambiguous (M:N or 1:N) mappings.

**23 supported classifications:**

| System | Identifiers |
|--------|-------------|
| **NIS communes** | `NIS_MUNICIPALITY_BEFORE_2019` (589), `NIS_MUNICIPALITY_2019` (581), `NIS_MUNICIPALITY_2025` (565) |
| **NIS arrondissements** | `NIS_DISTRICT_BEFORE_2019`, `_2019`, `_2025` |
| **NIS provinces** | `NIS_PROVINCE_BEFORE_2019`, `_2019`, `_2025` |
| **NIS regions** | `NIS_REGION_BEFORE_2019`, `_2019`, `_2025` |
| **NIS country** | `NIS_COUNTRY` (code 1000 — Belgium) |
| **NUTS LAU** | `NUTS_MUNICIPALITY_2021` |
| **NUTS arrondissements** (NUTS 3) | `NUTS_DISTRICT_2021`, `_2027` |
| **NUTS provinces** (NUTS 2) | `NUTS_PROVINCE_2021`, `_2027` |
| **NUTS regions** (NUTS 1) | `NUTS_REGION_2021`, `_2027` |
| **NUTS country** (NUTS 0) | `NUTS_COUNTRY` (code BE — Belgium) |
| **Other** | `POSTAL` (postal codes), `NBB_DISTRICT_2021` |

All identifiers are case-insensitive. Unknown identifiers raise a typed error (`rcl_invalid_classification`).

## Installation

```r
# Install dependencies
install.packages(c("data.table", "rlang"))

# Install nbbbenuts from GitHub
remotes::install_github("N0n3Z/RegionalClassification")
```

## Quick Start

Every usage example lives here, grouped by task. Load the package and the
reference snapshot first:

```r
library(nbbbenuts)
library(data.table)

master_data <- load_master_data()
```

**Convert codes** — `convert_codes()` always returns a `data.table(code_from, code_to, nature)`.
All codes are `character` (integer input is accepted and converted):

```r
# NIS communes (2019) -> NUTS3 (2021)
convert_codes(c("21001", "11002", "62063"), "NIS_MUNICIPALITY_2019", "NUTS_DISTRICT_2021", master_data)

# Postal codes -> NIS communes
convert_codes(c("1000", "2000", "4000"), "POSTAL", "NIS_MUNICIPALITY_2019", master_data)

# NIS 2025 -> NUTS 2027 (official Statbel/Eurostat mapping)
convert_codes(c("21004", "11002"), "NIS_MUNICIPALITY_2025", "NUTS_DISTRICT_2027", master_data)

# NIS temporal change: the `nature` column carries
# UNCHANGED / FUSION / CHANGE_DSTR / CHANGE_PROV
convert_codes(c("21001", "11056"), "NIS_MUNICIPALITY_2019", "NIS_MUNICIPALITY_2025", master_data)
```

**Inspect conversion paths** — all paths (including multi-hop) resolve automatically:

```r
# Is a path simple (N:1 / 1:1) or ambiguous?
check_conversion_path("NIS_MUNICIPALITY_2019", "NUTS_DISTRICT_2021")
check_conversion_path("NIS_MUNICIPALITY_2025", "NUTS_DISTRICT_2021")   # 1:N
check_conversion_path("POSTAL", "NIS_REGION_2019")

# With master_data, two data-aware fields are added: `executable` and
# `effectively_simple` (an aggregation that re-merges to one target per source
# is deterministic even if it crosses an overlap edge -- no allow_ambiguous needed).
check_conversion_path("NIS_DISTRICT_2019", "NUTS_PROVINCE_2021", master_data)$effectively_simple

# Browse every supported conversion
get_conversion_matrix()
list_available_conversions()
```

**Ambiguous conversions & weighted splits** — 1:N / M:N need `allow_ambiguous = TRUE`:

```r
# Verviers arrondissement (63000) spans two NUTS3 regions: BE335 (FR) + BE336 (DE)
convert_codes("63000", "NIS_DISTRICT_2019", "NUTS_DISTRICT_2021", master_data,
              allow_ambiguous = TRUE)

# NIS_MUNICIPALITY_2025 -> NUTS_DISTRICT_2021 is 1:N: 3 communes (46029, 46030,
# 71072) fuse localities from different NUTS3 regions (coverage 562/565).
convert_codes(c("21001", "46029"), "NIS_MUNICIPALITY_2025", "NUTS_DISTRICT_2021", master_data,
              allow_ambiguous = TRUE)

# The package SHIPS population weights (NIS 2019 communes, 2011-2024), so
# proportional splits work out of the box -- no registration needed.
split_weights_template("NIS_DISTRICT_2019", "NUTS_DISTRICT_2021", master_data,
                       variable = "population")
#   63000  BE335  ~0.73   (real francophone share)
#   63000  BE336  ~0.27   (real germanophone share)

# split_ambiguous() / rebase_series() accept weights = "population" directly;
# weight_year = 2015L picks a reference year for period-consistent weights.
emp <- data.table(arr_code = c("11000", "63000"), total_wage = c(5e9, 1e9))
split_ambiguous(emp, "arr_code", value_cols = "total_wage",
                from = "NIS_DISTRICT_2019", to = "NUTS_DISTRICT_2021",
                master_data = master_data, weights = "population", value_type = "additive")

# For a custom variable or your own values, register a table (0.60/0.40 here are
# illustrative placeholders). Without any weights, splits fall back to EQUAL weights.
register_split_weights("NIS_DISTRICT_2019", "NUTS_DISTRICT_2021",
                       data.table(code_from = c("63000", "63000"),
                                  code_to   = c("BE335", "BE336"),
                                  weight    = c(0.60, 0.40)))
```

**Dataset-level conversion & diagnostics**:

```r
dt <- data.table(commune = c("21001", "11002", "62063"), value = c(100, 200, 300))

# Auto-detects the source classification, adds a target column
convert_dataset(dt, code_col = "commune", to = "NUTS_DISTRICT_2021", master_data)

# Coverage report / auto-detect the classification of a column
diagnose_classification(dt, "commune", master_data)
```

**Longitudinal rebasing** — put a multi-version panel onto one target version.
`version_map` assigns each period to its source classification:

```r
panel <- data.table(
  year      = c(2022L, 2022L, 2025L),
  commune   = c("11002", "11007", "11002"),
  population = c(18000, 8500, 28000)
)
rebase_series(panel, period_col = "year", code_col = "commune", value_cols = "population",
              version_map = list("NIS_MUNICIPALITY_2019" = 2022L,
                                 "NIS_MUNICIPALITY_2025" = 2025L),
              to = "NIS_MUNICIPALITY_2025", master_data = master_data)
```

**Labels, crosswalks, validation**:

```r
# Official French / Dutch names
get_label(c("21004", "11002"), "NIS_MUNICIPALITY_2019", master_data, lang = "fr")

# Full correspondence table (optionally with weight column)
get_crosswalk("NIS_MUNICIPALITY_2019", "NUTS_DISTRICT_2021", master_data)
get_crosswalk("NIS_DISTRICT_2019", "NUTS_DISTRICT_2021", master_data, weights = TRUE)

# Validate codes against the reference set
validate_codes(c("21004", "99999"), "NIS_MUNICIPALITY_2019", master_data)
```

**Fuzzy name matching**:

```r
fuzzy_match_names(c("Bruxeles", "Anvers", "Liege"), "NIS_MUNICIPALITY_2019", master_data,
                  max_dist = 0.3, language = "fr")

# Try several classifications at once and keep the best match per name
identify_from_names(c("Bruxelles", "Gent"), master_data)
```

**Visualization** (optional Suggests):

```r
visualize_classification_graph()   # interactive graph (requires visNetwork)
visualize_conversion_matrix()      # feasibility matrix (requires ggplot2)
```

## Conversion Graph

The package resolves conversions over a declared graph with a two-pass BFS
(simple edges first, then all edges). Cardinality determines whether a
conversion needs `allow_ambiguous = TRUE`:

| Type | Meaning | Requires `allow_ambiguous` |
|------|---------|---------------------------|
| `1:1` | Bijection | No |
| `N:1` | Many sources → one target | No |
| `1:N` | One source → multiple targets | **Yes** |
| `M:N` | Many sources → many targets | **Yes** |

An aggregation that crosses a `1:N` edge but re-merges to a single target per
source (e.g. arrondissement → NUTS province) is **effectively simple** and does
not require `allow_ambiguous` — check `check_conversion_path(from, to, master_data)$effectively_simple`.

## NIS Versions

Belgian communes are reorganised through periodic mergers and administrative transfers.

```
BEFORE_2019 ──[REFNIS_CHANGE_BEFORE2019]──► 2019 ──[REFNIS_CHANGE_2025]──► 2025
   589 communes                               581                             565
```

The `nature` column in `convert_codes()` output tracks how each commune changed:

| Value | Meaning |
|-------|---------|
| `UNCHANGED` | Same code in both versions |
| `FUSION` | Old commune merged into a new one |
| `CHANGE_DSTR` | Commune moved to a different arrondissement |
| `CHANGE_PROV` | Commune moved to a different province |

## NUTS 2027

NUTS 2027 codes implement EU Regulation 2026/195 (applicable from 1 January 2027). For NIS 2025 communes the mapping uses the official Statbel file. Key changes for Belgium:

| NUTS 2021 | NUTS 2027 | Region |
|-----------|-----------|--------|
| BE21x → **BE26x** | Antwerpen |
| BE22x (partial) → **BE22x / BE26x** | Vlaams-Brabant |
| BE23x → **BE27x** | Oost-Vlaanderen |

> **Note:** A direct **forward** `NUTS_DISTRICT_2021 → NUTS_DISTRICT_2027` edge exists (`1:N`), derived at build time, for **aggregate** NUTS3 2021 data — most codes map 1:1, but a few map to two 2027 codes (three communes changed province between 2019 and 2025), so it needs `allow_ambiguous = TRUE` and weighted splitting. There is **no reverse** `2027 → 2021` conversion. If you still have the underlying communes, convert them directly (exact, no weights): `NIS_MUNICIPALITY_2025 → NUTS_DISTRICT_2027`, or route `NUTS_DISTRICT_2021 → NIS_MUNICIPALITY_2019 → NIS_MUNICIPALITY_2025 → NUTS_DISTRICT_2027`.

## All Functions

| Function | Description |
|----------|-------------|
| `load_master_data()` | Load the pre-built reference snapshot |
| `convert_codes(codes, from, to, master_data)` | Convert codes between classifications |
| `convert_dataset(dt, code_col, to, master_data)` | Convert a column in a dataset |
| `split_ambiguous(dt, code_col, ...)` | Weighted split for 1:N / M:N conversions |
| `split_weights_template(from, to, master_data, variable, weight_year)` | Build a weights template (equal, shipped population, or custom) |
| `rebase_series(panel, code_col, ...)` | Rebase a time series across NIS versions |
| `diagnose_classification(dt, code_col, master_data)` | Diagnose coverage / auto-detect |
| `detect_classification(codes, master_data)` | Auto-detect a classification from codes |
| `check_conversion_path(from, to, md = NULL)` | Check path type, executability, coverage |
| `print_conversion_check(from, to)` | Print detailed path info to console |
| `get_crosswalk(from, to, master_data)` | Full correspondence table |
| `get_label(codes, classification, master_data)` | Official FR/NL names |
| `validate_codes(codes, classification, master_data)` | Check codes against reference set |
| `fuzzy_match_names(names, target, master_data)` | Match approximate names to codes |
| `identify_from_names(names, master_data)` | Identify classification from names |
| `register_split_weights(from, to, weights_dt, variable)` | Register split weights |
| `get_split_weights(from, to, variable)` | Retrieve registered weights |
| `list_available_conversions()` | List all supported conversion edges |
| `get_conversion_matrix(md = NULL)` | Full feasibility matrix |
| `visualize_classification_graph()` | Interactive graph (requires visNetwork) |
| `visualize_conversion_matrix()` | Matrix view (requires ggplot2) |

## Rebuilding the Data Snapshot

Only needed if the Statbel/Eurostat source files change. Place the files below in `data/raw/`, then run `rebuild_master_data()`.

| File | Description |
|------|-------------|
| `REFNIS_2019.xls` | NIS commune reference 2019 |
| `REFNIS_2025.xlsx` | NIS commune reference 2025 |
| `REFNIS_BEFORE_2019.xls` | NIS commune reference pre-2019 |
| `REFNIS_CHANGE_2025.xlsx` | NIS 2019 → 2025 fusion table |
| `REFNIS_CHANGE_BEFORE2019.xlsx` | NIS BEFORE_2019 → 2019 change table |
| `CONVERSION_NIS2019_NUTS2021.xlsx` | NIS 2019 → NUTS 2021 mapping |
| `REFNIS_2025-NUTS_2027.xlsx` | NIS 2025 → NUTS 2027 mapping |
| `CONVERSION_POSTAL_NIS2019.xlsx` | Postal → NIS 2019 mapping |
| `CONVERSION_POSTAL_NIS2025.xlsx` | Postal → NIS 2025 mapping |
| `NUTS_ARRONDISSEMENT.csv` | NUTS 3 ↔ internal arrondissement codes |

Standard population weights are rebuilt separately from `data-raw/build_standard_weights.R`.

## Package Structure

```
nbbbenuts/
├── R/
│   ├── 00_config.R              # Conversion graph edges, NIS constants, NUTS 2027 lookup
│   ├── 00b_registry.R           # CLASSIFICATION_NODES (23-entry single source of truth)
│   ├── 01_load_data.R           # Raw file parsers
│   ├── 02_build_master_table.R  # Master table construction (build-time only)
│   ├── 03_convert.R             # Conversion routing and execution
│   ├── 04_fuzzy_match.R         # Fuzzy name matching
│   ├── 05_conversion_check.R    # BFS path checker, conversion matrix
│   ├── 06_visualize.R           # Visualization utilities
│   ├── 07_dataset_convert.R     # convert_dataset()
│   ├── 07_detect.R              # Auto-detection of classification from codes
│   ├── 07_diagnose.R            # Diagnostics
│   ├── 07_split_ambiguous.R     # Weighted M:N split engine + standard weights
│   ├── 08_load_prebuilt.R       # load_master_data(), rebuild_master_data()
│   ├── 09_query.R               # get_crosswalk(), get_label(), validate_codes()
│   ├── 10_rebase.R              # rebase_series()
│   └── classifications.R        # Reference documentation for all classification identifiers
├── inst/extdata/                # Pre-built RDS snapshot + standard population weights
├── vignettes/                   # Introduction, conversions, diagnostics, ambiguous splits
├── data/raw/                    # Source files
└── tests/testthat/              # Automated test suite
```

## Testing

```r
devtools::test()    # FAIL 0 | WARN 0 | SKIP 0
devtools::check()   # 0 errors | 0 warnings | 0 notes
```
