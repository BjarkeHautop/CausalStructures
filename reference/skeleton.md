# Drop edge marks to an undirected graph

Returns the skeleton of `cg`: the undirected graph obtained by replacing
every directed or partially-directed edge with an undirected edge (a
node pair keeps a single edge regardless of how many marked edges
connected it).

## Usage

``` r
skeleton(cg)
```

## Arguments

- cg:

  A DAG or PDAG-family (PDAG, CPDAG, MPDAG) graph created with
  [`cgraph()`](https://bjarkehautop.github.io/CausalStructures/reference/cgraph.md).

## Value

A `UG` graph proxy.

## Examples

``` r
if (julia_ready()) {
  dag <- cgraph(A %-->% B, B %-->% C)
  skeleton(dag)
}
#> UG with 3 nodes and 2 edges:
#>   nodes: A, B, C
#>   edges:
#>     A --- B, B --- C
```
