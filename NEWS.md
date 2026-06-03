# nbbbenuts (development version)

## Bug fixes

* `convert_codes()` now executes **every** multi-hop conversion that
  `check_conversion_path()` reports as reachable. Previously the path checker
  did a generic graph BFS while the executor only knew hand-written single-hop
  handlers (plus a POSTAL special case), so conversions such as
  `NUTS3_2021 -> NUTS1_2021`, `NUTS3_2021 -> NUTS0` or `NUTS1_2021 -> NUTS0`
  validated as "simple" but then failed with `rcl_no_route`. The executor now
  composes single-hop handlers along a path in the handler graph, keeping the
  graph as the single source of truth for topology.
* Added the previously-missing simple single-hop handlers
  `NIS_PROVINCE_* -> NIS_REGION_*`, `NIS_ARRONDISSEMENT_BEFORE_2019 ->
  NIS_PROVINCE_BEFORE_2019`, `NUTS2_2021 -> NUTS1_2021`, `NUTS1_2021 -> NUTS0`
  and `NUTS1_2027 -> NUTS0`.

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
