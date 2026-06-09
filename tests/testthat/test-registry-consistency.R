library(data.table)

# ==============================================================================
# test-registry-consistency.R  —  Phase 5b: CLASSIFICATION_REGISTRY coherence
# ==============================================================================
# CLASSIFICATION_REGISTRY (R/00_config.R) is a human-readable catalogue of
# classification *systems* (NIS, NUTS, POSTAL, INTERNAL) with their declared
# versions and levels.  CLASSIFICATION_NODES (R/00b_registry.R) is the runtime
# registry of individual classification *nodes* (22 identifiers).
#
# These tests assert that the two sources of truth are mutually consistent:
#   RC1  Every system used by a node is declared in CLASSIFICATION_REGISTRY.
#   RC2  Every non-NA version used by a node is listed in the registry system.
#   RC3  Every level used by a node is listed in the registry system
#        (case-insensitive: nodes use "nuts3", registry has "NUTS3").
#   RC4  Every version declared in the registry is referenced by at least one
#        node (no orphan versions; "current" is exempted — POSTAL/INTERNAL).
#   RC5  CLASSIFICATION_NODES keys equal VALID_CLASSIFICATIONS (parity with the
#        conversion graph — already in test-registry.R; kept here as a cross-
#        file anchor so both files catch regressions independently).
# ==============================================================================

# ── RC1: Every node system is declared in CLASSIFICATION_REGISTRY ─────────────

test_that("every system used by CLASSIFICATION_NODES exists in CLASSIFICATION_REGISTRY", {
  node_systems <- unique(vapply(CLASSIFICATION_NODES, `[[`, character(1), "system"))
  unknown      <- setdiff(node_systems, names(CLASSIFICATION_REGISTRY))
  expect_equal(length(unknown), 0L,
               info = paste("Unknown system(s):", paste(unknown, collapse = ", ")))
})

# ── RC2: Every non-NA node version is declared in its system ──────────────────

test_that("every non-NA node version is declared in CLASSIFICATION_REGISTRY", {
  failures <- character(0)
  for (id in names(CLASSIFICATION_NODES)) {
    n <- CLASSIFICATION_NODES[[id]]
    if (!is.na(n$version)) {
      reg_versions <- CLASSIFICATION_REGISTRY[[n$system]][["versions"]]
      if (!n$version %in% reg_versions)
        failures <- c(failures,
                      sprintf("%s: version '%s' absent from CLASSIFICATION_REGISTRY$%s$versions",
                              id, n$version, n$system))
    }
  }
  expect_equal(length(failures), 0L,
               info = paste(failures, collapse = "\n"))
})

# ── RC3: Every node level is declared in its system (case-insensitive) ────────

test_that("every node level is declared in CLASSIFICATION_REGISTRY (case-insensitive)", {
  failures <- character(0)
  for (id in names(CLASSIFICATION_NODES)) {
    n          <- CLASSIFICATION_NODES[[id]]
    reg_levels <- tolower(CLASSIFICATION_REGISTRY[[n$system]][["levels"]])
    if (!tolower(n$level) %in% reg_levels)
      failures <- c(failures,
                    sprintf("%s: level '%s' absent from CLASSIFICATION_REGISTRY$%s$levels",
                            id, n$level, n$system))
  }
  expect_equal(length(failures), 0L,
               info = paste(failures, collapse = "\n"))
})

# ── RC4: Every registry version is referenced by at least one node ────────────

test_that("every registry version is referenced by at least one CLASSIFICATION_NODE", {
  # "current" is used by POSTAL and INTERNAL which have version = NA_character_
  # in CLASSIFICATION_NODES — exempt from the reverse check.
  EXEMPT_VERSIONS <- "current"

  failures <- character(0)
  for (sys in names(CLASSIFICATION_REGISTRY)) {
    for (v in CLASSIFICATION_REGISTRY[[sys]][["versions"]]) {
      if (v %in% EXEMPT_VERSIONS) next
      has_node <- any(vapply(CLASSIFICATION_NODES, function(n) {
        n$system == sys && !is.na(n$version) && n$version == v
      }, logical(1)))
      if (!has_node)
        failures <- c(failures,
                      sprintf("CLASSIFICATION_REGISTRY$%s$versions includes '%s' but no node uses it",
                              sys, v))
    }
  }
  expect_equal(length(failures), 0L,
               info = paste(failures, collapse = "\n"))
})

# ── RC5: CLASSIFICATION_NODES keys == VALID_CLASSIFICATIONS ───────────────────

test_that("CLASSIFICATION_NODES keys equal VALID_CLASSIFICATIONS (22 nodes)", {
  # Cross-file anchor (also checked in test-registry.R).
  expect_setequal(names(CLASSIFICATION_NODES), VALID_CLASSIFICATIONS)
  expect_equal(length(CLASSIFICATION_NODES), 22L)
})
