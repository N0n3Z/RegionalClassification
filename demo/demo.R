# ==============================================================================
# demo.R — Démonstration complète du package nbbbenuts
#
# Ce script illustre toutes les fonctions publiques du package.
# Exécuter section par section dans RStudio ou en ligne de commande :
#   Rscript demo/demo.R
# ==============================================================================

library(nbbbenuts)
library(data.table)


# ==============================================================================
# 0. Chargement des données de référence
# ==============================================================================

master_data <- load_master_data()
# > Master data loaded from '.../inst/extdata':
# > 583 communes NIS 2019, 567 NIS 2025, 589 NIS BEFORE_2019


# ==============================================================================
# 1. Classifications disponibles
# ==============================================================================

# Liste tous les identifiants canoniques (22 au total)
get_all_classification_nodes()

# Matrice de conversions possibles (1 = route disponible)
get_conversion_matrix()

# Détail d'une route avant conversion
print_conversion_check("NIS_COMMUNE_2019", "NUTS3_2021")
# > Path: NIS_COMMUNE_2019 -> NUTS_LAU_2021 -> NUTS3_2021  (simple)

print_conversion_check("NIS_ARRONDISSEMENT_2019", "NUTS3_2021")
# > NOT simple: arrondissement Verviers (63000) est ambiguë (BE335 + BE336)

# Documentation complète des identifiants
# ?classification_reference


# ==============================================================================
# 2. Conversion de codes — convert_codes()
# ==============================================================================

# --- 2a. Communes NIS 2019 → NUTS3 2021 ----------------------------------------
convert_codes(
  c(21004L, 11002L, 44021L, 62063L),
  from = "NIS_COMMUNE_2019",
  to   = "NUTS3_2021",
  master_data
)
#    code_from  code_to
# 1:     21004   BE100   (Bruxelles-Capitale)
# 2:     11002   BE211   (Arrondissement d'Anvers)
# 3:     44021   BE234   (Arrondissement de Gand)
# 4:     62063   BE332   (Arrondissement de Liège)

# --- 2b. Codes postaux → NIS communes ------------------------------------------
convert_codes(c(1000L, 2000L, 4000L), "POSTAL", "NIS_COMMUNE_2019", master_data)
#    code_from  code_to
# 1:      1000    21004   (Bruxelles)
# 2:      2000    11002   (Anvers)
# 3:      4000    62063   (Liège)

# --- 2c. NIS commune → tous les niveaux géographiques -------------------------
commune <- 11002L  # Anvers

convert_codes(commune, "NIS_COMMUNE_2019", "NIS_ARRONDISSEMENT_2019", master_data)
convert_codes(commune, "NIS_COMMUNE_2019", "NIS_PROVINCE_2019",       master_data)
convert_codes(commune, "NIS_COMMUNE_2019", "NIS_REGION_2019",         master_data)
convert_codes(commune, "NIS_COMMUNE_2019", "NUTS3_2021",              master_data)
convert_codes(commune, "NIS_COMMUNE_2019", "NUTS2_2021",              master_data)
convert_codes(commune, "NIS_COMMUNE_2019", "NUTS1_2021",              master_data)
convert_codes(commune, "NIS_COMMUNE_2019", "NUTS0",                   master_data)
convert_codes(commune, "NIS_COMMUNE_2019", "INTERNAL_ARRONDISSEMENT", master_data)

# --- 2d. Conversions entre versions NIS ----------------------------------------

# NIS 2019 → NIS 2025 (fusions de communes)
convert_codes(c(11002L, 11007L), "NIS_COMMUNE_2019", "NIS_COMMUNE_2025", master_data)
# 11002 → 11002  (inchangée)
# 11007 → 11002  (fusionnée dans 11002 en 2025)

# NIS 2025 → NIS 2019 (décomposition — retourne plusieurs lignes)
convert_codes(11002L, "NIS_COMMUNE_2025", "NIS_COMMUNE_2019", master_data,
              allow_ambiguous = TRUE)
# 11002 → 11002
# 11002 → 11007

# NIS BEFORE_2019 → NIS 2019
convert_codes(c(55022L, 56011L), "NIS_COMMUNE_BEFORE_2019", "NIS_COMMUNE_2019",
              master_data)

# --- 2e. NUTS 2027 (EU regulation 2026/195) ------------------------------------
convert_codes(
  c(21004L, 11002L, 44021L),
  "NIS_COMMUNE_2019", "NUTS3_2027",
  master_data
)
# 21004 → BE100  (Bruxelles, inchangé)
# 11002 → BE261  (Anvers : BE211 → BE261)
# 44021 → BE274  (Gand   : BE234 → BE274)

