# ==============================================================================
# 05_conversion_check.R - Check if simple conversion is possible
# ==============================================================================


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
      is_simple = TRUE,
      path = from_norm,
      relations = character(0),
      explanation = "Same classification - no conversion needed.",
      edges_used = list()
    ))
  }

  # Build adjacency list from CONVERSION_GRAPH_EDGES
  graph <- build_conversion_graph()

  # Find shortest path using BFS
  path_result <- find_conversion_path(from_norm, to_norm, graph)

  if (is.null(path_result)) {
    return(list(
      is_simple = FALSE,
      path = NULL,
      relations = NULL,
      explanation = sprintf(
        "No conversion path exists from '%s' to '%s'. Use list_available_conversions() to see all supported paths.",
        from, to
      ),
      edges_used = list()
    ))
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

  return(list(
    is_simple = is_simple,
    path = path_result$path,
    relations = path_result$relations,
    explanation = explanation,
    edges_used = path_result$edges_used
  ))
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

    # Add reverse edge with flipped relation
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
  nodes <- unique(c(
    sapply(CONVERSION_GRAPH_EDGES, function(e) e$from),
    sapply(CONVERSION_GRAPH_EDGES, function(e) e$to)
  ))
  sort(nodes)
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
