# nbbbenuts

R package for converting between Belgian geographic classification systems.

## Overview

Belgian administrative data uses multiple overlapping classification systems that change over time. This package provides a unified interface to convert between them — including historical versions.

**Supported classifications:**

| Identifier | Description |
|---|---|
| `NIS_COMMUNE_BEFORE_2019` | NIS communes before the 2019 revision (591 communes) |
| `NIS_COMMUNE_2019` | NIS communes 2019 revision (583 communes) |
| `NIS_COMMUNE_2025` | NIS communes 2025 revision (567 communes) |
| `NIS_ARRONDISSEMENT_2019` / `_2025` | NIS arrondissements |
| `NIS_PROVINCE_2019` / `_2025` | NIS provinces |
| `NIS_REGION_2019` / `_2025` | NIS regions (Brussels, Wallonia, Flanders) |
| `NUTS3_2021` / `NUTS3_2027` | NUTS level 3 (EU regulation) |
| `NUTS2_2021` / `NUTS2_2027` | NUTS level 2 |
| `NUTS1_2021` / `NUTS1_2027` | NUTS level 1 |
| `NUTS_LAU_2021` | Local Administrative Unit (LAU) |
| `POSTAL` | Belgian postal codes |
| `INTERNAL_ARRONDISSEMENT` | Internal arrondissement codes |

## Quick Start

```r
source("main.R")

# Convert NIS communes (2019) to NUTS3 (2021)
convert_codes(c(21001L, 11002L, 62063L), "NIS_COMMUNE_2019", "NUTS3_2021", master_data)

# Convert postal codes to NIS communes
convert_codes(c(1000L, 2000L, 4000L), "POSTAL", "NIS_COMMUNE_2019", master_data)

# Convert to NUTS 2027 (EU regulation 2026/195)
convert_codes(c(21004L, 11002L, 44021L), "NIS_COMMUNE_2019", "NUTS3_2027", master_data)

# Use pre-2019 historical communes
convert_codes(c(55022L, 56011L), "NIS_COMMUNE_BEFORE_2019", "NIS_COMMUNE_2019", master_data)

# Fuzzy name matching
fuzzy_match_names(c("Bruxeles", "Anvers", "Liege"), "NIS_COMMUNE_2019", master_data)
```

## Installation

### Prerequisites

```r
# Required for normal use
install.packages(c("data.table", "here"))

# Required only for rebuild_master_data()
install.packages(c("readxl", "stringdist"))
```

### Normal use — no raw files needed

The package ships with a pre-built snapshot in `inst/extdata/`. Simply run:

```r
source("main.R")   # loads from inst/extdata/ in milliseconds
```

### Rebuilding the snapshot

Only needed if the raw source files change. Place the files below in `data/raw/`, then call `rebuild_master_data()`.

| File | Description |
|---|---|
| `REFNIS_2019.xls` | NIS commune reference 2019 |
| `REFNIS_2025.xlsx` | NIS commune reference 2025 |
| `REFNIS_BEFORE_2019.xls` | NIS commune reference pre-2019 |
| `REFNIS_CHANGE_2025.xlsx` | NIS 2019 → 2025 fusion table |
| `REFNIS_CHANGE_BEFORE2019.xlsx` | NIS BEFORE_2019 → 2019 change table |
| `CONVERSION_NIS2019_NUTS2021.xlsx` | NIS 2019 → NUTS 2021 mapping |
| `REFNIS_2025-NUTS_2027.xlsx` | NIS 2025 → NUTS 2027 mapping |
| `CONVERSION_POSTAL_NIS2019.xlsx` | Postal → NIS 2019 mapping |
| `CONVERSION_POSTAL_NIS2025.xlsx` | Postal → NIS 2025 mapping |
| `NUTS_ARRONDISSEMENT.csv` | NUTS ↔ internal arrondissement codes |

## NIS Versions

Belgian communes are reorganized periodically through mergers and district transfers.

```
BEFORE_2019  --[REFNIS_CHANGE_BEFORE2019]--> 2019 --[REFNIS_CHANGE_2025]--> 2025
   589 communes                               583                             567
```

