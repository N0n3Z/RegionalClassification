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


# ==============================================================================
# Classification identifier constants
# Single source of truth for every classification id and version string used
# across the package.  Changing a name here propagates everywhere; a typo is
# caught at load time (object-not-found) rather than silently at runtime.
#
# Naming:
#   CLS_*  -- classification node identifiers (match names(CLASSIFICATION_NODES))
#   VER_*  -- version strings stored in data columns (nis_version, from_version)
# ==============================================================================

# --- Version strings ---
VER_BEFORE_2019 <- "BEFORE_2019"
VER_2019        <- "2019"
VER_2025        <- "2025"
VER_NUTS_2021   <- "2021"
VER_NUTS_2027   <- "2027"

# --- NIS BEFORE_2019 ---
CLS_NIS_MUNICIPALITY_BEFORE_2019        <- "NIS_MUNICIPALITY_BEFORE_2019"
CLS_NIS_DISTRICT_BEFORE_2019 <- "NIS_DISTRICT_BEFORE_2019"
CLS_NIS_PROVINCE_BEFORE_2019       <- "NIS_PROVINCE_BEFORE_2019"
CLS_NIS_REGION_BEFORE_2019         <- "NIS_REGION_BEFORE_2019"
# --- NIS 2019 ---
CLS_NIS_MUNICIPALITY_2019               <- "NIS_MUNICIPALITY_2019"
CLS_NIS_DISTRICT_2019        <- "NIS_DISTRICT_2019"
CLS_NIS_PROVINCE_2019              <- "NIS_PROVINCE_2019"
CLS_NIS_REGION_2019                <- "NIS_REGION_2019"
# --- NIS 2025 ---
CLS_NIS_MUNICIPALITY_2025               <- "NIS_MUNICIPALITY_2025"
CLS_NIS_DISTRICT_2025        <- "NIS_DISTRICT_2025"
CLS_NIS_PROVINCE_2025              <- "NIS_PROVINCE_2025"
CLS_NIS_REGION_2025                <- "NIS_REGION_2025"
# --- NUTS 2021 ---
CLS_NUTS_MUNICIPALITY_2021         <- "NUTS_MUNICIPALITY_2021"
CLS_NUTS_DISTRICT_2021                     <- "NUTS_DISTRICT_2021"
CLS_NUTS_PROVINCE_2021                     <- "NUTS_PROVINCE_2021"
CLS_NUTS_REGION_2021                     <- "NUTS_REGION_2021"
CLS_NUTS_COUNTRY                          <- "NUTS_COUNTRY"
# --- NUTS 2027 ---
CLS_NUTS_DISTRICT_2027                     <- "NUTS_DISTRICT_2027"
CLS_NUTS_PROVINCE_2027                     <- "NUTS_PROVINCE_2027"
CLS_NUTS_REGION_2027                     <- "NUTS_REGION_2027"
# --- Other ---
CLS_NIS_COUNTRY                    <- "NIS_COUNTRY"
CLS_POSTAL                         <- "POSTAL"
CLS_NBB_DISTRICT_2021        <- "NBB_DISTRICT_2021"

# All 23 classification ids -- used by test-name-constants.R
CLS_ALL <- c(
  CLS_NIS_MUNICIPALITY_BEFORE_2019, CLS_NIS_DISTRICT_BEFORE_2019,
  CLS_NIS_PROVINCE_BEFORE_2019, CLS_NIS_REGION_BEFORE_2019,
  CLS_NIS_MUNICIPALITY_2019, CLS_NIS_DISTRICT_2019,
  CLS_NIS_PROVINCE_2019, CLS_NIS_REGION_2019,
  CLS_NIS_MUNICIPALITY_2025, CLS_NIS_DISTRICT_2025,
  CLS_NIS_PROVINCE_2025, CLS_NIS_REGION_2025,
  CLS_NIS_COUNTRY,
  CLS_NUTS_MUNICIPALITY_2021, CLS_NUTS_DISTRICT_2021, CLS_NUTS_PROVINCE_2021,
  CLS_NUTS_REGION_2021, CLS_NUTS_COUNTRY,
  CLS_NUTS_DISTRICT_2027, CLS_NUTS_PROVINCE_2027, CLS_NUTS_REGION_2027,
  CLS_POSTAL, CLS_NBB_DISTRICT_2021
)

