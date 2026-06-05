library(data.table)

# Load the golden fixture (generated once by gen_golden() in helper-golden.R
# and committed).  The fixture captures (code_from, code_to, nature) for every
# directly-executable hop + a set of multi-hop pairs.
# In P0/P1 this is trivially green (same engine generated the fixture).
# In P2+, after .ROUTE_TABLE is replaced by .crosswalk_hop, this is the
# primary regression guard.

golden_path <- testthat::test_path("fixtures", "golden_crosswalks.rds")

if (!file.exists(golden_path)) {
  test_that("golden fixture is present", {
    skip(paste("golden_crosswalks.rds not found at", golden_path,
               "— run gen_golden() from helper-golden.R to create it."))
  })
} else {

  golden <- readRDS(golden_path)
  md     <- load_master_data()

  # --- Per-hop tests ---
  edge_keys <- unique(paste0(golden$per_edge$from_id, "__", golden$per_edge$to_id))

  for (key in edge_keys) {
    parts <- strsplit(key, "__", fixed = TRUE)[[1]]
    from  <- parts[1L]
    to    <- parts[2L]
    ref   <- golden$per_edge[from_id == from & to_id == to]

    local({
      .from <- from; .to <- to; .ref <- ref
      test_that(sprintf("golden: %s -> %s", .from, .to), {
        src <- unique(.ref$code_from)
        r   <- suppressWarnings(suppressMessages(
          convert_codes(src, .from, .to, md, allow_ambiguous = TRUE)
        ))
        # Compare (code_from, code_to, nature) as a set of concatenated keys
        r_key   <- paste(as.character(r$code_from),
                         as.character(r$code_to),
                         as.character(r$nature))
        ref_key <- paste(.ref$code_from, .ref$code_to, .ref$nature)
        expect_true(setequal(r_key, ref_key))
      })
    })
  }

  # --- Multi-hop tests ---
  mh_keys <- unique(paste0(golden$multihop$from_id, "__", golden$multihop$to_id))

  for (key in mh_keys) {
    parts <- strsplit(key, "__", fixed = TRUE)[[1]]
    from  <- parts[1L]
    to    <- parts[2L]
    ref   <- golden$multihop[from_id == from & to_id == to]

    local({
      .from <- from; .to <- to; .ref <- ref
      test_that(sprintf("golden multi-hop: %s -> %s", .from, .to), {
        src <- unique(.ref$code_from)
        r   <- suppressWarnings(suppressMessages(
          convert_codes(src, .from, .to, md, allow_ambiguous = TRUE)
        ))
        r_key   <- paste(as.character(r$code_from),
                         as.character(r$code_to),
                         as.character(r$nature))
        ref_key <- paste(.ref$code_from, .ref$code_to, .ref$nature)
        expect_true(setequal(r_key, ref_key))
      })
    })
  }

}
