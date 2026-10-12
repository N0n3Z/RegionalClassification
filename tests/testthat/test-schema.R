library(data.table)

# ==============================================================================
# Schema v2 naming convention (see SCHEMA_V1_TO_V2 in R/00_config.R)
# ==============================================================================

SCHEMA_COL_PATTERN <- "^(code|label|version|classification)(_[a-z0-9]+)*$"
SCHEMA_PLAIN_COLS  <- c("relation", "nature", "weight")

test_that("registry code_col follows the node-id naming rule", {
  for (id in names(CLASSIFICATION_NODES)) {
    expect_equal(CLASSIFICATION_NODES[[id]]$code_col,
                 nbbbenuts:::.node_code_col(id), info = id)
  }
})

test_that("every persisted table follows the column naming convention", {
  for (tbl in MASTER_FLAT_TABLES) {
    cols <- names(master_data[[tbl]])
    expect_gt(length(cols), 0L)
    bad <- cols[!grepl(SCHEMA_COL_PATTERN, cols) & !cols %in% SCHEMA_PLAIN_COLS]
    expect_length(bad, 0L)
    if (length(bad)) message(tbl, ": ", paste(bad, collapse = ", "))
  }
})

test_that("label columns end with a language suffix", {
  for (tbl in MASTER_FLAT_TABLES) {
    lbl <- grep("^label", names(master_data[[tbl]]), value = TRUE)
    expect_true(all(grepl("_(fr|nl)$", lbl)), info = tbl)
  }
})

test_that("every code_* column is character", {
  for (tbl in MASTER_FLAT_TABLES) {
    dt <- master_data[[tbl]]
    for (col in grep("^code", names(dt), value = TRUE))
      expect_type(dt[[col]], "character")
  }
})

test_that("no persisted table carries a schema v1 column name", {
  v1_cols <- unique(unlist(lapply(SCHEMA_V1_TO_V2, names)))
  for (tbl in MASTER_FLAT_TABLES)
    expect_length(intersect(names(master_data[[tbl]]), v1_cols), 0L)
  expect_null(master_data$communes)
})

test_that("SCHEMA_V1_TO_V2 targets all follow the convention", {
  targets <- unique(unlist(SCHEMA_V1_TO_V2))
  expect_true(all(grepl(SCHEMA_COL_PATTERN, targets)))
})

test_that("nis_changes version_to is consistent with version_from", {
  nc <- master_data$nis_changes
  expect_equal(nc$version_to, unname(NIS_CHANGE_VERSION_TO[nc$version_from]))
})

# -- .migrate_schema_v1() ------------------------------------------------------

v1_fixture <- function() {
  list(
    communes = data.table(cd_commune = "21004", tx_commune_fr = "Bruxelles",
                          cd_arr = "21000", cd_arr_2digit = "21",
                          cd_nuts3 = "BE100", nis_version = "2019"),
    postal = data.table(cd_postal = "1000", cd_commune_nis = "21004",
                        tx_postal_name_fr = "Bruxelles", nis_version = "2019"),
    nis_changes = data.table(cd_refnis_old = c("11001", "11002"),
                             cd_refnis_new = c("11002", "11002"),
                             nature = "FUSION",
                             from_version = c("2019", "BEFORE_2019")),
    entities = data.table(classification_id = "POSTAL", code = "1000",
                          name_fr = "Bruxelles", name_nl = "Brussel"),
    crosswalks = data.table(from_id = "POSTAL", to_id = "NIS_MUNICIPALITY_2019",
                            code_from = "1000", code_to = "21004",
                            relation = "N:1", nature = NA_character_)
  )
}

test_that(".migrate_schema_v1 renames a v1 object to schema v2 with one warning", {
  v1 <- v1_fixture()
  expect_warning(md <- nbbbenuts:::.migrate_schema_v1(v1), class = "rcl_legacy_schema")
  expect_null(md$communes)
  expect_equal(names(md$municipalities),
               c("code_nis_municipality", "label_nis_municipality_fr",
                 "code_nis_district", "code_nuts_district_2021", "version"))
  expect_equal(names(md$postal),
               c("code_postal", "code_nis_municipality", "label_postal_fr", "version"))
  expect_equal(names(md$nis_changes),
               c("code_from", "code_to", "nature", "version_from", "version_to"))
  expect_equal(md$nis_changes$version_to, c("2025", "2019"))
  expect_equal(names(md$entities), c("classification", "code", "label_fr", "label_nl"))
  expect_equal(names(md$crosswalks)[1:2], c("classification_from", "classification_to"))
  # input left untouched (tables are copied)
  expect_true("cd_commune" %in% names(v1$communes))
})

test_that(".migrate_schema_v1 is a no-op on a v2 object", {
  expect_silent(md <- nbbbenuts:::.migrate_schema_v1(master_data))
  expect_identical(md, master_data)
})

test_that("load_master_data migrates a v1 snapshot directory", {
  dir <- tempfile("v1snap")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  v1 <- v1_fixture()
  for (nm in names(v1)) saveRDS(v1[[nm]], file.path(dir, paste0(nm, ".rds")))
  expect_warning(md <- suppressMessages(load_master_data(dir)), class = "rcl_legacy_schema")
  expect_true("code_nis_municipality" %in% names(md$municipalities))
})

test_that("conversion on an in-memory v1 object aborts with rcl_legacy_schema", {
  v1 <- v1_fixture()
  expect_error(
    convert_codes("1000", CLS_POSTAL, CLS_NIS_MUNICIPALITY_2019, v1),
    class = "rcl_legacy_schema"
  )
})
