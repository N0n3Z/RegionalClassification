# Suivi des changements visibles par les utilisateurs

> Tenu à jour à chaque modification. Référence : ce que les utilisateurs ont aujourd'hui,
> la branche `main` (**nbbbenuts 1.2.0**). Règle (utilisateur, 2026-10-30) : une fonction,
> ses arguments ou ses sorties ne changent que si c'est **nécessaire** ; tout changement est
> inscrit ici avec sa raison.
>
> Légende — **Cassant** : un appel ou un code utilisateur existant peut échouer ou donner
> un autre résultat. **Nécessaire** : correction d'un résultat faux, ou dépendance
> technique ; sinon le changement relève du confort / de la cohérence et pourrait être
> évité ou adouci.

## 1. Déjà réalisé sur les branches (pas encore dans `main`)

### Branche `claude/schema-v2` (2.0.0) — renommages

| Fonction / objet | Changement | Cassant | Nécessaire |
|---|---|---|---|
| `load_master_data()`, `build_master_table()` | table `communes` → `municipalities` ; colonnes `cd_*` / `tx_*` → `code_*` / `label_*` ; `nis_version` → `version` ; `entities` : `classification_id`, `name_fr/_nl` → `classification`, `label_fr/_nl` ; `crosswalks` : `from_id`, `to_id` → `classification_from`, `classification_to` | oui (code lisant `master_data` directement) | non (cohérence des noms) |
| `convert_dataset()`, `split_ambiguous()` | nom par défaut de la colonne créée : `cd_nuts3_2021`, `cd_nis2019`, `cd_arr2019`… → `code_nuts_district_2021`, `code_nis_municipality_2019`, `code_nis_district_2019`… (inchangé si `target_col` est fourni) | oui | non |
| `get_crosswalk()` | colonnes `NIS_DISTRICT_2019`, `NUTS_DISTRICT_2021`… → `code_nis_district_2019`, `code_nuts_district_2021`… | oui | non |
| `list_available_conversions()`, `get_conversion_matrix()` | colonnes `from`, `to` → `classification_from`, `classification_to` | oui | non |
| `fuzzy_match_names()`, `identify_from_names()` | colonnes `input_name`, `matched_name`, `matched_code` → `label_input`, `label_matched`, `code_matched` | oui | non |
| Jeux d'exemple `rc_*` | renommés (`rc_communes_2019` → `rc_municipalities_2019`, `rc_arrondissements_2019` → `rc_districts_2019`, `rc_nuts3_2021` → `rc_nuts_districts_2021`…) ; colonnes `cd_*` / `nom_fr` → `code_*` / `label_fr` ; codes en caractères | oui (`data(...)`) | non |
| Dépendance | `data.table >= 1.17.0` | oui (installation) | **oui** (1.14.10 plante) |
| `load_master_data(dir)` | un ancien snapshot v1 est migré à la volée (warning `rcl_legacy_schema`) | non (ajout) | — |

### Branche `fix/before2019-nuts2021` — correction

| Fonction / objet | Changement | Cassant | Nécessaire |
|---|---|---|---|
| `convert_codes()` depuis `NIS_MUNICIPALITY_BEFORE_2019` | vers `NUTS_DISTRICT_2021` : 87 communes donnaient des codes NUTS 2016 inexistants (Mouscron 54007 : BE324 → **BE328**) ; vers `NBB_DISTRICT_2021` : NA → code ; LAU 2021 des 26 communes fusionnées corrigé (Puurs 12030 → **12041**) | oui (valeurs) | **oui** (résultats faux) |

### Branche `claude/schema-v2-long-model` (3.0.0) — modèle long

