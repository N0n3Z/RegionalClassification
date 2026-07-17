library(data.table)

# ------------------------------------------------------------------------------
# Parity between the conversion GRAPH (check_conversion_path / get_conversion_matrix)
# and the EXECUTOR (route_conversion). Historically these were two independent
# sources of truth: check_conversion_path() did a generic multi-hop BFS on the
# graph, while route_conversion() only knew about hand-written single-hop handlers
# plus a POSTAL special case. A path could therefore validate as "simple" yet
# fail at execution (e.g. NUTS_DISTRICT_2021 -> NUTS_REGION_2021). The executor now composes
# single-hop handlers along a path in the handler graph, so every simple route
# the graph declares must be executable. This test guards that invariant.
# ------------------------------------------------------------------------------

test_that("every simple conversion in the matrix is executable (graph <-> executor parity)", {
  mtx    <- get_conversion_matrix()
  simple <- mtx[is_simple == TRUE & from != to]

  # Executability is now tested against the CROSSWALK graph (.xw_path via
  # .route_is_executable), i.e. what route_conversion() can actually run -- not
  # mere reachability in the declared CONVERSION_GRAPH_EDGES graph.
  ok  <- mapply(nbbbenuts:::.route_is_executable, simple$from, simple$to,
                MoreArgs = list(md = master_data))
  bad <- simple[!ok]

  expect_equal(
    nrow(bad), 0L,
    info = paste0(
      "Simple routes the executor cannot resolve: ",
      paste(bad$from, "->", bad$to, collapse = "; ")
    )
  )
})

# -- C1: the gate must never advertise a non-executable route as usable --------
# The declared graph auto-inverts every edge, so it is reachable-superset of what
# the executor materialises. convert_codes() now gates on real executability:
# a declared-but-non-executable pair must fail with a clear rcl_no_route dead-end
# BEFORE any "use allow_ambiguous = TRUE" advice, which would be contradictory
# (the executor would then die with rcl_no_route anyway).
test_that("get_conversion_matrix(md) exposes executability and simple => executable", {
  mtx <- get_conversion_matrix(master_data)
  expect_true("executable" %in% names(mtx))

  # Historical invariant: every simple route is executable.
  expect_equal(nrow(mtx[is_simple == TRUE & from != to & executable == FALSE]), 0L)

  # Such declared-but-non-executable pairs genuinely exist (auto-inverted
  # de-aggregation edges); the matrix must surface them, not hide them.
  expect_true(nrow(mtx[from != to & executable == FALSE]) > 0L)
})

test_that("declared-but-non-executable routes fail as rcl_no_route, not contradictory advice", {
  mtx      <- get_conversion_matrix(master_data)
  non_exec <- mtx[from != to & executable == FALSE]

  # Sample one target per source family to keep the test fast while covering the
  # different origin node types.
  probe <- non_exec[, .SD[1L], by = from]

  for (i in seq_len(nrow(probe))) {
    f <- probe$from[i]; t <- probe$to[i]
    src <- nbbbenuts:::.list_codes_for(f, master_data)
    if (length(src) == 0L) next
    # Even with allow_ambiguous = TRUE the route is a dead-end: it must raise
    # rcl_no_route (never rcl_ambiguous_conversion, and never reach execution).
    expect_error(
      convert_codes(src[1L], f, t, master_data, allow_ambiguous = TRUE),
      class = "rcl_no_route",
      info = sprintf("%s -> %s must be a clean rcl_no_route dead-end", f, t)
    )
  }
})

# -- C2: .xw_path is simple-first (deterministic, perimeter-preserving) --------
test_that(".xw_path prefers a fully-simple route over one crossing an overlap edge", {
  # POSTAL -> NUTS_DISTRICT_2021 must route through NIS_MUNICIPALITY_2019 (all
  # N:1) rather than NIS_MUNICIPALITY_2025 (whose 1:N fused-commune edge would
  # fan out / drop the 3 cross-NUTS3 communes). Previously this was correct only
  # by crosswalk insertion order; now it is guaranteed by construction.
  p <- nbbbenuts:::.xw_path("POSTAL", "NUTS_DISTRICT_2021", master_data)
  expect_false(is.null(p))
  expect_false("NIS_MUNICIPALITY_2025" %in% p)

  # And the conversion itself stays exact (no NA) for a fused-commune postal code.
  r <- convert_codes(c(1000L, 2000L), CLS_POSTAL, CLS_NUTS_DISTRICT_2021, master_data)
  expect_true(all(!is.na(r$code_to)))
})

