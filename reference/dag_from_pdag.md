# Extend a PDAG to a consistent DAG

Orients every undirected edge of the PDAG-family graph `cg`, using the
Dor-Tarsi algorithm: repeatedly find a sink node (no directed children,
whose undirected neighbors form a clique), orient all its undirected
edges toward it, and remove it. Errors if no valid DAG extension exists.

## Usage

``` r
dag_from_pdag(cg)
```

## Arguments

- cg:

  A PDAG-family (PDAG, CPDAG, MPDAG) graph created with
  [`cgraph()`](https://bjarkehautop.github.io/CausalStructures/reference/cgraph.md).

## Value

A `DAG` graph proxy.

## References

Dor D, Tarsi M (1992). “A simple algorithm to construct a consistent
extension of a partially oriented graph.” Technical Report R-185,
Cognitive Systems Laboratory, UCLA.

## Examples

``` r
if (julia_ready()) {
  pdag <- cgraph(A %---% B, B %---% C, class = "PDAG")
  dag_from_pdag(pdag)
}
#> DAG with 3 nodes and 2 edges:
#>   nodes: A, B, C
#>   edges:
#>     A --> B, B --> C
```
