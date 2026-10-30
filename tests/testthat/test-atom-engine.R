library(data.table)

# Atom-based engine (R/12_atoms.R, docs/plans/engine-redesign.md). It is opt-in
# (options(nbbbenuts.engine = "atoms")) until it replaces the crosswalk engine;
# these tests pin that it reproduces every current conversion.

with_atoms <- function(expr) {
  old <- options(nbbbenuts.engine = "atoms"); on.exit(options(old), add = TRUE)
  force(expr)
}
with_crosswalks <- function(expr) {
  old <- options(nbbbenuts.engine = "crosswalks"); on.exit(options(old), add = TRUE)
  force(expr)
}

# Links on which the atom engine knowingly differs from the crosswalk engine.
ATOM_ENGINE_EXPECTED_DIFFS <- data.table(
  classification_from = "POSTAL", classification_to = "NIS_MUNICIPALITY_2025",
  code_from = "1020",
  # 1020 (Laeken) is not KEEP_UNIQUE in the 2025 postal file: the crosswalk
  # engine has no 2025 commune for it (NA); the atoms keep its 2019 commune
  # (21004 Bruxelles), as it already reaches the 2025 district and region.
  reason = "postal code without a 2025 commune in the source file"
)

test_that("the default engine is the atom engine (step 3)", {
  old <- options(nbbbenuts.engine = NULL); on.exit(options(old), add = TRUE)
  expect_identical(nbbbenuts:::.engine(), "atoms")
})

test_that("membership partitions the atoms in every classification", {
  mem <- nbbbenuts:::.atom_membership(master_data)
  atoms <- master_data$entities[classification == nbbbenuts:::.ATOM_ID, code]
  for (id in setdiff(names(CLASSIFICATION_NODES), CLS_POSTAL)) {
    m <- mem[classification == id]
    expect_setequal(unique(m$atom), atoms)                          # covers every atom
    expect_false(anyDuplicated(m$atom) > 0L, info = id)             # one unit per atom
    expect_setequal(unique(m$code), master_data$entities[classification == id, code])
  }
  # postal codes are finer than the atom: every postal code has >= 1 atom
  expect_setequal(unique(mem[classification == CLS_POSTAL, code]),
                  master_data$entities[classification == CLS_POSTAL, code])
})

test_that("the atom engine offers exactly the conversions of the crosswalk engine", {
  ids <- names(CLASSIFICATION_NODES)
  for (f in ids) for (t in ids) {
    expect_identical(nbbbenuts:::.atom_pair_allowed(f, t),
                     with_crosswalks(nbbbenuts:::.route_is_executable(f, t, master_data)),
                     info = paste(f, "->", t))
  }
})

test_that("the atom engine reproduces every conversion of the reference snapshot", {
  golden <- readRDS(testthat::test_path("fixtures", "golden_all_pairs.rds"))
  pairs  <- unique(golden[, .(classification_from, classification_to)])
  got <- with_atoms(rbindlist(lapply(seq_len(nrow(pairs)), function(i) {
    f <- pairs$classification_from[i]; t <- pairs$classification_to[i]
    src <- nbbbenuts:::.list_codes_for(f, master_data)
    r <- suppressWarnings(suppressMessages(
      convert_codes(src, f, t, master_data, allow_ambiguous = TRUE)))
    data.table(classification_from = f, classification_to = t,
               code_from = as.character(r$code_from), code_to = as.character(r$code_to),
               nature = r$nature)
  })))
  key <- c("classification_from", "classification_to", "code_from")
  skip_rows <- function(d) d[!ATOM_ENGINE_EXPECTED_DIFFS, on = key]
  cols <- c(key, "code_to", "nature")
  only_golden <- fsetdiff(unique(skip_rows(golden)[, ..cols]), unique(skip_rows(got)[, ..cols]))
  only_atoms  <- fsetdiff(unique(skip_rows(got)[, ..cols]), unique(skip_rows(golden)[, ..cols]))
  expect_equal(nrow(only_golden), 0L)
  expect_equal(nrow(only_atoms), 0L)
  if (nrow(only_golden) + nrow(only_atoms) > 0L) print(rbind(only_golden, only_atoms)[1:10])
  # the documented differences are real (the list is not stale)
  expect_identical(got[ATOM_ENGINE_EXPECTED_DIFFS, on = key, code_to], "21004")
})

