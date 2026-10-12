# Plan — Standardisation du modèle de données de `nbbbenuts` (v2.0.0)

## Contexte
Les tables de `master_data` (`communes`, `postal`, `nis_changes`, `entities`,
`crosswalks`) ont été construites par couches successives et n'ont aucune
convention commune :
- les niveaux s'appellent `MUNICIPALITY/DISTRICT/PROVINCE/REGION` dans le graphe, mais
  `commune` / `arr` / `prov` / `province` dans les colonnes ;
- un même concept (code commune NIS) porte 5 noms (`cd_refnis`, `cd_commune`,
  `cd_commune_nis`, `cd_refnis_old|new`, `code`/`code_from`) ;
- la version s'appelle `nis_version` ou `from_version` ; NUTS 2021 est implicite
  (`cd_nuts3`) alors que 2027 est suffixé (`cd_nuts3_2027`) ;
- deux styles coexistent : `cd_`/`tx_` (tables larges) et sans préfixe (`entities`, `crosswalks`).

Décisions prises avec l'utilisateur : **(1)** convention en **anglais, alignée sur les
nœuds du graphe** ; **(2)** démarche **en deux étapes** : renommage cohérent d'abord
(étape 1), puis bascule vers le modèle long `entities` + `crosswalks` comme modèle
canonique (étape 2). L'exécution se fait **en local** (R requis ; R n'est pas installé dans le
container cloud).

---

## Convention de nommage (à appliquer partout)

Format : **`<rôle>_<sujet>[_<qualificatif>][_<langue>]`**, en snake_case anglais.

| Rôle | Usage |
|---|---|
| `code_` | un code de classification (toujours `character`) |
| `label_` | un libellé ; suffixe de langue `_fr` / `_nl` toujours en dernier |
| `version` / `version_from` / `version_to` | discriminant de version |
| `classification` / `classification_from` / `classification_to` | id de nœud (`CLS_*`) |
| `relation`, `nature`, `weight` | inchangés |

**Règle du sujet = nœud du graphe** : le nom de colonne se dérive mécaniquement de l'id
du nœud : `tolower(id)`, **sans** la version NIS (portée par la colonne `version` de la
ligne), **avec** la version pour NUTS / NBB (qui vivent comme colonnes sur une ligne NIS).

| Nœud | Colonne code | Colonnes libellé |
|---|---|---|
| `NIS_MUNICIPALITY_*` | `code_nis_municipality` | `label_nis_municipality_fr/_nl` |
| `NIS_DISTRICT_*` | `code_nis_district` | `label_nis_district_fr/_nl` |
| `NIS_PROVINCE_*` | `code_nis_province` | `label_nis_province_fr/_nl` |
| `NIS_REGION_*` | `code_nis_region` | `label_nis_region_fr/_nl` |
| `NIS_COUNTRY` | `code_nis_country` | — |
| `NUTS_MUNICIPALITY_2021` | `code_nuts_municipality_2021` | — |
| `NUTS_DISTRICT_2021` | `code_nuts_district_2021` | `label_nuts_district_2021_fr/_nl` |
| `NUTS_PROVINCE_2021` | `code_nuts_province_2021` | — |
| `NUTS_REGION_2021` | `code_nuts_region_2021` | — |
| `NUTS_COUNTRY` | `code_nuts_country` | — |
| `NUTS_*_2027` | `code_nuts_district_2027`, `code_nuts_province_2027`, `code_nuts_region_2027`, `code_nuts_country_2027` | — |
| `NBB_DISTRICT_2021` | `code_nbb_district_2021` | — |
| `POSTAL` | `code_postal` | `label_postal_fr/_nl` |

Les **noms de tables** suivent aussi le graphe : `communes` → `municipalities`.

---

## Correspondance complète ancien → nouveau

