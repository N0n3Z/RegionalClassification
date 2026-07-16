# ==============================================================================
# demo.R -- Demonstration complete du package nbbbenuts
#
# Ce script illustre toutes les fonctions publiques du package.
# Executer section par section dans RStudio ou en ligne de commande :
#   Rscript demo/demo.R
# ==============================================================================

library(nbbbenuts)
library(data.table)


# ==============================================================================
# 0. Chargement des donnees de reference
# ==============================================================================

master_data <- load_master_data()
# > Master data loaded from '.../inst/extdata':
# > 581 communes NIS 2019, 565 NIS 2025, 589 NIS BEFORE_2019


# ==============================================================================
# 1. Classifications disponibles
# ==============================================================================

# Liste tous les identifiants canoniques (23 au total)
get_all_classification_nodes()

# Matrice de conversions possibles
get_conversion_matrix()

# Chemins de conversion avec semantique de perimetre
print_conversion_check("NIS_MUNICIPALITY_2019", "NUTS_DISTRICT_2021")
# Simple conversion: YES
# Perimeter-preserving: YES
# Perimeter relations: identity -> nesting
# Path: NIS_MUNICIPALITY_2019 -> NUTS_MUNICIPALITY_2021 -> NUTS_DISTRICT_2021

print_conversion_check("NIS_DISTRICT_2019", "NUTS_DISTRICT_2021")
# Simple conversion: NO
# Perimeter-preserving: NO (straddle)
# arrondissement Verviers (63000) chevauche BE335 + BE336

print_conversion_check("NIS_MUNICIPALITY_2025", "NUTS_DISTRICT_2021")
# Simple conversion: NO  (3 fusions enjambent les frontieres NUTS3)
# Perimeter-preserving: NO (straddle)

# Test rapide : la conversion preserve-t-elle les perimetres ?
is_perimeter_preserving("NIS_MUNICIPALITY_2019", "NUTS_DISTRICT_2021")   # TRUE
is_perimeter_preserving("NIS_MUNICIPALITY_2025", "NUTS_DISTRICT_2021")   # FALSE (fusions 1:N)
is_perimeter_preserving("NIS_MUNICIPALITY_2019", "NIS_MUNICIPALITY_2025")  # TRUE (temporel)

# --- Simplicite TOPOLOGIQUE vs EFFECTIVE (data-aware) --------------------------
# En passant master_data, check_conversion_path expose deux champs supplementaires :
#   executable          -- le moteur sait-il reellement executer la route ?
#   effectively_simple  -- la route est-elle N:1/1:1 SUR LES DONNEES ? (une agregation
#                          qui traverse une arete overlap mais re-converge vers une
#                          seule cible par source est "effectivement simple")
r <- check_conversion_path("NIS_DISTRICT_2019", "NUTS_PROVINCE_2021", master_data)
r$is_simple            # FALSE : le chemin traverse l'arete 1:N Verviers (topologique)
r$effectively_simple   # TRUE  : BE335 et BE336 nichent tous deux dans BE33 -> 1 cible
r$executable           # TRUE

# La matrice complete avec ces deux colonnes data-aware :
get_conversion_matrix(master_data)[is_simple == FALSE & effectively_simple == TRUE]
# -> les agregations deterministes que convert_codes() accepte sans allow_ambiguous

# Toutes les conversions disponibles avec leur semantique de perimetre
la <- list_available_conversions()
# Colonnes : from, to, relation, perimeter_relation, notes
la[perimeter_relation == "temporal"]   # conversions entre versions NIS
la[perimeter_relation == "overlap"]    # 1:N (enjambement ; aucune arete M:N actuellement)
la[perimeter_relation == "nesting"]    # agregations N:1 pures
la[perimeter_relation == "identity"]   # correspondances 1:1

# Documentation complete des identifiants
# ?classification_reference


# ==============================================================================
# 2. Conversion de codes -- convert_codes()
# ==============================================================================

