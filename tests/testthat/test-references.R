library(data.table)

# ==============================================================================
# Independent reference facts
# ==============================================================================
# Every expectation below comes from the official classifications (Statbel
# REFNIS and its 2019 / 2025 fusion lists, Eurostat NUTS 2021, bpost postal
# codes), not from this package's output. They are the oracle that the golden
# fixtures (which freeze the build output, bugs included) cannot be.
# ==============================================================================

ref_cv <- function(codes, from, to) {
  r <- suppressWarnings(convert_codes(codes, from, to, master_data, allow_ambiguous = TRUE))
  r <- r[, .(to = paste(sort(unique(code_to)), collapse = "+"),
             nature = paste(sort(unique(nature)), collapse = "+")), by = code_from]
  r[match(as.character(codes), code_from)]
}
ref_n <- function(id) master_data$entities[classification == id, .N]

test_that("official counts of NIS units", {
  expect_equal(ref_n(CLS_NIS_MUNICIPALITY_BEFORE_2019), 589L)
  expect_equal(ref_n(CLS_NIS_MUNICIPALITY_2019), 581L)   # after the 1 Jan 2019 fusions
  expect_equal(ref_n(CLS_NIS_MUNICIPALITY_2025), 565L)   # after the 1 Jan 2025 fusions
  for (v in c(VER_BEFORE_2019, VER_2019, VER_2025)) {
    expect_equal(ref_n(sprintf("NIS_DISTRICT_%s", v)), 43L, info = v)
    expect_equal(ref_n(sprintf("NIS_PROVINCE_%s", v)), 11L, info = v)  # 10 + Brussels (4000)
    expect_equal(ref_n(sprintf("NIS_REGION_%s", v)), 3L, info = v)
  }
})

test_that("official counts of NUTS 2021 units for Belgium", {
  expect_equal(ref_n(CLS_NUTS_REGION_2021), 3L)
  expect_equal(ref_n(CLS_NUTS_PROVINCE_2021), 11L)
  expect_equal(ref_n(CLS_NUTS_DISTRICT_2021), 44L)
  expect_equal(ref_n(CLS_NUTS_MUNICIPALITY_2021), 581L)  # LAU 2021 = NIS 2019 communes
})

test_that("NIS regions and provinces carry their REFNIS codes", {
  reg <- master_data$entities[classification == CLS_NIS_REGION_2019]
  expect_match(reg[code == "2000", label_nl], "VLAAMS", ignore.case = TRUE)
  expect_match(reg[code == "3000", label_nl], "WAALS", ignore.case = TRUE)
  expect_match(reg[code == "4000", label_nl], "BRUSSEL", ignore.case = TRUE)
  expect_identical(ref_cv(c("11002", "62063", "21004"), CLS_NIS_MUNICIPALITY_2019, CLS_NIS_REGION_2019)$to,
                   c("2000", "3000", "4000"))
  # Antwerpen, Vilvoorde (Vlaams-Brabant 20001), Braine-l'Alleud (Brabant wallon 20002),
  # Liege, Bruxelles (pseudo-province 4000)
  expect_identical(ref_cv(c("11002", "23088", "25014", "62063", "21004"),
                          CLS_NIS_MUNICIPALITY_2019, CLS_NIS_PROVINCE_2019)$to,
                   c("10000", "20001", "20002", "60000", "4000"))
})

test_that("NIS 2019 communes fall in their NUTS 2021 arrondissement", {
  expected <- c(
    "21004" = "BE100",  # Bruxelles
    "11002" = "BE211",  # Antwerpen
    "24062" = "BE242",  # Leuven
    "25072" = "BE310",  # Nivelles (Brabant wallon = one NUTS3)
    "31005" = "BE251",  # Brugge
    "44021" = "BE234",  # Gent
    "71022" = "BE224",  # Hasselt (Limburg NUTS3 renumbered in 2021)
    "51069" = "BE32A",  # Lessines -> arr. Ath (moved there in 2019)
    "57081" = "BE328",  # Tournai -> arr. Tournai-Mouscron
    "57096" = "BE328",  # Mouscron -> arr. Tournai-Mouscron
    "58001" = "BE329",  # La Louviere (arr. created in 2019)
    "62063" = "BE332",  # Liege
    "63079" = "BE335",  # Verviers (French-speaking part)
    "63023" = "BE336",  # Eupen (German-speaking Community)
    "92094" = "BE352"   # Namur
  )
  got <- ref_cv(names(expected), CLS_NIS_MUNICIPALITY_2019, CLS_NUTS_DISTRICT_2021)
  expect_identical(setNames(got$to, got$code_from), expected)
})

test_that("arrondissement Verviers straddles two NUTS3", {
  expect_identical(ref_cv("63000", CLS_NIS_DISTRICT_2019, CLS_NUTS_DISTRICT_2021)$to, "BE335+BE336")
})

