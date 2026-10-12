# Test whether two graphs are Markov equivalent

Returns `TRUE` if `g1` and `g2` (both DAGs, or both MAGs) belong to the
same Markov equivalence class, i.e. they impose the same
(conditional-)independence constraints.

## Usage

``` r
markov_equivalent(g1, g2)
```

## Arguments

- g1, g2:

  Graphs to compare, created with
  [`cgraph()`](https://bjarkehautop.github.io/CausalStructures/reference/cgraph.md).
  Both must be DAGs, or both must be MAGs.

## Value

A logical scalar.

## Details

For DAGs, this holds iff they share the same skeleton and the same set
of v-structures (unshielded colliders `a --> b <-- c` with `a`, `c`
non-adjacent) - the Verma-Pearl characterization. For MAGs, this holds
iff they map to the same PAG.

## References

Verma T, Pearl J (1990). “Equivalence and synthesis of causal models.”
In *Proceedings of UAI 1990*.

Ali RA, Richardson TS, Spirtes P (2009). “Markov equivalence for
ancestral graphs.” *Annals of Statistics*, **37**(5B), 2808–2837.

## Examples

``` r
if (julia_ready()) {
  g1 <- cgraph(A %-->% B, C %-->% B)
  g2 <- cgraph(A %-->% B, C %-->% B)
  g3 <- cgraph(A %-->% B, B %-->% C)
  list(
    same_skeleton_same_v_structures = markov_equivalent(g1, g2),
    different_v_structures = markov_equivalent(g1, g3)
  )
}
#> $same_skeleton_same_v_structures
#> [1] TRUE
#> 
#> $different_v_structures
#> [1] FALSE
#> 
```
