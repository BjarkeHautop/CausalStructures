# Graph class predicates

Test which class a graph belongs to (`is_dag()`, `is_pdag()`,
`is_cpdag()`, `is_mpdag()`, `is_ug()`, `is_admg()`, `is_ag()`,
`is_mag()`, `is_pag()`) or structural properties (`is_simple()`,
`is_acyclic()`).

## Usage

``` r
is_dag(cg)

is_pdag(cg)

is_cpdag(cg)

is_mpdag(cg)

is_ug(cg)

is_admg(cg)

is_ag(cg)

is_mag(cg)

is_pag(cg)

is_simple(cg)

is_acyclic(cg)
```

## Arguments

- cg:

  A graph created with
  [`cgraph()`](https://bjarkehautop.github.io/CausalStructures/reference/cgraph.md),
  of any class.

## Value

A logical scalar.

## Details

These test the actual edge structure of `cg`, independent of the `class`
it has.

## Examples

``` r
if (julia_ready()) {
  dag <- cgraph(A %-->% B, class = "PDAG")
  list(
    is_dag = is_dag(dag), # TRUE, even though assigned PDAG
    is_ug = is_ug(dag),
    is_acyclic = is_acyclic(dag)
  )
}
#> $is_dag
#> [1] TRUE
#> 
#> $is_ug
#> [1] FALSE
#> 
#> $is_acyclic
#> [1] TRUE
#> 
```
