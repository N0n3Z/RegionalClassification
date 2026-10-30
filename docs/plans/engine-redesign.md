# Note de conception — Un moteur de conversion fondé sur des atomes

> **Statut** : note de conception (2026-10-30), à discuter — aucune décision prise, aucun
> code écrit. Base : `nbbbenuts` 3.0.0 tel que sur `claude/maintainer-docs-demo`.
> Objet : décrire l'architecture cible du moteur, le choix de l'unité atomique (dont la
> question « les codes postaux peuvent-ils être l'atome ? »), un plan de migration et
> ses risques, pour décider à tête reposée.

---

## 1. Constat : un moteur historique qui fonctionne grâce aux tests

Le package convertit correctement aujourd'hui (4 142 tests, dont un invariant de
précision « vérité communale » sur toutes les paires). Mais il le fait par un
**assemblage de couches** plutôt que par construction :

1. **Deux graphes, deux vérités.**
   - le graphe *déclaré* (`CONVERSION_GRAPH_EDGES`, ~70 arêtes écrites à la main, avec
     leur relation) sert à `check_conversion_path()`, `is_simple`, aux notes et aux
     visualisations ;
   - le graphe *exécuté* (les 197 paires présentes dans `crosswalks`) sert à
     `convert_codes()` via une autre recherche de chemin (`.xw_path`).

   Conséquences observées : chemin affiché différent du chemin exécuté (NIS 2025 →
   NUTS_REGION_2021 « via le pays ») ; deux notions de simplicité (`is_simple`
   topologique, `effectively_simple` mesurée sur les données) ; une relation déclarée qui
   contredisait les données (NIS 2025 → NBB déclaré N:1 : trois communes perdues sans
   avertissement, corrigé en 3.0.0).

