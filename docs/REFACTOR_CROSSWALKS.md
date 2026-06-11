# Refactor — master_data normalisée (entities + crosswalks) + sémantique de périmètre

> Document de travail destiné à l’exécution **en local** (R disponible,
> tests intégrés). Exclu du package build via `.Rbuildignore`. Branche
> de départ recommandée : `feature/crosswalks-model` (depuis `main` à
> jour). Indépendant de l’objet `nomenclature` (branche
> `feature/nomenclature-object`) ; le champ `aggregates` n’est PAS
> requis ici.

------------------------------------------------------------------------

## 0. Pourquoi ce refactor

La `master_data` actuelle (`R/02_build_master_table.R`) = table
`communes` **large / dénormalisée**. Défauts structurels :

1.  **Colonnes à sens conditionnel à `nis_version`** : `cd_nuts3` n’a de
    sens que pour 2019/BEFORE_2019, `cd_nuts3_2027` pour 2025, et le
    slice 2025 porte des colonnes NUTS 2021 *backfillées* (NA pour les 3
    fusions ambiguës).
2.  **Les cas 1:N / M:N (Type D) ne sont pas représentables dans une
    ligne large** → ils sont reconstruits par des handlers ad hoc :
    `.convert_comm2025_to_nuts3_2021`, `convert_arr_to_nuts3`,
    `convert_arr_to_internal` (`R/03_convert.R`). Le 1:N « fuit » hors
    du modèle de données.
3.  **Hiérarchies NUTS dupliquées** et re-dérivées à la volée :
    `.master_pair_hop` fait
    `unique(communes[..., .(cd_nuts3, cd_nuts2)])`.
4.  **Peu modulaire** : nouvelle source = nouvelles colonnes + logique
    de build.

### Modèle cible (normalisé, isomorphe au graphe)

- **`entities(classification_id, code, name_fr, name_nl)`** — membres de
  chaque nœud.
- **`crosswalks(from_id, to_id, code_from, code_to, relation, nature)`**
  — **une ligne par lien primitif**, M:N **natif** (Verviers
  `63000 → BE335` + `63000 → BE336` = 2 lignes).
- **`weights(from_id, to_id, code_from, code_to, variable, weight)`** —
  exogènes, ancrés aux lignes overlap (Phase 4).
- `communes` / `postal` / `nis_changes` **conservés** (back-compat +
  intermédiaires de build).

### Deux invariants critiques (ne PAS les rater)

