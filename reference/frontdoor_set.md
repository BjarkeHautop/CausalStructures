# Find a frontdoor adjustment set

Returns a set `Z` with `include ⊆ Z ⊆ restrict` satisfying all three
front-door conditions (Algorithm 1 of the reference below) for the
causal effect of `x` on `y`; validate a candidate set directly with
[`is_valid_frontdoor()`](https://bjarkehautop.github.io/CausalStructures/reference/is_valid_frontdoor.md).

## Usage

``` r
frontdoor_set(cg, x, y, include = character(), restrict = NULL)
```

## Arguments

- cg:

  A DAG or ADMG created with
  [`cgraph()`](https://bjarkehautop.github.io/CausalStructures/reference/cgraph.md).
  For an ADMG, the backdoor and condition-3 checks use m-separation,
  with bidirected edges treated as latent-confounder edges (a spouse
  contributes an arrowhead into a node just like a directed parent
  does).

- x, y:

  Exposure and outcome node name, or character vector of node names.

- include:

  Character vector of nodes forced into the set.

- restrict:

  Character vector of candidate nodes the set is drawn from. `NULL`
  (default) allows every node except `x` and `y`.

## Value

Character vector with a valid frontdoor set, or `NULL` if none exists.

## References

Jeong H, Tian J, Bareinboim E (2022). “Finding and Listing Front-door
Adjustment Sets.” In Koyejo S, Mohamed S, Agarwal A, Belgrave D, Cho K,
Oh A (eds.), *Advances in Neural Information Processing Systems*, volume
35, 33173–33185.
<https://proceedings.neurips.cc/paper_files/paper/2022/file/d67ac621411d6fa4dca682ce62f84ea7-Paper-Conference.pdf>.

## Examples

``` r
if (julia_ready()) {
  dag <- cgraph(U %-->% X, U %-->% Y, X %-->% Z, Z %-->% Y)
  list(
    default = frontdoor_set(dag, "X", "Y"), # Z mediates X -> Y
    restricted = frontdoor_set(dag, "X", "Y", restrict = "Z")
  )
}
#> $default
#> [1] "Z"
#> 
#> $restricted
#> [1] "Z"
#> 
```
