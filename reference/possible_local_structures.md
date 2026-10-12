# Enumerate valid local structures at a node of a PAG

Returns every valid local structure at `x` in the PAG `cg`: each entry
is a subset of `x`'s circle-marked neighbors for which a MAG consistent
with `cg` exists with a bidirected edge to every node in the subset and
a directed edge away from `x` to every other circle-marked neighbor.
Pair an entry with
[`maximal_local_mag()`](https://bjarkehautop.github.io/CausalStructures/reference/maximal_local_mag.md)
to get the corresponding graph; this is the graph-only ingredient
[`pagcauses()`](https://bjarkehautop.github.io/CausalStructures/reference/pagcauses.md)
enumerates local structures with.

## Usage

``` r
possible_local_structures(cg, x)
```

## Arguments

- cg:

  A PAG created with
  [`cgraph()`](https://bjarkehautop.github.io/CausalStructures/reference/cgraph.md).

- x:

  Node name.

## Value

List of character vectors, one per valid local structure.

## Details

Assumes `cg` has no selection bias (no undirected edges).

## References

Wang T, Qin T, Zhou Z (2023). “Sound and complete causal identification
with latent variables given local background knowledge.” *Artificial
Intelligence*, **322**, 103964.

Wang T, Tao L, Qin T, Zhou Z (2025). “Estimating possible causal effects
with latent variables via adjustment and novel rule orientation.”
*Artificial Intelligence*, **347**, 104387.

## Examples

``` r
if (julia_ready()) {
  pag <- cgraph(
    X %o->% Y, X %o->% C, X %o->% A, Y %o-o% C, C %o-o% A,
    B %o->% C, B %o->% Y, B %o->% A,
    class = "PAG"
  )
  possible_local_structures(pag, "X")
}
#> [[1]]
#> character(0)
#> 
#> [[2]]
#> [1] "A"
#> 
#> [[3]]
#> [1] "C"
#> 
#> [[4]]
#> [1] "A" "C"
#> 
#> [[5]]
#> [1] "Y"
#> 
#> [[6]]
#> [1] "C" "Y"
#> 
```
