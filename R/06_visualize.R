# ==============================================================================
# 06_visualize.R - Visualization tools for classification relationships
# ==============================================================================


#' Visualize the classification relationship graph
#'
#' Creates an interactive network graph showing all classifications,
#' their versions, and the relationships between them.
#' Green edges = simple (1:1 or N:1), red edges = ambiguous (M:N or 1:N).
#'
#' @param highlight_from Optional: highlight paths from this classification
#' @param highlight_to Optional: highlight paths to this classification
#' @param output_file Optional: save to HTML file
#' @return visNetwork object (if visNetwork is available), otherwise a text summary
#' @examples
#' \donttest{
#'   # Full graph
#'   visualize_classification_graph()
#'
#'   # Highlight paths from NIS communes
#'   visualize_classification_graph(highlight_from = "NIS_COMMUNE_2019")
#'
#'   # Save to file
#'   visualize_classification_graph(output_file = "classification_graph.html")
#' }
visualize_classification_graph <- function(highlight_from = NULL,
                                           highlight_to = NULL,
                                           output_file = NULL) {

  if (!requireNamespace("visNetwork", quietly = TRUE)) {
    message("Package 'visNetwork' not installed. Showing text representation.")
    return(print_text_graph())
  }

  # Build nodes
  all_nodes <- get_all_classification_nodes()

  # Assign colors by classification system
  node_colors <- sapply(all_nodes, function(n) {
    if (grepl("^NIS_", n)) return("#4A90D9")       # Blue for NIS
    if (grepl("^NUTS", n)) return("#E67E22")        # Orange for NUTS
    if (grepl("^POSTAL", n)) return("#27AE60")      # Green for Postal
    if (grepl("^INTERNAL", n)) return("#8E44AD")    # Purple for Internal
    return("#95A5A6")                                # Gray for others
  })

  # Assign groups
  node_groups <- sapply(all_nodes, function(n) {
    if (grepl("^NIS_", n)) return("NIS")
    if (grepl("^NUTS", n)) return("NUTS")
    if (grepl("^POSTAL", n)) return("POSTAL")
    if (grepl("^INTERNAL", n)) return("INTERNAL")
    return("OTHER")
  })

  # Prettify labels
  node_labels <- gsub("_", "\n", all_nodes)

  nodes <- data.frame(
    id = all_nodes,
    label = node_labels,
    color = node_colors,
    group = node_groups,
    shape = "box",
    font.size = 14,
    stringsAsFactors = FALSE
  )

  # Build edges
  edges_list <- lapply(seq_along(CONVERSION_GRAPH_EDGES), function(i) {
    e <- CONVERSION_GRAPH_EDGES[[i]]
    is_simple <- e$relation %in% c("1:1", "N:1")
    data.frame(
      from = e$from,
      to = e$to,
      label = e$relation,
      color = ifelse(is_simple, "#27AE60", "#E74C3C"),
      width = ifelse(is_simple, 2, 3),
      dashes = !is_simple,
      title = e$notes,
      arrows = "to",
      stringsAsFactors = FALSE
    )
  })
  edges <- do.call(rbind, edges_list)

  # Highlight specific path if requested
  if (!is.null(highlight_from) && !is.null(highlight_to)) {
    from_norm <- normalize_classification_id(highlight_from)
    to_norm <- normalize_classification_id(highlight_to)
    path_check <- check_conversion_path(from_norm, to_norm)

    if (!is.null(path_check$path)) {
      # Highlight path nodes
      nodes$color[nodes$id %in% path_check$path] <- "#F1C40F"
      nodes$font.size[nodes$id %in% path_check$path] <- 18

      # Highlight path edges
      for (i in seq_len(length(path_check$path) - 1)) {
        from_edge <- path_check$path[i]
        to_edge <- path_check$path[i + 1]
        edge_idx <- which(
          (edges$from == from_edge & edges$to == to_edge) |
          (edges$from == to_edge & edges$to == from_edge)
        )
        if (length(edge_idx) > 0) {
          edges$width[edge_idx] <- 5
          edges$color[edge_idx] <- "#F1C40F"
        }
      }
    }
  }

  # Create network
  net <- visNetwork::visNetwork(
    nodes, edges,
    main = "Classification Geographique - Relations",
    submain = paste0(
      "Vert = conversion simple (1:1 / N:1) | ",
      "Rouge pointille = conversion ambigue (M:N / 1:N)"
    ),
    width = "100%", height = "700px"
  )

  net <- visNetwork::visOptions(net,
    highlightNearest = list(enabled = TRUE, degree = 1, hover = TRUE),
    nodesIdSelection = TRUE
  )

  net <- visNetwork::visLegend(net,
    addNodes = list(
      list(label = "NIS", shape = "box", color = "#4A90D9"),
      list(label = "NUTS", shape = "box", color = "#E67E22"),
      list(label = "Postal", shape = "box", color = "#27AE60"),
      list(label = "Interne", shape = "box", color = "#8E44AD")
    ),
    addEdges = list(
      list(label = "Simple", color = "#27AE60", width = 2),
      list(label = "Ambigu", color = "#E74C3C", width = 3, dashes = TRUE)
    ),
    useGroups = FALSE
  )

  net <- visNetwork::visPhysics(net,
    solver = "forceAtlas2Based",
    forceAtlas2Based = list(gravitationalConstant = -100)
  )

  # Save to file if requested
  if (!is.null(output_file)) {
    visNetwork::visSave(net, file = output_file)
    message(sprintf("Graph saved to %s", output_file))
  }

  return(net)
}