test_that("1 January 2019 fusions and Hainaut recodings", {
  expected <- c(
    # fusions
    "12030" = "12041", "12034" = "12041",                    # Puurs-Sint-Amands
    "44001" = "44084", "44029" = "44084",                    # Aalter
    "44011" = "44083", "44049" = "44083",                    # Deinze
    "44036" = "44085", "44072" = "44085", "44080" = "44085", # Lievegem
    "45017" = "45068", "45057" = "45068",                    # Kruisem
    "71047" = "72042", "72040" = "72042",                    # Oudsbergen
    "72025" = "72043", "72029" = "72043",                    # Pelt
    # Hainaut: arr. Mouscron merged into Tournai-Mouscron, arr. La Louviere created
    "54007" = "57096", "54010" = "57097",                    # Mouscron, Comines-Warneton
    "55022" = "58001", "56011" = "58002", "56085" = "58003", "56087" = "58004",
    "55010" = "51067", "55039" = "51068", "55023" = "51069", # Enghien, Silly, Lessines -> Ath
    "52063" = "55085", "52043" = "55086"                     # Seneffe, Manage -> Soignies
  )
  got <- ref_cv(names(expected), CLS_NIS_MUNICIPALITY_BEFORE_2019, CLS_NIS_MUNICIPALITY_2019)
  expect_identical(setNames(got$to, got$code_from), expected)
  expect_identical(unique(got[to %in% c("12041", "44083", "44084", "44085", "45068", "72042", "72043"), nature]),
                   "FUSION")
  expect_identical(unique(got[code_from %in% c("54007", "55022", "52043"), nature]), "CHANGE_DSTR")
  names_2019 <- master_data$entities[classification == CLS_NIS_MUNICIPALITY_2019 &
                                     code %in% c("12041", "44085", "45068", "72042", "72043")]
  expect_setequal(names_2019$label_nl, c("Puurs-Sint-Amands", "Lievegem", "Kruisem", "Oudsbergen", "Pelt"))
})

test_that("1 January 2025 fusions", {
  expected <- c(
    "11002" = "11002", "11007" = "11002",                    # Antwerpen absorbs Borsbeek
    "46014" = "46029", "44045" = "46029",                    # Lokeren + Moerbeke
    "46003" = "46030", "46013" = "46030", "11056" = "46030", # Beveren-Kruibeke-Zwijndrecht
    "71022" = "71072", "73040" = "71072",                    # Hasselt + Kortessem
    "23023" = "23106", "23024" = "23106", "23032" = "23106", # Pajottegem
    "73083" = "73111", "73009" = "73111",                    # Tongeren-Borgloon
    "73006" = "73110", "73032" = "73110",                    # Bilzen-Hoeselt
    "44043" = "44088", "44040" = "44088",                    # Merelbeke-Melle
    "44048" = "44086", "44012" = "44086",                    # Nazareth-De Pinte
    "71069" = "71071", "71057" = "71071",                    # Tessenderlo-Ham
    "82003" = "82039", "82005" = "82039"                     # Bastogne + Bertogne
  )
  got <- ref_cv(names(expected), CLS_NIS_MUNICIPALITY_2019, CLS_NIS_MUNICIPALITY_2025)
  expect_identical(setNames(got$to, got$code_from), expected)
  # Zwijndrecht changes province (Antwerpen -> Oost-Vlaanderen), Moerbeke and
  # Kortessem change arrondissement.
  expect_identical(got[code_from == "11056", nature], "CHANGE_PROV")
  expect_identical(got[code_from %in% c("44045", "73040"), nature], c("CHANGE_DSTR", "CHANGE_DSTR"))
  names_2025 <- master_data$entities[classification == CLS_NIS_MUNICIPALITY_2025 &
                                     code %in% c("23106", "46030", "73111", "44088", "71071")]
  expect_setequal(names_2025$label_nl, c("Pajottegem", "Beveren-Kruibeke-Zwijndrecht",
                                         "Tongeren-Borgloon", "Merelbeke-Melle", "Tessenderlo-Ham"))
  # 581 - 565 = 16 codes disappear
  xw25 <- master_data$crosswalks[classification_from == CLS_NIS_MUNICIPALITY_2019 &
                                 classification_to == CLS_NIS_MUNICIPALITY_2025]
  expect_equal(uniqueN(xw25$code_from) - uniqueN(xw25$code_to), 16L)
})

test_that("postal codes map to their municipality", {
  p19 <- c("1000" = "21004", "2000" = "11002", "3500" = "71022", "4000" = "62063",
           "5000" = "92094", "7700" = "57096", "8000" = "31005", "9000" = "44021",
           "9160" = "46014", "1540" = "23032")
  got <- ref_cv(names(p19), CLS_POSTAL, CLS_NIS_MUNICIPALITY_2019)
  expect_identical(setNames(got$to, got$code_from), p19)
  # same postal codes, 2025 municipalities: Hasselt, Lokeren, Herne -> Pajottegem,
  # Zwijndrecht -> Beveren-Kruibeke-Zwijndrecht
  p25 <- c("3500" = "71072", "9160" = "46029", "1540" = "23106", "2070" = "46030")
  got <- ref_cv(names(p25), CLS_POSTAL, CLS_NIS_MUNICIPALITY_2025)
  expect_identical(setNames(got$to, got$code_from), p25)
})

test_that("labels of well-known units", {
  expect_identical(get_label("21004", CLS_NIS_MUNICIPALITY_2019, master_data)$label, "Bruxelles")
  expect_identical(get_label("21004", CLS_NIS_MUNICIPALITY_2019, master_data, lang = "nl")$label, "Brussel")
  expect_identical(get_label("62063", CLS_NIS_MUNICIPALITY_2019, master_data, lang = "nl")$label, "Luik")
  expect_identical(get_label("24062", CLS_NIS_MUNICIPALITY_2019, master_data)$label, "Louvain")
})
