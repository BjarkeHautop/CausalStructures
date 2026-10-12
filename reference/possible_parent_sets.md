# Enumerate possible parent sets (local IDA)

Returns every possible parental set of `x` implied by `cg`: the
graph-only half of the local IDA algorithm. One entry is returned per
locally valid orientation of `x`'s undirected neighbors (not per DAG in
the Markov equivalence class of `cg` - the two collections agree when
read as sets, but their multiplicities differ in general).

## Usage

``` r
possible_parent_sets(cg, x)
```

## Arguments

- cg:

  A PDAG-family (PDAG, CPDAG, MPDAG) graph created with
  [`cgraph()`](https://bjarkehautop.github.io/CausalStructures/reference/cgraph.md).

- x:

  Node name.

## Value

List of character vectors, one per locally valid orientation.

## References

Maathuis MH, Kalisch M, Bühlmann P (2009). “Estimating high-dimensional
intervention effects from observational data.” *The Annals of
Statistics*, **37**(6A), 3133–3164.

## Examples

``` r
if (julia_ready()) {
  cpdag <- cgraph(
    X1 %---% X2, X1 %---% X3, X1 %---% X4, X3 %-->% Y, X4 %-->% Y,
    class = "CPDAG"
  )
  possible_parent_sets(cpdag, "X1")
}
#> [[1]]
#> character(0)
#> 
#> [[2]]
#> [1] "X2"
#> 
#> [[3]]
#> [1] "X3"
#> 
#> [[4]]
#> [1] "X4"
#> 
```
