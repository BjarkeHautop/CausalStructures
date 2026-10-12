# Find every possible D-SEP set

Returns D-SEP(x, y, cg): every vertex other than `x` for which there is
a collider path between `x` and the vertex in `cg` on which every
vertex, including the vertex itself, is an ancestor of `x` or of some
member of `y`. This is the plain graph-level primitive that
[`backdoor_set()`](https://bjarkehautop.github.io/CausalStructures/reference/backdoor_set.md)
(for MAG/PAG) uses internally to build its generalized back-door set.

## Usage

``` r
possible_d_sep(cg, x, y)
```

## Arguments

- cg:

  An AG-family (AG, MAG) or PAG graph created with
  [`cgraph()`](https://bjarkehautop.github.io/CausalStructures/reference/cgraph.md).

- x:

  Node name.

- y:

  Node name, or character vector of node names.

## Value

Sorted character vector of node names.

## References

Maathuis MH, Colombo D (2015). “A generalized back-door criterion.” *The
Annals of Statistics*, **43**(3), 1060–1088.

## Examples

``` r
if (julia_ready()) {
  mag <- cgraph(A %<->% X, A %-->% M, M %-->% Y, X %-->% Y, class = "MAG")
  list(
    possible_d_sep = possible_d_sep(mag, "X", "Y"),
    backdoor_set = backdoor_set(mag, "X", "Y") # M_X drops X --> Y
  )
}
#> $possible_d_sep
#> [1] "A" "M" "Y"
#> 
#> $backdoor_set
#> [1] "A"
#> 
```