# --- 2a. Communes NIS 2019 -> NUTS3 2021 ----------------------------------------
convert_codes(
  c(21004L, 11002L, 44021L, 62063L),
  from = "NIS_MUNICIPALITY_2019",
  to   = "NUTS_DISTRICT_2021",
  master_data
)
#    code_from  code_to  nature
# 1:     21004   BE100   RECODE   (Bruxelles-Capitale)
# 2:     11002   BE211   RECODE   (Arrondissement d'Anvers)
# 3:     44021   BE234   RECODE   (Arrondissement de Gand)
# 4:     62063   BE332   RECODE   (Arrondissement de Liege)

# --- 2b. Codes postaux -> NIS communes ------------------------------------------
convert_codes(c(1000L, 2000L, 4000L), "POSTAL", "NIS_MUNICIPALITY_2019", master_data)
#    code_from  code_to  nature
# 1:      1000    21004   RECODE  (Bruxelles)
# 2:      2000    11002   RECODE  (Anvers)
# 3:      4000    62063   RECODE  (Liege)

# --- 2c. NIS commune -> tous les niveaux geographiques -------------------------
commune <- 11002L  # Anvers

convert_codes(commune, "NIS_MUNICIPALITY_2019", "NIS_DISTRICT_2019", master_data)
convert_codes(commune, "NIS_MUNICIPALITY_2019", "NIS_PROVINCE_2019",       master_data)
convert_codes(commune, "NIS_MUNICIPALITY_2019", "NIS_REGION_2019",         master_data)
convert_codes(commune, "NIS_MUNICIPALITY_2019", "NUTS_DISTRICT_2021",              master_data)
convert_codes(commune, "NIS_MUNICIPALITY_2019", "NUTS_PROVINCE_2021",              master_data)
convert_codes(commune, "NIS_MUNICIPALITY_2019", "NUTS_REGION_2021",              master_data)
convert_codes(commune, "NIS_MUNICIPALITY_2019", "NUTS_COUNTRY",                   master_data)
convert_codes(commune, "NIS_MUNICIPALITY_2019", "NBB_DISTRICT_2021", master_data)

# --- 2c-bis. Province -> region : emboitement N:1 (scission du Brabant) ---------
# Depuis la scission de 1995, chaque province appartient a exactement une region :
# pas d'ambiguite, pas besoin de allow_ambiguous. L'ancienne province unifiee du
# Brabant (20000) n'existe plus -> Brabant flamand (20001) / Brabant wallon (20002).
# Bruxelles-Capitale n'a pas de province statutaire : on lui attribue une
# pseudo-province egale a son code de region (4000).
convert_codes(c(10000L, 20001L, 20002L, 4000L),
              "NIS_PROVINCE_2019", "NIS_REGION_2019", master_data)
#    code_from  code_to  nature
# 1:    10000     2000   RECODE  (Anvers          -> Flamande)
# 2:    20001     2000   RECODE  (Brabant flamand -> Flamande)
# 3:    20002     3000   RECODE  (Brabant wallon  -> Wallonne)
# 4:     4000     4000   RECODE  (Bruxelles       -> Bruxelles, pseudo-province)

# --- 2d. Conversions entre versions NIS (colonne nature) -----------------------
#
# Les conversions temporelles portent une colonne 'nature' :
#   UNCHANGED   -- code inchange dans les deux versions (551 communes)
#   FUSION      -- une ou plusieurs communes 2019 fusionnees en un code 2025 (27)
#   CHANGE_DSTR -- commune deplacee dans un autre arrondissement (2 communes)
#   CHANGE_PROV -- commune deplacee dans une autre province (1 commune)

# NIS 2019 -> NIS 2025 : fusions de communes
convert_codes(c(11002L, 11007L), "NIS_MUNICIPALITY_2019", "NIS_MUNICIPALITY_2025", master_data)
#    code_from  code_to  nature
# 1:     11002    11002   UNCHANGED
# 2:     11007    11002   FUSION   (Borgerhout fusionne dans Anvers)

