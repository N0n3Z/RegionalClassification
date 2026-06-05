# Documentation — `nbbbenuts` (RegionalClassification)

> Document d'ensemble, accessible et complet, sur le package et l'état des travaux.
> Pour le détail d'exécution du refactor en cours, voir `REFACTOR_CROSSWALKS.md`.
> Pour les règles projet (commandes, conventions), voir `CLAUDE.md`.

---

## 1. À quoi sert le package

`nbbbenuts` est un package R qui **convertit des codes géographiques belges** entre
plusieurs systèmes de classification et à travers le temps :

- **Systèmes** : NIS (codes Statbel : communes, arrondissements, provinces, régions),
  NUTS (codes Eurostat : NUTS0/1/2/3, LAU), codes **postaux**, et une classification
  **interne** (arrondissements 2 chiffres, avec Verviers scindé 65/66).
- **Versions dans le temps** : NIS `BEFORE_2019` / `2019` / `2025` (les communes
  fusionnent au fil des réformes), NUTS `2021` / `2027`.

Exemple d'usage typique : on a un jeu de données indexé par code postal et on veut
le réexprimer en NUTS3, ou rebaser un panel communal 2019→2025 malgré les fusions.

```r
library(nbbbenuts)
md <- load_master_data()                         # charge la table de référence (rapide)

convert_codes(c(21004L, 11002L), "NIS_COMMUNE_2019", "NUTS3_2021", md)
convert_codes(c(1000L, 2000L),  "POSTAL",           "NIS_COMMUNE_2019", md)
```

---

## 2. Le concept central : le **périmètre géographique**

L'unité fondamentale n'est pas le *code* mais le **périmètre** : un territoire délimité
sur la carte. Un même périmètre reçoit **plusieurs codes** selon le système
(p.ex. la Région bruxelloise = NIS `4000`, NUTS1 `BE1`, NUTS2 `BE10`…). Convertir, c'est
soit **changer d'étiquette** (même territoire), soit **suivre un territoire qui évolue**.

Quatre **types de conversion**, du plus simple au plus complexe :

| Type | Nature | Cardinalité | Exemple | Données |
|------|--------|-------------|---------|---------|
| **A — Recodage** | même périmètre, code différent | 1:1 ou N:1 | `NIS_COMMUNE_2019 → NUTS3_2021` | exact, agrégation simple |
| **B — Temporel stable** | code change, territoire inchangé | 1:1 | majorité des communes 2019→2025 | exact (`nature = UNCHANGED`) |
| **C — Temporel modifié** | le territoire évolue | N:1 (forward) | fusions de communes | agrégation nécessaire (`FUSION`) |
| **D — Chevauchement** | un périmètre source enjambe une frontière cible | 1:N / M:N | Verviers → BE335 + BE336 | **désagrégation par poids** |

Les cas **D** sont les seuls qui exigent des **poids exogènes** (population, emploi,
surface…) fournis par l'utilisateur pour répartir une donnée de part et d'autre de la
frontière.

---

## 3. Les 22 classifications supportées

Identifiant interne sous la forme lisible utilisée dans les appels :

- **NIS** : `NIS_{COMMUNE,ARRONDISSEMENT,PROVINCE,REGION}_{BEFORE_2019,2019,2025}`
- **NUTS 2021** : `NUTS_LAU_2021`, `NUTS3_2021`, `NUTS2_2021`, `NUTS1_2021`, `NUTS0`
- **NUTS 2027** : `NUTS3_2027`, `NUTS2_2027`, `NUTS1_2027` (NUTS0 partagé)
- **POSTAL**, **INTERNAL_ARRONDISSEMENT**

`get_all_classification_nodes()` les liste ; `list_available_conversions()` montre les
liens possibles et leur cardinalité.

---

## 4. Les fonctions principales (API)

