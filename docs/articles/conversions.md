# Conversions géographiques

## Initialisation

``` r

library(nbbbenuts)
master_data <- load_master_data()
```

------------------------------------------------------------------------

## 1. `convert_codes()` — conversion de vecteurs

La fonction centrale du package. Elle retourne un `data.table` à trois
colonnes :

| Colonne | Contenu |
|----|----|
| `code_from` | Code source (dans le type canonique : entier pour NIS/POSTAL, caractère pour NUTS) |
| `code_to` | Code cible |
| `nature` | Type de conversion (voir tableau ci-dessous) |

Valeurs de `nature` :

| Valeur        | Quand                                                       |
|---------------|-------------------------------------------------------------|
| `UNCHANGED`   | NIS temporel : commune inchangée                            |
| `FUSION`      | NIS temporel : fusion de communes                           |
| `CHANGE_DSTR` | NIS temporel : changement d’arrondissement                  |
| `CHANGE_PROV` | NIS temporel : changement de province                       |
| `RECODE`      | Non-temporel sans enjambement (nesting N:1, identity 1:1)   |
| `OVERLAP`     | Non-temporel avec enjambement (1:N ou M:N)                  |
| `NA`          | Chemin multi-hop composé (nature intermédiaire non définie) |

### NIS communes → NUTS3 2021

``` r

convert_codes(
  c(21004L, 11002L, 44021L, 62063L),
  from = "NIS_MUNICIPALITY_2019",
  to   = "NUTS_DISTRICT_2021",
  master_data
)
#    code_from code_to  nature
# 1:     21004   BE100   RECODE
# 2:     11002   BE211   RECODE
# 3:     44021   BE234   RECODE
# 4:     62063   BE332   RECODE
```

### NIS communes → NUTS3 2027

``` r

convert_codes(
  c(21004L, 11002L, 44021L),
  from = "NIS_MUNICIPALITY_2019",
  to   = "NUTS_DISTRICT_2027",
  master_data
)
#    code_from code_to
# 1:     21004   BE100   (inchangé)
# 2:     11002   BE261   (BE211 -> BE261)
# 3:     44021   BE274   (BE234 -> BE274)
```

### Codes postaux → communes NIS

``` r

convert_codes(c(1000L, 2000L, 4000L), "POSTAL", "NIS_MUNICIPALITY_2019", master_data)
#    code_from code_to
# 1:      1000   21004
# 2:      2000   11002
# 3:      4000   62063
```

### NIS 2019 → NIS 2025 : colonne `nature`

Toutes les conversions temporelles NIS portent une colonne `nature` qui
qualifie le type de changement :

| Valeur | Signification |
|----|----|
| `UNCHANGED` | Le code commune est identique dans les deux versions (553 communes) |
| `FUSION` | Plusieurs communes 2019 ont fusionné en une commune 2025 (27 paires) |
| `CHANGE_DSTR` | La commune a changé d’arrondissement entre 2019 et 2025 (2 communes) |
| `CHANGE_PROV` | La commune a changé de province entre 2019 et 2025 (1 commune) |

``` r

# FUSION : plusieurs communes 2019 -> 1 code 2025 (Beringen)
convert_codes(c(71002L, 71011L), "NIS_MUNICIPALITY_2019", "NIS_MUNICIPALITY_2025", master_data)
#    code_from code_to      nature
# 1:     71002   71072      FUSION
# 2:     71011   71072      FUSION

# Sens inverse : 1 code 2025 -> plusieurs codes 2019
convert_codes(71072L, "NIS_MUNICIPALITY_2025", "NIS_MUNICIPALITY_2019", master_data)
#    code_from code_to      nature
# 1:     71072   71002      FUSION
# 2:     71072   71011      FUSION
```

### CHANGE_DSTR et CHANGE_PROV

Trois communes ont changé de découpage administratif en 2025 :

