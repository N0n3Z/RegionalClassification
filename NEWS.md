# nbbbenuts 2.0.0

## Breaking changes

* **Standardised data model (schema v2).** The tables returned by
  `load_master_data()` / `build_master_table()` now follow a single naming
  convention, `<role>_<subject>[_<qualifier>][_<lang>]`, aligned on the
  classification ids of the conversion graph:
  - roles: `code_*` (always character), `label_*_fr` / `label_*_nl`,
    `version` / `version_from` / `version_to`, `classification` /
    `classification_from` / `classification_to`; `relation`, `nature` and
    `weight` are unchanged;
  - the subject of a code column is the lower-cased node id, without the NIS
    version (carried by the row's `version`): `NIS_DISTRICT_2019` ->
    `code_nis_district`, `NUTS_DISTRICT_2021` -> `code_nuts_district_2021`.

  Table `communes` is renamed **`municipalities`**. Column renames:

  | Table | v1 | v2 |
  |---|---|---|
  | municipalities | `cd_commune`, `tx_commune_fr/_nl` | `code_nis_municipality`, `label_nis_municipality_fr/_nl` |
  | municipalities | `cd_arr`, `tx_arr_fr/_nl` | `code_nis_district`, `label_nis_district_fr/_nl` |
  | municipalities | `cd_province`, `tx_prov_fr/_nl` | `code_nis_province`, `label_nis_province_fr/_nl` |
  | municipalities | `cd_region`, `tx_region_fr/_nl` | `code_nis_region`, `label_nis_region_fr/_nl` |
  | municipalities | `cd_nis_country` | `code_nis_country` |
  | municipalities | `cd_nuts_lau` | `code_nuts_municipality_2021` |
  | municipalities | `cd_nuts3`, `cd_nuts2`, `cd_nuts1`, `cd_nuts0` | `code_nuts_district_2021`, `code_nuts_province_2021`, `code_nuts_region_2021`, `code_nuts_country` |
  | municipalities | `tx_nuts3_fr/_nl` | `label_nuts_district_2021_fr/_nl` |
  | municipalities | `cd_nuts3_2027`, `cd_nuts2_2027`, `cd_nuts1_2027`, `cd_nuts0_2027` | `code_nuts_district_2027`, `code_nuts_province_2027`, `code_nuts_region_2027`, `code_nuts_country_2027` |
  | municipalities | `cd_arr_internal` | `code_nbb_district_2021` |
  | municipalities | `cd_arr_2digit` | *removed (unused)* |
  | municipalities, postal | `nis_version` | `version` |
  | postal | `cd_postal`, `cd_commune_nis`, `tx_postal_name_fr/_nl` | `code_postal`, `code_nis_municipality`, `label_postal_fr/_nl` |
  | nis_changes | `cd_refnis_old`, `cd_refnis_new`, `from_version` | `code_from`, `code_to`, `version_from` (+ new `version_to`) |
  | entities | `classification_id`, `name_fr/_nl` | `classification`, `label_fr/_nl` |
  | crosswalks | `from_id`, `to_id` | `classification_from`, `classification_to` |

  `municipalities` columns are now ordered `version`, NIS hierarchy, NUTS
  2021 / 2027, NBB.

  `CLASSIFICATION_NODES` (`source_table`, `code_col`, `label_*_col`) follows the
  same names. The conversion results themselves are unchanged (same codes,
  same rows). `convert_codes()` (`code_from`, `code_to`, `nature`), the
  split-weight API (`code_from`, `code_to`, `weight`), `get_label()` and
  `validate_codes()` already followed the convention and are unchanged.

* **User-facing outputs follow the same convention.** A code column created
  for a classification is named `code_<lower-cased id>`, version included:

  | Function / data | v1 | v2 |
  |---|---|---|
  | `convert_dataset()`, `split_ambiguous()` default `target_col` | `cd_nuts3_2021`, `cd_nis2019`, `cd_arr2019`, `cd_prov2019`, `cd_lau2021`, `cd_arr_internal`, ... | `code_nuts_district_2021`, `code_nis_municipality_2019`, `code_nis_district_2019`, `code_nis_province_2019`, `code_nuts_municipality_2021`, `code_nbb_district_2021`, ... |
  | `get_crosswalk()` | columns named after the ids (`NIS_DISTRICT_2019`, `NUTS_DISTRICT_2021`) | `code_nis_district_2019`, `code_nuts_district_2021` |
  | `list_available_conversions()`, `get_conversion_matrix()` | `from`, `to` | `classification_from`, `classification_to` |
  | `fuzzy_match_names()`, `identify_from_names()` | `input_name`, `matched_name`, `matched_code` | `label_input`, `label_matched`, `code_matched` |
  | example datasets `rc_*` | `cd_commune`, `cd_arr`, `cd_region`, `cd_nuts3`, `cd_nuts3_2027`, `cd_postal`; `nom_fr` / `nom_nl` | `code_nis_municipality_2019` / `_2025`, `code_nis_district_2019`, `code_nis_region_2019`, `code_nuts_district_2021`, `code_nuts_district_2027`, `code_postal`; `label_fr` / `label_nl` |

  Example datasets renamed after the graph levels: `rc_communes_2019` ->
  `rc_municipalities_2019`, `rc_communes_2025` -> `rc_municipalities_2025`,
  `rc_arrondissements_2019` -> `rc_districts_2019`, `rc_nuts3_2021` ->
  `rc_nuts_districts_2021`, `rc_full_nuts3_2021` -> `rc_full_nuts_districts_2021`,
  `rc_full_nuts3_2027` -> `rc_full_nuts_districts_2027` (update your
  `data(...)` calls).

  The code columns of `rc_municipalities_2019`, `rc_municipalities_2025`,
  `rc_districts_2019` and `rc_postal` are now character (they were still
  integer). Measure columns (`population`, `emplois`, ...) are unchanged.

## Dependencies

* `data.table (>= 1.17.0)` is now required: the test suite crashes R
  (segfault in `is.sorted()`) with data.table 1.14.10.

* **v1 snapshots are migrated automatically.** `load_master_data()` reads a
  pre-2.0.0 snapshot directory (`communes.rds`, `cd_*` columns), migrates it in
  memory and signals a warning of class `rcl_legacy_schema`; re-save it with
  `save_master_tables()`. Passing an in-memory v1 `master_data` object to the
  conversion functions aborts with the same class.

## Bug fixes

* **NIS BEFORE_2019 communes now carry NUTS 2021 codes.** Their NUTS columns
  were read from the NIS -> NUTS file at a 2018 reference date, which returned
  the NUTS 2016 codes. For the 87 Hainaut and Limburg communes recoded in 2019,
  `NIS_MUNICIPALITY_BEFORE_2019 -> NUTS_DISTRICT_2021` returned codes that do
  not exist in NUTS 2021 (`BE221`, `BE222`, `BE321`-`BE327`; e.g. Mouscron
  `54007` gave `BE324` instead of `BE328`), and `-> NBB_DISTRICT_2021` returned
  `NA`. The 26 communes merged in 2019 also had their pre-2019 code as
  `code_nuts_municipality_2021` (Puurs `12030` instead of `12041`). BEFORE_2019
  communes now inherit the NUTS 2021 and NBB codes of their NIS 2019 successor.
  A v1 snapshot migrated by `load_master_data()` keeps the old values; rebuild
  it with `rebuild_master_data()`.


# nbbbenuts 1.2.0

## Breaking changes

* **All classification codes are now `character`.** NIS and POSTAL codes were
  previously stored and returned as `integer`; they are now `character`, matching
  NUTS and NBB codes (which were already character). A geographic code is an
  identifier, not a quantity, so a single string type is used throughout.
  - **Input is permissive**: passing integer codes (e.g. `convert_codes(21004L, ...)`)
    still works — they are coerced to their character form (`"21004"`).
  - **Output changes**: every returned `code_from` / `code_to` column, and every
    code column of `master_data` (`communes`, `postal`, `nis_changes`,
    `entities`, `crosswalks`) and of the bundled example datasets, is now
    `character`. Downstream joins, comparisons, and `==` filters that relied on
    integer codes must be updated (character-vs-integer comparisons still work via
    R's automatic coercion, but the stored type is character).
  - The bundled `inst/extdata/*.rds` snapshots were rebuilt. If you maintain a
    custom snapshot, re-run `rebuild_master_data()`.
  - The country code keeps the value `"1000"` (the historical integer form of the
    `01000` Statbel REALM code), not `"01000"`.


# nbbbenuts 1.1.0

## Improvements

* `convert_codes()` and `convert_dataset()` now auto-print their result at the
  top level. Previously a bare `convert_codes(...)` call (result not assigned)
  echoed nothing the first time, a consequence of data.table's modify-by-
  reference print-suppression (FAQ 2.23); the returned tables now reset that
  flag so results display as expected in interactive and demo use.

* The bundled demonstration script (`demo/demo.R`) is now fully in English
  (comments and messages).


# nbbbenuts 0.2.0

## Breaking changes

* **NIS province codes for Brabant and Brussels changed.** The defunct unified
  Brabant province code `20000` (split in 1995) is no longer produced. NIS
  province output now uses the real REFNIS codes — `20001` (Vlaams-Brabant,
  Flemish) and `20002` (Brabant wallon, Walloon) — and Brussels-Capital is
  assigned a synthetic **pseudo-province `4000`** (equal to its region code, as
  it has no statutory province). Any code keyed on `20000` must be updated.
  Caveat: a bare `4000` cannot be auto-detected as province vs region; pass an
  explicit classification. See `PROVINCE_REGION_NESTING.md`.

* **`NIS_PROVINCE_* -> NIS_REGION_*` is now `N:1` (nesting), not `M:N`.** Each
  province nests in exactly one region, so the conversion no longer requires
  `allow_ambiguous = TRUE` and its `perimeter_relation` is `"nesting"` instead of
  `"overlap"`. The nomenclature aggregation DAG was nested accordingly
  (`region -> province -> arrondissement -> municipality`): a region now
  aggregates provinces (previously arrondissements directly), so an
  arrondissement has a single parent.

* **Classification IDs renamed** to the `SYSTEM_LEVEL_VERSION` convention.
  All 14 identifiers have changed; update any hard-coded strings in your code:

  | Old identifier | New identifier |
  |----------------|----------------|
  | `NIS_COMMUNE_2019` | `NIS_MUNICIPALITY_2019` |
  | `NIS_COMMUNE_2025` | `NIS_MUNICIPALITY_2025` |
  | `NIS_COMMUNE_BEFORE_2019` | `NIS_MUNICIPALITY_BEFORE_2019` |
  | `NIS_ARRONDISSEMENT_2019` | `NIS_DISTRICT_2019` |
  | `NIS_ARRONDISSEMENT_2025` | `NIS_DISTRICT_2025` |
  | `NIS_ARRONDISSEMENT_BEFORE_2019` | `NIS_DISTRICT_BEFORE_2019` |
  | `NIS_PROVINCE_2019` | *(unchanged)* |
  | `NIS_REGION_2019` | *(unchanged)* |
  | `NUTS_LAU_2021` | `NUTS_MUNICIPALITY_2021` |
  | `NUTS3_2021` | `NUTS_DISTRICT_2021` |
  | `NUTS2_2021` | `NUTS_PROVINCE_2021` |
  | `NUTS1_2021` | `NUTS_REGION_2021` |
  | `NUTS3_2027` | `NUTS_DISTRICT_2027` |
  | `NUTS2_2027` | `NUTS_PROVINCE_2027` |
  | `NUTS1_2027` | `NUTS_REGION_2027` |
  | `NUTS0` | `NUTS_COUNTRY` |
  | `INTERNAL_ARRONDISSEMENT` | `NBB_DISTRICT_2021` |

  `CLS_*` constants are provided as the recommended replacement for all
  hard-coded strings (e.g. `CLS_NIS_MUNICIPALITY_2019` instead of
  `"NIS_MUNICIPALITY_2019"`).

* **`level` field values** in `CLASSIFICATION_NODES` now follow the same
  vocabulary (e.g. `"municipality"` instead of `"commune"`, `"district"`
  instead of `"arrondissement"`). Code that inspects `nom_level()` or
  `CLASSIFICATION_NODES[[id]]$level` directly must be updated.

* **`NBB_DISTRICT_2021`** system field changed from `"INTERNAL"` to `"NBB"`.
  `nomenclature("INTERNAL", ...)` no longer works; use `nomenclature("NBB", "district", "2021")`.

## New features

* **Shipped standard population weights.** The package now ships commune-level
  population for NIS 2019 communes across multiple years (2011-2024), so
  `split_weights_template(from, to, md, variable = "population")` and
  `split_ambiguous(..., weights = "population")` / `rebase_series(..., split =
  "population")` work out of the box -- proportional splits without registering
  weights. A new `weight_year` argument selects the reference year (default: the
  most recent) for period-consistent weights, e.g. historical retropolation. The
  shipped table carries `variable`/`vintage`/`year`/`code`/`value`, ready to hold
  additional vintages (e.g. BEFORE_2019) later without rework.

* **Data-aware conversion gate.** `check_conversion_path(from, to, md)` now
  returns `executable` and `effectively_simple`, and `convert_codes()` /
  `convert_dataset()` gate on `effectively_simple`. Aggregations that cross an
  overlap edge but re-merge to a single target per source (e.g.
  `NIS_DISTRICT_2019 -> NUTS_PROVINCE_2021`, where Verviers' two NUTS3 nest in one
  NUTS2) no longer require `allow_ambiguous`. `get_conversion_matrix(md)` gains an
  `executable`/`effectively_simple` column. `is_simple`/`straddle_free` stay
  topological and unchanged.

## Reliability & data-integrity fixes

* **Graph <-> executor parity.** `convert_codes()` now gates on real
  executability, so declared-but-unmaterialised de-aggregation routes fail with a
  clear `rcl_no_route` instead of first advising `allow_ambiguous`. `.xw_path()`
  is simple-first (deterministic path choice).
* **Detection.** Character NUTS codes are matched against real reference sets, so
  NUTS 2027 codes and the country code `BE` are detected correctly (previously
  always the 2021 vintage).
* **Fuzzy matching.** `fuzzy_match_names()` uses a relative distance for every
  method, so `max_dist` is comparable across `jw`/`osa`/`lv`/... (an edit-count
  method no longer silently marks near-matches as non-confident); `method` is
  validated.
* **Splitting.** Multi-hop composition de-duplicates re-merging rows (no more
  double-counting); weight normalisation guards a zero sum; `convert_dataset()`
  honours `na_action` and a type-robust join in the M:N branch.
* **Longitudinal rebasing.** `rebase_series()` rejects overlapping `version_map`
  periods (silent inflation guard).
* **Build hardening.** `filter_at_date()`, orphaned-2025 handling, unique-key and
  required-column assertions, robust column binding and postal-universe checks now
  fail loudly instead of corrupting data silently.
* **Example datasets regenerated** to match the current master (581/565/43),
  removing spurious province codes; all socio-economic columns remain fictional
  test data.

## New features (continued)

* **Crosswalks engine** (`get_crosswalk()`, `list_crosswalks()`): generates
  tidy crosswalk tables between any two supported classifications.  The result
  includes source code, target code, and a `nature` column that classifies
  each row as one of `UNCHANGED`, `FUSION`, `CHANGE_DSTR`, `CHANGE_PROV`
  (temporal NIS edges), `RECODE` (1:1 non-temporal), `OVERLAP` (1:N / M:N),
  or `NA` (multi-hop path).
* **Entities table** (`master_data$entities`): a unified lookup table of all
  geographic entities (communes, arrondissements, provinces, regions, NUTS
  units, postal codes) with French/Dutch names and code fields.
* **Perimeter semantics** (`is_perimeter_preserving()`,
  `check_conversion_path()$perimeter_relations`,
  `check_conversion_path()$perimeter_status`,
  `check_conversion_path()$straddle_free`): every edge in the conversion graph
  is now classified as `temporal`, `identity`, `nesting`, or `overlap`,
  allowing callers to determine whether a conversion preserves spatial
  boundaries without manual inspection.
* **`nature` column in `convert_codes()` output**: temporal NIS conversions
  now include a `nature` column (`UNCHANGED`, `FUSION`, `CHANGE_DSTR`,
  `CHANGE_PROV`) that explains how each commune changed between editions.
* **Classification registry** (`CLASSIFICATION_NODES`, `R/00b_registry.R`):
  a 23-node structured registry that is now the single source of truth for
  system/level/version/code_type metadata, replacing ad-hoc string parsing.
* **`NIS_COUNTRY`** (`CLS_NIS_COUNTRY`): new country-level node for the NIS
  system (code `1000L`, source: Statbel REFNIS "REALM" / 01000 / ROYAUME / HET RIJK).
  Unversioned; aggregates `NIS_REGION_BEFORE_2019`, `NIS_REGION_2019`, and
  `NIS_REGION_2025`. Symmetric with `NUTS_COUNTRY`.
* **Golden-fixture test** (`tests/testthat/test-crosswalks-golden.R`):
  crosswalk content is pinned against a pre-built fixture
  (`fixtures/golden_crosswalks.rds`) to detect regressions in code mapping
  or nature classification.
* **Registry consistency tests** (`tests/testthat/test-registry-consistency.R`):
  asserts that every node referenced by `CONVERSION_GRAPH_EDGES` exists in
  `CLASSIFICATION_NODES` and that every registry node is reachable in the graph.

## Bug fixes

* Corrected the cardinality of three commune -> NUTS3 edges in the conversion
  graph (`NIS_MUNICIPALITY_BEFORE_2019 -> NUTS_DISTRICT_2021`, `NIS_MUNICIPALITY_BEFORE_2019 ->
  NUTS_DISTRICT_2027`, `NIS_MUNICIPALITY_2019 -> NUTS_DISTRICT_2027`) from `1:1` to `N:1`: many
  communes share one NUTS3 region. They were previously labelled `1:1`, which
  made their reverse appear `1:1` too, so `check_conversion_path()` wrongly
  reported descents such as `NUTS3 -> commune`, `NUTS3 -> NUTS_LAU` and
  `* -> *_BEFORE_2019` as lossless "simple" conversions when they are in fact
  ambiguous (`1:N`). The forward direction stays `N:1` (still simple).
* `convert_codes()` now executes **every** multi-hop conversion that
  `check_conversion_path()` reports as reachable. Previously the path checker
  did a generic graph BFS while the executor only knew hand-written single-hop
  handlers (plus a POSTAL special case), so conversions such as
  `NUTS_DISTRICT_2021 -> NUTS_REGION_2021`, `NUTS_DISTRICT_2021 -> NUTS_COUNTRY` or `NUTS_REGION_2021 -> NUTS_COUNTRY`
  validated as "simple" but then failed with `rcl_no_route`. The executor now
  composes single-hop handlers along a path in the handler graph, keeping the
  graph as the single source of truth for topology.
* Added the previously-missing simple single-hop handlers
  `NIS_PROVINCE_* -> NIS_REGION_*`, `NIS_DISTRICT_BEFORE_2019 ->
  NIS_PROVINCE_BEFORE_2019`, `NUTS_PROVINCE_2021 -> NUTS_REGION_2021`, `NUTS_REGION_2021 -> NUTS_COUNTRY`
  and `NUTS_REGION_2027 -> NUTS_COUNTRY`.

## Improvements

* The unified `communes` master table is now schema-validated at build time
  (`build_master_table()`): each per-version sub-table is checked against
  `MASTER_COMMUNE_CORE_COLS` / `MASTER_COMMUNE_KNOWN_COLS` before being stacked,
  turning a silently NA-filled renamed/dropped column into an explicit
  `rcl_schema_error`.
* `R/03_convert.R`: the repetitive per-version dispatch closures are now built
  from small handler factories (`.master_hop`, `.b19_hop`, `.master_pair_hop`),
  so adding a future NIS/NUTS version is a matter of declaring hops rather than
  copy-pasting closure bodies. The POSTAL multi-hop special case is gone, handled
  by the generic composer.
* New test (`test-route-parity.R`) asserts that every conversion the graph
  reports as simple is actually executable, guarding the graph/executor parity
  against future drift.

## New functions

* `detect_classification()` — auto-detects the geographic classification of a
  vector of codes (NIS commune, NUTS3, postal, ...).
* `split_ambiguous()` — weighted M:N splitting for ambiguous arrondissement-to-NUTS3
  conversions (e.g. Verviers 63000 → BE335 / BE336).
* `register_split_weights()` / `get_split_weights()` / `list_split_weights()` /
  `clear_split_weights()` — session-scoped registry for pre-registered split weights.
* `diagnose_classification()` — comprehensive diagnostic report for a vector of codes.
* `get_all_classification_nodes()` / `get_conversion_matrix()` — now exported;
  allow programmatic inspection of the full conversion graph.

## Improvements

* Structured error conditions throughout: all errors and warnings now carry a named
  condition class (`rcl_invalid_input`, `rcl_ambiguous_conversion`, `rcl_no_route`,
  `rcl_data_missing`, `rcl_missing_package`, `rcl_unmatched_codes`), making them
  interceptable with `tryCatch()` / `withCallingHandlers()`.
* `convert_codes()` now raises `rcl_no_route` (not `rcl_ambiguous_conversion`) when
  no route exists at all; identity conversions (`from == to`) are short-circuited.
* `fuzzy_match_names()` gains a `requireNamespace("stringdist")` guard with a clear
  `rcl_missing_package` error instead of a cryptic crash.
* `normalize_name()` works in any R locale (including `C`) by matching UTF-8 byte
  sequences directly via `rawToChar(as.raw(...))` + `useBytes = TRUE`.
* `identify_from_names()` warns with `rcl_unmatched_codes` when no confident match
  is found across all tried classifications.
* `load_master_data()` raises `rcl_data_missing` with the missing path as metadata
  when the pre-built RDS directory does not exist.
* Dispatch table (`R/03_convert.R`): the 296-line if/else chain in `route_conversion()`
  is replaced by a package-level named list built once at load time.
* NAMESPACE is now managed by roxygen2 (`@export` tags on all public functions).

## Internal

* `R/07_dataset_convert.R` split into four focused files:
  `07_dataset_convert.R`, `07_detect.R`, `07_split_ambiguous.R`, `07_diagnose.R`.
* `here` moved from `Imports` to `Suggests` (used only behind `requireNamespace()`).
* `stringdist` and `readxl` confirmed as `Suggests`.
* `rlang (>= 1.0.0)` added to `Imports`.

# nbbbenuts 0.1.0

* Initial release.
