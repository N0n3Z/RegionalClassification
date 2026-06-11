# Build the master classification table from all loaded data

Creates a unified table structure with three main data.tables:
`communes` (all NIS versions), `postal` (both postal mappings), and
`nis_changes` (all NIS version transitions).

## Usage

``` r
build_master_table(raw_data)
```

## Arguments

- raw_data:

  Named list of data.tables from load_all_raw_data()

## Value

list with three unified flat tables plus build-time hierarchy
intermediates