| Fonction / objet | Changement | Cassant | Nécessaire |
|---|---|---|---|
| `load_master_data()` | ne renvoie plus que `entities` + `crosswalks` ; `master_data$municipalities`, `$postal`, `$nis_changes` → `wide_view(master_data, ...)` (choix utilisateur) | oui | non (choix d'architecture) |
| `save_master_tables()`, `rebuild_master_data()` | n'écrivent / ne renvoient que les deux tables longues | oui (rare) | non |
| `wide_view()` | **nouvelle** fonction | non | — |

### Branche `test/invariants` — corrections trouvées par les tests

| Fonction / objet | Changement | Cassant | Nécessaire |
|---|---|---|---|
| `convert_codes(..., "NIS_MUNICIPALITY_2025", "NBB_DISTRICT_2021")` | exige désormais `allow_ambiguous = TRUE` (pour toutes les communes) ; 46029 / 46030 / 71072 : NA → deux districts (choix utilisateur) | oui (erreur sans `allow_ambiguous`) | **oui** (3 communes perdues) |
| `convert_codes(..., "NIS_MUNICIPALITY_2025", "NUTS_PROVINCE_2021")` | les 3 mêmes communes ne disparaissent plus ; exige `allow_ambiguous = TRUE` | oui | **oui** (perte silencieuse) |
| `check_conversion_path()`, `list_available_conversions()` | relation `1:N` → `M:N` pour NIS 2025 → NUTS3 2021 et NUTS3 2021 → 2027 | faiblement (texte) | non (exactitude du libellé) |

### Branche `claude/multi-version-convert`

| Fonction / objet | Changement | Cassant | Nécessaire |
|---|---|---|---|
| `convert_multi_version()` | **nouvelle** fonction (aucune fonction existante modifiée, demande utilisateur) | non | — |

### Branche `claude/nis-cross-version-levels` — niveaux agrégés entre versions

| Fonction / objet | Changement | Cassant | Nécessaire |
|---|---|---|---|
| `convert_codes()` | 144 conversions nouvelles (districts / provinces / régions NIS entre versions, NIS ↔ NUTS, NUTS 2027 → 2021 / → NIS) ; les conversions existantes donnent les mêmes codes | non (ajout) | — |
| `convert_codes()` — colonne `nature` | renseignée (`RECODE` / `OVERLAP`) sur ~12 000 lignes de conversions existantes qui renvoyaient `NA` (choix utilisateur) | faiblement (code testant `is.na(nature)`) | non |
| `convert_codes("1020", "POSTAL", "NIS_DISTRICT_2025" / "NIS_REGION_2025")` | NA → 21000 / 4000 (choix utilisateur) | faiblement | non (plus juste) |
| `convert_codes(..., "NUTS_DISTRICT_2027", "NUTS_DISTRICT_2021")` | erreur `rcl_no_route` → conversion ambiguë (exige `allow_ambiguous`) | non (ajout) | — |
| `check_conversion_path("NIS_DISTRICT_2019", "NUTS_PROVINCE_2021")` | `is_simple` FALSE → TRUE (nouveau chemin simple) | faiblement | non (conséquence) |
| `split_weights_template(variable = "population")` | un code non pondérable (BEFORE_2019 71000, Oudsbergen) reçoit `weight = NA` + warning `rcl_weights_required`, au lieu de faire échouer toute la paire | oui (valeurs NA) | **oui** (poids égaux faux sinon) |
| `split_ambiguous(weights = "population")`, `rebase_series()` | BEFORE_2019 → 2019 : vrais poids pour le Hainaut au lieu de poids égaux ; erreur `rcl_weights_required` si les données contiennent 71000 sans poids fournis (choix utilisateur) ; un poids explicitement NA n'est plus remplacé par un partage égal | oui | **oui** |

### Branche `claude/maintainer-docs-demo`

| Fonction / objet | Changement | Cassant | Nécessaire |
|---|---|---|---|
| `identify_from_names()` | ordre par défaut de `possible_classifications` : NIS communes avant POSTAL ; sur des noms de communes, renvoie les codes NIS (21004…) au lieu des codes postaux (1000…) (choix utilisateur) | oui (valeurs) | **oui** (résultat contre-intuitif) |
| `DESCRIPTION` | mainteneur Romain Grailet, URLs `github.com/StatHH` | non | — |

## 2. Refonte prévue (`docs/plans/engine-redesign.md`)

Objectif : **aucune ligne**. Signatures, arguments, colonnes de sortie et valeurs de
`nature` inchangés ; mêmes codes pour les 291 conversions actuelles.

| Fonction / objet | Changement | Cassant | Nécessaire |
|---|---|---|---|
| `convert_codes()` | 4 conversions nouvelles vers `NIS_MUNICIPALITY_BEFORE_2019` (dé-fusion 2019 → BEFORE_2019), si l'atome code postal est retenu | non (ajout) | — |
| poids `"population"` | **à surveiller** : inchangés si la population communale reste la référence ; changeraient si la population par code postal était utilisée partout | à décider | — |
| `options(nbbbenuts.engine = "atoms")` (interne, non documentée) | active le nouveau moteur ; par défaut l'ancien reste utilisé. Aucun changement tant que la bascule (étape 3) n'est pas faite | non | — |
| `convert_codes("1020", "POSTAL", "NIS_MUNICIPALITY_2025")` | **à la bascule** : NA → 21004 (Laeken rattaché à Bruxelles, cohérent avec le district / la région 2025 déjà renvoyés) | faiblement | non (cohérence) — à valider avant la bascule |

## 3. Synthèse

- **Nécessaires** (corrections ou dépendance) : `data.table >= 1.17.0`, codes NUTS
  BEFORE_2019, NIS 2025 → NBB / NUTS2, poids Oudsbergen, `identify_from_names()`.
- **Non nécessaires mais cassants** : tous les renommages de la 2.0.0 (colonnes de
  `master_data`, de `convert_dataset()` / `split_ambiguous()` par défaut, `get_crosswalk()`,
  `list_available_conversions()` / `get_conversion_matrix()`, `fuzzy_match_names()` /
  `identify_from_names()`, jeux d'exemple) et le retrait des tables larges de
  `load_master_data()` (3.0.0). Ce sont eux qui toucheront le plus les utilisateurs
  existants.
- **Décision utilisateur (2026-10-30)** : ces changements non nécessaires sont **conservés
  tels quels** (pas de rétablissement des anciens noms, pas d'option de compatibilité, pas
  de réexposition des tables larges). La migration des utilisateurs passe par la NEWS
  (tables de correspondance 2.0.0 et 3.0.0) et `wide_view()`. Cette décision vaut pour les
  branches existantes ; tout **nouveau** changement reste soumis à la règle « seulement si
  nécessaire ».
