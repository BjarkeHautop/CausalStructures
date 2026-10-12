# Enumerate possible joint parent sets (joint-IDA)

Generalizes
[`possible_parent_sets()`](https://bjarkehautop.github.io/CausalStructures/reference/possible_parent_sets.md)
from a single intervention node to a set `xs` of simultaneous
interventions: every undirected edge incident to at least one node of
`xs` is jointly reoriented, keeping only orientations that introduce no
new v-structure and remain acyclic. Each returned entry is a list of
parent sets in the same order as `xs` (entry `i` gives a valid parent
set for `xs[i]` under that joint orientation).

## Usage

``` r
possible_joint_parent_sets(cg, xs)
```

## Arguments

- cg:

  A PDAG-family (PDAG, CPDAG, MPDAG) graph created with
  [`cgraph()`](https://bjarkehautop.github.io/CausalStructures/reference/cgraph.md).

- xs:

  Character vector of node names (the simultaneous interventions; must
  be non-empty with no duplicates).

## Value

List of lists of character vectors: one list per valid joint
orientation, each containing one parent set per node of `xs`.

## References

Maathuis MH, Kalisch M, Bühlmann P (2009). “Estimating high-dimensional
intervention effects from observational data.” *The Annals of
Statistics*, **37**(6A), 3133–3164.

Nandy P, Maathuis MH, Richardson TS (2017). “Estimating the effect of
joint interventions from observational data in sparse high-dimensional
settings.” *The Annals of Statistics*, **45**(2), 647–674.

## Examples

``` r
if (julia_ready()) {
  cpdag <- cgraph(
    X1 %---% X2, X1 %---% A, X2 %---% B, A %-->% Y, B %-->% Y,
    class = "CPDAG"
  )
  possible_joint_parent_sets(cpdag, c("X1", "X2"))
}
#> [[1]]
#> [[1]][[1]]
#> [1] "X2"
#> 
#> [[1]][[2]]
#> [1] "B"
#> 
#> 
#> [[2]]
#> [[2]][[1]]
#> [1] "A"
#> 
#> [[2]][[2]]
#> [1] "X1"
#> 
#> 
#> [[3]]
#> [[3]][[1]]
#> character(0)
#> 
#> [[3]][[2]]
#> [1] "X1"
#> 
#> 
#> [[4]]
#> [[4]][[1]]
#> [1] "X2"
#> 
#> [[4]][[2]]
#> character(0)
#> 
#> 
```