### `communes` → `municipalities`
| Ancien | Nouveau |
|---|---|
| `cd_commune` | `code_nis_municipality` |
| `tx_commune_fr` / `tx_commune_nl` | `label_nis_municipality_fr` / `_nl` |
| `cd_arr` | `code_nis_district` |
| `tx_arr_fr` / `tx_arr_nl` | `label_nis_district_fr` / `_nl` |
| `cd_arr_2digit` | **supprimée** (seul usage : sa création, `R/02_build_master_table.R:421`) |
| `cd_province` | `code_nis_province` |
| `tx_prov_fr` / `tx_prov_nl` | `label_nis_province_fr` / `_nl` |
| `cd_region` | `code_nis_region` |
| `tx_region_fr` / `tx_region_nl` | `label_nis_region_fr` / `_nl` |
| `cd_nis_country` | `code_nis_country` |
| `cd_nuts_lau` | `code_nuts_municipality_2021` |
| `cd_nuts3` / `cd_nuts2` / `cd_nuts1` / `cd_nuts0` | `code_nuts_district_2021` / `_province_2021` / `_region_2021` / `code_nuts_country` |
| `tx_nuts3_fr` / `tx_nuts3_nl` | `label_nuts_district_2021_fr` / `_nl` |
| `cd_nuts3_2027` / `cd_nuts2_2027` / `cd_nuts1_2027` / `cd_nuts0_2027` | `code_nuts_district_2027` / `_province_2027` / `_region_2027` / `code_nuts_country_2027` |
| `cd_arr_internal` | `code_nbb_district_2021` |
| `nis_version` | `version` |

### `postal`
| `cd_postal` → `code_postal` · `cd_commune_nis` → `code_nis_municipality` · `tx_postal_name_fr/_nl` → `label_postal_fr/_nl` · `nis_version` → `version` |
|---|

### `nis_changes`
| `cd_refnis_old` → `code_from` · `cd_refnis_new` → `code_to` · `from_version` → `version_from` · **nouvelle** `version_to` (`"2019"` pour BEFORE_2019, `"2025"` pour 2019) · `nature` inchangé |
|---|

### `entities`
| `classification_id` → `classification` · `code` inchangé · `name_fr/_nl` → `label_fr/_nl` |
|---|

### `crosswalks`
| `from_id` → `classification_from` · `to_id` → `classification_to` · `code_from`, `code_to`, `relation`, `nature` inchangés |
|---|

`code_from`/`code_to`/`weight` (poids de split, API publique) **ne changent pas**.
`standard_weights` (`variable, vintage, year, code, value`) reste tel quel.

### Hors périmètre
- **Couche de parsing brut** (`R/01_load_data.R` : `cd_refnis`, `tx_descr_fr`, `cd_refnis_before2019`…) :
  ces noms reflètent les fichiers source Statbel. Ils restent internes à la build. Les noms
  canoniques s'appliquent à partir de la sortie de `build_master_table()`. À dire dans un
  commentaire en tête de `01_load_data.R`.
- **Jeux d'exemple** (`rc_communes_2019`, `rc_postal`…, colonnes `cd_commune`, `nom_fr`…) : ce
  sont des données « utilisateur » qui illustrent `convert_dataset(dt, "cd_commune", …)`, on n'y
  touche pas.
- Variables locales (`from_norm`, `code_col` comme champ de registre…) : inchangées.

---

## ÉTAPE 1 — Renommage cohérent (une PR, version 2.0.0)

### 1.1 Source unique de vérité pour le schéma — `R/00_config.R`
1. Ajouter une constante **`SCHEMA_V1_TO_V2`** : liste nommée par table
   (`communes`, `postal`, `nis_changes`, `entities`, `crosswalks`), chacune étant un vecteur
   nommé `c(ancien = "nouveau")` reprenant exactement les tableaux ci-dessus. Elle sert à
   la migration des anciens snapshots (1.3) et de référence aux tests.
2. Réécrire `MASTER_COMMUNE_CORE_COLS` / `MASTER_COMMUNE_KNOWN_COLS` avec les nouveaux noms
   (renommer aussi en `MASTER_MUNICIPALITY_CORE_COLS` / `_KNOWN_COLS`), retirer `cd_arr_2digit`.
3. `MASTER_FLAT_TABLES` : `"communes"` → `"municipalities"`.
4. Commentaires des arêtes `CONVERSION_GRAPH_EDGES` qui citent `cd_nuts3`, `cd_arr_internal`…
   (≈l. 427-460) : mettre à jour.
