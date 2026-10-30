# Plan — Conversions NIS district / province entre versions

> **Statut** : plan à valider (2026-10-30). Remplace la proposition
> `DISTRICT_CROSS_VERSION_EDGE.md` (branche `claude/add-regional-classification-fork-9e9yt`),
> écrite pour la v1.2 (`.ROUTE_TABLE`, `nis_changes`, noms `cd_*`) et incomplète sur les
> données. Branche : `claude/nis-cross-version-levels`, au-dessus de
> `claude/multi-version-convert` (3.0.0, modèle long).

Choix de l'utilisateur : **districts + provinces**, **2025 ↔ 2019 et BEFORE_2019 ↔ 2019**,
**poids de population livrés** par défaut.

## Contexte

Aujourd'hui seuls les niveaux commune ont des liens entre versions
(`NIS_MUNICIPALITY_BEFORE_2019 ↔ 2019 ↔ 2025`). Un dataset au niveau district ou province
ne peut pas changer de version (`rcl_no_route`) ; `convert_multi_version()` refuse donc par
exemple `NIS_DISTRICT_BEFORE_2019 → NIS_PROVINCE_2019`.

## Ce que disent les données

Dérivé des liens communaux de `crosswalks` (commune version A → commune version B, puis
chaque commune → son district / sa province dans sa version) :

| Paire | Liens | Codes ambigus côté source | Codes cibles à plusieurs sources |
|---|---|---|---|
| District 2025 → 2019 | 46 | 46000 (→ 11000, 44000, 46000), 71000 (→ 71000, 73000) | 11000, 44000, 73000 |
| District 2019 → 2025 | 46 | 11000, 44000, 73000 | 46000, 71000 |
| District BEFORE_2019 → 2019 | 48 | 52000, 55000, 56000, 71000 | 51000, 55000, 57000, 58000, 72000 |
| Province 2025 → 2019 | 12 | 40000 (→ 10000, 40000) | 10000 |
| Province 2019 → 2025 | 12 | 10000 | 40000 |
| Province BEFORE_2019 ↔ 2019 | 11 | aucun (1:1) | aucun |

Causes : Moerbeke 44045 (Gent → Sint-Niklaas), Kortessem 73040 (Tongeren → Hasselt),
Zwijndrecht 11056 (Antwerpen → Sint-Niklaas, change de province) en 2025 ; réforme du
Hainaut (arr. 54000 Mouscron supprimé, 58000 La Louvière créé) et Oudsbergen
(71047 Opglabbeek + 72040 Meeuwen-Gruitrode) en 2019. Les codes de districts sont les
mêmes en 2019 et 2025 (43), pas en BEFORE_2019 / 2019.

Toutes ces paires sont **M:N** (sauf provinces BEFORE_2019 ↔ 2019 : 1:1).

## Conception

### 1. Dérivation dans la build — `R/02_build_master_table.R`

Nouveau helper interne `.derive_level_crosswalk(xw_mun, mun_level_from, mun_level_to)` dans
`build_crosswalks()`, appliqué après la construction des liens communaux :

- entrée : les liens `NIS_MUNICIPALITY_<A> → NIS_MUNICIPALITY_<B>` déjà construits (sans NA)
  et les liens commune → niveau de chaque version (`.pairs_xw` existants) ;
- sortie : `unique(district_A, district_B)` (resp. province), **sur les 43 districts / 11
  provinces**, sans repli « code inconnu → même code » ;
