# Make nodes exogenous

Returns a copy of `cg` with each node in `nodes` made exogenous: its
incoming edges are removed, and its parents are connected directly to
its children to preserve reachability.

## Usage

``` r
exogenize(cg, nodes)
```

## Arguments

- cg:

  A DAG created with
  [`cgraph()`](https://bjarkehautop.github.io/CausalStructures/reference/cgraph.md).

- nodes:

  Character vector of node names to exogenize.

## Value

A Julia proxy object representing the resulting DAG.

## Examples

``` r
if (julia_ready()) {
  dag <- cgraph(A %-->% M, M %-->% Y)
  exogenize(dag, "M")
}
#> DAG with 3 nodes and 2 edges:
#>   nodes: A, M, Y
#>   edges:
#>     A --> Y, M --> Y
```
