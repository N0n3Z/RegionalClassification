library(data.table)

# -- Parity: registry keys == VALID_CLASSIFICATIONS ---------------------------
test_that("CLASSIFICATION_NODES keys match VALID_CLASSIFICATIONS exactly", {
  expect_true(setequal(names(CLASSIFICATION_NODES), VALID_CLASSIFICATIONS))
})

test_that("CLASSIFICATION_NODES keys match get_all_classification_nodes() parity", {
  # get_all_classification_nodes() still returns a sorted character vector;
  # the new registry must cover exactly the same set of identifiers.
  expect_true(setequal(names(CLASSIFICATION_NODES), get_all_classification_nodes()))
})

# -- Every node resolvable via .node() ----------------------------------------
test_that("every valid classification resolves via .node()", {
  for (id in VALID_CLASSIFICATIONS) {
    n <- nbbbenuts:::.node(id)
    expect_true(is.list(n), info = id)
    expect_true(all(c("system","level","version","code_type","source_table",
                      "version_filter","code_col","label_fr_col","label_nl_col",
                      "distinct","detectable") %in% names(n)),
                info = id)
  }
})

test_that(".node() aborts with rcl_invalid_classification for unknown id", {
  expect_error(nbbbenuts:::.node("DOES_NOT_EXIST"),
               class = "rcl_invalid_classification")
})

# -- code_type is "integer" or "character" ------------------------------------
test_that("every node has code_type 'integer' or 'character'", {
  for (id in VALID_CLASSIFICATIONS) {
    ct <- nbbbenuts:::.node_code_type(id)
    expect_true(ct %in% c("integer", "character"), info = id)
  }
})

# -- code_type matches the actual column type in the RDS ----------------------
test_that("code_type matches the real column class in master_data", {
  for (id in names(CLASSIFICATION_NODES)) {
    n   <- CLASSIFICATION_NODES[[id]]
    tbl <- if (n$source_table == "communes") master_data$communes
           else                               master_data$postal
    # Use the version-filtered slice (some columns only exist in one version)
    slice <- tbl[get("nis_version") == n$version_filter]
    if (nrow(slice) == 0L) next  # BEFORE_2019 optional
    col <- slice[[n$code_col]]
    if (is.null(col)) next

    expected_class <- if (n$code_type == "integer") "integer" else "character"
    actual_class   <- class(col)
    expect_equal(actual_class, expected_class, info = id)
  }
})

# -- label columns exist in the source table ----------------------------------
test_that("non-NA label columns exist in the source table", {
  for (id in names(CLASSIFICATION_NODES)) {
    n   <- CLASSIFICATION_NODES[[id]]
    tbl <- if (n$source_table == "communes") master_data$communes
           else                               master_data$postal
    if (!is.na(n$label_fr_col))
      expect_true(n$label_fr_col %in% names(tbl), info = paste(id, "fr"))
    if (!is.na(n$label_nl_col))
      expect_true(n$label_nl_col %in% names(tbl), info = paste(id, "nl"))
  }
})

# -- .node_parse() covers all 22 nodes ----------------------------------------
test_that(".node_parse() returns non-NA type for every node", {
  for (id in VALID_CLASSIFICATIONS) {
    p <- nbbbenuts:::.node_parse(id)
    expect_false(is.na(p$type),    info = id)
    expect_true(is.character(p$type), info = id)
  }
})

test_that(".node_parse() spot-checks match legacy .parse_classification_id()", {
  check <- function(id, exp_type, exp_ver) {
    p <- nbbbenuts:::.node_parse(id)
    expect_equal(p$type,    exp_type, info = id)
    expect_equal(p$version, exp_ver,  info = id)
  }
  check(CLS_NIS_MUNICIPALITY_2019,              "NIS_MUNICIPALITY",        "2019")
  check(CLS_NIS_MUNICIPALITY_BEFORE_2019,       "NIS_MUNICIPALITY",        "BEFORE_2019")
  check(CLS_NIS_DISTRICT_BEFORE_2019,           "NIS_DISTRICT",            "BEFORE_2019")
  check(CLS_NIS_PROVINCE_BEFORE_2019,           "NIS_PROVINCE",            "BEFORE_2019")
  check(CLS_NIS_REGION_BEFORE_2019,             "NIS_REGION",              "BEFORE_2019")
  check(CLS_NUTS_DISTRICT_2021,                 "NUTS_DISTRICT",           "2021")
  check(CLS_NUTS_LAU_2021,                      "NUTS_LAU",                "2021")
  check(CLS_NUTS_COUNTRY,                       CLS_NUTS_COUNTRY,          NA_character_)
  check(CLS_POSTAL,                             CLS_POSTAL,                NA_character_)
  check(CLS_NBB_DISTRICT_2021,                  "NBB_DISTRICT",            "2021")
})

