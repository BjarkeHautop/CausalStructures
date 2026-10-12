# Identify an interventional distribution

`id()` returns the interventional distribution `P(y | do(x))`, rendered
as a formula in terms of the observational distribution (Shpitser &
Pearl's ID algorithm), or `NULL` if the effect is not identifiable.
`idc()` additionally conditions on `given` (the IDC algorithm), reducing
to `id()` when `given` is empty.

## Usage

``` r
id(cg, x, y)

idc(cg, x, y, given = character())
```

## Arguments

- cg:

  A DAG or ADMG created with
  [`cgraph()`](https://bjarkehautop.github.io/CausalStructures/reference/cgraph.md).

- x, y:

  Intervention (exposure) and outcome node name, or character vector of
  node names. Must be disjoint from each other (and from `given`, for
  `idc()`).

- given:

  Character vector of node names to additionally condition on (`idc()`
  only).

## Value

A character scalar with the rendered formula, or `NULL` if the effect is
not identifiable.

## Details

Bidirected edges represent latent confounders. To identify an effect in
a DAG with unobserved variables, project them out first with
[`latent_project()`](https://bjarkehautop.github.io/CausalStructures/reference/latent_project.md).

The rendered formula may mention variables outside `x`/`y`/`given`: the
algorithm can enlarge the intervention set whenever doing so provably
changes nothing, and the result is then a function of those extra values
too. This binding renders the resulting `Estimand` as a formatted
character string; it does not expose the underlying symbolic-algebra
representation (`Prob`, `Marginal`, `Product`, `Quotient` in
CausalStructures.jl) for programmatic manipulation.

## References

Shpitser I, Pearl J (2008). “Complete Identification Methods for the
Causal Hierarchy.” *Journal of Machine Learning Research*, **9**,
1941–1979.

Tian J, Pearl J (2002). “A General Identification Condition for Causal
Effects.” In *Proceedings of the 18th National Conference on Artificial
Intelligence (AAAI 2002)*, 567–573.

## Examples

``` r
if (julia_ready()) {
  # Back-door adjustment, recovered as the g-formula
  dag <- cgraph(Z %-->% X, X %-->% Y, Z %-->% Y)
  id(dag, "X", "Y")
}
#> [1] "Σ_{Z} P(Y | X, Z) P(Z)"

if (julia_ready()) {
  # Front-door graph: X and Y are confounded, but the effect is still
  # identifiable through the mediator M
  admg <- cgraph(X %-->% M, M %-->% Y, X %<->% Y, class = "ADMG")
  id(admg, "X", "Y")
}
#> [1] "Σ_{M} P(M | X) (Σ_{X'} P(X') P(Y | M, X'))"

if (julia_ready()) {
  # The bow arc: the canonical unidentifiable effect
  bow <- cgraph(X %-->% Y, X %<->% Y, class = "ADMG")
  is.null(id(bow, "X", "Y"))
}
#> [1] TRUE

if (julia_ready()) {
  dag <- cgraph(Z %-->% X, X %-->% Y, Z %-->% Y)
  idc(dag, "X", "Y", given = "Z")
}
#> [1] "P(Y | X, Z)"
```
