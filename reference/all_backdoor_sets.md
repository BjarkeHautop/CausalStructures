# Enumerate backdoor adjustment sets

Lists all sets (up to size `max_size`) satisfying the backdoor
criterion; see
[`is_valid_backdoor()`](https://bjarkehautop.github.io/CausalStructures/reference/is_valid_backdoor.md).
When `minimal = TRUE` (default), only inclusion-minimal sets are
returned.

## Usage

``` r
all_backdoor_sets(cg, x, y, minimal = TRUE, max_size = 3)
```

## Arguments

- cg:

  A DAG or ADMG created with
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
  dag <- cgraph(A %-->% X, X %-->% Y, A %-->% Y)
  all_backdoor_sets(dag, "X", "Y")
}
#> [[1]]
#> [1] "A"
#> 
```
