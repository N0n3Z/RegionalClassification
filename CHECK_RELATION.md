# CHECK_RELATION — travail restant à réaliser en local

Branche : `check_relation`

Cette branche corrige la relation `NIS_PROVINCE_* → NIS_REGION_*` :
elle passe de `M:N` (`overlap`) à **`N:1` (`nesting`)**, en s'appuyant sur la
scission du Brabant (20001 / 20002) et une **pseudo-province de Bruxelles**
(code `4000`). Voir `docs/PROVINCE_REGION_NESTING.md` pour le détail.

## ⚠️ Pourquoi des étapes locales sont indispensables

Les changements ont été faits **au niveau du code source uniquement**.
L'environnement d'exécution distant **n'a pas R / readxl installés**, donc je
n'ai PAS pu :

1. reconstruire le snapshot de données `inst/extdata/*.rds`
   (`rebuild_master_data()` lit les `.xlsx` via `readxl`) ;
2. régénérer la *golden fixture* `tests/testthat/fixtures/golden_crosswalks.rds` ;
3. régénérer la doc (`man/*.Rd`, `NAMESPACE`, `docs/reference/`) ;
4. lancer la suite de tests (`devtools::test()`) ni `devtools::check()`.

➡️ **Tant que ces étapes ne sont pas faites en local, données et graphe sont
désynchronisés et la suite de tests sera ROUGE.** C'est attendu : les `.rds`
livrés contiennent encore l'ancien code `20000`, alors que le graphe déclare
maintenant `province → region = N:1`.

## ✅ À exécuter en local, dans l'ordre

```r
# 0. Pré-requis : R + le paquet readxl installé
#    install.packages("readxl")

devtools::load_all(".")

# 1. Reconstruire le snapshot de données depuis data/raw/ (REQUIS)
#    -> regénère inst/extdata/communes.rds, crosswalks.rds, entities.rds, ...
#    -> les communes du Brabant porteront 20001/20002, Bruxelles 4000
rebuild_master_data()

# 2. Régénérer la golden fixture (elle est dérivée des données)
#    gen_golden() est défini dans tests/testthat/helper-golden.R
testthat::source_test_helpers("tests/testthat")  # charge helper-golden.R
gen_golden()                                      # réécrit fixtures/golden_crosswalks.rds

# 3. Régénérer la documentation roxygen (docstrings modifiées)
devtools::document()

# 4. Lancer la suite de tests — DOIT être verte après 1–3
devtools::test()

# 5. Contrôle complet avant de déclarer terminé
devtools::check()
```

## 🔎 Vérifications de cohérence à faire après le rebuild

```r
md <- load_master_data()

# (a) Plus aucune commune ne doit porter l'ancien code 20000
stopifnot(!any(md$communes$cd_province == 20000L, na.rm = TRUE))

# (b) Les nouveaux codes de province existent bien
stopifnot(all(c(20001L, 20002L, 4000L) %in% md$communes$cd_province))

# (c) province -> region est N:1 et sans ambiguïté (pas d'allow_ambiguous)
convert_codes(c(10000L, 20001L, 20002L, 4000L),
              CLS_NIS_PROVINCE_2019, CLS_NIS_REGION_2019, md)
#  10000 -> 2000 ; 20001 -> 2000 ; 20002 -> 3000 ; 4000 -> 4000

# (d) L'arête est bien déclarée nesting
e <- Find(function(x) x$from == CLS_NIS_PROVINCE_2019 &&
                      x$to   == CLS_NIS_REGION_2019, CONVERSION_GRAPH_EDGES)
stopifnot(e$relation == "N:1")
```

## 📌 Points d'attention

- **Collision 4000** : le code de pseudo-province de Bruxelles est égal au code
  de sa région. L'auto-détection d'un code nu `4000` le classera comme *région*.
  L'API de conversion (from/to explicites) n'est pas affectée. Détaillé dans
  `docs/PROVINCE_REGION_NESTING.md`.

- **REFNIS BEFORE_2019 / 2019** : la correction suppose que ces fichiers
  utilisent le même schéma que 2025 (20001/20002, pas de 20000), ce qui est le
  cas depuis la scission de 1995. À reconfirmer empiriquement après le rebuild
  via la vérification (a) ci-dessus.

## 🟡 Décision optionnelle (hors périmètre de cette branche)

Le **DAG de nomenclature** (`R/00b_registry.R`) modélise toujours la région
comme agrégeant directement les arrondissements (un arrondissement a donc deux
parents : province ET région). C'était justifié par l'ancien `M:N`.

Maintenant que `province → region` est un emboîtement propre, on *pourrait*
restructurer le DAG en `région → province → arrondissement`. Ce n'est PAS fait
dans cette branche car :

- c'est une structure distincte du graphe de conversion (la demande portait sur
  la relation de conversion) ;
- cela modifie le comportement public de `nomenclature_parents()` /
  `nomenclature_children()` ;
- cela casserait volontairement `test-nomenclature.R` (« an arrondissement is
  aggregated by BOTH a province and a region »).

➡️ À trancher séparément si on veut aligner le DAG sur l'emboîtement strict.
