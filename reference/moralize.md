# Moralize a graph

Returns the moral graph of `cg`: an undirected graph with a "marriage"
edge added between every pair of directed parents that share a common
child, then every edge replaced with an undirected edge. For a
PDAG-family graph, only directed parents participate in marriage edges;
undirected neighbors are carried over but don't form a clique.

## Usage

``` r
moralize(cg)
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
  dag <- cgraph(A %-->% C, B %-->% C)
  moralize(dag) # A and B are now married
}
#> UG with 3 nodes and 3 edges:
#>   nodes: A, B, C
#>   edges:
#>     A --- C, B --- C, A --- B
```
