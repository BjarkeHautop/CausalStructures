# Possible-ancestor/descendant node-set queries

`possible_ancestors()` finds every node `V` for which some DAG (for a
PDAG-family `cg`) or MAG (for a PAG `cg`) in the equivalence class
represented by `cg` has `V` as an ancestor of `node`: nodes reachable
from `node` by a *possibly directed* path, one on which no edge is
compelled in the direction away from `node` (traversing an undirected
edge, or a directed/circle edge oriented, or possibly orientable, toward
`node`). `possible_descendants()` is the mirror notion in the other
direction. Both are supersets of
[`ancestors()`](https://bjarkehautop.github.io/CausalStructures/reference/node-queries.md)/[`descendants()`](https://bjarkehautop.github.io/CausalStructures/reference/node-queries.md),
since those only count edges *compelled* in the right direction.

## Usage

``` r
possible_ancestors(cg, node, open = getOption("CausalStructures.open", TRUE))

possible_descendants(cg, node, open = getOption("CausalStructures.open", TRUE))
```

## Arguments

- cg:

  A PDAG-family (PDAG, CPDAG, MPDAG) or PAG graph created with
  [`cgraph()`](https://bjarkehautop.github.io/CausalStructures/reference/cgraph.md).

- node:

  Node name.

- open:

  If `TRUE` (default, from the `CausalStructures.open` option), exclude
  `node` itself from the result; if `FALSE`, include it.

## Value

Sorted character vector of node names.

## References

Perković E, Textor J, Kalisch M, Maathuis MH (2018). “Complete Graphical
Characterization and Construction of Adjustment Sets in Markov
Equivalence Classes of Ancestral Graphs.” *Journal of Machine Learning
Research*, **18**, 1–62.

## Examples

``` r
if (julia_ready()) {
  cpdag <- cgraph(A %---% B, B %---% C, class = "CPDAG")
  list(
    ancestors = ancestors(cpdag, "C"),
    possible_ancestors = possible_ancestors(cpdag, "C"),
    possible_ancestors_including_self =
      possible_ancestors(cpdag, "C", open = FALSE)
  )
}
#> $ancestors
#> character(0)
#> 
#> $possible_ancestors
#> [1] "A" "B"
#> 
#> $possible_ancestors_including_self
#> [1] "A" "B" "C"
#> 
```