# --- Classification Registry ---
# Defines all known classification systems, their versions, and levels.
CLASSIFICATION_REGISTRY <- list(
  NIS = list(
    description = "Nomenclature INS/NIS (Institut National de Statistique)",
    versions = c("BEFORE_2019", "2019", "2025"),
    levels = c("municipality", "district", "province", "region", "country"),
    source = "Statbel"
  ),
  NUTS = list(
    description = "Nomenclature des unites territoriales statistiques (Eurostat)",
    versions = c("2021", "2027"),
    levels = c("country", "region", "province", "district", "municipality"),
    source = "Eurostat / EU regulation"
  ),
  POSTAL = list(
    description = "Codes postaux belges",
    versions = c("current"),
    levels = c("postal"),
    source = "bpost"
  ),
  NBB = list(
    description = paste0(
      "Classification interne NBB basee sur NIS arrondissement (2 chiffres). ",
      "Verviers est splitte: 65 = francophone, 66 = germanophone."
    ),
    versions = c("2021"),
    levels = c("district"),
    source = "NBB interne"
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
    provides = c("NUTS", "NBB"),
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
  list(from = CLS_NIS_MUNICIPALITY_BEFORE_2019, to = CLS_NIS_DISTRICT_BEFORE_2019,
       relation = "N:1", via = "hierarchy",
       notes = "Derived from commune code: first 2 digits * 1000"),
  # Direct commune->region edge (N:1): every commune, including Brabant communes,
  # belongs to exactly one region.  Without this direct edge the BFS would find
  # the path via province->region which is M:N due to Brabant.
  list(from = CLS_NIS_MUNICIPALITY_BEFORE_2019, to = CLS_NIS_REGION_BEFORE_2019,
       relation = "N:1", via = "hierarchy",
       notes = "Each commune belongs to exactly one region (N:1, direct column lookup)."),
  list(from = CLS_NIS_DISTRICT_BEFORE_2019, to = CLS_NIS_PROVINCE_BEFORE_2019,
       relation = "N:1", via = "hierarchy",
       notes = "Derived from REFNIS hierarchy"),
  # Province 20000 (Brabant) spans Brussels, Flemish, and Walloon regions => M:N.
  # Every other province maps 1:1 to its region, but the M:N declaration is
  # required to surface the Brabant ambiguity.  Use commune-level paths instead.
  list(from = CLS_NIS_PROVINCE_BEFORE_2019, to = CLS_NIS_REGION_BEFORE_2019,
       relation = "M:N", via = "hierarchy",
       notes = paste0("Province 20000 (Brabant) maps to 3 regions (Brussels/Flemish/Walloon). ",
                      "All other provinces are N:1.  Prefer commune-level paths.")),

  # --- NIS BEFORE_2019 to NUTS 2021 (pre-2019 assignments) ---
  list(from = CLS_NIS_MUNICIPALITY_BEFORE_2019, to = CLS_NUTS_DISTRICT_2021,
       relation = "N:1", via = "CONVERSION_NIS2019_NUTS2021",
       notes = paste0(
         "Many communes share one NUTS3 (N:1); the reverse NUTS3 -> commune is ",
         "ambiguous. Uses historical NUTS assignments (DT_VLDT_STOP = 2019-01-01 ",
         "for changed codes)."
       )),
  list(from = CLS_NIS_MUNICIPALITY_BEFORE_2019, to = CLS_NUTS_DISTRICT_2027,
       relation = "N:1", via = "derived",
       notes = paste0("N:1 (same as BEFORE_2019->NUTS_DISTRICT_2021). ",
                      "Path: NIS_MUNICIPALITY_BEFORE_2019 -> NIS_MUNICIPALITY_2019 -> NIS_MUNICIPALITY_2025 -> NUTS_DISTRICT_2027. ",
                      "Uses the official REFNIS_2025-NUTS_2027 mapping, not a code-rename table.")),

  # --- NIS BEFORE_2019 -> NIS 2019 ---
  # Forward N:1: each BEFORE_2019 commune maps to exactly one 2019 commune.
  # Belgian commune reforms only involve mergers (multiple old -> one new), never
  # splits.  Empirically confirmed: 0 old communes with multiple new codes in
  # nis_changes[from_version=="BEFORE_2019"].
  # Reverse (2019->BEFORE_2019) is auto-generated as 1:N.
  list(from = CLS_NIS_MUNICIPALITY_BEFORE_2019, to = CLS_NIS_MUNICIPALITY_2019,
       relation = "N:1", via = "REFNIS_CHANGE_BEFORE2019",
       notes = paste0(
         "Unchanged communes: 1:1 (same code). ",
         "Merged communes resolved via REFNIS_CHANGE_BEFORE2019.xlsx. ",
         "N:1 forward (no splits); reverse is 1:N (ambiguous)."
       )),

  # --- Within NIS 2019 hierarchy ---
  list(from = CLS_NIS_MUNICIPALITY_2019, to = CLS_NIS_DISTRICT_2019,
       relation = "N:1", via = "hierarchy",
       notes = "Derived from commune code: first 2 digits * 1000"),
  list(from = CLS_NIS_MUNICIPALITY_2019, to = CLS_NIS_REGION_2019,
       relation = "N:1", via = "hierarchy",
       notes = "Each commune belongs to exactly one region (N:1, direct column lookup)."),
  list(from = CLS_NIS_DISTRICT_2019, to = CLS_NIS_PROVINCE_2019,
       relation = "N:1", via = "hierarchy",
       notes = "Derived from REFNIS hierarchy"),
  list(from = CLS_NIS_PROVINCE_2019, to = CLS_NIS_REGION_2019,
       relation = "M:N", via = "hierarchy",
       notes = paste0("Province 20000 (Brabant) maps to 3 regions (Brussels/Flemish/Walloon). ",
                      "All other provinces are N:1.  Prefer commune-level paths.")),

  # --- Within NIS 2025 hierarchy ---
  list(from = CLS_NIS_MUNICIPALITY_2025, to = CLS_NIS_DISTRICT_2025,
       relation = "N:1", via = "hierarchy",
       notes = "Derived from commune code: first 2 digits * 1000"),
  list(from = CLS_NIS_MUNICIPALITY_2025, to = CLS_NIS_REGION_2025,
       relation = "N:1", via = "hierarchy",
       notes = "Each commune belongs to exactly one region (N:1, direct column lookup)."),
  list(from = CLS_NIS_DISTRICT_2025, to = CLS_NIS_PROVINCE_2025,
       relation = "N:1", via = "hierarchy",
       notes = "Derived from REFNIS hierarchy"),
  list(from = CLS_NIS_PROVINCE_2025, to = CLS_NIS_REGION_2025,
       relation = "M:N", via = "hierarchy",
       notes = paste0("Province 20000 (Brabant) maps to 3 regions (Brussels/Flemish/Walloon). ",
                      "All other provinces are N:1.  Prefer commune-level paths.")),

  # --- NIS regions to NIS_COUNTRY ---
  list(from = CLS_NIS_REGION_BEFORE_2019, to = CLS_NIS_COUNTRY,
       relation = "N:1", via = "hierarchy",
       notes = "All regions aggregate to Belgium (NIS code 1000)"),
  list(from = CLS_NIS_REGION_2019, to = CLS_NIS_COUNTRY,
       relation = "N:1", via = "hierarchy",
       notes = "All regions aggregate to Belgium (NIS code 1000)"),
  list(from = CLS_NIS_REGION_2025, to = CLS_NIS_COUNTRY,
       relation = "N:1", via = "hierarchy",
       notes = "All regions aggregate to Belgium (NIS code 1000)"),

  # --- NIS 2019 to NUTS 2021 ---
  list(from = CLS_NIS_MUNICIPALITY_2019, to = CLS_NUTS_MUNICIPALITY_2021,
       relation = "1:1", via = "CONVERSION_NIS2019_NUTS2021",
       notes = "Direct 1:1 mapping from CONVERSION file"),
  list(from = CLS_NUTS_MUNICIPALITY_2021, to = CLS_NUTS_DISTRICT_2021,
       relation = "N:1", via = "CONVERSION_NIS2019_NUTS2021",
       notes = "LAU to NUTS3 from CD_LVL_SUP hierarchy"),
  list(from = CLS_NUTS_DISTRICT_2021, to = CLS_NUTS_PROVINCE_2021,
       relation = "N:1", via = "CONVERSION_NIS2019_NUTS2021",
       notes = "Hierarchical"),
  list(from = CLS_NUTS_PROVINCE_2021, to = CLS_NUTS_REGION_2021,
       relation = "N:1", via = "CONVERSION_NIS2019_NUTS2021",
       notes = "Hierarchical"),
  list(from = CLS_NUTS_REGION_2021, to = CLS_NUTS_COUNTRY,
       relation = "N:1", via = "CONVERSION_NIS2019_NUTS2021",
       notes = "Hierarchical"),

  # --- NIS arrondissement to NUTS3 ---
  # Empirically 1:N: exactly ONE arrondissement (63000 Verviers) maps to 2 NUTS3
  # regions (BE335 FR + BE336 DE).  All NUTS3 regions map to exactly one
  # arrondissement (rev-multi=0) => the reverse NUTS3->arr is N:1 (simple).
  list(from = CLS_NIS_DISTRICT_2019, to = CLS_NUTS_DISTRICT_2021,
       relation = "1:N", via = "CONVERSION_NIS2019_NUTS2021",
       notes = paste0(
         "Verviers (63000) maps to BE335 (francophone) AND BE336 (germanophone). ",
         "All other arrondissements are 1:1.  Overall: 1:N (not M:N). ",
         "Reverse NUTS3->arrondissement is N:1 (simple)."
       )),

  # --- Postal to NIS ---
  list(from = CLS_POSTAL, to = CLS_NIS_MUNICIPALITY_2019,
       relation = "N:1", via = "CONVERSION_POSTAL_NIS2019",
       notes = "Each postal code maps to one commune (KEEP_UNIQUE=TRUE)"),
  list(from = CLS_POSTAL, to = CLS_NIS_MUNICIPALITY_2025,
       relation = "N:1", via = "CONVERSION_POSTAL_NIS2025",
       notes = "Each postal code maps to one commune (KEEP_UNIQUE=TRUE)"),

  # --- NIS version changes ---
  # Forward (2019->2025) is N:1: each 2019 commune maps to exactly one 2025
  # commune (unchanged or merged into one specific target). Several 2019
  # communes can share the same 2025 target (fusions), but the mapping is
  # unambiguous from the source side.
  # Reverse (2025->2019) is auto-generated as 1:N: a fused 2025 commune maps
  # back to the multiple 2019 constituents -> ambiguous, requires allow_ambiguous.
  list(from = CLS_NIS_MUNICIPALITY_2019, to = CLS_NIS_MUNICIPALITY_2025,
       relation = "N:1", via = "REFNIS_CHANGE",
       notes = paste0(
         "Each 2019 commune maps to exactly one 2025 commune (N:1 forward). ",
         "Fusions: multiple 2019 communes merge into one 2025 commune. ",
         "District/province changes: commune keeps its code or gets a new one. ",
         "Reverse (2025->2019) is 1:N for fused communes."
       )),

  # --- NUTS3 to Internal arrondissement ---
  list(from = CLS_NUTS_DISTRICT_2021, to = CLS_NBB_DISTRICT_2021,
       relation = "1:1", via = "NUTS_ARRONDISSEMENT",
       notes = paste0(
         "Direct mapping from NUTS3 to internal 2-digit code. ",
         "Verviers is split: BE335->65 (FR), BE336->66 (DE)."
       )),

  # --- NIS arrondissement to Internal (special case) ---
  # 1:N for the same reason as arrondissement->NUTS3: only Verviers (63000)
  # maps to two internal codes (65 FR + 66 DE).  All INTERNAL codes map to
  # exactly one arrondissement (reverse is N:1 = simple).
  list(from = CLS_NIS_DISTRICT_2019, to = CLS_NBB_DISTRICT_2021,
       relation = "1:N", via = "derived",
       notes = paste0(
         "Verviers (63000) -> internal 65 (FR) + 66 (DE). ",
         "All other arrondissements are 1:1.  Reverse INTERNAL->arr is N:1."
       )),

  # --- NUTS 2027 hierarchy (within-2027 only) ---
  # NOTE: there is NO direct NUTS_DISTRICT_2021 <-> NUTS_DISTRICT_2027 edge.
  # The two NUTS3 systems cover DIFFERENT geographic areas: 3 communes changed
  # province/arrondissement between 2019 and 2025, shifting their NUTS3 region
  # (e.g. commune 11056: BE211 in 2021 -> BE276 in 2027).  A pure code-rename
  # approach is therefore incorrect for these communes.
  # The correct path for any 2019-based data is:
  #   NIS_MUNICIPALITY_2019 -> NIS_MUNICIPALITY_2025 -> NUTS_DISTRICT_2027
  # using the authoritative REFNIS_2025-NUTS_2027.xlsx file.
  list(from = CLS_NUTS_DISTRICT_2027, to = CLS_NUTS_PROVINCE_2027,
       relation = "N:1", via = "derived",
       notes = "Hierarchical (first 4 chars of NUTS3 2027 code)"),
  list(from = CLS_NUTS_PROVINCE_2027, to = CLS_NUTS_REGION_2027,
       relation = "N:1", via = "derived",
       notes = "Hierarchical"),
  list(from = CLS_NUTS_REGION_2027, to = CLS_NUTS_COUNTRY,
       relation = "N:1", via = "derived",
       notes = "Hierarchical"),
  list(from = CLS_NIS_MUNICIPALITY_2019, to = CLS_NUTS_DISTRICT_2027,
       relation = "N:1", via = "derived",
       notes = paste0(
         "Path: NIS_MUNICIPALITY_2019 -> NIS_MUNICIPALITY_2025 -> NUTS_DISTRICT_2027. ",
         "Uses the official REFNIS_2025-NUTS_2027.xlsx mapping. ",
         "NOT via a NUTS_DISTRICT_2021 code-rename table (would be wrong for 3 communes ",
         "that changed province between 2019 and 2025)."
       )),
  list(from = CLS_POSTAL, to = CLS_NUTS_DISTRICT_2027,
       relation = "N:1", via = "derived",
       notes = "Via POSTAL -> NIS_MUNICIPALITY_2019 -> NIS_MUNICIPALITY_2025 -> NUTS_DISTRICT_2027"),

  # --- NIS 2025 -> NUTS 2027 ---
  list(from = CLS_NIS_MUNICIPALITY_2025, to = CLS_NUTS_DISTRICT_2027,
       relation = "N:1", via = "CONVERSION_NIS2025_NUTS2027",
       notes = "Direct mapping via REFNIS_2025-NUTS_2027.xlsx (hierarchical format)."),
  list(from = CLS_NIS_MUNICIPALITY_2025, to = CLS_NUTS_PROVINCE_2027,
       relation = "N:1", via = "CONVERSION_NIS2025_NUTS2027",
       notes = "Via NIS_MUNICIPALITY_2025 -> NUTS_DISTRICT_2027 -> NUTS_PROVINCE_2027"),
  list(from = CLS_NIS_MUNICIPALITY_2025, to = CLS_NUTS_REGION_2027,
       relation = "N:1", via = "CONVERSION_NIS2025_NUTS2027",
       notes = "Via NIS_MUNICIPALITY_2025 -> NUTS_DISTRICT_2027 -> NUTS_REGION_2027"),

  # --- NIS 2025 -> NUTS 2021 (Phase 4) ---
  # cd_nuts3 / cd_nuts_lau / cd_arr_internal backfilled onto the 2025 master via
  # add_nuts2021_columns_2025(): unchanged communes inherit from 2019; fused communes
  # are unambiguous when all constituents share the same NUTS3.
  # 3 communes (46029, 46030, 71072) fuse localities from *different* NUTS_DISTRICT_2021
  # regions -> genuinely 1:N. The handler returns N rows for these communes
  # (one per distinct constituent NUTS3); weights must be registered separately via
  # register_split_weights().
  list(from = CLS_NIS_MUNICIPALITY_2025, to = CLS_NUTS_DISTRICT_2021,
       relation = "1:N", via = "derived",
       no_reverse = TRUE,
       ambiguous_codes = c(46029L, 46030L, 71072L),
       coverage = "564/567 (99.5%)",
       notes = paste0(
         "3 NIS 2025 communes (46029, 46030, 71072) fuse localities from different ",
         "NUTS_DISTRICT_2021 regions; each maps to N NUTS3 targets (1:N). ",
         "All other 564 communes are unambiguous (N:1). ",
         "Use allow_ambiguous = TRUE; register weights via register_split_weights() ",
         "for proportional splits. ",
         "no_reverse = TRUE: the reverse NUTS_DISTRICT_2021 -> NIS_MUNICIPALITY_2025 is 1:N ",
         "(many communes per NUTS3) and would create a spurious simple path ",
         "NUTS_DISTRICT_2021 -> NIS_MUNICIPALITY_2025 -> NUTS_DISTRICT_2027."
       )),
  # NIS_MUNICIPALITY_2025 -> NUTS_MUNICIPALITY_2021: deliberately absent.
  # LAU (Local Administrative Unit) is a 1:1 identifier for NIS 2019 communes.
  # Fused communes in NIS 2025 do not have a single LAU code (LAU is undefined
  # after a merge of two or more communes). Adding this edge would create a
  # spurious simple path NIS_MUNICIPALITY_2025 -> NUTS_MUNICIPALITY_2021 -> NIS_MUNICIPALITY_2019
  # that silently gives NA for fused communes instead of their 2019 constituents.
  # Users who need LAU codes for 2025 communes should convert via NIS 2019 and
  # filter for unchanged communes.
  list(from = CLS_NIS_MUNICIPALITY_2025, to = CLS_NBB_DISTRICT_2021,
       relation = "N:1", via = "derived",
       notes = paste0("cd_arr_internal backfilled onto 2025 master from constituent 2019 communes. ",
                      "Same uniqueness logic as NUTS_DISTRICT_2021 backfill."))
)

# --- Valid classification identifiers ---
# Derived from CONVERSION_GRAPH_EDGES: every 'from'/'to' node that appears in
# at least one conversion edge is a valid classification identifier.
# normalize_classification_id() enforces membership in this set.
VALID_CLASSIFICATIONS <- unique(c(
  vapply(CONVERSION_GRAPH_EDGES, `[[`, character(1L), "from"),
  vapply(CONVERSION_GRAPH_EDGES, `[[`, character(1L), "to")
))

# --- Belgian NIS Administrative Code Constants ---
# These structural codes are defined by Belgian law / Statbel and do not change
# between NIS versions (regions and provinces predate the 2019/2025 commune fusions).
# All build logic in 01_load_data.R and 02_build_master_table.R uses these names.
# Never scatter these literals through the codebase -- reference this block instead.

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
  "nis_changes", # NIS version transitions: 2019->2025 and BEFORE_2019->2019 (from_version)
  "entities",    # one row per (classification_id, code) -- flat enumeration of all nodes
  "crosswalks"   # one row per primitive code link (from_id, to_id, code_from, code_to, relation, nature)
)