- **Build autonome après suppression des handlers.** Les crosswalks
  doivent être **construits depuis les tables parsées/assemblées du
  build** (pas en appelant le moteur runtime), pour que
  [`rebuild_master_data()`](https://n0n3z.github.io/regionalclassification/reference/rebuild_master_data.md)
  reste fonctionnel une fois les handlers supprimés (Phase 2).
- **Types de retour.** entities/crosswalks stockent les codes en
  **character**. Le moteur doit **re-coercer en sortie** au type
  canonique du nœud (`.node_code_type` / `.node_coerce`,
  `R/00b_registry.R`) pour préserver les retours actuels (ex.
  `NIS_REGION_2019 → 2000L` integer ; `NUTS_DISTRICT_2021 → "BE335"`
  character). Sans ça, des tests integer cassent
  (`expect_equal(r$code_to, 2000L)`).

------------------------------------------------------------------------

## Ordre d’exécution (règle d’or : **ne pas faire P2 sans P1 verte**)

`P0 golden → P1 crosswalks + parité (additif) → P2 bascule moteur → P3 lecteurs sur entities → P4 sémantique + poids → P5 CHANGE_* + docs`

Après **chaque** phase : `devtools::load_all("."); devtools::test()`.
Reconstruire le snapshot quand le build change :
[`rebuild_master_data()`](https://n0n3z.github.io/regionalclassification/reference/rebuild_master_data.md)
(raw + `readxl`). Fin :
[`devtools::document()`](https://devtools.r-lib.org/reference/document.html) +
[`devtools::check()`](https://devtools.r-lib.org/reference/check.html)
(0/0/0).

------------------------------------------------------------------------

## Phase 0 — Geler les sorties de référence (« golden ») AVANT toute modif

But : capturer le comportement du moteur **actuel** pour prouver la
non-régression de la P2.

`tests/testthat/helper-golden.R` (générateur) +
`tests/testthat/fixtures/golden_crosswalks.rds` :

``` r

# Lancer UNE fois avec le moteur actuel, puis committer le .rds.
gen_golden <- function() {
  md <- load_master_data()
  keys <- names(nbbbenuts:::.ROUTE_TABLE)               # chaque hop exécutable
  per_edge <- rbindlist(lapply(keys, function(key) {
    p <- strsplit(key, "__", fixed = TRUE)[[1]]
    from <- p[1]; to <- p[2]
    src <- nbbbenuts:::.list_codes_for(from, md)         # tous les codes membres de `from`
    r <- suppressWarnings(convert_codes(src, from, to, md, allow_ambiguous = TRUE))
    data.table(from_id = from, to_id = to,
               code_from = as.character(r$code_from),
               code_to   = as.character(r$code_to),
               nature    = r$nature)
  }))
  # + paires multi-hop représentatives
  multihop <- list(c("POSTAL","NUTS_DISTRICT_2027"), c("NUTS_DISTRICT_2021","NUTS_COUNTRY"),
                   c("NIS_MUNICIPALITY_2019","NUTS_DISTRICT_2027"), c("NBB_DISTRICT_2021","NUTS_PROVINCE_2021"),
                   c("NUTS_LAU_2021","NIS_REGION_2019"))
  # ... idem, empilé ...
  saveRDS(list(per_edge = per_edge, multihop = ...), "tests/testthat/fixtures/golden_crosswalks.rds")
}
```

Le **test** (actif dès P2) charge ce fixture et asserte que le moteur le
reproduit (`setequal` par `(from_id,to_id)`, `nature` comprise).

*Livrable* : fixture committée ; aucun changement de code source.

------------------------------------------------------------------------

## Phase 1 — Construire `entities` + `crosswalks` dans le build (ADDITIF)

### 1a. `entities` — réutilise `.node_reference_codes` (`R/00b_registry.R`)

Dans `build_master_table` (`R/02_build_master_table.R`), après
l’assemblage de `communes_unified` / `postal_unified` (≈ ligne 218-221),
avant le `result <- list(...)` :

``` r

md_tmp <- list(communes = communes_unified, postal = postal_unified)
entities <- rbindlist(lapply(names(CLASSIFICATION_NODES), function(id) {
  rc <- .node_reference_codes(id, md_tmp)          # data.table(code, name_fr, name_nl) ou NULL
  if (is.null(rc)) return(NULL)
  rc[, `:=`(classification_id = id, code = as.character(code))]
  rc[, .(classification_id, code, name_fr, name_nl)]
}))
```

Schéma :
`entities(classification_id chr, code chr, name_fr chr, name_nl chr)`.

### 1b. `crosswalks` — constructeurs **par arête, depuis les sources**

Nouvelle fonction `build_crosswalks(...)` produisant, pour **chaque clé
de `.ROUTE_TABLE`** (= chaque hop exécutable, forward + reverse), les
lignes `(from_id, to_id, code_from, code_to, relation, nature)` en
**character**, à partir des tables déjà calculées dans
`build_master_table` (`comm_2019`, `master_2019`, `master_2025`,
`master_before2019`, `postal_map_2019/2025`, `nis_changes`, + la logique
de backfill 2025→2021).

Patrons (set complet = `names(.ROUTE_TABLE)`) :

| Famille d’arêtes | Source (déjà disponible dans le build) |
|----|----|
| `NIS_COMMUNE_v → NIS_ARR/PROV/REGION_v`, `→ NUTS_LAU/NUTS3/2/1/0_2021`, `→ cd_arr_internal` | `unique(master_v[, .(cd_commune, <to_col>)])` |
| `POSTAL → NIS_MUNICIPALITY_2019/2025` | `postal_map_v[, .(cd_postal, cd_commune_nis)]` |
| `NUTS_DISTRICT_2021→NUTS2`, `NUTS2→NUTS1`, `NUTS1→NUTS_COUNTRY`, `NUTS_DISTRICT↔︎NBB_DISTRICT`, `NUTS_LAU→NIS_MUNICIPALITY_2019` (rev), `NBB_DISTRICT→NUTS_DISTRICT` (rev), `NUTS_DISTRICT_2021→NIS_DISTRICT_2019` (rev) | `unique(master_2019[!is.na(<col>), .(<from_col>, <to_col>)])` |
| `NIS_DISTRICT_2019 → NUTS_DISTRICT_2021` (**Verviers 1:N**) | `unique(master_2019[!is.na(cd_nuts3), .(cd_arr, cd_nuts3)])` → 63000 = 2 lignes |
| `NIS_DISTRICT_2019 → NBB_DISTRICT_2021` (**Verviers 1:N**) | `unique(master_2019[!is.na(cd_arr_internal), .(cd_arr, cd_arr_internal)])` |
| `NIS_PROVINCE_v → NIS_REGION_v` (**Brabant M:N**) | `unique(master_v[, .(cd_province, cd_region)])` → 20000 = 3 lignes |
| `NIS_MUNICIPALITY_2019 → NIS_MUNICIPALITY_2025` (**temporel, nature**) | `nis_changes[from_version=="2019", .(cd_refnis_old, cd_refnis_new, nature)]` + lignes `UNCHANGED` pour les codes 2019 absents de la table |
| `NIS_MUNICIPALITY_2025 → NIS_MUNICIPALITY_2019` (**reverse 1:N, nature**) | idem inversé (un 2025 fusionné → plusieurs 2019) |
| `NIS_MUNICIPALITY_BEFORE_2019 → NIS_MUNICIPALITY_2019` (temporel) | `nis_changes[from_version=="BEFORE_2019"]` + `UNCHANGED` |
| `NIS_MUNICIPALITY_2025 → NUTS3/2/1_2027` | `master_2025[, .(cd_commune, cd_nuts3_2027/...)]` |
| `NIS_MUNICIPALITY_2025 → NUTS_DISTRICT_2021` (**3 fusions 1:N**) | **relocaliser** la logique de `.convert_comm2025_to_nuts3_2021` (backfill `add_nuts2021_columns_2025` + expansion des codes ambigus via `nis_changes`) en constructeur de build |
| `NIS_MUNICIPALITY_2019/BEFORE → NUTS_DISTRICT_2027` (dérivé) | composer 2019→2025→2027 **une fois** au build (réutiliser `master_2025` cd_nuts3_2027 via le mapping de changements) |
| `NIS_MUNICIPALITY_2025 → NUTS2/1_2027`, etc. | hiérarchie 2027 depuis `master_2025` |

- `relation` : reprise de `CONVERSION_GRAPH_EDGES` (`R/00_config.R`)
  pour l’arête forward, ou de sa réciproque (flip `N:1↔︎1:N`, `1:1`,
  `M:N` — cf. `build_conversion_graph`, `R/05_conversion_check.R`) pour
  les hops reverse.
- `nature` : posée par les constructeurs temporels
  (`UNCHANGED/FUSION/CHANGE_DSTR/CHANGE_PROV`), `NA_character_` sinon.
- **Codes en character** partout.

Astuce de mise en œuvre la plus sûre : écrire un petit registre interne
`from_id, to_id -> fonction(parts) -> data.table(code_from, code_to[, nature])`,
puis empiler. Réutiliser `convert_via_lookup`/jointures `data.table`
simples.

### 1c. Persistance (gratuite)

`R/00_config.R` :

``` r

MASTER_FLAT_TABLES <- c("communes", "postal", "nis_changes", "entities", "crosswalks")
```

`save_master_tables` / `load_master_data` (`R/08_load_prebuilt.R`)
**itèrent ce vecteur** → RDS gérés automatiquement, **aucun** code de
chargement à modifier. Ajouter `entities`/`crosswalks` au `list(...)`
retourné par `build_master_table`.

### 1d. Test de parité (le garde-fou central)

`tests/testthat/test-crosswalks-parity.R` : pour chaque clé
`.ROUTE_TABLE`,

``` r
xw  <- master_data$crosswalks[from_id == X & to_id == Y, .(code_from, code_to)]
ref <- convert_codes(<codes de X>, X, Y, master_data, allow_ambiguous = TRUE)  # moteur ACTUEL
expect_true(setequal(paste(xw$code_from, xw$code_to),
                     paste(as.character(ref$code_from), as.character(ref$code_to))))
```

Inclure `nature` pour les arêtes temporelles. **Cette parité doit être
verte avant la P2.**

*Livrable* : build additif ;
[`rebuild_master_data()`](https://n0n3z.github.io/regionalclassification/reference/rebuild_master_data.md)
régénère les RDS ; suite existante + parité vertes.

------------------------------------------------------------------------

## Phase 2 — Brancher l’exécuteur sur `crosswalks` (PHASE RISQUÉE)

`R/03_convert.R` — remplacer la table de dispatch par un lookup
générique.

``` r

# Hop générique : lit les lignes de la table crosswalks pour l'arête (from -> to).
.crosswalk_hop <- function(input_dt, from, to, md) {
  lkp <- md$crosswalks[from_id == from & to_id == to, .(code_from, code_to, nature)]
  ic  <- data.table(code_from = as.character(input_dt$code_from))
  res <- merge(ic, lkp, by = "code_from", all.x = TRUE, allow.cartesian = TRUE)
  n_na <- sum(is.na(res$code_to))
  if (n_na > 0L) warn(sprintf("%d code(s) could not be converted (no match found)", n_na),
                      class = "rcl_unmatched_codes")
  res[, .(code_from, code_to, nature)]
}
```

- `.handler_graph()` : adjacence dérivée de
  `unique(md$crosswalks[, .(from_id, to_id)])` (au lieu de
  `names(.ROUTE_TABLE)`). ⚠️ `.handler_graph` doit donc recevoir `md`
  (le cache `.route_cache` doit être keyé sur la donnée, ou recalculé) —
  alternative : construire l’adjacence une fois depuis
  `CONVERSION_GRAPH_EDGES` (forward + reverse) puisque les arêtes du
  graphe == les paires présentes dans crosswalks.
- `.compose_via_handlers()` : itère les hops via
  `.crosswalk_hop(.., path[k], path[k+1], md)` au lieu de
  `.ROUTE_TABLE[[key]]`. Conserver la jointure par valeur +
  `setorder(.ord)`.
- [`route_conversion()`](https://n0n3z.github.io/regionalclassification/reference/route_conversion.md)
  :
  1.  `from == to` → identité ;
  2.  coercer l’entrée :
      `input_dt[, code_from := .node_coerce(code_from, from)]` ;
  3.  si `(from,to)` a des lignes crosswalk → `.crosswalk_hop` ; sinon
      `.compose_via_handlers` ;
  4.  **re-coercition de sortie** :
      `res[, code_to := .node_coerce(code_to, to)]` et
      `res[, code_from := .node_coerce(code_from, from)]` ;
  5.  `.normalize_conversion_result` (assure
      `code_from, code_to, nature`).
- **Supprimer** : `.ROUTE_TABLE`, `.master_hop`, `.b19_hop`,
  `.master_pair_hop`, `.convert_comm2025_to_nuts3_2021`,
  `convert_arr_to_nuts3`, `convert_arr_to_internal`,
  `convert_via_master`, `.route_nis2025_nuts2027`, `.get_master_b19`,
  `convert_nis2019_to_nis2025`, `convert_nis2025_to_nis2019`,
  `convert_nis_before2019_to_nis2019`. Garder `convert_via_lookup` si
  réutilisé ailleurs, sinon le retirer.
- `.normalize_conversion_result` inchangé.

*Validation* : `test-crosswalks-golden.R`, `test-crosswalks-parity.R`,
**et toute la suite existante inchangée** (`test-conversions.R`,
`test-route-parity.R`, `test-rebase.R`, `test-split-registry.R`,
`test-edge-cases.R`). Surveiller **les types de retour** (integer NIS vs
character NUTS) — c’est le piège n°1 de cette phase.

------------------------------------------------------------------------

## Phase 3 — Lecteurs sur `entities` ; `communes` rétrogradée

- Rebrancher sur `entities` :
  - `.node_reference_codes` (`R/00b_registry.R`) peut lire `entities`
    (`md$entities[classification_id == id]`) plutôt que les slices
    communes/postal.
  - `.list_codes_for` (`R/09_query.R`), `R/07_detect.R` (refs),
    `R/07_diagnose.R` (`.get_reference_codes`), `build_name_reference`
    (`R/04_fuzzy_match.R`).
- `master_data$communes` : **conservé** tel quel (intermédiaire de
  build + back-compat des consommateurs directs et des tests). Le
  dériver entièrement des crosswalks est **hors périmètre** par défaut
  (risque \> gain immédiat) ; à envisager plus tard.

*Validation* : `test-query.R`, `test-diagnose.R`, `test-detect`,
`test-fuzzy.R`.

------------------------------------------------------------------------

## Phase 4 — Sémantique de périmètre + poids ancrés (Q2 / Q3 / Q4)

### 4a. `perimeter_relation` (dérivé) + certification (Q4)

Helper dans `R/05_conversion_check.R`, dérivé par arête via `relation` +
system/version (`.node`) :

    temporal  : même système & versions différentes (non NA)   # Type B/C
    overlap   : relation %in% {"1:N","M:N"}                     # Type D
    identity  : relation == "1:1"                               # Type A
    nesting   : sinon (N:1 hors temporel)                       # Type A

[`check_conversion_path()`](https://n0n3z.github.io/regionalclassification/reference/check_conversion_path.md)
renvoie en plus : - `perimeter_relations` (par arête de `edges_used`), -
`perimeter_status` ∈ {`exact` (tout identity/nesting), `temporal` (≥1
temporal, 0 overlap), `requires_weights` (≥1 overlap)}, -
`straddle_free` = aucune arête overlap dans le chemin. Export
**`is_perimeter_preserving(from, to)`** = `straddle_free`.
[`list_available_conversions()`](https://n0n3z.github.io/regionalclassification/reference/list_available_conversions.md) +
[`print_conversion_check()`](https://n0n3z.github.io/regionalclassification/reference/print_conversion_check.md)
exposent `perimeter_relation`.

### 4b. `nature` au niveau ligne (Q2)

Natif dans `crosswalks` ; compléter les lignes NA dans
`.normalize_conversion_result` (`R/03_convert.R`) via multiplicité :

``` r

dt[, .n := .N, by = code_from]
dt[is.na(nature) & .n > 1L, nature := "OVERLAP"]   # Type D
dt[is.na(nature),          nature := "RECODE"]     # Type A
dt[, .n := NULL]
```

Vocabulaire final : `RECODE` (A), `UNCHANGED` (B),
`FUSION`/`CHANGE_DSTR`/`CHANGE_PROV` (C), `OVERLAP` (D). ⚠️ Semi-cassant
: ajuster les tests qui supposaient `nature == NA` pour les conversions
non-temporelles ; vérifier que `convert_dataset`
(`R/07_dataset_convert.R`) et `get_crosswalk` (`R/09_query.R`) ne
laissent pas fuiter `nature` dans leur sortie publique.

### 4c. Poids ancrés au périmètre (Q3) — `R/07_split_ambiguous.R`

- Registre/table
  `weights(from_id, to_id, code_from, code_to, variable, weight)` **keyé
  sur l’arête overlap primitive** (le périmètre qui enjambe :
  `NIS_DISTRICT_2019→NUTS_DISTRICT_2021` pour Verviers,
  `NIS_MUNICIPALITY_2025→NUTS_DISTRICT_2021` pour 46029/46030/71072,
  `NIS_PROVINCE_*→NIS_REGION_*` pour Brabant), **pas** la paire
  utilisateur.
- `.resolve_weights` localise l’arête overlap du chemin
  (`check_conversion_path()$edges_used` filtré sur
  `perimeter_relation=="overlap"`) et y résout les poids →
  **réutilisables par tout multi-hop** qui traverse ce périmètre.
- **Validation** : couverture (les `code_from` overlap des crosswalks) +
  somme à 1 par `code_from`.
- **Plusieurs jeux par périmètre** via `variable`
  (population/emploi/surface) — déjà permis par le design
  `register_split_weights(..., variable=)`.
- **Poids par colonne en un seul appel** (nouveau) :
  [`split_ambiguous()`](https://n0n3z.github.io/regionalclassification/reference/split_ambiguous.md)
  accepte `weights` sous forme de mapping `value_col -> variable` (ou
  `value_col -> weights_dt`), p.ex.
  `weights = list(population = "population", emploi = "employment")`.
  Rétro-compat : un scalaire s’applique à toutes les `value_cols` comme
  aujourd’hui (boucle actuelle
  `for (vc in value_cols) row_copy[, (vc) := get(vc) * w]` à généraliser
  par colonne).

*Validation* : `test-perimeter-semantics.R` (nouveau),
`test-split-registry.R`.

------------------------------------------------------------------------

## Phase 5 — Clarifier CHANGE_DSTR / CHANGE_PROV (Q1) + docs

- `data-raw/analyse_changes.R` : sur `master_data$nis_changes`, vérifier
  que CHANGE_DSTR/PROV sont des recodages **à commune entière** :
  - aucun `cd_refnis_old` ne se scinde en plusieurs `cd_refnis_new` (=
    transfert partiel) ;
  - rapport code inchangé vs recodé. Hypothèse attendue :
    reclassification administrative → **périmètre communal stable** →
    Type A pour des données communales (à distinguer de FUSION qui
    agrège).
- `tests/testthat/test-changes-nature.R` : verrouille la propriété
  empirique.
- Vignette « modèle de périmètre » (A/B/C/D ↔︎ `crosswalks.relation` /
  `perimeter_relation` / `nature` / `perimeter_status`) ; mise à jour
  `README.md`, `NEWS.md`, `CLAUDE.md` ;
  [`devtools::document()`](https://devtools.r-lib.org/reference/document.html).

*Validation* :
[`devtools::check()`](https://devtools.r-lib.org/reference/check.html)
0/0/0.

------------------------------------------------------------------------

## Fichiers critiques (récap)

- `R/02_build_master_table.R` — `build_entities`, `build_crosswalks`
  (constructeurs par arête + relocalisation Type D) ; ajout au
  [`list()`](https://rdrr.io/r/base/list.html) retourné.
- `R/00_config.R` — `MASTER_FLAT_TABLES` (+ `entities`, `crosswalks`).
- `R/03_convert.R` — `.crosswalk_hop`,
  `.handler_graph`/`.compose_via_handlers` sur crosswalks, re-coercition
  de sortie ; **suppression** des handlers/factories/Type-D/temporels/
  `convert_via_master`/`.route_nis2025_nuts2027`/`.get_master_b19`.
- `R/05_conversion_check.R` — `perimeter_relation`, `perimeter_status`,
  `straddle_free`, `is_perimeter_preserving`.
- `R/00b_registry.R`, `R/07_detect.R`, `R/07_diagnose.R`,
  `R/09_query.R`, `R/04_fuzzy_match.R` — lecture sur `entities`.
- `R/07_split_ambiguous.R` — poids ancrés overlap + mapping par colonne.
- `R/08_load_prebuilt.R` — **aucun** changement (automatique via
  `MASTER_FLAT_TABLES`).
- Tests : `test-crosswalks-golden.R` (P0), `test-crosswalks-parity.R`
  (P1), `test-perimeter-semantics.R`, `test-changes-nature.R` + suite
  existante.
- `data-raw/analyse_changes.R` ; docs `vignettes/*`, `README.md`,
  `NEWS.md`, `CLAUDE.md`.

## Pièges / arbitrages (à garder sous les yeux)

1.  **Types de retour** : crosswalks en character → re-coercer
    `code_from`/`code_to` au type canonique du nœud **en sortie** de
    `route_conversion`. Piège n°1 de la P2.
2.  **Build autonome après P2** : crosswalks construits **depuis les
    sources** (P1), jamais via les handlers runtime (supprimés en P2),
    sinon
    [`rebuild_master_data()`](https://n0n3z.github.io/regionalclassification/reference/rebuild_master_data.md)
    casse.
3.  **Parité = garde-fou** : golden (P0) + parité par-arête (P1) gèlent
    les cardinalités durement corrigées (Brabant 3 régions, 3 communes
    cross-NUTS3, Verviers 1:N). Aucune ne doit être recalculée
    différemment.
4.  **`.handler_graph` dépend désormais de la donnée** (crosswalks) —
    soit le construire depuis `CONVERSION_GRAPH_EDGES` (équivalent et
    sans état), soit invalider le cache `.route_cache`.
5.  **`nature` (Q2)** semi-cassant : NA → RECODE/OVERLAP pour les
    conversions non-temporelles.
6.  **Indépendant** de `feature/nomenclature-object` ; ne dépend PAS du
    champ `aggregates`.
