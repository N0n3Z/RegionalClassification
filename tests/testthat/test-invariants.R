library(data.table)

# ==============================================================================
# Structural invariants of the long model (entities + crosswalks)
# ==============================================================================
# Unlike the golden fixtures, which freeze whatever the build produced, these
# tests state properties the data must have whatever its content. They loop
# over every classification pair present in `crosswalks`, so a new pair is
# covered without writing a new test. The NUTS 2016 codes once carried by the
# BEFORE_2019 rows would have failed "every code_to exists in entities".
# ==============================================================================

xw  <- master_data$crosswalks
ent <- master_data$entities
inv_pairs <- unique(xw[, .(classification_from, classification_to)])
pair_label <- function(f, t) paste(f, "->", t)

# Links whose code_to is legitimately NA: (classification_from, classification_to,
# code_from). Each entry must say why.
ALLOWED_NA_LINKS <- data.table(
  classification_from = "POSTAL", classification_to = "NIS_MUNICIPALITY_2025",
  # 1020 (Laeken) is not KEEP_UNIQUE in the 2025 postal file: it is no longer
  # attached to a single municipality. The POSTAL universe is the 2019 one.
  code_from = "1020"
)

# Observed cardinality of a set of links: "1:1", "N:1", "1:N" or "M:N".
observed_relation <- function(code_from, code_to) {
  multi_to   <- anyDuplicated(code_from) > 0L
  multi_from <- anyDuplicated(code_to) > 0L
  if (multi_to && multi_from) "M:N" else if (multi_to) "1:N"
  else if (multi_from) "N:1" else "1:1"
}
# A declared relation allows these observed ones.
RELATION_ALLOWS <- list(
  "1:1" = "1:1",
  "N:1" = c("N:1", "1:1"),
  "1:N" = c("1:N", "1:1"),
  "M:N" = c("M:N", "1:N", "N:1", "1:1")
)

links_of <- function(f, t) xw[classification_from == f & classification_to == t]
codes_of <- function(id) ent[classification == id, code]

# -- referential integrity -----------------------------------------------------

test_that("every crosswalk classification is a registry node", {
  ids <- unique(c(inv_pairs$classification_from, inv_pairs$classification_to))
  expect_length(setdiff(ids, names(CLASSIFICATION_NODES)), 0L)
  expect_length(setdiff(ent$classification, names(CLASSIFICATION_NODES)), 0L)
})

test_that("every code_from / code_to exists in entities", {
  for (i in seq_len(nrow(inv_pairs))) {
    f <- inv_pairs$classification_from[i]; t <- inv_pairs$classification_to[i]
    l <- links_of(f, t)
    unknown_from <- setdiff(l$code_from, codes_of(f))
    unknown_to   <- setdiff(na.omit(l$code_to), codes_of(t))
    expect_length(unknown_from, 0L)
    expect_length(unknown_to, 0L)
    if (length(unknown_from) + length(unknown_to) > 0L)
      message(pair_label(f, t), ": unknown codes ",
              paste(head(c(unknown_from, unknown_to), 5), collapse = ", "))
  }
})

test_that("every entity code has a link in each outgoing crosswalk", {
  for (i in seq_len(nrow(inv_pairs))) {
    f <- inv_pairs$classification_from[i]; t <- inv_pairs$classification_to[i]
    missing <- setdiff(codes_of(f), links_of(f, t)$code_from)
    expect_length(missing, 0L)
    if (length(missing)) message(pair_label(f, t), ": no link for ",
                                 paste(head(missing, 5), collapse = ", "))
  }
})

test_that("code_to is NA only for the documented links", {
  na_links <- xw[is.na(code_to), .(classification_from, classification_to, code_from)]
  unexpected <- fsetdiff(na_links, ALLOWED_NA_LINKS)
  expect_equal(nrow(unexpected), 0L)
  if (nrow(unexpected)) print(unexpected)
  # an allowlisted link that disappeared means the allowlist is stale
  expect_equal(nrow(fsetdiff(ALLOWED_NA_LINKS, na_links)), 0L)
})

test_that("no duplicate entities or crosswalk links", {
  expect_false(anyDuplicated(ent[, .(classification, code)]) > 0L)
  expect_false(anyDuplicated(
    xw[, .(classification_from, classification_to, code_from, code_to)]) > 0L)
})

# -- relations -----------------------------------------------------------------

test_that("every crosswalk pair declares a relation compatible with its links", {
  for (i in seq_len(nrow(inv_pairs))) {
    f <- inv_pairs$classification_from[i]; t <- inv_pairs$classification_to[i]
    l   <- links_of(f, t)
    rel <- unique(l$relation)
    expect_length(rel, 1L)
    expect_false(anyNA(rel), info = pair_label(f, t))
    if (length(rel) != 1L || is.na(rel)) next
    obs <- observed_relation(l[!is.na(code_to), code_from], l[!is.na(code_to), code_to])
    expect_true(obs %in% RELATION_ALLOWS[[rel]],
                info = sprintf("%s declared %s, observed %s", pair_label(f, t), rel, obs))
  }
})

test_that("crosswalk relations match the conversion graph edges", {
  for (e in CONVERSION_GRAPH_EDGES) {
    l <- links_of(e$from, e$to)
    if (nrow(l) == 0L) next
    expect_identical(unique(l$relation), e$relation, info = pair_label(e$from, e$to))
  }
})

