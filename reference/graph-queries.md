# Graph-level node queries

`nodes()` returns all node names in alphabetical order.
`topological_sort()` returns the nodes of a DAG in topological order:
for every directed edge `u --> v`, `u` appears before `v`.
`exogenous_nodes()` returns the nodes with no parents (for a UG, the
isolated nodes).

## Usage

``` r
nodes(cg)

topological_sort(cg)

exogenous_nodes(cg, undirected_as_parents = FALSE)
```

## Arguments

- cg:

  A graph created with
  [`cgraph()`](https://bjarkehautop.github.io/CausalStructures/reference/cgraph.md).
  Supported classes vary by function:

  - `nodes()`: any class.

  - `topological_sort()`: DAG.

  - `exogenous_nodes()`: any class except PAG.

- undirected_as_parents:

  Only used for PDAG-family graphs. If `TRUE`, a node incident to any
  undirected edge is not considered exogenous.

## Value

Character vector of node names.

## Examples

``` r
if (julia_ready()) {
  dag <- cgraph(B %-->% A, A %-->% C)
  list(
    nodes = nodes(dag),
    topological_sort = topological_sort(dag),
    exogenous_nodes = exogenous_nodes(dag)
  )
}
#> $nodes
#> [1] "A" "B" "C"
#> 
#> $topological_sort
#> [1] "B" "A" "C"
#> 
#> $exogenous_nodes
#> [1] "B"
#> 

if (julia_ready()) {
  pdag <- cgraph(A %-->% B, B %---% C, class = "PDAG")
  list(
    exogenous_nodes = exogenous_nodes(pdag),
    exogenous_nodes_undirected_as_parents =
      exogenous_nodes(pdag, undirected_as_parents = TRUE)
  )
}
#> $exogenous_nodes
#> [1] "A" "C"
#> 
#> $exogenous_nodes_undirected_as_parents
#> [1] "A"
#> 
```
