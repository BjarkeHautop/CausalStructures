# Get all edges in a graph

Get all edges in a graph

## Usage

``` r
edges(cg)
```

## Arguments

- cg:

  A graph created with
  [`cgraph()`](https://bjarkehautop.github.io/CausalStructures/reference/cgraph.md),
  of any class.

## Value

A data frame with one row per edge and columns `from`, `to` (node names)
and `type` (the edge's notation, e.g. `"-->"`, `"---"`, `"<->"`,
`"o->"`, `"o--"`, or `"o-o"` — see
[edge-operators](https://bjarkehautop.github.io/CausalStructures/reference/edge-operators.md)),
or zero rows if the graph has no edges.

## Examples

``` r
if (julia_ready()) {
  dag <- cgraph(A %-->% B, B %-->% C)
  edges(dag)

  pag <- cgraph(A %o-o% B, class = "PAG")
  edges(pag)
}
#>   from to type
#> 1    A  B  o-o
```
