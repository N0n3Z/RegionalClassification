# ==============================================================================
# 00_config.R - Package configuration and classification metadata
# ==============================================================================
# This file contains the minimal hardcoded definitions that CANNOT be derived
# from the input data files. Each hardcoded element is justified below.
#
# JUSTIFICATION FOR HARDCODED ELEMENTS:
# 1. CLASSIFICATION_REGISTRY: Defines the known classification systems and their
#    versions. This is metadata about what classifications exist - it cannot be
#    inferred from the data files themselves since the files don't self-describe
#    which classification system they belong to.
# 2. FILE_MAPPING: Maps input filenames to their role in the system. The files
#    don't contain metadata about their purpose.
# 3. CONVERSION_GRAPH_EDGES: Defines which conversions are theoretically possible.
#    While some can be inferred, the complete graph topology is knowledge about
#    the classification system design.
# ==============================================================================

library(data.table)

# --- Classification Registry ---
# Defines all known classification systems, their versions, and levels.
CLASSIFICATION_REGISTRY <- list(
  NIS = list(
    description = "Nomenclature INS/NIS (Institut National de Statistique)",
    versions = c("2019", "2025"),
    levels = c("commune", "arrondissement", "province", "region", "pays"),
    source = "Statbel"
  ),
  NUTS = list(
    description = "Nomenclature des unites territoriales statistiques (Eurostat)",
    versions = c("2021", "2027"),
    levels = c("NUTS0", "NUTS1", "NUTS2", "NUTS3", "LAU"),
    source = "Eurostat / EU regulation"
  ),
  POSTAL = list(
    description = "Codes postaux belges",
    versions = c("current"),
    levels = c("postal"),
    source = "bpost"
  ),
  INTERNAL = list(
    description = paste0(
      "Classification interne basee sur NIS arrondissement (2 chiffres). ",
      "Verviers est splitte: 65 = francophone, 66 = germanophone."
    ),
    versions = c("current"),
    levels = c("arrondissement"),
    source = "Interne"
  )
)

# --- File Mapping ---
# Maps raw data filenames to their role. Allows adding new files without
# changing the loading logic.
FILE_MAPPING <- list(
  CONVERSION_NIS2019_NUTS2021 = list(
    filename = "CONVERSION_NIS2019_NUTS2021.xlsx",
    description = "NIS 2019 communes mapped to NUTS 2021 hierarchy",
    sheet = "TU_COM_NUTS_LAU-20190101",
    provides = c("NIS_2019", "NUTS_2021"),
    filter = NULL
  ),
  CONVERSION_POSTAL_NIS2019 = list(
    filename = "CONVERSION_POSTAL_NIS2019.xlsx",
    description = "Postal codes to NIS 2019 communes",
    sheet = NULL,
    provides = c("POSTAL", "NIS_2019"),
    filter = list(column = "KEEP_UNIQUE", value = TRUE)
  ),
  CONVERSION_POSTAL_NIS2025 = list(
    filename = "CONVERSION_POSTAL_NIS2025.xlsx",
    description = "Postal codes to NIS 2025 communes",
    sheet = NULL,
    provides = c("POSTAL", "NIS_2025"),
    filter = list(column = "KEEP_UNIQUE", value = TRUE)
  ),
  REFNIS_2019 = list(
    filename = "REFNIS_2019.xls",
    description = "Reference NIS 2019 - all entities",
    sheet = "REFNIS",
    provides = c("NIS_2019"),
    filter = NULL
  ),
  REFNIS_2025 = list(
    filename = "REFNIS_2025.xlsx",
    description = "Reference NIS 2025 - all entities",
    sheet = "REFNIS",
    provides = c("NIS_2025"),
    filter = NULL
  ),
  REFNIS_CHANGE = list(
    filename = "REFNIS_CHANGE_2025.xlsx",
    description = "Changes between NIS 2019 and NIS 2025",
    sheet = "overview",
    provides = c("NIS_2019", "NIS_2025"),
    filter = NULL
  ),
  NUTS_ARRONDISSEMENT = list(
    filename = "NUTS_ARRONDISSEMENT.csv",
    description = "NUTS3 to internal arrondissement code mapping",
    sheet = NULL,
    provides = c("NUTS", "INTERNAL"),
    filter = NULL
  )
)

