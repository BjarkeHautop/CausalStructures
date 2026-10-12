# Enumerate possible optimal adjustment sets (O-set-based IDA)

Returns the optimal adjustment set for each locally valid orientation of
`x`'s undirected neighbors in `cg`: the graph part of optimal-adjustment
IDA. Entries are in the same order (one per locally valid orientation)
as
[`possible_parent_sets()`](https://bjarkehautop.github.io/CausalStructures/reference/possible_parent_sets.md)`(cg, x)`,
so pairing the two element-wise recovers, for each orientation, both its
parent set and its optimal adjustment set. An entry is `NULL` when `y`
is among the resulting parents of `x` for that orientation.

## Usage

``` r
possible_optimal_adjustment_sets(cg, x, y)
```

## Arguments

- cg:

  A PDAG-family (PDAG, CPDAG, MPDAG) graph created with
  [`cgraph()`](https://bjarkehautop.github.io/CausalStructures/reference/cgraph.md).

- x, y:

  Exposure and outcome node names.

## Value

List of character vectors, or `NULL` entries, one per locally valid
orientation of `x`'s undirected neighbors.

## References

Maathuis MH, Kalisch M, Bühlmann P (2009). “Estimating high-dimensional
intervention effects from observational data.” *The Annals of
Statistics*, **37**(6A), 3133–3164.

Henckel L, Perković E, Maathuis MH (2022). “Graphical Criteria for
Efficient Total Effect Estimation Via Adjustment in Causal Linear
Models.” *Journal of the Royal Statistical Society: Series B*, **84**,
579–599.

Witte J, Henckel L, Maathuis MH, Didelez V (2020). “On efficient
adjustment in causal graphs.” *Journal of Machine Learning Research*,
**21**(246), 1–45.

## Examples

``` r
if (julia_ready()) {
  cpdag <- cgraph(
    X1 %---% X2, X1 %---% X3, X1 %---% X4, X3 %-->% Y, X4 %-->% Y,
    class = "CPDAG"
  )
  list(
    parent_sets = possible_parent_sets(cpdag, "X1"),
    optimal_adjustment_sets = possible_optimal_adjustment_sets(
      cpdag, "X1", "Y"
    )
  )
}
#> $parent_sets
#> $parent_sets[[1]]
#> character(0)
#> 
#> $parent_sets[[2]]
#> [1] "X2"
#> 
#> $parent_sets[[3]]
#> [1] "X3"
#> 
#> $parent_sets[[4]]
#> [1] "X4"
#> 
#> 
#> $optimal_adjustment_sets
#> $optimal_adjustment_sets[[1]]
#> character(0)
#> 
#> $optimal_adjustment_sets[[2]]
#> character(0)
#> 
#> $optimal_adjustment_sets[[3]]
#> [1] "X3"
#> 
#> $optimal_adjustment_sets[[4]]
#> [1] "X4"
#> 
#> 
```