# NIS 2019 -> NIS 2025 : CHANGE_DSTR (commune 44045 -> arr. different)
convert_codes(44045L, "NIS_MUNICIPALITY_2019", "NIS_MUNICIPALITY_2025", master_data)
#    code_from  code_to       nature
# 1:     44045    46029  CHANGE_DSTR

# NIS 2019 -> NIS 2025 : CHANGE_PROV (commune 11056 -> autre province)
convert_codes(11056L, "NIS_MUNICIPALITY_2019", "NIS_MUNICIPALITY_2025", master_data)
#    code_from  code_to       nature
# 1:     11056    46030  CHANGE_PROV

# NIS 2025 -> NIS 2019 : decomposition (retourne plusieurs lignes pour les fusions)
convert_codes(11002L, "NIS_MUNICIPALITY_2025", "NIS_MUNICIPALITY_2019", master_data,
              allow_ambiguous = TRUE)
#    code_from  code_to  nature
# 1:     11002    11002   UNCHANGED
# 2:     11002    11007   FUSION

# La nature est symetrique sur le chemin inverse (CHANGE_PROV conserve)
convert_codes(46030L, "NIS_MUNICIPALITY_2025", "NIS_MUNICIPALITY_2019", master_data,
              allow_ambiguous = TRUE)
#    code_from  code_to       nature
# ...           11056   CHANGE_PROV   (la ligne correspondante)

# NIS BEFORE_2019 -> NIS 2019
convert_codes(c(55022L, 56011L), "NIS_MUNICIPALITY_BEFORE_2019", "NIS_MUNICIPALITY_2019",
              master_data)

# --- 2e. NUTS 2027 (Reglement UE 2026/195) ------------------------------------
convert_codes(
  c(21004L, 11002L, 44021L),
  "NIS_MUNICIPALITY_2019", "NUTS_DISTRICT_2027",
  master_data
)
# 21004 -> BE100  (Bruxelles, inchange)
# 11002 -> BE261  (Anvers : BE211 -> BE261)
# 44021 -> BE274  (Gand   : BE234 -> BE274)

# NUTS3 2021 -> NUTS3 2027 : arete directe 1:N (allow_ambiguous requis).
# La plupart des codes -> 1 cible ; BE211 -> {BE261, BE276} car la commune 11056
# a change de province entre 2019 et 2025.
convert_codes(c("BE100", "BE211"), "NUTS_DISTRICT_2021", "NUTS_DISTRICT_2027",
              master_data, allow_ambiguous = TRUE)
#    code_from  code_to  nature
# 1:     BE100    BE100   RECODE
# 2:     BE211    BE261   OVERLAP
# 3:     BE211    BE276   OVERLAP
# -> Pour repartir une valeur agregee sur les cibles ambigues, utiliser des poids :
#    register_split_weights("NUTS_DISTRICT_2021","NUTS_DISTRICT_2027", tpl) + split_ambiguous(...).
# -> Si tu as les communes, convertis-les directement vers 2027 (exact, sans poids).

# Sens inverse 2027 -> 2021 : pas d'arete directe (erreur attendue)
tryCatch(
  convert_codes("BE261", "NUTS_DISTRICT_2027", "NUTS_DISTRICT_2021", master_data),
  error = function(e) message("Sens inverse non direct : ", conditionMessage(e))
)

# --- 2f. Conversion ambigue -- arrondissement Verviers (1:N) --------------------
# Verviers -> NUTS3 est un VRAI eclatement (BE335 != BE336) : bloque par defaut.
tryCatch(
  convert_codes(63000L, "NIS_DISTRICT_2019", "NUTS_DISTRICT_2021", master_data),
  error = function(e) message("Erreur attendue : ", conditionMessage(e))
)

