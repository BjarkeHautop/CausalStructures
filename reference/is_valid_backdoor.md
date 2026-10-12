# Validate a backdoor adjustment set

`given` is a valid backdoor set if (1) no node in `given` is a
descendant of `x`, and (2) `given` blocks every backdoor path from `x`
to `y` (every parent of `x` is d-separated from `y` given `given`
together with `x`).

## Usage

``` r
is_valid_backdoor(cg, x, y, given = character())
```

## Arguments

- cg:

  A DAG or ADMG created with
  [`cgraph()`](https://bjarkehautop.github.io/CausalStructures/reference/cgraph.md).

- x, y:

  Exposure and outcome node name, or character vector of node names.

- given:

  Character vector of adjustment node names (may be empty).

## Value

`TRUE` if `given` satisfies the backdoor criterion.

## Examples

``` r
if (julia_ready()) {
  dag <- cgraph(A %-->% X, X %-->% Y, A %-->% Y)
  list(
    empty = is_valid_backdoor(dag, "X", "Y"), # A --> Y left open
    conditioned_on_a = is_valid_backdoor(dag, "X", "Y", "A")
  )
}
#> $empty
#> [1] FALSE
#> 
#> $conditioned_on_a
#> [1] TRUE
#> 
```