# --- Schema of the unified `communes` table ---
# The communes table is the rbindlist() of one sub-table per NIS version, which
# do NOT all carry the same columns (e.g. NIS 2025 carries only the 2027 NUTS
# columns, not the 2021 ones). rbindlist(fill = TRUE) tolerates that by design,
# but it would also silently mask a renamed or dropped column with all-NA.
# .validate_commune_schema() (02_build_master_table.R) uses the two sets below
# to turn such silent drift into an explicit build-time error:
#   - CORE: columns every per-version sub-table MUST provide.
#   - KNOWN: the full set a sub-table is ALLOWED to contain (a version may omit
#     version-specific columns, but may not introduce an unknown one).
MASTER_COMMUNE_CORE_COLS <- c(
  "cd_commune", "tx_commune_fr", "tx_commune_nl",
  "cd_arr", "cd_province", "cd_region", "nis_version"
)

MASTER_COMMUNE_KNOWN_COLS <- c(
  MASTER_COMMUNE_CORE_COLS,
  "tx_arr_fr", "tx_arr_nl", "cd_arr_2digit",
  "tx_prov_fr", "tx_prov_nl", "tx_region_fr", "tx_region_nl",
  "cd_nis_country",
  "cd_nuts_lau", "cd_nuts3", "cd_nuts2", "cd_nuts1", "cd_nuts0",
  "tx_nuts3_fr", "tx_nuts3_nl",
  "cd_nuts3_2027", "cd_nuts2_2027", "cd_nuts1_2027", "cd_nuts0_2027",
  "cd_arr_internal"
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

