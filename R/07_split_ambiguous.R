# ==============================================================================
# 07_split_ambiguous.R - Weighted M:N splitting and weight registry
# ==============================================================================

#' Handle M:N conversions on a dataset using weighted splits
#'
#' When converting between classifications where some codes map to multiple
#' targets (e.g. arrondissement Verviers 63000 -> NUTS3 BE335 + BE336), this
#' function distributes value columns proportionally using supplied or
#' registered weights.
#'
#' @param dt         data.table with data to convert
#' @param code_col   Name of the column containing source codes
#' @param value_cols Character vector of column names to redistribute.
#'   For value_type="additive": multiplied by weight (totals, counts, sums).
#'   For value_type="ratio": kept unchanged (rates, averages, indices).
#' @param from       Source classification
#' @param to         Target classification
#' @param master_data Output from build_master_table()
#' @param weights    How to weight the split. One of:
#'   - NULL (default): use registry if available, otherwise equal weights
#'   - data.table with columns (code_from, code_to, weight)
#'   - character: name of a registered variable ("population", "employment", ...)
#' @param value_type "additive" or "ratio". See value_cols.
#' @param target_col Name of the new target code column. NULL = auto-generated.
#' @param normalize  Normalize weights to sum to 1 per code_from? Default TRUE.
#' @param add_weight_col Add a 'split_weight' column to the result? Default FALSE.
#' @param verbose    Print split summary? Default TRUE.
#' @return data.table. Ambiguous codes produce multiple rows; unambiguous codes
#'   produce one row each.
#'
#' @examples
#' \donttest{
#'   master_data <- load_master_data()
#'   arr_salaries <- data.table::data.table(
#'     arr_code   = c("11000", "62000", "63000"),   # 63000 = Verviers (ambiguous)
#'     total_wage = c(5e9, 3e9, 1e9),
#'     avg_salary = c(2900, 2700, 2400)
#'   )
#'
#'   # Equal weights (default)
#'   split_ambiguous(arr_salaries, "arr_code",
#'                   value_cols = c("total_wage", "avg_salary"),
#'                   from = "NIS_DISTRICT_2019", to = "NUTS_DISTRICT_2021",
#'                   master_data,
#'                   value_type = "additive")
#'
#'   # Manual population weights for Verviers
#'   weights <- data.table::data.table(
#'     code_from = c("63000", "63000"),
#'     code_to   = c("BE335", "BE336"),
#'     weight    = c(0.857, 0.143)
#'   )
#'   split_ambiguous(arr_salaries, "arr_code",
#'                   value_cols = "total_wage",
#'                   from = "NIS_DISTRICT_2019", to = "NUTS_DISTRICT_2021",
#'                   master_data,
#'                   weights    = weights,
#'                   value_type = "additive")
#' }
#' @export
split_ambiguous <- function(
  dt,
  code_col,
  value_cols,
  from,
  to,
  master_data,
  weights         = NULL,
  value_type      = c("additive", "ratio"),
  target_col      = NULL,
  normalize       = TRUE,
  add_weight_col  = FALSE,
  verbose         = TRUE
) {
  value_type <- match.arg(value_type)

  if (!is.data.table(dt)) dt <- as.data.table(dt)
  dt <- copy(dt)

  if (!code_col %in% names(dt)) {
    abort(sprintf("Column '%s' not found in dt.", code_col), class = "rcl_invalid_input")
  }
  missing_val <- setdiff(value_cols, names(dt))
  if (length(missing_val) > 0) {
    abort(sprintf("value_cols not found in dt: %s", paste(missing_val, collapse = ", ")),
          class = "rcl_invalid_input")
  }

  from_norm <- normalize_classification_id(from)
  to_norm   <- normalize_classification_id(to)

  if (is.null(target_col)) {
    target_col <- default_col_name(to_norm)
  }

  # Coerce the source key to the node's canonical (character) type, like
  # convert_dataset() does, so the returned source column is character regardless
  # of how the user typed it (a bare integer column would otherwise survive as
  # integer while the target column is character).
  dt[, (code_col) := .node_coerce(get(code_col), from_norm)]

  # --- Get full mapping (M:N allowed) ---
  all_codes <- unique(na.omit(dt[[code_col]]))
  all_map   <- convert_codes(all_codes, from_norm, to_norm, master_data,
                              allow_ambiguous = TRUE)

  map_counts  <- all_map[, .N, by = code_from]
  ambig_codes <- map_counts[N > 1, code_from]
  simple_map  <- all_map[!code_from %in% ambig_codes]

  if (verbose) {
    message(sprintf(
      "split_ambiguous: %d unique code(s), %d ambiguous (%s).",
      length(all_codes), length(ambig_codes),
      if (length(ambig_codes) > 0) paste(ambig_codes, collapse = ", ") else "none"
    ))
  }

  # --- No ambiguous codes: direct conversion ---
  if (length(ambig_codes) == 0) {
    if (verbose) message("  No ambiguous codes. Applying direct conversion.")
    dt[, (target_col) := all_map$code_to[match(get(code_col), all_map$code_from)]]
    return(dt)
  }

  # --- Resolve weights ---
  resolved <- .resolve_weights(ambig_codes, all_map, from_norm, to_norm,
                                weights, normalize, verbose, master_data)

  # --- Simple rows (1:1) ---
  dt_simple <- dt[!get(code_col) %in% ambig_codes]
  dt_simple[, (target_col) := simple_map$code_to[match(get(code_col), simple_map$code_from)]]
  if (add_weight_col) dt_simple[, split_weight := 1]

  # --- Ambiguous rows (1:N) ---
  dt_ambig <- dt[get(code_col) %in% ambig_codes]

  split_parts <- lapply(ambig_codes, function(ac) {
    rows <- dt_ambig[get(code_col) == ac]
    wts  <- resolved[code_from == ac]

    expanded <- rbindlist(lapply(seq_len(nrow(wts)), function(i) {
      row_copy <- copy(rows)
      row_copy[, (target_col) := wts$code_to[i]]
      w <- wts$weight[i]

      if (value_type == "additive") {
        for (vc in value_cols) {
          row_copy[, (vc) := get(vc) * w]
        }
      }
      # value_type == "ratio": keep values unchanged

      if (add_weight_col) row_copy[, split_weight := w]
      row_copy
    }))

    if (verbose) {
      message(sprintf("  Code %s split into:", ac))
      for (i in seq_len(nrow(wts))) {
        value_note <- if (value_type == "additive") "values redistributed"
                      else "values unchanged (ratio)"
        message(sprintf("    %s  weight=%.4f  (%s)",
                        wts$code_to[i], wts$weight[i], value_note))
      }
    }

    expanded
  })

  dt_split <- rbindlist(split_parts, use.names = TRUE, fill = TRUE)

  # --- Combine ---
  result <- rbindlist(list(dt_simple, dt_split), use.names = TRUE, fill = TRUE)

  if (verbose) {
    message(sprintf("  Result: %d rows (input: %d, +%d from splits).",
                    nrow(result), nrow(dt), nrow(result) - nrow(dt)))
  }

  return(result)
}