# Forcer toutes les correspondances possibles
convert_codes(63000L, "NIS_DISTRICT_2019", "NUTS_DISTRICT_2021",
              master_data, allow_ambiguous = TRUE)
#    code_from  code_to  nature
# 1:     63000   BE335   OVERLAP  (Arr. Verviers francophone)
# 2:     63000   BE336   OVERLAP  (Arr. Verviers germanophone)

# --- 2g. Agregation deterministe -- PAS besoin de allow_ambiguous ---------------
# Meme si le chemin traverse l'arete 1:N Verviers, agreger vers un niveau plus
# grossier ou BE335 et BE336 re-convergent (province BE33, region BE3, pays BE)
# est deterministe : le gate data-aware l'autorise directement (audit M2).
convert_codes(63000L, "NIS_DISTRICT_2019", "NUTS_PROVINCE_2021", master_data)
#    code_from  code_to  nature
# 1:     63000    BE33   RECODE   (une seule cible -> pas d'ambiguite)

convert_codes(63000L, "NIS_DISTRICT_2019", "NUTS_COUNTRY", master_data)
#    code_from  code_to  nature
# 1:     63000      BE   RECODE


# ==============================================================================
# 3. Conversion d'un dataset -- convert_dataset()
# ==============================================================================

dt <- data.table(
  cd_commune = c(21004L, 11002L, 44021L, 62063L),
  pop        = c(180000L, 530000L, 260000L, 200000L)
)

# Auto-detection de la classification source + ajout d'une colonne NUTS3
convert_dataset(dt, "cd_commune",
                from = "NIS_MUNICIPALITY_2019",
                to   = "NUTS_DISTRICT_2021",
                master_data)
# Ajoute la colonne 'cd_nuts3_2021'.

# Conversion complete : communes -> NUTS3 -> arrondissements NIS
dt2 <- copy(dt)
convert_dataset(dt2, "cd_commune", from = "NIS_MUNICIPALITY_2019",
                to = "NIS_DISTRICT_2019", master_data)


# ==============================================================================
# 4. Validation de codes -- validate_codes()
# ==============================================================================

validate_codes(c(21004L, 99999L, 11002L), "NIS_MUNICIPALITY_2019", master_data)
#      code  is_valid
# 1:  21004      TRUE
# 2:  99999     FALSE
# 3:  11002      TRUE

validate_codes(c("1000", "9999"), "POSTAL", master_data)
validate_codes(c("BE100", "ZZZZ"), "NUTS_DISTRICT_2021", master_data)
validate_codes(c("21", "99"),      "NBB_DISTRICT_2021", master_data)


# ==============================================================================
# 5. Noms officiels -- get_label()
# ==============================================================================

# Noms francais
get_label(c(21004L, 11002L, 62063L), "NIS_MUNICIPALITY_2019", master_data, lang = "fr")
#      code      label
# 1:  21004  Bruxelles
# 2:  11002      Anvers
# 3:  62063      Liege

# Noms neerlandais
get_label(c(21004L, 11002L), "NIS_MUNICIPALITY_2019", master_data, lang = "nl")

# NUTS3
get_label(c("BE100", "BE211", "BE332"), "NUTS_DISTRICT_2021", master_data, lang = "fr")

# Codes postaux
get_label(c(1000L, 2000L), "POSTAL", master_data, lang = "fr")

# Code inconnu -> NA
get_label(c(21004L, 99999L), "NIS_MUNICIPALITY_2019", master_data)


# ==============================================================================
# 6. Table de correspondance -- get_crosswalk()
# ==============================================================================

# Correspondance complete communes -> NUTS3
cw <- get_crosswalk("NIS_MUNICIPALITY_2019", "NUTS_DISTRICT_2021", master_data)
head(cw)

# Correspondance postaux -> communes (N:1)
get_crosswalk("POSTAL", "NIS_MUNICIPALITY_2019", master_data)

