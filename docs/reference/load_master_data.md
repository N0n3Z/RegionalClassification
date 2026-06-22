# Load the pre-built master table from bundled RDS files

This is the default and fast way to initialise the package. No raw
source files are required. All R types (integer, character, etc.) are
preserved exactly as serialised by save_master_tables().

## Usage

``` r
load_master_data(dir = .get_prebuilt_dir())
```

## Arguments

- dir:

  Path to the directory containing the RDS files. Defaults to the
  package extdata directory.

## Value

Named list identical in structure to the output of build_master_table().
The four intermediate hierarchy lists are set to NULL as they are not
needed at runtime.

## Examples

``` r
# \donttest{
  master_data <- load_master_data()
#> Master data loaded from 'C:/Users/Dell/AppData/Local/Temp/Rtmp6rbXw4/temp_libpath26b420df5361/nbbbenuts/extdata': 581 communes NIS 2019, 565 NIS 2025, 589 NIS BEFORE_2019
  # master_data now contains all lookup tables, ready for convert_codes() etc.
# }
```
