# Add or remove edges

`add_edges()` and `remove_edges()` return a new graph of the same class
with the edges described by `...` added or removed, using the operators
documented at
[edge-operators](https://bjarkehautop.github.io/CausalStructures/reference/edge-operators.md)
(e.g. `B %-->% C, C %-->% D`); any isolated-node declarations in `...`
are ignored. `remove_edges()` errors if an edge in `...` is not present
in `cg`. For programmatic use, pass a spec string via `spec` instead of
`...`.

## Usage

``` r
add_edges(cg, ..., spec = NULL)

remove_edges(cg, ..., spec = NULL)
```

## Arguments

- cg:

  A graph created with
  [`cgraph()`](https://bjarkehautop.github.io/CausalStructures/reference/cgraph.md),
  of any class.

- ...:

  Edge expressions; see
  [edge-operators](https://bjarkehautop.github.io/CausalStructures/reference/edge-operators.md).
  Mutually exclusive with `spec`.

- spec:

  Edge specification string, for programmatic use. Mutually exclusive
  with `...`.

## Value

A Julia proxy object representing the resulting graph.

## Examples

``` r
if (julia_ready()) {
  dag <- cgraph(A %-->% B)
  list(
    add_edges = add_edges(dag, B %-->% C),
    remove_edges = remove_edges(dag, A %-->% B)
  )
}
#> $add_edges
#> DAG with 3 nodes and 2 edges:
#>   nodes: A, B, C
#>   edges:
#>     A --> B, B --> C
#> 
#> $remove_edges
#> DAG with 2 nodes and 0 edges:
#>   nodes: A, B
#>   edges:
#>     (none)
#> 
```
