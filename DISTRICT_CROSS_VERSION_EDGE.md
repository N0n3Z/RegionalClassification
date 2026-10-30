# Proposition : arête NIS_DISTRICT_2025 → NIS_DISTRICT_2019

## Contexte

Dans l'état actuel du package, il n'existe aucun chemin de conversion entre les
classifications d'arrondissements NIS à travers les versions (2019 ↔ 2025). Les
seules arêtes inter-versions disponibles se situent au niveau commune :

```
NIS_MUNICIPALITY_2019  →  NIS_MUNICIPALITY_2025   (N:1, reverse 1:N)
```

Les arêtes dirigées touchant `NIS_DISTRICT_2025` sont uniquement :

```
NIS_MUNICIPALITY_2025  →  NIS_DISTRICT_2025   (N:1, entrante)
NIS_DISTRICT_2025      →  NIS_PROVINCE_2025    (N:1, sortante)
```

Un appel à `split_ambiguous("NIS_DISTRICT_2025", "NIS_DISTRICT_2019", ...)` lève
donc une erreur `rcl_no_path`.

## Approche proposée

Ajouter une arête directe `NIS_DISTRICT_2025 → NIS_DISTRICT_2019` de relation
`1:N`, dérivée mécaniquement de la table `nis_changes` existante.

### Principe

Le mapping district 2025 → district(s) 2019 s'obtient en agrégeant les
changements au niveau commune :

1. Pour chaque commune NIS 2025, identifier sa ou ses communes NIS 2019
   constitutives (via `nis_changes`, `from_version = "2019"`).
2. Dériver le district d'appartenance de chaque commune (integer division par
   1000, puis par 1 pour obtenir le code à 5 chiffres de l'arrondissement).
3. Grouper par district 2025 : collecter l'ensemble des districts 2019 sources.
4. **1:1** si tous les codes 2019 appartiennent au même district 2025.
5. **1:N** si certaines communes constitutives provenaient d'un district 2019
   différent (cas `CHANGE_DSTR`).

### Districts affectés (cas 1:N)

D'après les données actuelles de `nis_changes`, deux natures de changement
créent de l'ambiguïté au niveau district :

| Nature       | Commune 2019 | District 2019 | Commune 2025 | District 2025 |
|--------------|-------------|---------------|-------------|---------------|
| `CHANGE_DSTR`| 44045       | 44000         | 46029       | 46000         |
| `CHANGE_DSTR`| (à vérifier)| 46000 ?       | 46030       | 46000         |

→ Le district **46000** en NIS 2025 est le seul district 1:N identifié : il
contient des communes issues à la fois du district 46000 et du district 44000
en NIS 2019.

Les fusions de communes (`FUSION`, ex. 71072 ← 71002 + 71011) ne créent **pas**
d'ambiguïté au niveau district si toutes les communes fusionnées appartenaient
au même district.

## Plan d'implémentation

### Étape 1 — Dériver la table de mapping (`R/02_build_master_table.R`)

Ajouter une fonction interne `.build_district_version_map()` qui :

```r
.build_district_version_map <- function(nis_changes) {
  # nis_changes contient : cd_nis_2019, cd_nis_2025, nature, from_version
  ch <- nis_changes[from_version == "2019",
                    .(cd_nis_2019 = as.character(cd_nis_2019),
                      cd_nis_2025 = as.character(cd_nis_2025))]

  # Dériver les codes district (5 chiffres, exemple 44045 -> "44000")
  ch[, dist_2019 := paste0(substr(cd_nis_2019, 1, 2), "000")]
  ch[, dist_2025 := paste0(substr(cd_nis_2025, 1, 2), "000")]

  # Un district 2025 -> ensemble des districts 2019 sources
  mapping <- unique(ch[, .(code_from = dist_2025, code_to = dist_2019)])
  mapping
}
```

Stocker le résultat dans la liste `master_data` sous la clé `district_version_map`.

