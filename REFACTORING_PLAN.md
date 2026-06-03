# Refactoring plan & session handoff — `nbbbenuts`

> **Purpose of this file.** It is a handoff document to resume work on this package
> on another machine / in a new session. It records (1) what was changed so far on
> branch `claude/vigilant-carson-zbTsd`, (2) the architecture context, and (3) the
> full, phased plan for the next chunk of work. After cloning, point a fresh Claude
> Code session at this file ("read REFACTORING_PLAN.md and continue from there").
>
> This file is excluded from the built package via `.Rbuildignore`.

---

## 0. How to resume locally

```bash
git clone <repo-url>
cd RegionalClassification
git checkout claude/vigilant-carson-zbTsd      # work branch (NOT main)
```

In R (from the package root):

```r
install.packages(c("data.table", "rlang"))                 # Imports
install.packages(c("readxl", "stringdist", "here",         # Suggests (rebuild + fuzzy + viz)
                   "visNetwork", "ggplot2", "testthat"))
devtools::load_all(".")
devtools::test()        # <-- run this FIRST to confirm the branch is green
```

**Why this matters:** the remote environment where this branch was developed has **no R
binary**, so none of the changes below were executed there — they were written and
reviewed statically. The first thing to do locally is run `devtools::test()` and confirm
everything passes (in particular `tests/testthat/test-route-parity.R`). If anything is red,
fix that before starting new work.

To rebuild the pre-built data snapshot from the raw files (needed for Phase 4 below):

```r
rebuild_master_data()   # requires readxl + the files in data/raw/; writes inst/extdata/*.rds
```

---

## 1. Current state of the branch

Branch `claude/vigilant-carson-zbTsd` is ahead of `main` by **3 commits** from this session:

| Commit | What it did |
|--------|-------------|
| `ede4ee9` | **Unify graph & executor.** `route_conversion()` is now graph-driven: when there is no direct handler it composes existing single-hop handlers along a path in the handler graph (`.compose_via_handlers` in `R/03_convert.R`). Added the missing simple single-hop handlers (`NIS_PROVINCE_* → NIS_REGION_*`, `NIS_ARRONDISSEMENT_BEFORE_2019 → NIS_PROVINCE_BEFORE_2019`, `NUTS2_2021 → NUTS1_2021`, `NUTS1_2021 → NUTS0`, `NUTS1_2027 → NUTS0`). Replaced ~40 repetitive dispatch closures with factories (`.master_hop`, `.b19_hop`, `.master_pair_hop`); removed the POSTAL multi-hop special case. Added build-time schema validation of the `communes` master (`.validate_commune_schema` + `MASTER_COMMUNE_CORE_COLS`/`MASTER_COMMUNE_KNOWN_COLS`). Added `tests/testthat/test-route-parity.R`. Fixed a doc default-path. |
| `0b69d6c` | **Graph cardinality fix.** Three `commune → NUTS3` edges were mislabelled `1:1` instead of `N:1` (`NIS_COMMUNE_BEFORE_2019 → NUTS3_2021`, `→ NUTS3_2027`, `NIS_COMMUNE_2019 → NUTS3_2027`). Because the reverse of `1:1` stays `1:1`, `check_conversion_path()` wrongly reported descents (`NUTS3 → commune/LAU`, `* → *_BEFORE_2019`) as lossless "simple" conversions. Relabelled to `N:1`; forward stays simple, reverse correctly becomes ambiguous `1:N`. This is what the parity test surfaced. |
| `2125295` | **Test hygiene.** Wrapped tests that deliberately trigger informative warnings (`rcl_unmatched_codes` on NA/unknown codes; ratio/fun + equal-weights advisories in `rebase_series`) in `expect_warning(...)` / `suppressWarnings(...)` so they assert intent instead of surfacing as loose warnings. No package behaviour change. |

