# Condition and marginalize a graph

Removes `cond_vars` and `marg_vars` from `cg`, returning the AG over the
remaining nodes that represents the graphical effect of conditioning on
`cond_vars` and marginalizing out `marg_vars`. At least one of the two
must be non-empty, and they must be disjoint.

## Usage

``` r
condition_marginalize(cg, cond_vars = character(), marg_vars = character())
```

## Arguments

- cg:

  A DAG, ADMG, or AG-family (AG, MAG) graph created with
  [`cgraph()`](https://bjarkehautop.github.io/CausalStructures/reference/cgraph.md).

- cond_vars:

  Character vector of node names to condition on.

- marg_vars:

  Character vector of node names to marginalize out.

## Value

A Julia proxy object representing the resulting AG.

## Examples

``` r
if (julia_ready()) {
  dag <- cgraph(A %-->% M, M %-->% Y, U %-->% A, U %-->% Y)
  condition_marginalize(dag, marg_vars = "U")
}
#> AG with 3 nodes and 3 edges:
#>   nodes: A, M, Y
#>   edges:
#>     A --> M, A --> Y, M --> Y
```