# --- Conversion Graph Edges ---
# Defines the possible conversion paths between classification nodes.
# Each edge has:
#   - from/to: classification node identifiers (SYSTEM_LEVEL_VERSION)
#   - relation: "1:1", "N:1", "1:N", or "M:N"
#   - via: which reference table(s) enable this conversion
#   - notes: explanation of the relationship
#
# Edges with relation "M:N" indicate that simple (direct) conversion is NOT
# possible without additional assumptions or data splitting.
CONVERSION_GRAPH_EDGES <- list(
  # --- Within NIS 2019 hierarchy ---
  list(from = "NIS_COMMUNE_2019", to = "NIS_ARRONDISSEMENT_2019",
       relation = "N:1", via = "hierarchy",
       notes = "Derived from commune code: first 2 digits * 1000"),
  list(from = "NIS_ARRONDISSEMENT_2019", to = "NIS_PROVINCE_2019",
       relation = "N:1", via = "hierarchy",
       notes = "Derived from REFNIS hierarchy"),
  list(from = "NIS_PROVINCE_2019", to = "NIS_REGION_2019",
       relation = "N:1", via = "hierarchy",
       notes = "Derived from REFNIS hierarchy"),

  # --- Within NIS 2025 hierarchy ---
  list(from = "NIS_COMMUNE_2025", to = "NIS_ARRONDISSEMENT_2025",
       relation = "N:1", via = "hierarchy",
       notes = "Derived from commune code: first 2 digits * 1000"),
  list(from = "NIS_ARRONDISSEMENT_2025", to = "NIS_PROVINCE_2025",
       relation = "N:1", via = "hierarchy",
       notes = "Derived from REFNIS hierarchy"),
  list(from = "NIS_PROVINCE_2025", to = "NIS_REGION_2025",
       relation = "N:1", via = "hierarchy",
       notes = "Derived from REFNIS hierarchy"),

  # --- NIS 2019 to NUTS 2021 ---
  list(from = "NIS_COMMUNE_2019", to = "NUTS_LAU_2021",
       relation = "1:1", via = "CONVERSION_NIS2019_NUTS2021",
       notes = "Direct 1:1 mapping from CONVERSION file"),
  list(from = "NUTS_LAU_2021", to = "NUTS3_2021",
       relation = "N:1", via = "CONVERSION_NIS2019_NUTS2021",
       notes = "LAU to NUTS3 from CD_LVL_SUP hierarchy"),
  list(from = "NUTS3_2021", to = "NUTS2_2021",
       relation = "N:1", via = "CONVERSION_NIS2019_NUTS2021",
       notes = "Hierarchical"),
  list(from = "NUTS2_2021", to = "NUTS1_2021",
       relation = "N:1", via = "CONVERSION_NIS2019_NUTS2021",
       notes = "Hierarchical"),
  list(from = "NUTS1_2021", to = "NUTS0",
       relation = "N:1", via = "CONVERSION_NIS2019_NUTS2021",
       notes = "Hierarchical"),

  # --- NIS arrondissement to NUTS3 (problematic!) ---
  list(from = "NIS_ARRONDISSEMENT_2019", to = "NUTS3_2021",
       relation = "M:N", via = "CONVERSION_NIS2019_NUTS2021",
       notes = paste0(
         "NOT a simple 1:1 mapping! NIS arrondissement 63000 (Verviers) maps to ",
         "both BE335 (francophone) and BE336 (germanophone) in NUTS 2021. ",
         "All other arrondissements have a 1:1 relationship."
       )),

  # --- Postal to NIS ---
  list(from = "POSTAL", to = "NIS_COMMUNE_2019",
       relation = "N:1", via = "CONVERSION_POSTAL_NIS2019",
       notes = "Each postal code maps to one commune (KEEP_UNIQUE=TRUE)"),
  list(from = "POSTAL", to = "NIS_COMMUNE_2025",
       relation = "N:1", via = "CONVERSION_POSTAL_NIS2025",
       notes = "Each postal code maps to one commune (KEEP_UNIQUE=TRUE)"),

  # --- NIS version changes ---
  list(from = "NIS_COMMUNE_2019", to = "NIS_COMMUNE_2025",
       relation = "M:N", via = "REFNIS_CHANGE",
       notes = paste0(
         "Fusions, district changes, and province changes between 2019 and 2025. ",
         "Multiple 2019 communes may merge into one 2025 commune (FUSION). ",
         "Some communes change arrondissement (CHANGE_DSTR) or province (CHANGE_PROV)."
       )),

  # --- NUTS3 to Internal arrondissement ---
  list(from = "NUTS3_2021", to = "INTERNAL_ARRONDISSEMENT",
       relation = "1:1", via = "NUTS_ARRONDISSEMENT",
       notes = paste0(
         "Direct mapping from NUTS3 to internal 2-digit code. ",
         "Verviers is split: BE335->65 (FR), BE336->66 (DE)."
       )),

  # --- NIS arrondissement to Internal (special case) ---
  list(from = "NIS_ARRONDISSEMENT_2019", to = "INTERNAL_ARRONDISSEMENT",
       relation = "M:N", via = "derived",
       notes = paste0(
         "Generally first 2 digits of NIS arrondissement = internal code, ",
         "EXCEPT for Verviers: NIS 63000 -> internal 65 (FR) + 66 (DE)."
       ))
)

# --- Helper: get data directory path ---
get_raw_data_path <- function() {
  if (requireNamespace("here", quietly = TRUE)) {
    return(here::here("data", "raw"))
  }
  return(file.path("data", "raw"))
}

get_processed_data_path <- function() {
  if (requireNamespace("here", quietly = TRUE)) {
    return(here::here("data", "processed"))
  }
  return(file.path("data", "processed"))
}
