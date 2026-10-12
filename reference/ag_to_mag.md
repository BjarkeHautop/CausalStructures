# Convert an AG to a Markov equivalent MAG

Adds an edge between every pair of non-adjacent nodes in the AG `cg`
that cannot be m-separated by any subset of the remaining nodes,
producing a Markov equivalent MAG. For each such pair `(u, v)`, the edge
is directed toward whichever node is not an ancestor of the other, or
bidirected if neither is an ancestor of the other. Edges are added one
at a time, with the graph re-evaluated after each addition (a new edge
can change m-separation and ancestor relationships).

## Usage

``` r
ag_to_mag(cg)
```

## Arguments

- cg:

  An AG created with
  [`cgraph()`](https://bjarkehautop.github.io/CausalStructures/reference/cgraph.md).

## Value

A `MAG` graph proxy.

## Examples

``` r
if (julia_ready()) {
  ag <- cgraph(A %-->% B, B %-->% C, class = "AG")
  ag_to_mag(ag)
}
#> MAG with 3 nodes and 2 edges:
#>   nodes: A, B, C
#>   edges:
#>     A --> B, B --> C
```
