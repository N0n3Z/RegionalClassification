# RegionalClassification

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
install.packages(c("data.table", "readxl", "here", "stringdist"))
```

### Data files

Place the following files in `data/raw/`:

| File | Description | Required |
|---|---|---|
| `REFNIS_2019.xls` | NIS commune reference 2019 | Yes |
| `REFNIS_2025.xlsx` | NIS commune reference 2025 | Yes |
| `REFNIS_BEFORE_2019.xls` | NIS commune reference pre-2019 | Yes |
| `CONVERSION_NIS2019_NUTS2021.xlsx` | NIS 2019 → NUTS 2021 mapping | Yes |
| `CONVERSION_POSTAL_NIS2019.xlsx` | Postal → NIS 2019 mapping | Yes |
| `CONVERSION_POSTAL_NIS2025.xlsx` | Postal → NIS 2025 mapping | Yes |
| `NUTS_ARRONDISSEMENT.csv` | NUTS ↔ internal arrondissement codes | Yes |
| `REFNIS_CHANGE_2025.xlsx` | NIS 2019 → 2025 fusion table | Yes |
| `REFNIS_CHANGE_BEFORE2019.xlsx` | NIS BEFORE_2019 → 2019 change table | Yes |
| `CONVERSION_NIS2025_NUTS2027.xlsx` | NIS 2025 → NUTS 2027 mapping | No (pending) |

## NIS Versions

Belgian communes are reorganized periodically through mergers and district transfers.

```
BEFORE_2019  --[REFNIS_CHANGE_BEFORE2019]--> 2019 --[REFNIS_CHANGE_2025]--> 2025
   591 communes                               583                             567
```

## NUTS 2027

NUTS 2027 codes are derived from NUTS 2021 according to EU regulation 2026/195. Key changes for Belgium:

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
| `check_conversion_path(from, to)` | Check if a conversion is direct/ambiguous |
| `print_conversion_check(from, to)` | Print detailed path info |
| `fuzzy_match_names(names, target, master_data)` | Match names to codes |
| `identify_from_names(names, master_data)` | Identify classification from names |
| `list_available_conversions()` | List all supported conversion routes |
| `visualize_classification_graph()` | Graph of all classification relationships |
| `visualize_conversion_matrix()` | Matrix view of supported conversions |

## Structure

```
RegionalClassification/
├── main.R                    # Entry point
├── R/
│   ├── 00_config.R           # Classification registry, file mappings, NUTS 2027 lookup
│   ├── 01_load_data.R        # Data loading and parsing functions
│   ├── 02_build_master_table.R  # Master table construction
│   ├── 03_convert.R          # Conversion routing and execution
│   ├── 04_fuzzy_match.R      # Fuzzy name matching
│   ├── 05_conversion_check.R # Conversion path checker
│   └── 06_visualize.R        # Visualization utilities
├── data/
│   └── raw/                  # Source data files (not versioned)
├── tests/
│   └── test_conversions.R    # 11 conversion tests
└── vignettes/
    └── introduction.Rmd      # Detailed usage guide
```
