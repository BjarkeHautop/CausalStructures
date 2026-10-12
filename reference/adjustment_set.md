# Find an adjustment set

Computes a valid adjustment set for the total causal effect of `x` on
`y`.

## Usage

``` r
adjustment_set(cg, x, y, type = c("optimal", "parents", "backdoor"))
```

## Arguments

- cg:

  A DAG, ADMG, PDAG-family (PDAG, CPDAG, MPDAG), AG-family (AG, MAG), or
  PAG graph created with
  [`cgraph()`](https://bjarkehautop.github.io/CausalStructures/reference/cgraph.md).

- x, y:

  Exposure and outcome node name, or character vector of node names (to
  identify the effect of a set of exposures on a set of outcomes).

- type:

  Adjustment set type: `"optimal"` (default), `"parents"`, or
  `"backdoor"`. Ignored for ADMG, MAG-family, and PAG graphs;
  `"backdoor"` is not supported for PDAG-family graphs.

## Value

Character vector with a valid adjustment set, or `NULL` if none exists.

## Details

The supported adjustment set types depend on the graph class:

- DAG:

  All three types are supported.

- PDAG-family (PDAG, CPDAG, MPDAG):

  Only `"parents"` and `"optimal"` are supported; `"backdoor"` raises an
  error.

- ADMG, MAG-family (AG, MAG), PAG:

  `type` is ignored. The smallest valid adjustment set is returned by
  searching sets of increasing size.

The available adjustment set types are:

- `"parents"`:

  The parents of `x`, excluding `x` and `y`.

- `"backdoor"`:

  An inclusion-minimal set satisfying Pearl's backdoor criterion: a
  minimal separator of `x` and `y` among `x`'s non-descendants, after
  removing `x`'s outgoing edges (falls back to the parents of `x` if no
  such separator is found).

- `"optimal"`:

  The O-set: the parents of causal nodes on a possibly causal path from
  `x` to `y`, excluding `x` and those causal nodes themselves.

Candidate adjustment sets can be validated with
[`is_valid_adjustment()`](https://bjarkehautop.github.io/CausalStructures/reference/is_valid_adjustment.md).

## References

Henckel L, Perković E, Maathuis MH (2022). “Graphical Criteria for
Efficient Total Effect Estimation Via Adjustment in Causal Linear
Models.” *Journal of the Royal Statistical Society: Series B*, **84**,
579–599. (`"optimal"`)

Pearl J (2009). *Causality: Models, Reasoning, and Inference*, 2nd
edition. Cambridge University Press. (`"parents"` and `"backdoor"`)

## Examples

``` r
if (julia_ready()) {
  dag <- cgraph(
    C %-->% X, X %-->% F + D, A %-->% X + K, K %-->% Y,
    D %-->% Y + G, Y %-->% H
  )
  list(
    parents = sort(adjustment_set(dag, "X", "Y", type = "parents")),
    backdoor = adjustment_set(dag, "X", "Y", type = "backdoor"),
    optimal = adjustment_set(dag, "X", "Y", type = "optimal") # default
  )
}
#> $parents
#> [1] "A" "C"
#> 
#> $backdoor
#> [1] "A"
#> 
#> $optimal
#> [1] "K"
#> 

if (julia_ready()) {
  pdag <- cgraph(A %-->% X, X %-->% Y, A %-->% Y, class = "PDAG")
  list(
    adjustment_set = adjustment_set(pdag, "X", "Y"), # A
    is_valid = is_valid_adjustment(pdag, "X", "Y", "A")
  )
}
#> $adjustment_set
#> [1] "A"
#> 
#> $is_valid
#> [1] TRUE
#> 

if (julia_ready()) {
  mag <- cgraph(A %<->% X, A %-->% Y, X %-->% Y, class = "MAG")
  adjustment_set(mag, "X", "Y") # A; type is ignored
}
#> NULL
```
