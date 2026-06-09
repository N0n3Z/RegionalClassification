# ==============================================================================
# tests/test_template.R -- Template pour ecrire ses propres tests
# ==============================================================================
#
# UTILISATION
# -----------
# 1. Lancez d'abord main.R pour charger le package et construire master_data.
# 2. Sourcez ce fichier : source("tests/test_template.R")
# 3. Appelez : run_custom_tests(MY_TESTS, master_data)
#
# STRUCTURE D'UN TEST
# -------------------
# Chaque test est une liste avec les champs suivants :
#
#   description  (obligatoire) Texte libre decrivant ce que le test verifie.
#   type         (obligatoire) Type de test : voir les sections ci-dessous.
#   ...          (variable)    Parametres propres a chaque type.
#
# TYPES DISPONIBLES
# -----------------
#   "convert"    Test de convert_codes() : codes -> codes
#   "dataset"    Test de convert_dataset() : colonne d'un data.table
#   "split"      Test de split_ambiguous() : conversion M:N avec poids
#   "diagnose"   Test de diagnose_classification() : diagnostic de couverture
#   "custom"     Test libre : vous fournissez une fonction check()
#
# ==============================================================================


# ==============================================================================
# 1. DEFINIR VOS TESTS
# ==============================================================================

MY_TESTS <- list(

  # ----------------------------------------------------------------------------
  # TYPE "convert" -- convert_codes()
  #
  # Champs :
  #   input     Vecteur de codes source (integer ou character)
  #   from      Classification source   (ex: "NIS_COMMUNE_2019")
  #   to        Classification cible    (ex: "NUTS3_2027")
  #   expected  Vecteur des codes attendus en sortie, dans le meme ordre
  #             que input. Utilisez NA pour les codes sans correspondance.
  # ----------------------------------------------------------------------------

  list(
    description = "Bruxelles (21004) reste BE100 en NUTS 2027",
    type        = "convert",
    input       = c(21004L),
    from        = "NIS_COMMUNE_2019",
    to          = "NUTS3_2027",
    expected    = c("BE100")
  ),

  list(
    description = "Antwerpen (11002) passe de BE211 (2021) a BE261 (2027)",
    type        = "convert",
    input       = c(11002L),
    from        = "NIS_COMMUNE_2019",
    to          = "NUTS3_2027",
    expected    = c("BE261")
  ),

  list(
    description = "Codes postaux -> communes NIS 2019",
    type        = "convert",
    input       = c(1000L, 2000L, 4000L),
    from        = "POSTAL",
    to          = "NIS_COMMUNE_2019",
    expected    = c(21004L, 11002L, 62063L)
  ),

  list(
    description = "NIS 2025 commune -> NUTS3 2027 via fichier officiel",
    type        = "convert",
    input       = c(11002L, 44021L, 71072L),
    from        = "NIS_COMMUNE_2025",
    to          = "NUTS3_2027",
    expected    = c("BE261", "BE274", "BE227")
  ),

  list(
    description = "Roundtrip NUTS3 2021 <-> 2027 : BE231 -> BE271 -> BE231",
    type        = "convert",
    input       = c("BE100", "BE231", "BE335"),
    from        = "NUTS3_2021",
    to          = "NUTS3_2027",
    expected    = c("BE100", "BE271", "BE335")
  ),

  list(
    description = "Commune BEFORE_2019 fusionnee -> NUTS3 2021",
    type        = "convert",
    # 55022 = Fosses-la-Ville (fusionne en 2019 -> 58001 = Mettet)
    input       = c(55022L),
    from        = "NIS_COMMUNE_BEFORE_2019",
    to          = "NUTS3_2021",
    expected    = c("BE352")
  ),

  # ----------------------------------------------------------------------------
  # TYPE "dataset" -- convert_dataset()
  #
  # Champs :
  #   dt            data.table (ou data.frame) d'entree
  #   code_col      Nom de la colonne contenant les codes source
  #   from          Classification source (NULL = auto-detection)
  #   to            Classification cible
  #   target_col    Nom attendu de la nouvelle colonne ajoutee
  #   check_fn      function(result) -> TRUE/FALSE
  #                 Fonction de validation sur le resultat retourne.
  # ----------------------------------------------------------------------------

  list(
    description = "convert_dataset : dataset salarial communes -> NUTS3 2021",
    type        = "dataset",
    dt          = data.table::data.table(
      region  = c("Bruxelles", "Anvers", "Liege"),
      commune = c(21004L, 11002L, 62063L),
      salaire = c(3500, 2900, 2600)
    ),
    code_col    = "commune",
    from        = "NIS_COMMUNE_2019",
    to          = "NUTS3_2021",
    target_col  = "cd_nuts3_2021",
    check_fn    = function(r) {
      r[commune == 21004L, cd_nuts3_2021] == "BE100" &&
      r[commune == 11002L, cd_nuts3_2021] == "BE211" &&
      r[commune == 62063L, cd_nuts3_2021] == "BE332"
    }
  ),

  list(
    description = "convert_dataset : auto-detection depuis codes NUTS3",
    type        = "dataset",
    dt          = data.table::data.table(
      nuts = c("BE100", "BE211", "BE332"),
      val  = c(100, 200, 300)
    ),
    code_col    = "nuts",
    from        = NULL,       # auto-detection
    to          = "NUTS3_2027",
    target_col  = "cd_nuts3_2027",
    check_fn    = function(r) {
      "cd_nuts3_2027" %in% names(r) &&
      r[nuts == "BE211", cd_nuts3_2027] == "BE261"
    }
  ),

  # ----------------------------------------------------------------------------
  # TYPE "split" -- split_ambiguous()
  #
  # Champs :
  #   dt          data.table d'entree
  #   code_col    Colonne contenant les codes source
  #   value_cols  Colonnes de valeurs a redistribuer
  #   from        Classification source
  #   to          Classification cible
  #   weights     NULL (poids egaux) ou data.table(code_from, code_to, weight)
  #   value_type  "additive" (totaux) ou "ratio" (taux)
  #   check_fn    function(result) -> TRUE/FALSE
  # ----------------------------------------------------------------------------

  list(
    description = "split_ambiguous : Verviers (63000) divise 50/50 (poids egaux)",
    type        = "split",
    dt          = data.table::data.table(
      arr_code   = c(11000L, 63000L),
      masse_sal  = c(5e9,    1e9)
    ),
    code_col    = "arr_code",
    value_cols  = "masse_sal",
    from        = "NIS_ARRONDISSEMENT_2019",
    to          = "NUTS3_2021",
    weights     = NULL,       # poids egaux -> 50/50
    value_type  = "additive",
    check_fn    = function(r) {
      nrow(r) == 3L &&                                          # 63000 -> 2 lignes
      abs(sum(r$masse_sal) - 6e9) < 1 &&                       # total preserve
      abs(r[cd_nuts3_2021 == "BE335", masse_sal] - 5e8) < 1e3  # 50% de 1e9
    }
  ),

  list(
    description = "split_ambiguous : Verviers avec poids population (85/15)",
    type        = "split",
    dt          = data.table::data.table(
      arr_code   = c(63000L),
      masse_sal  = c(1e9)
    ),
    code_col    = "arr_code",
    value_cols  = "masse_sal",
    from        = "NIS_ARRONDISSEMENT_2019",
    to          = "NUTS3_2021",
    weights     = data.table::data.table(
      code_from = c(63000L, 63000L),
      code_to   = c("BE335", "BE336"),
      weight    = c(0.857,   0.143)
    ),
    value_type  = "additive",
    check_fn    = function(r) {
      abs(r[cd_nuts3_2021 == "BE335", masse_sal] - 857e6) < 1e3 &&
      abs(r[cd_nuts3_2021 == "BE336", masse_sal] - 143e6) < 1e3
    }
  ),

  # ----------------------------------------------------------------------------
  # TYPE "diagnose" -- diagnose_classification()
  #
  # Champs :
  #   dt              data.table d'entree
  #   code_col        Colonne contenant les codes
  #   classification  Classification a verifier (NULL = auto-detection)
  #   check_fn        function(result) -> TRUE/FALSE
  #                   Le resultat est la liste retournee par diagnose_classification().
  # ----------------------------------------------------------------------------

  list(
    description = "diagnose : jeu NUTS3 2021 complet -> COMPLETE",
    type        = "diagnose",
    dt          = NULL,       # NULL = utiliser tous les codes de reference (voir check_fn)
    code_col    = "nuts3",
    classification = "NUTS3_2021",
    check_fn    = function(r, master_data) {
      # Construit un jeu complet a la volee
      dt_full <- data.table::data.table(nuts3 = master_data$nuts3_ref_2021$cd_nuts3)
      res <- diagnose_classification(dt_full, "nuts3", master_data,
                                     classification = "NUTS3_2021", verbose = FALSE)
      res$status == "COMPLETE" && res$n_missing == 0L
    }
  ),

  list(
    description = "diagnose : code inconnu BE999 detecte",
    type        = "diagnose",
    dt          = data.table::data.table(nuts3 = c("BE100", "BE211", "BE999")),
    code_col    = "nuts3",
    classification = "NUTS3_2021",
    check_fn    = function(r, master_data) {
      r$n_unknown == 1L && "BE999" %in% r$unknown_codes$code
    }
  ),

  list(
    description = "diagnose : auto-detection sur communes NIS 2019",
    type        = "diagnose",
    dt          = data.table::data.table(
      code = c(21004L, 11002L, 44021L, 62063L, 63079L)
    ),
    code_col    = "code",
    classification = NULL,   # auto-detection
    check_fn    = function(r, master_data) {
      r$recommendation      == "NIS_COMMUNE_2019" &&
      r$classification_type == "NIS_COMMUNE" &&
      r$version             == "2019"
    }
  ),

  # ----------------------------------------------------------------------------
  # TYPE "custom" -- test libre
  #
  # Champs :
  #   fn    function(master_data) -> TRUE/FALSE
  #         Votre logique complete. Retournez TRUE si le test passe.
  # ----------------------------------------------------------------------------

  list(
    description = "custom : Verviers arrondissement produit 2 codes NUTS3",
    type        = "custom",
    fn          = function(master_data) {
      r <- convert_codes(63000L, "NIS_ARRONDISSEMENT_2019", "NUTS3_2021",
                         master_data, allow_ambiguous = TRUE)
      nrow(r) == 2L &&
      all(c("BE335", "BE336") %in% r$code_to)
    }
  )

)  # fin MY_TESTS


