# Test d-separation

Two nodes are d-separated given a conditioning set `given` if every path
between them is blocked: a path is blocked if it contains either a
non-collider node in `given`, or a collider node (and all its
descendants) not in `given`.

## Usage

``` r
d_separated(cg, x, y, given = character())
```

## Arguments

- cg:

  A DAG or PDAG-family (PDAG, CPDAG, MPDAG) graph created with
  [`cgraph()`](https://bjarkehautop.github.io/CausalStructures/reference/cgraph.md).

- x, y:

  Node name, or character vector of node names (to test whether the two
  *sets* are separated).

- given:

  Character vector of conditioning node names (may be empty).

## Value

`TRUE` if `x` and `y` are d-separated given `given`.

## Examples

``` r
if (julia_ready()) {
  chain <- cgraph(A %-->% B, B %-->% C)
  list(
    open = d_separated(chain, "A", "C"), # chain A --> B --> C is open
    blocked = d_separated(chain, "A", "C", "B") # conditioning on B
  )
}
#> $open
#> [1] FALSE
#> 
#> $blocked
#> [1] TRUE
#> 

if (julia_ready()) {
  collider <- cgraph(A %-->% C, B %-->% C)
  list(
    blocked = d_separated(collider, "A", "B"), # collider is blocked
    opened = d_separated(collider, "A", "B", "C") # conditioning opens it
  )
}
#> $blocked
#> [1] TRUE
#> 
#> $opened
#> [1] FALSE
#> 
```
