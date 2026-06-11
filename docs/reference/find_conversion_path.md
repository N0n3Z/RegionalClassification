# Find best conversion path using two-pass BFS

First tries to find a path using only simple edges (1:1 and N:1). If no
simple path exists, finds the shortest path using all edges.

## Usage

``` r
find_conversion_path(from, to, graph)
```

## Arguments

- from:

  Starting node

- to:

  Target node

- graph:

  Adjacency list from build_conversion_graph()

## Value

list with path, relations, edges_used, or NULL if no path
