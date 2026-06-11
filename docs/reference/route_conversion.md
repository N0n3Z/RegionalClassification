# Route conversion to the appropriate handler

For a direct (from, to) edge present in md\$crosswalks, performs a
single table lookup via .crosswalk_hop(). Otherwise, composes single-hop
crosswalk lookups along the shortest path in the crosswalk graph
(.xw_path, built from md\$crosswalks so every hop is guaranteed to have
rows).

## Usage

``` r
route_conversion(input_dt, from, to, md)
```

## Arguments

- input_dt:

  data.table with code_from column

- from:

  Normalized source classification

- to:

  Normalized target classification

- md:

  Master data (output from build_master_table)

## Value

data.table with code_from, code_to, nature

## Details

Output codes are re-coerced to the canonical type of each node
(.node_coerce, R/00b_registry.R) after the lookup, preserving the
contract that NIS codes are integer and NUTS codes are character.