5. Ajouter un helper (`@noRd`) **`.node_code_col(id)`**, qui implémente la règle de
   dérivation (NIS : retirer le suffixe de version ; `NUTS_COUNTRY` → `code_nuts_country`).
   Il ne sert qu'aux tests (1.5) : le registre garde ses colonnes explicites, pour rester
   lisible.

### 1.2 Registre — `R/00b_registry.R`
- Dans chaque entrée de `CLASSIFICATION_NODES`, mettre à jour `source_table`
  (`"communes"` → `"municipalities"`), `code_col`, `label_fr_col`, `label_nl_col` selon la
  correspondance.
- `.node_reference_codes()` (≈l. 338-360) : `classification_id` → `classification`,
  `name_fr/_nl` → `label_fr/_nl` ; le fallback sur les tables larges utilise
  `version` au lieu de `nis_version`.

### 1.3 Build et chargement
**`R/02_build_master_table.R`** (le plus gros morceau) :
- `build_postal_*` (l. 13, 43) : `setnames` direct vers `code_postal, code_nis_municipality,
  label_postal_fr, label_postal_nl`.
- l. 179-186 (internal map NUTS3 → NBB) et l. 370-433 (assemblage communes) : produire
  directement les noms canoniques (les `setnames` existants l. 370-388 visent les
  nouveaux noms). Supprimer la création de `cd_arr_2digit` (l. 421) et l'ajuster dans `setcolorder`.
  **Garde-fou** : l'arithmétique entière (`%/% 1000L`, modulo) se fait toujours *avant*
  `.stringify_code_columns()`, il ne faut pas déplacer ce point.
- `add_nuts2021_columns_2025()` (l. 464-560) : `cd_commune_2025`, `cd_nuts3`, `cd_nuts_lau`,
  `cd_arr_internal` → nouveaux noms.
- Étape `nis_changes` unifiée (l. 265-310) : `code_from`, `code_to`, `nature`,
  `version_from`, `version_to` ; mettre à jour `.assert_unique_keys(…, c("version_from","code_from"))`
  et `.assert_cols`.
- `build_entities_table()` / `build_crosswalks()` (l. 588-950) : nouveaux noms de colonnes
  (`.xw()` produit `classification_from`, `classification_to` ; `.pairs_xw` reçoit les
  nouveaux noms de colonnes ; tous les `m19$cd_commune`, `p19$cd_postal`, etc.).
- `.stringify_code_columns()` : la détection des colonnes code doit passer de `^cd_` à
  `^code_` (le vérifier dans sa définition).
- `.validate_commune_schema()` → `.validate_municipality_schema()`.
- Liste retournée : `municipalities = …`.

