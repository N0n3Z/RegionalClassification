library(data.table)

# ==============================================================================
# test-temporal-nature.R  --  Phase 5a: CHANGE_DSTR / CHANGE_PROV coverage
# ==============================================================================
# Guards that convert_codes() correctly propagates nature values on temporal
# (NIS 2019 <-> 2025) edges:
#
#   UNCHANGED   --  commune code persists in both versions (553 communes)
#   FUSION      --  one or more 2019 communes merged into one 2025 code (27 pairs)
#   CHANGE_DSTR --  commune moved to a different arrondissement (2 communes)
#   CHANGE_PROV --  commune moved to a different province (1 commune)
#
# Source codes (from nis_changes table, from_version == VER_2019):
#   CHANGE_DSTR:  44045 -> 46029,  73040 -> 71072
#   CHANGE_PROV:  11056 -> 46030
# ==============================================================================

# -- TN1: CHANGE_DSTR -- forward (2019 -> 2025) --------------------------------

test_that("convert_codes returns CHANGE_DSTR for commune 44045 (arr change -> 46029)", {
  r <- convert_codes(44045L, CLS_NIS_MUNICIPALITY_2019, CLS_NIS_MUNICIPALITY_2025, master_data)
  expect_equal(r$nature,   "CHANGE_DSTR")
  expect_equal(r$code_to,  46029L)
  expect_equal(r$code_from, 44045L)
})

test_that("convert_codes returns CHANGE_DSTR for commune 73040 (arr change -> 71072)", {
  r <- convert_codes(73040L, CLS_NIS_MUNICIPALITY_2019, CLS_NIS_MUNICIPALITY_2025, master_data)
  expect_equal(r$nature,   "CHANGE_DSTR")
  expect_equal(r$code_to,  71072L)
  expect_equal(r$code_from, 73040L)
})

# -- TN2: CHANGE_PROV -- forward (2019 -> 2025) --------------------------------

test_that("convert_codes returns CHANGE_PROV for commune 11056 (prov change -> 46030)", {
  r <- convert_codes(11056L, CLS_NIS_MUNICIPALITY_2019, CLS_NIS_MUNICIPALITY_2025, master_data)
  expect_equal(r$nature,   "CHANGE_PROV")
  expect_equal(r$code_to,  46030L)
  expect_equal(r$code_from, 11056L)
})

# -- TN3: CHANGE_DSTR / CHANGE_PROV -- reverse (2025 -> 2019) ------------------
# NIS_MUNICIPALITY_2025 -> NIS_MUNICIPALITY_2019 is a non-simple edge overall (FUSION
# cases make it 1:N for some codes), so allow_ambiguous = TRUE is required.
# CHANGE_DSTR and CHANGE_PROV codes are 1:1 in both directions (single row).

test_that("reverse temporal conversion preserves CHANGE_DSTR (46029 contains 44045)", {
  # 46029 is a composite 2025 commune: 44045 (CHANGE_DSTR) merged with other
  # FUSION communes.  allow_ambiguous returns one row per constituent 2019 code.
  r <- convert_codes(46029L, CLS_NIS_MUNICIPALITY_2025, CLS_NIS_MUNICIPALITY_2019,
                     master_data, allow_ambiguous = TRUE)
  # At least one row should record the CHANGE_DSTR constituent
  dstr_row <- r[code_to == 44045L]
  expect_equal(nrow(dstr_row), 1L)
  expect_equal(dstr_row$nature, "CHANGE_DSTR")
})

test_that("reverse temporal conversion preserves CHANGE_PROV (46030 contains 11056)", {
  # 46030 is a composite 2025 commune: 11056 (CHANGE_PROV) merged with FUSION
  # communes.  allow_ambiguous returns one row per constituent 2019 code.
  r <- convert_codes(46030L, CLS_NIS_MUNICIPALITY_2025, CLS_NIS_MUNICIPALITY_2019,
                     master_data, allow_ambiguous = TRUE)
  prov_row <- r[code_to == 11056L]
  expect_equal(nrow(prov_row), 1L)
  expect_equal(prov_row$nature, "CHANGE_PROV")
})

# -- TN4: UNCHANGED and FUSION still correct -----------------------------------

test_that("UNCHANGED commune returns nature='UNCHANGED' and same code", {
  # 21004 = Auderghem (Brussels): code persists unchanged in 2025
  r <- convert_codes(21004L, CLS_NIS_MUNICIPALITY_2019, CLS_NIS_MUNICIPALITY_2025, master_data)
  expect_equal(r$nature,   "UNCHANGED")
  expect_equal(r$code_to,  21004L)
})

test_that("FUSION commune returns nature='FUSION'", {
  # 11007 was merged into 11002 in NIS 2025
  r <- convert_codes(11007L, CLS_NIS_MUNICIPALITY_2019, CLS_NIS_MUNICIPALITY_2025, master_data)
  expect_equal(r$nature, "FUSION")
})

# -- TN5: Batch conversion returns correct mix --------------------------------

test_that("batch temporal conversion carries the correct nature per code", {
  codes <- c(21004L, 44045L, 11056L, 73040L, 11007L)
  r     <- convert_codes(codes, CLS_NIS_MUNICIPALITY_2019, CLS_NIS_MUNICIPALITY_2025, master_data)

  expect_equal(r[code_from == 21004L, nature], "UNCHANGED")
  expect_equal(r[code_from == 44045L, nature], "CHANGE_DSTR")
  expect_equal(r[code_from == 11056L, nature], "CHANGE_PROV")
  expect_equal(r[code_from == 73040L, nature], "CHANGE_DSTR")
  expect_equal(r[code_from == 11007L, nature], "FUSION")
})

