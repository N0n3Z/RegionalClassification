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


# --- Classification Registry ---
# Defines all known classification systems, their versions, and levels.
CLASSIFICATION_REGISTRY <- list(
  NIS = list(
    description = "Nomenclature INS/NIS (Institut National de Statistique)",
    versions = c("BEFORE_2019", "2019", "2025"),
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
  REFNIS_BEFORE_2019 = list(
    filename = "REFNIS_BEFORE_2019.xls",
    description = "Reference NIS BEFORE_2019 - communes pre-2019 fusion",
    sheet = "REFNIS",
    provides = c("NIS_BEFORE_2019"),
    filter = NULL
  ),
  REFNIS_CHANGE_BEFORE2019 = list(
    filename = "REFNIS_CHANGE_BEFORE2019.xlsx",
    description = "Changes between NIS BEFORE_2019 and NIS 2019",
    sheet = NULL,
    provides = c("NIS_BEFORE_2019", "NIS_2019"),
    filter = NULL,
    col_nis_old = "CD_REFNIS_OLD",
    col_nis_new = "CD_REFNIS_NEW"
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
  ),

  CONVERSION_NIS2025_NUTS2027 = list(
    filename    = "REFNIS_2025-NUTS_2027.xlsx",
    description = "NIS 2025 communes mapped to NUTS 2027 -- same hierarchical format as CONVERSION_NIS2019_NUTS2021.xlsx",
    sheet       = NULL,
    provides    = c("NIS_2025", "NUTS_2027"),
    filter      = NULL
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
  # --- Within NIS BEFORE_2019 hierarchy ---
  list(from = "NIS_COMMUNE_BEFORE_2019", to = "NIS_ARRONDISSEMENT_BEFORE_2019",
       relation = "N:1", via = "hierarchy",
       notes = "Derived from commune code: first 2 digits * 1000"),
  list(from = "NIS_ARRONDISSEMENT_BEFORE_2019", to = "NIS_PROVINCE_BEFORE_2019",
       relation = "N:1", via = "hierarchy",
       notes = "Derived from REFNIS hierarchy"),
  list(from = "NIS_PROVINCE_BEFORE_2019", to = "NIS_REGION_BEFORE_2019",
       relation = "N:1", via = "hierarchy",
       notes = "Derived from REFNIS hierarchy"),

  # --- NIS BEFORE_2019 to NUTS 2021 (pre-2019 assignments) ---
  list(from = "NIS_COMMUNE_BEFORE_2019", to = "NUTS3_2021",
       relation = "1:1", via = "CONVERSION_NIS2019_NUTS2021",
       notes = "Uses historical NUTS assignments (DT_VLDT_STOP = 2019-01-01 for changed codes)"),
  list(from = "NIS_COMMUNE_BEFORE_2019", to = "NUTS3_2027",
       relation = "1:1", via = "derived",
       notes = "Via NIS_COMMUNE_BEFORE_2019 -> NUTS3_2021 -> NUTS3_2027"),

  # --- NIS BEFORE_2019 -> NIS 2019 (requires REFNIS_CHANGE_BEFORE2019.xlsx for merged communes) ---
  list(from = "NIS_COMMUNE_BEFORE_2019", to = "NIS_COMMUNE_2019",
       relation = "M:N", via = "REFNIS_CHANGE_BEFORE2019",
       notes = paste0(
         "Unchanged communes: 1:1 (same code). ",
         "Merged communes resolved via REFNIS_CHANGE_BEFORE2019.xlsx."
       )),

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
       )),

  # --- NUTS 2021 <-> NUTS 2027 ---
  list(from = "NUTS3_2021", to = "NUTS3_2027",
       relation = "1:1", via = "derived",
       notes = paste0(
         "Direct 1:1 remapping per EU regulation 2026/195. Changed: ",
         "Antwerpen BE21x->BE26x, Oost-Vlaanderen BE23x->BE27x, ",
         "Limburg BE223->BE226 and BE224->BE227."
       )),
  list(from = "NUTS3_2027", to = "NUTS2_2027",
       relation = "N:1", via = "derived",
       notes = "Hierarchical (first 4 chars of NUTS3 2027 code)"),
  list(from = "NUTS2_2027", to = "NUTS1_2027",
       relation = "N:1", via = "derived",
       notes = "Hierarchical"),
  list(from = "NUTS1_2027", to = "NUTS0",
       relation = "N:1", via = "derived",
       notes = "Hierarchical"),
  list(from = "NIS_COMMUNE_2019", to = "NUTS3_2027",
       relation = "1:1", via = "derived",
       notes = "Via NUTS 2021: NIS_COMMUNE_2019 -> NUTS3_2021 -> NUTS3_2027"),
  list(from = "NUTS3_2027", to = "INTERNAL_ARRONDISSEMENT",
       relation = "1:1", via = "derived",
       notes = "Via NUTS 2021: NUTS3_2027 -> NUTS3_2021 -> INTERNAL_ARRONDISSEMENT"),
  list(from = "POSTAL", to = "NUTS3_2027",
       relation = "N:1", via = "derived",
       notes = "Via POSTAL -> NIS_COMMUNE_2019 -> NUTS3_2027"),

  # --- NIS 2025 -> NUTS 2027 ---
  list(from = "NIS_COMMUNE_2025", to = "NUTS3_2027",
       relation = "N:1", via = "CONVERSION_NIS2025_NUTS2027",
       notes = "Direct mapping via REFNIS_2025-NUTS_2027.xlsx (hierarchical format)."),
  list(from = "NIS_COMMUNE_2025", to = "NUTS2_2027",
       relation = "N:1", via = "CONVERSION_NIS2025_NUTS2027",
       notes = "Via NIS_COMMUNE_2025 -> NUTS3_2027 -> NUTS2_2027"),
  list(from = "NIS_COMMUNE_2025", to = "NUTS1_2027",
       relation = "N:1", via = "CONVERSION_NIS2025_NUTS2027",
       notes = "Via NIS_COMMUNE_2025 -> NUTS3_2027 -> NUTS1_2027")
)