# ==============================================================================
# Split Weight Registry
# ==============================================================================

# Session-scoped registry for pre-registered split weights.
# Thread-safety note: this environment is package-global and not safe for
# concurrent R processes. Use clear_split_weights() between test runs.
.split_weight_registry <- new.env(parent = emptyenv())

#' Register split weights for an ambiguous conversion
#'
#' Stores a weighting table in the session registry for use by split_ambiguous().
#' Multiple variables (population, employment, etc.) can be registered for the
#' same conversion pair.
#'
#' @param from       Source classification
#' @param to         Target classification
#' @param weights_dt data.table with columns: code_from, code_to, weight
#' @param variable   Name of the weighting variable (default: "population")
#' @return Invisible NULL (called for side effect)
#' @examples
#' \donttest{
#'   # Register population-based Verviers split (indicative values)
#'   register_split_weights(
#'     from       = "NIS_DISTRICT_2019",
#'     to         = "NUTS_DISTRICT_2021",
#'     weights_dt = data.table::data.table(
#'       code_from = c("63000", "63000"),
#'       code_to   = c("BE335", "BE336"),
#'       weight    = c(0.857, 0.143)
#'     ),
#'     variable   = "population"
#'   )
#' }
#' @export
register_split_weights <- function(from, to, weights_dt, variable = "population") {
  from_norm  <- normalize_classification_id(from)
  to_norm    <- normalize_classification_id(to)
  weights_dt <- as.data.table(weights_dt)

  required <- c("code_from", "code_to", "weight")
  missing  <- setdiff(required, names(weights_dt))
  if (length(missing) > 0) {
    abort(sprintf("weights_dt must have columns: %s (missing: %s)",
                  paste(required, collapse = ", "), paste(missing, collapse = ", ")),
          class = "rcl_invalid_input")
  }

  key <- paste(from_norm, to_norm, variable, sep = "__")
  assign(key, weights_dt, envir = .split_weight_registry)
  message(sprintf("  Registered split weights: %s -> %s [variable: %s, %d entries]",
                  from_norm, to_norm, variable, nrow(weights_dt)))
  invisible(NULL)
}

