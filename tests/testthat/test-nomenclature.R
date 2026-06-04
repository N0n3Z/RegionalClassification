library(data.table)

# ── Construction ─────────────────────────────────────────────────────────────
test_that("nomenclature() builds a valid object and resolves the canonical id", {
  n <- nomenclature("NIS", "commune", "2019")
  expect_s3_class(n, "nomenclature")
  expect_equal(nom_system(n),  "NIS")
  expect_equal(nom_level(n),   "commune")
  expect_equal(nom_version(n), "2019")
  expect_equal(as.character(n), "NIS_COMMUNE_2019")
})

test_that("nomenclature() accepts numeric versions and is case-insensitive", {
  expect_equal(as.character(nomenclature("nis", "Commune", 2019)), "NIS_COMMUNE_2019")
  expect_equal(as.character(nomenclature("NUTS", "nuts3", 2021)),  "NUTS3_2021")
})

test_that("nomenclature() resolves unversioned systems without a version", {
  expect_equal(as.character(nomenclature("POSTAL")),                       "POSTAL")
  expect_equal(as.character(nomenclature("NUTS", "nuts0")),                "NUTS0")
  expect_equal(as.character(nomenclature("INTERNAL", "arrondissement")),   "INTERNAL_ARRONDISSEMENT")
})

test_that("nomenclature() is idempotent on a nomenclature input", {
  n <- nomenclature("NUTS", "nuts3", "2027")
  expect_identical(nomenclature(n), n)
})

test_that("nomenclature() errors on unknown triplet", {
  expect_error(nomenclature("NIS", "commune", "1999"), class = "rcl_invalid_classification")
  expect_error(nomenclature("FOO", "bar"),             class = "rcl_invalid_classification")
})

test_that("nomenclature() errors (ambiguous) when version is needed but omitted", {
  # NIS commune exists in 3 versions -> ambiguous without version
  expect_error(nomenclature("NIS", "commune"), class = "rcl_invalid_classification")
})

# ── Predicate / accessors ────────────────────────────────────────────────────
test_that("is_nomenclature() discriminates", {
  expect_true(is_nomenclature(nomenclature("POSTAL")))
  expect_false(is_nomenclature("NIS_COMMUNE_2019"))
  expect_false(is_nomenclature(42L))
})

test_that("nom_version() is NA for unversioned systems", {
  expect_true(is.na(nom_version(nomenclature("POSTAL"))))
  expect_true(is.na(nom_version(nomenclature("NUTS", "nuts0"))))
})

# ── id <-> object bridges ────────────────────────────────────────────────────
test_that(".nom_to_id() accepts objects and strings", {
  expect_equal(nbbbenuts:::.nom_to_id(nomenclature("NIS", "commune", "2019")), "NIS_COMMUNE_2019")
  expect_equal(nbbbenuts:::.nom_to_id("nis_commune_2019"), "NIS_COMMUNE_2019")
  expect_error(nbbbenuts:::.nom_to_id("NOPE"), class = "rcl_invalid_classification")
})

test_that(".id_to_nom() / .nom_to_id() round-trip for every node", {
  for (id in names(CLASSIFICATION_NODES)) {
    n <- nbbbenuts:::.id_to_nom(id)
    expect_s3_class(n, "nomenclature")
    expect_equal(nbbbenuts:::.nom_to_id(n), id, info = id)
  }
})

# ── S3 methods ───────────────────────────────────────────────────────────────
test_that("format/print show a readable representation", {
  expect_match(format(nomenclature("NIS", "commune", "2019")),
               "NIS / commune / 2019", fixed = TRUE)
  expect_match(format(nomenclature("POSTAL")), "POSTAL / postal", fixed = TRUE)
  expect_output(print(nomenclature("NUTS", "nuts3", "2021")), "nuts3")
})

test_that("== and != compare on canonical id (object and string)", {
  n <- nomenclature("NIS", "commune", "2019")
  expect_true(n == nomenclature("nis", "commune", 2019))
  expect_true(n == "NIS_COMMUNE_2019")
  expect_true(n != nomenclature("NIS", "commune", "2025"))
  expect_false(n != "NIS_COMMUNE_2019")
})

# ── Introspection ────────────────────────────────────────────────────────────
test_that("list_nomenclatures() returns objects, filterable by system", {
  all_n <- list_nomenclatures()
  expect_equal(length(all_n), length(CLASSIFICATION_NODES))
  expect_true(all(vapply(all_n, is_nomenclature, logical(1))))

  nis <- list_nomenclatures("NIS")
  expect_true(all(vapply(nis, nom_system, "") == "NIS"))
  expect_setequal(vapply(nis, nom_level, ""),
                  c("commune", "arrondissement", "province", "region"))
})

test_that("nomenclature_levels()/versions() expose the discovery surface", {
  expect_setequal(nomenclature_levels("NIS"),
                  c("commune", "arrondissement", "province", "region"))
  expect_true("2021" %in% nomenclature_versions("NUTS"))
  expect_true("2027" %in% nomenclature_versions("NUTS"))
})

# ── Aggregation (DAG) ────────────────────────────────────────────────────────
test_that("nomenclature_children() returns the finer aggregated level", {
  kids <- nomenclature_children(nomenclature("NIS", "arrondissement", "2019"))
  expect_equal(length(kids), 1L)
  expect_equal(as.character(kids[[1]]), "NIS_COMMUNE_2019")

  expect_equal(length(nomenclature_children(nomenclature("NIS", "commune", "2019"))), 0L)
})

test_that("an arrondissement is aggregated by BOTH a province and a region", {
  parents <- nomenclature_parents(nomenclature("NIS", "arrondissement", "2019"))
  ids <- vapply(parents, as.character, "")
  expect_setequal(ids, c("NIS_PROVINCE_2019", "NIS_REGION_2019"))
})

test_that("NUTS0 aggregates both the 2021 and 2027 NUTS1 levels", {
  kids <- nomenclature_children(nomenclature("NUTS", "nuts0"))
  ids  <- vapply(kids, as.character, "")
  expect_setequal(ids, c("NUTS1_2021", "NUTS1_2027"))
})

# ── Registry consistency for the new `aggregates` field ───────────────────────
test_that("every `aggregates` target exists and shares the system", {
  for (id in names(CLASSIFICATION_NODES)) {
    n <- CLASSIFICATION_NODES[[id]]
    for (child in n$aggregates) {
      expect_true(child %in% names(CLASSIFICATION_NODES),
                  info = sprintf("%s aggregates unknown id %s", id, child))
      expect_equal(CLASSIFICATION_NODES[[child]]$system, n$system,
                   info = sprintf("%s aggregates %s across systems", id, child))
    }
  }
})

test_that("non-NUTS0 aggregation stays within a single version", {
  for (id in names(CLASSIFICATION_NODES)) {
    if (id == "NUTS0") next  # NUTS0 deliberately spans 2021 + 2027
    n <- CLASSIFICATION_NODES[[id]]
    for (child in n$aggregates) {
      expect_equal(CLASSIFICATION_NODES[[child]]$version, n$version,
                   info = sprintf("%s aggregates %s across versions", id, child))
    }
  }
})