# NUTS 2021 ↔ NUTS 2027 aller-retour
nuts2027 <- convert_codes(
  c("BE211", "BE223", "BE231", "BE335"),
  "NUTS3_2021", "NUTS3_2027", master_data
)
convert_codes(nuts2027$code_to, "NUTS3_2027", "NUTS3_2021", master_data)

# --- 2f. Conversion ambiguë — arrondissement Verviers (M:N) --------------------
# Par défaut, une erreur est levée pour les conversions ambiguës
tryCatch(
  convert_codes(63000L, "NIS_ARRONDISSEMENT_2019", "NUTS3_2021", master_data),
  error = function(e) message("Erreur attendue : ", conditionMessage(e))
)

# Forcer toutes les correspondances possibles
convert_codes(63000L, "NIS_ARRONDISSEMENT_2019", "NUTS3_2021",
              master_data, allow_ambiguous = TRUE)
#    code_from  code_to
# 1:     63000   BE335   (Arr. Verviers francophone)
# 2:     63000   BE336   (Arr. Verviers germanophone)


# ==============================================================================
# 3. Conversion d'un dataset — convert_dataset()
# ==============================================================================

dt <- data.table(
  cd_commune = c(21004L, 11002L, 44021L, 62063L),
  pop        = c(180000L, 530000L, 260000L, 200000L)
)

# Auto-détection de la classification source + ajout d'une colonne NUTS3
convert_dataset(dt, "cd_commune",
                from = "NIS_COMMUNE_2019",
                to   = "NUTS3_2021",
                master_data)
# Ajoute la colonne 'cd_nuts3_2021'.

# Conversion complète : communes → NUTS3 → arrondissements NIS
dt2 <- copy(dt)
convert_dataset(dt2, "cd_commune", from = "NIS_COMMUNE_2019",
                to = "NIS_ARRONDISSEMENT_2019", master_data)


# ==============================================================================
# 4. Validation de codes — validate_codes()
# ==============================================================================

validate_codes(c(21004L, 99999L, 11002L), "NIS_COMMUNE_2019", master_data)
#      code  is_valid
# 1:  21004      TRUE
# 2:  99999     FALSE
# 3:  11002      TRUE

validate_codes(c("1000", "9999"), "POSTAL", master_data)
validate_codes(c("BE100", "ZZZZ"), "NUTS3_2021", master_data)
validate_codes(c("21", "99"),      "INTERNAL_ARRONDISSEMENT", master_data)


# ==============================================================================
# 5. Noms officiels — get_label()
# ==============================================================================

# Noms français
get_label(c(21004L, 11002L, 62063L), "NIS_COMMUNE_2019", master_data, lang = "fr")
#      code      label
# 1:  21004  Bruxelles
# 2:  11002      Anvers
# 3:  62063      Liège

# Noms néerlandais
get_label(c(21004L, 11002L), "NIS_COMMUNE_2019", master_data, lang = "nl")

# NUTS3
get_label(c("BE100", "BE211", "BE332"), "NUTS3_2021", master_data, lang = "fr")

# Codes postaux
get_label(c(1000L, 2000L), "POSTAL", master_data, lang = "fr")

# Code inconnu → NA
get_label(c(21004L, 99999L), "NIS_COMMUNE_2019", master_data)


# ==============================================================================
# 6. Table de correspondance — get_crosswalk()
# ==============================================================================

# Correspondance complète communes → NUTS3
cw <- get_crosswalk("NIS_COMMUNE_2019", "NUTS3_2021", master_data)
head(cw)

# Correspondance postaux → communes (N:1 — chaque code postal apparaît une fois)
get_crosswalk("POSTAL", "NIS_COMMUNE_2019", master_data)

# Avec colonne de poids — utile pour les paires ambiguës
get_crosswalk("NIS_ARRONDISSEMENT_2019", "NUTS3_2021", master_data, weights = TRUE)
# ...
# 63000   BE335   0.5   (poids égaux par défaut)
# 63000   BE336   0.5

# Avec poids de population enregistrés (voir section 8)
register_split_weights(
  "NIS_ARRONDISSEMENT_2019", "NUTS3_2021",
  data.table(code_from = c(63000L, 63000L),
             code_to   = c("BE335", "BE336"),
             weight    = c(0.857, 0.143))
)
get_crosswalk("NIS_ARRONDISSEMENT_2019", "NUTS3_2021", master_data, weights = TRUE)
# 63000   BE335   0.857
# 63000   BE336   0.143
clear_split_weights()