### Étape 2 — Déclarer l'arête (`R/00_config.R`)

Ajouter dans `CONVERSION_GRAPH_EDGES` :

```r
list(
  from     = CLS_NIS_DISTRICT_2025,
  to       = CLS_NIS_DISTRICT_2019,
  relation = "1:N",
  via      = "derived",
  notes    = paste0(
    "Derived from commune-level nis_changes (from_version='2019'). ",
    "Most districts are 1:1 (unchanged communes). ",
    "Districts containing CHANGE_DSTR communes are 1:N ",
    "(e.g. district 46000 in 2025 includes communes formerly in district 44000). ",
    "Reverse (2019->2025) is also derivable but not added here (not needed)."
  )
)
```

### Étape 3 — Ajouter le handler (`R/03_convert.R`)

Dans `.ROUTE_TABLE`, ajouter le handler :

```r
paste(CLS_NIS_DISTRICT_2025, CLS_NIS_DISTRICT_2019, sep = "->") = function(codes, master_data) {
  mapping <- master_data$district_version_map
  result  <- mapping[code_from %in% codes]
  # Codes sans correspondance explicite = 1:1 (code identique)
  all_from <- data.table(code_from = as.character(codes))
  result   <- merge(all_from, mapping, by = "code_from", all.x = TRUE)
  result[is.na(code_to), code_to := code_from]
  result[, .(code_from, code_to)]
}
```

### Étape 4 — Tests (`tests/testthat/`)

Ajouter dans un fichier `test-district-cross-version.R` :

- **DCV1** : conversion d'un district stable (ex. 21000) renvoie le même code
- **DCV2** : conversion du district 46000 (2025) renvoie deux lignes (44000 et 46000)
- **DCV3** : `check_conversion_path("NIS_DISTRICT_2025", "NIS_DISTRICT_2019")` retourne `is_simple = FALSE`
- **DCV4** : `split_ambiguous()` distribue correctement un dataset avec district 46000
- **DCV5** : `test-route-parity.R` — vérifier que la nouvelle arête a un handler enregistré

### Étape 5 — Poids pour `split_ambiguous()`

La nouvelle arête permet à `split_ambiguous()` de fonctionner, mais les poids
ne sont **pas** automatiquement disponibles. L'utilisateur doit les fournir :

```r
# Poids = part de population de la commune migrante dans le district 46000 (2025)
tpl <- split_weights_template("NIS_DISTRICT_2025", "NIS_DISTRICT_2019", master_data)
# Résultat attendu :
#   code_from  code_to  weight
#       46000    44000     0.5   <- à remplacer par la vraie part
#       46000    46000     0.5   <- à remplacer par la vraie part

# Ajuster avec des données réelles (ex. population 2019)
tpl[code_from == "46000" & code_to == "44000", weight := 0.08]  # commune 44045 ~8% du district
tpl[code_from == "46000" & code_to == "46000", weight := 0.92]

register_split_weights("NIS_DISTRICT_2025", "NIS_DISTRICT_2019", tpl)
```

## Complexité estimée

| Tâche                              | Effort |
|------------------------------------|--------|
| `.build_district_version_map()`    | ~20 lignes |
| Déclaration arête config           | ~10 lignes |
| Handler `.ROUTE_TABLE`             | ~15 lignes |
| Tests (5 cas)                      | ~50 lignes |
| Mise à jour vignette/demo          | ~10 lignes |

Total : **~1h de développement**, aucune dépendance externe, cohérent avec
l'architecture existante.

## Limites

- Les poids restent à la charge de l'utilisateur (pas de données de population
  intégrées au package pour les communes ayant changé de district).
- La direction inverse (NIS_DISTRICT_2019 → NIS_DISTRICT_2025) n'est pas
  ajoutée ici car elle est de nature N:1 et triviale (`convert_codes` suffit via
  un chemin composé commune → district).
