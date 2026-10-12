# Resolve a PAG to a representative MAG

Returns one MAG belonging to the Markov equivalence class represented by
the PAG `cg`: a left inverse of
[`mag_to_pag()`](https://bjarkehautop.github.io/CausalStructures/reference/mag_to_pag.md),
so `mag_to_pag(mag_from_pag(pag))` recovers `pag`. Every circle mark
left unresolved by the PAG is resolved to a tail or arrowhead following
Zhang's construction (2008, Theorem 2): a circle opposite a fixed mark
always becomes directed; an undirected edge (selection bias) is kept
unchanged; the remaining all-circle edges form a chordal component,
oriented into a DAG with no new unshielded colliders by Dor-Tarsi
simplicial elimination.

## Usage

``` r
mag_from_pag(cg)
```

## Arguments

- cg:

  A PAG created with
  [`cgraph()`](https://bjarkehautop.github.io/CausalStructures/reference/cgraph.md).

## Value

A `MAG` graph proxy.

## References

Zhang J (2008). “On the completeness of orientation rules for causal
discovery in the presence of latent confounders and selection bias.”
*Artificial Intelligence*, **172**(16-17), 1873–1896.

Dor D, Tarsi M (1992). “A simple algorithm to construct a consistent
extension of a partially oriented graph.” Technical Report R-185,
Cognitive Systems Laboratory, UCLA.

## Examples

``` r
if (julia_ready()) {
  pag <- cgraph(A %o-o% B, B %o-o% C, class = "PAG")
  mag_from_pag(pag)
}
#> MAG with 3 nodes and 2 edges:
#>   nodes: A, B, C
#>   edges:
#>     B --> A, C --> B
```
