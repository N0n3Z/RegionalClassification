# Backfill NUTS 2021 columns onto NIS 2025 communes (build-time only)

Derives cd_nuts3, cd_nuts2, cd_nuts1, cd_nuts0, cd_nuts_lau, and
cd_arr_internal for NIS 2025 communes from the NIS 2019 master: -
Unchanged communes (same code in 2019 and 2025): copy directly. -
Changed communes (in nis_changes\[from_version=="2019"\]): collect the
NUTS_DISTRICT_2021 of all constituent 2019 communes and assign it only
if all constituents share the same NUTS3; else NA +
rcl_ambiguous_backfill warning. cd_nuts_lau stays NA for fusions (LAU is
a 1:1 commune identifier and is undefined after a merge).

## Usage

``` r
add_nuts2021_columns_2025(master_2025, master_2019, nis_changes)
```

## Arguments

- master_2025:

  data.table for NIS 2025 communes (from build_master_table)

- master_2019:

  data.table for NIS 2019 communes (fully enriched)

- nis_changes:

  Raw output from
  [`parse_nis_changes()`](https://n0n3z.github.io/regionalclassification/reference/parse_nis_changes.md)
  – must have at least `cd_refnis_old` and `cd_refnis_new` columns. The
  `from_version` and `nature` columns are added later (step 8 of
  `build_master_table`) and must NOT be present yet.

## Value

data.table master_2025 with NUTS 2021 columns added in-place. Note:
`cd_nuts2`, `cd_nuts1`, and `cd_nuts0` may be non-`NA` for communes
where `cd_nuts3` is `NA` (cross-NUTS3 fusions), because NUTS2/1/0 are
coarser and all constituent 2019 communes may agree on the broader
region even when their NUTS3 assignments differ.

## Details

The 2025 master must already carry cd_nuts3_2027 etc. (added from the
NIS 2025 NUTS 2027 source file during the 2025 master build step).