#' Print a text-based representation of the classification graph
#'
#' For use when visNetwork is not available.
#'
#' @return invisible(NULL)
print_text_graph <- function() {

  cat("\n")
  cat("========================================================\n")
  cat("  CLASSIFICATION GEOGRAPHIQUE - SCHEMA DES RELATIONS\n")
  cat("========================================================\n\n")

  # Group edges by classification system
  cat("--- NIS Hierarchy (2019 & 2025) ---\n")
  cat("  Commune -> Arrondissement -> Province -> Region\n")
  cat("  (N:1 a chaque etape)\n\n")

  cat("--- NUTS Hierarchy (2021) ---\n")
  cat("  LAU -> NUTS3 -> NUTS2 -> NUTS1 -> NUTS0\n")
  cat("  (N:1 a chaque etape)\n\n")

  cat("--- Cross-classification links ---\n")
  for (edge in CONVERSION_GRAPH_EDGES) {
    # Skip intra-hierarchy edges
    from_sys <- sub("_.*", "", edge$from)
    to_sys <- sub("_.*", "", edge$to)
    if (from_sys == to_sys) next

    is_simple <- edge$relation %in% c("1:1", "N:1")
    symbol <- ifelse(is_simple, "[OK]", "[!!]")

    cat(sprintf("  %s %s -> %s (%s)\n",
                symbol, edge$from, edge$to, edge$relation))
    if (!is_simple) {
      cat(sprintf("       Note: %s\n", edge$notes))
    }
  }

  cat("\n--- Legende ---\n")
  cat("  [OK] = Conversion simple (1:1 ou N:1)\n")
  cat("  [!!] = Conversion ambigue (M:N ou 1:N) - necessite des choix\n")
  cat("\n")

  invisible(NULL)
}

