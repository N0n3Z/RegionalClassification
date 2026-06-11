# nbbbenuts

R package for converting Belgian geographic codes between classification systems and across time versions.

## Overview

Belgian administrative data uses multiple overlapping classification systems that change over time. This package provides a unified, graph-based interface to convert between them — with explicit handling of ambiguous (M:N or 1:N) mappings.

**23 supported classifications:**

| System | Identifiers |
|--------|-------------|
| **NIS communes** | `NIS_MUNICIPALITY_BEFORE_2019` (589), `NIS_MUNICIPALITY_2019` (583), `NIS_MUNICIPALITY_2025` (567) |
| **NIS arrondissements** | `NIS_DISTRICT_BEFORE_2019`, `_2019`, `_2025` |
| **NIS provinces** | `NIS_PROVINCE_BEFORE_2019`, `_2019`, `_2025` |
| **NIS regions** | `NIS_REGION_BEFORE_2019`, `_2019`, `_2025` |
| **NIS country** | `NIS_COUNTRY` (code 1000 — Belgium) |
| **NUTS 2021** | `NUTS_MUNICIPALITY_2021`, `NUTS_DISTRICT_2021`, `NUTS_PROVINCE_2021`, `NUTS_REGION_2021`, `NUTS_COUNTRY` |
| **NUTS 2027** | `NUTS_DISTRICT_2027`, `NUTS_PROVINCE_2027`, `NUTS_REGION_2027` |
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

```r
library(nbbbenuts)

master_data <- load_master_data()

# NIS communes (2019) -> NUTS3 (2021)
convert_codes(c(21001L, 11002L, 62063L), "NIS_MUNICIPALITY_2019", "NUTS_DISTRICT_2021", master_data)

# Postal codes -> NIS communes
convert_codes(c(1000L, 2000L, 4000L), "POSTAL", "NIS_MUNICIPALITY_2019", master_data)

# NIS 2025 -> NUTS 2027 (official Statbel/Eurostat mapping)
convert_codes(c(21004L, 11002L), "NIS_MUNICIPALITY_2025", "NUTS_DISTRICT_2027", master_data)

# NIS temporal change (nature column carries UNCHANGED / FUSION / CHANGE_DSTR / CHANGE_PROV)
convert_codes(c(21001L, 11056L), "NIS_MUNICIPALITY_2019", "NIS_MUNICIPALITY_2025", master_data)

# Fuzzy name matching
fuzzy_match_names(c("Bruxeles", "Anvers", "Liege"), "NIS_MUNICIPALITY_2019", master_data,
                  max_dist = 0.3, language = "fr")
```

`convert_codes()` always returns a `data.table` with exactly three columns: `code_from`, `code_to`, `nature`.

## Conversion Graph

The package uses a BFS-based conversion graph. All paths are resolved automatically — including multi-hop chains.

```r
# Check whether a path exists and whether it is simple (N:1 / 1:1)
check_conversion_path("NIS_MUNICIPALITY_2019", "NUTS_DISTRICT_2021")
check_conversion_path("NIS_MUNICIPALITY_2025", "NUTS_DISTRICT_2021")   # 1:N — see below
check_conversion_path("POSTAL", "NIS_REGION_2019")

# Browse the full matrix of supported conversions
get_conversion_matrix()
list_available_conversions()
```

### Simple vs ambiguous conversions

| Type | Meaning | Requires `allow_ambiguous` |
|------|---------|---------------------------|
| `1:1` | Bijection | No |
| `N:1` | Many sources → one target | No |
| `1:N` | One source → multiple targets | **Yes** |
| `M:N` | Many sources → many targets | **Yes** |

```r
# Verviers arrondissement (63000) spans two NUTS3 regions: BE335 (FR) + BE336 (DE)
convert_codes(63000L, "NIS_DISTRICT_2019", "NUTS_DISTRICT_2021", master_data,
              allow_ambiguous = TRUE)

# NIS_MUNICIPALITY_2025 -> NUTS_DISTRICT_2021 is 1:N:
# 3 communes (46029, 46030, 71072) fuse localities from different NUTS3 regions.
# check_conversion_path() reports Coverage: 564/567 (99.5%) and the 3 ambiguous codes.
convert_codes(c(21001L, 46029L), "NIS_MUNICIPALITY_2025", "NUTS_DISTRICT_2021", master_data,
              allow_ambiguous = TRUE)
```

### Weighted splits for ambiguous conversions

```r
# Register population weights for the Verviers split
wts <- data.table(
  code_from = c(63000L, 63000L),
  code_to   = c("BE335", "BE336"),
  weight    = c(0.857, 0.143)
)
register_split_weights("NIS_DISTRICT_2019", "NUTS_DISTRICT_2021",
                       variable = "population", weights = wts)

# Apply to a dataset
split_ambiguous(my_data, "arr_code",
                value_cols  = "total_wage",
                from        = "NIS_DISTRICT_2019",
                to          = "NUTS_DISTRICT_2021",
                master_data = master_data,
                value_type  = "additive")
```