# ==============================================================================
# 7. Diagnostic de couverture — diagnose_classification()
# ==============================================================================

# --- 7a. Mode vérification (classification fournie) ----------------------------
nuts3_data <- data.table(
  nuts3 = c("BE100", "BE211", "BE332"),
  value = c(100, 200, 150)
)

diagnose_classification(nuts3_data, "nuts3", master_data,
                        classification = "NUTS3_2021")
# Affiche : couverture, codes manquants, codes inconnus, doublons

# Le résultat invisible contient les détails structurés
diag <- diagnose_classification(nuts3_data, "nuts3", master_data,
                                classification = "NUTS3_2021", verbose = FALSE)
diag$coverage_rate   # fraction de codes de référence présents
diag$status          # "COMPLETE", "INCOMPLETE", "COMPLETE_WITH_UNKNOWNS", ...
diag$missing_codes   # data.table des codes absents
diag$unknown_codes   # data.table des codes non reconnus

# --- 7b. Mode auto-détection (classification = NULL) ---------------------------
diagnose_classification(nuts3_data, "nuts3", master_data)
# Classe toutes les classifications par taux de correspondance et recommande la meilleure


# ==============================================================================
# 8. Correspondances pondérées — split_ambiguous() et registre de poids
# ==============================================================================

# --- 8a. split_ambiguous() directement -----------------------------------------
arr_data <- data.table(
  arr_code   = c(11000L, 62000L, 63000L),
  total_wage = c(5e9, 3e9, 1e9),
  avg_salary = c(2900, 2700, 2400)
)

# Poids égaux (par défaut) — variable additive
split_ambiguous(
  arr_data,
  code_col   = "arr_code",
  value_cols = c("total_wage"),
  from       = "NIS_ARRONDISSEMENT_2019",
  to         = "NUTS3_2021",
  master_data,
  value_type = "additive"
)
# 63000 → BE335 : total_wage * 0.5
# 63000 → BE336 : total_wage * 0.5

# Variable ratio — valeurs inchangées dans les deux cibles
split_ambiguous(
  arr_data,
  code_col   = "arr_code",
  value_cols = "avg_salary",
  from       = "NIS_ARRONDISSEMENT_2019",
  to         = "NUTS3_2021",
  master_data,
  value_type = "ratio"
)

# --- 8b. Template de poids — split_weights_template() --------------------------
tpl <- split_weights_template("NIS_ARRONDISSEMENT_2019", "NUTS3_2021", master_data)
#    code_from  code_to  weight
# 1:     63000    BE335     0.5
# 2:     63000    BE336     0.5

# Remplacer par des poids de population
tpl[code_from == "63000" & code_to == "BE335", weight := 0.857]
tpl[code_from == "63000" & code_to == "BE336", weight := 0.143]

# --- 8c. Registre de poids pour réutilisation ----------------------------------
register_split_weights(
  from       = "NIS_ARRONDISSEMENT_2019",
  to         = "NUTS3_2021",
  weights_dt = tpl,
  variable   = "population"
)

list_split_weights()
#           from            to  variable
# NIS_ARRONDISSEMENT_2019  NUTS3_2021  population

get_split_weights("NIS_ARRONDISSEMENT_2019", "NUTS3_2021", variable = "population")

clear_split_weights()


# ==============================================================================
# 9. Rebasement longitudinal — rebase_series()
# ==============================================================================

# --- 9a. Fusion N:1 : communes qui fusionnent en 2025 --------------------------
# Les communes 11002 (Anvers) et 11007 (Borgerhout) ont fusionné dans NIS 2025.
panel <- data.table(
  year       = c(2022L, 2022L, 2022L, 2025L, 2025L),
  commune    = c(11002L, 11007L, 21004L, 11002L, 21004L),
  population = c(530000, 42000, 180000, 590000, 182000)
)

result_n1 <- rebase_series(
  panel,
  period_col  = "year",
  code_col    = "commune",
  value_cols  = "population",
  version_map = list(
    "NIS_COMMUNE_2019" = 2022L,
    "NIS_COMMUNE_2025" = 2025L
  ),
  to          = "NIS_COMMUNE_2025",
  master_data = master_data
)
# 2022 : commune 11002 → 530000 + 42000 = 572000 (fusionnées)
# 2025 : données inchangées (déjà en NIS 2025)

# --- 9b. Variable ratio — taux : aggregation avec la moyenne -------------------
panel_rates <- data.table(
  year    = c(2022L, 2022L),
  commune = c(11002L, 11007L),
  taux_emploi = c(0.62, 0.58)
)

