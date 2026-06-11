# Execute the actual conversion between two classifications

Execute the actual conversion between two classifications

## Usage

``` r
execute_conversion(codes, from, to, master_data)
```

## Arguments

- codes:

  Vector of codes

- from:

  Source classification identifier

- to:

  Target classification identifier

- master_data:

  Output from build_master_table()

## Value

data.table with columns `code_from`, `code_to`, `nature` (see
[`convert_codes`](https://n0n3z.github.io/regionalclassification/reference/convert_codes.md)).