2. **La composition de chemins perd de la précision.** Composer deux sauts dont l'un est
   agrégé et M:N (commune 2025 → province 2025 → provinces 2019) sur-estime les liens (toute
   la Flandre orientale recevait la province d'Anvers). Parade actuelle : **~150 raccourcis
   directs** calculés au build — en pratique un cache partiel de la fermeture transitive
   (`crosswalks` : 37 941 lignes pour 197 paires sur 23 × 22 = 506 possibles).

3. **La relation (1:1, N:1, 1:N, M:N) est déclarée, pas calculée.** Elle doit être
   recoupée par un test (« relation déclarée = cardinalité observée ») au lieu d'être un
   résultat.

4. **`nature` mélange deux axes** : le type de changement temporel (`UNCHANGED`,
   `FUSION`, `CHANGE_DSTR`, `CHANGE_PROV`) et la sémantique de périmètre (`RECODE`,
   `OVERLAP`) ; elle vaut `NA` sur les chemins composés.

5. **Trois registres se recouvrent** (`CLASSIFICATION_NODES`, `CLASSIFICATION_REGISTRY`,
   objets `nomenclature`) et le code de **build** (lecture Excel, `build_master_table()`)
   cohabite avec le code d'exécution dans `R/`.

Rien de cela n'est un bug aujourd'hui ; c'est un coût de maintenance et un risque à chaque
extension (chaque nouvelle classification ou version demande des arêtes, des raccourcis et
des tests de parité).

---

## 2. Principe : tout est une réunion d'atomes

Toutes les classifications du package sont des **partitions du territoire belge**. Si l'on
choisit une partition **plus fine que toutes les autres** (les *atomes*), chaque unité de
chaque classification est une réunion d'atomes, décrite par une seule table :

```
membership(classification, code, atom)        -- l'unité `code` contient l'atome `atom`
```

Une conversion de A vers B est alors **une seule jointure**, sans recherche de chemin :

```
convert(A -> B) = { (a, b) : il existe un atome x, x ∈ a et x ∈ b }
                = membership[A] ⋈_atom membership[B]
```

Propriétés, toutes **par construction** :

- **Exacte** : c'est littéralement la « vérité communale » que l'invariant de précision
  vérifie aujourd'hui. Plus de chemin grossier possible, plus de raccourcis à matérialiser.
- **Complète** : toute paire est convertible (y compris les 4 paires sans route
  aujourd'hui vers les communes BEFORE_2019) ; la seule question devient « est-ce
  ambigu ? ».
- **Cardinalité calculée** : une source a plusieurs cibles → 1:N ; une cible plusieurs
  sources → N:1 ; les deux → M:N. `is_simple` = « chaque source a une seule cible »
  (aujourd'hui `effectively_simple`), mesurée sur les codes demandés.
- **Temps et systèmes traités pareil** : 2019 → 2025 n'est qu'une paire de classifications
  parmi d'autres ; les communes 2019 et 2025 sont elles-mêmes des réunions d'atomes.
- **Poids** : un poids est une mesure par atome (population, emploi…) ; le poids d'un lien
  (a, b) est la masse des atomes de a ∩ b divisée par celle de a. Le cas Oudsbergen
  devient une simple « mesure inconnue pour l'atome x ».

Vérification faite sur les données actuelles : en passant par les atomes BEFORE_2019, les
paires NIS_DISTRICT_2025 → NUTS_PROVINCE_2021, NUTS_DISTRICT_2027 → NUTS_DISTRICT_2021 et
NIS_PROVINCE_2025 → NIS_PROVINCE_2019 donnent **exactement** les liens du moteur actuel.

---

## 3. Le choix de l'atome

Condition : l'atome doit être une **partition plus fine que toutes les classifications
gérées** (chaque unité = réunion exacte d'atomes), et porter de préférence les **mesures**
servant aux poids. Mesures sur `data/raw/` (2026-10-30) :

| Candidat | Plus fin que tout ? | Stabilité | Mesures (poids) | Verdict |
|---|---|---|---|---|
| Communes NIS 2019 (581) | **Non** : les communes BEFORE_2019 fusionnées en 2019 (Oudsbergen = Opglabbeek + Meeuwen-Gruitrode, de deux arrondissements) ne s'y décomposent pas | — | population livrée 2011–2024 | atome implicite actuel, insuffisant |
| Communes BEFORE_2019 (589) | **Oui** pour toutes les classifications hors codes postaux : les réformes 2019 et 2025 ne font que **fusionner** des communes ou en **déplacer d'entières** | la plus ancienne version | population **inconnue** pour les 15 communes fusionnées en 2019 | repli si l'hypothèse H2 tombe |
| **Codes postaux (1 149)** | **Oui sous hypothèses H1–H2** (ci-dessous) : plus fins que les communes de toutes les versions | mêmes 1 149 codes dans les fichiers 2019 et 2025 | **population par code postal disponible** (données de l'utilisateur) | **recommandé** |
| Secteurs statistiques Statbel (~19 800) | Oui, emboîtés dans les communes | versionnés par Statbel | population officielle par secteur | utile seulement si un jour on descend sous le code postal |

### Les codes postaux comme atome : hypothèses

- **H1 — un code postal appartient à une seule commune.** Faux pour 3 codes sur 1 149, en
  2019 comme en 2025 : 1040 (Etterbeek, débord sur Bruxelles), 1050 (Ixelles, débord sur
  Bruxelles), 1804 (Vilvoorde, débord sur Zemst). Hypothèse acceptée : on les rattache à
  leur **commune principale**, celle que le fichier source marque `KEEP_UNIQUE = TRUE`
  (Etterbeek, Ixelles, Vilvoorde) — exactement ce que fait déjà le package. Coût : la
  population de la partie débordante est comptée dans la commune principale.
- **H2 — un code postal tombe dans une seule commune BEFORE_2019.** Nécessaire pour que
  l'atome soit plus fin que *toutes* les versions. Compatible avec les données : les 7
  communes fusionnées en 2019 ont toutes au moins autant de codes postaux que de communes
  d'origine, avec des codes propres à chaque ancienne commune (Oudsbergen : 3660
  Opglabbeek, 3670 Meeuwen-Gruitrode ; Pelt : 3900 / 3910 ; Puurs-Sint-Amands : 2870 /
  2890 ; Deinze : 9800 / 9850 ; Aalter, Kruisem, Lievegem idem). **À confirmer** avec une
  correspondance code postal → commune BEFORE_2019 (le package ne l'a pas : il n'a que code
  postal → commune 2019 / 2025) ; l'appariement ancien code ↔ ancienne commune ci-dessus
  repose sur la connaissance des codes, pas encore sur un fichier.
- **H3 — stabilité.** Les fichiers 2019 et 2025 contiennent les mêmes 1 149 codes. Un code
  postal créé ou supprimé par bpost demandera une nouvelle version des atomes (le modèle le
  permet : `membership` est versionnée par classification, l'atome peut l'être aussi).
- 1020 (Laeken) n'est pas `KEEP_UNIQUE` dans le fichier 2025 : sous H1 il reste rattaché à
  Bruxelles (21004), ce qui règle au passage son absence actuelle en 2025.

### Ce que cela apporte

- **Poids exacts partout**, y compris Oudsbergen : la part d'Opglabbeek dans le district
  BEFORE_2019 71000 se calcule avec la population de 3660.
- **La dé-fusion 2019 → BEFORE_2019 devient calculable** (Oudsbergen → Opglabbeek +
  Meeuwen-Gruitrode, au prorata de 3660 / 3670) — les 4 dernières paires sans route
  disparaissent.
- Les codes postaux cessent d'être une classification « à part » : ce sont les atomes, et
  toute donnée par code postal (fréquente pour les adresses d'entreprises) se convertit
  exactement vers n'importe quelle classification.

### Recommandation

- **Atome = code postal**, sous H1 (commune principale) et H2 (à confirmer par une
  correspondance code postal → commune BEFORE_2019).
- **Mesures = population par code postal** fournie par l'utilisateur (à intégrer dans
  `data-raw/`, avec sa source et ses années).
- **Repli** si H2 est infirmée pour certains codes : atome = intersection code postal ×
  commune BEFORE_2019 pour ces seuls codes (quelques morceaux de plus), ou atome = commune
  BEFORE_2019 et codes postaux en classification rattachée.
- Garde-fou : l'hypothèse H1 est une approximation documentée ; `membership` garde la trace
  des 3 codes à cheval (`approximated = TRUE`) pour qu'un utilisateur puisse les repérer.

---

## 4. Modèle de données cible

| Table | Contenu | Taille estimée |
|---|---|---|
| `atoms` | `atom` (code postal), `approximated` (H1 : code à cheval rattaché à sa commune principale) | 1 149 lignes |
| `membership` | `classification`, `code`, `atom` | ~25 000 lignes (1 149 atomes × 22 classifications) |
| `entities` | inchangée : `classification`, `code`, `label_fr`, `label_nl` | 3 798 lignes |
| `lineage` | changements de communes publiés par Statbel : `classification_from`, `code_from`, `classification_to`, `code_to`, `change` (`FUSION`, `CHANGE_DSTR`, `CHANGE_PROV`) | ~60 lignes |
| `atom_measures` | `variable`, `year`, `atom`, `value` (population par code postal…) ; `NA` explicite si inconnu | remplace `standard_weight_values` |

`crosswalks` disparaît comme table persistée : il devient une **vue calculée**
(`get_crosswalk()`), mise en cache en mémoire si nécessaire. Le snapshot passe d'environ
38 000 à environ 26 000 lignes. Avec l'atome de repli (communes BEFORE_2019), `membership`
ferait ~13 000 lignes ; l'équivalence avec le moteur actuel a été vérifiée sur cet atome
(section 2), elle le sera sur les codes postaux à l'étape 1.

**Deux colonnes au lieu de `nature`** :
- `change` (temporel, depuis `lineage`) : `UNCHANGED` si a et b ont exactement les mêmes
  atomes, sinon le type publié par Statbel (`FUSION`, `CHANGE_DSTR`, `CHANGE_PROV`), ou
  `REDRAWN` pour un niveau agrégé dont le territoire change (district 46000) ;
- `perimeter` : `IDENTITY` (mêmes atomes), `NESTING` (a ⊂ b), `OVERLAP` (a déborde sur
  plusieurs cibles).

---

## 5. Moteur et API

- `convert_codes(codes, from, to, md, allow_ambiguous)` : **signature inchangée**. Calcul :
  atomes des codes demandés → codes cibles ; blocage si un code demandé a plusieurs cibles
  et `allow_ambiguous = FALSE` (même règle que `effectively_simple` aujourd'hui).
- `check_conversion_path()` : décrit la paire (cardinalité calculée, nombre de codes
  ambigus, périmètre) au lieu d'un chemin. Le champ `path` disparaît ou devient
  `c(from, to)` (changement d'API à documenter).
- Graphe : `list_available_conversions()`, `get_conversion_matrix()` et les
  visualisations sont **dérivés des données** (cardinalité de chaque paire). Les arêtes
  déclarées deviennent de la **documentation vérifiée** : un test exige qu'elles
  correspondent aux cardinalités calculées.
- `split_ambiguous()`, `split_weights_template()`, `rebase_series()`,
  `convert_multi_version()`, `wide_view()` : inchangés côté utilisateur ; les poids
  viennent de `atom_measures`.
- Registre unique : `CLASSIFICATION_NODES` (système, niveau, version, libellés) ; les
  objets `nomenclature` en sont dérivés ; `CLASSIFICATION_REGISTRY` est supprimé.
- Build déplacé : lecture des fichiers bruts et construction dans `data-raw/` (ou un module
  interne non exporté), le package n'exécutant que le moteur.

---

## 6. Plan de migration

Le filet de sécurité existe déjà : l'invariant de précision et la photo « toutes paires »
(291 paires exécutables) disent exactement ce que le nouveau moteur doit reproduire.

| Étape | Contenu | Critère de sortie |
|---|---|---|
| 0 | Photo de référence : toutes les paires exécutables, tous les codes, plus le golden actuel | fixture versionnée |
| 1 | Construire `membership` / `lineage` au build, **en parallèle** de `crosswalks` (rien ne change pour l'utilisateur) | test : jointure par atomes = `crosswalks` sur les 197 paires |
| 2 | Nouveau moteur derrière une option interne ; comparer les 291 paires | résultats identiques (codes) ; écarts de `nature` documentés |
| 3 | Basculer `convert_codes()` sur le nouveau moteur ; `crosswalks` devient une vue | suite de tests verte, CI verte |
| 4 | `nature` → `change` + `perimeter` ; `check_conversion_path()` simplifié | **changement d'API** → version 4.0.0, NEWS avec table de correspondance |
| 5 | Supprimer le graphe déclaré du moteur (gardé comme documentation testée), les raccourcis, `.xw_path`, `CLASSIFICATION_REGISTRY` | `R CMD check` OK, code net en baisse |
| 6 | Poids par code postal (`atom_measures`) : remplace la population communale ; débloque Oudsbergen et la dé-fusion 2019 → BEFORE_2019 | poids = population livrée sur toutes les paires où les deux coexistent (au prorata des 3 codes approximés) |

Préalable à l'étape 1 : obtenir (ou construire et valider) la correspondance code postal →
commune BEFORE_2019 pour confirmer H2, et intégrer la population par code postal dans
`data-raw/` (source, années, licence).

Les étapes 1 à 3 sont **sans changement d'API** et peuvent sortir en 3.x ; l'étape 4 est la
seule rupture.

---

## 7. Risques

| Risque | Mesure |
|---|---|
| Différences subtiles de `nature` entre l'ancien et le nouveau moteur | étape 2 : comparaison exhaustive, écarts listés et validés un par un |
| Performance (jointure à chaque appel) | tables minuscules (~13 000 lignes) ; jointure `data.table` indexée ; cache par paire si besoin |
| Classifications futures qui recoupent les atomes (autres zonages) | `membership` supporte les recoupements (M:N explicite) ; l'atome peut descendre au secteur statistique sans changer le moteur |
| H2 infirmée pour quelques codes postaux (un code couvrant deux anciennes communes) | repli local : atome = intersection code postal × commune BEFORE_2019 pour ces codes |
| Approximation H1 (3 codes à cheval) | tracée (`approximated`), documentée ; impact limité aux débords de 1040, 1050 vers Bruxelles et de 1804 vers Zemst |
| Codes postaux modifiés par bpost | nouvelle version des atomes ; le build vérifie que chaque code de chaque fichier est connu |
| Utilisateurs de `check_conversion_path()$path` ou de `crosswalks` directement | étape 4 seulement, avec version majeure et table de migration |
| Perte de l'information « chemin » utile pédagogiquement | `print_conversion_check()` peut toujours expliquer la paire (atomes communs, unités ambiguës) |

---

## 8. Décisions à prendre

1. Engager la refonte, ou rester sur le moteur actuel (exact et testé) ?
2. Atome : codes postaux (recommandé, sous H1 et H2) ou communes BEFORE_2019 ?
3. Source de la correspondance code postal → commune BEFORE_2019 pour confirmer H2, et
   source / années / licence de la population par code postal ?
4. Accepter la rupture d'API de l'étape 4 (`nature` scindée, `check_conversion_path()`
   simplifié) en 4.0.0, ou s'arrêter à l'étape 3 (refonte interne, API inchangée) ?
