# Test m-separation

Generalizes d-separation to graphs with bidirected and undirected edges;
for a DAG, m-separation is equivalent to
[`d_separated()`](https://bjarkehautop.github.io/CausalStructures/reference/d_separated.md).
For a PAG, circle marks collapse to tails, as for
[possible_ancestors()](https://bjarkehautop.github.io/CausalStructures/reference/possible-queries.md).

## Usage

``` r
m_separated(cg, x, y, given = character())
```

## Arguments

- cg:

  A DAG, ADMG, AG-family (AG, MAG), or PAG graph created with
  [`cgraph()`](https://bjarkehautop.github.io/CausalStructures/reference/cgraph.md).

- x, y:

  Node name, or character vector of node names (to test whether the two
  *sets* are separated).

- given:

  Character vector of conditioning node names (may be empty).

## Value

`TRUE` if `x` and `y` are m-separated given `given`.

## Examples

``` r
if (julia_ready()) {
  admg <- cgraph(A %-->% B, A %<->% C, class = "ADMG")
  list(
    open = m_separated(admg, "B", "C"), # bidirected edge at A connects
    blocked = m_separated(admg, "B", "C", "A") # conditioning on A blocks
  )
}
#> $open
#> [1] FALSE
#> 
#> $blocked
#> [1] TRUE
#> 

if (julia_ready()) {
  pag <- cgraph(A %o->% B, C %o->% B, class = "PAG")
  m_separated(pag, "A", "C")
}
#> [1] TRUE
```
