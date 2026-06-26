# Plan — Arête `NUTS_DISTRICT_2021 → NUTS_DISTRICT_2027` avec splitting pondéré

> Plan d'implémentation validé. À appliquer **en local** (R + readxl requis pour le rebuild et les
> tests). Cette branche ne contient pour l'instant que le plan ; l'implémentation suit.

## Context

Aujourd'hui `convert_codes("BE211", "NUTS_DISTRICT_2021", "NUTS_DISTRICT_2027", md, allow_ambiguous = TRUE)`
**échoue** (`rcl_no_route`). Cause : l'exécuteur compose uniquement sur le **graphe des
crosswalks matérialisés** (`.xw_graph`/`.xw_path`, `R/03_convert.R`) et n'inverse jamais les
arêtes ; depuis `NUTS_DISTRICT_2021` il ne peut pas redescendre au niveau commune, donc aucun
chemin vers un nœud 2027. Le démo (`demo/demo.R:152-157`) montre pourtant un aller-retour
2021↔2027 → **exemple cassé**.

Besoin opérationnel (vital pour l'utilisateur) : convertir des **codes** NUTS3 2021 → NUTS3 2027,
avec des **poids** pour les quelques cas ambigus. Résultat visé : une arête directe `1:N`,
exécutable avec `allow_ambiguous = TRUE`, réutilisant le moteur de poids générique existant.

### Avis critique (honnête) — à garder en tête
- **Bonne idée, bien cadrée, faible risque technique** : le moteur de poids
  (`register_split_weights`/`split_ambiguous`, `R/07_split_ambiguous.R`) est **entièrement
  générique** (aucune modif moteur), et un **précédent exact** existe :
  `NIS_MUNICIPALITY_2025 → NUTS_DISTRICT_2021` (`1:N`, `no_reverse`, `ambiguous_codes`, poids).
- **Réserve de fond** : la conversion est intrinsèquement **une approximation**. Un NUTS3 2021 =
  agrégat de communes **2019** ; un NUTS3 2027 = agrégat de communes **2025**. L'arête encode *à la
  fois* les fusions 2019→2025 et la redéfinition NUTS. Les poids ne sont exacts que pour des
  valeurs **additives** (totaux/effectifs) — faux pour taux/indices sauf en mode `ratio`.
- **Bonne nouvelle** : l'ambiguïté est **minuscule** (≈ 3 communes « cross-NUTS3 » : 46029, 46030,
  71072 → quelques codes 2021 seulement, ex. `BE211 → {BE261, BE276}`). ~99 % des NUTS3 2021 → 1
  seul NUTS3 2027 (exact).
- **Recommandation** : implémenter **un crosswalk direct pré-calculé au build** (ne PAS ouvrir les
  descentes génériques NUTS3→commune, qui rendraient exécutables des tas d'autres conversions
  lossy non voulues). Positionner cette arête comme **raccourci de commodité**, en gardant
  « porter les données au niveau commune » comme méthode canonique dans la doc.

