# Normalize latent structure

Simplifies the latent nodes of `cg` while preserving the induced
marginal model over the observed variables (Evans 2016, Lemmas 1-3):
exogenizes each latent node, then drops latent nodes with at most one
active child or whose child set is a strict subset of another latent
node's child set.

## Usage

``` r
normalize_latent_structure(cg, latents)
```

## Arguments

- cg:

  A DAG created with
  [`cgraph()`](https://bjarkehautop.github.io/CausalStructures/reference/cgraph.md).

- latents:

  Character vector of latent (unobserved) node names.

## Value

A Julia proxy object representing the resulting DAG.

## Examples

``` r
if (julia_ready()) {
  dag <- cgraph(U %-->% A, U %-->% B, A %-->% B)
  normalize_latent_structure(dag, "U")
}
#> DAG with 3 nodes and 3 edges:
#>   nodes: A, B, U
#>   edges:
#>     A --> B, U --> A, U --> B
```
