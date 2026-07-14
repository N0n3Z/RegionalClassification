# TODO (local) — Compléter les fusions BEFORE_2019 → 2019

> À exécuter **en local** (R + readxl requis pour le rebuild). Ce document décrit le
> point **B** du diagnostic : les 7 fusions communales de 2019 sont **absentes** du
> fichier source `data/raw/REFNIS_CHANGE_BEFORE2019.xlsx`, si bien que leurs 15
> communes constituantes se convertissent en `NA` (« orphaned »).
>
> Le point **A** (natures — `CHANGE_DSTR` étiquetés `FUSION`) est déjà corrigé dans le
> code sur la branche `fix/before2019-nature` ; il faut néanmoins **rebuild** pour que
> ça prenne effet (la `nature` est figée dans le snapshot `inst/extdata/*.rds`).

## Contexte du problème

Le fichier `REFNIS_CHANGE_BEFORE2019.xlsx` ne contient aujourd'hui que **11 lignes**,
toutes `NATURE = CHANGE_DSTR` (réforme des arrondissements wallons de 2019 : création de
l'arr. La Louvière `58`, etc.). Les **7 fusions flamandes** de 2019 n'y figurent pas.

Conséquence dans `build_crosswalks()` (`R/02_build_master_table.R:736-755`) : n'étant ni
« unchanged » (leur ancien code a disparu en 2019) ni dans le fichier de changements, les
15 communes constituantes tombent dans `orphaned_b19` → `code_to = NA`.

## Les 7 fusions à ajouter (nouveau code = `CD_REFNIS_NEW`, `NATURE = FUSION`)

| Communes constituantes (BEFORE_2019) | Nouveau code 2019 | Nouveau nom |
|--------------------------------------|-------------------|-------------|
| Meeuwen-Gruitrode, Opglabbeek        | **72042**         | Oudsbergen |
| Neerpelt, Overpelt                   | **72043**         | Pelt |
| Kruishoutem, Zingem                  | **45068**         | Kruisem |
| Aalter, Knesselare                   | **44084**         | Aalter |
| Deinze, Nevele                       | **44083**         | Deinze |
| Puurs, Sint-Amands                   | **12041**         | Puurs-Sint-Amands |
| Waarschoot, Lovendegem, Zomergem     | **44085**         | Lievegem |

→ **15 lignes** au total (2+2+2+2+2+2+3).

## Étape 1 — Récupérer les anciens codes NIS (autoritatifs)

Les 15 anciens codes sont **exactement** les communes « orphaned ». Extrais-les avec
leurs noms pour éviter toute erreur de saisie :

```r
devtools::load_all(".")
md    <- load_master_data()
m_b19 <- unique(md$communes[nis_version == VER_BEFORE_2019, cd_commune])
m_19  <- unique(md$communes[nis_version == VER_2019,        cd_commune])
ch    <- md$nis_changes[from_version == VER_BEFORE_2019, cd_refnis_old]

orphaned <- setdiff(m_b19, union(ch, m_19))
md$communes[nis_version == VER_BEFORE_2019 & cd_commune %in% orphaned,
            .(cd_commune, tx_commune_nl, tx_commune_fr)][order(cd_commune)]
# -> doit lister les 15 communes ci-dessus (Meeuwen-Gruitrode, Opglabbeek, ...).
#    Relève chaque cd_commune et associe-le à son nouveau code via le tableau ci-dessus.
```

## Étape 2 — Compléter le fichier source

Ajoute les **15 lignes** à `data/raw/REFNIS_CHANGE_BEFORE2019.xlsx` (même schéma que
les lignes existantes) :

| NIS_VERSION_OLD | NIS_VERSION_NEW | CD_REFNIS_OLD | CD_REFNIS_NEW | NATURE |
|-----------------|-----------------|---------------|---------------|--------|
| BEFORE_2019 | 2019 | `<code Meeuwen-Gruitrode>` | 72042 | FUSION |
| BEFORE_2019 | 2019 | `<code Opglabbeek>`        | 72042 | FUSION |
| BEFORE_2019 | 2019 | `<code Neerpelt>`          | 72043 | FUSION |
| BEFORE_2019 | 2019 | `<code Overpelt>`          | 72043 | FUSION |
| BEFORE_2019 | 2019 | `<code Kruishoutem>`       | 45068 | FUSION |
| BEFORE_2019 | 2019 | `<code Zingem>`            | 45068 | FUSION |
| BEFORE_2019 | 2019 | `<code Aalter>`            | 44084 | FUSION |
| BEFORE_2019 | 2019 | `<code Knesselare>`        | 44084 | FUSION |
| BEFORE_2019 | 2019 | `<code Deinze>`            | 44083 | FUSION |
| BEFORE_2019 | 2019 | `<code Nevele>`            | 44083 | FUSION |
| BEFORE_2019 | 2019 | `<code Puurs>`             | 12041 | FUSION |
| BEFORE_2019 | 2019 | `<code Sint-Amands>`       | 12041 | FUSION |
| BEFORE_2019 | 2019 | `<code Waarschoot>`        | 44085 | FUSION |
| BEFORE_2019 | 2019 | `<code Lovendegem>`        | 44085 | FUSION |
| BEFORE_2019 | 2019 | `<code Zomergem>`          | 44085 | FUSION |

> Le fix A ayant rendu la colonne `NATURE` autoritaire, ces lignes seront correctement
> étiquetées `FUSION`, tandis que les 11 existantes resteront `CHANGE_DSTR`.

## Étape 3 — Rebuild + vérification

```r
devtools::load_all(".")
rebuild_master_data()          # régénère inst/extdata/*.rds avec les fusions + natures
md <- load_master_data()

# 1) Plus aucune commune orpheline (les 15 sont désormais mappées)
m_b19 <- unique(md$communes[nis_version == VER_BEFORE_2019, cd_commune])
m_19  <- unique(md$communes[nis_version == VER_2019,        cd_commune])
ch    <- md$nis_changes[from_version == VER_BEFORE_2019, cd_refnis_old]
length(setdiff(m_b19, union(ch, m_19)))          # -> 0

# 2) Une fusion se convertit correctement (exemple : une commune de Pelt -> 72043)
convert_codes(<code Neerpelt>, "NIS_MUNICIPALITY_BEFORE_2019",
              "NIS_MUNICIPALITY_2019", md)        # -> 72043, nature FUSION

# 3) Natures correctes : 11 CHANGE_DSTR + 15 FUSION
r <- suppressWarnings(convert_codes(m_b19, "NIS_MUNICIPALITY_BEFORE_2019",
                                    "NIS_MUNICIPALITY_2019", md))
table(r$nature, useNA = "ifany")                  # CHANGE_DSTR = 11, FUSION = 15
```

## Étape 4 — Tests + golden

```r
source("tests/testthat/helper-golden.R"); gen_golden()   # le crosswalk B19->19 a changé
devtools::document(); devtools::test(); devtools::check()
```

Le test `test-temporal-nature.R` (mis à jour dans le fix A) valide déjà
`CHANGE_DSTR == 11`. Après l'étape 2, tu peux ajouter un test miroir
`FUSION == 15` et `orphaned == 0` si tu veux figer la complétude.

---

### Récapitulatif
- **Fix A** (code) : déjà sur `fix/before2019-nature` → nécessite un **rebuild** pour prendre effet.
- **Fix B** (données) : compléter le `.xlsx` (étapes 1-2) puis **rebuild + golden** (étapes 3-4).
- Les deux ensemble : natures correctes **et** fusions converties.
