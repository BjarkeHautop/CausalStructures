# Validate a frontdoor criterion set

`given` is a valid front-door set if (1) it intercepts every directed
path from `x` to `y`, (2) there is no unblocked backdoor path from `x`
to any node in `given`, and (3) for every node in `given`, all backdoor
paths to `y` are blocked by `x` together with the rest of `given`. When
these hold, the effect is identified via the front-door formula even
with unmeasured confounders between `x` and `y`.

## Usage

``` r
is_valid_frontdoor(cg, x, y, given = character())
```

## Arguments

- cg:

  A DAG or ADMG created with
  [`cgraph()`](https://bjarkehautop.github.io/CausalStructures/reference/cgraph.md).

- x, y:

  Exposure and outcome node name, or character vector of node names.

- given:

  Character vector of conditioning node names (may be empty).

## Value

`TRUE` if the configuration satisfies the frontdoor criterion.

## Examples

``` r
if (julia_ready()) {
  dag <- cgraph(U %-->% X, X %-->% M, M %-->% Y, U %-->% Y)
  list(
    m_mediates = is_valid_frontdoor(dag, "X", "Y", "M"),
    empty = is_valid_frontdoor(dag, "X", "Y") # X -> M -> Y left open
  )
}
#> $m_mediates
#> [1] TRUE
#> 
#> $empty
#> [1] FALSE
#> 
```
