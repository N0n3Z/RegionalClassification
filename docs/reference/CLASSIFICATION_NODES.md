# Classification node registry

Named list with one entry per valid classification identifier (the 23
nodes that also appear in \`VALID_CLASSIFICATIONS\`). Each entry
carries:

## Usage

``` r
CLASSIFICATION_NODES
```

## Details

- system:

  One of \`"NIS"\`, \`"NUTS"\`, \`"POSTAL"\`, \`"NBB"\`.

- level:

  Granularity within the system (e.g. \`"municipality"\`,
  \`"district"\`, \`"province"\`, \`"country"\`).

- version:

  Classification version string, or \`NA_character\_\` when not
  versioned (POSTAL, NUTS_COUNTRY).

- code_type:

  Physical storage type: \`"integer"\` or \`"character"\`.

- source_table:

  Which master table holds the codes: \`"communes"\` or \`"postal"\`.

- version_filter:

  The \`nis_version\` value used to slice the source table.

- code_col:

  Column name of the code in the source table.

- label_fr_col:

  Column name of the French label, or \`NA_character\_\` when
  unavailable.

- label_nl_col:

  Column name of the Dutch label, or \`NA_character\_\` when
  unavailable.

- distinct:

  \`TRUE\` when the reference set requires \`unique(na.omit(...))\`
  (aggregated levels); \`FALSE\` for base-level entities where every row
  is already a distinct code.

- detectable:

  \`TRUE\` for classifications included in the
  \`detect_classification()\` integer matching loop.

- aggregates:

  Character vector of the node id(s) this node is the direct aggregation
  of (the finer level it groups). \`character(0)\` for base/leaf levels.
  The aggregation graph is a DAG, not a tree: an arrondissement is
  aggregated by BOTH a province and a region, and \`NUTS_COUNTRY\`
  aggregates both \`NUTS_REGION_2021\` and \`NUTS_REGION_2027\`.
  Province -\> region is deliberately NOT an aggregation (province 20000
  Brabant spans 3 regions); a region aggregates arrondissements
  directly. Used by \`nomenclature_children()\` /
  \`nomenclature_parents()\` and validated against the conversion graph.
