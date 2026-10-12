# Induced subgraph

Induced subgraph

## Usage

``` r
subgraph(cg, nodes)
```

## Arguments

- cg:

  A graph created with
  [`cgraph()`](https://bjarkehautop.github.io/CausalStructures/reference/cgraph.md),
  of any class.

- nodes:

  Character vector of node names to keep.

## Value

A Julia proxy object representing the subgraph.

## Examples

``` r
if (julia_ready()) {
  dag <- cgraph(A %-->% B, B %-->% C)
  subgraph(dag, c("A", "B"))
}
#> DAG with 2 nodes and 1 edge:
#>   nodes: A, B
#>   edges:
#>     A --> B
```