## NUTS 2027

NUTS 2027 codes are sourced from the official Statbel file `REFNIS_2025-NUTS_2027.xlsx` for NIS 2025 communes. For NIS 2019 and BEFORE_2019 communes, NUTS 2027 is derived by remapping NUTS 2021 codes according to EU regulation 2026/195. Key changes for Belgium:

| NUTS 2021 | NUTS 2027 | Province |
|---|---|---|
| BE21x | BE26x | Antwerpen |
| BE22x | BE22x / BE26x | Vlaams-Brabant (partial) |
| BE23x | BE27x | Oost/West-Vlaanderen |
| BE32x | BE32x | Hainaut (unchanged) |

## Key Features

### Ambiguous conversions

Some conversions are M:N by nature (e.g. arrondissement Verviers spans two NUTS3 regions). The package handles this explicitly:

```r
# Will raise an error — Verviers is ambiguous
convert_codes(63000L, "NIS_ARRONDISSEMENT_2019", "NUTS3_2021", master_data)

# Returns all possible mappings
convert_codes(63000L, "NIS_ARRONDISSEMENT_2019", "NUTS3_2021", master_data,
              allow_ambiguous = TRUE)

# Check whether a conversion is simple before converting
check_conversion_path("NIS_ARRONDISSEMENT_2019", "NUTS3_2021")
```

### Fuzzy name matching

```r
# Match approximate names to codes
fuzzy_match_names(c("Bruxeles", "Antwerpn", "Vervirs"), "NIS_COMMUNE_2019",
                  master_data, max_dist = 0.3, language = "both")
```

## Available Functions

| Function | Description |
|---|---|
| `convert_codes(codes, from, to, master_data)` | Convert codes between classifications |
| `convert_dataset(dt, code_col, to, master_data)` | Convert a column in a dataset (auto-detects source) |
| `split_ambiguous(dt, code_col, value_cols, from, to, master_data)` | Weighted split for M:N conversions (e.g. Verviers) |
| `diagnose_classification(dt, code_col, master_data)` | Diagnose coverage or auto-detect classification |
| `register_split_weights(from, to, weights_dt, variable)` | Register population/employment weights |
| `check_conversion_path(from, to)` | Check if a conversion is direct/ambiguous |
| `print_conversion_check(from, to)` | Print detailed path info |
| `fuzzy_match_names(names, target, master_data)` | Match names to codes |
| `identify_from_names(names, master_data)` | Identify classification from names |
| `list_available_conversions()` | List all supported conversion routes |
| `visualize_classification_graph()` | Graph of all classification relationships |
| `visualize_conversion_matrix()` | Matrix view of supported conversions |

## Structure

```
nbbbenuts/
├── main.R                       # Entry point (loads from inst/extdata/ by default)
├── R/
│   ├── 00_config.R              # Classification registry, file mappings, NUTS 2027 lookup
│   ├── 01_load_data.R           # Data loading and parsing functions
│   ├── 02_build_master_table.R  # Master table construction + save_master_tables()
│   ├── 03_convert.R             # Conversion routing and execution
│   ├── 04_fuzzy_match.R         # Fuzzy name matching
│   ├── 05_conversion_check.R    # Conversion path checker
│   ├── 06_visualize.R           # Visualization utilities
│   ├── 07_dataset_convert.R     # convert_dataset(), split_ambiguous(), diagnose_classification()
│   └── 08_load_prebuilt.R       # load_master_data(), rebuild_master_data()
├── inst/
│   └── extdata/                 # Pre-built RDS snapshot: communes.rds, postal.rds, nis_changes.rds
├── data/
│   └── raw/                     # Source data files (not versioned)
├── tests/
│   ├── test_conversions.R       # 13 automated conversion tests
│   └── test_template.R          # Template for user-defined tests
└── vignettes/
    ├── introduction.Rmd         # Detailed usage guide
    ├── conversions.Rmd          # Conversion examples
    ├── ambiguous-splits.Rmd     # Handling M:N conversions
    └── diagnostics.Rmd          # Diagnostic and auto-detection
```