result_ratio <- rebase_series(
  panel_rates,
  period_col  = "year",
  code_col    = "commune",
  value_cols  = "taux_emploi",
  version_map = list("NIS_COMMUNE_2019" = 2022L),
  to          = "NIS_COMMUNE_2025",
  master_data = master_data,
  fun         = mean,
  value_type  = "ratio"
)
# commune 11002 : taux = mean(0.62, 0.58) = 0.60

# --- 9c. Split 1:N : données par arrondissement vers NUTS3 --------------------
# Étape 1 : préparer les poids
tpl2 <- split_weights_template("NIS_ARRONDISSEMENT_2019", "NUTS3_2021", master_data)
tpl2[code_from == "63000" & code_to == "BE335", weight := 0.857]
tpl2[code_from == "63000" & code_to == "BE336", weight := 0.143]

# Étape 2 : enregistrer pour la session
register_split_weights("NIS_ARRONDISSEMENT_2019", "NUTS3_2021", tpl2,
                       variable = "population")

# Étape 3 : rebase
arr_panel <- data.table(
  year    = c(2020L, 2021L, 2020L, 2021L),
  arr     = c(63000L, 63000L, 11000L, 11000L),
  emplois = c(120000, 122000, 310000, 315000)
)

result_1n <- rebase_series(
  arr_panel,
  period_col  = "year",
  code_col    = "arr",
  value_cols  = "emplois",
  version_map = list("NIS_ARRONDISSEMENT_2019" = 2020:2021),
  to          = "NUTS3_2021",
  master_data = master_data
  # split = "population" est la valeur par défaut
)
# BE335 : 120000 * 0.857 ≈ 102840
# BE336 : 120000 * 0.143 ≈ 17160

# Passage des poids directement (usage ponctuel sans registre)
result_direct <- rebase_series(
  arr_panel,
  period_col  = "year",
  code_col    = "arr",
  value_cols  = "emplois",
  version_map = list("NIS_ARRONDISSEMENT_2019" = 2020:2021),
  to          = "NUTS3_2021",
  master_data = master_data,
  split       = tpl2
)

clear_split_weights()

# --- 9d. Périodes non couvertes — warning rcl_missing_periods ------------------
data_mixed <- data.table(year = 2022:2024, commune = 21004L, pop = c(1, 2, 3))
withCallingHandlers(
  rebase_series(
    data_mixed,
    period_col  = "year",
    code_col    = "commune",
    value_cols  = "pop",
    version_map = list("NIS_COMMUNE_2019" = 2022L),
    to          = "NIS_COMMUNE_2025",
    master_data = master_data
  ),
  rcl_missing_periods = function(w) {
    message("Périodes ignorées : ", conditionMessage(w))
    invokeRestart("muffleWarning")
  }
)


# ==============================================================================
# 10. Correspondance floue de noms — fuzzy_match_names()
# ==============================================================================

fuzzy_match_names(
  names    = c("Bruxeles", "Antwerpn", "Liege", "Naemur", "Vervirs"),
  target   = "NIS_COMMUNE_2019",
  master_data,
  max_dist = 0.3,
  language = "both"
)
#   input_name  matched_name  matched_code  distance  is_confident
#   Bruxeles    Bruxelles        21004       0.037      TRUE
#   Antwerpn    Antwerpen        11002       0.037      TRUE
#   Liege       Liège            62063       0.150      TRUE
#   Naemur      Namur            92094       0.167      TRUE
#   Vervirs     Verviers         63079       0.042      TRUE


# ==============================================================================
# 11. Visualisation (requiert le package visNetwork en option)
# ==============================================================================

# Graphe des relations entre classifications
visualize_classification_graph()

# Matrice de conversions
visualize_conversion_matrix()

# Hiérarchie NIS 2019
visualize_hierarchy("NIS_2019", master_data)


# ==============================================================================
# 12. Utilitaires
# ==============================================================================

# Toutes les conversions disponibles dans le package
list_available_conversions()

# Chemin de conversion détaillé
check_conversion_path("POSTAL", "NUTS3_2021")
# $is_simple  TRUE
# $path       "POSTAL -> NIS_COMMUNE_2019 -> NUTS_LAU_2021 -> NUTS3_2021"

check_conversion_path("NIS_COMMUNE_2025", "NUTS3_2021")
# Passe par NIS 2019 en intermédiaire

# Reconstruire le snapshot depuis les fichiers bruts (si data/raw/ est disponible)
# master_data <- rebuild_master_data()
