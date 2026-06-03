# Documentation locale — nbbbenuts

Site de documentation statique généré à partir des fichiers source du package
(`man/*.Rd`, `vignettes/*.Rmd`, `NEWS.md`). Aucun accès réseau requis.

---

## Prérequis

**Python 3.8+** et deux bibliothèques :

```bash
pip3 install markdown jinja2
```

---

## Construire et lancer

Depuis la **racine du projet** :

```bash
# Construire le site et démarrer un serveur sur http://localhost:8080
python3 docs_build/build_site.py --serve

# Construire seulement (sans serveur)
python3 docs_build/build_site.py
```

Le site généré se trouve dans `docs_build/site/` (ignoré par git).  
Ouvrir <http://localhost:8080> dans un navigateur.

---

## Mettre à jour le site

Le site se régénère entièrement à chaque exécution du script.  
Il suffit de relancer la commande après avoir modifié :

| Ce qui change | Fichiers source lus |
|---------------|---------------------|
| Documentation d'une fonction | `man/<nom>.Rd` |
| Un article / guide | `vignettes/<nom>.Rmd` |
| Notes de version | `NEWS.md` |
| Organisation des sections | `docs_build/build_site.py` → variable `REFERENCE` |
| Style / couleurs | `docs_build/build_site.py` → variable `BASE_CSS` |

---

## Structure du site généré

```
docs_build/site/
├── index.html              # Page d'accueil
├── search.json             # Index de recherche
├── news.html               # Contenu de NEWS.md
├── reference/
│   ├── index.html          # Index des fonctions par thème
│   ├── convert_codes.html
│   ├── rebase_series.html
│   └── ...                 # Une page par fonction exportée
└── articles/
    ├── index.html          # Liste des guides
    ├── introduction.html
    ├── conversions.html
    ├── ambiguous-splits.html
    └── diagnostics.html
```

---

## Ajouter une fonction à la référence

Ouvrir `docs_build/build_site.py` et ajouter le nom dans la variable `REFERENCE` :

```python
REFERENCE = [
    ...
    ("Ma nouvelle section", [
        "ma_fonction",
    ]),
]
```

La page sera générée automatiquement depuis `man/ma_fonction.Rd`.

---

## Changer le port

```bash
# Éditer la ligne PORT dans build_site.py, ou lancer un serveur manuellement :
python3 -m http.server 9090 --directory docs_build/site
```
