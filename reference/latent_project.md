# Project out latent variables

Project out latent (unobserved) variables to produce an ADMG over the
observed variables only.

## Usage

``` r
latent_project(cg, latents)
```

## Arguments

- cg:

  A DAG created with
  [`cgraph()`](https://bjarkehautop.github.io/CausalStructures/reference/cgraph.md).

- latents:

  Character vector of latent (unobserved) node names.

## Value

A Julia proxy object representing the resulting ADMG.

## Examples

``` r
if (julia_ready()) {
  dag <- cgraph(U %-->% A, U %-->% B, A %-->% B)
  latent_project(dag, "U")
}
#> ADMG with 2 nodes and 2 edges:
#>   nodes: A, B
#>   edges:
#>     A --> B, A <-> B
```