# -- .node_label_meta() matches .LABEL_META structure -------------------------
test_that(".node_label_meta() returns the five expected fields", {
  meta <- nbbbenuts:::.node_label_meta(CLS_NUTS_DISTRICT_2021)
  expect_equal(sort(names(meta)), sort(c("ver","code","fr","nl","src")))
  expect_equal(meta$code, "cd_nuts3")
  expect_equal(meta$src,  "communes")
  expect_equal(meta$fr,   "tx_nuts3_fr")
})

test_that(".node_label_meta() returns correct values for all 22 nodes", {
  # .LABEL_META has been removed; verify key nodes directly against known values.
  check <- function(id, exp_ver, exp_code, exp_fr, exp_nl, exp_src) {
    m <- nbbbenuts:::.node_label_meta(id)
    expect_equal(m$ver,  exp_ver,  info = id)
    expect_equal(m$code, exp_code, info = id)
    expect_equal(m$fr,   exp_fr,   info = id)
    expect_equal(m$nl,   exp_nl,   info = id)
    expect_equal(m$src,  exp_src,  info = id)
  }
  check(CLS_NIS_MUNICIPALITY_2019,    "2019",        "cd_commune",    "tx_commune_fr", "tx_commune_nl", "communes")
  check(CLS_NIS_MUNICIPALITY_2025,    "2025",        "cd_commune",    "tx_commune_fr", "tx_commune_nl", "communes")
  check(CLS_NIS_MUNICIPALITY_BEFORE_2019, "BEFORE_2019", "cd_commune","tx_commune_fr","tx_commune_nl", "communes")
  check(CLS_NIS_DISTRICT_2019, "2019",    "cd_arr",        "tx_arr_fr",    "tx_arr_nl",     "communes")
  check(CLS_NUTS_DISTRICT_2021,          "2019",        "cd_nuts3",      "tx_nuts3_fr",  "tx_nuts3_nl",   "communes")
  check(CLS_NUTS_PROVINCE_2021,          "2019",        "cd_nuts2",      NA_character_,  NA_character_,   "communes")
  check(CLS_NUTS_LAU_2021,       "2019",        "cd_nuts_lau",   "tx_commune_fr","tx_commune_nl", "communes")
  check(CLS_NUTS_COUNTRY,               "2019",        "cd_nuts0",      NA_character_,  NA_character_,   "communes")
  check(CLS_NUTS_DISTRICT_2027,          "2025",        "cd_nuts3_2027", NA_character_,  NA_character_,   "communes")
  check(CLS_POSTAL,              "2019",        "cd_postal",     "tx_postal_name_fr","tx_postal_name_nl","postal")
  check(CLS_NBB_DISTRICT_2021,"2019",     "cd_arr_internal","tx_arr_fr",   "tx_arr_nl",     "communes")
  # All 22 nodes resolvable without error
  for (id in VALID_CLASSIFICATIONS) {
    m <- nbbbenuts:::.node_label_meta(id)
    expect_true(is.list(m) && length(m) == 5L, info = id)
  }
})

# -- .node_reference_codes() returns the right structure ----------------------
test_that(".node_reference_codes() returns data.table(code, name_fr, name_nl)", {
  ref <- nbbbenuts:::.node_reference_codes(CLS_NUTS_DISTRICT_2021, master_data)
  expect_true(is.data.table(ref))
  expect_true(all(c("code","name_fr","name_nl") %in% names(ref)))
  expect_gt(nrow(ref), 0L)
  expect_type(ref$code, "character")
})

