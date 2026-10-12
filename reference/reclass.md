# Reclassify a graph

Returns a new graph of class `class` with the same nodes and edges as
`cg`. Errors if the edges violate the structural constraints of `class`.

## Usage

``` r
reclass(
  cg,
  class = c("DAG", "UG", "PDAG", "CPDAG", "MPDAG", "ADMG", "AG", "MAG", "PAG", "UNKNOWN")
)
```

## Arguments

- cg:

  A graph created with
  [`cgraph()`](https://bjarkehautop.github.io/CausalStructures/reference/cgraph.md),
  of any class.

- class:

  Target graph class: `"DAG"`, `"UG"`, `"PDAG"`, `"CPDAG"`, `"MPDAG"`,
  `"ADMG"`, `"AG"`, `"MAG"`, `"PAG"`, or `"UNKNOWN"` (no structural
  constraints; accepts all edge types).

## Value

A Julia proxy object representing the reclassified graph.

## Examples

``` r
if (julia_ready()) {
  dag <- cgraph(A %-->% B, class = "UNKNOWN")
  reclassed <- reclass(dag, class = "DAG")
  is_dag(reclassed)
}
#> [1] TRUE
```
