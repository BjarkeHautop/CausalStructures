# Compute a graph layout

Computes node coordinates for
[`plot.cgraph()`](https://bjarkehautop.github.io/CausalStructures/reference/plot.md).

## Usage

``` r
cgraph_layout(
  x,
  method = NULL,
  direction = c("right", "down", "up", "left"),
  ...
)
```

## Arguments

- x:

  A graph created with
  [`cgraph()`](https://bjarkehautop.github.io/CausalStructures/reference/cgraph.md),
  of any class.

- method:

  Character string specifying the layout method:

  - `"sugiyama"`: layered/hierarchical layout, from the
    [Sugiyama.jl](https://github.com/BjarkeHautop/Sugiyama.jl) package.
    Every edge is layered from its first to its second node (`A --> B`
    puts `A` before `B`), and any cycles are broken, so it works for
    every graph class.

  - `"stress"`: stress majorization (Gansner, Koren and North, 2005),
    starting from classical multidimensional scaling. A good
    general-purpose choice - well-spaced and deterministic for a given
    graph.

  - `"shell"`: nodes evenly spaced on a circle, in
    [`nodes()`](https://bjarkehautop.github.io/CausalStructures/reference/graph-queries.md)
    order.

  - `"squaregrid"`: nodes on a square grid, row by row in
    [`nodes()`](https://bjarkehautop.github.io/CausalStructures/reference/graph-queries.md)
    order.

  Defaults (`NULL`) to `"sugiyama"` when `x` was constructed (or
  [`reclass()`](https://bjarkehautop.github.io/CausalStructures/reference/reclass.md)ed)
  as a `DAG`, `"stress"` otherwise. This checks `x`'s actual class, not
  its edge structure (see
  [predicates](https://bjarkehautop.github.io/CausalStructures/reference/predicates.md)) -
  a `PDAG` with only directed, acyclic edges still defaults to
  `"stress"`.

- direction:

  For `"sugiyama"`, which way the layers flow: `"right"` (the default,
  as in CausalStructures.jl), `"down"`, `"up"` or `"left"`.

- ...:

  Ignored, so that
  [`plot.cgraph()`](https://bjarkehautop.github.io/CausalStructures/reference/plot.md)
  can pass its `...` through.

## Value

A `data.frame` with columns `name`, `x`, and `y`.

## See also

Other plotting:
[`plot.cgraph()`](https://bjarkehautop.github.io/CausalStructures/reference/plot.md),
[`plot_default_options()`](https://bjarkehautop.github.io/CausalStructures/reference/plot_default_options.md),
[`plot_options()`](https://bjarkehautop.github.io/CausalStructures/reference/plot_options.md)

## Examples

``` r
if (julia_ready()) {
  dag <- cgraph(A %-->% B, B %-->% C)
  cgraph_layout(dag)
  cgraph_layout(dag, method = "stress")
}
#>   name            x             y
#> 1    A  1.00000e+00 -8.603189e-09
#> 2    B  5.85951e-17  1.720638e-08
#> 3    C -1.00000e+00 -8.603189e-09
```
