library(data.table)

# -- Construction -------------------------------------------------------------
test_that("nomenclature() builds a valid object and resolves the canonical id", {
  n <- nomenclature("NIS", "municipality", "2019")
  expect_s3_class(n, "nomenclature")
  expect_equal(nom_system(n),  "NIS")
  expect_equal(nom_level(n),   "municipality")
  expect_equal(nom_version(n), "2019")
  expect_equal(as.character(n), CLS_NIS_MUNICIPALITY_2019)
})

test_that("nomenclature() accepts numeric versions and is case-insensitive", {
  expect_equal(as.character(nomenclature("nis", "Municipality", 2019)), CLS_NIS_MUNICIPALITY_2019)
  expect_equal(as.character(nomenclature("NUTS", "district", 2021)),  CLS_NUTS_DISTRICT_2021)
})

test_that("nomenclature() resolves unversioned systems without a version", {
  expect_equal(as.character(nomenclature(CLS_POSTAL)),                       CLS_POSTAL)
  expect_equal(as.character(nomenclature("NUTS", "country")),                CLS_NUTS_COUNTRY)
  expect_equal(as.character(nomenclature("NBB", "district", "2021")),   CLS_NBB_DISTRICT_2021)
})

test_that("nomenclature() is idempotent on a nomenclature input", {
  n <- nomenclature("NUTS", "district", "2027")
  expect_identical(nomenclature(n), n)
})

test_that("nomenclature() errors on unknown triplet", {
  expect_error(nomenclature("NIS", "municipality", "1999"), class = "rcl_invalid_classification")
  expect_error(nomenclature("FOO", "bar"),             class = "rcl_invalid_classification")
})

test_that("nomenclature() errors (ambiguous) when version is needed but omitted", {
  # NIS commune exists in 3 versions -> ambiguous without version
  expect_error(nomenclature("NIS", "municipality"), class = "rcl_invalid_classification")
})

# -- Predicate / accessors ----------------------------------------------------
test_that("is_nomenclature() discriminates", {
  expect_true(is_nomenclature(nomenclature(CLS_POSTAL)))
  expect_false(is_nomenclature(CLS_NIS_MUNICIPALITY_2019))
  expect_false(is_nomenclature(42L))
})

test_that("nom_version() is NA for unversioned systems", {
  expect_true(is.na(nom_version(nomenclature(CLS_POSTAL))))
  expect_true(is.na(nom_version(nomenclature("NUTS", "country"))))
})

# -- id <-> object bridges ----------------------------------------------------
test_that(".nom_to_id() accepts objects and strings", {
  expect_equal(nbbbenuts:::.nom_to_id(nomenclature("NIS", "municipality", "2019")), CLS_NIS_MUNICIPALITY_2019)
  expect_equal(nbbbenuts:::.nom_to_id("nis_municipality_2019"), CLS_NIS_MUNICIPALITY_2019)
  expect_error(nbbbenuts:::.nom_to_id("NOPE"), class = "rcl_invalid_classification")
})

test_that(".id_to_nom() / .nom_to_id() round-trip for every node", {
  for (id in names(CLASSIFICATION_NODES)) {
    n <- nbbbenuts:::.id_to_nom(id)
    expect_s3_class(n, "nomenclature")
    expect_equal(nbbbenuts:::.nom_to_id(n), id, info = id)
  }
})

# -- S3 methods ---------------------------------------------------------------
test_that("format/print show a readable representation", {
  expect_match(format(nomenclature("NIS", "municipality", "2019")),
               "NIS / municipality / 2019", fixed = TRUE)
  expect_match(format(nomenclature(CLS_POSTAL)), "POSTAL / postal", fixed = TRUE)
  expect_output(print(nomenclature("NUTS", "district", "2021")), "district")
})

test_that("== and != compare on canonical id (object and string)", {
  n <- nomenclature("NIS", "municipality", "2019")
  expect_true(n == nomenclature("nis", "municipality", 2019))
  expect_true(n == CLS_NIS_MUNICIPALITY_2019)
  expect_true(n != nomenclature("NIS", "municipality", "2025"))
  expect_false(n != CLS_NIS_MUNICIPALITY_2019)
})

# -- Introspection ------------------------------------------------------------
test_that("list_nomenclatures() returns objects, filterable by system", {
  all_n <- list_nomenclatures()
  expect_equal(length(all_n), length(CLASSIFICATION_NODES))
  expect_true(all(vapply(all_n, is_nomenclature, logical(1))))

  nis <- list_nomenclatures("NIS")
  expect_true(all(vapply(nis, nom_system, "") == "NIS"))
  expect_setequal(vapply(nis, nom_level, ""),
                  c("municipality", "district", "province", "region", "country"))
})

test_that("nomenclature_levels()/versions() expose the discovery surface", {
  expect_setequal(nomenclature_levels("NIS"),
                  c("municipality", "district", "province", "region", "country"))
  expect_true("2021" %in% nomenclature_versions("NUTS"))
  expect_true("2027" %in% nomenclature_versions("NUTS"))
})

# -- Aggregation (DAG) --------------------------------------------------------
test_that("nomenclature_children() returns the finer aggregated level", {
  kids <- nomenclature_children(nomenclature("NIS", "district", "2019"))
  expect_equal(length(kids), 1L)
  expect_equal(as.character(kids[[1]]), CLS_NIS_MUNICIPALITY_2019)

  expect_equal(length(nomenclature_children(nomenclature("NIS", "municipality", "2019"))), 0L)
})

test_that("NIS levels form a strict region -> province -> district hierarchy", {
  # An arrondissement has exactly ONE parent: its province (since the 1995
  # Brabant split each province nests in a single region, so the region sits one
  # level up via the province rather than aggregating arrondissements directly).
  parents <- nomenclature_parents(nomenclature("NIS", "district", "2019"))
  expect_setequal(vapply(parents, as.character, ""), CLS_NIS_PROVINCE_2019)

  # A region aggregates provinces (not arrondissements directly).
  reg_kids <- nomenclature_children(nomenclature("NIS", "region", "2019"))
  expect_setequal(vapply(reg_kids, as.character, ""), CLS_NIS_PROVINCE_2019)

  # A province aggregates arrondissements.
  prov_kids <- nomenclature_children(nomenclature("NIS", "province", "2019"))
  expect_setequal(vapply(prov_kids, as.character, ""), CLS_NIS_DISTRICT_2019)
})

test_that("NUTS_COUNTRY aggregates both the 2021 and 2027 NUTS1 levels", {
  kids <- nomenclature_children(nomenclature("NUTS", "country"))
  ids  <- vapply(kids, as.character, "")
  expect_setequal(ids, c(CLS_NUTS_REGION_2021, CLS_NUTS_REGION_2027))
})

# -- Registry consistency for the new `aggregates` field -----------------------
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

test_that("non-NUTS_COUNTRY aggregation stays within a single version", {
  for (id in names(CLASSIFICATION_NODES)) {
    if (id == CLS_NUTS_COUNTRY) next  # NUTS_COUNTRY deliberately spans 2021 + 2027
    if (id == CLS_NIS_COUNTRY)  next  # NIS_COUNTRY deliberately spans all NIS versions
    n <- CLASSIFICATION_NODES[[id]]
    for (child in n$aggregates) {
      expect_equal(CLASSIFICATION_NODES[[child]]$version, n$version,
                   info = sprintf("%s aggregates %s across versions", id, child))
    }
  }
})
