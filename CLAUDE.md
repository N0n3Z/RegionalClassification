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

**Long model (v3.0.0):** the master data is `entities` + `crosswalks` only —
the only persisted tables and the only ones runtime code reads (`.entities_of()`,
`.links()` in `R/11_wide_view.R`). The wide tables `municipalities` / `postal` /
`nis_changes` exist only inside `build_master_table()`; `wide_view()` rebuilds
them from the long model and `test-wide-view.R` checks it against
`fixtures/golden_wide.rds`. Tests read wide tables through `wide_md` (helper).

**Tests that are not regression snapshots:** `test-invariants.R` (structural
properties checked over every crosswalk pair -- add an entry to
`ALLOWED_NA_LINKS` only with a reason) and `test-references.R` (facts from the
official Statbel / Eurostat / bpost lists, never from package output). When a
golden fixture changes, these say whether the new data is right.

**Aggregated levels across versions (v3.0.0):** links between NIS districts /
provinces / regions of different versions, NIS <-> NUTS at the same level and
NUTS 2021 <-> 2027 are derived from the commune crosswalks in `build_crosswalks()`
(`.derive_level_xw()`); never add an aggregated cross-version edge by hand. Every
conversion from one commune version to an aggregated node of another is stored
as a direct crosswalk (exact): composing through an aggregated M:N edge is
coarser, and the precision invariant in `test-invariants.R` fails if it happens.

**Atom engine (in transition, `docs/plans/engine-redesign.md`):** `R/12_atoms.R`
derives `membership(classification, code, atom)` from the crosswalks (atom =
BEFORE_2019 commune; postal codes as soon as `POSTAL -> NIS_MUNICIPALITY_BEFORE_2019`
exists) and converts by one join. Opt-in with `options(nbbbenuts.engine = "atoms")`;
`test-atom-engine.R` pins it to `fixtures/golden_all_pairs.rds` (regenerate with
`gen_golden_all_pairs()` only when a conversion change is intended, and list every
known difference in `ATOM_ENGINE_EXPECTED_DIFFS`). The package has users: exported
functions change only if necessary; log user-facing changes in
`docs/plans/user-facing-changes.md`.

## Architecture (where things live)

- `R/00_config.R` — `CONVERSION_GRAPH_EDGES` (conversion topology),
  `VALID_CLASSIFICATIONS` (derived from edges), NIS code constants,
  `MASTER_MUNICIPALITY_*` schema, `SCHEMA_V1_TO_V2`, `NUTS2021_TO_NUTS2027`.
- `R/01_load_data.R`, `R/02_build_master_table.R` — load/parse raw files and
  build the unified `municipalities` / `postal` / `nis_changes` tables (version
  discriminator columns `version` / `version_from` / `version_to`), plus the
  long tables `entities` and `crosswalks`.
- `R/03_convert.R` — conversion core: `convert_codes` → `check_conversion_path`
  (gate) → `route_conversion` (direct handler in `.ROUTE_TABLE`, else compose
  single hops via `.compose_via_handlers`).
- `R/05_conversion_check.R` — BFS over the graph; `is_simple` = path uses only
  `1:1`/`N:1` edges.
- `R/07_detect.R`, `R/07_diagnose.R`, `R/09_query.R` — detection, diagnostics,
  labels/crosswalks/validation.
- `R/07_dataset_convert.R`, `R/07_split_ambiguous.R`, `R/10_rebase.R` — dataset-
  level conversion, weighted M:N splitting (Verviers), longitudinal rebasing.

Facts worth knowing: **all classification codes are `character`** (v1.2.0; NIS
and POSTAL used to be integer). Input stays permissive — integer codes are
coerced via `.node_coerce()` — but everything is stored and returned as
character. The build derives the NIS hierarchy with integer arithmetic on REFNIS
codes (level classification by modulo) and only stringifies the code columns at
the end of `build_master_table()` via `.stringify_code_columns()`.

**Schema v2 naming** (v2.0.0): persisted tables use
`<role>_<subject>[_<qualifier>][_<lang>]` — `code_*`, `label_*_fr/_nl`,
`version*`, `classification*` — where the subject is the lower-cased graph node id
without the NIS version (`code_nis_municipality`, `code_nuts_district_2021`,
`code_nbb_district_2021`). `communes` is now `municipalities`. Build-time
intermediates (`01_load_data.R`, per-version sub-tables) keep source names
(`cd_refnis`, `cd_nuts3`, ...) and are renamed once via `SCHEMA_V1_TO_V2`
(`R/00_config.R`), which also migrates v1 snapshots on load
(`.migrate_schema_v1()`, warning `rcl_legacy_schema`).
User-facing code columns (`convert_dataset()` targets, `get_crosswalk()`,
example datasets `rc_*`) use the full id, version included:
`default_col_name()` = `code_<lower-cased id>` (`code_nuts_district_2021`).
`tests/testthat/test-schema.R` enforces the convention. Verviers (NIS arr 63000) is the canonical ambiguous case
(NUTS3 BE335 FR + BE336 DE). The conversion graph and the executor must stay in
lock-step — `tests/testthat/test-route-parity.R` guards that.

## Conventions

- Develop on a feature branch (schema v2 work: `claude/schema-v2`).
  Never push to `main`. Commit/push only when asked.
- Errors/warnings use typed condition classes (`rcl_*`); keep new ones consistent.
- Internal helpers are unexported; use `#' @noRd` or plain comments so roxygen
  does not generate orphan `man/*.Rd`.
- After changing roxygen, run `devtools::document()` so `man/` and `NAMESPACE`
  stay in sync.

