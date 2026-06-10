# Plan — Conserver `NUTS_LAU_2021` (documenté) + centraliser les noms (`CLS_*` / `VER_*`)

> Document de travail pour exécution **en local**. Deux chantiers de propreté **indépendants**,
> postérieurs au refactor crosswalks (déjà mergé sur `main`). Exclu du package build via
> `.Rbuildignore`.

## Context

1. **`NUTS_LAU_2021` : on garde, on documente.** LAU 2021 (niveau Eurostat) ≡ code commune
   NIS 2019 *en Belgique* (bijection 1:1 ; `cd_nuts_lau` ≡ `cd_commune`). La redondance est sur la
   **valeur**, pas sur la **sémantique** : LAU est le niveau local *standard* de la hiérarchie NUTS
   (LAU ⊂ NUTS3 ⊂ NUTS2 ⊂ NUTS1 ⊂ NUTS0). Le retirer casserait l'API, amputerait la hiérarchie NUTS
   et irait à l'encontre du principe « 1 nœud = 1 (système, version, niveau) ». Décision retenue
   après arbitrage : **conserver + documenter la bijection** (coût quasi nul, zéro breaking change).
2. **Centraliser les identifiants de nomenclatures et de versions** en constantes (`CLS_*`,
   `VER_*`) déclarées une fois, pour éliminer les littéraux dispersés (typo silencieux, renommage
   facile).

Contexte post-refactor : le moteur est générique (crosswalks) → **plus de `if (from == "...")`**
dans `R/03_convert.R`. La vérité des ids = `names(CLASSIFICATION_NODES)` + `VALID_CLASSIFICATIONS`
(dérivé des arêtes) ; un id invalide est déjà attrapé au runtime. Les constantes apportent
surtout : **typo détecté au chargement** (vs runtime) + ergonomie/renommage.

---

## Partie A — Garder `NUTS_LAU_2021`, documenter la bijection

Travail **purement documentaire** : aucun changement de code fonctionnel, de graphe, de
crosswalks, de colonnes, ni de RDS/golden ; aucun rebuild ; aucun breaking change. Le compte de
nœuds reste **22**.

- **`R/00b_registry.R`** : commentaire sur l'entrée `NUTS_LAU_2021` — « En Belgique, LAU 2021 =
  code commune NIS 2019 (bijection 1:1) ; labels empruntés à la commune (`tx_commune_fr/nl`). »
- **`R/classifications.R`** : noter la bijection `NIS_COMMUNE_2019 ↔ NUTS_LAU_2021` (1:1, même
  périmètre, étiquette Eurostat).
- **`vignettes/conversions.Rmd`** (+ `DOCUMENTATION.md`) : une phrase — LAU 2021 et la commune
  NIS 2019 désignent le même territoire sous deux systèmes, d'où la conversion 1:1.
- **(Recommandé) Test verrouillant la bijection** — nouveau `tests/testthat/test-lau-bijection.R` :
  pour toutes les communes 2019, `convert_codes(communes, "NIS_COMMUNE_2019", "NUTS_LAU_2021")`
  rend le même code (à la coercition `character` près) et la réciproque
  `NUTS_LAU_2021 → NIS_COMMUNE_2019` est 1:1. Documente **et** garantit la bijection dans le temps
  (alerte si une édition future la rompait).

**Vérification A** : `devtools::test()` reste vert ; `length(VALID_CLASSIFICATIONS) == 22` ;
`convert_codes(.., "NIS_COMMUNE_2019", "NUTS_LAU_2021")` reste 1:1. Aucun rebuild.

---

## Partie B — Centraliser les noms (périmètre **ciblé**, recommandé)

**Arbitrage de périmètre** (verbosité/lisibilité vs sécurité) :
- **`VER_*` (versions)** : **partout** (fort ROI — un `"BEFORE2019"` mal tapé est aujourd'hui
  silencieux).
- **`CLS_*` (ids)** : dans **`CONVERSION_GRAPH_EDGES`** (from/to) et les **tests**.
- **Clés de `CLASSIFICATION_NODES`** : **gardées littérales** (un `setNames()` nuirait à la
  lisibilité de la déclaration de référence) **+ test de cohérence**
  `setequal(names(CLASSIFICATION_NODES), CLS_ALL)`.
