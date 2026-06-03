library(data.table)

# ──────────────────────────────────────────────────────────────────────────────
# Parity between the conversion GRAPH (check_conversion_path / get_conversion_matrix)
# and the EXECUTOR (route_conversion). Historically these were two independent
# sources of truth: check_conversion_path() did a generic multi-hop BFS on the
# graph, while route_conversion() only knew about hand-written single-hop handlers
# plus a POSTAL special case. A path could therefore validate as "simple" yet
# fail at execution (e.g. NUTS3_2021 -> NUTS1_2021). The executor now composes
# single-hop handlers along a path in the handler graph, so every simple route
# the graph declares must be executable. This test guards that invariant.
# ──────────────────────────────────────────────────────────────────────────────

test_that("every simple conversion in the matrix is executable (graph <-> executor parity)", {
  mtx    <- get_conversion_matrix()
  simple <- mtx[is_simple == TRUE & from != to]

  ok  <- mapply(nbbbenuts:::.route_is_executable, simple$from, simple$to)
  bad <- simple[!ok]

  expect_equal(
    nrow(bad), 0L,
    info = paste0(
      "Simple routes the executor cannot resolve: ",
      paste(bad$from, "->", bad$to, collapse = "; ")
    )
  )
})

# ── Multi-hop NUTS aggregation: previously raised rcl_no_route ────────────────
test_that("NUTS3_2021 -> NUTS1_2021 is executable and matches manual chaining", {
  r_multi <- convert_codes("BE211", "NUTS3_2021", "NUTS1_2021", master_data)
  expect_equal(nrow(r_multi), 1L)
  expect_false(is.na(r_multi$code_to))

  # Composing through the executor must equal chaining the single hops by hand.
  r_n2    <- convert_codes("BE211", "NUTS3_2021", "NUTS2_2021", master_data)
  r_chain <- convert_codes(r_n2$code_to, "NUTS2_2021", "NUTS1_2021", master_data)
  expect_equal(r_multi$code_to, r_chain$code_to)
})

test_that("NUTS3_2021 -> NUTS0 aggregates all the way to country level", {
  r <- convert_codes(c("BE211", "BE100", "BE335"), "NUTS3_2021", "NUTS0", master_data)
  expect_equal(nrow(r), 3L)
  expect_true(all(r$code_to == "BE"))
})

# ── Province -> region: M:N (Brabant spans 3 regions), requires allow_ambiguous ─
test_that("NIS_PROVINCE_2019 -> NIS_REGION_2019 is M:N (Brabant ambiguity)", {
  # Non-Brabant province: 1 row, correct region, but requires allow_ambiguous
  # because the graph declares province->region as M:N.
  r <- convert_codes(10000L, "NIS_PROVINCE_2019", "NIS_REGION_2019", master_data,
                     allow_ambiguous = TRUE)
  expect_equal(nrow(r), 1L)
  expect_equal(r$code_to, 2000L)

  # Brabant (20000) correctly returns 3 rows: Brussels, Flemish, Walloon
  r2 <- convert_codes(20000L, "NIS_PROVINCE_2019", "NIS_REGION_2019", master_data,
                      allow_ambiguous = TRUE)
  expect_equal(nrow(r2), 3L)
  expect_true(all(c(2000L, 3000L, 4000L) %in% r2$code_to))

  # Without allow_ambiguous: rcl_ambiguous_conversion
  expect_error(
    convert_codes(10000L, "NIS_PROVINCE_2019", "NIS_REGION_2019", master_data),
    class = "rcl_ambiguous_conversion"
  )
})

# ── POSTAL multi-hop now flows through the generic composer ───────────────────
test_that("POSTAL -> NUTS3_2027 still works after removing the POSTAL special case", {
  r <- convert_codes(c(1000L, 2000L), "POSTAL", "NUTS3_2027", master_data)
  expect_equal(nrow(r), 2L)
  expect_true(all(!is.na(r$code_to)))
})