test_that("NIS temporal links carry a nature, the others do not", {
  # Only the NIS change files (REFNIS_CHANGE*) provide a nature; a NUTS revision
  # (NUTS_DISTRICT_2021 -> NUTS_DISTRICT_2027) has none.
  natures <- c("UNCHANGED", "FUSION", "CHANGE_DSTR", "CHANGE_PROV")
  for (i in seq_len(nrow(inv_pairs))) {
    f <- inv_pairs$classification_from[i]; t <- inv_pairs$classification_to[i]
    nf <- CLASSIFICATION_NODES[[f]]; nt <- CLASSIFICATION_NODES[[t]]
    temporal <- nf$system == "NIS" && nt$system == "NIS" && nf$level == nt$level &&
                !identical(nf$version, nt$version)
    l <- links_of(f, t)[!is.na(code_to)]
    if (temporal) {
      expect_true(all(l$nature %in% natures), info = pair_label(f, t))
    } else {
      expect_true(all(is.na(l$nature)), info = pair_label(f, t))
    }
  }
})

# -- consistency between pairs ---------------------------------------------------

test_that("a direct link equals the composition through any intermediate node", {
  functional <- function(f, t) {
    l <- links_of(f, t)[!is.na(code_to)]
    nrow(l) > 0L && !anyDuplicated(l$code_from)
  }
  n_checked <- 0L
  for (i in seq_len(nrow(inv_pairs))) {
    a <- inv_pairs$classification_from[i]; c <- inv_pairs$classification_to[i]
    if (!functional(a, c)) next
    mids <- intersect(inv_pairs[classification_from == a, classification_to],
                      inv_pairs[classification_to == c, classification_from])
    for (b in mids) {
      if (!functional(a, b) || !functional(b, c)) next
      ab <- links_of(a, b)[!is.na(code_to), .(code_from, mid = code_to)]
      bc <- links_of(b, c)[!is.na(code_to), .(mid = code_from, via = code_to)]
      ac <- links_of(a, c)[!is.na(code_to), .(code_from, direct = code_to)]
      m  <- merge(merge(ab, bc, by = "mid"), ac, by = "code_from")
      bad <- m[via != direct]
      n_checked <- n_checked + 1L
      expect_equal(nrow(bad), 0L, info = paste(a, "->", b, "->", c))
      if (nrow(bad)) message(a, " -> ", b, " -> ", c, ": ",
                             paste(head(bad$code_from, 5), collapse = ", "))
    }
  }
  expect_gt(n_checked, 20L)   # the loop must actually exercise triples
})

test_that("a pair and its reverse hold the same links", {
  for (i in seq_len(nrow(inv_pairs))) {
    f <- inv_pairs$classification_from[i]; t <- inv_pairs$classification_to[i]
    if (f > t || nrow(links_of(t, f)) == 0L) next
    fwd <- links_of(f, t)[!is.na(code_to), .(a = code_from, b = code_to)]
    rev <- links_of(t, f)[!is.na(code_to), .(a = code_to, b = code_from)]
    expect_equal(nrow(fsetdiff(fwd, rev)), 0L, info = pair_label(f, t))
    expect_equal(nrow(fsetdiff(rev, fwd)), 0L, info = pair_label(t, f))
  }
})

# -- code formats and hierarchy rules ------------------------------------------

CODE_FORMATS <- list(
  NIS  = list(municipality = "^[1-9][0-9]{4}$", district = "^[1-9][0-9]000$",
              province = "^([1-9]0000|2000[12]|4000)$", region = "^[234]000$",
              country = "^1000$"),
  NUTS = list(municipality = "^[1-9][0-9]{4}$", district = "^BE[0-9][0-9A-Z]{2}$",
              province = "^BE[0-9][0-9A-Z]$", region = "^BE[0-9]$", country = "^BE$"),
  NBB  = list(district = "^[0-9]{2}$"),
  POSTAL = list(postal = "^[1-9][0-9]{3}$")
)

test_that("every entity code has the format of its classification", {
  for (id in unique(ent$classification)) {
    n   <- CLASSIFICATION_NODES[[id]]
    pat <- CODE_FORMATS[[n$system]][[n$level]]
    expect_false(is.null(pat), info = id)
    if (is.null(pat)) next
    bad <- grep(pat, codes_of(id), value = TRUE, invert = TRUE)
    expect_length(bad, 0L)
    if (length(bad)) message(id, ": ", paste(head(bad, 5), collapse = ", "))
  }
})

test_that("a NIS municipality belongs to the district of its first two digits", {
  for (v in c(VER_BEFORE_2019, VER_2019, VER_2025)) {
    l <- links_of(sprintf("NIS_MUNICIPALITY_%s", v), sprintf("NIS_DISTRICT_%s", v))
    expect_identical(l$code_to, paste0(substr(l$code_from, 1L, 2L), "000"), info = v)
  }
})

test_that("a NUTS code starts with the code of its parent", {
  for (i in seq_len(nrow(inv_pairs))) {
    f <- inv_pairs$classification_from[i]; t <- inv_pairs$classification_to[i]
    nf <- CLASSIFICATION_NODES[[f]]; nt <- CLASSIFICATION_NODES[[t]]
    if (nf$system != "NUTS" || nt$system != "NUTS" ||
        nf$level == "municipality" || nf$level == nt$level) next
    l <- links_of(f, t)[!is.na(code_to)]
    if (!all(nchar(l$code_to) < nchar(l$code_from))) next   # child -> parent only
    bad <- l[substr(code_from, 1L, nchar(code_to)) != code_to]
    expect_equal(nrow(bad), 0L, info = pair_label(f, t))
  }
})

test_that("labelled classifications have a label for every code", {
  for (id in unique(ent$classification)) {
    n <- CLASSIFICATION_NODES[[id]]
    e <- ent[classification == id]
    if (!is.na(n$label_fr_col)) expect_false(anyNA(e$label_fr), info = paste(id, "fr"))
    if (!is.na(n$label_nl_col)) expect_false(anyNA(e$label_nl), info = paste(id, "nl"))
  }
})