| Fonction | Rôle |
|----------|------|
| `load_master_data()` | charge la table de référence pré-construite (rapide, sans fichiers bruts) |
| `convert_codes(codes, from, to, md, allow_ambiguous=)` | **cœur** : convertit un vecteur de codes. Renvoie `data.table(code_from, code_to, nature)` |
| `convert_dataset(dt, code_col, from, to, md)` | convertit une colonne d'un tableau, en gardant les autres colonnes |
| `check_conversion_path(from, to)` / `print_conversion_check()` | indique si une conversion est « simple » (exacte) ou ambiguë, et le chemin emprunté |
| `validate_codes(codes, classification, md)` | vérifie l'appartenance de codes à une classification |
| `get_label(codes, classification, md)` | renvoie les libellés (FR/NL) |
| `get_crosswalk(from, to, md)` | table de correspondance complète entre deux classifications |
| `detect_classification(codes, md)` / `diagnose_classification(...)` | détection automatique + diagnostic de couverture |
| `split_ambiguous(...)` + `register_split_weights(...)` | **désagrégation pondérée** des cas D (Verviers, etc.) |
| `rebase_series(...)` | rebasage longitudinal d'un panel sur une version cible (agrégation/split) |
| `fuzzy_match_names(...)` | rattachement de noms (mal orthographiés) à des codes |
| `rebuild_master_data()` | reconstruit la table de référence depuis les fichiers bruts (`data/raw/`) |

**Garde-fou** : par défaut, `convert_codes` **refuse** une conversion ambiguë (type D)
et lève une erreur typée `rcl_ambiguous_conversion`. Il faut `allow_ambiguous = TRUE`
pour obtenir toutes les correspondances, puis `split_ambiguous()` pour répartir les
données avec des poids.

```r
# Verviers : ambigu sans allow_ambiguous
convert_codes(63000L, "NIS_ARRONDISSEMENT_2019", "NUTS3_2021", md, allow_ambiguous = TRUE)
#  -> 2 lignes : 63000 -> BE335 et 63000 -> BE336
```

---

## 5. Architecture interne (comment ça marche)

