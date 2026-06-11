# Load a single data file (xlsx, xls, or csv)

Load a single data file (xlsx, xls, or csv)

## Usage

``` r
load_single_file(filepath, sheet = NULL, filter_spec = NULL)
```

## Arguments

- filepath:

  Full path to file

- sheet:

  Sheet name for Excel files (NULL for default)

- filter_spec:

  List with 'column' and 'value' for filtering, or NULL

## Value

data.table
