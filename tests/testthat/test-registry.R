library(data.table)

# ── Parity: registry keys == VALID_CLASSIFICATIONS ───────────────────────────
test_that("CLASSIFICATION_NODES keys match VALID_CLASSIFICATIONS exactly", {
  expect_true(setequal(names(CLASSIFICATION_NODES), VALID_CLASSIFICATIONS))
})

test_that("CLASSIFICATION_NODES keys match get_all_classification_nodes() parity", {
  # get_all_classification_nodes() still returns a sorted character vector;
  # the new registry must cover exactly the same set of identifiers.
  expect_true(setequal(names(CLASSIFICATION_NODES), get_all_classification_nodes()))
})

# ── Every node resolvable via .node() ────────────────────────────────────────
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

# ── code_type is "integer" or "character" ────────────────────────────────────
test_that("every node has code_type 'integer' or 'character'", {
  for (id in VALID_CLASSIFICATIONS) {
    ct <- nbbbenuts:::.node_code_type(id)
    expect_true(ct %in% c("integer", "character"), info = id)
  }
})

# ── code_type matches the actual column type in the RDS ──────────────────────
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

# ── label columns exist in the source table ──────────────────────────────────
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

# ── .node_parse() covers all 22 nodes ────────────────────────────────────────
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
  check("NIS_COMMUNE_2019",              "NIS_COMMUNE",             "2019")
  check("NIS_COMMUNE_BEFORE_2019",       "NIS_COMMUNE",             "BEFORE_2019")
  check("NIS_ARRONDISSEMENT_BEFORE_2019","NIS_ARRONDISSEMENT",      "BEFORE_2019")
  check("NIS_PROVINCE_BEFORE_2019",      "NIS_PROVINCE",            "BEFORE_2019")
  check("NIS_REGION_BEFORE_2019",        "NIS_REGION",              "BEFORE_2019")
  check("NUTS3_2021",                    "NUTS3",                   "2021")
  check("NUTS_LAU_2021",                 "NUTS_LAU",                "2021")
  check("NUTS0",                         "NUTS0",                   NA_character_)
  check("POSTAL",                        "POSTAL",                  NA_character_)
  check("INTERNAL_ARRONDISSEMENT",       "INTERNAL_ARRONDISSEMENT", NA_character_)
})

# ── .node_label_meta() matches .LABEL_META structure ─────────────────────────
test_that(".node_label_meta() returns the five expected fields", {
  meta <- nbbbenuts:::.node_label_meta("NUTS3_2021")
  expect_equal(sort(names(meta)), sort(c("ver","code","fr","nl","src")))
  expect_equal(meta$code, "cd_nuts3")
  expect_equal(meta$src,  "communes")
  expect_equal(meta$fr,   "tx_nuts3_fr")
})

test_that(".node_label_meta() agrees with .LABEL_META for all nodes", {
  for (id in names(nbbbenuts:::.LABEL_META)) {
    legacy <- nbbbenuts:::.LABEL_META[[id]]
    new    <- nbbbenuts:::.node_label_meta(id)
    expect_equal(new$ver,  legacy$ver,  info = id)
    expect_equal(new$code, legacy$code, info = id)
    expect_equal(new$fr,   legacy$fr,   info = id)
    expect_equal(new$nl,   legacy$nl,   info = id)
    expect_equal(new$src,  legacy$src,  info = id)
  }
})

# ── .node_reference_codes() returns the right structure ──────────────────────
test_that(".node_reference_codes() returns data.table(code, name_fr, name_nl)", {
  ref <- nbbbenuts:::.node_reference_codes("NUTS3_2021", master_data)
  expect_true(is.data.table(ref))
  expect_true(all(c("code","name_fr","name_nl") %in% names(ref)))
  expect_gt(nrow(ref), 0L)
  expect_type(ref$code, "character")
})

test_that(".node_reference_codes() returns NULL for empty BEFORE_2019 slice", {
  empty_md <- master_data
  empty_md$communes <- master_data$communes[nis_version != "BEFORE_2019"]
  result <- nbbbenuts:::.node_reference_codes("NIS_COMMUNE_BEFORE_2019", empty_md)
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
  check_parity("NIS_COMMUNE_2019")
  check_parity("NIS_ARRONDISSEMENT_2019")
  check_parity("NUTS3_2021")
  check_parity("NUTS3_2027")
  check_parity("POSTAL")
  check_parity("INTERNAL_ARRONDISSEMENT")
})

# ── .node_coerce() type coercion ─────────────────────────────────────────────
test_that(".node_coerce() coerces to integer for NIS nodes", {
  result <- nbbbenuts:::.node_coerce("21004", "NIS_COMMUNE_2019")
  expect_type(result, "integer")
  expect_equal(result, 21004L)
})

test_that(".node_coerce() coerces to character for NUTS nodes", {
  result <- nbbbenuts:::.node_coerce(21004L, "NUTS3_2021")
  expect_type(result, "character")
  expect_equal(result, "21004")
})
