# Find a minimal separator

Finds a minimal d-separator (DAG, PDAG classes) or m-separator (ADMG,
ancestral-graph classes, PAG) between `x` and `y`: no proper subset
(excluding forced `include` nodes) of the returned set still separates
them.

## Usage

``` r
minimal_separator(cg, x, y, include = character(), restrict = NULL)
```

## Arguments

- cg:

  A DAG, ADMG, AG-family (AG, MAG), PDAG-family (PDAG, CPDAG, MPDAG), or
  PAG graph created with
  [`cgraph()`](https://bjarkehautop.github.io/CausalStructures/reference/cgraph.md).

- x, y:

  Node name, or character vector of node names (to separate the two
  *sets*).

- include:

  Character vector of nodes forced into the separator (must be a subset
  of `restrict`, if given).

- restrict:

  Character vector of candidate nodes the separator is drawn from.
  `NULL` (default) allows every node except `x` and `y`.

## Value

Character vector with a minimal separating set, or `NULL` if none
exists.

## Examples

``` r
if (julia_ready()) {
  dag <- cgraph(A %-->% X, X %-->% M, M %-->% Y, A %-->% Y)
  list(
    default = minimal_separator(dag, "X", "Y"), # both A and M needed
    forced_include = minimal_separator(dag, "X", "Y", include = "M"),
    restricted = minimal_separator(dag, "X", "Y", restrict = "M")
  )
}
#> $default
#> [1] "A" "M"
#> 
#> $forced_include
#> [1] "A" "M"
#> 
#> $restricted
#> NULL
#> 

if (julia_ready()) {
  edge <- cgraph(A %-->% B)
  minimal_separator(edge, "A", "B") # direct edge: no separator exists
}
#> NULL
```
