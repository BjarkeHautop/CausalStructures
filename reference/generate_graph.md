# Generate a random graph

Generates a random graph on `n` observed nodes named `V1, ..., Vn`.
Edges are sampled uniformly at random over all possible pairs using
Erdős–Rényi and oriented by a random topological ordering, guaranteeing
acyclicity. This samples uniformly over graphs of a given size/density,
but *not* uniformly over the space of DAGs (some DAGs correspond to more
topological orderings than others). For an exact uniform draw from all
labelled DAGs on `n` nodes regardless of edge count, use
[`uniform_dag()`](https://bjarkehautop.github.io/CausalStructures/reference/uniform_dag.md)
instead.

## Usage

``` r
generate_graph(
  n,
  m = NULL,
  p = NULL,
  class = c("DAG", "CPDAG", "ADMG", "MAG", "PAG"),
  latents = 0,
  seed = NULL
)
```

## Arguments

- n:

  Number of observed nodes.

- m:

  Number of edges (supply exactly one of `m` and `p`); drawn from the
  full `n + latents` node set when `latents > 0`.

- p:

  Edge probability (supply exactly one of `m` and `p`); applied to the
  full `n + latents` node set when `latents > 0`.

- class:

  Graph class: `"DAG"`, `"CPDAG"`, `"ADMG"`, `"MAG"`, or `"PAG"`.

- latents:

  Number of latent nodes to sample alongside the `n` observed nodes and
  then project out. Only supported for `class = "ADMG"`, `"MAG"`, or
  `"PAG"`; must be `0` (default) otherwise.

- seed:

  Optional integer seed for reproducibility.

## Value

A Julia proxy object representing the graph.

## Details

Exactly one of `m` (exact edge count) or `p` (edge probability) must be
given. For `class = "CPDAG"`, the sampled DAG is converted with
[`dag_to_cpdag()`](https://bjarkehautop.github.io/CausalStructures/reference/dag_to_cpdag.md).
For `class = "ADMG"`, `"MAG"`, or `"PAG"`, `latents` additional nodes
`L1, ..., Lk` are added to the underlying random DAG and then
marginalized out via
[`latent_project()`](https://bjarkehautop.github.io/CausalStructures/reference/latent_project.md);
`m`/`p` are applied to the full `n + latents` node set before
projection. `latents` must be `0` (the default) for `class = "DAG"` or
`class = "CPDAG"`.

Unlike ADMGs, MAGs (and PAGs, which are derived from a sampled MAG)
additionally require the *ancestral* constraint (no bidirected edge
between a node and its own ancestor), which a naive latent projection
can violate whenever a marginalized common cause and a separate directed
path connect the same pair of observed nodes. For `class = "MAG"` or
`class = "PAG"`, each candidate is checked and, if invalid, resampled
(up to an internal retry limit) until a valid MAG is found; this errors
if none is found, which can happen for very dense graphs with many
latents. For `class = "PAG"`, the resulting MAG is then converted to its
equivalence class with
[`mag_to_pag()`](https://bjarkehautop.github.io/CausalStructures/reference/mag_to_pag.md).

## Examples

``` r
if (julia_ready()) {
  cg <- generate_graph(4, m = 3, seed = 1405)
  cg
}
#> DAG with 4 nodes and 3 edges:
#>   nodes: V1, V2, V3, V4
#>   edges:
#>     V3 --> V4, V4 --> V1, V4 --> V2

if (julia_ready()) {
  admg <- generate_graph(6, p = 0.3, class = "ADMG", latents = 2, seed = 1405)
  admg
}
#> ADMG with 6 nodes and 4 edges:
#>   nodes: V1, V2, V3, V4, V5, V6
#>   edges:
#>     V2 --> V1, V3 --> V1, V4 --> V1, V5 --> V2

if (julia_ready()) {
  pag <- generate_graph(6, p = 0.3, class = "PAG", latents = 2, seed = 1405)
  pag
}
#> PAG with 6 nodes and 4 edges:
#>   nodes: V1, V2, V3, V4, V5, V6
#>   edges:
#>     V2 o-> V1, V3 o-> V1, V4 o-> V1, V2 o-o V5
```