# Avec colonne de poids -- utile pour les paires ambigues
get_crosswalk("NIS_DISTRICT_2019", "NUTS_DISTRICT_2021", master_data, weights = TRUE)
# ...
# 63000   BE335   0.5   (poids egaux par defaut)
# 63000   BE336   0.5

# Avec des poids personnalises enregistres (voir section 8).
# NB : 0.60/0.40 sont des valeurs FICTIVES d'illustration -- pas des poids officiels.
register_split_weights(
  "NIS_DISTRICT_2019", "NUTS_DISTRICT_2021",
  data.table(code_from = c(63000L, 63000L),
             code_to   = c("BE335", "BE336"),
             weight    = c(0.60, 0.40))
)
get_crosswalk("NIS_DISTRICT_2019", "NUTS_DISTRICT_2021", master_data, weights = TRUE)
# 63000   BE335   0.60
# 63000   BE336   0.40
clear_split_weights()


# ==============================================================================
# 7. Diagnostic de couverture -- diagnose_classification()
# ==============================================================================

# --- 7a. Mode verification (classification fournie) ----------------------------
nuts3_data <- data.table(
  nuts3 = c("BE100", "BE211", "BE332"),
  value = c(100, 200, 150)
)

diagnose_classification(nuts3_data, "nuts3", master_data,
                        classification = "NUTS_DISTRICT_2021")
# Affiche : couverture, codes manquants, codes inconnus, doublons

# Le resultat invisible contient les details structures
diag <- diagnose_classification(nuts3_data, "nuts3", master_data,
                                classification = "NUTS_DISTRICT_2021", verbose = FALSE)
diag$coverage_rate   # fraction de codes de reference presents
diag$status          # "COMPLETE", "INCOMPLETE", "COMPLETE_WITH_UNKNOWNS", ...
diag$missing_codes   # data.table des codes absents
diag$unknown_codes   # data.table des codes non reconnus

# --- 7b. Mode auto-detection (classification = NULL) ---------------------------
diagnose_classification(nuts3_data, "nuts3", master_data)
# Classe toutes les classifications par taux de correspondance

# --- 7c. Detection directe -- detect_classification() --------------------------
# Renvoie le seul identifiant le plus probable (>= 80 % de correspondance).
detect_classification(c(21004L, 11002L, 62063L), master_data)  # "NIS_MUNICIPALITY_2019"
detect_classification(c("BE100", "BE211"),        master_data)  # "NUTS_DISTRICT_2021"
detect_classification(c("BE261", "BE262"),        master_data)  # "NUTS_DISTRICT_2027" (millesime 2027)
detect_classification("BE",                       master_data)  # "NUTS_COUNTRY"
detect_classification(c(1000L, 2000L),            master_data)  # "POSTAL"


# ==============================================================================
# 8. Correspondances ponderees -- split_ambiguous() et registre de poids
# ==============================================================================
#
# Le package LIVRE des poids POPULATION standard (communes NIS 2019, 2011-2024) :
# variable = "population" fonctionne cle-en-main (voir 8b). Sans poids fournis,
# split_ambiguous() applique des poids EGAUX par defaut.
# NB : les quelques valeurs de poids ECRITES A LA MAIN plus bas (p. ex. 0.60/0.40
# pour Verviers) restent des exemples illustratifs -- pour de vrais poids, utilisez
# variable = "population" ou fournissez les votres via commune_values.

# --- 8a. split_ambiguous() directement -----------------------------------------
arr_data <- data.table(
  arr_code   = c(11000L, 62000L, 63000L),
  total_wage = c(5e9, 3e9, 1e9),
  avg_salary = c(2900, 2700, 2400)
)

