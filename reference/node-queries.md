# Node-set queries

`parents()` and `children()` are the nodes directly connected to `node`
by a directed edge. `ancestors()` and `descendants()` are all nodes from
which (respectively, to which) `node` is reachable by following directed
edges. `spouses()` are the nodes connected to `node` by a bidirected
edge (`node <-> spouse`).

## Usage

``` r
parents(cg, node)

children(cg, node)

ancestors(cg, node, open = getOption("CausalStructures.open", TRUE))

descendants(cg, node, open = getOption("CausalStructures.open", TRUE))

spouses(cg, node)
```

## Arguments

- cg:

  A graph created with
  [`cgraph()`](https://bjarkehautop.github.io/CausalStructures/reference/cgraph.md).
  Supported classes vary by function:

  - `parents()`, `children()`: any class except UG.

  - `ancestors()`, `descendants()`: DAG, PDAG-family (PDAG, CPDAG,
    MPDAG), ADMG, or AG-family (AG, MAG).

  - `spouses()`: ADMG, AG-family (AG, MAG), or PAG.

- node:

  Node name.

- open:

  If `TRUE` (default, from the `CausalStructures.open` option), exclude
  `node` itself from the result; if `FALSE`, include it.

## Value

Sorted character vector of node names.

## Details

See
[`neighbors()`](https://bjarkehautop.github.io/CausalStructures/reference/neighbors.md),
[`markov_blanket()`](https://bjarkehautop.github.io/CausalStructures/reference/markov_blanket.md),
and
[possible-queries](https://bjarkehautop.github.io/CausalStructures/reference/possible-queries.md)
for the remaining node-set queries, which take extra arguments.

## Examples

``` r
if (julia_ready()) {
  dag <- cgraph(A %-->% X + Y, X %-->% M %-->% Y)
  list(
    parents = parents(dag, "M"),
    children = children(dag, "X"),
    ancestors = ancestors(dag, "Y"),
    descendants = descendants(dag, "X"),
    descendants_closed = descendants(dag, "X", open = FALSE)
  )
}
#> $parents
#> [1] "X"
#> 
#> $children
#> [1] "M"
#> 
#> $ancestors
#> [1] "A" "M" "X"
#> 
#> $descendants
#> [1] "M" "Y"
#> 
#> $descendants_closed
#> [1] "M" "X" "Y"
#> 
```