#' Retrieve registered split weights
#'
#' @param from     Source classification
#' @param to       Target classification
#' @param variable Weighting variable name (default: "population")
#' @return data.table(code_from, code_to, weight) or NULL if not registered
#' @examples
#' \donttest{
#'   library(data.table)
#'   register_split_weights(
#'     "NIS_DISTRICT_2019", "NUTS_DISTRICT_2021",
#'     data.table(code_from = c("63000", "63000"),
#'                code_to   = c("BE335", "BE336"),
#'                weight    = c(0.857, 0.143))
#'   )
#'   get_split_weights("NIS_DISTRICT_2019", "NUTS_DISTRICT_2021")
#' }
#' @export
get_split_weights <- function(from, to, variable = "population") {
  from_norm <- normalize_classification_id(from)
  to_norm   <- normalize_classification_id(to)
  key       <- paste(from_norm, to_norm, variable, sep = "__")
  if (exists(key, envir = .split_weight_registry)) {
    return(get(key, envir = .split_weight_registry))
  }
  NULL
}

#' List all registered split weights
#'
#' @return data.table with columns (from, to, variable), or invisible NULL when empty
#' @examples
#' \donttest{
#'   list_split_weights()  # returns NULL or data.table of registered weights
#' }
#' @export
list_split_weights <- function() {
  keys <- ls(.split_weight_registry)
  if (length(keys) == 0) {
    message("No split weights registered.")
    return(invisible(NULL))
  }
  parts <- strsplit(keys, "__")
  data.table(
    from     = vapply(parts, `[`, character(1), 1),
    to       = vapply(parts, `[`, character(1), 2),
    variable = vapply(parts, `[`, character(1), 3)
  )
}

#' Clear all registered split weights
#'
#' Removes all entries from the session weight registry. Useful in tests
#' and interactive sessions to start from a clean state.
#'
#' @return Invisible NULL (called for side effect)
#' @examples
#' clear_split_weights()
#' @export
clear_split_weights <- function() {
  rm(list = ls(.split_weight_registry), envir = .split_weight_registry)
  invisible(NULL)
}


