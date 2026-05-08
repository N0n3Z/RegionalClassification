# RegionalClassification (development version)

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

# RegionalClassification 0.1.0

* Initial release.
