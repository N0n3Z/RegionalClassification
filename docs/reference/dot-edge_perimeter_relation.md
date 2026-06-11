# Classify the perimeter semantics of a single conversion edge

Returns a string describing whether the edge preserves, aggregates, or
crosses spatial perimeters:

- temporal:

  Same system, both nodes have explicit versions that differ. Boundaries
  may change edition-to-edition but no cross-system split occurs.

- identity:

  1:1 edge, same or different system, same effective territory.

- nesting:

  N:1 edge – many fine units aggregate into one coarser unit. The source
  perimeter is fully contained in the target.

- overlap:

  1:N or M:N edge – a source unit straddles multiple target units, so
  the source perimeter is *not* contained in any single target unit.
  This is the only category that breaks perimeter preservation.

## Usage

``` r
.edge_perimeter_relation(edge)
```

## Arguments

- edge:

  One element of `CONVERSION_GRAPH_EDGES` (or a reverse edge built by
  [`build_conversion_graph()`](https://n0n3z.github.io/regionalclassification/reference/build_conversion_graph.md)).

## Value

A length-1 character string: one of `"temporal"`, `"identity"`,
`"nesting"`, `"overlap"`.