**`R/08_load_prebuilt.R`** — `load_master_data()` / `save_master_tables()` :
- Écrire `municipalities.rds` (supprimer `communes.rds` de `inst/extdata/`).
- Ajouter **`.migrate_schema_v1()`** (`@noRd`) : si l'objet chargé contient `communes`
  (ou une colonne de l'ancien schéma), le renommer via `SCHEMA_V1_TO_V2` (`setnames(…, skip_absent = TRUE)`),
  ajouter `version_to`, supprimer `cd_arr_2digit`, et émettre **un** warning typé
  `rcl_legacy_schema` (classe à créer, comme les autres `rcl_*`). On peut ainsi charger un
  snapshot v1 sans tout reconstruire, et c'est aussi le **moyen de produire les nouveaux `.rds`**
  si les fichiers bruts `data/raw/` ne sont pas disponibles (voir 1.6).

### 1.4 Code runtime (substitution mécanique, fichier par fichier)
Ordre conseillé (les dépendances d'abord) : `03_convert.R` → `05_conversion_check.R` →
`07_detect.R` → `07_diagnose.R` → `09_query.R` → `07_split_ambiguous.R` →
`07_dataset_convert.R` → `10_rebase.R` → `06_visualize.R` → `00c_nomenclature.R` →
`04_fuzzy_match.R` → `classifications.R`.
- `03_convert.R` : `md$crosswalks[from_id == from & to_id == to]` →
  `classification_from == from & classification_to == to` (l. 152, 252, 345, 353 et la clé de cache l. 299).
- Partout : `md$communes` / `master_data$communes` → `$municipalities` ; `nis_version ==` →
  `version ==` ; `from_version` → `version_from`.
- `06_visualize.R:394` : `cd_nuts3` / `tx_nuts3_fr` → nouveaux noms.
- **`R/nbbbenuts-package.R`** (l. 20-50, `utils::globalVariables`) : remplacer la liste
  par les nouveaux noms (sinon `R CMD check` émet des NOTE « no visible binding »).

Commande pour repérer ce qui reste après chaque fichier :
```bash
grep -rnwE "cd_commune|cd_commune_nis|cd_arr|cd_arr_internal|cd_arr_2digit|cd_province|cd_prov|cd_region|cd_nis_country|cd_nuts_lau|cd_nuts[0-3](_2027)?|cd_postal|tx_(commune|arr|prov|province|region|nuts3|postal_name)_(fr|nl)|nis_version|from_version|cd_refnis_(old|new)|from_id|to_id|classification_id|name_fr|name_nl" R/ tests/ vignettes/ inst/ --include=*.R --include=*.Rmd --include=*.md
```
Les seules occurrences légitimes en fin d'étape : `R/01_load_data.R` (couche de parsing),
`SCHEMA_V1_TO_V2`, `.migrate_schema_v1()`, `R/data.R` et les jeux d'exemple.

### 1.5 Tests — `tests/testthat/`
- `helper-master_data.R` : adapter le chargement / les fixtures.
- Substitution mécanique dans tous les `test-*.R` (≈20 fichiers ; les plus touchés :
  `test-load-data.R`, `test-build-guards.R`, `test-crosswalks-parity.R`, `test-temporal-nature.R`,
  `test-lau-bijection.R`, `test-nis-country.R`, `test-registry-consistency.R`).
- `fixtures/golden_crosswalks.rds` : **régénérer** via `.migrate_schema_v1()` appliqué à
  l'ancien golden, puis vérifier qu'il est identique, au nom de colonnes près, avant/après :
  ```r
  old <- readRDS("tests/testthat/fixtures/golden_crosswalks.rds")
  new <- data.table::copy(old); data.table::setnames(new, SCHEMA_V1_TO_V2$crosswalks, skip_absent = TRUE)
  stopifnot(identical(unname(as.list(old)), unname(as.list(new))))
  saveRDS(new, "tests/testthat/fixtures/golden_crosswalks.rds")
  ```
- **Nouveau `test-schema.R`** :
  1. pour chaque nœud `source_table == "municipalities"`, `code_col == .node_code_col(id)` ;
  2. toutes les colonnes de `municipalities`, `postal`, `nis_changes`, `entities`,
     `crosswalks` respectent `^(code|label|version|classification)(_[a-z0-9]+)*$` ou
     appartiennent à `c("relation","nature","weight")` ;
  3. toute colonne `code_*` est `character` ;
  4. `.migrate_schema_v1()` sur un mini objet v1 renvoie le schéma v2 et lève `rcl_legacy_schema`.

### 1.6 Données, docs, version
1. Reconstruire le snapshot :
   - **avec** `data/raw/` : `rebuild_master_data()` ;
   - **sans** : `md <- suppressWarnings(load_master_data())` (migration),
     puis `save_master_tables(md)`, puis supprimer `inst/extdata/communes.rds`.
   Dans les deux cas, comparer avec l'ancien snapshot : mêmes `nrow`, et contenus identiques au
   renommage près (même script que pour le golden, table par table).
2. `devtools::document()` (le roxygen de `CLASSIFICATION_NODES`, `load_master_data`,
   `get_crosswalk`… mentionne les anciennes colonnes : les mettre à jour avant).
3. `DESCRIPTION` : `Version: 2.0.0`.
4. `NEWS.md` : section « Breaking changes » avec le tableau de correspondance, et une note
   sur la migration automatique des snapshots v1 (warning `rcl_legacy_schema`).
5. `CLAUDE.md` : section « Facts » : `communes` → `municipalities`, colonnes `code_*`,
   convention de nommage (et pointer vers `test-schema.R`).
6. Vignettes / README : grep et mise à jour des exemples qui lisent `master_data$communes`.

### 1.7 Commits suggérés (une PR)
1. `config+registry: introduce v2 schema constants and node column names`
2. `build: emit canonical v2 column names; drop cd_arr_2digit`
3. `runtime: switch all readers to v2 schema`
4. `load: migrate v1 snapshots with rcl_legacy_schema warning`
5. `tests: adapt suite, regenerate golden, add test-schema.R`
6. `data+docs: rebuild extdata, document(), NEWS, bump 2.0.0`

---

## ÉTAPE 2 — Modèle long canonique (PR séparée, après merge de l'étape 1)

État actuel utile : le moteur de conversion lit **déjà** uniquement `md$crosswalks`
(`R/03_convert.R:146-400`), et `.node_reference_codes()` préfère déjà `md$entities`.
Les tables larges ne servent plus qu'aux libellés, à la hiérarchie, à la détection, au
rebase, au split et aux visualisations.

1. **Inventaire** : `grep -n "\$municipalities\|\$postal\|\$nis_changes" R/*.R` hors
   `02_build_master_table.R`. Chaque lecture runtime doit se réécrire contre
   `entities` (codes, libellés) ou `crosswalks` (liens, hiérarchie via arêtes `N:1`,
   transitions temporelles via `nature`).
2. **Compléter les tables longues** pour qu'elles se suffisent :
   - `entities` : ajouter `version` (redondant avec l'id, mais filtrable) et, si besoin,
     `code_parent` n'est **pas** ajouté (la hiérarchie vit dans `crosswalks`) ;
   - `crosswalks` : déjà complet (`classification_from/to`, `code_from/to`, `relation`, `nature`).
3. **Helpers d'accès uniques** (`@noRd`, dans `00b_registry.R`) :
   `.entities_of(id, md)`, `.links(from, to, md)`, `.parent_of(id, md)` (BFS d'un pas sur une arête
   N:1). Tous les modules runtime passent par eux.
4. **Registre** : `source_table` / `code_col` / `label_*_col` / `version_filter` ne servent plus
   qu'à la build. Les déplacer dans un bloc `build = list(...)` de chaque nœud, ou les sortir
   du registre public.
5. **Tables larges = build-time** : `municipalities`, `postal` et `nis_changes` restent
   produites par la build (elles alimentent `build_entities_table()` / `build_crosswalks()`)
   mais ne sont **plus persistées** dans `inst/extdata/`. Fournir un accesseur exporté
   `wide_view(md, version = "2019")`, qui reconstruit une table large depuis le modèle long,
   pour les utilisateurs qui s'en servaient.
6. Tests : `test-route-parity.R` et `test-crosswalks-parity.R` restent les filets.
   Ajouter un test d'aller-retour `wide_view()` ≡ ancienne table large (golden).
7. Version 2.1.0 (ou 3.0.0 si on retire les tables larges de `load_master_data()` sans alias).

---

## Vérification (en local, à chaque commit de l'étape 1)
```r
devtools::load_all(".")
devtools::test()                       # référence AVANT de commencer : noter le nb de tests verts
devtools::test(filter = "schema")      # nouveau test de convention
devtools::test(filter = "route-parity|crosswalks|temporal|lau")
devtools::document()
devtools::check()                      # 0 error / 0 warning ; pas de nouvelle NOTE "no visible binding"
```
Contrôles fonctionnels de bout en bout :
```r
md <- load_master_data()
names(md); names(md$municipalities)                  # uniquement code_* / label_* / version
convert_codes("63000", "NIS_DISTRICT_2019", "NUTS_DISTRICT_2021", md)  # Verviers -> BE335 + BE336
convert_dataset(rc_communes_2019, "cd_commune", to = "NUTS_DISTRICT_2021", md)
get_crosswalk("NIS_MUNICIPALITY_2019", "NIS_MUNICIPALITY_2025", md)
rebase_series(...)   # exemple de la doc de 10_rebase.R
# Snapshot v1 : doit charger avec un seul warning rcl_legacy_schema
```
Critère de fin : les résultats de conversion sont strictement identiques avant et après
(golden des crosswalks identique au renommage près, et suite de tests au même nombre de tests verts + `test-schema.R`).

Branche : `claude/funny-einstein-7iubz9` (ne jamais pousser sur `main`).