# -- Multi-hop NUTS aggregation: previously raised rcl_no_route ----------------
test_that("NUTS_DISTRICT_2021 -> NUTS_REGION_2021 is executable and matches manual chaining", {
  r_multi <- convert_codes("BE211", CLS_NUTS_DISTRICT_2021, CLS_NUTS_REGION_2021, master_data)
  expect_equal(nrow(r_multi), 1L)
  expect_false(is.na(r_multi$code_to))

  # Composing through the executor must equal chaining the single hops by hand.
  r_n2    <- convert_codes("BE211", CLS_NUTS_DISTRICT_2021, CLS_NUTS_PROVINCE_2021, master_data)
  r_chain <- convert_codes(r_n2$code_to, CLS_NUTS_PROVINCE_2021, CLS_NUTS_REGION_2021, master_data)
  expect_equal(r_multi$code_to, r_chain$code_to)
})

test_that("NUTS_DISTRICT_2021 -> NUTS_COUNTRY aggregates all the way to country level", {
  r <- convert_codes(c("BE211", "BE100", "BE335"), CLS_NUTS_DISTRICT_2021, CLS_NUTS_COUNTRY, master_data)
  expect_equal(nrow(r), 3L)
  expect_true(all(r$code_to == "BE"))
})

# -- Province -> region: N:1 nesting (Brabant split since 1995) ----------------
test_that("NIS_PROVINCE_2019 -> NIS_REGION_2019 is a clean N:1 nesting", {
  # Each province nests in exactly one region, so NO allow_ambiguous is needed.
  # The former unified Brabant province (20000) no longer exists: it is split
  # into Vlaams-Brabant (20001) and Brabant wallon (20002); Brussels uses a
  # pseudo-province (4000) equal to its region code.
  r <- convert_codes(c(10000L, 20001L, 20002L, 4000L),
                     CLS_NIS_PROVINCE_2019, CLS_NIS_REGION_2019, master_data)
  expect_equal(nrow(r), 4L)
  expect_equal(r[code_from == "10000"]$code_to, "2000")  # Anvers          -> Flemish
  expect_equal(r[code_from == "20001"]$code_to, "2000")  # Vlaams-Brabant  -> Flemish
  expect_equal(r[code_from == "20002"]$code_to, "3000")  # Brabant wallon  -> Walloon
  expect_equal(r[code_from == "4000"]$code_to,  "4000")  # Brussels pseudo -> Brussels
})

# -- POSTAL multi-hop now flows through the generic composer -------------------
test_that("POSTAL -> NUTS_DISTRICT_2027 still works after removing the POSTAL special case", {
  r <- convert_codes(c(1000L, 2000L), CLS_POSTAL, CLS_NUTS_DISTRICT_2027, master_data)
  expect_equal(nrow(r), 2L)
  expect_true(all(!is.na(r$code_to)))
})

# -- M2: data-aware gate -- re-merging aggregations don't need allow_ambiguous --
test_that("aggregations that re-merge through an overlap edge are effectively simple", {
  # arrondissement -> NUTS province/region/country: the path crosses the Verviers
  # 1:N edge, but both NUTS3 (BE335/BE336) nest in one NUTS2 (BE33), so every
  # source yields exactly one target. These must convert WITHOUT allow_ambiguous.
  r1 <- convert_codes(63000L, CLS_NIS_DISTRICT_2019, CLS_NUTS_PROVINCE_2021, master_data)
  expect_equal(nrow(r1), 1L)
  expect_equal(r1$code_to, "BE33")

  r2 <- convert_codes(63000L, CLS_NIS_DISTRICT_2019, CLS_NUTS_COUNTRY, master_data)
  expect_equal(r2$code_to, "BE")

  # check_conversion_path(md) reports effectively_simple TRUE though is_simple FALSE.
  pc <- check_conversion_path(CLS_NIS_DISTRICT_2019, CLS_NUTS_PROVINCE_2021, master_data)
  expect_false(pc$is_simple)              # topological: path crosses an overlap edge
  expect_true(pc$effectively_simple)      # data-aware: re-merges to one target
})

test_that("genuine 1:N routes stay blocked without allow_ambiguous (data-aware)", {
  # Verviers -> NUTS3 genuinely fans out (BE335 != BE336): still ambiguous.
  expect_error(
    convert_codes(63000L, CLS_NIS_DISTRICT_2019, CLS_NUTS_DISTRICT_2021, master_data),
    class = "rcl_ambiguous_conversion"
  )
  pc <- check_conversion_path(CLS_NIS_DISTRICT_2019, CLS_NUTS_DISTRICT_2021, master_data)
  expect_false(pc$effectively_simple)
})

test_that("get_conversion_matrix(md) exposes effectively_simple", {
  mtx <- get_conversion_matrix(master_data)
  expect_true("effectively_simple" %in% names(mtx))
  # Every topologically simple route is also effectively simple.
  expect_equal(nrow(mtx[is_simple == TRUE & effectively_simple == FALSE]), 0L)
  # At least one route is effectively-but-not-topologically simple (the M2 wins).
  expect_true(nrow(mtx[is_simple == FALSE & effectively_simple == TRUE & from != to]) > 0L)
})
