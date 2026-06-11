# Diagnostic et détection de classification

``` r

library(nbbbenuts)
library(data.table)
master_data <- load_master_data()
```

------------------------------------------------------------------------

## 1. `diagnose_classification()` — vérification de couverture

Vérifie l’alignement d’un dataset avec une classification de référence :
codes inconnus, codes manquants, doublons, taux de couverture.

### Mode vérification (classification fournie)

``` r

# Dataset avec un code manquant et un code inconnu
nuts3_data <- data.table(
  nuts3 = c("BE100", "BE211", "BE999"),   # BE999 n'existe pas
  value = c(100, 200, 150)
)

res <- diagnose_classification(
  dt             = nuts3_data,
  code_col       = "nuts3",
  master_data    = master_data,
  classification = "NUTS_DISTRICT_2021"
)
```

Sortie console :

    ================================================================
      CLASSIFICATION DIAGNOSTIC
    ================================================================
      Dataset    : 3 rows  |  column 'nuts3'
      Reference  : NUTS_DISTRICT_2021  (44 codes)
    ================================================================
      Coverage   : 2 / 44  [#-------------------]  4.5%
      Unknown    : 1 code(s) in dataset not in reference
      Duplicates : 0

      Unknown codes (1):
        BE999

Résultat retourné :

``` r

res$status          # "INCOMPLETE_WITH_UNKNOWNS"
res$coverage_rate   # 0.04545...
res$n_missing       # 42
res$n_unknown       # 1
res$unknown_codes   # data.table avec "BE999"
res$missing_codes   # data.table avec les 42 codes absents du dataset
```

### Dataset complet → statut COMPLETE

``` r

# Dataset contenant tous les codes NUTS3 2021
dt_full <- data.table(
  nuts3 = unique(master_data$communes[nis_version == "2019" & !is.na(cd_nuts3),
                                       cd_nuts3])
)

res_full <- diagnose_classification(dt_full, "nuts3", master_data,
                                    classification = "NUTS_DISTRICT_2021")
res_full$status  # "COMPLETE"
res_full$n_missing  # 0
```

### Codes dupliqués

``` r

dt_dup <- data.table(
  nuts3 = c("BE100", "BE100", "BE211"),
  val   = c(10, 20, 30)
)

res_dup <- diagnose_classification(dt_dup, "nuts3", master_data,
                                   classification = "NUTS_DISTRICT_2021",
                                   verbose = FALSE)
res_dup$n_duplicates  # 1
res_dup$status        # "INCOMPLETE_WITH_UNKNOWNS" ou "INCOMPLETE" selon les cas
```

------------------------------------------------------------------------

## 2. `diagnose_classification()` — mode auto-détection

Sans `classification`, la fonction compare le dataset contre toutes les
classifications connues et retourne la meilleure correspondance.

``` r

# Dataset avec des communes NIS 2019
communes_data <- data.table(
  code = c(21004L, 11002L, 44021L, 62063L, 63079L)
)

res_detect <- diagnose_classification(communes_data, "code", master_data)
```

Sortie console :

    ================================================================
      CLASSIFICATION AUTO-DETECTION
    ================================================================
      Classification              Match%   Cover%   Unknown%
      ----------------------------------------------------------
      NIS_MUNICIPALITY_2019            100.0%    0.9%       0.0%  <-- best
      NIS_MUNICIPALITY_BEFORE_2019      80.0%    0.7%      20.0%
      NIS_MUNICIPALITY_2025            100.0%    0.9%       0.0%
      ...
      Recommendation: NIS_MUNICIPALITY_2019

Résultat retourné :

``` r

res_detect$recommendation      # "NIS_MUNICIPALITY_2019"
res_detect$classification_type # "NIS_COMMUNE"
res_detect$version             # "2019"
res_detect$candidates          # data.table avec tous les scores
```

### Cas avec codes NUTS3 2027

``` r

nuts27_data <- data.table(nuts = c("BE100", "BE261", "BE274"))

res <- diagnose_classification(nuts27_data, "nuts", master_data)
res$recommendation  # "NUTS_DISTRICT_2027"
res$version         # "2027"
```

------------------------------------------------------------------------

## 3. `detect_classification()` — détection rapide sur un vecteur

Variante légère qui retourne directement la classification la plus
probable pour un vecteur de codes, sans afficher de sortie console.

``` r

detect_classification(c(21004L, 11002L, 62063L), master_data)
# [1] "NIS_MUNICIPALITY_2019"

detect_classification(c("BE100", "BE211", "BE332"), master_data)
# [1] "NUTS_DISTRICT_2021"

detect_classification(c(1000L, 2000L, 4000L), master_data)
# [1] "POSTAL"
```

------------------------------------------------------------------------

## 4. `fuzzy_match_names()` — correspondance floue sur les noms

Associe des noms approchés (fautes de frappe, accents, abréviations) à
des codes officiels.

``` r

fuzzy_match_names(
  names    = c("Bruxeles", "Antwerpn", "Liege", "Vervirs"),
  target   = "NIS_MUNICIPALITY_2019",
  master_data,
  max_dist = 0.3,
  language = "both"   # "fr", "nl", ou "both"
)
#   input_name  matched_name  matched_code  distance  is_confident
#   Bruxeles    Bruxelles        21004       0.037      TRUE
#   Antwerpn    Antwerpen        11002       0.037      TRUE
#   Liege       Liège            62063       0.150      TRUE
#   Vervirs     Verviers         63079       0.042      TRUE
```

### Matching contre d’autres classifications

``` r

# Noms de provinces
fuzzy_match_names(
  names   = c("Hainaut", "Lieg", "Namr"),
  target  = "NIS_PROVINCE_2019",
  master_data
)

# Noms de codes postaux
fuzzy_match_names(
  names   = c("Bruxelles", "Anvers", "Gand"),
  target  = "POSTAL",
  master_data
)

# Codes NUTS3
fuzzy_match_names(
  names   = c("Arr. Anvers", "Arr. Liège", "Arr. Namur"),
  target  = "NUTS_DISTRICT_2021",
  master_data,
  max_dist = 0.4
)
```

### Seuil de distance

`max_dist` est une distance relative (0 = identique, 1 = totalement
différent). Valeur recommandée : 0.1–0.3.

``` r

# Correspondance stricte (fautes mineures seulement)
fuzzy_match_names(c("Bruxells"), "NIS_MUNICIPALITY_2019", master_data, max_dist = 0.1)

# Correspondance permissive (abréviations, noms partiels)
fuzzy_match_names(c("Bxl", "Anv", "Lge"), "NIS_MUNICIPALITY_2019", master_data,
                  max_dist = 0.5)
```

------------------------------------------------------------------------

## 5. `identify_from_names()` — identification de classification

Détecte automatiquement la classification probable à partir d’un vecteur
de noms, sans connaître la classification cible à l’avance.

``` r

identify_from_names(
  names       = c("Bruxelles", "Antwerpen", "Gent", "Liège"),
  master_data
)
# Best match: NIS_MUNICIPALITY_2019 (4/4 matched, avg distance 0.02)
```