## NIS Versions

Belgian communes are reorganised through periodic mergers and administrative transfers.

```
BEFORE_2019 ──[REFNIS_CHANGE_BEFORE2019]──► 2019 ──[REFNIS_CHANGE_2025]──► 2025
   589 communes                               583                             567
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

> **Note:** There is no direct `NUTS_DISTRICT_2021 ↔ NUTS_DISTRICT_2027` conversion. Three communes changed province between 2019 and 2025, shifting their NUTS3 region. Always route via NIS communes: `NUTS_DISTRICT_2021 → NIS_MUNICIPALITY_2019 → NIS_MUNICIPALITY_2025 → NUTS_DISTRICT_2027`.

## Dataset-Level Conversion

```r
library(data.table)
dt <- data.table(commune = c(21001L, 11002L, 62063L), value = c(100, 200, 300))

# Auto-detects source classification, adds target column
convert_dataset(dt, code_col = "commune", to = "NUTS_DISTRICT_2021", master_data)

# Diagnose coverage of an existing column
diagnose_classification(dt, "commune", master_data)

# Rebase a time series across NIS versions
rebase_series(panel, code_col = "nis_code", from_version = "2019",
              to_version = "2025", master_data = master_data)
```

## Reference Functions

```r
# Get official French/Dutch names for codes
get_label(c(21004L, 11002L), "NIS_MUNICIPALITY_2019", master_data, lang = "fr")

# Build a full crosswalk table (optionally with weights)
get_crosswalk("NIS_MUNICIPALITY_2019", "NUTS_DISTRICT_2021", master_data)
get_crosswalk("NIS_DISTRICT_2019", "NUTS_DISTRICT_2021", master_data, weights = TRUE)

# Validate codes against the reference set
validate_codes(c(21004L, 99999L), "NIS_MUNICIPALITY_2019", master_data)
```

## All Functions

| Function | Description |
|----------|-------------|
| `load_master_data()` | Load the pre-built reference snapshot |
| `convert_codes(codes, from, to, master_data)` | Convert codes between classifications |
| `convert_dataset(dt, code_col, to, master_data)` | Convert a column in a dataset |
| `split_ambiguous(dt, code_col, ...)` | Weighted split for 1:N / M:N conversions |
| `rebase_series(panel, code_col, ...)` | Rebase a time series across NIS versions |
| `diagnose_classification(dt, code_col, master_data)` | Diagnose coverage / auto-detect |
| `check_conversion_path(from, to)` | Check path type, coverage, ambiguous codes |
| `print_conversion_check(from, to)` | Print detailed path info to console |
| `get_crosswalk(from, to, master_data)` | Full correspondence table |
| `get_label(codes, classification, master_data)` | Official FR/NL names |
| `validate_codes(codes, classification, master_data)` | Check codes against reference set |
| `fuzzy_match_names(names, target, master_data)` | Match approximate names to codes |
| `identify_from_names(names, master_data)` | Identify classification from names |
| `register_split_weights(from, to, weights_dt, variable)` | Register split weights |
| `get_split_weights(from, to, variable)` | Retrieve registered weights |
| `list_available_conversions()` | List all supported conversion edges |
| `get_conversion_matrix()` | Full feasibility matrix |
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

## Package Structure

```
nbbbenuts/
├── R/
│   ├── 00_config.R              # Conversion graph edges, classification registry, NUTS 2027 lookup
│   ├── 01_load_data.R           # Raw file parsers
│   ├── 02_build_master_table.R  # Master table construction (build-time only)
│   ├── 03_convert.R             # Conversion routing and execution
│   ├── 04_fuzzy_match.R         # Fuzzy name matching
│   ├── 05_conversion_check.R    # BFS path checker, conversion matrix
│   ├── 06_visualize.R           # Visualization utilities
│   ├── 07_dataset_convert.R     # convert_dataset(), split_ambiguous(), diagnose_classification()
│   ├── 07_detect.R              # Auto-detection of classification from codes
│   ├── 07_diagnose.R            # Diagnostics
│   ├── 07_split_ambiguous.R     # Weighted M:N split engine
│   ├── 08_load_prebuilt.R       # load_master_data(), rebuild_master_data()
│   ├── 09_query.R               # get_crosswalk(), get_label(), validate_codes()
│   ├── 10_rebase.R              # rebase_series()
│   ├── classifications.R        # Reference documentation for all classification identifiers
│   └── registry.R               # CLASSIFICATION_NODES (23-entry single source of truth)
├── inst/extdata/                # Pre-built RDS snapshot (communes, postal, nis_changes)
├── data/raw/                    # Source files (not versioned)
└── tests/testthat/              # 680 automated tests
```

## Testing

```r
devtools::test()    # 680 tests — FAIL 0 | WARN 0 | SKIP 0
devtools::check()   # 0 errors | 0 warnings | 0 notes
```
