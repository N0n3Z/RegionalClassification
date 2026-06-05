# ==============================================================================
# 05_conversion_check.R - Check if simple conversion is possible
# ==============================================================================


#' Classify the perimeter semantics of a single conversion edge
#'
#' Returns a string describing whether the edge preserves, aggregates, or
#' crosses spatial perimeters:
#' \describe{
#'   \item{temporal}{Same system, both nodes have explicit versions that differ.
#'     Boundaries may change edition-to-edition but no cross-system split occurs.}
#'   \item{identity}{1:1 edge, same or different system, same effective territory.}
#'   \item{nesting}{N:1 edge — many fine units aggregate into one coarser unit.
#'     The source perimeter is fully contained in the target.}
#'   \item{overlap}{1:N or M:N edge — a source unit straddles multiple target
#'     units, so the source perimeter is \emph{not} contained in any single
#'     target unit. This is the only category that breaks perimeter preservation.}
#' }
#'
#' @param edge One element of \code{CONVERSION_GRAPH_EDGES} (or a reverse edge
#'   built by \code{build_conversion_graph()}).
#' @return A length-1 character string: one of \code{"temporal"},
#'   \code{"identity"}, \code{"nesting"}, \code{"overlap"}.
#' @keywords internal
.edge_perimeter_relation <- function(edge) {
  from_n <- CLASSIFICATION_NODES[[edge$from]]
  to_n   <- CLASSIFICATION_NODES[[edge$to]]
  same_sys <- !is.null(from_n) && !is.null(to_n) &&
              from_n$system == to_n$system
  both_ver <- same_sys &&
              !is.na(from_n$version) && !is.na(to_n$version)
  temporal <- both_ver && from_n$version != to_n$version

  if (temporal)                            return("temporal")
  if (edge$relation %in% c("1:N", "M:N")) return("overlap")
  if (edge$relation == "1:1")             return("identity")
  "nesting"   # N:1
}


#' Check if a simple (direct, unambiguous) conversion is possible
#'
#' A conversion is "simple" if there exists a path where every edge
#' has a 1:1 or N:1 relationship (no M:N or 1:N that would create ambiguity
#' in the target values).
#'
#' @param from Source classification identifier
#' @param to Target classification identifier
#' @return list with:
#'   - is_simple: logical
#'   - path: character vector of nodes in the conversion path
#'   - relations: character vector of relationship types along the path
#'   - explanation: human-readable explanation
#'   - edges_used: list of edges in the path
#' @examples
#' # Simple 1:1 path
#' check_conversion_path("NIS_COMMUNE_2019", "NUTS3_2021")
#'
#' # Ambiguous path (Verviers splits two NUTS3 regions)
#' check_conversion_path("NIS_ARRONDISSEMENT_2019", "NUTS3_2021")
#'
#' # Multi-hop path via intermediate classification
#' check_conversion_path("POSTAL", "NUTS3_2027")
#' @export
check_conversion_path <- function(from, to) {

  from_norm <- normalize_classification_id(from)
  to_norm <- normalize_classification_id(to)

  if (from_norm == to_norm) {
    return(list(
      is_simple           = TRUE,
      path                = from_norm,
      relations           = character(0),
      explanation         = "Same classification - no conversion needed.",
      edges_used          = list(),
      perimeter_relations = character(0),
      perimeter_status    = "preserving",
      straddle_free       = TRUE
    ))
  }

  # Build adjacency list from CONVERSION_GRAPH_EDGES
  graph <- build_conversion_graph()

  # Find shortest path using BFS
  path_result <- find_conversion_path(from_norm, to_norm, graph)

  if (is.null(path_result)) {
    return(list(
      is_simple           = FALSE,
      path                = NULL,
      relations           = NULL,
      explanation         = sprintf(
        "No conversion path exists from '%s' to '%s'. Use list_available_conversions() to see all supported paths.",
        from, to
      ),
      edges_used          = list(),
      perimeter_relations = NULL,
      perimeter_status    = NA_character_,
      straddle_free       = NA
    ))
  }

  # If a direct declared edge exists between from and to, its cardinality takes
  # precedence over any indirect BFS path. This prevents a multi-hop simple path
  # (e.g. via INTERNAL_ARRONDISSEMENT) from masking a direct 1:N or M:N edge.
  direct_edge <- Find(function(e) e$from == from_norm && e$to == to_norm,
                      CONVERSION_GRAPH_EDGES)
  if (!is.null(direct_edge) && !(direct_edge$relation %in% c("1:1", "N:1"))) {
    path_result <- list(
      path       = c(from_norm, to_norm),
      relations  = direct_edge$relation,
      edges_used = list(direct_edge)
    )
  }

  # Check if all edges in path are simple (1:1 or N:1)
  is_simple <- all(path_result$relations %in% c("1:1", "N:1"))

  if (is_simple) {
    explanation <- sprintf(
      "Simple conversion possible from '%s' to '%s'.\nPath: %s\nRelationships: %s",
      from, to,
      paste(path_result$path, collapse = " -> "),
      paste(path_result$relations, collapse = ", ")
    )
  } else {
    # Identify the problematic edge(s)
    problematic <- which(!path_result$relations %in% c("1:1", "N:1"))
    prob_details <- sapply(problematic, function(i) {
      edge <- path_result$edges_used[[i]]
      sprintf("  - %s -> %s: relationship is %s\n    %s",
              edge$from, edge$to, edge$relation, edge$notes)
    })

    explanation <- sprintf(
      paste0("Conversion from '%s' to '%s' is NOT simple (has ambiguous steps).\n",
             "Path: %s\n",
             "Relationships: %s\n",
             "Problematic step(s):\n%s"),
      from, to,
      paste(path_result$path, collapse = " -> "),
      paste(path_result$relations, collapse = ", "),
      paste(prob_details, collapse = "\n")
    )
  }

  # Extract optional coverage / ambiguous_codes metadata from the edges used
  ambiguous_codes <- NULL
  coverage        <- NULL
  for (edge in path_result$edges_used) {
    if (!is.null(edge$ambiguous_codes)) {
      ambiguous_codes <- c(ambiguous_codes, edge$ambiguous_codes)
      coverage        <- edge$coverage
    }
  }

  if (!is.null(coverage)) {
    ambig_line <- sprintf(
      "\nCoverage   : %s\nAmbiguous  : %d code(s) → %s\n%s",
      coverage,
      length(ambiguous_codes),
      paste(sort(ambiguous_codes), collapse = ", "),
      "→ Use allow_ambiguous = TRUE; register weights via register_split_weights() for proportional splits."
    )
    explanation <- paste0(explanation, ambig_line)
  }

  perimeter_relations <- vapply(path_result$edges_used,
                                .edge_perimeter_relation, character(1))
  perimeter_status    <- if (length(perimeter_relations) == 0L ||
                             !any(perimeter_relations == "overlap"))
                           "preserving" else "crossing"
  straddle_free       <- perimeter_status == "preserving"

  return(list(
    is_simple           = is_simple,
    path                = path_result$path,
    relations           = path_result$relations,
    explanation         = explanation,
    edges_used          = path_result$edges_used,
    ambiguous_codes     = ambiguous_codes,
    coverage            = coverage,
    perimeter_relations = perimeter_relations,
    perimeter_status    = perimeter_status,
    straddle_free       = straddle_free
  ))
}

