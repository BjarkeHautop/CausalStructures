# Simulate data from a DAG

Simulates observational data from a linear Gaussian structural causal
model over `cg`: each node is a linear function of its parents plus
independent Gaussian noise with standard deviation `error_sd`, with edge
coefficients drawn uniformly from `coef_range`. If `standardize = TRUE`
(default), each variable is standardized to zero mean and unit variance.

## Usage

``` r
simulate_data(
  cg,
  n,
  standardize = TRUE,
  coef_range = c(-1, 1),
  error_sd = 1,
  seed = NULL
)
```

## Arguments

- cg:

  A DAG created with
  [`cgraph()`](https://bjarkehautop.github.io/CausalStructures/reference/cgraph.md).

- n:

  Number of samples to generate.

- standardize:

  If `TRUE` (default), standardize each variable to zero mean and unit
  variance.

- coef_range:

  Length-2 numeric vector giving the range edge coefficients are drawn
  uniformly from.

- error_sd:

  Standard deviation of each node's Gaussian noise term.

- seed:

  Optional integer seed for reproducibility.

## Value

A data frame with `n` rows (samples) and one column per node, named and
ordered as in
[`nodes()`](https://bjarkehautop.github.io/CausalStructures/reference/graph-queries.md).

## Examples

``` r
if (julia_ready()) {
  dag <- cgraph(A %-->% B, B %-->% C)
  data <- simulate_data(dag, n = 100, seed = 1405)
  head(data)
}
#>            A           B          C
#> 1  0.2252116  0.94046212 -1.1023971
#> 2 -1.0289753  1.09599384 -0.2653914
#> 3  0.4662671 -0.06848752  0.7857454
#> 4 -1.0319934  0.67852248 -0.7721987
#> 5  0.5336344 -0.81277109  1.1373351
#> 6  1.1702497  0.09957588 -0.1748956

if (julia_ready()) {
  dag <- cgraph(A %-->% B, B %-->% C)
  data2 <- simulate_data(
    dag,
    n = 100,
    standardize = FALSE,
    coef_range = c(0.5, 2),
    error_sd = 0.1,
    seed = 1405
  )
  head(data2)
}
#>             A            B           C
#> 1  0.02084420  0.174572904  0.03517713
#> 2 -0.10735354  0.006284409  0.08569061
#> 3  0.04548387  0.077840337  0.15441345
#> 4 -0.10766204 -0.049208871 -0.07452100
#> 5  0.05236988 -0.010144336  0.07057341
#> 6  0.11744204  0.205968631  0.09921774
```
