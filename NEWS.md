# nbbbenuts (development version)

## New features

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
  a 22-node structured registry that is now the single source of truth for
  system/level/version/code_type metadata, replacing ad-hoc string parsing.
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