#' Build a split weights template for an ambiguous conversion pair
#'
#' Returns a `data.table(code_from, code_to, weight)` for every ambiguous (1:N)
#' code in the `from -> to` conversion, ready to pass to [register_split_weights()]
#' or to the `split` argument of [rebase_series()] / `weights` of [split_ambiguous()].
#'
#' The template carries a **single** weighting variable at a time:
#' \itemize{
#'   \item `variable = NULL`, `commune_values = NULL` (default): **equal** weights (1/N).
#'   \item `variable = "population"` (a shipped standard): weights filled from the
#'     package's standard commune-level values.
#'   \item `commune_values = <table>`: weights computed from a **custom**
#'     commune-level variable you supply (any other named variable).
#' }
#' Variable-based weights are computed at the `weight_vintage` commune level (the
#' finest common refinement): each commune's value is attributed to the
#' `(from, to)` pair it falls under, then normalised to sum to 1 per `code_from`.
#'
#' Only codes that actually produce multiple target codes appear in the template;
#' unambiguous (1:1 or N:1) codes are omitted since they never need splitting.
#'
#' @param from Source classification identifier (see [classification_reference]).
#' @param to   Target classification identifier.
#' @param master_data Output from [load_master_data()].
#' @param variable Optional weighting-variable name (single). `NULL` (default)
#'   returns equal weights. `"population"` (or any other shipped standard) fills
#'   weights from the package's standard values. Any other name requires
#'   `commune_values`.
#' @param commune_values Optional `data.table` giving the variable at the
#'   `weight_vintage` commune level: columns `code` and `value` (or the first two
#'   columns are used). Supplying it computes **custom** weights and overrides the
#'   `variable` lookup.
#' @param weight_vintage Commune classification used as the weighting refinement
#'   (default `CLS_NIS_MUNICIPALITY_2019`). Both `from` and `to` must be reachable
#'   from it via a simple (N:1) path; the 2019 commune level covers every current
#'   ambiguous edge.
#' @param weight_year Optional reference year for a shipped standard `variable`.
#'   The package ships population for several years; `NULL` (default) uses the
#'   **most recent** shipped year, or pass an integer (e.g. `2019L`) for
#'   period-consistent weights (e.g. historical retropolation). Ignored when
#'   `commune_values` is supplied.
#' @return A `data.table` with columns `code_from` (character), `code_to`
#'   (character), and `weight` (numeric, summing to 1 per `code_from`). Returns an
#'   empty table (with a message) when no ambiguous codes exist for the pair.
#'
#' @examples
#' \donttest{
#'   master_data <- load_master_data()
#'
#'   # 1. Inspect the template -- equal weights are the starting point
#'   tpl <- split_weights_template(
#'     "NIS_DISTRICT_2019", "NUTS_DISTRICT_2021", master_data
#'   )
#'   #    code_from code_to weight
#'   # 1:     63000   BE335    0.5
#'   # 2:     63000   BE336    0.5
#'
#'   # 1-bis. Standard POPULATION weights (shipped): most recent year by default,
#'   #         or pick a year for period-consistent (e.g. retropolation) weights.
#'   tpl_pop  <- split_weights_template(
#'     "NIS_DISTRICT_2019", "NUTS_DISTRICT_2021", master_data, variable = "population"
#'   )
#'   tpl_2015 <- split_weights_template(
#'     "NIS_DISTRICT_2019", "NUTS_DISTRICT_2021", master_data,
#'     variable = "population", weight_year = 2015L
#'   )
#'
#'   # Or a custom commune-level variable you supply:
#'   my_vals <- data.table::data.table(code = c(63012, 63023), value = c(8000, 2000))
#'   tpl_cus <- split_weights_template(
#'     "NIS_DISTRICT_2019", "NUTS_DISTRICT_2021", master_data, commune_values = my_vals
#'   )
#'
#'   # 3a. Register for repeated use
#'   register_split_weights(
#'     "NIS_DISTRICT_2019", "NUTS_DISTRICT_2021", tpl, variable = "population"
#'   )
#'
#'   # 3b. Or pass directly to split_ambiguous
#'   arr_data <- data.table::data.table(
#'     year = c(2020L, 2021L), arr = c("63000", "63000"), emploi = c(120000, 122000)
#'   )
#'   split_ambiguous(arr_data, "arr", value_cols = "emploi",
#'                   from = "NIS_DISTRICT_2019", to = "NUTS_DISTRICT_2021",
#'                   master_data = master_data, weights = tpl, verbose = FALSE)
#' }
#' @seealso [register_split_weights()], [rebase_series()], [split_ambiguous()]
#' @export
split_weights_template <- function(from, to, master_data,
                                   variable       = NULL,
                                   commune_values = NULL,
                                   weight_vintage = CLS_NIS_MUNICIPALITY_2019,
                                   weight_year    = NULL) {
  from_norm <- normalize_classification_id(from)
  to_norm   <- normalize_classification_id(to)
  .validate_master_data(master_data)

  all_codes  <- .list_codes_for(from_norm, master_data)
  mapping_dt <- suppressWarnings(
    convert_codes(all_codes, from_norm, to_norm, master_data, allow_ambiguous = TRUE)
  )
  mapping_dt[, code_from := as.character(code_from)]
  mapping_dt[, code_to   := as.character(code_to)]

  n_per_from  <- mapping_dt[!is.na(code_to), .N, by = code_from]
  ambig_codes <- n_per_from[N > 1L, code_from]

  if (length(ambig_codes) == 0L) {
    message(sprintf("No ambiguous (1:N) codes for %s -> %s: no template needed.",
                    from_norm, to_norm))
    return(invisible(
      data.table(code_from = character(0L), code_to = character(0L), weight = numeric(0L))
    ))
  }

  template <- mapping_dt[code_from %in% ambig_codes & !is.na(code_to),
                         .(code_from, code_to)]

  # --- Equal-weight template (default) ---
  if (is.null(variable) && is.null(commune_values)) {
    template[, weight := 1 / .N, by = code_from]
    return(template[, .(code_from, code_to, weight)])
  }

  # --- Variable-based weights (standard or custom) ---
  # Resolve commune-level values (code, value) at weight_vintage (and, for a
  # shipped standard, at weight_year -- NULL picks the most recent year).
  vintage <- normalize_classification_id(weight_vintage)
  vals    <- .resolve_weight_values(variable, commune_values, vintage,
                                    weight_year, master_data)

  # Map each weighting commune to its `from` and `to` code. Both legs must be
  # simple (N:1) from a commune, so convert without allow_ambiguous (1 row each).
  comm <- vals$code
  leg_from <- convert_codes(comm, vintage, from_norm, master_data)
  leg_to   <- convert_codes(comm, vintage, to_norm,   master_data)

  link <- data.table(code = as.character(comm))
  link[, code_from := as.character(
    leg_from$code_to[match(code, as.character(leg_from$code_from))])]
  link[, code_to := as.character(
    leg_to$code_to[match(code, as.character(leg_to$code_from))])]
  link <- merge(link, vals, by = "code", all.x = TRUE)

  agg <- link[!is.na(code_from) & !is.na(code_to) & !is.na(value),
              .(mass = sum(value)), by = .(code_from, code_to)]

  # Attribute masses to the ambiguous skeleton; missing pairs -> 0; renormalise.
  out <- merge(template, agg, by = c("code_from", "code_to"), all.x = TRUE)
  out[is.na(mass), mass := 0]
  out[, weight := if (sum(mass) > 0) mass / sum(mass) else 1 / .N, by = code_from]
  out[, .(code_from, code_to, weight)]
}