test_that(".node_reference_codes() returns NULL for absent BEFORE_2019 data", {
  # Phase 3: the fast path reads md$entities, so we must remove the BEFORE_2019
  # classification from entities (not just from communes) to simulate data absence.
  empty_md <- master_data
  empty_md$entities <- master_data$entities[
    !classification_id %in% grep("BEFORE_2019", names(CLASSIFICATION_NODES), value = TRUE)
  ]
  result <- nbbbenuts:::.node_reference_codes(CLS_NIS_MUNICIPALITY_BEFORE_2019, empty_md)
  expect_null(result)
})

test_that(".node_reference_codes() agrees with .list_codes_for() for key nodes", {
  check_parity <- function(id) {
    ref   <- nbbbenuts:::.node_reference_codes(id, master_data)
    legacy <- nbbbenuts:::.list_codes_for(id, master_data)
    # Both should contain the same set of codes (order may differ)
    expect_true(setequal(as.character(ref$code), as.character(legacy)),
                info = id)
  }
  check_parity(CLS_NIS_MUNICIPALITY_2019)
  check_parity(CLS_NIS_DISTRICT_2019)
  check_parity(CLS_NUTS_DISTRICT_2021)
  check_parity(CLS_NUTS_DISTRICT_2027)
  check_parity(CLS_POSTAL)
  check_parity(CLS_NBB_DISTRICT_2021)
})

# -- .node_coerce() type coercion ---------------------------------------------
test_that(".node_coerce() coerces to integer for NIS nodes", {
  result <- nbbbenuts:::.node_coerce("21004", CLS_NIS_MUNICIPALITY_2019)
  expect_type(result, "integer")
  expect_equal(result, 21004L)
})

test_that(".node_coerce() coerces to character for NUTS nodes", {
  result <- nbbbenuts:::.node_coerce(21004L, CLS_NUTS_DISTRICT_2021)
  expect_type(result, "character")
  expect_equal(result, "21004")
})

# -- Phase 5: CLASSIFICATION_REGISTRY consistency with CLASSIFICATION_NODES ----
# CLASSIFICATION_REGISTRY is a system-level grouping (NIS, NUTS, POSTAL, INTERNAL).
# CLASSIFICATION_NODES is the granular per-node truth. The registry must cover
# every system and level that a node declares.

test_that("CLASSIFICATION_REGISTRY covers every system in CLASSIFICATION_NODES", {
  node_systems <- unique(vapply(CLASSIFICATION_NODES, function(n) n$system, character(1)))
  missing_sys  <- setdiff(node_systems, names(CLASSIFICATION_REGISTRY))
  expect_equal(length(missing_sys), 0L,
               info = paste("Systems in CLASSIFICATION_NODES but not in CLASSIFICATION_REGISTRY:",
                            paste(missing_sys, collapse = ", ")))
})

test_that("CLASSIFICATION_REGISTRY levels cover every level in CLASSIFICATION_NODES", {
  for (id in names(CLASSIFICATION_NODES)) {
    n       <- CLASSIFICATION_NODES[[id]]
    reg_lvl <- tolower(CLASSIFICATION_REGISTRY[[n$system]]$levels)
    expect_true(tolower(n$level) %in% reg_lvl,
                info = sprintf(
                  "%s: level '%s' not in CLASSIFICATION_REGISTRY$%s$levels (%s)",
                  id, n$level, n$system, paste(reg_lvl, collapse = ", ")
                ))
  }
})

test_that("CLASSIFICATION_REGISTRY versions cover every non-NA version in CLASSIFICATION_NODES", {
  for (id in names(CLASSIFICATION_NODES)) {
    n <- CLASSIFICATION_NODES[[id]]
    if (is.na(n$version)) next   # NA -> "current" in the registry; skip
    reg_ver <- CLASSIFICATION_REGISTRY[[n$system]]$versions
    expect_true(n$version %in% reg_ver,
                info = sprintf(
                  "%s: version '%s' not in CLASSIFICATION_REGISTRY$%s$versions (%s)",
                  id, n$version, n$system, paste(reg_ver, collapse = ", ")
                ))
  }
})
