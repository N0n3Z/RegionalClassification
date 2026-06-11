# Save master table and all auxiliary tables to processed directory

Saves every flat data.table in master_data as an RDS file, preserving
all R types exactly. Call this after build_master_table() to update the
pre-built snapshot used by load_master_data().

## Usage

``` r
save_master_tables(master_data, output_dir = get_processed_data_path())
```

## Arguments

- master_data:

  Output from build_master_table()

- output_dir:

  Path to output directory (default: inst/extdata/, via
  get_processed_data_path())

## Value

Invisible NULL (called for side effect)