# Resolve a single weighting variable to commune-level (code, value) at `vintage`.
# Priority: explicit commune_values > shipped standard for `variable`.
# `year` selects a shipped reference year (NULL = most recent); ignored for
# commune_values (which the caller supplies at a single period already).
#' @noRd
.resolve_weight_values <- function(variable, commune_values, vintage, year, master_data) {
  if (!is.null(commune_values)) {
    cv <- as.data.table(commune_values)
    if (ncol(cv) < 2L)
      abort("commune_values must have at least 2 columns (code, value).",
            class = "rcl_invalid_input")
    if (!all(c("code", "value") %in% names(cv)))
      setnames(cv, names(cv)[1:2], c("code", "value"))
    return(cv[, .(code = as.character(code), value = as.numeric(value))])
  }
  if (is.null(variable))
    abort("Provide either `variable` (a shipped standard) or `commune_values`.",
          class = "rcl_invalid_input")

  std <- .standard_weight_values(variable, vintage, year, master_data)
  if (is.null(std))
    abort(sprintf(paste0("No shipped standard weights for variable '%s' at vintage '%s'",
                         "%s. Supply commune_values=, or build the standard table via ",
                         "data-raw/build_standard_weights.R."),
                  variable, vintage,
                  if (is.null(year)) "" else sprintf(" / year %s", year)),
          class = "rcl_data_missing")
  std
}