# Poids egaux (par defaut) -- variable additive
split_ambiguous(
  arr_data,
  code_col   = "arr_code",
  value_cols = c("total_wage"),
  from       = "NIS_DISTRICT_2019",
  to         = "NUTS_DISTRICT_2021",
  master_data,
  value_type = "additive"
)
# 63000 -> BE335 : total_wage * 0.5
# 63000 -> BE336 : total_wage * 0.5

# Variable ratio -- valeurs inchangees dans les deux cibles
split_ambiguous(
  arr_data,
  code_col   = "arr_code",
  value_cols = "avg_salary",
  from       = "NIS_DISTRICT_2019",
  to         = "NUTS_DISTRICT_2021",
  master_data,
  value_type = "ratio"
)

# --- 8b. Template de poids -- split_weights_template() -------------------------
# Par defaut : poids EGAUX.
tpl <- split_weights_template("NIS_DISTRICT_2019", "NUTS_DISTRICT_2021", master_data)
#    code_from  code_to  weight
# 1:     63000    BE335     0.5
# 2:     63000    BE336     0.5

# Poids POPULATION livres (cle-en-main) -- annee la plus recente par defaut :
tpl_pop <- split_weights_template("NIS_DISTRICT_2019", "NUTS_DISTRICT_2021",
                                  master_data, variable = "population")
#    code_from  code_to     weight
# 1:     63000    BE335   ~0.73     (part francophone reelle)
# 2:     63000    BE336   ~0.27     (part germanophone reelle)

# Choisir une annee de reference (retropolation period-consistent) :
tpl_2015 <- split_weights_template("NIS_DISTRICT_2019", "NUTS_DISTRICT_2021",
                                   master_data, variable = "population", weight_year = 2015L)

# split_ambiguous / rebase_series acceptent directement weights = "population" :
split_ambiguous(arr_data, "arr_code", value_cols = "total_wage",
                from = "NIS_DISTRICT_2019", to = "NUTS_DISTRICT_2021",
                master_data, weights = "population", value_type = "additive")

# Ou des valeurs ecrites a la main (ILLUSTRATIF -- non officiel) :
tpl[code_from == "63000" & code_to == "BE335", weight := 0.60]
tpl[code_from == "63000" & code_to == "BE336", weight := 0.40]

# --- 8c. Registre de poids personnalises pour reutilisation --------------------
# NB : on enregistre sous un nom DISTINCT ("population_custom") pour ne pas
# masquer le standard "population" livre.
register_split_weights(
  from       = "NIS_DISTRICT_2019",
  to         = "NUTS_DISTRICT_2021",
  weights_dt = tpl,
  variable   = "population_custom"
)

list_split_weights()
#           from            to           variable
# NIS_DISTRICT_2019  NUTS_DISTRICT_2021  population_custom

get_split_weights("NIS_DISTRICT_2019", "NUTS_DISTRICT_2021", variable = "population_custom")

clear_split_weights()


# ==============================================================================
# 9. Rebasement longitudinal -- rebase_series()
# ==============================================================================

# --- 9a. Fusion N:1 : communes qui fusionnent en 2025 --------------------------
# Les communes 11002 (Anvers) et 11007 (Borgerhout) ont fusionne dans NIS 2025.
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
    "NIS_MUNICIPALITY_2019" = 2022L,
    "NIS_MUNICIPALITY_2025" = 2025L
  ),
  to          = "NIS_MUNICIPALITY_2025",
  master_data = master_data
)
# 2022 : commune 11002 -> 530000 + 42000 = 572000 (fusionnees)
# 2025 : donnees inchangees (deja en NIS 2025)

# --- 9b. Variable ratio -- agregation avec la moyenne -------------------------
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
  version_map = list("NIS_MUNICIPALITY_2019" = 2022L),
  to          = "NIS_MUNICIPALITY_2025",
  master_data = master_data,
  fun         = mean,
  value_type  = "ratio"
)
# commune 11002 : taux = mean(0.62, 0.58) = 0.60

