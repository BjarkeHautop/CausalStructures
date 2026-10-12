# Create a causal graph

Builds a graph from edge expressions using the operators documented at
[edge-operators](https://bjarkehautop.github.io/CausalStructures/reference/edge-operators.md),
e.g. `A %-->% X + Y, X %-->% M %-->% Y`. A bare node name (or
`+`-combination of names) declares isolated node(s).

## Usage

``` r
cgraph(
  ...,
  spec = NULL,
  class = c("DAG", "UG", "PDAG", "CPDAG", "MPDAG", "ADMG", "AG", "MAG", "PAG", "UNKNOWN")
)
```

## Arguments

- ...:

  Edge expressions (see
  [edge-operators](https://bjarkehautop.github.io/CausalStructures/reference/edge-operators.md))
  and/or bare node declarations. Mutually exclusive with `spec`.

- spec:

  Graph specification string, for programmatic construction. Mutually
  exclusive with `...`.

- class:

  Graph class: `"DAG"`, `"UG"`, `"PDAG"`, `"CPDAG"`, `"MPDAG"`,
  `"ADMG"`, `"AG"`, `"MAG"`, `"PAG"`, or `"UNKNOWN"` (no structural
  constraints; accepts all edge types, including multiple edges between
  the same pair of nodes).

## Value

A Julia proxy object representing the graph.

## Details

For programmatic construction (e.g. from an edge list assembled at
runtime), pass a spec string directly via `spec` instead of `...`, using
the same syntax as the operators expand to (e.g.
`"A --> X + Y, X --> M --> Y"`).

## Examples

``` r
if (julia_ready()) {
  dag <- cgraph(A %-->% X + Y, X %-->% M %-->% Y, class = "DAG")
  cpdag <- cgraph(A %---% B %---% C, class = "CPDAG")

  # equivalent to the dag above, built from a spec string
  dag2 <- cgraph(spec = "A --> X + Y, X --> M --> Y", class = "DAG")

  cgraph(A %-->% B, A %<->% B, class = "UNKNOWN")
}
#> UNKNOWN with 2 nodes and 2 edges:
#>   nodes: A, B
#>   edges:
#>     A --> B, A <-> B
```