# Look up shipped standard commune-level values for (variable, vintage, year) ->
# (code, value), or NULL if unavailable.  Source: master_data$standard_weights if
# present, else inst/extdata/standard_weight_values.rds.  Schema:
# data.table(variable, vintage, year, code, value).  A NULL/absent `year` selects
# the most recent shipped year; an absent `vintage` column (legacy single-vintage
# file) is treated as matching any vintage.
#' @noRd
.standard_weight_values <- function(variable, vintage, year, master_data) {
  sw <- master_data$standard_weights
  if (is.null(sw)) {
    f <- system.file("extdata", "standard_weight_values.rds", package = "nbbbenuts")
    if (nzchar(f) && file.exists(f)) sw <- readRDS(f)
  }
  if (is.null(sw)) return(NULL)
  sw <- as.data.table(sw)
  if (!all(c("variable", "code", "value") %in% names(sw))) return(NULL)

  # Use renamed locals in the [i] filters: inside DT[...] a bare `variable` /
  # `vintage` would resolve to the COLUMN (data.table NSE), not the argument,
  # making the filter a no-op (column == column, all TRUE).
  var_name  <- variable
  vint_name <- vintage
  hit <- sw[sw$variable == var_name]
  if ("vintage" %in% names(hit)) hit <- hit[hit$vintage == vint_name]
  if (nrow(hit) == 0L) return(NULL)

  if ("year" %in% names(hit)) {
    yr  <- if (is.null(year)) max(hit$year, na.rm = TRUE) else as.integer(year)
    hit <- hit[hit$year == yr]
    if (nrow(hit) == 0L) return(NULL)
  }
  hit[, .(code = as.character(code), value = as.numeric(value))]
}


# ==============================================================================
# Internal helpers
# ==============================================================================