#' Visualize the conversion feasibility matrix as a heatmap
#'
#' @param output_file Optional: save plot to file
#' @return ggplot object if ggplot2 available, otherwise text matrix
#' @examples
#' \donttest{
#'   visualize_conversion_matrix()
#'   visualize_conversion_matrix(output_file = "conversion_matrix.png")
#' }
visualize_conversion_matrix <- function(output_file = NULL) {

  mat <- get_conversion_matrix()

  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    message("Package 'ggplot2' not installed. Showing text matrix.")
    # Pivot to wide format
    wide <- dcast(mat, from ~ to, value.var = "is_simple")
    print(wide)
    return(invisible(wide))
  }

  # Create heatmap
  mat[, status := fifelse(is_simple, "Simple", "Ambigu")]
  mat[is.na(is_simple), status := "Pas de chemin"]
  mat[from == to, status := "Identite"]

  p <- ggplot2::ggplot(mat, ggplot2::aes(x = to, y = from, fill = status)) +
    ggplot2::geom_tile(color = "white", linewidth = 0.5) +
    ggplot2::scale_fill_manual(
      values = c("Simple" = "#27AE60", "Ambigu" = "#E74C3C",
                 "Pas de chemin" = "#BDC3C7", "Identite" = "#3498DB"),
      name = "Type de conversion"
    ) +
    ggplot2::theme_minimal() +
    ggplot2::theme(
      axis.text.x = ggplot2::element_text(angle = 45, hjust = 1, size = 8),
      axis.text.y = ggplot2::element_text(size = 8),
      plot.title = ggplot2::element_text(hjust = 0.5)
    ) +
    ggplot2::labs(
      title = "Matrice de faisabilite des conversions",
      x = "Vers", y = "De"
    )

  if (!is.null(output_file)) {
    ggplot2::ggsave(output_file, p, width = 14, height = 10)
    message(sprintf("Matrix saved to %s", output_file))
  }

  return(p)
}

#' Visualize the hierarchy of a specific classification
#'
#' Shows the tree structure of levels within a classification.
#'
#' @param classification "NIS_2019", "NIS_2025", or "NUTS_2021"
#' @param master_data Output from build_master_table()
#' @param max_communes Maximum communes to show per arrondissement (default 3)
#' @return Character string (tree representation), printed to console
#' @examples
#' \donttest{
#'   master_data <- load_master_data()
#'   visualize_hierarchy("NIS_2019",  master_data)
#'   visualize_hierarchy("NIS_2025",  master_data)
#'   visualize_hierarchy("NUTS_2021", master_data)
#' }
visualize_hierarchy <- function(classification, master_data,
                                max_communes = 3) {

  cls <- toupper(trimws(classification))

  if (cls %in% c("NIS_2019", "NIS2019")) {
    return(print_nis_tree(master_data$communes[nis_version == "2019"], max_communes))
  }
  if (cls %in% c("NIS_2025", "NIS2025")) {
    return(print_nis_tree(master_data$communes[nis_version == "2025"], max_communes))
  }
  if (cls %in% c("NUTS_2021", "NUTS2021")) {
    return(print_nuts_tree(master_data, max_communes))
  }

  abort(
    sprintf("Hierarchy visualization not supported for '%s'. Use 'NIS_2019', 'NIS_2025', or 'NUTS_2021'.",
            classification),
    class = "rcl_invalid_input"
  )
}