# --- 9c. Split 1:N : donnees par arrondissement vers NUTS3 --------------------
arr_panel <- data.table(
  year    = c(2020L, 2021L, 2020L, 2021L),
  arr     = c(63000L, 63000L, 11000L, 11000L),
  emplois = c(120000, 122000, 310000, 315000)
)

# split = "population" (defaut) utilise le STANDARD POPULATION livre -- aucun
# enregistrement de poids necessaire.
result_1n <- rebase_series(
  arr_panel,
  period_col  = "year",
  code_col    = "arr",
  value_cols  = "emplois",
  version_map = list("NIS_DISTRICT_2019" = 2020:2021),
  to          = "NUTS_DISTRICT_2021",
  master_data = master_data
  # split = "population" est la valeur par defaut
)
# Verviers 120000 reparti selon les parts de population reelles :
# BE335 ~ 120000 * 0.73 ; BE336 ~ 120000 * 0.27

# Passage de poids PERSONNALISES directement (usage ponctuel sans registre) :
tpl2 <- split_weights_template("NIS_DISTRICT_2019", "NUTS_DISTRICT_2021", master_data)
tpl2[code_from == "63000" & code_to == "BE335", weight := 0.60]   # valeurs fictives
tpl2[code_from == "63000" & code_to == "BE336", weight := 0.40]
result_direct <- rebase_series(
  arr_panel,
  period_col  = "year",
  code_col    = "arr",
  value_cols  = "emplois",
  version_map = list("NIS_DISTRICT_2019" = 2020:2021),
  to          = "NUTS_DISTRICT_2021",
  master_data = master_data,
  split       = tpl2
)

# --- 9d. Periodes non couvertes -- warning rcl_missing_periods -----------------
data_mixed <- data.table(year = 2022:2024, commune = 21004L, pop = c(1, 2, 3))
withCallingHandlers(
  rebase_series(
    data_mixed,
    period_col  = "year",
    code_col    = "commune",
    value_cols  = "pop",
    version_map = list("NIS_MUNICIPALITY_2019" = 2022L),
    to          = "NIS_MUNICIPALITY_2025",
    master_data = master_data
  ),
  rcl_missing_periods = function(w) {
    message("Periodes ignorees : ", conditionMessage(w))
    invokeRestart("muffleWarning")
  }
)


# ==============================================================================
# 10. Datasets d'exemple complets
# ==============================================================================
#
# /!\ IMPORTANT : ces datasets sont fournis UNIQUEMENT pour la demonstration et
#     les tests. Les colonnes socio-economiques (population, emplois, masse_sal,
#     taux_activite, ...) sont des valeurs PUREMENT FICTIVES generees
#     aleatoirement -- ce ne sont PAS de vraies statistiques. Ne les utilisez
#     jamais pour une analyse reelle ; chargez vos propres donnees.
#
# Le package inclut huit datasets prets a l'emploi :
#
#   Datasets propres (une ligne par unite geographique) :
#     rc_full_municipalities_2019  -- 581 communes NIS 2019
#     rc_full_municipalities_2025  -- 565 communes NIS 2025
#     rc_full_districts_2019       -- 43 arrondissements NIS 2019
#     rc_full_regions_2019         -- 3 regions NIS 2019
#     rc_full_nuts3_2021           -- 44 regions NUTS3 2021
#     rc_full_nuts3_2027           -- 44 regions NUTS3 2027
#     rc_full_postal               -- 1 149 codes postaux
#
#   Dataset sale (pour tester le diagnostic) :
#     rc_dirty_municipalities_2019 -- 319 lignes avec doublons, codes inconnus,
#                                     valeurs NA et codes d'une autre version

# --- 10a. Conversion complete d'un dataset propre ------------------------------
data(rc_full_municipalities_2019)

convert_dataset(rc_full_municipalities_2019, "cd_commune",
                from = "NIS_MUNICIPALITY_2019",
                to   = "NUTS_DISTRICT_2021",
                master_data)

