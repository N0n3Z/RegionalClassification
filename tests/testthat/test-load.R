library(data.table)

# -- Test L1: structure retournee par load_master_data -------------------------
test_that("load_master_data returns a named list with expected tables", {
  expect_true(is.list(master_data))
  expect_equal(names(master_data), c("entities", "crosswalks"))
})

# -- Test L2: communes contient les 3 versions NIS -----------------------------
test_that("load_master_data communes has 2019, 2025, and BEFORE_2019 versions", {
  versions <- unique(wide_md$municipalities$version)
  expect_true("2019"        %in% versions)
  expect_true("2025"        %in% versions)
  expect_true("BEFORE_2019" %in% versions)
})

# -- Test L3: communes 2019 contient les colonnes attendues --------------------
test_that("communes 2019 has all required columns", {
  cols_required <- c("code_nis_municipality", "code_nis_district", "code_nis_province", "code_nis_region",
                     "code_nuts_district_2021", "version")
  comm19 <- wide_md$municipalities[version == VER_2019]
  expect_true(nrow(comm19) > 0L)
  expect_true(all(cols_required %in% names(comm19)))
})

# -- Test L4: postal table contient des donnees --------------------------------
test_that("postal table is non-empty with code_postal and code_nis_municipality", {
  expect_true(is.data.table(wide_md$postal))
  expect_true(nrow(wide_md$postal) > 0L)
  expect_true(all(c("code_postal", "code_nis_municipality") %in% names(wide_md$postal)))
})

# -- Test L5: nis_changes table est presente -----------------------------------
test_that("nis_changes table is non-empty", {
  expect_true(is.data.table(wide_md$nis_changes))
  expect_true(nrow(wide_md$nis_changes) > 0L)
})

# -- Test L6: erreur rcl_data_missing pour repertoire inexistant ---------------
test_that("load_master_data raises rcl_data_missing for non-existent dir", {
  expect_error(
    load_master_data(dir = "/tmp/nonexistent_dir_xyz_abc"),
    class = "rcl_data_missing"
  )
})

# -- Test L7: NIS 2019 a >= 500 communes (Belgique) ----------------------------
test_that("communes 2019 has at least 500 records (Belgian communes)", {
  comm19 <- wide_md$municipalities[version == VER_2019]
  expect_gte(nrow(comm19), 500L)
})

# -- Test L8: toutes les regions belges sont presentes -------------------------
test_that("communes 2019 contains all three Belgian regions", {
  regions <- unique(wide_md$municipalities[version == VER_2019, code_nis_region])
  expect_true(2000L %in% regions || "2000" %in% as.character(regions))  # Wallonie
  expect_true(3000L %in% regions || "3000" %in% as.character(regions))  # Flandre
  expect_true(4000L %in% regions || "4000" %in% as.character(regions))  # Bruxelles
})
