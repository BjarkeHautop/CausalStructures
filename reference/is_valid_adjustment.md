# Validate an adjustment set

Tests the Generalized Adjustment Criterion, which covers DAGs, ADMGs,
PDAG-family graphs, MAG-family graphs, and PAGs alike: `given` must
contain no forbidden node (a descendant of a proper causal node between
`x` and `y`, or `x` itself), and must m-separate `x` from `y` in the
proper backdoor graph.

## Usage

``` r
is_valid_adjustment(cg, x, y, given = character())
```

## Arguments

- cg:

  A DAG, ADMG, PDAG-family (PDAG, CPDAG, MPDAG), AG-family (AG, MAG), or
  PAG graph created with
  [`cgraph()`](https://bjarkehautop.github.io/CausalStructures/reference/cgraph.md).

- x, y:

  Exposure and outcome node name, or character vector of node names.

- given:

  Character vector of adjustment node names (may be empty).

## Value

`TRUE` if `given` satisfies the adjustment criterion for identifying the
causal effect of `x` on `y`.

## References

Perković E, Textor J, Kalisch M, Maathuis MH (2018). “Complete Graphical
Characterization and Construction of Adjustment Sets in Markov
Equivalence Classes of Ancestral Graphs.” *Journal of Machine Learning
Research*, **18**, 1–62.

## Examples

``` r
if (julia_ready()) {
  admg <- cgraph(L %-->% X, X %-->% Y, L %-->% Y, class = "ADMG")
  list(
    empty = is_valid_adjustment(admg, "X", "Y"), # L --> Y not blocked
    conditioned_on_l = is_valid_adjustment(admg, "X", "Y", "L")
  )
}
#> $empty
#> [1] FALSE
#> 
#> $conditioned_on_l
#> [1] TRUE
#> 
```
