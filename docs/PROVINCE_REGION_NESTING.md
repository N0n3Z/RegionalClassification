# Province → Region : un emboîtement N:1 (et la pseudo-province de Bruxelles)

## TL;DR

`NIS_PROVINCE_* → NIS_REGION_*` est une relation **N:1 (`nesting`)**, et non
`M:N` (`overlap`). Chaque province appartient à exactement une région.

Ce document explique pourquoi l'ancien modèle était `M:N`, pourquoi c'était un
artefact de construction, et comment la **pseudo-province de Bruxelles** rend
l'emboîtement parfait.

## 1. Le problème historique

Avant cette correction, le code de province était dérivé de l'arrondissement par
troncature :

```r
cd_prov_candidate <- (cd_arr %/% 10000L) * 10000L
```

Pour les quatre arrondissements de l'ancien Brabant, cette règle produisait
**toujours le même code 20000** :

| Arrondissement | Nom            | Région réelle      | Province (ancien build) |
|----------------|----------------|--------------------|-------------------------|
| 21000          | Bruxelles-Cap. | Bruxelles (4000)   | 20000                   |
| 23000          | Hal-Vilvorde   | Flandre (2000)     | 20000                   |
| 24000          | Louvain        | Flandre (2000)     | 20000                   |
| 25000          | Nivelles       | Wallonie (3000)    | 20000                   |

La province fictive `20000` enjambait donc **trois régions** → la relation
`province → region` était déclarée `M:N` (`overlap`).

## 2. La réalité (REFNIS)

La province de Brabant **n'existe plus depuis le 1ᵉʳ janvier 1995**. Le fichier
REFNIS officiel (vérifié pour 2025, identique en logique pour 2019 / BEFORE_2019)
**ne contient aucun code 20000**. Il contient :

| Code   | Province               | Région             |
|--------|------------------------|--------------------|
| 20001  | Brabant flamand (Vlaams-Brabant) | Flandre (2000) |
| 20002  | Brabant wallon         | Wallonie (3000)    |

> ⚠️ Attention au piège : `20001 = Brabant **flamand**`, `20002 = Brabant
> **wallon**` (contre-intuitif). Source : `data/raw/REFNIS_2025.xlsx`.

Bruxelles-Capitale, elle, **n'a pas de province** : la hiérarchie REFNIS va
directement `commune → arrondissement 21000 → région 4000`.

## 3. La correction

### 3.1 Codes de province réels pour le Brabant

Le mapping arrondissement → province est désormais explicite
(`NIS_ARR_PROVINCE_OVERRIDE` dans `R/00_config.R`) :

- `23000` (Hal-Vilvorde) → `20001`
- `24000` (Louvain)      → `20001`
- `25000` (Nivelles)     → `20002`

Tous les autres arrondissements gardent la règle par troncature, qui reste
correcte (ex. `11000 → 10000` Anvers).

### 3.2 La pseudo-province de Bruxelles

Bruxelles n'ayant pas de province statutaire, on lui attribue une
**pseudo-province synthétique** dont le code est **égal au code de la région**,
soit **`4000`** (`NIS_PROVINCE_BRUSSELS`). Une ligne de province est injectée à
l'analyse (`R/01_load_data.R`), avec le libellé de la région.

Résultat : l'arrondissement `21000` → province `4000` → région `4000`.

### 3.3 Province → région : N:1 propre

`NIS_PROVINCE_TO_REGION` (`R/00_config.R`) est la source unique de vérité :

| Province | Région  |        | Province | Région  |
|----------|---------|--------|----------|---------|
| 10000    | 2000    |        | 20002    | 3000    |
| 20001    | 2000    |        | 50000    | 3000    |
| 30000    | 2000    |        | 60000    | 3000    |
| 40000    | 2000    |        | 80000    | 3000    |
| 70000    | 2000    |        | 90000    | 3000    |
| **4000** | **4000**|        |          |         |

Chaque province → une seule région. L'arête est donc `N:1` / `nesting`, et la
conversion `province → region` ne requiert plus `allow_ambiguous = TRUE`.

## 4. Mise en garde : collision numérique 4000

Le code de pseudo-province `4000` est **identique** au code de la région de
Bruxelles-Capitale. Ce choix est délibéré (cohérent avec NUTS, où Bruxelles est
à la fois NUTS1 `BE1` et NUTS2 `BE10`) et sans danger pour l'API de conversion,
qui prend toujours des classifications `from` / `to` explicites.

**Seule limite** : une détection automatique sur un code nu `4000` ne peut pas
distinguer « province » de « région ». Si l'auto-détection est utilisée, `4000`
sera interprété comme une région. Spécifiez explicitement la classification pour
lever toute ambiguïté.

## 5. Fichiers touchés

- `R/00_config.R` — constantes, `NIS_ARR_PROVINCE_OVERRIDE`,
  `NIS_PROVINCE_TO_REGION`, arêtes `province → region` passées en `N:1`.
- `R/01_load_data.R` — classification de niveau (20001/20002), injection de la
  pseudo-province de Bruxelles, mapping province → région.
- `R/02_build_master_table.R` — commentaires ; le bloc de résolution Brabant
  devient un filet de sécurité défensif.
- Tests : `test-route-parity.R`, `test-perimeter-semantics.R`.
- Docs : `DOCUMENTATION.md`, `docs/articles/conversions.md`, docstrings.
