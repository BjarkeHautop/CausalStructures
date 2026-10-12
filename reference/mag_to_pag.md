# Map a MAG to its PAG equivalence class

Returns the PAG representing the Markov equivalence class of the MAG
`cg`: same skeleton, with each endpoint kept as an arrowhead or tail
only if that mark is shared by every MAG in the class (a circle mark
otherwise). Starts from the skeleton with all-circle marks, orients
unshielded colliders as they appear in `cg`, then applies Zhang's
complete orientation rules R1-R10 until no further mark is implied. The
input graph is unchanged; for a single representative MAG instead of the
whole class, use
[`mag_from_pag()`](https://bjarkehautop.github.io/CausalStructures/reference/mag_from_pag.md).

## Usage

``` r
mag_to_pag(cg)
```

## Arguments

- cg:

  A MAG created with
  [`cgraph()`](https://bjarkehautop.github.io/CausalStructures/reference/cgraph.md).

## Value

A `PAG` graph proxy.

## References

Zhang J (2008). “On the completeness of orientation rules for causal
discovery in the presence of latent confounders and selection bias.”
*Artificial Intelligence*, **172**(16-17), 1873–1896.

## Examples

``` r
if (julia_ready()) {
  mag <- cgraph(A %-->% B, B %-->% C, class = "MAG")
  mag_to_pag(mag)
}
#> PAG with 3 nodes and 2 edges:
#>   nodes: A, B, C
#>   edges:
#>     A o-o B, B o-o C
```
