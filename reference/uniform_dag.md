# Generate a uniformly random DAG

Generates a random
[DAG](https://bjarkehautop.github.io/CausalStructures/reference/cgraph.md)
on `n` observed nodes named `V1, ..., Vn`, sampled uniformly at random
from the space of all labelled DAGs on `n` nodes, using the
recursive-enumeration algorithm of Kuipers & Moffa (2015).

## Usage

``` r
uniform_dag(n, seed = NULL)
```

## Arguments

- n:

  Number of observed nodes.

- seed:

  Optional integer seed for reproducibility.

## Value

A Julia proxy object representing the graph.

## Details

Unlike
[`generate_graph()`](https://bjarkehautop.github.io/CausalStructures/reference/generate_graph.md),
which samples edges independently (uniform over graphs of a given
size/density but *not* uniform over the space of DAGs), this samples
uniformly over the full space of labelled DAGs on `n` nodes.

## Examples

``` r
if (julia_ready()) {
  dag <- uniform_dag(6, seed = 1405)
  dag
}
#> DAG with 6 nodes and 11 edges:
#>   nodes: V1, V2, V3, V4, V5, V6
#>   edges:
#>     V2 --> V6, V3 --> V6, V4 --> V6, V1 --> V6, V3 --> V2, … (6 more)
```