Implémentation **en local** (R + readxl ; indispo dans l'env de planification). Nouvelle branche
dédiée.

---

## Justification architecturale (build-time vs runtime)

Deux moments distincts dans la vie du package :
- **Build** = fabrication du snapshot de données. Rare, lancé par le mainteneur via
  `rebuild_master_data()` → exécute `build_master_table()`/`build_crosswalks()`
  (`R/02_build_master_table.R`), lit les Excel bruts, calcule toutes les tables et les **fige**
  dans `inst/extdata/*.rds`.
- **Runtime** = usage courant. `convert_codes()` (`R/03_convert.R`) charge le `.rds` figé
  (`load_master_data()`) et fait des **lookups** dans la table `crosswalks` déjà calculée. Ne
  relit jamais les sources, ne recompose rien de lourd.

Analogie : build = *pré-calculer/compiler une table de correspondance* ; runtime = *consulter*
cette table.

**Notre arête est calculée au BUILD** : le chaînage par les communes (`m19`→`nis_changes`→`m25`)
tourne une fois dans `build_crosswalks()` et produit des lignes `(nuts3_2021, nuts3_2027)`
matérialisées. Au runtime, `convert_codes("BE211", …)` n'est qu'un `md$crosswalks[from_id==… &
to_id==…]` — instantané, déterministe, **aucun** chaînage commune live.

**Alternative rejetée — composer au RUNTIME via des arêtes de descente.** Il faudrait matérialiser
`NUTS_DISTRICT_2021 → NUTS_MUNICIPALITY_2021` (agrégation inverse 1:N) pour que `.xw_path` trouve le
chemin à l'exécution. Conséquences :
1. **Pollution du graphe** : le BFS de l'exécuteur rendrait alors exécutables des dizaines de
   descentes lossy non voulues (`province → commune`, `région → commune`, …). L'arête directe
   n'expose la descente que pour cette paire.
2. **Ancrage des poids dégradé** : l'ambiguïté ne porte plus sur ~3 codes 2021 mais sur *chaque*
   NUTS3 (un NUTS3 → des dizaines de communes), forçant des poids en parts communales — soit
   reconstruire l'info communale à partir d'agrégé.
3. **Runtime plus lourd** (fan-out commune par commune + re-dédup) pour un résultat identique.

**Single source of truth préservée** : le crosswalk direct est une **projection dérivée** des mêmes
tables communales (pas une vérité indépendante), et le **test anti-dérive** (§6) verrouille que
`ambiguous_codes` == réalité du crosswalk reconstruit. Donc « passer formellement par
NIS_MUNICIPALITY » est respecté — au build, pas au runtime.

NB : pour des données **au niveau commune** (Cas 1), ne pas utiliser cette arête — convertir les
communes directement vers 2027 (exact, sans poids). L'arête NUTS3 2021→2027 sert au Cas 2 (on n'a
que de l'agrégé NUTS3 2021).

## 1. Construire le crosswalk — `R/02_build_master_table.R`

Dans `build_crosswalks()`, bloc « NUTS 2027 hierarchy » (après `NUTS_REGION_2027__NUTS_COUNTRY`,
~ligne 726). `m19`, `m25`, `nis_changes` sont déjà en scope.

**Principe** : chaîner au niveau commune sur NIS 2019 — `2019 commune → cd_nuts3 (2021)` ET
`→ commune 2025 (via nis_changes, sinon même code) → cd_nuts3_2027`. Puis `unique(2021, 2027)`.
⚠️ **Ne PAS** construire depuis `m25` seul : les 3 communes ambiguës ont `cd_nuts3` (2021) = NA
dans le backfill m25 → on perdrait précisément les cas ambigus.

```r
  # ---- NUTS_DISTRICT_2021 -> NUTS_DISTRICT_2027 (derived, 1:N) --------------
  ch19_n27 <- nis_changes[from_version == VER_2019, .(cd_refnis_old, cd_refnis_new)]
  link2025 <- merge(data.table(cd_commune = unique(m19$cd_commune)),
                    ch19_n27, by.x = "cd_commune", by.y = "cd_refnis_old", all.x = TRUE)
  link2025[is.na(cd_refnis_new), cd_refnis_new := cd_commune]   # unchanged keep their code

  n3_2021 <- unique(m19[!is.na(cd_nuts3),      .(cd_commune, cd_nuts3)])
  n3_2027 <- unique(m25[!is.na(cd_nuts3_2027), .(cd_commune, cd_nuts3_2027)])

  chain <- merge(link2025, n3_2021, by = "cd_commune", all.x = FALSE)
  chain <- merge(chain, n3_2027, by.x = "cd_refnis_new", by.y = "cd_commune", all.x = FALSE)
  pairs_21_27 <- unique(chain[!is.na(cd_nuts3) & !is.na(cd_nuts3_2027),
                              .(cd_nuts3, cd_nuts3_2027)])

  xw[["NUTS_DISTRICT_2021__NUTS_DISTRICT_2027"]] <- .xw(
    "NUTS_DISTRICT_2021", "NUTS_DISTRICT_2027",
    pairs_21_27$cd_nuts3, pairs_21_27$cd_nuts3_2027)
```

`.xw()` estampille `relation = .rel(...) = "1:N"` (depuis l'arête déclarée) et `nature = NA`.

## 2. Déclarer l'arête — `R/00_config.R`

Remplacer le bloc-commentaire ~370-378 (« NO direct NUTS_DISTRICT_2021↔2027 edge ») et ajouter,
dans la section NUTS 2027, une arête **calquée sur `NIS_MUNICIPALITY_2025 → NUTS_DISTRICT_2021`** :

```r
  list(from = CLS_NUTS_DISTRICT_2021, to = CLS_NUTS_DISTRICT_2027,
       relation = "1:N", via = "derived",
       no_reverse = TRUE,
       ambiguous_codes = c("BE211"),   # PLACEHOLDER — fixer via le test anti-dérive (§6)
       coverage = "NN/44",             # PLACEHOLDER — fixer après rebuild
       notes = paste0(
         "Derived at commune level (2019 -> cd_nuts3 2021 AND -> NIS 2025 -> cd_nuts3_2027). ",
         "3 cross-province fusions (46029/46030/71072) make some 2021 NUTS3 map to >1 2027 NUTS3 ",
         "(1:N, e.g. BE211 -> {BE261, BE276}). allow_ambiguous = TRUE ; weights via ",
         "register_split_weights(). no_reverse = TRUE: reverse is also 1:N and unexecutable.")),
```

**Décision de cardinalité — `1:N` + `no_reverse = TRUE` (et surtout PAS `M:N`)** :
- La vraie relation est M:N (sens inverse aussi 1:N). Mais déclarer `1:N` + `no_reverse` reproduit
  exactement le pattern de l'analogue existant et **force `allow_ambiguous`** au runtime (idem M:N
  côté comportement), **sans réintroduire la seule arête M:N du graphe** (le codebase n'en a plus
  depuis le fix Brabant ; cf. commentaire `test-perimeter-semantics.R:43`).
- `no_reverse = TRUE` est **obligatoire** : sinon `build_conversion_graph()` synthétise une arête
  inverse `2027→2021` sans crosswalk correspondant (l'exécuteur n'inverse pas) → chemin déclaré
  mais inexécutable → `test-route-parity.R` casse.
- `ambiguous_codes` ici = **codes NUTS3 caractère** (pas integer comme l'analogue commune).
- Aucun nouveau nœud (les deux existent déjà) → `VALID_CLASSIFICATIONS` inchangé.

## 3. Sens inverse `2027 → 2021` — **hors périmètre**

Ne pas matérialiser. `no_reverse` supprime l'auto-reverse ; pas de crosswalk inverse → le sens
inverse reste non-direct (chemin indirect non-simple, erreur sans `allow_ambiguous`). Si besoin
futur : ajouter symétriquement `xw[["NUTS_DISTRICT_2027__NUTS_DISTRICT_2021"]]` + une 2ᵉ arête
`no_reverse=TRUE` — **changement séparé**.

## 4. Poids — aucun changement moteur

Générique confirmé. Workflow utilisateur après rebuild :
```r
tpl <- split_weights_template("NUTS_DISTRICT_2021", "NUTS_DISTRICT_2027", md)  # poids égaux
tpl[code_from=="BE211" & code_to=="BE261", weight := 0.97]
tpl[code_from=="BE211" & code_to=="BE276", weight := 0.03]
register_split_weights("NUTS_DISTRICT_2021", "NUTS_DISTRICT_2027", tpl)
split_ambiguous(dt, "nuts3", value_cols="emp", from="NUTS_DISTRICT_2021",
                to="NUTS_DISTRICT_2027", md, value_type="additive")   # ou rebase_series(split=tpl)
```
Clé registre : `NUTS_DISTRICT_2021__NUTS_DISTRICT_2027__population`. La colonne cible de sortie est
`cd_nuts3_2027` (`default_col_name`, `R/07_dataset_convert.R:188`).

## 5. Docs

- **`R/classifications.R`** : (a) ajouter la ligne table `| NUTS_DISTRICT_2021 | NUTS_DISTRICT_2027 | (!) 1:N |` ;
  (b) réécrire la note « no direct conversion » → arête directe **1:N** (sens
  2021→2027 seulement, `allow_ambiguous` requis ; inverse toujours via NIS). `devtools::document()` après.
- **`DOCUMENTATION.md`** : exemples/notes 2021↔2027 (« pas de lien direct » → « lien direct 1:N
  2021→2027 »).
- **`R/00_config.R`** : bloc-commentaire ~370-378 (couvert §2).
- **`demo/demo.R:152-157`** : ajouter `allow_ambiguous = TRUE` au sens forward (sinon
  `rcl_ambiguous_conversion`) ; garder le sens inverse en `tryCatch` (toujours en erreur) ou le retirer.

## 6. Tests

- **Réécrire** `tests/testthat/test-conversions.R` Test 11 : forward sans
  `allow_ambiguous` → toujours `rcl_ambiguous_conversion` ; **avec** `allow_ambiguous=TRUE` →
  succès, `BE211` rend 2 lignes `{BE261, BE276}`, un code inchangé (`BE100`) rend 1 ligne ;
  `check_conversion_path(...)$is_simple == FALSE` ; inverse 2027→2021 toujours en erreur.
- **Ajouter** : (a) test split pondéré (registre + `split_ambiguous`, somme préservée, poids
  respectés sur `cd_nuts3_2027`) — calqué sur `test-split-registry.R` SR7 / `test-conversions.R`
  Test 13 ; (b) **test anti-dérive** dans `test-crosswalks-parity.R`, calqué sur le bloc
  `NIS_MUNICIPALITY_2025 → NUTS_DISTRICT_2021` :
  ```r
  e  <- Find(function(x) x$from==CLS_NUTS_DISTRICT_2021 && x$to==CLS_NUTS_DISTRICT_2027, CONVERSION_GRAPH_EDGES)
  xw <- md$crosswalks[from_id==CLS_NUTS_DISTRICT_2021 & to_id==CLS_NUTS_DISTRICT_2027]
  real_ambig <- xw[, .N, by=code_from][N>1L, sort(code_from)]    # caractère
  expect_setequal(e$ambiguous_codes, real_ambig)
  ```
  → c'est **ce test** qui fournit la valeur exacte de `ambiguous_codes`/`coverage` (lire
  `real_ambig` au 1ᵉʳ run, puis renseigner §2 **avant** de lancer la suite).
- **Régénérer** `tests/testthat/fixtures/golden_crosswalks.rds` via `gen_golden()` (itère toutes
  les clés crosswalks → capte la nouvelle arête automatiquement).
- Re-vérifier `test-perimeter-semantics.R` (nouvelle ligne `overlap`, filtres par from/to → OK).

## 7. Rebuild & vérification (local)

```r
devtools::load_all(".")
rebuild_master_data()                                   # régénère inst/extdata/*.rds + crosswalk
md <- load_master_data()
md$crosswalks[from_id=="NUTS_DISTRICT_2021" & to_id=="NUTS_DISTRICT_2027",
              .N, by=code_from][N>1]                    # <- fixer ambiguous_codes/coverage ICI
convert_codes("BE211","NUTS_DISTRICT_2021","NUTS_DISTRICT_2027", md, allow_ambiguous=TRUE)  # 2 lignes
convert_codes("BE100","NUTS_DISTRICT_2021","NUTS_DISTRICT_2027", md, allow_ambiguous=TRUE)  # 1 ligne
source("tests/testthat/helper-golden.R"); gen_golden()  # APRÈS avoir figé ambiguous_codes
devtools::document(); devtools::test(); devtools::check()
```
**Ordre critique** : renseigner `ambiguous_codes`/`coverage` (depuis le sanity-check) **avant**
`devtools::test()`, sinon le test anti-dérive échoue.

## Fichiers critiques
- `R/02_build_master_table.R` — bloc de build du crosswalk (§1).
- `R/00_config.R` — arête + bloc-commentaire (§2).
- `R/classifications.R` — table + note (§5), puis `devtools::document()`.
- `tests/testthat/test-conversions.R` — réécriture Test 11 + tests ajoutés (§6).
- `tests/testthat/test-crosswalks-parity.R` — test anti-dérive (§6).
- `demo/demo.R`, `DOCUMENTATION.md` — exemples/notes (§5).
- Régénérés : `inst/extdata/*.rds`, `tests/testthat/fixtures/golden_crosswalks.rds`, `man/*.Rd`.

## Risques / arêtes vives
- **`no_reverse = TRUE` non négociable** (sinon parité graphe↔exécuteur cassée).
- **Ne pas déclarer `M:N`** : réintroduirait la seule M:N du graphe ; `1:N`+`no_reverse` = même
  comportement runtime.
- **Test 11 casse jusqu'à réécriture** — c'est le changement de comportement attendu (à signaler).
- **`ambiguous_codes` caractère** (NUTS3), comparaison `sort(code_from)` caractère des deux côtés.
- **Golden obligatoire à régénérer** (sinon `test-crosswalks-golden.R` échoue sur la nouvelle arête).
- **Approximation assumée** (cf. avis critique) : documenter le mode `ratio` pour les valeurs non
  additives, et garder la voie commune-niveau comme canonique.