#' Test whether a conversion path is perimeter-preserving
#'
#' A conversion is perimeter-preserving when no edge along the (shortest) path
#' has a `1:N` or `M:N` cardinality in the forward direction — i.e. no source
#' unit straddles two or more target units. Temporal edges (same system,
#' different edition) are always considered perimeter-preserving.
#'
#' Typical results:
#' \itemize{
#'   \item \code{NIS_COMMUNE_2019 -> NUTS3_2021}: `TRUE`  (N:1, nesting)
#'   \item \code{NIS_COMMUNE_2025 -> NUTS3_2021}: `FALSE` (1:N, fused communes
#'     straddle NUTS3 boundaries)
#'   \item \code{NIS_COMMUNE_2019 -> NIS_COMMUNE_2025}: `TRUE`  (temporal)
#' }
#'
#' @param from Source classification identifier.
#' @param to   Target classification identifier.
#' @return `TRUE` if all edges in the path are perimeter-preserving, `FALSE`
#'   if any edge is an overlap (1:N / M:N), and `NA` if no conversion path
#'   exists.
#' @examples
#' is_perimeter_preserving("NIS_COMMUNE_2019", "NUTS3_2021")   # TRUE
#' is_perimeter_preserving("NIS_COMMUNE_2025", "NUTS3_2021")   # FALSE
#' @export
is_perimeter_preserving <- function(from, to) {
  result <- check_conversion_path(from, to)
  if (is.null(result$path)) return(NA)
  isTRUE(result$straddle_free)
}


# Private cache environment — mutable after namespace lock
.graph_cache <- new.env(parent = emptyenv())

#' Build conversion graph from CONVERSION_GRAPH_EDGES
#'
#' Returns the cached graph after the first call (subsequent calls are O(1)).
#'
#' @return list (adjacency list) where each element is a list of edges
#' @keywords internal
build_conversion_graph <- function() {

  if (exists("graph", envir = .graph_cache, inherits = FALSE)) {
    return(get("graph", envir = .graph_cache))
  }

  graph <- list()

  for (edge in CONVERSION_GRAPH_EDGES) {
    from <- edge$from
    to <- edge$to

    if (is.null(graph[[from]])) graph[[from]] <- list()
    graph[[from]][[length(graph[[from]]) + 1]] <- edge

    # Add reverse edge with flipped relation, unless no_reverse = TRUE.
    # no_reverse guards cases where the reversed cardinality would be misleading
    # (e.g. the reverse of NIS_COMMUNE_2025 -> NUTS3_2021 (1:N) is 1:N from
    # NUTS3's perspective, not N:1, because many communes share a NUTS3 region).
    if (!isTRUE(edge$no_reverse)) {
      reverse_relation <- switch(edge$relation,
                                 "1:1" = "1:1",
                                 "N:1" = "1:N",
                                 "1:N" = "N:1",
                                 "M:N" = "M:N")

      reverse_edge <- edge
      reverse_edge$from <- to
      reverse_edge$to <- from
      reverse_edge$relation <- reverse_relation
      reverse_edge$notes <- paste("[Reverse]", edge$notes)

      if (is.null(graph[[to]])) graph[[to]] <- list()
      graph[[to]][[length(graph[[to]]) + 1]] <- reverse_edge
    }
  }

  assign("graph", graph, envir = .graph_cache)
  graph
}

