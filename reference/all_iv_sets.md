# Enumerate all valid instrumental variable sets

Finds all minimal (or all) sets of valid instruments for identifying the
causal effect of `x` on `y`; see
[`is_valid_iv()`](https://bjarkehautop.github.io/CausalStructures/reference/is_valid_iv.md).

## Usage

``` r
all_iv_sets(cg, x, y, minimal = TRUE, max_size = 3)
```

## Arguments

- cg:

  A DAG or ADMG created with
  [`cgraph()`](https://bjarkehautop.github.io/CausalStructures/reference/cgraph.md).

- x:

  Exposure node name.

- y:

  Outcome node name, or character vector of node names.

- minimal:

  If `TRUE` (default), return only minimal sets.

- max_size:

  Maximum number of instruments to consider.

## Value

List of character vectors (empty list if none exist).

## Examples

``` r
if (julia_ready()) {
  dag <- cgraph(
    Z1 %-->% X, Z2 %-->% X, X %-->% Y, U %-->% X, U %-->% Y
  )
  all_iv_sets(dag, "X", "Y")
}
#> [[1]]
#> [1] "Z1"
#> 
#> [[2]]
#> [1] "Z2"
#> 
```
