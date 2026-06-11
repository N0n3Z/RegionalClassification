# Build a reference table of names and codes for a given classification

Phase 3: driven entirely by the registry (.node_reference_codes) instead
of a hardcoded switch over source-table columns. Any classification that
has at least one non-NA label (name_fr or name_nl) in the entities table
is now supported automatically. An abort is raised only when no labels
are available (e.g. NUTS2, NUTS1, NUTS_COUNTRY which carry no names).

## Usage

``` r
build_name_reference(target, md, language = "both")
```

## Arguments

- target:

  Normalized classification identifier

- md:

  Master data

- language:

  "fr", "nl", or "both"

## Value

data.table with ref_name, ref_code, ref_language