#' Find best conversion path using two-pass BFS
#'
#' First tries to find a path using only simple edges (1:1 and N:1).
#' If no simple path exists, finds the shortest path using all edges.
#'
#' @param from Starting node
#' @param to Target node
#' @param graph Adjacency list from build_conversion_graph()
#' @return list with path, relations, edges_used, or NULL if no path
find_conversion_path <- function(from, to, graph) {

  if (from == to) {
    return(list(path = from, relations = character(0), edges_used = list()))
  }

  # Pass 1: BFS using only simple edges (1:1, N:1)
  simple_result <- bfs_find_path(from, to, graph, only_simple = TRUE)
  if (!is.null(simple_result)) {
    return(simple_result)
  }

  # Pass 2: BFS using all edges
  return(bfs_find_path(from, to, graph, only_simple = FALSE))
}

#' BFS path finder
#'
#' @param from Starting node
#' @param to Target node
#' @param graph Adjacency list
#' @param only_simple If TRUE, only traverse 1:1 and N:1 edges
#' @return list with path, relations, edges_used, or NULL
bfs_find_path <- function(from, to, graph, only_simple = FALSE) {

  queue <- list(list(node = from, path = from,
                     relations = character(0), edges = list()))
  visited <- from

  while (length(queue) > 0) {
    current <- queue[[1]]
    queue <- queue[-1]

    neighbors <- graph[[current$node]]
    if (is.null(neighbors)) next

    for (edge in neighbors) {
      # Skip non-simple edges in pass 1
      if (only_simple && !edge$relation %in% c("1:1", "N:1")) next

      next_node <- edge$to

      if (next_node == to) {
        return(list(
          path = c(current$path, next_node),
          relations = c(current$relations, edge$relation),
          edges_used = c(current$edges, list(edge))
        ))
      }

      if (!next_node %in% visited) {
        visited <- c(visited, next_node)
        queue[[length(queue) + 1]] <- list(
          node = next_node,
          path = c(current$path, next_node),
          relations = c(current$relations, edge$relation),
          edges = c(current$edges, list(edge))
        )
      }
    }
  }

  return(NULL)
}

#' Print a human-readable conversion path check
#'
#' @param from Source classification
#' @param to Target classification
#' @return Invisible path check result (prints to console)
#' @examples
#' print_conversion_check("NIS_COMMUNE_2019", "NUTS3_2021")
#' print_conversion_check("NIS_ARRONDISSEMENT_2019", "NUTS3_2021")
#' print_conversion_check("POSTAL", "NUTS3_2027")
#' @export
print_conversion_check <- function(from, to) {

  result <- check_conversion_path(from, to)

  cat("=== Conversion Path Check ===\n")
  cat(sprintf("From: %s\n", from))
  cat(sprintf("To:   %s\n", to))
  cat(sprintf("Simple conversion: %s\n",
              ifelse(result$is_simple, "YES", "NO")))
  if (!is.na(result$straddle_free)) {
    cat(sprintf("Perimeter-preserving: %s\n",
                ifelse(result$straddle_free, "YES", "NO (straddle)")))
    if (!is.null(result$perimeter_relations) && length(result$perimeter_relations) > 0L)
      cat(sprintf("Perimeter relations: %s\n",
                  paste(result$perimeter_relations, collapse = " -> ")))
  }
  cat("\n")
  cat(result$explanation)
  cat("\n")

  invisible(result)
}

#' Get all nodes in the conversion graph
#'
#' @return character vector of all classification node identifiers
#' @export
get_all_classification_nodes <- function() {
  sort(VALID_CLASSIFICATIONS)
}

#' Generate a full conversion feasibility matrix
#'
#' @return data.table with from, to, is_simple, relation_chain
#' @export
get_conversion_matrix <- function() {

  nodes <- get_all_classification_nodes()

  results <- rbindlist(lapply(nodes, function(from_node) {
    rbindlist(lapply(nodes, function(to_node) {
      if (from_node == to_node) {
        return(data.table(from = from_node, to = to_node,
                          is_simple = TRUE, relation_chain = "identity"))
      }
      check <- check_conversion_path(from_node, to_node)
      data.table(
        from = from_node,
        to = to_node,
        is_simple = check$is_simple,
        relation_chain = if (!is.null(check$relations))
          paste(check$relations, collapse = " -> ") else NA_character_
      )
    }))
  }))

  return(results)
}