- relation : celle observée (`.observed_rel`, déjà en place) — doit coïncider avec l'arête
  déclarée (test d'invariant existant).

**Nature** (obligatoire : `test-invariants.R` exige une nature sur les liens temporels NIS) :
- `UNCHANGED` : district (province) dont le territoire est identique dans les deux versions
  (toutes ses communes restent ensemble, aucune n'entre ni ne sort) ;
- `CHANGE_DSTR` (district) / `CHANGE_PROV` (province) : lien d'un territoire qui gagne ou
  perd des communes — y compris le lien « identité » 46000 → 46000.
- Aucune nouvelle valeur de nature : on réutilise celles des communes.

Paires ajoutées (8) : districts 2025→2019, 2019→2025, BEFORE_2019→2019, 2019→BEFORE_2019 ;
provinces 2025→2019, 2019→2025, BEFORE_2019→2019, 2019→BEFORE_2019.

### 2. Arêtes du graphe — `R/00_config.R`

Huit arêtes explicites (`via = "derived"`, `no_reverse = TRUE` puisque chaque sens est
déclaré), `relation = "M:N"` sauf provinces BEFORE_2019 ↔ 2019 (`"1:1"`), avec
`ambiguous_codes` et une note citant les communes en cause.

### 3. Raccourcis précis commune → niveau d'une autre version (point de vigilance)

Le moteur choisit le chemin le plus court sur les paires de `crosswalks` (simple d'abord,
puis tout chemin). Une nouvelle arête district M:N peut **remplacer un chemin existant plus
précis** à longueur égale. Exemple : `NIS_MUNICIPALITY_2025 → NIS_DISTRICT_2019`
- aujourd'hui : commune 2025 → communes 2019 → districts 2019 ; 46029 Lokeren →
  {44000, 46000} (exact) ;
- avec la nouvelle arête : commune 2025 → district 2025 → districts 2019 ; 46029 →
  {11000, 44000, 46000} (**11000 faux** : Zwijndrecht n'est pas dans Lokeren).

Parade sans toucher au moteur : ajouter les **raccourcis directs** commune → district /
province de l'autre version (calculés au niveau commune, donc exacts), pour chaque paire
qui deviendrait ambiguë par un chemin plus grossier. Un saut direct est toujours préféré.

**Critère bloquant** : avant / après, `convert_codes()` sur **toutes** les paires
exécutables (pas seulement les 5 trajets multi-étapes du golden actuel) donne exactement les
mêmes résultats, sauf pour les paires qui n'avaient aucune route. Ajouter ce contrôle au
golden (`gen_golden()` : section « toutes les paires »).

### 4. Poids — population livrée

`split_weights_template(..., variable = "population")` et `split_ambiguous(weights =
"population")` utilisent déjà la population communale 2019 livrée (2011–2024), dès que
`from` et `to` sont atteignables depuis `NIS_MUNICIPALITY_2019` par un chemin simple.
- **2025 ↔ 2019** (districts et provinces) : fonctionne sans code supplémentaire
  (commune 2019 → commune 2025 est N:1). Ex. poids 46000 → 44000 = population de
  Moerbeke / population du district 46000 (version 2025).
- **BEFORE_2019 ↔ 2019** : fonctionne pour le Hainaut (communes recodées 1:1), **mais pas
  pour 71000 → {71000, 72000}** : Oudsbergen 2019 regroupe Opglabbeek (71000) et
  Meeuwen-Gruitrode (72000), dont la population séparée n'est pas livrée. Proposition :
  poids égaux pour ce seul cas, avec un avertissement `rcl_unmatched_codes` explicite, et
  documentation de la marche à suivre (`commune_values` à la version BEFORE_2019). À
  confirmer pendant l'implémentation : `split_weights_template()` lève-t-il une erreur sur
  la jambe ambiguë ? Si oui, il faudra un repli dans le **nouveau** code, pas une
  modification des fonctions existantes.

### 5. Tests

- `test-invariants.R`, `test-references.R` : couvrent automatiquement les nouvelles paires
  (intégrité, couverture, relation déclarée = observée, natures, symétrie aller/retour,
  commutativité direct = composé).
- Nouveau `test-cross-version-levels.R`, faits officiels :
  - district 46000 (2025) → 11000 + 44000 + 46000 ; 71000 (2025) → 71000 + 73000 ;
  - district 54000 (BEFORE_2019) → 57000 seul ; 58000 (2019) ← 55000 + 56000 ;
  - province 40000 (2025) → 10000 + 40000 ; provinces BEFORE_2019 ↔ 2019 identiques ;
  - districts inchangés (21000, 63000…) → eux-mêmes, nature `UNCHANGED` ;
  - précision préservée : `NIS_MUNICIPALITY_2025 → NIS_DISTRICT_2019` pour 46029 reste
    {44000, 46000} ;
  - poids population : 46000 → 44000 = population Moerbeke / population district 46000 ;
  - `convert_multi_version()` sur des districts mélangés BEFORE_2019 / 2019 / 2025.
- Golden : régénéré, diff attendu = **ajouts seulement** (nouvelles paires).

### 6. Documentation

NEWS (3.0.0, nouvelles conversions), DOCUMENTATION (tableau des arêtes, section 3.5),
README (exemple court), CLAUDE.md (règle : un niveau agrégé entre versions est dérivé des
communes ; raccourcis directs pour garder la précision). Supprimer la proposition
`DISTRICT_CROSS_VERSION_EDGE.md` remplacée par ce plan (sur sa branche, avec accord).

## Hors périmètre

- NUTS : les révisions NUTS ont déjà leurs arêtes (2021 → 2027).
- Régions : identiques dans toutes les versions ; déjà convertibles via les provinces.
- Nouvelles données de population BEFORE_2019 (non disponibles dans `data/raw/`).

## Vérification

```r
pkgload::load_all(".")
testthat::test_dir("tests/testthat", load_package = "none")   # 1962 -> + nouveaux, 0 échec
# avant/après sur toutes les paires exécutables : identiques hors paires nouvelles
```
`R CMD check` OK, reconstruction depuis `data/raw/` = snapshot, CI verte (branche `claude/**`).

## Estimation

Build + arêtes ~80 lignes, raccourcis ~30, tests ~120, docs ~40. Le contrôle « toutes les
paires avant / après » est la partie la plus longue à exécuter, pas à écrire.
