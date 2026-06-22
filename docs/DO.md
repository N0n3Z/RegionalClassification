# DO — étapes à réaliser en local

Checklist d’actions pour finaliser la branche `check_relation` (détails
et explications dans `CHECK_RELATION.md`).

> ⚠️ Pré-requis : R installé + `install.packages("readxl")`. Tant que
> ces étapes ne sont pas faites, la suite de tests est **rouge** (les
> `.rds` livrés contiennent encore l’ancien code province `20000`).

## 1. Reconstruire les données

``` r

devtools::load_all(".")
rebuild_master_data()        # régénère inst/extdata/*.rds depuis data/raw/
```

## 2. Régénérer la golden fixture

``` r

source("tests/testthat/helper-golden.R")
gen_golden()                 # réécrit tests/testthat/fixtures/golden_crosswalks.rds
```

## 3. Régénérer la documentation

``` r

devtools::document()         # met à jour man/*.Rd + NAMESPACE
```

## 4. Tester

``` r

devtools::test()             # doit être VERT après les étapes 1–3
devtools::check()            # contrôle complet avant de déclarer terminé
```

## 5. Vérifications de cohérence

``` r

md <- load_master_data()

# (a) plus aucune commune avec l'ancien code 20000
stopifnot(!any(md$communes$cd_province == 20000L, na.rm = TRUE))

# (b) les nouveaux codes de province existent
stopifnot(all(c(20001L, 20002L, 4000L) %in% md$communes$cd_province))

# (c) province -> region : N:1, sans allow_ambiguous
convert_codes(c(10000L, 20001L, 20002L, 4000L),
              CLS_NIS_PROVINCE_2019, CLS_NIS_REGION_2019, md)
#  10000 -> 2000 ; 20001 -> 2000 ; 20002 -> 3000 ; 4000 -> 4000

# (d) arête déclarée nesting
e <- Find(function(x) x$from == CLS_NIS_PROVINCE_2019 &&
                      x$to   == CLS_NIS_REGION_2019, CONVERSION_GRAPH_EDGES)
stopifnot(e$relation == "N:1")

# (e) DAG nomenclature : région -> province -> district
stopifnot(identical(
  vapply(nomenclature_children(nomenclature("NIS","region","2019")), as.character, ""),
  CLS_NIS_PROVINCE_2019))
```

## 6. Régénérer le site pkgdown (docs/)

Le site `docs/` est un artefact généré qui n’a PAS été reconstruit lors
du rebuild initial : il référence encore l’ancien `M:N (Brabant 20000)`.

``` r

pkgdown::build_site()        # régénère docs/reference/*, docs/articles/*, etc.
```

## 7. Commit & push (si tout est vert)

``` sh
git add -A
git commit -m "chore: rebuild data + golden + docs after province->region nesting fix"
git push -u origin <branche>
```
