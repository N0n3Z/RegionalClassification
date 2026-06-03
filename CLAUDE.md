# CLAUDE.md

Guidance for Claude Code when working in this repository.

## Project

`nbbbenuts` — an R package that converts Belgian geographic codes between
classification systems (NIS communes/arrondissements/provinces/regions, NUTS,
postal, internal) and across time versions (NIS BEFORE_2019 / 2019 / 2025,
NUTS 2021 / 2027). Pure data-wrangling package; dependencies are `data.table`
and `rlang` (Imports), with `readxl`, `stringdist`, `here`, `visNetwork`,
`ggplot2`, `testthat` as Suggests.

## Commands

```r
devtools::load_all(".")     # load the package for interactive work
devtools::test()            # run the testthat suite — DO THIS FIRST to confirm state
devtools::document()        # regenerate man/*.Rd + NAMESPACE after roxygen changes
devtools::check()           # full R CMD check before declaring done
rebuild_master_data()       # rebuild inst/extdata/*.rds from data/raw/ (needs readxl)
```

The package normally runs off the pre-built snapshot in `inst/extdata/*.rds`
(`load_master_data()`), so `data/raw/` is only needed when rebuilding.

## Architecture (where things live)

- `R/00_config.R` — `CONVERSION_GRAPH_EDGES` (conversion topology),
  `VALID_CLASSIFICATIONS` (derived from edges), NIS code constants,
  `MASTER_COMMUNE_*` schema, `NUTS2021_TO_NUTS2027`.
- `R/01_load_data.R`, `R/02_build_master_table.R` — load/parse raw files and
  build the unified `communes` / `postal` / `nis_changes` tables (version
  discriminator columns `nis_version` / `from_version`).
- `R/03_convert.R` — conversion core: `convert_codes` → `check_conversion_path`
  (gate) → `route_conversion` (direct handler in `.ROUTE_TABLE`, else compose
  single hops via `.compose_via_handlers`).
- `R/05_conversion_check.R` — BFS over the graph; `is_simple` = path uses only
  `1:1`/`N:1` edges.
- `R/07_detect.R`, `R/07_diagnose.R`, `R/09_query.R` — detection, diagnostics,
  labels/crosswalks/validation.
- `R/07_dataset_convert.R`, `R/07_split_ambiguous.R`, `R/10_rebase.R` — dataset-
  level conversion, weighted M:N splitting (Verviers), longitudinal rebasing.

Facts worth knowing: NIS/POSTAL/INTERNAL codes are **integer**, NUTS codes are
**character**. Verviers (NIS arr 63000) is the canonical ambiguous case
(NUTS3 BE335 FR + BE336 DE). The conversion graph and the executor must stay in
lock-step — `tests/testthat/test-route-parity.R` guards that.

## Conventions

- Develop on the work branch `claude/vigilant-carson-zbTsd` (or a branch off it).
  Never push to `main`. Commit/push only when asked.
- Errors/warnings use typed condition classes (`rcl_*`); keep new ones consistent.
- Internal helpers are unexported; use `#' @noRd` or plain comments so roxygen
  does not generate orphan `man/*.Rd`.
- After changing roxygen, run `devtools::document()` so `man/` and `NAMESPACE`
  stay in sync.

## In-progress work

A multi-phase refactor is planned (single-source-of-truth classification
registry + NIS 2025 → NUTS 2021 paths + uniform `convert_codes()` return schema).
See **`REFACTORING_PLAN.md`** at the repo root for the full plan, current branch
state, and phase-by-phase steps. Start there when resuming.
