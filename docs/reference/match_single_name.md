# Match a single name against a reference table

Match a single name against a reference table

## Usage

``` r
match_single_name(name, ref, max_dist = 0.1, method = "jw")
```

## Arguments

- name:

  Input name to match

- ref:

  Reference data.table from build_name_reference()

- max_dist:

  Maximum relative distance

- method:

  String distance method

## Value

data.table with match results