test_that("the atom engine gates ambiguity like the crosswalk engine", {
  expect_error(with_atoms(convert_codes("63000", CLS_NIS_DISTRICT_2019, CLS_NUTS_DISTRICT_2021,
                                        master_data)), class = "rcl_ambiguous_conversion")
  expect_error(with_atoms(convert_codes("21004", CLS_NIS_MUNICIPALITY_2019,
                                        CLS_NIS_MUNICIPALITY_BEFORE_2019, master_data)),
               class = "rcl_no_route")
  r <- with_atoms(convert_codes("63000", CLS_NIS_DISTRICT_2019, CLS_NUTS_PROVINCE_2021, master_data))
  expect_identical(r$code_to, "BE33")
  expect_warning(with_atoms(convert_codes(c(NA, "99999"), CLS_NIS_MUNICIPALITY_2019,
                                          CLS_NUTS_DISTRICT_2021, master_data)),
                 class = "rcl_unmatched_codes")
})

# -- postal codes as atoms (design note, hypotheses H1 / H2) -------------------
# The real postal -> BEFORE_2019 commune correspondence is not shipped yet. This
# SYNTHETIC one is only a test device: each postal code goes to the first
# BEFORE_2019 commune of its 2019 commune (exact for the 574 2019 communes that
# are a single BEFORE_2019 commune, arbitrary for the 7 merged in 2019).
synthetic_postal_atoms <- function(md) {
  x  <- md$crosswalks
  p  <- x[classification_from == CLS_POSTAL & classification_to == CLS_NIS_MUNICIPALITY_2019 &
          !is.na(code_to), .(postal = code_from, m19 = code_to)]
  b  <- x[classification_from == CLS_NIS_MUNICIPALITY_BEFORE_2019 &
          classification_to == CLS_NIS_MUNICIPALITY_2019, .(before = code_from, m19 = code_to)]
  first <- b[order(before), .(before = before[1L]), by = m19]
  pb <- merge(p, first, by = "m19")
  md2 <- md
  md2$crosswalks <- rbind(md$crosswalks, data.table(
    classification_from = CLS_POSTAL, classification_to = CLS_NIS_MUNICIPALITY_BEFORE_2019,
    code_from = pb$postal, code_to = pb$before, relation = "N:1", nature = NA_character_))
  md2
}

test_that("postal atoms refine the BEFORE_2019 atoms without changing any unit link", {
  md2 <- synthetic_postal_atoms(master_data)
  expect_identical(nbbbenuts:::.atom_id(md2), CLS_POSTAL)
  expect_identical(nbbbenuts:::.atom_id(master_data), CLS_NIS_MUNICIPALITY_BEFORE_2019)
  mem <- nbbbenuts:::.atom_membership(md2)
  postal <- master_data$entities[classification == CLS_POSTAL, code]
  for (id in names(CLASSIFICATION_NODES)) {
    m <- mem[classification == id]
    expect_setequal(unique(m$atom), postal)                       # every postal code is an atom
    expect_false(anyDuplicated(m$atom) > 0L, info = id)           # partition
  }
  # refining the atoms leaves every conversion between units identical
  for (pair in list(c(CLS_NIS_MUNICIPALITY_2025, CLS_NIS_DISTRICT_2019),
                    c(CLS_NIS_DISTRICT_BEFORE_2019, CLS_NIS_DISTRICT_2019),
                    c(CLS_NUTS_DISTRICT_2027, CLS_NUTS_DISTRICT_2021),
                    c(CLS_NIS_PROVINCE_2025, CLS_NUTS_PROVINCE_2021))) {
    src <- master_data$entities[classification == pair[1], code]
    a <- with_atoms(suppressWarnings(convert_codes(src, pair[1], pair[2], master_data, allow_ambiguous = TRUE)))
    b <- with_atoms(suppressWarnings(convert_codes(src, pair[1], pair[2], md2, allow_ambiguous = TRUE)))
    expect_equal(nrow(fsetdiff(unique(a[, .(code_from, code_to)]), unique(b[, .(code_from, code_to)]))), 0L,
                 info = paste(pair, collapse = " -> "))
    expect_equal(nrow(fsetdiff(unique(b[, .(code_from, code_to)]), unique(a[, .(code_from, code_to)]))), 0L,
                 info = paste(pair, collapse = " -> "))
  }
  # a postal code now resolves its BEFORE_2019 district exactly (one district each)
  r <- with_atoms(convert_codes(postal, CLS_POSTAL, CLS_NIS_DISTRICT_BEFORE_2019, md2,
                                allow_ambiguous = TRUE))
  expect_false(anyDuplicated(r[!is.na(code_to), code_from]) > 0L)
})
