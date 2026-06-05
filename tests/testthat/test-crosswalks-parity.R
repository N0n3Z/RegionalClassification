library(data.table)

# ==============================================================================
# test-crosswalks-parity.R  —  Phase 1 guard
# ==============================================================================
# For every directly-executable hop in .ROUTE_TABLE, asserts that the crosswalks
# table built during build_master_table() produces EXACTLY the same
# (code_from, code_to) pairs as the current runtime engine.
#
# This test MUST be green before Phase 2 (engine bascule).
# Temporal edges (NIS version transitions) also check `nature` equality.
# ==============================================================================

md <- load_master_data()

if (is.null(md$crosswalks)) {
  test_that("crosswalks table is present", {
    skip(paste0("master_data$crosswalks is NULL — run:\n",
                "  saveRDS(build_crosswalks(md$communes, md$postal, md$nis_changes),",
                " 'inst/extdata/crosswalks.rds')"))
  })
} else {

  keys <- names(nbbbenuts:::.ROUTE_TABLE)

  temporal_keys <- c(
    "NIS_COMMUNE_2019__NIS_COMMUNE_2025",
    "NIS_COMMUNE_2025__NIS_COMMUNE_2019",
    "NIS_COMMUNE_BEFORE_2019__NIS_COMMUNE_2019"
  )

  # --- Coverage assertion ---------------------------------------------------
  # A skip() inside the per-edge loop would silently pass if build_crosswalks
  # forgot to build an edge.  Guard against that with an explicit set check
  # for all non-BEFORE_2019 edges (BEFORE_2019 is optional / data-dependent).
  test_that("every non-BEFORE_2019 route key has crosswalk rows", {
    core    <- grep("BEFORE_2019", keys, value = TRUE, invert = TRUE)
    covered <- unique(md$crosswalks[, paste0(from_id, "__", to_id)])
    missing <- setdiff(core, covered)
    expect_true(
      length(missing) == 0L,
      label = paste("route keys missing from crosswalks:",
                    paste(missing, collapse = ", "))
    )
  })

  # --- Postal universe assumption -------------------------------------------
  # POSTAL->NIS_COMMUNE_2025 crosswalk is built on the p19 universe (the same
  # one .list_codes_for("POSTAL") uses).  This is valid only if every p25
  # postal code already appears in p19.  Verify that here so a future postal
  # remapping triggers a loud failure rather than a silent gap.
  test_that("all p25 postal codes are present in p19 (POSTAL universe assumption)", {
    p19_codes <- md$postal[nis_version == "2019", unique(cd_postal)]
    p25_codes <- md$postal[nis_version == "2025", unique(cd_postal)]
    new_in_p25 <- setdiff(p25_codes, p19_codes)
    expect_true(
      length(new_in_p25) == 0L,
      label = paste("p25 codes not in p19:", paste(new_in_p25, collapse = ", "))
    )
  })

  for (key in keys) {
    parts <- strsplit(key, "__", fixed = TRUE)[[1]]
    from  <- parts[1L]
    to    <- parts[2L]

    local({
      .from     <- from
      .to       <- to
      .temporal <- key %in% temporal_keys

      test_that(sprintf("crosswalks parity: %s -> %s", .from, .to), {
        xw <- md$crosswalks[from_id == .from & to_id == .to]

        # Skip edges for which no crosswalk data was built (optional data absent)
        if (nrow(xw) == 0L) {
          skip(sprintf("no crosswalk rows for %s -> %s (data not loaded?)", .from, .to))
        }

        src <- nbbbenuts:::.list_codes_for(.from, md)
        expect_gt(length(src), 0L)

        ref <- suppressWarnings(suppressMessages(
          convert_codes(src, .from, .to, md, allow_ambiguous = TRUE)
        ))

        xw_key  <- paste(xw$code_from, xw$code_to)
        ref_key <- paste(as.character(ref$code_from), as.character(ref$code_to))
        expect_true(
          setequal(xw_key, ref_key),
          label = sprintf("%s -> %s: crosswalk %d rows, engine %d rows",
                          .from, .to, nrow(xw), nrow(ref))
        )

        # For temporal edges, also verify nature agreement.
        # Only check rows where code_to is not NA: orphaned/unmapped codes
        # legitimately have code_to = NA and nature = NA in both crosswalk
        # and engine; merging on NA keys would produce phantom mismatches.
        if (.temporal) {
          xw_nat  <- xw[!is.na(code_to),
                        .(code_from, code_to, nature_xw = nature)]
          ref_nat <- ref[!is.na(as.character(code_to)),
                         .(code_from  = as.character(code_from),
                           code_to    = as.character(code_to),
                           nature_ref = nature)]
          merged <- merge(xw_nat, ref_nat, by = c("code_from", "code_to"), all = TRUE)
          expect_true(
            all(merged$nature_xw == merged$nature_ref, na.rm = FALSE),
            label = sprintf("%s -> %s: nature mismatch", .from, .to)
          )
        }
      })
    })
  }

}