#' @noRd
.resolve_weights <- function(ambig_codes, all_map, from, to, weights, normalize, verbose,
                             master_data = NULL) {

  # Equal-weight fallback
  equal_wts <- all_map[code_from %in% ambig_codes,
                        .(code_from, code_to, weight = 1 / .N), by = code_from][
                        , .(code_from, code_to, weight)]

  # Phase 4c: look up weights with primitive-overlap-edge anchoring.
  # If weights are not registered for the user-supplied (from, to) pair, also
  # try the first overlap edge in the conversion path.  This lets a user
  # register weights once for (NIS_ARR_2019 -> NUTS_DISTRICT_2021) and have them
  # automatically apply when converting NIS_ARR_2019 -> NUTS_PROVINCE_2021 or any
  # other pair that traverses that same overlap edge.
  .get_reg_weights <- function(variable = "population") {
    reg <- get_split_weights(from, to, variable = variable)
    if (!is.null(reg)) return(reg)
    # Fallback: primitive overlap edge in path
    path_check <- tryCatch(check_conversion_path(from, to), error = function(e) NULL)
    if (is.null(path_check) || is.null(path_check$edges_used) ||
        length(path_check$edges_used) == 0L)
      return(NULL)
    overlap_edges <- Filter(
      function(e) .edge_perimeter_relation(e) == "overlap",
      path_check$edges_used
    )
    for (e in overlap_edges) {
      reg2 <- get_split_weights(e$from, e$to, variable = variable)
      if (!is.null(reg2)) {
        if (verbose)
          message(sprintf(
            "  Weights anchored to primitive overlap edge: %s -> %s [variable: %s]",
            e$from, e$to, variable
          ))
        return(reg2)
      }
    }
    NULL
  }

  resolved <-
    if (is.null(weights)) {
      reg <- .get_reg_weights()
      if (!is.null(reg)) {
        if (verbose) message("  Using default weights from registry.")
        .merge_weights(equal_wts, reg)
      } else {
        if (verbose) message("  No weights provided. Using equal weights.")
        equal_wts
      }

    } else if (is.character(weights) && length(weights) == 1) {
      reg <- .get_reg_weights(variable = weights)
      if (is.null(reg) && !is.null(master_data)) {
        # Not registered -> try the SHIPPED standard for this variable (e.g.
        # "population"), at the most recent shipped year. For a specific year,
        # build the template explicitly with split_weights_template(weight_year=).
        std_tpl <- tryCatch(
          suppressMessages(split_weights_template(from, to, master_data, variable = weights)),
          rcl_data_missing = function(e) NULL, error = function(e) NULL)
        if (!is.null(std_tpl) && nrow(std_tpl) > 0L) reg <- std_tpl
      }
      if (is.null(reg)) {
        warn(sprintf(paste0("Weight variable '%s' not found in registry or shipped ",
                            "standard for %s -> %s. Using equal weights."),
                     weights, from, to),
             class = "rcl_unmatched_codes")
        equal_wts
      } else {
        if (verbose) message(sprintf("  Using '%s' weights.", weights))
        .merge_weights(equal_wts, reg)
      }

    } else if (is.data.table(weights) || is.data.frame(weights)) {
      wdt      <- as.data.table(weights)
      required <- c("code_from", "code_to", "weight")
      missing  <- setdiff(required, names(wdt))
      if (length(missing) > 0) {
        abort(sprintf("weights must have columns: %s (missing: %s)",
                      paste(required, collapse = ", "), paste(missing, collapse = ", ")),
              class = "rcl_invalid_input")
      }
      relevant   <- wdt[code_from %in% ambig_codes]
      uncovered  <- setdiff(ambig_codes, unique(relevant$code_from))
      if (length(uncovered) > 0) {
        warn(sprintf("Weights not provided for: %s. Using equal weights for these.",
                     paste(uncovered, collapse = ", ")),
             class = "rcl_unmatched_codes")
      }
      rbindlist(list(relevant, equal_wts[code_from %in% uncovered]), use.names = TRUE)

    } else {
      abort("'weights' must be NULL, a character string, or a data.table(code_from, code_to, weight).",
            class = "rcl_invalid_input")
    }

  if (normalize) {
    # Guard against a zero weight sum (all weights for a code_from explicitly 0),
    # which would divide to NaN. Fall back to equal weights, mirroring
    # split_weights_template() and .merge_weights(). (audit M3)
    resolved[, weight := if (sum(weight) > 0) weight / sum(weight) else 1 / .N,
             by = code_from]
  }

  resolved
}

#' @keywords internal
.merge_weights <- function(skeleton, reg) {
  sk  <- skeleton[, .(code_from = as.character(code_from),
                      code_to   = as.character(code_to))]
  reg <- reg[, .(code_from = as.character(code_from),
                 code_to   = as.character(code_to),
                 weight)]
  result <- merge(sk, reg, by = c("code_from", "code_to"), all.x = TRUE)
  result[is.na(weight), weight := 1 / .N, by = code_from]
  result
}