# --- Belgian NIS Administrative Code Constants ---
# These structural codes are defined by Belgian law / Statbel and do not change
# between NIS versions (regions and provinces predate the 2019/2025 commune fusions).
# All build logic in 01_load_data.R and 02_build_master_table.R uses these names.
# Never scatter these literals through the codebase — reference this block instead.

NIS_REGION_FLEMISH  <- 2000L
NIS_REGION_WALLOON  <- 3000L
NIS_REGION_BRUSSELS <- 4000L

NIS_PROVINCE_BRABANT    <- 20000L  # Spans all 3 regions; split by arrondissement

NIS_ARR_BRUSSELS        <- 21000L  # Brussels-Capital arrondissement  -> Brussels region
NIS_ARR_HAL_VILVORDE    <- 23000L  # Hal-Vilvorde                     -> Flemish region
NIS_ARR_LOUVAIN         <- 24000L  # Louvain (Leuven)                 -> Flemish region
NIS_ARR_NIVELLES        <- 25000L  # Nivelles                         -> Walloon  region

# Province first-digit (cd_province %/% 10000) -> NIS region code.
# Brabant (digit 2) is NA because province 20000 spans three regions;
# region is resolved commune-by-commune via arrondissement (see 02_build_master_table.R).
NIS_PROV_DIGIT_TO_REGION <- c(
  "1" = 2000L,        # Antwerp      -> Flemish
  "2" = NA_integer_,  # Brabant      -> split (resolved by arrondissement)
  "3" = 2000L,        # East Flanders-> Flemish  (province code 30000... wait, 3x000)
  "4" = 2000L,        # West Flanders-> Flemish
  "5" = 3000L,        # Hainaut      -> Walloon
  "6" = 3000L,        # Liege        -> Walloon
  "7" = 2000L,        # Limburg      -> Flemish
  "8" = 3000L,        # Luxembourg   -> Walloon
  "9" = 3000L         # Namur        -> Walloon
)

# --- Flat tables persisted in inst/extdata/ ---
# Three unified tables replace the previous 13 separate tables.
# Each is keyed by a version discriminator column (nis_version / from_version).
# Hierarchy lists (nis_hierarchy_*, nuts_hierarchy_*, nuts_arrondissement_mapping)
# are intentionally excluded: they are build-time intermediates not needed at runtime.
MASTER_FLAT_TABLES <- c(
  "communes",    # all NIS versions (2019, 2025, BEFORE_2019) with NUTS 2021/2027 columns
  "postal",      # postal -> NIS mappings for all versions (nis_version discriminator)
  "nis_changes"  # NIS version transitions: 2019->2025 and BEFORE_2019->2019 (from_version)
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
    return(here::here("inst", "extdata"))
  }
  return(file.path("inst", "extdata"))
}

# --- NUTS 2021 -> NUTS 2027 mapping ---
# Source: EU Regulation 2026/195 (JO L 27.1.2026), applicable from 1 January 2027.
# Only changed codes are listed; all others remain identical between versions.
NUTS2021_TO_NUTS2027 <- data.table::data.table(
  nuts_2021 = c(
    # NUTS2 changes
    "BE21", "BE23",
    # NUTS3: Antwerpen (BE21 -> BE26)
    "BE211", "BE212", "BE213",
    # NUTS3: Limburg (partial renumbering)
    "BE223", "BE224",
    # NUTS3: Oost-Vlaanderen (BE23 -> BE27)
    "BE231", "BE232", "BE233", "BE234", "BE235", "BE236"
  ),
  nuts_2027 = c(
    "BE26", "BE27",
    "BE261", "BE262", "BE263",
    "BE226", "BE227",
    "BE271", "BE272", "BE273", "BE274", "BE275", "BE276"
  )
)
