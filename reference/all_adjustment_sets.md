# Enumerate all valid adjustment sets

Lists all sets (up to size `max_size`) satisfying the Generalized
Adjustment Criterion; see
[`is_valid_adjustment()`](https://bjarkehautop.github.io/CausalStructures/reference/is_valid_adjustment.md).
When `minimal = TRUE` (default), only inclusion-minimal sets are
returned.

## Usage

``` r
all_adjustment_sets(cg, x, y, minimal = TRUE, max_size = 3)
```

## Arguments

- cg:

  A DAG, ADMG, PDAG-family (PDAG, CPDAG, MPDAG), AG-family (AG, MAG), or
  PAG graph created with
  [`cgraph()`](https://bjarkehautop.github.io/CausalStructures/reference/cgraph.md).

- x, y:

  Exposure and outcome node name, or character vector of node names.

- minimal:

  If `TRUE` (default), return only minimal sets.

- max_size:

  Maximum adjustment set size to consider.

## Value

List of character vectors (empty list if none exist).

## Examples

``` r
if (julia_ready()) {
  admg <- cgraph(L %-->% X, X %-->% Y, L %-->% Y, class = "ADMG")
  all_adjustment_sets(admg, "X", "Y")
}
#> [[1]]
#> [1] "L"
#> 
```
