# Anterior/posterior node-set queries

`anteriors()` finds every node from which `node` is reachable by
following directed edges backward or traversing undirected edges;
`posteriors()` is the mirror notion following directed edges forward.
For a DAG, anteriors/posteriors are equivalent to
[`ancestors()`](https://bjarkehautop.github.io/CausalStructures/reference/node-queries.md)/[`descendants()`](https://bjarkehautop.github.io/CausalStructures/reference/node-queries.md)
(no undirected edges exist to traverse); for a PDAG-family or AG-family
graph, undirected edges extend the reachable set beyond strict
ancestors/descendants.

## Usage

``` r
anteriors(cg, node, open = getOption("CausalStructures.open", TRUE))

posteriors(cg, node, open = getOption("CausalStructures.open", TRUE))
```

## Arguments

- cg:

  A DAG, ADMG, PDAG-family (PDAG, CPDAG, MPDAG), or AG-family (AG, MAG)
  graph created with
  [`cgraph()`](https://bjarkehautop.github.io/CausalStructures/reference/cgraph.md).

- node:

  Node name.

- open:

  If `TRUE` (default, from the `CausalStructures.open` option), exclude
  `node` itself from the result; if `FALSE`, include it.

## Value

Sorted character vector of node names.

## Examples

``` r
if (julia_ready()) {
  pdag <- cgraph(A %-->% B, B %---% C, class = "PDAG")
  list(
    anteriors_of_a = anteriors(pdag, "A"),
    anteriors_of_c = anteriors(pdag, "C") # reaches B via undirected, A via directed
  )
}
#> $anteriors_of_a
#> character(0)
#> 
#> $anteriors_of_c
#> [1] "A" "B"
#> 
```