#' Print NIS tree structure
#' @param communes data.table of communes (filtered to one nis_version)
#' @param max_communes Maximum communes to show per arrondissement
#' @noRd
print_nis_tree <- function(communes, max_communes = 3) {

  cat("\n")

  regions <- unique(communes[, .(cd_region, tx_region_fr)])
  regions <- regions[!is.na(cd_region)]

  for (r in seq_len(nrow(regions))) {
    reg <- regions[r]
    cat(sprintf("Region: %s (%d)\n", reg$tx_region_fr, reg$cd_region))

    provs <- unique(communes[cd_region == reg$cd_region,
                              .(cd_province, tx_prov_fr)])
    provs <- provs[!is.na(cd_province)]

    for (p in seq_len(nrow(provs))) {
      prov <- provs[p]
      is_last_prov <- p == nrow(provs)
      prefix_p <- ifelse(is_last_prov, "  +-- ", "  |-- ")
      prefix_p_child <- ifelse(is_last_prov, "      ", "  |   ")

      prov_label <- if (!is.na(prov$tx_prov_fr)) prov$tx_prov_fr else "(pas de province)"
      cat(sprintf("%sProvince: %s (%s)\n", prefix_p, prov_label, prov$cd_province))

      arrs <- unique(communes[cd_province == prov$cd_province & cd_region == reg$cd_region,
                               .(cd_arr, tx_arr_fr)])
      arrs <- arrs[!is.na(cd_arr)]

      for (a in seq_len(nrow(arrs))) {
        arr <- arrs[a]
        is_last_arr <- a == nrow(arrs)
        prefix_a <- paste0(prefix_p_child,
                           ifelse(is_last_arr, "+-- ", "|-- "))
        prefix_a_child <- paste0(prefix_p_child,
                                 ifelse(is_last_arr, "    ", "|   "))

        cat(sprintf("%sArr: %s (%d)\n", prefix_a, arr$tx_arr_fr, arr$cd_arr))

        comms <- communes[cd_arr == arr$cd_arr,
                           .(cd_commune, tx_commune_fr)]
        n_comms <- nrow(comms)
        show_n <- min(max_communes, n_comms)

        for (c_i in seq_len(show_n)) {
          comm <- comms[c_i]
          is_last_comm <- c_i == show_n && show_n == n_comms
          prefix_c <- paste0(prefix_a_child,
                             ifelse(is_last_comm, "+-- ", "|-- "))
          cat(sprintf("%s%s (%d)\n", prefix_c,
                      comm$tx_commune_fr, comm$cd_commune))
        }
        if (show_n < n_comms) {
          cat(sprintf("%s+-- ... et %d autres communes\n",
                      prefix_a_child, n_comms - show_n))
        }
      }
    }
  }

  invisible(NULL)
}

#' Print NUTS tree structure
#' @param master_data Output from load_master_data()
#' @param max_communes Maximum communes to show per NUTS3 region
#' @noRd
print_nuts_tree <- function(master_data, max_communes = 3) {

  master <- master_data$communes[nis_version == "2019"]

  cat("\nNUTS 2021 Hierarchy (Belgium)\n")
  cat("BE (Belgique/Belgie)\n")

  # NUTS1
  nuts1_list <- sort(unique(master[!is.na(cd_nuts1), cd_nuts1]))

  for (n1 in nuts1_list) {
    cat(sprintf("  |-- %s\n", n1))

    # NUTS2
    nuts2_list <- sort(unique(master[cd_nuts1 == n1 & !is.na(cd_nuts2), cd_nuts2]))

    for (n2 in nuts2_list) {
      cat(sprintf("  |   |-- %s\n", n2))

      # NUTS3
      nuts3_list <- sort(unique(master[cd_nuts2 == n2 & !is.na(cd_nuts3), cd_nuts3]))

      for (n3 in nuts3_list) {
        # Get NUTS3 name from embedded column
        n3_name <- master[cd_nuts3 == n3 & !is.na(tx_nuts3_fr), tx_nuts3_fr][1L]
        if (is.na(n3_name)) n3_name <- ""
        cat(sprintf("  |   |   |-- %s %s\n", n3, n3_name))

        # Communes
        comms  <- master[cd_nuts3 == n3, .(cd_commune, tx_commune_fr, cd_nuts_lau)]
        n_comms <- nrow(comms)
        show_n  <- min(max_communes, n_comms)

        for (c_i in seq_len(show_n)) {
          cat(sprintf("  |   |   |   |-- %s %s (NIS: %d)\n",
                      comms$cd_nuts_lau[c_i],
                      comms$tx_commune_fr[c_i],
                      comms$cd_commune[c_i]))
        }
        if (show_n < n_comms) {
          cat(sprintf("  |   |   |   +-- ... et %d autres\n",
                      n_comms - show_n))
        }
      }
    }
  }

  invisible(NULL)
}
