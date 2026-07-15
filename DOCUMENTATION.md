# Documentation technique -- `nbbbenuts`

> Reference technique complete du package R de conversion de codes geographiques belges.
> Pour les instructions d'utilisation rapide, voir `vignettes/introduction.Rmd`.
> Pour l'historique du refactoring, voir `REFACTORING_PLAN.md`.

---

## Table des matieres

1. [Vue d'ensemble](#1-vue-densemble)
2. [Les 23 classifications supportees](#2-les-23-classifications-supportees)
3. [Le graphe de conversion](#3-le-graphe-de-conversion)
4. [Semantique de perimetre](#4-semantique-de-perimetre)
5. [La colonne `nature`](#5-la-colonne-nature)
6. [API complete](#6-api-complete)
   - 6.1 Chargement des donnees
   - 6.2 Conversion de codes
   - 6.3 Conversion d'un dataset
   - 6.4 Inspection des chemins
   - 6.5 Validation et labels
   - 6.6 Tables de correspondance
   - 6.7 Detection et diagnostic
   - 6.8 Poids et desagregation
   - 6.9 Rebasage longitudinal
   - 6.10 Correspondance floue
   - 6.11 Objet `nomenclature`
   - 6.12 Visualisation
7. [Architecture interne](#7-architecture-interne)
8. [Modele de donnees `master_data`](#8-modele-de-donnees-master_data)
9. [Classes d'erreur et avertissements](#9-classes-derreur-et-avertissements)
10. [Suite de tests](#10-suite-de-tests)
11. [Reconstruction du snapshot](#11-reconstruction-du-snapshot)
12. [Datasets d'exemple](#12-datasets-dexemple)

---

## 1. Vue d'ensemble

`nbbbenuts` convertit des **codes geographiques belges** entre systemes de classification
et a travers le temps. Il couvre quatre systemes :

| Systeme | Identifiant | Exemples de codes |
|---------|-------------|-------------------|
| **NIS** (Statbel) | `NIS_*_{BEFORE_2019,2019,2025}` | `21004` (Bruxelles), `63000` (arr. Verviers) |
| **NUTS** (Eurostat) | `NUTS_{DISTRICT,PROVINCE,REGION}_{2021,2027}`, `NUTS_MUNICIPALITY_2021`, `NUTS_COUNTRY` | `"BE100"`, `"BE211"` |
| **Postal** (bpost) | `POSTAL` | `1000`, `2000` |
| **Interne** | `NBB_DISTRICT_2021` | `"21"` (Bxl), `"65"` (Verviers FR), `"66"` (Verviers DE) |

Deux dimensions temporelles :
- **NIS** : `BEFORE_2019` (589 communes), `2019` (581), `2025` (565) -- les communes
  fusionnent lors des reformes territoriales.
- **NUTS** : `2021` (en vigueur) et `2027` (Reglement UE 2026/195).

**Proprietes cles de l'API :**
- Codes NIS et POSTAL sont de type **integer** ; codes NUTS et NBB sont de type
  **character**.
- `convert_codes()` renvoie toujours un `data.table(code_from, code_to, nature)`.
- Les conversions ambigues (1:N, M:N) sont bloquees par defaut ; `allow_ambiguous = TRUE`
  leve cette garde.
- `devtools::test()` doit passer sans echec (`FAIL 0`) avant tout commit.

---

## 2. Les 23 classifications supportees

```r
get_all_classification_nodes()
```

Organisees **par niveau** ; les versions figurent dans le detail de chaque
niveau (et non en lignes separees). Total : 23 identifiants.

| Systeme | Niveau            | Identifiants (par version)                                                       | Type | Notes |
|---------|-------------------|----------------------------------------------------------------------------------|------|-------|
| NIS     | municipality      | `NIS_MUNICIPALITY_BEFORE_2019`, `NIS_MUNICIPALITY_2019`, `NIS_MUNICIPALITY_2025` | int  | Communes (les versions refletent les vagues de fusion 2019/2025) |
| NIS     | district          | `NIS_DISTRICT_BEFORE_2019`, `NIS_DISTRICT_2019`, `NIS_DISTRICT_2025`             | int  | Arrondissements |
| NIS     | province          | `NIS_PROVINCE_BEFORE_2019`, `NIS_PROVINCE_2019`, `NIS_PROVINCE_2025`             | int  | Scission Brabant : `20001` Brabant flamand / `20002` Brabant wallon ; Bruxelles pseudo-province `4000` |
| NIS     | region            | `NIS_REGION_BEFORE_2019`, `NIS_REGION_2019`, `NIS_REGION_2025`                   | int  | Flamande `2000`, Wallonne `3000`, Bruxelles `4000` |
| NIS     | country           | `NIS_COUNTRY`                                                                    | int  | Code NIS `1000` (source Statbel : 01000 / ROYAUME / HET RIJK). Non-versionne. |
| NUTS    | LAU / municipality| `NUTS_MUNICIPALITY_2021`                                                         | chr  | Bijection 1:1 avec `NIS_MUNICIPALITY_2019` en Belgique (meme territoire, codage Eurostat) |
| NUTS    | district (NUTS 3) | `NUTS_DISTRICT_2021`, `NUTS_DISTRICT_2027`                                       | chr  | |
| NUTS    | province (NUTS 2) | `NUTS_PROVINCE_2021`, `NUTS_PROVINCE_2027`                                       | chr  | |
| NUTS    | region (NUTS 1)   | `NUTS_REGION_2021`, `NUTS_REGION_2027`                                           | chr  | |
| NUTS    | country (NUTS 0)  | `NUTS_COUNTRY`                                                                   | chr  | Non-versionne |
| POSTAL  | postal            | `POSTAL`                                                                         | int  | Codes postaux bpost |
| NBB     | district          | `NBB_DISTRICT_2021`                                                              | chr  | Code interne 2 chiffres ; Verviers scinde : 65=FR, 66=DE |

**Alias acceptes** : les identifiants tolerent plusieurs formes abreges
(ex. `"CP"`, `"CODE_POSTAL"`, `"POSTAL"` ; `"COMMUNE_2019"`, `"NIS_COM_2019"`).
Voir `normalize_classification_id()`.

**Registre machine** : `CLASSIFICATION_NODES` (liste nommee de 23 entrees, `R/00b_registry.R`)
contient pour chaque noeud :

```
system, level, version, code_type, source_table, version_filter,
code_col, label_fr_col, label_nl_col, distinct, detectable, aggregates
```

---

## 3. Le graphe de conversion

### 3.1 Aretes primitives

Le graphe est declare dans `CONVERSION_GRAPH_EDGES` (`R/00_config.R`). Chaque arete
specifie : `from`, `to`, `relation` (`1:1` / `N:1` / `1:N` / `M:N`), `notes`,
et optionnellement `no_reverse`, `ambiguous_codes`, `coverage`.

Cardinalites :

| Cardinalite | Signification | Exemple |
|-------------|---------------|---------|
| `1:1` | bijection exacte | `NIS_MUNICIPALITY_2019 -> NUTS_MUNICIPALITY_2021` |
| `N:1` | agregation (N sources -> 1 cible) | `NIS_MUNICIPALITY_2019 -> NUTS_DISTRICT_2021` |
| `1:N` | eclatement (1 source -> N cibles) | `NIS_MUNICIPALITY_2025 -> NUTS_DISTRICT_2021` pour 3 fusions cross-NUTS3 |
| `M:N` | chevauchement complet | (aucune arete M:N actuellement ; cardinalite supportee par le framework) |

### 3.2 Aretes inverses

Chaque arete est automatiquement inversee au chargement du graphe (sauf `no_reverse = TRUE`)
avec la cardinalite symetrique (`1:1` reste `1:1`, `N:1` devient `1:N`, etc.).

`no_reverse = TRUE` protege les aretes dont l'inversion serait semantiquement incorrecte.
Exemple : l'inverse de `NIS_MUNICIPALITY_2025 -> NUTS_DISTRICT_2021` (`1:N`) est `1:N` depuis la
perspective NUTS3 (beaucoup de communes partagent un NUTS3), pas `N:1`.

### 3.3 Recherche de chemin (BFS)

`find_conversion_path()` (`R/05_conversion_check.R`) fait deux passes :
1. **Passe 1** : BFS sur les aretes `1:1` et `N:1` uniquement -- cherche un chemin simple.
2. **Passe 2** : BFS sur toutes les aretes -- si aucun chemin simple n'existe.

Si une **arete directe** est declaree entre `from` et `to` avec une cardinalite non-simple,
elle prend le dessus sur le chemin indirect trouve par BFS (protection contre les faux simples).

### 3.4 Conversion multi-saut

Les chemins multi-sauts sont **composes** dans `execute_conversion()` :
chaque saut intermedaire est execute via `md$crosswalks` ; les resultats sont joints.
La colonne `nature` reste `NA` pour les chemins composes (la nature n'est definie
que pour les aretes primitives).

### 3.5 Conversions notables

- **`NUTS_DISTRICT_2021 -> NUTS_DISTRICT_2027`** : **lien direct `1:N`** (sens 2021->2027 uniquement),
  derive au build en chainant par les communes. La plupart des NUTS3 2021 -> 1 seul NUTS3 2027 ;
  quelques-uns (ceux contenant les 3 communes ayant change de province entre 2019 et 2025, ex.
  `BE211 -> {BE261, BE276}`) -> 2 cibles, d'ou `allow_ambiguous = TRUE` + splitting pondere
  (`register_split_weights()`). Pour des donnees **au niveau commune**, convertir les communes
  directement vers `NUTS_DISTRICT_2027` (exact, sans poids). Le sens inverse 2027->2021 n'a pas
  d'arete directe (passer par NIS).
- **`province -> region`** est `N:1` (emboitement). Depuis la scission du Brabant
  en 1995, la province unifiee 20000 n'existe plus : Vlaams-Brabant (20001) est en
  Flandre, le Brabant wallon (20002) en Wallonie, et Bruxelles-Capitale utilise une
  pseudo-province (4000) egale a son code de region. Chaque province appartient donc
  a exactement une region. Voir `docs/PROVINCE_REGION_NESTING.md`.
- **Verviers** (`NIS_DISTRICT_2019 = 63000`) est le seul arrondissement 1:N
  vers NUTS3 (BE335 francophone + BE336 germanophone).

---

## 4. Semantique de perimetre

Chaque arete porte une **semantique de perimetre** calculee par `.edge_perimeter_relation()`
et reportee dans `check_conversion_path()` (champ `perimeter_relations`) ainsi que dans
`list_available_conversions()` (colonne `perimeter_relation`).

| Valeur      | Definition | Exemples |
|-------------|------------|---------|
| `temporal`  | Meme systeme, versions differentes. Les limites peuvent evoluer edition par edition mais sans chevauchement entre systemes. | `NIS_MUNICIPALITY_2019 -> NIS_MUNICIPALITY_2025` |
| `identity`  | Arete `1:1` -- correspondance bijective, meme territoire effectif. | `NIS_MUNICIPALITY_2019 -> NUTS_MUNICIPALITY_2021` |
| `nesting`   | Arete `N:1` -- N unites fines s'agglomerent en 1 unite grossiere. Le perimetre source est entierement contenu dans la cible. | `NIS_MUNICIPALITY_2019 -> NUTS_DISTRICT_2021` |
| `overlap`   | Arete `1:N` ou `M:N` -- une unite source **enjambe** plusieurs cibles. Seule categorie qui brise la preservation du perimetre. | `NIS_DISTRICT_2019 -> NUTS_DISTRICT_2021` |

**Statut global d'un chemin :**
- `"preserving"` : aucun saut n'est `overlap`.
- `"crossing"` : au moins un saut est `overlap`.

```r
is_perimeter_preserving("NIS_MUNICIPALITY_2019", "NUTS_DISTRICT_2021")   # TRUE
is_perimeter_preserving("NIS_MUNICIPALITY_2025", "NUTS_DISTRICT_2021")   # FALSE
is_perimeter_preserving("NIS_MUNICIPALITY_2019", "NIS_MUNICIPALITY_2025")  # TRUE (temporal)
```

---

## 5. La colonne `nature`

`convert_codes()` renvoie toujours `(code_from, code_to, nature)`. Les valeurs de `nature` :

| Valeur         | Quand | Arete |
|----------------|-------|-------|
| `UNCHANGED`    | Conversion temporelle NIS, commune inchangee | temporal |
| `FUSION`       | Conversion temporelle NIS, plusieurs communes fusionnees en une | temporal |
| `CHANGE_DSTR`  | Conversion temporelle NIS, commune deplacee dans un autre arrondissement | temporal |
| `CHANGE_PROV`  | Conversion temporelle NIS, commune deplacee dans une autre province | temporal |
| `RECODE`       | Conversion non temporelle sans enjambement (nesting N:1, identity 1:1) | nesting / identity |
| `OVERLAP`      | Conversion non temporelle avec enjambement (1:N ou M:N) | overlap |
| `NA`           | Chemin multi-saut compose (nature intermediaire non definie) | multi-saut |

**Cas BEFORE_2019 -> 2019** : seules `UNCHANGED` et `FUSION` peuvent apparaitre ;
15 communes "orphelines" de BEFORE_2019 n'ont pas de correspondant en 2019 (`code_to = NA`).

**Cas 2019 -> 2025 -- comptes exacts :**
- `UNCHANGED` : 553 communes
- `FUSION` : 27 communes source (13 paires de fusions)
- `CHANGE_DSTR` : 2 communes (44045 -> 46029, 73040 -> 71072)
- `CHANGE_PROV` : 1 commune (11056 -> 46030)

**Symetrie temporelle** : la nature est preservee sur le chemin inverse.
`convert_codes(46030L, "NIS_MUNICIPALITY_2025", "NIS_MUNICIPALITY_2019", md, allow_ambiguous=TRUE)`
renvoie `CHANGE_PROV` pour la ligne `code_to == 11056`.

---

## 6. API complete

### 6.1 Chargement des donnees

#### `load_master_data(path = NULL)`

Charge la table de reference pre-construite depuis `inst/extdata/*.rds`.
Rapide (pas de fichiers bruts). Retourne une liste nommee avec :
`communes`, `postal`, `nis_changes`, `entities`, `crosswalks`.

```r
master_data <- load_master_data()
```

#### `rebuild_master_data(data_dir = NULL, output_dir = NULL)`

Reconstruit le snapshot depuis les fichiers bruts (`data/raw/`). Necessite `readxl`.
Sauvegarde dans `inst/extdata/` via `save_master_tables()`.

#### `load_all_raw_data(data_dir)` / `build_master_table(raw)` / `save_master_tables(md)`

Etapes intermediaires du pipeline de construction, exposees pour usage avance.

---

### 6.2 Conversion de codes

#### `convert_codes(codes, from, to, master_data, allow_ambiguous = FALSE)`

**Fonction centrale.** Convertit un vecteur de codes.

**Parametres :**
- `codes` : vecteur de codes source (integer ou character selon la classification).
- `from`, `to` : identifiants de classification (voir section 2).
- `master_data` : objet retourne par `load_master_data()`.
- `allow_ambiguous` : si `FALSE` (defaut), leve `rcl_ambiguous_conversion` pour tout
  chemin contenant un saut `1:N` ou `M:N`.

**Retour :** `data.table(code_from, code_to, nature)`.

**Comportement pour les codes inconnus :** une ligne avec `code_to = NA` est retournee ;
l'avertissement `rcl_unmatched_codes` est emis.

**Erreurs typees :**
- `rcl_no_route` : aucun chemin dans le graphe entre `from` et `to`.
- `rcl_ambiguous_conversion` : chemin non-simple et `allow_ambiguous = FALSE`.

```r
# Simple N:1
convert_codes(c(21004L, 11002L), "NIS_MUNICIPALITY_2019", "NUTS_DISTRICT_2021", master_data)

# Temporel avec nature
convert_codes(c(11002L, 11007L), "NIS_MUNICIPALITY_2019", "NIS_MUNICIPALITY_2025", master_data)
# code_from  code_to  nature
#     11002    11002  UNCHANGED
#     11007    11002  FUSION

# Ambigu -- Verviers
convert_codes(63000L, "NIS_DISTRICT_2019", "NUTS_DISTRICT_2021",
              master_data, allow_ambiguous = TRUE)
# code_from  code_to  nature
#     63000    BE335  OVERLAP
#     63000    BE336  OVERLAP
```

---

### 6.3 Conversion d'un dataset

#### `convert_dataset(dt, code_col, to, master_data, from = NULL, target_col = NULL, keep_code = TRUE, verbose = TRUE, allow_ambiguous = FALSE, na_action = "warn")`

Convertit une colonne d'un `data.table` (ou `data.frame`). Ajoute `target_col` (nom
auto-genere si `NULL`). Si `from = NULL`, auto-detecte la classification source via
`detect_classification()`.

**Parametres specifiques :**
- `target_col` : nom de la colonne resultat. Defaut : `"cd_{to_lower}"`.
- `keep_code` : conserver la colonne source ? Defaut `TRUE`.
- `na_action` : `"warn"` (defaut, garde les NA), `"keep"` (silencieux), `"drop"` (supprime les lignes).

```r
dt <- data.table(commune = c(21004L, 11002L), pop = c(180000, 530000))
convert_dataset(dt, "commune", "NUTS_DISTRICT_2021", master_data, from = "NIS_MUNICIPALITY_2019")
#    commune      pop  cd_nuts3_2021
# 1:   21004   180000         BE100
# 2:   11002   530000         BE211
```

---

### 6.4 Inspection des chemins

#### `check_conversion_path(from, to)`

Retourne une liste nommee :

| Champ | Type | Contenu |
|-------|------|---------|
| `is_simple` | logical | `TRUE` si tous les sauts sont `1:1` ou `N:1` |
| `path` | character | vecteur des noeuds du chemin |
| `relations` | character | vecteur des cardinalites par saut |
| `explanation` | character | texte lisible |
| `edges_used` | list | aretes utilisees (elements de `CONVERSION_GRAPH_EDGES`) |
| `ambiguous_codes` | integer/character | codes ambigus (si applicables) |
| `coverage` | character | couverture (si applicable) |
| `perimeter_relations` | character | semantique par saut : `"temporal"` / `"identity"` / `"nesting"` / `"overlap"` |
| `perimeter_status` | character | `"preserving"` ou `"crossing"` |
| `straddle_free` | logical | `TRUE` si `perimeter_status == "preserving"` |

#### `is_perimeter_preserving(from, to)`

Raccourci logique : `TRUE` si preserving, `FALSE` si crossing, `NA` si pas de chemin.

#### `print_conversion_check(from, to)`

Affiche un resume lisible (simple/ambigu, perimeter status, path, relations).
Retourne le resultat `check_conversion_path()` de maniere invisible.

#### `list_available_conversions()`

Retourne un `data.table` de toutes les aretes du graphe (incluant les inverses) avec :
`from`, `to`, `relation`, `perimeter_relation`, `notes`.

```r
la <- list_available_conversions()
la[perimeter_relation == "temporal"]   # aretes entre versions NIS
la[perimeter_relation == "overlap"]    # aretes avec enjambement
```

#### `get_conversion_matrix()`

Retourne un `data.table` (N x N) avec : `from`, `to`, `is_simple`, `relation_chain`.
Couteux (O(N^2) appels a `check_conversion_path()`).

---

### 6.5 Validation et labels

#### `validate_codes(codes, classification, master_data)`

Verifie l'appartenance des codes a une classification.
Retourne `data.table(code, is_valid)`.

```r
validate_codes(c(21004L, 99999L), "NIS_MUNICIPALITY_2019", master_data)
#    code  is_valid
#   21004      TRUE
#   99999     FALSE
```

#### `get_label(codes, classification, master_data, lang = "fr")`

Retourne `data.table(code, label)`. `lang` : `"fr"` (defaut) ou `"nl"`.
Codes inconnus -> `label = NA`.

---

### 6.6 Tables de correspondance

#### `get_crosswalk(from, to, master_data, weights = FALSE)`

Retourne la table de correspondance complete entre deux classifications.
Si `weights = TRUE`, ajoute une colonne `weight` (utilise les poids enregistres via
`register_split_weights()`, ou 0.5 egal pour les paires ambigues sans poids).

```r
cw <- get_crosswalk("NIS_MUNICIPALITY_2019", "NUTS_DISTRICT_2021", master_data)
# 581 lignes (une par commune 2019), avec code_from, code_to

get_crosswalk("NIS_DISTRICT_2019", "NUTS_DISTRICT_2021", master_data, weights = TRUE)
# Colonne weight : 0.5/0.5 pour Verviers (63000) par defaut
```

---

### 6.7 Detection et diagnostic

#### `detect_classification(codes, master_data)`

Essaie d'identifier automatiquement la classification a partir des valeurs.
Retourne la classification la plus probable (string) ou `NULL`.

#### `diagnose_classification(dt, col, master_data, classification = NULL, verbose = TRUE)`

- Si `classification` est fourni : verifie la couverture par rapport a la classification
  de reference et affiche un tableau de bord.
- Si `classification = NULL` : auto-detection, classe toutes les classifications par
  taux de correspondance et recommande la meilleure.

**Retour invisible :** liste avec `coverage_rate`, `n_missing`, `n_unknown`,
`n_duplicates`, `missing_codes`, `unknown_codes`, `status`.

`status` possible : `"COMPLETE"`, `"INCOMPLETE"`, `"COMPLETE_WITH_UNKNOWNS"`,
`"INCOMPLETE_WITH_UNKNOWNS"`, `"EMPTY"`, `"ALL_UNKNOWN"`.

---

### 6.8 Poids et desagregation

#### `split_ambiguous(dt, code_col, value_cols, from, to, master_data, value_type = "additive")`

Repartit les valeurs d'un `data.table` sur les cibles multiples d'une conversion
ambigue (`1:N` ou `M:N`).

- `value_type = "additive"` : les valeurs sont multipliees par le poids.
- `value_type = "ratio"` : les valeurs sont recopiees a l'identique dans chaque cible.

Utilise les poids enregistres (voir ci-dessous), ou 0.5/0.5 egal si aucun poids.

#### `split_weights_template(from, to, master_data)`

Retourne un `data.table(code_from, code_to, weight)` pre-rempli avec des poids egaux
(1/N). Sert de point de depart pour definir des poids personnalises.

```r
tpl <- split_weights_template("NIS_DISTRICT_2019", "NUTS_DISTRICT_2021", master_data)
# code_from  code_to  weight
#     63000    BE335     0.5
#     63000    BE336     0.5

tpl[code_from == "63000" & code_to == "BE335", weight := 0.60]
tpl[code_from == "63000" & code_to == "BE336", weight := 0.40]
```

#### `register_split_weights(from, to, weights_dt, variable = "default")`

Enregistre des poids personnalises pour la session (environment interne, pas persistent).
`variable` permet de distinguer plusieurs jeux de poids (ex. `"population"`, `"emploi"`).

#### `get_split_weights(from, to, variable = "default")`

Recupere les poids enregistres. Leve `rcl_no_weights` si aucun poids n'est enregistre.

#### `list_split_weights()`

Retourne un `data.table` listant tous les jeux de poids enregistres dans la session.

#### `clear_split_weights()`

Efface tous les poids enregistres dans la session.

---

### 6.9 Rebasage longitudinal

#### `rebase_series(dt, period_col, code_col, value_cols, version_map, to, master_data, fun = sum, value_type = "additive", split = "default")`

Convertit un panel longitudinal spanning plusieurs versions NIS vers une version cible.

**Parametres :**
- `period_col` : colonne des periodes (annee, trimestre, etc.).
- `code_col` : colonne des codes geographiques.
- `value_cols` : colonnes de valeurs a convertir.
- `version_map` : `list("NIS_MUNICIPALITY_2019" = 2022L, "NIS_MUNICIPALITY_2025" = 2025L)`.
  Chaque entree associe une classification a un ou plusieurs periodes.
- `to` : classification cible.
- `fun` : fonction d'agregation pour `value_type = "additive"` (defaut `sum`).
- `value_type` : `"additive"` (ex. effectifs) ou `"ratio"` (ex. taux).
- `split` : `"default"` (utilise les poids enregistres) ou objet `data.table` de poids.

**Avertissements emis :**
- `rcl_missing_periods` : certaines periodes du dataset ne sont pas couvertes par `version_map`.

```r
panel <- data.table(
  year = c(2022L, 2022L, 2025L),
  commune = c(11002L, 11007L, 11002L),
  pop = c(530000, 42000, 590000)
)

rebase_series(
  panel,
  period_col  = "year",
  code_col    = "commune",
  value_cols  = "pop",
  version_map = list("NIS_MUNICIPALITY_2019" = 2022L, "NIS_MUNICIPALITY_2025" = 2025L),
  to          = "NIS_MUNICIPALITY_2025",
  master_data = master_data
)
# 2022 : commune 11002 -> 530000 + 42000 = 572000 (fusionne)
# 2025 : 590000 (inchange)
```

---

### 6.10 Correspondance floue

#### `fuzzy_match_names(names, target, master_data, max_dist = 0.3, language = "both")`

Rattache des noms (orthographe approchee) a des codes officiels.
Necessite le package `stringdist` (Suggests).

**Retour :** `data.table(input_name, matched_name, matched_code, distance, is_confident)`.

```r
fuzzy_match_names(
  c("Bruxeles", "Antwerpn", "Liege"),
  target = "NIS_MUNICIPALITY_2019",
  master_data,
  max_dist = 0.3
)
```

#### `identify_from_names(names, master_data, ...)`

Variante de `fuzzy_match_names` avec auto-detection de la classification cible.

---

### 6.11 Objet `nomenclature`

Interface programmatique pour manipuler les classifications dynamiquement.

#### `nomenclature(system, level, version = NA)`

Construit un objet `nomenclature` valide contre `CLASSIFICATION_NODES`.

```r
n <- nomenclature("NIS", "municipality", "2019")
nom_system(n)   # "NIS"
nom_level(n)    # "municipality"
nom_version(n)  # "2019"
```

#### `list_nomenclatures()` / `nomenclature_levels(system)` / `nomenclature_versions(system, level)`

Introspection de l'espace des classifications valides.

#### `nomenclature_children(n)` / `nomenclature_parents(n)`

Navigation dans la hierarchie d'agregation definie par le champ `aggregates` de
`CLASSIFICATION_NODES`.

#### `is_nomenclature(x)`

Test de type.

---

### 6.12 Visualisation

Ces fonctions necessitent `visNetwork` (Suggests).

#### `visualize_classification_graph(master_data = NULL)`

Graphe interactif des relations entre classifications (noeuds = classifications,
aretes = conversions avec cardinalite).

#### `visualize_conversion_matrix(master_data = NULL)`

Matrice de faisabilite des conversions (simple / ambigu / impossible).

#### `visualize_hierarchy(version, master_data, max_communes = 20)`

Arbre hierarchique NIS pour une version donnee (`"NIS_2019"` ou `"NIS_2025"`).

---

## 7. Architecture interne

```
R/
 00_config.R          -- CLASSIFICATION_REGISTRY, CONVERSION_GRAPH_EDGES, constantes NIS
 00b_registry.R       -- CLASSIFICATION_NODES (source de verite unique, 23 noeuds)
 00c_nomenclature.R   -- objet nomenclature + S3 methods
 01_load_data.R       -- chargement et parsing des fichiers bruts (Excel)
 02_build_master_table.R -- construction de entities + crosswalks + tables sources
 03_convert.R         -- convert_codes(), execute_conversion(), route_conversion()
 04_fuzzy_match.R     -- fuzzy_match_names(), identify_from_names()
 05_conversion_check.R-- check_conversion_path(), BFS, build_conversion_graph()
 06_visualize.R       -- visualize_*()
 07_dataset_convert.R -- convert_dataset()
 07_detect.R          -- detect_classification()
 07_diagnose.R        -- diagnose_classification()
 07_split_ambiguous.R -- split_ambiguous(), split_weights_template(), registre de poids
 08_load_prebuilt.R   -- load_master_data(), save_master_tables()
 09_query.R           -- validate_codes(), get_label(), get_crosswalk(), .node_reference_codes()
 10_rebase.R          -- rebase_series()
 classifications.R    -- documentation de classification_reference (?classification_reference)
 data.R               -- documentation des datasets internes
 zzz.R                -- utils::globalVariables() (suppresser les NOTEs R CMD CHECK)
```

### 7.1 Flot d'une conversion

```
convert_codes(codes, from, to, md)
  |
  +-- check_conversion_path(from, to)      -- valide et trouve le chemin (cache BFS)
  |     build_conversion_graph()           -- construit l'adjacence depuis CONVERSION_GRAPH_EDGES
  |     find_conversion_path()             -- passe 1 (simple) puis passe 2 (tous)
  |
  +-- execute_conversion(codes, from, to, md)
        route_conversion(from, to, md)     -- lecture de md$crosswalks pour le saut direct
        .crosswalk_hop(from, to, md)       -- lookup data.table [from_id == F & to_id == T]
        .compose_via_crosswalks(path, md)  -- composition pour les chemins multi-sauts
        .normalize_conversion_result()     -- force le schema (code_from, code_to, nature)
                                           -- remplit nature = RECODE / OVERLAP selon perimetre
```

### 7.2 `CLASSIFICATION_NODES`

Chaque entree est une liste avec :

```r
CLASSIFICATION_NODES[["NIS_MUNICIPALITY_2019"]]
# $system        "NIS"
# $level         "municipality"
# $version       "2019"
# $code_type     "integer"
# $source_table  "communes"
# $version_filter "2019"
# $code_col      "cd_commune"
# $label_fr_col  "tx_commune_fr"
# $label_nl_col  "tx_commune_nl"
# $distinct      FALSE
# $detectable    TRUE
# $aggregates    character(0)   # commune est un noeud feuille
```

Le champ `aggregates` forme un DAG (pas un arbre) : `NIS_DISTRICT_2019` est agrege
par la province ET par la region ; `NUTS_COUNTRY` agrege `NUTS_REGION_2021` ET `NUTS_REGION_2027`.

### 7.3 Moteur de conversion (Phase 2)

L'executeur lit **exclusivement** `md$crosswalks` pour chaque saut individuel.
Les anciens handlers fermes ont ete supprimes. Le test `test-route-parity.R` garantit
que toute conversion declaree simple est executee correctement et que les crosswalks
reproduisent exactement les resultats du moteur (fixture golden + parite par arete).

### 7.4 Normalisation du resultat

`.normalize_conversion_result(dt, from, to)` remplit la colonne `nature` :
- Chemins temporels (meme systeme, versions differentes) : nature deja portee par
  `md$crosswalks` (`UNCHANGED`/`FUSION`/`CHANGE_DSTR`/`CHANGE_PROV`).
- Chemins non-temporels : nature = `"RECODE"` si perimetre `identity`/`nesting`,
  `"OVERLAP"` si perimetre `overlap`.
- Chemins multi-sauts (appel sans `from`/`to`) : nature reste `NA`.

---

## 8. Modele de donnees `master_data`

`load_master_data()` retourne une liste avec cinq tables :

### `communes` -- table large

Une ligne par `(cd_commune, nis_version)`. Colonnes principales :

```
cd_commune     int   -- code NIS de la commune
nis_version    chr   -- "BEFORE_2019" | "2019" | "2025"
tx_commune_fr  chr   -- nom francais
tx_commune_nl  chr   -- nom neerlandais
cd_arr         int   -- code arrondissement NIS
cd_prov        int   -- code province NIS
cd_region      int   -- code region NIS
cd_nuts_lau    chr   -- code NUTS LAU 2021
cd_nuts3       chr   -- code NUTS3 2021
cd_nuts2       chr   -- code NUTS2 2021
cd_nuts1       chr   -- code NUTS1 2021
cd_nuts3_2027  chr   -- code NUTS3 2027 (NULL si pas encore calcule)
cd_internal    chr   -- code NBB_DISTRICT_2021 (2 chiffres)
```

### `postal` -- codes postaux

```
cd_postal  int   -- code postal (4 chiffres)
cd_commune int   -- commune NIS 2019 correspondante
```

### `nis_changes` -- transitions de version

```
from_version  chr   -- "BEFORE_2019" ou "2019"
to_version    chr   -- "2019" ou "2025"
code_from     int   -- code source
code_to       int   -- code cible
nature        chr   -- "UNCHANGED" | "FUSION" | "CHANGE_DSTR" | "CHANGE_PROV"
```

### `entities` -- enumeration des membres par classification

```
classification_id  chr   -- identifiant de la classification
code               chr   -- code (toujours character ici, coerce si besoin)
name_fr            chr   -- nom francais
name_nl            chr   -- nom neerlandais
```

Une ligne par `(classification_id, code)`. Sert a `validate_codes()`, `get_label()`,
`detect_classification()`.

### `crosswalks` -- liens primitifs entre classifications

```
from_id   chr   -- classification source
to_id     chr   -- classification cible
code_from chr   -- code source
code_to   chr   -- code cible (NA si code source sans correspondant)
relation  chr   -- "1:1" | "N:1" | "1:N" | "M:N"
nature    chr   -- nature de la conversion (voir section 5)
```

Une ligne par lien primitif. C'est la table lue par `route_conversion()` pour chaque
saut du chemin. La fixture golden (`tests/testthat/fixtures/golden_crosswalks.rds`)
fige son contenu ; tout changement dans les crosswalks impose de regenerer la fixture
avec `gen_golden()`.

---

## 9. Classes d'erreur et avertissements

Toutes les erreurs et avertissements utilisant `rlang::abort()` / `rlang::warn()` portent
une classe `rcl_*`. Interceptables avec `tryCatch(..., rcl_xxx = handler)`.

| Classe | Type | Declencheur |
|--------|------|-------------|
| `rcl_no_route` | erreur | `convert_codes()` : aucun chemin de `from` vers `to` |
| `rcl_ambiguous_conversion` | erreur | `convert_codes()` : chemin non-simple et `allow_ambiguous = FALSE` |
| `rcl_unmatched_codes` | warning | codes inconnus dans la source, `code_to = NA` |
| `rcl_missing_periods` | warning | `rebase_series()` : periodes non couvertes par `version_map` |
| `rcl_no_weights` | erreur | `get_split_weights()` : aucun poids enregistre pour la paire |
| `rcl_invalid_weights` | erreur | poids qui ne somment pas a 1, ou codes absents |
| `rcl_schema_error` | erreur | table `communes` non conforme au schema attendu au build |

---

## 10. Suite de tests

```
tests/testthat/
  helper-master_data.R         -- charge master_data une fois (session-level fixture)
  helper-golden.R              -- gen_golden() : regenere la fixture golden

  test-conversions.R           -- cas principaux convert_codes() (NIS, NUTS, POSTAL)
  test-conversion-check.R      -- check_conversion_path(), is_perimeter_preserving()
  test-perimeter-semantics.R   -- .edge_perimeter_relation(), straddle_free
  test-temporal-nature.R       -- CHANGE_DSTR / CHANGE_PROV / UNCHANGED / FUSION
  test-crosswalks-golden.R     -- golden fixture : sorties figees du moteur
  test-crosswalks-parity.R     -- parite crosswalk <-> moteur par arete
  test-route-parity.R          -- toute conversion simple est executable
  test-registry.R              -- CLASSIFICATION_NODES : structure, count (23)
  test-registry-consistency.R  -- coherence CLASSIFICATION_NODES <-> CLASSIFICATION_REGISTRY
  test-split-registry.R        -- registre de poids (register/get/clear)
  test-convert-dataset.R       -- convert_dataset()
  test-rebase.R                -- rebase_series()
  test-diagnose.R              -- diagnose_classification()
  test-query.R                 -- validate_codes(), get_label(), get_crosswalk()
  test-misc.R                  -- alias, normalize_classification_id(), edge cases
  test-edge-cases.R            -- codes NA, vecteurs vides, from == to
  test-nomenclature.R          -- objet nomenclature, S3 methods, hierarchie
  test-fuzzy.R                 -- fuzzy_match_names() (skip si stringdist absent)
  test-load.R                  -- load_master_data(), structure des tables
```

**Etat cible :** FAIL 0 | WARN 0 | SKIP 8 | PASS 949.
Les 8 SKIPs sont des tests `fuzzy_match_names` gardes par `skip_if_not_installed("stringdist")`.

**Regle golden** : toute modification qui change le contenu des crosswalks ou les valeurs
de `nature` impose de regenerer la fixture :

```r
devtools::load_all(".")
source("tests/testthat/helper-golden.R")
gen_golden()   # ecrit tests/testthat/fixtures/golden_crosswalks.rds
# puis git add + commit la fixture
```

Ne **jamais** supprimer `golden_crosswalks.rds` -- regenerer uniquement.

---

## 11. Reconstruction du snapshot

Le package fonctionne normalement sur le snapshot pre-construit (`inst/extdata/*.rds`).
La reconstruction est necessaire uniquement apres modification des fichiers bruts.

### Fichiers bruts requis (`data/raw/`)

| Fichier | Contenu |
|---------|---------|
| `CONVERSION_NIS2019_NUTS2021.xlsx` | NIS 2019 vers NUTS 2021 (Statbel/Eurostat) |
| `REFNIS_2025-NUTS_2027.xlsx` | NIS 2025 vers NUTS 2027 (Statbel) |
| `REFNIS_2019.xls`, `REFNIS_2025.xlsx`, `REFNIS_BEFORE_2019.xls` | Hierarchies REFNIS par version |
| `REFNIS_CHANGE_2025.xlsx` | Transitions NIS 2019 -> 2025 (avec nature) |
| `REFNIS_CHANGE_BEFORE2019.xlsx` | Transitions NIS BEFORE_2019 -> 2019 (avec nature) |
| `CONVERSION_POSTAL_NIS2019.xlsx`, `CONVERSION_POSTAL_NIS2025.xlsx` | Codes postaux -> communes NIS (filtre `KEEP_UNIQUE`) |
| `NUTS_ARRONDISSEMENT.csv` | NUTS3 -> arrondissement interne (NBB) |

### Commandes

```r
# Reconstruction complete
master_data <- rebuild_master_data()       # charge les bruts, construit, sauvegarde

# Ou etapes separees
raw   <- load_all_raw_data("data/raw/")
md    <- build_master_table(raw)
save_master_tables(md)                     # ecrit inst/extdata/*.rds
```

### Schema de validation

`build_master_table()` valide le schema de la table `communes` au build et leve
`rcl_schema_error` si des colonnes obligatoires sont absentes ou si les types
ne correspondent pas au registre `CLASSIFICATION_NODES`.

---

## 12. Datasets d'exemple

Le package inclut huit `data.table` prets a l'emploi (charges avec `data()`).

> **/!\ Donnees d'EXEMPLE / TEST uniquement.** Toutes les colonnes
> socio-economiques (`population`, `emplois`, `masse_sal`, `taux_activite`, ...)
> sont **PUREMENT FICTIVES**, generees aleatoirement (`set.seed(42)` dans
> `data-raw/generate_example_datasets.R`). Ce ne sont **pas** de vraies
> statistiques : elles servent uniquement a demontrer et tester l'API. Ne les
> utilisez jamais pour une analyse reelle.

### Datasets propres (couverture complete)

Chaque dataset contient une ligne par unite geographique, avec cinq colonnes :
la colonne code + `population`, `emplois`, `masse_sal`, `taux_activite`.

| Dataset | Code col | N lignes | Classification |
|---------|----------|----------|----------------|
| `rc_full_municipalities_2019` | `cd_commune` | 581 | `NIS_MUNICIPALITY_2019` |
| `rc_full_municipalities_2025` | `cd_commune` | 565 | `NIS_MUNICIPALITY_2025` |
| `rc_full_districts_2019`      | `cd_arr`     |  43 | `NIS_DISTRICT_2019` |
| `rc_full_regions_2019`        | `cd_region`  |   3 | `NIS_REGION_2019` |
| `rc_full_nuts3_2021`          | `cd_nuts3`   |  44 | `NUTS_DISTRICT_2021` |
| `rc_full_nuts3_2027`          | `cd_nuts3_2027` | 44 | `NUTS_DISTRICT_2027` |
| `rc_full_postal`              | `cd_postal`  | 1 149 | `POSTAL` |

### Dataset sale (`rc_dirty_municipalities_2019`)

319 lignes basees sur `NIS_MUNICIPALITY_2019` avec quatre types d'anomalies
intentionnelles, pour demonstrer `diagnose_classification()` et `validate_codes()` :

| Anomalie | Quantite |
|----------|----------|
| Doublons de lignes | 5 communes repetees |
| Codes d'une autre version | 4 codes NIS 2025 absents de 2019 |
| Code NA | 2 lignes |
| Valeur `population` NA | 8 lignes |

```r
data(rc_dirty_municipalities_2019)
master_data <- load_master_data()

# Diagnostic complet
diagnose_classification(rc_dirty_municipalities_2019, "cd_commune", master_data,
                        classification = "NIS_MUNICIPALITY_2019")

# Validation code par code
validate_codes(rc_dirty_municipalities_2019$cd_commune,
               "NIS_MUNICIPALITY_2019", master_data)

# Auto-detection (si la classification n'est pas connue a l'avance)
diagnose_classification(rc_dirty_municipalities_2019, "cd_commune", master_data)
```

### Regeneration

Les fichiers `.rda` dans `data/` sont produits par :

```r
source("data-raw/generate_example_datasets.R")
```

La graine aleatoire `set.seed(42)` garantit la reproductibilite.

---

## Glossaire

| Terme | Definition |
|-------|------------|
| **NIS** | Nomenclature INS/NIS de Statbel (Institut National de Statistique belge) |
| **NUTS** | Nomenclature des Unites Territoriales Statistiques d'Eurostat |
| **LAU** | Local Administrative Unit (= commune belge dans la nomenclature NUTS) |
| **crosswalk** | Table de correspondance entre deux classifications (une ligne par lien primitif) |
| **nature** | Qualification d'une conversion : UNCHANGED / FUSION / CHANGE_DSTR / CHANGE_PROV / RECODE / OVERLAP / NA |
| **perimetre** | Territoire physique delimite sur la carte (distinct du code qui l'etiquette) |
| **semantique de perimetre** | Classification d'un saut selon son impact perimetre : temporal / identity / nesting / overlap |
| **straddle** | Un perimetre source qui enjambe deux ou plusieurs perimetres cibles (arete `overlap`) |
| **Verviers** | Arrondissement NIS 63000 -- seul cas 1:N vers NUTS3 (BE335 FR + BE336 DE) |
| **BFS** | Breadth-First Search -- algorithme de recherche de chemin dans le graphe de conversion |
| **fixture golden** | Snapshot des sorties du moteur, verifie a chaque run pour detecter toute regression |
