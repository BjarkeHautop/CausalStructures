# Enumerate frontdoor adjustment sets

Lists all sets `Z` with `include ⊆ Z ⊆ restrict` satisfying the
front-door criterion; see
[`frontdoor_set()`](https://bjarkehautop.github.io/CausalStructures/reference/frontdoor_set.md)
and
[`is_valid_frontdoor()`](https://bjarkehautop.github.io/CausalStructures/reference/is_valid_frontdoor.md).

## Usage

``` r
all_frontdoor_sets(cg, x, y, include = character(), restrict = NULL)
```

## Arguments

- cg:

  A DAG or ADMG created with
  [`cgraph()`](https://bjarkehautop.github.io/CausalStructures/reference/cgraph.md).
  For an ADMG, see the note on m-separation in
  [`frontdoor_set()`](https://bjarkehautop.github.io/CausalStructures/reference/frontdoor_set.md).

- x, y:

  Exposure and outcome node name, or character vector of node names.

- include:

  Character vector of nodes forced into every set.

- restrict:

  Character vector of candidate nodes sets are drawn from. `NULL`
  (default) allows every node except `x` and `y`.

## Value

List of character vectors (empty list if none exist).

## Examples

``` r
if (julia_ready()) {
  dag <- cgraph(U %-->% X, U %-->% Y, X %-->% Z, Z %-->% Y)
  all_frontdoor_sets(dag, "X", "Y", restrict = "Z")
}
#> [[1]]
#> [1] "Z"
#> 
```
