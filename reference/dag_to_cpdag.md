# Convert a DAG to its CPDAG

Returns the CPDAG representing the Markov equivalence class (MEC) of the
DAG `cg`: unshielded colliders (v-structures) determine which edges are
compelled, an initial PDAG is built from the skeleton with those
orientations, and
[`meek_closure()`](https://bjarkehautop.github.io/CausalStructures/reference/meek_closure.md)
propagates the rest.

## Usage

``` r
dag_to_cpdag(cg)
```

## Arguments

- cg:

  A DAG created with
  [`cgraph()`](https://bjarkehautop.github.io/CausalStructures/reference/cgraph.md).

## Value

A `CPDAG` graph proxy.

## Examples

``` r
if (julia_ready()) {
  dag <- cgraph(A %-->% B, B %-->% C)
  dag_to_cpdag(dag)
}
#> CPDAG with 3 nodes and 2 edges:
#>   nodes: A, B, C
#>   edges:
#>     A --- B, B --- C
```
