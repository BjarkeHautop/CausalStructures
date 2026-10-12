# Test whether two nodes are adjacent

Tests adjacency, not directed reachability: `has_edge(g, x, y)` and
`has_edge(g, y, x)` always agree, even for a directed edge `x --> y`.

## Usage

``` r
has_edge(cg, x, y)
```

## Arguments

- cg:

  A graph created with
  [`cgraph()`](https://bjarkehautop.github.io/CausalStructures/reference/cgraph.md),
  of any class.

- x, y:

  Node names.

## Value

`TRUE` if the graph has any edge between `x` and `y`, regardless of
direction.

## Examples

``` r
if (julia_ready()) {
  dag <- cgraph(A %-->% B, C)
  list(
    "A,B" = has_edge(dag, "A", "B"),
    "B,A" = has_edge(dag, "B", "A"),
    "A,C" = has_edge(dag, "A", "C")
  )
}
#> $`A,B`
#> [1] TRUE
#> 
#> $`B,A`
#> [1] TRUE
#> 
#> $`A,C`
#> [1] FALSE
#> 
```
