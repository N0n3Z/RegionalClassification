library(data.table)

# ==============================================================================
# test-perimeter-semantics.R  —  Phase 4a: perimeter_relation logic
# ==============================================================================
# These tests guard:
#   1. .edge_perimeter_relation() — classification of individual edges
#   2. check_conversion_path()    — enriched return fields
#   3. is_perimeter_preserving()  — exported convenience wrapper
#   4. list_available_conversions() — perimeter_relation column
# ==============================================================================

# ── PS1: .edge_perimeter_relation() — spot-checks ────────────────────────────

test_that(".edge_perimeter_relation returns 'temporal' for NIS temporal edge", {
  # NIS_COMMUNE_2019 -> NIS_COMMUNE_2025: same system, different versions
  edge <- Find(function(e) e$from == "NIS_COMMUNE_2019" && e$to == "NIS_COMMUNE_2025",
               CONVERSION_GRAPH_EDGES)
  expect_false(is.null(edge))
  pr <- nbbbenuts:::.edge_perimeter_relation(edge)
  expect_equal(pr, "temporal")
})

test_that(".edge_perimeter_relation returns 'nesting' for N:1 same-version aggregation edge", {
  # NUTS3_2021 -> NUTS2_2021: N:1, same system, same version → nesting (aggregation)
  edge <- Find(function(e) e$from == "NUTS3_2021" && e$to == "NUTS2_2021",
               CONVERSION_GRAPH_EDGES)
  expect_false(is.null(edge))
  pr <- nbbbenuts:::.edge_perimeter_relation(edge)
  expect_equal(pr, "nesting")
})

test_that(".edge_perimeter_relation returns 'overlap' for 1:N edge", {
  # NIS_COMMUNE_2025 -> NUTS3_2021: 1:N (fused communes straddle NUTS3)
  edge <- Find(function(e) e$from == "NIS_COMMUNE_2025" && e$to == "NUTS3_2021",
               CONVERSION_GRAPH_EDGES)
  expect_false(is.null(edge))
  pr <- nbbbenuts:::.edge_perimeter_relation(edge)
  expect_equal(pr, "overlap")
})

test_that(".edge_perimeter_relation returns 'overlap' for M:N edge", {
  # NIS_PROVINCE_2019 -> NIS_REGION_2019: M:N (Brabant maps to 3 regions)
  edge <- Find(function(e) e$from == "NIS_PROVINCE_2019" && e$to == "NIS_REGION_2019",
               CONVERSION_GRAPH_EDGES)
  expect_false(is.null(edge))
  expect_equal(edge$relation, "M:N")
  pr <- nbbbenuts:::.edge_perimeter_relation(edge)
  expect_equal(pr, "overlap")
})

test_that(".edge_perimeter_relation returns 'nesting' for NUTS aggregation edge", {
  # NUTS3_2021 -> NUTS2_2021: N:1, same system NUTS, same version 2021 → nesting
  # (both_ver = TRUE and temporal = FALSE since versions are equal)
  edge <- Find(function(e) e$from == "NUTS3_2021" && e$to == "NUTS2_2021",
               CONVERSION_GRAPH_EDGES)
  expect_false(is.null(edge))
  pr <- nbbbenuts:::.edge_perimeter_relation(edge)
  expect_equal(pr, "nesting")
})

# ── PS2: check_conversion_path() — perimeter fields ──────────────────────────

test_that("check_conversion_path includes perimeter_relations/status/straddle_free", {
  r <- check_conversion_path("NIS_COMMUNE_2019", "NUTS3_2021")
  expect_true(all(c("perimeter_relations", "perimeter_status", "straddle_free") %in% names(r)))
})

test_that("check_conversion_path: NIS_COMMUNE_2019 -> NUTS3_2021 is perimeter-preserving", {
  r <- check_conversion_path("NIS_COMMUNE_2019", "NUTS3_2021")
  expect_equal(r$perimeter_status, "preserving")
  expect_true(r$straddle_free)
  expect_false(any(r$perimeter_relations == "overlap"))
})

test_that("check_conversion_path: NIS_COMMUNE_2025 -> NUTS3_2021 is NOT perimeter-preserving", {
  r <- check_conversion_path("NIS_COMMUNE_2025", "NUTS3_2021")
  expect_equal(r$perimeter_status, "crossing")
  expect_false(r$straddle_free)
  expect_true(any(r$perimeter_relations == "overlap"))
})

test_that("check_conversion_path: NIS_COMMUNE_2019 -> NIS_COMMUNE_2025 is perimeter-preserving (temporal)", {
  r <- check_conversion_path("NIS_COMMUNE_2019", "NIS_COMMUNE_2025")
  expect_equal(r$perimeter_status, "preserving")
  expect_true(r$straddle_free)
  expect_equal(r$perimeter_relations, "temporal")
})

test_that("check_conversion_path: NIS_ARRONDISSEMENT_2019 -> NUTS3_2021 is NOT perimeter-preserving", {
  r <- check_conversion_path("NIS_ARRONDISSEMENT_2019", "NUTS3_2021")
  expect_equal(r$perimeter_status, "crossing")
  expect_false(r$straddle_free)
})

