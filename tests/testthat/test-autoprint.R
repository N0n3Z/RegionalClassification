# Regression guard for the data.table auto-print gotcha (FAQ 2.23).
#
# When a function modifies a data.table by reference (`:=`, `set*()`) and then
# returns that same object, data.table sets an internal flag that suppresses the
# NEXT auto-print at the top level. A bare `convert_codes(...)` call would then
# echo nothing the first time. The fix is a trailing `[]` on the returned table,
# which resets that flag. These tests emulate what the REPL does on a top-level
# call (print the value if it is visible) and assert it produces output.

# Emulate the REPL's auto-print: print the value iff it is visible, honouring
# data.table's internal "just modified by reference" suppression flag.
autoprint_lines <- function(expr) {
  wv <- withVisible(expr)
  if (!wv$visible) return(character(0))
  utils::capture.output(print(wv$value))
}

test_that("convert_codes() auto-prints its result at the top level", {
  md <- load_master_data()
  out <- autoprint_lines(
    convert_codes(c(21004L, 11002L), "NIS_MUNICIPALITY_2019",
                  "NUTS_DISTRICT_2021", md)
  )
  expect_gt(length(out), 0L)
  expect_true(any(grepl("code_from", out)))
})

test_that("convert_dataset() auto-prints its result at the top level", {
  md <- load_master_data()

  # 1:1 branch
  out_11 <- autoprint_lines(
    convert_dataset(data.table::data.table(c = c(21004L, 11002L)), "c",
                    to = "NUTS_DISTRICT_2021", md,
                    from = "NIS_MUNICIPALITY_2019", verbose = FALSE)
  )
  expect_gt(length(out_11), 0L)

  # M:N branch (Verviers arrondissement splits across two NUTS3 districts)
  out_mn <- autoprint_lines(
    convert_dataset(data.table::data.table(arr = 63000L), "arr",
                    to = "NUTS_DISTRICT_2021", md,
                    from = "NIS_DISTRICT_2019", verbose = FALSE,
                    allow_ambiguous = TRUE)
  )
  expect_gt(length(out_mn), 0L)
})
