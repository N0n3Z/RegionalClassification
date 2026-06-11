# Build a commune-level table with full NIS hierarchy for a given version

Build a commune-level table with full NIS hierarchy for a given version

## Usage

``` r
build_nis_commune_table(nis_parsed, version)
```

## Arguments

- nis_parsed:

  Output from parse_refnis_hierarchy()

- version:

  "2019" or "2025"

## Value

data.table with commune info and parent codes
