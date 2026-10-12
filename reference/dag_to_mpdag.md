# Convert a DAG to its MPDAG

Returns the MPDAG representing the DAGs Markov equivalent to `cg`: the
CPDAG of `cg` closed under
[`meek_closure()`](https://bjarkehautop.github.io/CausalStructures/reference/meek_closure.md)'s
rules R1-R4.

## Usage

``` r
dag_to_mpdag(cg)
```

## Arguments

- cg:

  A DAG created with
  [`cgraph()`](https://bjarkehautop.github.io/CausalStructures/reference/cgraph.md).

## Value

An `MPDAG` graph proxy.

## References

Meek C (1995). “Causal inference and causal explanation with background
knowledge.” In *Proceedings of UAI 1995*, 403–410.

## Examples

``` r
if (julia_ready()) {
  dag <- cgraph(A %-->% B, B %-->% C)
  dag_to_mpdag(dag)
}
#> MPDAG with 3 nodes and 2 edges:
#>   nodes: A, B, C
#>   edges:
#>     A --- B, B --- C
```
