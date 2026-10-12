# Add or remove isolated nodes

`add_nodes()` returns a new graph of the same class with `nodes` added
as isolated nodes (nodes already present are ignored). `remove_nodes()`
returns a new graph with `nodes` and all their incident edges removed,
and errors if a node is not present.

## Usage

``` r
add_nodes(cg, nodes)

remove_nodes(cg, nodes)
```

## Arguments

- cg:

  A graph created with
  [`cgraph()`](https://bjarkehautop.github.io/CausalStructures/reference/cgraph.md),
  of any class.

- nodes:

  Character vector of node names.

## Value

A Julia proxy object representing the resulting graph.

## Examples

``` r
if (julia_ready()) {
  dag <- cgraph(A %-->% B)
  list(
    add_nodes = add_nodes(dag, "C"),
    remove_nodes = remove_nodes(dag, "B")
  )
}
#> $add_nodes
#> DAG with 3 nodes and 1 edge:
#>   nodes: A, B, C
#>   edges:
#>     A --> B
#> 
#> $remove_nodes
#> DAG with 1 node and 0 edges:
#>   nodes: A
#>   edges:
#>     (none)
#> 
```
