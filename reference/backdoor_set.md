# Find a generalized backdoor set

Returns a generalized back-door set relative to `(x, y)` in `cg` using
the Generalized Backdoor Criterion (GBC), or `NULL` if none exists.

## Usage

``` r
backdoor_set(cg, x, y)
```

## Arguments

- cg:

  A DAG, CPDAG, MAG, or PAG graph created with
  [`cgraph()`](https://bjarkehautop.github.io/CausalStructures/reference/cgraph.md).

- x, y:

  Exposure and outcome node names.

## Value

Character vector with a generalized back-door set, or `NULL` if none
exists.

## References

Maathuis MH, Colombo D (2015). “A generalized back-door criterion.” *The
Annals of Statistics*, **43**(3), 1060–1088.

## Examples

``` r
if (julia_ready()) {
  # A --> X <-- C protects both edges into X
  cpdag <- cgraph(A %-->% X, C %-->% X, X %-->% Y, class = "CPDAG")
  sort(backdoor_set(cpdag, "X", "Y"))
}
#> [1] "A" "C"
```
