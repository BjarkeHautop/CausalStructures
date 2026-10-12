# Validate instrumental variables

Tests whether a set of variables are valid instruments for identifying
the causal effect of exposure `x` on outcome `y`: every node in `z` must
be d-/m-separated from `y` given `x` in the graph obtained by deleting
`x`'s incoming edges (exclusion restriction), and at least one node in
`z` must be d-/m-connected to `x` (relevance).

## Usage

``` r
is_valid_iv(cg, x, y, z = character())
```

## Arguments

- cg:

  A DAG or ADMG created with
  [`cgraph()`](https://bjarkehautop.github.io/CausalStructures/reference/cgraph.md).

- x:

  Exposure node name.

- y:

  Outcome node name, or character vector of node names.

- z:

  Character vector of instrument node names.

## Value

`TRUE` if `z` satisfies the instrumental variable criterion.

## Examples

``` r
if (julia_ready()) {
  # Classic IV graph: Z --> X --> Y with hidden confounder U --> X, U --> Y
  dag <- cgraph(Z %-->% X, X %-->% Y, U %-->% X, U %-->% Y)
  list(
    z = is_valid_iv(dag, "X", "Y", "Z"), # Z is a valid instrument
    u = is_valid_iv(dag, "X", "Y", "U") # U confounds X and Y
  )
}
#> $z
#> [1] TRUE
#> 
#> $u
#> [1] FALSE
#> 
```
