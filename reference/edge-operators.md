# Edge specification operators

Infix operators used inside
[`cgraph()`](https://bjarkehautop.github.io/CausalStructures/reference/cgraph.md),
[`add_edges()`](https://bjarkehautop.github.io/CausalStructures/reference/edge-mutation.md),
and
[`remove_edges()`](https://bjarkehautop.github.io/CausalStructures/reference/edge-mutation.md)
to specify edges, e.g. `A %-->% X + Y`. Multiple edges fan out from (or
into) a single marker with `+`: `A %-->% X + Y` means `A --> X` and
`A --> Y`; chaining connects consecutive nodes pairwise, so
`X %-->% M %-->% Y` means `X --> M` and `M --> Y`.

## Usage

``` r
lhs %-->% rhs

lhs %<--% rhs

lhs %---% rhs

lhs %<->% rhs

lhs %o->% rhs

lhs %<-o% rhs

lhs %o--% rhs

lhs %--o% rhs

lhs %o-o% rhs
```

## Arguments

- lhs, rhs:

  Node name(s): a bare symbol, a string, or a `+`-combination or
  [`c()`](https://rdrr.io/r/base/c.html) of either.

## Value

Not meaningful on its own; see the Description.

## Details

|          |                                     |
|----------|-------------------------------------|
| Operator | Meaning                             |
| `%-->%`  | directed, `src --> dst`             |
| `%<--%`  | directed, `dst --> src`             |
| `%---%`  | undirected                          |
| `%<->%`  | bidirected                          |
| `%o->%`  | partially directed, `src o-> dst`   |
| `%<-o%`  | partially directed, `dst o-> src`   |
| `%o--%`  | partially undirected, `src o-- dst` |
| `%--o%`  | partially undirected, `dst o-- src` |
| `%o-o%`  | partial (both ends circle)          |

These operators only make sense inside the `...` of
[`cgraph()`](https://bjarkehautop.github.io/CausalStructures/reference/cgraph.md),
[`add_edges()`](https://bjarkehautop.github.io/CausalStructures/reference/edge-mutation.md),
or
[`remove_edges()`](https://bjarkehautop.github.io/CausalStructures/reference/edge-mutation.md),
which capture their arguments unevaluated; they are not exported and are
not meant to be called directly.

## Examples

``` r
if (julia_ready()) {
  dag <- cgraph(A %-->% X + Y, X %-->% M %-->% Y)
  edges(dag)
}
#>   from to type
#> 1    A  X  -->
#> 2    A  Y  -->
#> 3    X  M  -->
#> 4    M  Y  -->
```
