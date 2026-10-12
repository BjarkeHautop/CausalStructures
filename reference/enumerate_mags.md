# Enumerate MAGs in a PAG equivalence class

Enumerates all Markov equivalent MAGs in the equivalence class
represented by a PAG (Partial Ancestral Graph): each circle endpoint of
the PAG is independently resolved to a tail or an arrowhead, keeping
only assignments that validate as a MAG and map back to the same PAG
under
[`mag_to_pag()`](https://bjarkehautop.github.io/CausalStructures/reference/mag_to_pag.md).
For a single representative instead of the whole class, use
[`mag_from_pag()`](https://bjarkehautop.github.io/CausalStructures/reference/mag_from_pag.md).

## Usage

``` r
enumerate_mags(cg)
```

## Arguments

- cg:

  A PAG (partially ancestral graph) created with
  [`cgraph()`](https://bjarkehautop.github.io/CausalStructures/reference/cgraph.md).

## Value

A Julia proxy list of MAGs in the equivalence class.

## Examples

``` r
if (julia_ready()) {
  pag <- cgraph(A %o-o% B, B %o-o% C, class = "PAG")
  length(enumerate_mags(pag))
}
#> [1] 8
```
