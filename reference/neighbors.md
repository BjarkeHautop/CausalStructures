# Neighbors of a node

Nodes adjacent to `node` by some edge. `mode` restricts which edge types
count: `"in"` (parents / arrowheads at `node`), `"out"` (children /
tails at `node`), `"undirected"`, or `"bidirected"`; `"all"` (default)
includes every neighbor regardless of edge type. For a PAG, `"in"`,
`"out"`, `"undirected"`, and `"bidirected"` only match *definite*
(circle-free) edges; neighbors joined by a circle mark (`o->`, `o--`,
`o-o`) are reported by `"all"` only.

## Usage

``` r
neighbors(cg, node, mode = c("all", "in", "out", "undirected", "bidirected"))
```

## Arguments

- cg:

  A graph created with
  [`cgraph()`](https://bjarkehautop.github.io/CausalStructures/reference/cgraph.md),
  of any class.

- node:

  Node name.

- mode:

  Which edge types to include: `"all"` (default), `"in"`, `"out"`,
  `"undirected"`, or `"bidirected"`.

## Value

Sorted character vector of node names.

## Examples

``` r
if (julia_ready()) {
  dag <- cgraph(A %-->% B, C %-->% B)
  list(
    all = neighbors(dag, "B"),
    "in" = neighbors(dag, "B", mode = "in"),
    out = neighbors(dag, "A", mode = "out")
  )
}
#> $all
#> [1] "A" "C"
#> 
#> $`in`
#> [1] "A" "C"
#> 
#> $out
#> [1] "B"
#> 
```