### 5.1 Le registre des classifications — `CLASSIFICATION_NODES` (`R/00b_registry.R`)
**Source de vérité unique** décrivant chaque nœud : `system`, `level`, `version`,
`code_type` (integer/character), `source_table`, colonne du code, colonnes de libellés,
et `aggregates` (le niveau plus fin qu'il agrège — voir §6.2). Tout en dérive : la
validation, la détection, les libellés, la coercition de type. *Avant*, cette
connaissance était dupliquée en 5 endroits ; elle est désormais centralisée.

### 5.2 Le graphe de conversion — `CONVERSION_GRAPH_EDGES` (`R/00_config.R`)
Déclare les **liens primitifs** entre nœuds, chacun avec une **cardinalité**
(`1:1`, `N:1`, `1:N`, `M:N`). Le moteur fait une **recherche de chemin (BFS)** sur ce
graphe (`R/05_conversion_check.R`) : une conversion est « simple » si tout le chemin est
en `1:1`/`N:1`. Les chemins multi-sauts sont **composés** automatiquement.

### 5.3 L'exécuteur — `route_conversion` (`R/03_convert.R`)
Pour chaque saut, applique un *handler* (aujourd'hui une table `.ROUTE_TABLE` de
fonctions), sinon **compose** les sauts le long du chemin. Le résultat est normalisé au
schéma `(code_from, code_to, nature)`. La cohérence graphe ⇄ exécuteur est verrouillée
par `tests/testthat/test-route-parity.R`.

### 5.4 La table de référence (`master_data`)
Chargée via `load_master_data()` depuis `inst/extdata/*.rds`. Aujourd'hui :
- `communes` : table large, une ligne par (commune, version NIS), avec toutes les
  colonnes NUTS/internes ;
- `postal`, `nis_changes` (transitions de version avec `nature`) ;
- **nouveau (Phase 1 du refactor)** : `entities` et `crosswalks` (voir §7).

### 5.5 L'objet `nomenclature` (`R/00c_nomenclature.R`)
Interface **programmatique** additive : `nomenclature("NIS","commune","2019")` construit
un objet structuré (validé contre le registre), avec accesseurs
(`nom_system/level/version`), introspection (`list_nomenclatures`, `nomenclature_levels`)
et liens d'agrégation (`nomenclature_children`/`nomenclature_parents`). Les chaînes
continuent de fonctionner partout (coexistence).

---

## 6. Ce qui a été fait — journal des travaux

### 6.1 Unification graphe ⇄ exécuteur + filet de parité
L'exécuteur ne savait faire que les sauts directs codés à la main : certaines conversions
multi-sauts pourtant déclarées « simples » échouaient (`NUTS3_2021 → NUTS0`, etc.).
→ Ajout d'un **composeur générique** + des handlers mono-saut manquants ; suppression du
cas spécial POSTAL. Ajout du test de parité `test-route-parity.R` qui garantit que *toute*
conversion déclarée simple est réellement exécutable. La duplication des ~50 handlers a
été réduite via des *factories*.

### 6.2 Corrections de fond sur la cardinalité (qualité des résultats)
Le test de parité a révélé de vraies erreurs de modélisation, corrigées :
- **`commune → NUTS3` est `N:1`, pas `1:1`** : plusieurs communes partagent un NUTS3.
  L'erreur faisait croire que la descente `NUTS3 → commune` était une conversion exacte,
  alors qu'elle est ambiguë.
- **`province → région` est `M:N`** : la province du **Brabant** (20000) couvre les 3
  régions. Ajout d'un lien direct `commune → région` (`N:1`) pour garder ce chemin simple.
- **`2019 → 2025` est `N:1`** (chaque commune 2019 → une seule commune 2025) ; l'inverse
  `2025 → 2019` est `1:N` pour les fusions.
- **Verviers** : `arrondissement → NUTS3` est `1:N` (pas M:N) — un seul arrondissement
  ambigu.
- **`NUTS3_2021 ↔ NUTS3_2027` supprimé** : 3 communes ont changé de province entre 2019 et
  2025, déplaçant leur NUTS3 → une simple table de renommage serait **fausse** pour elles.
  La conversion vers 2027 passe désormais par les données officielles via NIS 2025.

### 6.3 Registre source-de-vérité + schéma de retour uniforme
- Création de `CLASSIFICATION_NODES` ; `query` / `detect` / `diagnose` / labels rebranchés
  dessus (fin des 5 copies dupliquées). Coercition de type integer/caractère centralisée.
- `convert_codes()` renvoie désormais un schéma **uniforme** `(code_from, code_to, nature)`.
- **Nouveaux chemins `NIS_COMMUNE_2025 → NUTS3_2021 / INTERNAL`** : backfill au build pour
  les communes inchangées ; les **3 fusions cross-NUTS3** (46029, 46030, 71072) sont
  traitées en `1:N`. Validation de schéma de la table `communes` au build.

### 6.4 Objet `nomenclature` (interface programmatique)
Couche additive pour manipuler les classifications dynamiquement et naviguer la
hiérarchie d'agrégation, sans casser l'API « chaîne ». (Branche `feature/nomenclature-object`.)

### 6.5 Refonte de la `master_data` en modèle normalisé — **Phase 0 + 1 faites**
Constat : la table `communes` large a des colonnes à sens conditionnel à la version, et
les cas 1:N/M:N « fuient » hors du modèle (reconstruits par du code ad hoc). Cible : un
modèle **normalisé** (voir §7). Réalisé jusqu'ici :
- `entities` + `crosswalks` construits **depuis les sources** au build ;
- **filet de sécurité** : fixture *golden* (sorties du moteur actuel figées) +
  test de **parité par arête** (le crosswalk reproduit exactement le moteur).
Le moteur n'est **pas encore** branché sur les crosswalks (Phase 2 à venir).
La Phase 1 a été **durcie** (assertion de couverture, univers postal cohérent, identité
de contenu confirmée) et l'ensemble de la suite passe (**962 tests**).

---

## 7. Le modèle cible `entities` + `crosswalks`

Pour rendre le modèle de données **isomorphe au modèle conceptuel** :

- **`entities(classification_id, code, name_fr, name_nl)`** — les membres de chaque nœud.
- **`crosswalks(from_id, to_id, code_from, code_to, relation, nature)`** — **une ligne par
  lien primitif**. Les cas D deviennent **natifs** : Verviers = 2 lignes
  (`63000→BE335`, `63000→BE336`). Plus de handler spécial.
- **`weights(...)`** (à venir) — poids exogènes **ancrés** aux lignes de chevauchement.

Bénéfices : fin des colonnes version-conditionnelles, 1:N/M:N en données (pas en code),
hiérarchies non dupliquées, exécuteur réduit à « lire la table de l'arête puis composer ».

---

## 8. Feuille de route (refactor crosswalks — détail dans `REFACTOR_CROSSWALKS.md`)

| Phase | Contenu | État |
|-------|---------|------|
| **0** | Figer les sorties « golden » du moteur actuel | ✅ fait |
| **1** | Construire `entities` + `crosswalks` (additif) + parité | ✅ fait |
| **2** | Brancher l'exécuteur sur `crosswalks` (suppression des handlers) | ⏳ à venir |
| **3** | Lecteurs (detect/diagnose/query/fuzzy) sur `entities` | ⏳ |
| **4** | Sémantique de périmètre 1re classe (`perimeter_relation`, `is_perimeter_preserving`), `nature` partout (RECODE/OVERLAP), **poids ancrés au périmètre** + poids par colonne | ⏳ |
| **5** | Clarifier `CHANGE_DSTR`/`CHANGE_PROV` (recodage à commune entière ?) + vignette « modèle de périmètre » | ⏳ |

**Règle d'or** : ne pas faire la Phase 2 tant que `test-crosswalks-parity.R` n'est pas vert.

---

## 9. État des branches

| Branche | Contenu |
|---------|---------|
| `main` | Registre source-de-vérité, corrections de cardinalité, schéma de retour uniforme, chemins NIS 2025→NUTS 2021, README à jour. **Base stable.** |
| `feature/nomenclature-object` | `main` + objet `nomenclature` (Phase A) + champ `aggregates`. |
| `feature/crosswalks-model` | `feature/nomenclature-object` + `entities`/`crosswalks` (Phase 0+1) + golden/parité. **Branche la plus avancée.** |

---

## 10. Développement & tests

```r
devtools::load_all(".")     # charger le package
devtools::test()            # suite testthat — À FAIRE EN PREMIER pour confirmer l'état
devtools::document()        # régénérer man/ + NAMESPACE après changement roxygen
devtools::check()           # R CMD check complet avant de déclarer terminé
rebuild_master_data()       # reconstruire inst/extdata/*.rds depuis data/raw/ (readxl)
```

Conventions : développer sur une branche de travail, jamais directement sur `main` ;
erreurs/avertissements en classes typées `rcl_*` ; après modif roxygen, `document()`.
Le package tourne normalement sur le snapshot `inst/extdata/*.rds` ; `data/raw/` n'est
nécessaire que pour `rebuild_master_data()`.

### Durcissements Phase 1 (faits — `962 tests passent`)
1. ✅ Assertion de **couverture** ajoutée dans `test-crosswalks-parity.R` : toute clé de
   route (hors BEFORE_2019 optionnel) doit avoir des lignes de crosswalk → un trou échoue
   bruyamment au lieu d'être silencieusement skippé.
2. ✅ `POSTAL → NIS_COMMUNE_2025` : crosswalk bâti sur l'univers **p19** (cohérent avec
   `entities`/`.list_codes_for`) + test vérifiant explicitement l'hypothèse p25 ⊆ p19.
3. ✅ `communes.rds`/`nis_changes.rds` confirmés **content-identiques** à `main` (Phase 1
   purement additive).

---

*Glossaire express* — **NIS** : codes Statbel ; **NUTS** : nomenclature territoriale
Eurostat ; **LAU** : unité administrative locale (= commune) ; **crosswalk** : table de
correspondance entre deux classifications ; **nature** : raison d'un changement temporel
(`UNCHANGED`/`FUSION`/`CHANGE_DSTR`/`CHANGE_PROV`) ; **Verviers** : arrondissement scindé
entre NUTS3 francophone (BE335) et germanophone (BE336), cas D canonique.
