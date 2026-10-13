library(data.table)

# wide_view() must rebuild, from the long model alone, the wide tables that
# nbbbenuts 2.x persisted. fixtures/golden_wide.rds holds those tables as
# shipped by the 2.0.0 snapshot (after the BEFORE_2019 NUTS fix).

golden_wide <- readRDS(testthat::test_path("fixtures", "golden_wide.rds"))

wide_keys <- list(
  municipalities = c("version", "code_nis_municipality"),
  postal         = c("version", "code_postal", "code_nis_municipality"),
  nis_changes    = c("version_from", "code_from", "code_to")
)

for (tbl in c("municipalities", "nis_changes")) {
  local({
    .tbl <- tbl
    test_that(sprintf("wide_view('%s') reproduces the 2.x table", .tbl), {
      ref <- setorderv(copy(golden_wide[[.tbl]]), wide_keys[[.tbl]])
      expect_identical(wide_view(master_data, .tbl), ref)
    })
  })
}

test_that("wide_view('postal') reproduces the 2.x codes", {
  ref <- setorderv(copy(golden_wide$postal), wide_keys$postal)
  got <- wide_view(master_data, "postal")
  expect_identical(names(got), names(ref))
  expect_identical(got[, !c("label_postal_fr", "label_postal_nl")],
                   ref[, !c("label_postal_fr", "label_postal_nl")])
})

test_that("wide_view filters on version", {
  w <- wide_view(master_data, version = VER_2025)
  expect_identical(unique(w$version), VER_2025)
  expect_equal(nrow(w), nrow(master_data$entities[classification == CLS_NIS_MUNICIPALITY_2025]))
  nc <- wide_view(master_data, "nis_changes", version = VER_BEFORE_2019)
  expect_identical(unique(nc$version_from), VER_BEFORE_2019)
})

test_that("wide_view rejects an unknown version", {
  expect_error(wide_view(master_data, "postal", version = VER_BEFORE_2019),
               class = "rcl_invalid_input")
})