- **`build_crosswalks`** (clés `xw[[...]]` / args) : **hors périmètre par défaut** — bloc répétitif
  déjà couvert par le test de couverture + golden ; le churn ne réduit aucun risque non couvert.
  (Optionnel ultérieur.)

**Piège d'ordre de chargement R** : R source `R/*.R` par nom ; `00_config.R` définit
`CONVERSION_GRAPH_EDGES`, `00b_registry.R` définit `CLASSIFICATION_NODES`. Les constantes doivent
exister **avant** → les déclarer **en tête de `R/00_config.R`** (dispo aussi pour `00b`).

- **B1 — Déclarer les constantes** en tête de `R/00_config.R` :
  ```r
  # Versions
  VER_BEFORE_2019 <- "BEFORE_2019"; VER_2019 <- "2019"; VER_2025 <- "2025"
  VER_NUTS_2021   <- "2021";        VER_NUTS_2027 <- "2027"
  # Classification ids (doivent égaler names(CLASSIFICATION_NODES) — 22 nœuds, LAU conservé)
  CLS_NIS_COMMUNE_2019 <- "NIS_COMMUNE_2019"   # ... une constante par nœud (22)
  CLS_ALL <- c(CLS_NIS_COMMUNE_2019, ...)      # pour le test de cohérence
  ```
- **B2 — `CONVERSION_GRAPH_EDGES`** : remplacer les littéraux `from=`/`to=` par les `CLS_*`.
- **B3 — Versions** : remplacer les littéraux par `VER_*` dans `R/02_build_master_table.R`
  (`build_nis_commune_table(version=…)`, slices `communes[nis_version==…]`,
  `nis_changes[from_version==…]`, postal), `R/00b_registry.R` (`version_filter = …` — ce sont des
  *valeurs*, pas des clés : OK), `R/08_load_prebuilt.R` (messages), et tout filtre
  `nis_version ==` / `from_version ==`.
- **B4 — Tests** : utiliser `CLS_*`/`VER_*` dans les appels ; nouveau
  `tests/testthat/test-name-constants.R` : (i) `setequal(CLS_ALL, names(CLASSIFICATION_NODES))` ;
  (ii) chaque `VER_*` est référencé par au moins un nœud / les données.
- **B5 — `normalize_classification_id`** : inchangé (s'appuie sur `VALID_CLASSIFICATIONS`, dérivé
  des arêtes → donc des `CLS_*` après B2).

**Non inclus (assumé)** : clés de `CLASSIFICATION_NODES` (littérales) ; `build_crosswalks` ;
`man/*.Rd` + vignettes (doc) ; les chaînes dans les `.rds` (ce sont des **données** ; valeurs
identiques → **aucun rebuild requis** pour la centralisation seule).

**Vérification B** : `devtools::test()` **inchangé (0 fail / 0 skip) SANS rebuild** = preuve que la
centralisation est iso-comportement ; `test-name-constants` vert. Si un test casse → typo de
constante (corriger, ne pas régénérer).

---

## Ordre & garde-fous
- A et B sont **indépendants** ; faire l'un sans l'autre est possible.
- **Aucun rebuild** requis (ni A documentaire, ni B iso-comportement) → ne pas régénérer
  `inst/extdata/*.rds` ni la fixture golden.
- Fin de chaque volet : `devtools::test()` ; à la toute fin `devtools::document()` +
  `devtools::check()` (0/0/0).
- Réflexe général du dépôt : *si* un changement futur modifie le contenu des crosswalks ou les
  valeurs de `nature`, régénérer `gen_golden()` (jamais supprimer la fixture). Ici, ce n'est pas
  le cas.

## Fichiers touchés (récap)
- **A** : `R/00b_registry.R` (commentaire), `R/classifications.R`, `vignettes/conversions.Rmd`,
  `DOCUMENTATION.md`, `tests/testthat/test-lau-bijection.R` (nouveau).
- **B** : `R/00_config.R` (constantes + `CONVERSION_GRAPH_EDGES`), `R/02_build_master_table.R`,
  `R/00b_registry.R`, `R/08_load_prebuilt.R`, divers tests, `tests/testthat/test-name-constants.R`
  (nouveau).