``` r

# CHANGE_DSTR : commune 44045 (Sint-Laureins) passe dans un autre arrondissement
convert_codes(44045L, "NIS_MUNICIPALITY_2019", "NIS_MUNICIPALITY_2025", master_data)
#    code_from code_to      nature
# 1:     44045   46029 CHANGE_DSTR

# CHANGE_PROV : commune 11056 (Puurs) change de province
convert_codes(11056L, "NIS_MUNICIPALITY_2019", "NIS_MUNICIPALITY_2025", master_data)
#    code_from code_to      nature
# 1:     11056   46030 CHANGE_PROV

# La nature est symétrique sur le sens inverse
convert_codes(46030L, "NIS_MUNICIPALITY_2025", "NIS_MUNICIPALITY_2019", master_data)
#    code_from code_to      nature
# 1:     46030   11056 CHANGE_PROV
```

Ces valeurs sont utiles pour auditer la stabilité longitudinale d’une
série statistique : une commune `CHANGE_DSTR` ou `CHANGE_PROV` peut
changer de périmètre dans des agrégats supérieurs (arrondissement,
province, NUTS2).

### Commune pré-2019 → classification actuelle

``` r

# 55022 = Fosses-la-Ville (fusionné en 2019 en commune 58001 = Mettet)
convert_codes(55022L, "NIS_MUNICIPALITY_BEFORE_2019", "NIS_MUNICIPALITY_2019", master_data)
convert_codes(55022L, "NIS_MUNICIPALITY_BEFORE_2019", "NUTS_DISTRICT_2021",       master_data)
convert_codes(55022L, "NIS_MUNICIPALITY_BEFORE_2019", "NUTS_DISTRICT_2027",       master_data)
```

### Tous les niveaux géographiques pour une commune

``` r

commune <- 11002L  # Antwerpen

convert_codes(commune, "NIS_MUNICIPALITY_2019", "NIS_DISTRICT_2019", master_data)
convert_codes(commune, "NIS_MUNICIPALITY_2019", "NIS_PROVINCE_2019",       master_data)
convert_codes(commune, "NIS_MUNICIPALITY_2019", "NIS_REGION_2019",         master_data)
convert_codes(commune, "NIS_MUNICIPALITY_2019", "NUTS_DISTRICT_2021",              master_data)
convert_codes(commune, "NIS_MUNICIPALITY_2019", "NUTS_PROVINCE_2021",              master_data)
convert_codes(commune, "NIS_MUNICIPALITY_2019", "NUTS_REGION_2021",              master_data)
convert_codes(commune, "NIS_MUNICIPALITY_2019", "NBB_DISTRICT_2021", master_data)
```

### Identifiants abrégés

Les noms de classifications acceptent plusieurs alias :

``` r

# Ces appels sont équivalents
convert_codes(1000L, "CP",           "NIS_COM_2019", master_data)
convert_codes(1000L, "CODE_POSTAL",  "COMMUNE_2019", master_data)
convert_codes(1000L, "POSTAL",       "NIS_MUNICIPALITY_2019", master_data)
```

------------------------------------------------------------------------

## 2. `convert_dataset()` — conversion d’un dataset complet

Opère directement sur une colonne de `data.table`, avec auto-détection
optionnelle de la classification source.

### Usage de base

``` r

library(data.table)

salaires <- data.table(
  commune = c(21004L, 11002L, 62063L),
  salaire = c(3500, 2900, 2600)
)

# Convertit la colonne 'commune' et ajoute une colonne 'cd_nuts3_2021'
result <- convert_dataset(
  dt       = salaires,
  code_col = "commune",
  from     = "NIS_MUNICIPALITY_2019",
  to       = "NUTS_DISTRICT_2021",
  master_data
)
print(result)
#    commune salaire cd_nuts3_2021
# 1:   21004    3500         BE100
# 2:   11002    2900         BE211
# 3:   62063    2600         BE332
```

### Auto-détection de la classification source

``` r

# Pas besoin de préciser 'from', le package détecte automatiquement
nuts_data <- data.table(
  nuts = c("BE100", "BE211", "BE332"),
  val  = c(100, 200, 300)
)

convert_dataset(nuts_data, "nuts", to = "NUTS_DISTRICT_2027", master_data)
#     nuts val cd_nuts3_2027
# 1: BE100 100         BE100
# 2: BE211 200         BE261
# 3: BE332 300         BE332
```

### Nom de colonne cible personnalisé

``` r

convert_dataset(
  dt         = salaires,
  code_col   = "commune",
  from       = "NIS_MUNICIPALITY_2019",
  to         = "NUTS_DISTRICT_2027",
  master_data,
  target_col = "nuts3_2027"
)
```

