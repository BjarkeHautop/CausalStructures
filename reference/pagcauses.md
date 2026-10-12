# Find every possible causal effect in a PAG (PAGcauses)

Returns every valid adjustment set relative to `(x, y)` in some MAG
consistent with the PAG `cg`: the set of possible causal effects of `x`
on `y` identifiable via covariate adjustment, found without enumerating
MAGs (PAGcauses, Algorithm 1). If `x` is not a possible ancestor of `y`,
returns an empty list (no causal effect). If the causal effect is
already identifiable directly in `cg`
([`backdoor_set()`](https://bjarkehautop.github.io/CausalStructures/reference/backdoor_set.md)),
returns that single set. Otherwise, this searches every valid local
structure at `x`
([`possible_local_structures()`](https://bjarkehautop.github.io/CausalStructures/reference/possible_local_structures.md))
and its maximal local MAG
([`maximal_local_mag()`](https://bjarkehautop.github.io/CausalStructures/reference/maximal_local_mag.md))
for potential adjustment sets.

## Usage

``` r
pagcauses(cg, x, y)
```

## Arguments

- cg:

  A PAG created with
  [`cgraph()`](https://bjarkehautop.github.io/CausalStructures/reference/cgraph.md).

- x, y:

  Exposure and outcome node names.

## Value

List of character vectors (empty list if `x` has no possible causal
effect on `y`).

## Details

Assumes `cg` has no selection bias (no undirected edges).

## References

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
  pagcauses(pag, "X", "Y")
}
#> [[1]]
#> character(0)
#> 
#> [[2]]
#> [1] "A" "B"
#> 
#> [[3]]
#> [1] "C"
#> 
#> [[4]]
#> [1] "B" "C"
#> 
#> [[5]]
#> [1] "A" "B" "C"
#> 
```