# -- TN6: Temporal nature values are within the declared set ------------------

test_that("all 2019->2025 temporal nature values are in {UNCHANGED,FUSION,CHANGE_DSTR,CHANGE_PROV}", {
  # Convert all NIS 2019 communes to 2025
  all_2019 <- unique(master_data$communes[nis_version == VER_2019, cd_commune])
  r        <- convert_codes(all_2019, CLS_NIS_MUNICIPALITY_2019, CLS_NIS_MUNICIPALITY_2025, master_data)
  valid    <- c("UNCHANGED", "FUSION", "CHANGE_DSTR", "CHANGE_PROV")
  bad      <- setdiff(unique(r$nature), valid)
  expect_equal(length(bad), 0L,
               info = paste("Unexpected nature values:", paste(bad, collapse = ", ")))
})

test_that("BEFORE_2019->2019 nature values are in {UNCHANGED, FUSION, CHANGE_DSTR}", {
  # BEFORE_2019->2019 carries the source NATURE column (not a hardcoded FUSION).
  # The change file holds 11 CHANGE_DSTR recodes (2019 Walloon arrondissement reform)
  # and 15 FUSION recodes (2019 Flemish municipal mergers); UNCHANGED is the
  # pass-through backbone. All 15 former "orphaned" fusion constituents (tracked in
  # FUSIONS_BEFORE_2019_TODO.md) are now mapped, so no NA is expected here.
  all_b19 <- unique(master_data$communes[nis_version == VER_BEFORE_2019, cd_commune])
  r       <- convert_codes(all_b19, CLS_NIS_MUNICIPALITY_BEFORE_2019, CLS_NIS_MUNICIPALITY_2019, master_data)
  valid   <- c("UNCHANGED", "FUSION", "CHANGE_DSTR")
  bad     <- setdiff(unique(r$nature), valid)
  expect_equal(length(bad), 0L,
               info = paste("Unexpected nature values:", paste(bad, collapse = ", ")))
  expect_false(anyNA(r$code_to))
})

test_that("BEFORE_2019->2019 preserves the source NATURE (11 CHANGE_DSTR + 15 FUSION recodes)", {
  # Regression guard for the hardcoded-FUSION bug: the 2019 arrondissement reform
  # recodes must surface as CHANGE_DSTR, not FUSION. Requires a rebuild to take
  # effect (nature is baked into the crosswalk snapshot).
  all_b19 <- unique(master_data$communes[nis_version == VER_BEFORE_2019, cd_commune])
  r       <- convert_codes(all_b19, CLS_NIS_MUNICIPALITY_BEFORE_2019, CLS_NIS_MUNICIPALITY_2019, master_data)
  expect_equal(sum(r$nature == "CHANGE_DSTR", na.rm = TRUE), 11L)
  expect_equal(sum(r$nature == "FUSION",      na.rm = TRUE), 15L)
})

test_that("no commune is orphaned across any adjacent NIS_VERSION pair", {
  # Regression guard for FUSIONS_BEFORE_2019_TODO.md: a commune present in
  # nis_version == from_ver must be either UNCHANGED (present in to_ver) or
  # covered by a nis_changes row -- never silently dropped (code_to = NA).
  # Generalized over every consecutive (from_ver, to_ver) pair so a future
  # NIS version (e.g. a 2031 refresh) is covered without a new hand-written test.
  version_pairs <- list(
    c(VER_BEFORE_2019, VER_2019),
    c(VER_2019,        VER_2025)
  )
  for (pair in version_pairs) {
    from_ver <- pair[1L]
    to_ver   <- pair[2L]
    m_from   <- unique(master_data$communes[nis_version == from_ver, cd_commune])
    m_to     <- unique(master_data$communes[nis_version == to_ver,   cd_commune])
    ch       <- master_data$nis_changes[from_version == from_ver, cd_refnis_old]
    orphaned <- setdiff(m_from, union(ch, m_to))
    expect_equal(length(orphaned), 0L,
                 label = sprintf("orphaned %s->%s codes", from_ver, to_ver),
                 info = paste("Orphaned codes:", paste(orphaned, collapse = ", ")))
  }
})

test_that("composed BEFORE_2019 -> 2025 conversion has no orphaned (NA) codes", {
  # The two hops above are each orphan-free, but composition (.compose_via_handlers)
  # is a separate code path -- guard it explicitly rather than assuming transitivity.
  all_b19 <- unique(master_data$communes[nis_version == VER_BEFORE_2019, cd_commune])
  r       <- convert_codes(all_b19, CLS_NIS_MUNICIPALITY_BEFORE_2019, CLS_NIS_MUNICIPALITY_2025, master_data)
  expect_false(anyNA(r$code_to))
})

# -- TN7: Nature counts match known totals ------------------------------------

test_that("CHANGE_DSTR count == 2 and CHANGE_PROV count == 1 in 2019->2025 crosswalk", {
  all_2019 <- unique(master_data$communes[nis_version == VER_2019, cd_commune])
  r        <- convert_codes(all_2019, CLS_NIS_MUNICIPALITY_2019, CLS_NIS_MUNICIPALITY_2025, master_data)
  expect_equal(sum(r$nature == "CHANGE_DSTR", na.rm = TRUE), 2L)
  expect_equal(sum(r$nature == "CHANGE_PROV", na.rm = TRUE), 1L)
})