**Net effect:** the conversion *graph* (what's reachable, with correct cardinality) and the
*executor* (what actually runs) are now in lock-step, guarded by a parity test. Schema drift
in the master table now fails loudly at build time.

---

## 2. Architecture quick map

Package name: **`nbbbenuts`** (DESCRIPTION). Belgian geographic code converter across
classification systems (NIS communes/arr/prov/region, NUTS, postal, internal) and time
versions (NIS BEFORE_2019/2019/2025, NUTS 2021/2027).

| File | Role |
|------|------|
| `R/00_config.R` | `CLASSIFICATION_REGISTRY` (decorative), `FILE_MAPPING`, **`CONVERSION_GRAPH_EDGES`** (topology), `VALID_CLASSIFICATIONS` (derived from edges), NIS code constants, `MASTER_COMMUNE_*` schema, `NUTS2021_TO_NUTS2027`. |
| `R/01_load_data.R` | Load/parse raw XLS(X)/CSV into structured hierarchies. |
| `R/02_build_master_table.R` | Build the unified `communes` / `postal` / `nis_changes` flat tables (version discriminator `nis_version` / `from_version`); `add_nuts2027_columns`; `.validate_commune_schema`; `save_master_tables`. |
| `R/03_convert.R` | **Conversion core.** `convert_codes` → `check_conversion_path` (gate) → `execute_conversion` → `route_conversion` (direct handler or `.compose_via_handlers`). Handler factories + `.ROUTE_TABLE`. |
| `R/05_conversion_check.R` | BFS over `CONVERSION_GRAPH_EDGES` (with auto-generated reverse edges); `is_simple` = path uses only `1:1`/`N:1`. `get_conversion_matrix`. |
| `R/07_detect.R` / `R/07_diagnose.R` | Auto-detect classification of a code vector; coverage diagnostics. **Hardcode per-classification reference sets** (target of the registry refactor). |
| `R/09_query.R` | `get_label` / `validate_codes` / `get_crosswalk`; `.LABEL_META` + `.list_codes_for` (**most complete partial registry**). |
| `R/07_dataset_convert.R`, `R/07_split_ambiguous.R`, `R/10_rebase.R` | Dataset-level conversion, weighted M:N splitting (Verviers), longitudinal rebasing across versions. |
| `inst/extdata/*.rds` | Pre-built snapshot loaded by `load_master_data()` (fast path; no raw files needed). |
| `data/raw/*` | Source spreadsheets, only needed for `rebuild_master_data()`. |

Key data-modelling facts:
- The `communes` table holds all NIS versions; **NIS 2025 communes currently carry only the
  2027 NUTS columns** (`cd_nuts3_2027`…), not the 2021 ones — this is the asymmetry Phase 4 fixes.
- Verviers (NIS arr 63000) is the canonical ambiguous case: maps to NUTS3 BE335 (FR) + BE336 (DE).
- Code types: NIS / POSTAL / INTERNAL codes are **integer**; NUTS codes are **character**.

---

## 3. Why the next refactor (problem statement)

Per-classification knowledge (version, code column, source table, code type, label columns) is
**duplicated across 5 independent places** that can silently diverge:

1. `CLASSIFICATION_REGISTRY` (`R/00_config.R`) — decorative, never read at runtime.
2. `.LABEL_META` (`R/09_query.R`) — the most complete (version, code col, fr/nl labels, table).
3. `.list_codes_for()` switch (`R/09_query.R`).
4. `refs <- list(...)` in `detect_classification()` (`R/07_detect.R`).
5. `.get_reference_codes()` switch + `.parse_classification_id()` (`R/07_diagnose.R`) — the latter
   is already missing `NUTS0`, `NUTS2_2027`, `NUTS1_2027` and silently falls through to a default.

Code type (int/char) is likewise decided handler-by-handler via scattered `as.integer()` in
`R/03_convert.R`. Adding a future version means editing 5+ places. **Goal: one registry as the
single source of truth, from which everything else derives.**

Decisions already made with the maintainer:
- **Scope = the registry refactor** (this is the big lever for future flexibility).
- **Add `NIS_COMMUNE_2025 → NUTS3_2021 / NUTS_LAU_2021 / INTERNAL_ARRONDISSEMENT`** paths.
- **Uniform return schema:** `convert_codes()` always returns `(code_from, code_to, nature)`.

Items explicitly **out of scope** (audited, judged fine as-is): merging `convert_via_master` /
`convert_via_lookup` (intentional fast-path vs defensive split); the conversion graph/executor
redesign (now correct); `parse_refnis_hierarchy` extra tests.

---

## 4. The plan — 6 independently testable phases

> Each phase ends in a "green-able" state and should be pushed separately so the maintainer can
> run `devtools::test()` between phases. R is not runnable in the remote env, so this staging is
> the main safety mechanism.

### Phase 0 — Registry `CLASSIFICATION_NODES` + accessors (additive, zero behaviour change)
Create `R/00b_registry.R`: a **named list, one entry per node id** (the 21 ids = current keys of
`.LABEL_META`). Seed from `.LABEL_META`, enriched with `system`, `level`, `code_type`, `distinct`.

Fields per entry: `system` (NIS/NUTS/POSTAL/INTERNAL), `level`, `version` (NA if none),
`code_type` ("integer"/"character"), `source_table` ("communes"/"postal"), `version_filter`
(`nis_version` value or NA), `code_col`, `label_fr_col`, `label_nl_col` (NA where none),
`distinct` (TRUE when reference set is `unique(na.omit(col))` — NUTS3/2/1/0, arr/prov/region,
INTERNAL; FALSE for commune/postal/LAU).

Values: `code_type="integer"` for all NIS_* + POSTAL + INTERNAL; `"character"` for all NUTS*.
`version_filter="2019"` for NUTS_2021/LAU/POSTAL/INTERNAL, `"2025"` for NUTS_2027, matching NIS
version for NIS nodes.

Accessors (the only readers of the registry):
- `.node(id)` → entry, else `abort(class="rcl_invalid_classification")`.
- `.node_code_type(id)` / `.node_coerce(codes, id)` — single coercion primitive.
- `.node_reference_codes(id, master_data)` → `data.table(code, name_fr, name_nl)`. **Replaces**
  `.list_codes_for` and `.get_reference_codes`.
- `.node_label_meta(id)` → `list(ver, code, fr, nl, src)`. **Replaces** `.LABEL_META`.
- `.node_parse(id)` → `list(type, version)`. **Replaces** `.parse_classification_id` (fixes gaps).

Add `tests/testthat/test-registry.R`: key parity (`setequal(names(CLASSIFICATION_NODES),
VALID_CLASSIFICATIONS)` and `get_all_classification_nodes()`); every node resolvable; `code_type`
matches the real column type in the RDS; label columns exist; `.node_parse` total.

*Validate:* new tests pass; existing tests untouched.

### Phase 1 — Rewire query / diagnose / detect to the registry
- `R/09_query.R`: delete `.LABEL_META` + `.list_codes_for`; `get_label` → `.node_label_meta`,
  `validate_codes`/`get_crosswalk` → `.node_reference_codes`. **Preserve** label-join semantics in
  `get_label`.
- `R/07_diagnose.R`: `.get_reference_codes` → `.node_reference_codes`; `.parse_classification_id`
  → `.node_parse`. Keep the `NULL`-when-slice-empty behaviour (BEFORE_2019 not loaded).
- `R/07_detect.R`: build `refs` by iterating the registry. **Risk:** current `refs` is a curated
  subset (7 integer classes) — to keep detection ranking identical, add a `detectable=TRUE` flag to
  the registry and iterate only those.

*Validate:* `test-query.R`, `test-diagnose.R` as regression locks (outputs identical to before).

### Phase 2 — Centralize int/char coercion in the executor
- In `route_conversion()` (`R/03_convert.R`), right after the `from==to` guard:
  `input_dt[, code_from := .node_coerce(code_from, from)]`.
- **Critical composer caveat:** `.compose_via_handlers()` feeds *intermediate* codes to the next
  handler without re-coercion. Coerce per hop: before each handler call in the composer loop,
  coerce `code_from` to `.node_code_type(path[k])`. Coercion then lives in exactly 2 places.
- Simplify `.master_hop`/`.b19_hop` (drop their `as.integer`); remove inline `as.integer` from
  named handlers.
- **Keep** `convert_via_lookup()`'s type reconciliation as a backstop (do not delete).

*Validate:* `test-route-parity.R`, `test-conversions.R`, `test-edge-cases.R`.

### Phase 3 — Uniform return schema `(code_from, code_to, nature)`
- Add `.normalize_conversion_result(dt)`: add `nature := NA_character_` if absent, then
  `setcolorder(c("code_from","code_to","nature"))`. Apply at the 3 return points of
  `route_conversion`. The composer drops `nature` mid-chain (correct — multi-hop `nature` is
  ill-defined → stays NA).
- Consumers that must **re-select columns** so `nature` doesn't leak into their public output:
  `get_crosswalk()` (`R/09_query.R`) and `convert_dataset()` (`R/07_dataset_convert.R`).
  `rebase_series`/`split_ambiguous` already re-select → safe.
- Update roxygen of `convert_codes`/`execute_conversion` to document the fixed contract and the
  `nature` values (`UNCHANGED`/`FUSION`/`CHANGE_DSTR`/`CHANGE_PROV`/`NA`).

*Validate:* `test-convert-dataset.R`, `test-query.R`, `test-rebase.R`, `test-split-registry.R`;
maintainer runs `devtools::document()`.

### Phase 4 — Add NIS 2025 → NUTS 2021 / LAU / INTERNAL  *(requires `rebuild_master_data()`)*
**Build** (`R/02_build_master_table.R`): new helper `add_nuts2021_columns_2025(master_2025,
master_2019, nis_changes)` (next to `add_nuts2027_columns`), backfilling `cd_nuts3`, `cd_nuts_lau`,
`cd_arr_internal` (+ `cd_nuts2/1/0`) onto NIS 2025 communes:
- **Unchanged communes** (same `cd_commune` in `nis_version` 2019 and 2025): copy from the 2019 row.
- **Fusion communes** (`cd_refnis_new` in `nis_changes[from_version=="2019"]`, several
  `cd_refnis_old`): collect the 2021 `cd_nuts3` of all constituent 2019 communes.
  - `uniqueN(cd_nuts3)==1` → unambiguous → assign (and roll up NUTS2/1/0).
  - else → ambiguous → leave `NA` + `warn(class="rcl_ambiguous_backfill")` listing the 2025 codes.
  - `cd_nuts_lau` for fused communes is undefined → NA.
- Determine ambiguity from the **constituent set in `nis_changes`**, not a code prefix.

**Schema:** these columns are already in `MASTER_COMMUNE_KNOWN_COLS`, so `.validate_commune_schema`
accepts them with no change — they just stop being NA-via-`fill`.

**Graph** (`CONVERSION_GRAPH_EDGES`): add `NIS_COMMUNE_2025 → NUTS3_2021` (N:1),
`→ INTERNAL_ARRONDISSEMENT` (N:1), `→ NUTS_LAU_2021` (1:1), all `via="derived"`, notes documenting
NA-for-ambiguous-fusions.

**Handlers** (`.ROUTE_TABLE`): one-liners via factory —
`.master_hop("2025","cd_commune","cd_nuts3")`, `…"cd_arr_internal"`, `…"cd_nuts_lau"`.
Upper NUTS2/1/0_2021 from 2025 then come for free via the composer.

**Data:** the maintainer must run `rebuild_master_data()` (raw files needed) to refresh
`inst/extdata/*.rds`. This is why Phase 4 is last.

*Validate:* parity test auto-covers the new edges; add explicit cases (non-NA for an unchanged
2025 commune; NA + warning for a known ambiguous fusion); schema validation passes.

### Phase 5 — Tidy `CLASSIFICATION_REGISTRY`
Either derive it from `CLASSIFICATION_NODES` (group by `system`) or keep it + add a consistency
test (its versions/levels ⊇ what the nodes declare). Recommended: keep + test (not used at runtime).

---

## 5. Critical files for the implementation
- `R/00b_registry.R` (new) — `CLASSIFICATION_NODES` + `.node_*` accessors.
- `R/00_config.R` — new graph edges (Phase 4), schema notes, Phase 5.
- `R/03_convert.R` — centralized coercion, `.normalize_conversion_result`, new 2025 handlers.
- `R/09_query.R` — delete `.LABEL_META`/`.list_codes_for`, rewire, fix `get_crosswalk` columns.
- `R/07_diagnose.R` — replace `.get_reference_codes` + `.parse_classification_id`.
- `R/07_detect.R` — derive `refs` from the registry (`detectable` flag).
- `R/02_build_master_table.R` — backfill 2021 NUTS columns onto NIS 2025 communes.
- `tests/testthat/test-registry.R` (new) + augment `test-route-parity.R`, `test-conversions.R`,
  `test-query.R`, `test-diagnose.R`.

## 6. Verification (run locally; no R in the remote env)
After each phase: `devtools::load_all("."); devtools::test()`.
Before finishing: `devtools::document()` then `R CMD check` (or `devtools::check()`).
Phases 0–3 only need the pre-built RDS; **Phase 4 needs a `rebuild_master_data()`**.

## 7. Gotchas to keep in mind
- **No R in the original dev env** → all branch changes are statically reviewed only; run tests first.
- **Phase 2** touches the executor (parity-tested area) — keep the `convert_via_lookup` reconciliation net.
- **Phase 4** cardinality: ambiguity is decided from the constituent 2019 communes of each fusion.
- **Detection (Phase 1):** preserve the detectable subset so the ranking heuristic doesn't change.
- Develop on `claude/vigilant-carson-zbTsd` (or a new branch off it); do not push to `main`.