# --- 10b. NUTS3 2021 -> NUTS2 2021 --------------------------------------------
data(rc_full_nuts3_2021)

convert_dataset(rc_full_nuts3_2021, "cd_nuts3",
                from = "NUTS_DISTRICT_2021",
                to   = "NUTS_PROVINCE_2021",
                master_data)

# --- 10c. Codes postaux -> communes NIS 2019 -----------------------------------
data(rc_full_postal)

convert_dataset(rc_full_postal, "cd_postal",
                from = "POSTAL",
                to   = "NIS_MUNICIPALITY_2019",
                master_data)

# --- 10d. Diagnostic du dataset sale ------------------------------------------
data(rc_dirty_municipalities_2019)

# Verification contre NIS_MUNICIPALITY_2019
diagnose_classification(rc_dirty_municipalities_2019, "cd_commune", master_data,
                        classification = "NIS_MUNICIPALITY_2019")
# Signale : doublons, codes inconnus (version 2025), codes NA

# Validation precise
val <- validate_codes(rc_dirty_municipalities_2019$cd_commune,
                      "NIS_MUNICIPALITY_2019", master_data)
val[is_valid == FALSE]

# Auto-detection de la meilleure classification
diagnose_classification(rc_dirty_municipalities_2019, "cd_commune", master_data)


# ==============================================================================
# 11. Correspondance floue de noms -- fuzzy_match_names()
# ==============================================================================

fuzzy_match_names(
  names    = c("Bruxeles", "Antwerpn", "Liege", "Naemur", "Vervirs"),
  target   = "NIS_MUNICIPALITY_2019",
  master_data,
  max_dist = 0.3,
  language = "both"
)
#   input_name  matched_name  matched_code  distance  is_confident
#   Bruxeles    Bruxelles        21004       0.037      TRUE
#   Antwerpn    Antwerpen        11002       0.037      TRUE
#   Liege       Liege            62063       0.150      TRUE
#   Naemur      Namur            92094       0.167      TRUE
#   Vervirs     Verviers         63079       0.042      TRUE


# ==============================================================================
# 12. Visualisation (requiert visNetwork)
# ==============================================================================

# Graphe des relations entre classifications
visualize_classification_graph()

# Matrice de conversions
visualize_conversion_matrix()

# Hierarchie NIS 2019
visualize_hierarchy("NIS_2019", master_data)


# ==============================================================================
# 13. Utilitaires
# ==============================================================================

# Chemin de conversion detaille avec semantique de perimetre
check_conversion_path("POSTAL", "NUTS_DISTRICT_2021")
# $is_simple          TRUE
# $path               "POSTAL -> NIS_MUNICIPALITY_2019 -> NUTS_MUNICIPALITY_2021 -> NUTS_DISTRICT_2021"
# $perimeter_status   "preserving"
# $straddle_free      TRUE

check_conversion_path("NIS_MUNICIPALITY_2025", "NUTS_DISTRICT_2021")
# $is_simple          FALSE
# $perimeter_status   "crossing"
# $straddle_free      FALSE

# En passant master_data, on obtient aussi executable + effectively_simple :
check_conversion_path("NIS_MUNICIPALITY_2025", "NUTS_DISTRICT_2021", master_data)
# $is_simple           FALSE
# $executable          TRUE
# $effectively_simple  FALSE   (3 fusions -> vraie ambiguite 1:N)

# Route DECLAREE mais NON executable : le moteur n'inverse pas les aretes.
tryCatch(
  convert_codes("BE261", "NUTS_DISTRICT_2027", "NIS_MUNICIPALITY_2025", master_data),
  rcl_no_route = function(e) message("Route non executable : ", conditionMessage(e))
)

# Reconstruire le snapshot depuis les fichiers bruts (si data/raw/ est disponible)
# master_data <- rebuild_master_data()
