# Build the maximal local MAG for a local structure

Returns the maximal local MAG for the local structure `c` at `x` in the
PAG `cg`: `cg` with a bidirected edge from `x` to every node in `c` and
a directed edge from `x` to every other circle-marked neighbor, treated
as local background knowledge and closed under the corresponding rule
set. `c` should be a valid local structure, i.e. an entry of
[`possible_local_structures()`](https://bjarkehautop.github.io/CausalStructures/reference/possible_local_structures.md)`(cg, x)`;
passing an invalid one gives an unsound result. The returned graph may
still contain circles, which is why it is returned as class `"UNKNOWN"`
rather than validated as a MAG or PAG.

## Usage

``` r
maximal_local_mag(cg, x, c)
```

## Arguments

- cg:

  A PAG created with
  [`cgraph()`](https://bjarkehautop.github.io/CausalStructures/reference/cgraph.md).

- x:

  Node name.

- c:

  Character vector of node names: a valid local structure at `x`.

## Value

A Julia proxy object representing the resulting `"UNKNOWN"` graph.

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
  mag <- cgraph(
    A %<->% X, B %-->% X, A %<->% B, X %-->% Y,
    class = "MAG"
  )
  pag <- mag_to_pag(mag)
  maximal_local_mag(pag, "X", "A")
}
#> UNKNOWN with 4 nodes and 4 edges:
#>   nodes: A, B, X, Y
#>   edges:
#>     A o-> B, A o-> X, X --> B, X --> Y
```