# ==============================================================================
# 2. RUNNER -- ne pas modifier
# ==============================================================================

#' Executer une liste de tests personnalises
#'
#' @param tests  Liste de tests (voir template ci-dessus)
#' @param master_data  Sortie de build_master_table()
#' @return invisible(list) avec le detail de chaque resultat
run_custom_tests <- function(tests, master_data) {

  if (!requireNamespace("data.table", quietly = TRUE)) stop("data.table requis")
  library(data.table)

  bar <- strrep("=", 66)
  cat(sprintf("\n%s\n  CUSTOM TESTS  (%d tests)\n%s\n\n", bar, length(tests), bar))

  pass  <- 0L
  fail  <- 0L
  results <- vector("list", length(tests))

  for (i in seq_along(tests)) {
    test <- tests[[i]]
    desc <- test$description %||% sprintf("Test %d", i)
    cat(sprintf("--- [%02d] %s ---\n", i, desc))

    tryCatch({

      ok <- switch(test$type,

        # ---- convert --------------------------------------------------------
        convert = {
          result <- convert_codes(test$input, test$from, test$to, master_data)
          # Align to input order
          aligned <- result$code_to[match(as.character(test$input),
                                          as.character(result$code_from))]
          expected <- as.character(test$expected)
          actual   <- as.character(aligned)
          if (!identical(actual, expected)) {
            cat(sprintf("  Input   : %s\n", paste(test$input, collapse = ", ")))
            cat(sprintf("  Attendu : %s\n", paste(expected, collapse = ", ")))
            cat(sprintf("  Obtenu  : %s\n", paste(actual, collapse = ", ")))
          }
          identical(actual, expected)
        },

        # ---- dataset --------------------------------------------------------
        dataset = {
          args <- list(
            dt         = as.data.table(test$dt),
            code_col   = test$code_col,
            to         = test$to,
            master_data = master_data,
            verbose    = FALSE
          )
          if (!is.null(test$from)) args$from <- test$from
          result <- do.call(convert_dataset, args)
          test$check_fn(result)
        },

        # ---- split ----------------------------------------------------------
        split = {
          result <- split_ambiguous(
            dt          = as.data.table(test$dt),
            code_col    = test$code_col,
            value_cols  = test$value_cols,
            from        = test$from,
            to          = test$to,
            master_data = master_data,
            weights     = test$weights,
            value_type  = test$value_type %||% "additive",
            verbose     = FALSE
          )
          test$check_fn(result)
        },

        # ---- diagnose -------------------------------------------------------
        diagnose = {
          if (!is.null(test$dt)) {
            result <- diagnose_classification(
              dt             = as.data.table(test$dt),
              code_col       = test$code_col,
              master_data    = master_data,
              classification = test$classification,
              verbose        = FALSE
            )
            test$check_fn(result, master_data)
          } else {
            # dt = NULL : la check_fn gere tout elle-meme
            test$check_fn(NULL, master_data)
          }
        },

        # ---- custom ---------------------------------------------------------
        custom = {
          test$fn(master_data)
        },

        stop(sprintf("Type de test inconnu : '%s'", test$type))
      )

      if (isTRUE(ok)) {
        cat("  PASS\n\n")
        pass <- pass + 1L
        results[[i]] <- list(status = "PASS", description = desc)
      } else {
        cat("  FAIL -- check_fn a retourne FALSE\n\n")
        fail <- fail + 1L
        results[[i]] <- list(status = "FAIL", description = desc,
                             error = "check_fn returned FALSE")
      }

    }, error = function(e) {
      cat(sprintf("  FAIL -- %s\n\n", e$message))
      fail <<- fail + 1L
      results[[i]] <<- list(status = "FAIL", description = desc, error = e$message)
    })
  }

  cat(sprintf("%s\n  RESULTATS : %d/%d tests passes\n%s\n\n",
              bar, pass, length(tests), bar))

  return(invisible(results))
}

# Operateur null-coalesce interne (evite de dependre d'un package externe)
`%||%` <- function(a, b) if (!is.null(a)) a else b


# ==============================================================================
# 3. EXECUTION
# ==============================================================================
# Decommentez la ligne ci-dessous pour lancer vos tests immediatement
# apres avoir source ce fichier (necessite que master_data soit charge).
#
# run_custom_tests(MY_TESTS, master_data)
