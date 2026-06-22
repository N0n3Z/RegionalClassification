# Match entity names to classification codes using fuzzy matching

Supports matching commune names, postal code names, and arrondissement
names.

## Usage

``` r
fuzzy_match_names(
  names,
  target_classification,
  master_data,
  max_dist = 0.1,
  method = "jw",
  language = "both"
)
```

## Arguments

- names:

  Character vector of names to match

- target_classification:

  Target classification to match against. One of:
  "NIS_MUNICIPALITY_2019", "NIS_MUNICIPALITY_2025", "POSTAL",
  "NIS_DISTRICT_2019", "NIS_DISTRICT_2025", "NUTS_DISTRICT_2021"

- master_data:

  Output from build_master_table()

- max_dist:

  Maximum string distance for fuzzy matching (default 0.1 = 10%)

- method:

  Matching method: "osa" (default), "lv", "dl", "hamming", "lcs",
  "qgram", "cosine", "jaccard", "jw", "soundex"

- language:

  Preferred language for matching: "fr", "nl", or "both" (default)

## Value

data.table with input_name, matched_name, matched_code, distance,
language

## Examples

``` r
# \donttest{
  master_data <- load_master_data()
#> Master data loaded from 'C:/Users/Dell/AppData/Local/Temp/RtmpMFZPCn/temp_libpath168c5fac3201/nbbbenuts/extdata': 581 communes NIS 2019, 565 NIS 2025, 589 NIS BEFORE_2019

  # Match misspelled commune names
  fuzzy_match_names(c("Bruxeles", "Antwerpn", "Liege"),
                    "NIS_MUNICIPALITY_2019", master_data)
#>    input_name matched_name matched_code   distance language is_confident
#>        <char>       <char>       <char>      <num>   <char>       <lgcl>
#> 1:   Bruxeles    Bruxelles        21004 0.03703704       fr         TRUE
#> 2:   Antwerpn    Antwerpen        11002 0.03703704       nl         TRUE
#> 3:      Liege        Liège        62063 0.00000000       fr         TRUE

  # Match with looser threshold, prefer French names
  fuzzy_match_names(c("Bxl", "Anv"), "NIS_MUNICIPALITY_2019", master_data,
                    max_dist = 0.5, language = "fr")
#>    input_name matched_name matched_code  distance language is_confident
#>        <char>       <char>       <char>     <num>   <char>       <lgcl>
#> 1:        Bxl    Bruxelles        21004 0.2222222       fr         TRUE
#> 2:        Anv       Anvers        11002 0.1666667       fr         TRUE
# }
```
