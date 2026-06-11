# Parse NIS BEFORE_2019 -\> NIS 2019 change table (optional file)

Parse NIS BEFORE_2019 -\> NIS 2019 change table (optional file)

## Usage

``` r
parse_refnis_change_before2019(
  change_dt,
  col_old = FILE_MAPPING$REFNIS_CHANGE_BEFORE2019$col_nis_old,
  col_new = FILE_MAPPING$REFNIS_CHANGE_BEFORE2019$col_nis_new
)
```

## Arguments

- change_dt:

  data.table from REFNIS_CHANGE_BEFORE2019.xlsx

- col_old:

  Name of old NIS code column

- col_new:

  Name of new NIS code column

## Value

data.table with cd_refnis_before2019 (integer) and cd_refnis_2019
(integer)
