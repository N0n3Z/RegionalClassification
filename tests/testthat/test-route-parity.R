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
  expect_equal(r[code_from == 10000L]$code_to, 2000L)  # Anvers          -> Flemish
  expect_equal(r[code_from == 20001L]$code_to, 2000L)  # Vlaams-Brabant  -> Flemish
  expect_equal(r[code_from == 20002L]$code_to, 3000L)  # Brabant wallon  -> Walloon
  expect_equal(r[code_from == 4000L]$code_to,  4000L)  # Brussels pseudo -> Brussels
})

# -- POSTAL multi-hop now flows through the generic composer -------------------
test_that("POSTAL -> NUTS_DISTRICT_2027 still works after removing the POSTAL special case", {
  r <- convert_codes(c(1000L, 2000L), CLS_POSTAL, CLS_NUTS_DISTRICT_2027, master_data)
  expect_equal(nrow(r), 2L)
  expect_true(all(!is.na(r$code_to)))
})
