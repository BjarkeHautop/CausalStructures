# Count and enumerate DAGs in a Markov equivalence class

`cg` (a PDAG, CPDAG, or MPDAG) represents a Markov equivalence class
(MEC) of DAGs. `enumerate_dags()` lists every DAG in that class;
`count_dags()` counts them without materializing them, which is much
cheaper and useful for sizing the problem before calling
`enumerate_dags()`, since a MEC can be very large.

## Usage

``` r
count_dags(cg)

enumerate_dags(cg)
```

## Arguments

- cg:

  A PDAG, CPDAG, or MPDAG created with
  [`cgraph()`](https://bjarkehautop.github.io/CausalStructures/reference/cgraph.md).

## Value

For `count_dags()`, an integer count. For `enumerate_dags()`, a list of
DAG proxies.

## Details

Both apply Meek closure to `cg` first to normalize it, then branch on
each undirected edge in lexicographic order, rejecting orientations that
would introduce a new v-structure or a directed cycle, and propagating
forced orientations via Meek's rules at each step (Chickering's (2002)
recursive listing algorithm).

## References

Chickering DM (2002). “Learning Equivalence Classes of Bayesian-Network
Structures.” *Journal of Machine Learning Research*, **2**, 445–498.

## Examples

``` r
if (julia_ready()) {
  pdag <- cgraph(A %---% B, B %---% C, class = "PDAG")
  count_dags(pdag)
}
#> [1] 3

if (julia_ready()) {
  pdag <- cgraph(A %---% B, B %---% C, class = "PDAG")
  enumerate_dags(pdag)
}
#> [[1]]
#> DAG with 3 nodes and 2 edges:
#>   nodes: A, B, C
#>   edges:
#>     A --> B, B --> C
#> 
#> [[2]]
#> DAG with 3 nodes and 2 edges:
#>   nodes: A, B, C
#>   edges:
#>     B --> A, B --> C
#> 
#> [[3]]
#> DAG with 3 nodes and 2 edges:
#>   nodes: A, B, C
#>   edges:
#>     B --> A, C --> B
#> 
```