test_that("check_conversion_path: identity (from == to) has empty perimeter_relations", {
  r <- check_conversion_path("NUTS3_2021", "NUTS3_2021")
  expect_equal(r$perimeter_relations, character(0))
  expect_equal(r$perimeter_status, "preserving")
  expect_true(r$straddle_free)
})

test_that("check_conversion_path: perimeter fields have correct types when path exists", {
  # NIS_COMMUNE_2019 -> NUTS3_2027 (multi-hop through NIS_COMMUNE_2025)
  r <- check_conversion_path("NIS_COMMUNE_2019", "NUTS3_2027")
  # Should have a valid path
  expect_false(is.null(r$path))
  expect_true(is.character(r$perimeter_relations))
  expect_true(is.character(r$perimeter_status))
  expect_true(is.logical(r$straddle_free))
})

# ── PS3: is_perimeter_preserving() ───────────────────────────────────────────

test_that("is_perimeter_preserving: TRUE for nesting path", {
  expect_true(is_perimeter_preserving("NIS_COMMUNE_2019", "NUTS3_2021"))
})

test_that("is_perimeter_preserving: TRUE for temporal path", {
  expect_true(is_perimeter_preserving("NIS_COMMUNE_2019", "NIS_COMMUNE_2025"))
})

test_that("is_perimeter_preserving: FALSE for 1:N path (fused communes)", {
  expect_false(is_perimeter_preserving("NIS_COMMUNE_2025", "NUTS3_2021"))
})

test_that("is_perimeter_preserving: FALSE for M:N path (Verviers)", {
  expect_false(is_perimeter_preserving("NIS_ARRONDISSEMENT_2019", "NUTS3_2021"))
})

test_that("is_perimeter_preserving: TRUE for identity (from == to)", {
  expect_true(is_perimeter_preserving("NUTS3_2021", "NUTS3_2021"))
})

test_that("is_perimeter_preserving: returns logical for all valid paths", {
  # NUTS3_2021 -> NUTS2_2021 is a simple nesting edge → preserving
  expect_true(is_perimeter_preserving("NUTS3_2021", "NUTS2_2021"))
})

# ── PS4: list_available_conversions() has perimeter_relation column ───────────

test_that("list_available_conversions includes perimeter_relation column", {
  la <- list_available_conversions()
  expect_true("perimeter_relation" %in% names(la))
  expect_true(all(la$perimeter_relation %in% c("temporal", "identity", "nesting", "overlap")))
})

test_that("list_available_conversions: temporal edges classified correctly", {
  la <- list_available_conversions()
  temporal_edges <- la[from == "NIS_COMMUNE_2019" & to == "NIS_COMMUNE_2025"]
  expect_equal(nrow(temporal_edges), 1L)
  expect_equal(temporal_edges$perimeter_relation, "temporal")
})

test_that("list_available_conversions: overlap edges classified correctly", {
  la <- list_available_conversions()
  # NIS_COMMUNE_2025 -> NUTS3_2021 is 1:N (overlap)
  ov <- la[from == "NIS_COMMUNE_2025" & to == "NUTS3_2021"]
  expect_equal(nrow(ov), 1L)
  expect_equal(ov$perimeter_relation, "overlap")
  # NIS_ARR -> NUTS3_2021 is M:N (overlap)
  ov2 <- la[from == "NIS_ARRONDISSEMENT_2019" & to == "NUTS3_2021"]
  expect_equal(nrow(ov2), 1L)
  expect_equal(ov2$perimeter_relation, "overlap")
})

# ── PS5: Phase 4b — nature values for single-hop non-temporal conversions ─────

test_that("convert_codes returns nature='RECODE' for nesting conversion (N:1)", {
  r <- convert_codes(21004L, "NIS_COMMUNE_2019", "NUTS3_2021", master_data)
  expect_equal(r$nature, "RECODE")
})

test_that("convert_codes returns nature='RECODE' for identity (from == to)", {
  r <- convert_codes("BE211", "NUTS3_2021", "NUTS3_2021", master_data)
  expect_equal(r$nature, "RECODE")
})

test_that("convert_codes returns nature='OVERLAP' for 1:N conversion", {
  # NIS_COMMUNE_2025 -> NUTS3_2021 is a 1:N edge (3 fused communes straddle NUTS3)
  # All rows in the result carry nature="OVERLAP" (edge-level classification)
  r <- suppressWarnings(suppressMessages(
    convert_codes(c(21001L, 21004L), "NIS_COMMUNE_2025", "NUTS3_2021",
                  master_data, allow_ambiguous = TRUE)
  ))
  expect_true(all(r$nature == "OVERLAP"))
})

test_that("convert_codes temporal nature still carries UNCHANGED/FUSION for NIS edges", {
  r <- convert_codes(21004L, "NIS_COMMUNE_2019", "NIS_COMMUNE_2025", master_data)
  expect_equal(r$nature, "UNCHANGED")
})

test_that("convert_codes multi-hop keeps nature = NA", {
  # NUTS3_2021 -> NUTS1_2021 is a multi-hop path: nature stays NA
  r <- convert_codes("BE211", "NUTS3_2021", "NUTS1_2021", master_data)
  expect_true(is.na(r$nature))
})