### Gestion des NA

``` r

dt_avec_na <- data.table(
  code    = c(21004L, NA, 99999L),
  valeur  = c(100, 200, 300)
)

# Avertissement pour NA et codes inconnus (comportement par défaut)
convert_dataset(dt_avec_na, "code", to = "NUTS_DISTRICT_2021", master_data,
                na_action = "warn")

# Supprimer les lignes NA/inconnues
convert_dataset(dt_avec_na, "code", to = "NUTS_DISTRICT_2021", master_data,
                na_action = "drop")
```

------------------------------------------------------------------------

## 3. `list_available_conversions()` — chemins disponibles

Affiche tous les chemins de conversion déclarés avec leur type de
relation et leur **sémantique de périmètre** (colonne
`perimeter_relation`).

``` r

la <- list_available_conversions()
# Colonnes : from, to, relation, perimeter_relation, notes
print(la[, .(from, to, relation, perimeter_relation)])

# Filtrer par sémantique de périmètre :
la[perimeter_relation == "temporal"]   # conversions entre versions NIS
la[perimeter_relation == "overlap"]    # conversions avec enjambement (1:N / M:N)
la[perimeter_relation == "nesting"]    # agrégations N:1 pures
la[perimeter_relation == "identity"]   # correspondances 1:1
```

Les quatre valeurs de `perimeter_relation` :

| Valeur | Signification |
|----|----|
| `temporal` | Même système, versions différentes (NIS 2019 → 2025, etc.) |
| `identity` | Correspondance exacte 1:1 sans perte (ex. NIS_MUNICIPALITY_2019 → NUTS_MUNICIPALITY_2021 : meme territoire, meme code, systeme Eurostat) |
| `nesting` | Agrégation N:1 (plusieurs communes → un arrondissement) |
| `overlap` | La source enjambe plusieurs cibles (ex. Verviers 1:N). `province -> region` est desormais `nesting` (N:1) depuis la scission du Brabant |

------------------------------------------------------------------------

## 4. `check_conversion_path()` et `is_perimeter_preserving()`

[`check_conversion_path()`](https://n0n3z.github.io/regionalclassification/reference/check_conversion_path.md)
retourne maintenant des informations de périmètre en plus du test de
simplicité.

``` r

# Chemin simple et préservant le périmètre
r <- check_conversion_path("NIS_MUNICIPALITY_2019", "NUTS_DISTRICT_2021")
# $is_simple          TRUE
# $path               c("NIS_MUNICIPALITY_2019", "NUTS_MUNICIPALITY_2021", "NUTS_DISTRICT_2021")
# $perimeter_relations c("identity", "nesting")
# $perimeter_status   "preserving"
# $straddle_free      TRUE

# Chemin ambigu et enjambant : Verviers (M:N)
r2 <- check_conversion_path("NIS_DISTRICT_2019", "NUTS_DISTRICT_2021")
# $is_simple          FALSE
# $perimeter_relations c("overlap")
# $perimeter_status   "crossing"
# $straddle_free      FALSE

# Chemin NIS 2025 -> NUTS3 2021 : 1:N (3 fusions enjambent les régions NUTS3)
r3 <- check_conversion_path("NIS_MUNICIPALITY_2025", "NUTS_DISTRICT_2021")
# $perimeter_status   "crossing"
# $straddle_free      FALSE
```

``` r

# Raccourci booléen
is_perimeter_preserving("NIS_MUNICIPALITY_2019", "NUTS_DISTRICT_2021")   # TRUE
is_perimeter_preserving("NIS_MUNICIPALITY_2025", "NUTS_DISTRICT_2021")   # FALSE
is_perimeter_preserving("NIS_MUNICIPALITY_2019", "NIS_MUNICIPALITY_2025")  # TRUE (temporal)
```

``` r

# Vue lisible pour exploration interactive (affiche perimeter_relations)
print_conversion_check("POSTAL", "NUTS_DISTRICT_2021")
print_conversion_check("NIS_MUNICIPALITY_2025", "NUTS_DISTRICT_2027")
print_conversion_check("NIS_DISTRICT_2019", "NUTS_DISTRICT_2021")
```
