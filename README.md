
<!-- README.md is generated from README.Rmd. Please edit that file -->

# CausalStructures

<!-- badges: start -->

[![Codecov test
coverage](https://codecov.io/gh/BjarkeHautop/CausalStructures/graph/badge.svg)](https://app.codecov.io/gh/BjarkeHautop/CausalStructures)
[![R-CMD-check](https://github.com/BjarkeHautop/CausalStructures/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/BjarkeHautop/CausalStructures/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

CausalStructures is an R binding to the Julia package
[CausalStructures.jl](https://github.com/BjarkeHautop/CausalStructures.jl),
for building, querying, and transforming causal graphs (DAGs, PDAGs,
ADMGs, ancestral graphs, PAGs, …) and reading off causal-identification
results (adjustment sets, front-door sets, instruments, …) from them.

Julia is embedded directly in the R process via
[JuliaCall](https://non-contradiction.github.io/JuliaCall/).

## Installation

Install CausalStructures from GitHub:

``` r
pak::pak("BjarkeHautop/CausalStructures")
```

CausalStructures requires [Julia](https://julialang.org/) (\>= 1.10) See
[here](https://julialang.org/downloads/) for the recommended way to
install Julia. Alternatively Julia can be installed via
`JuliaCall::install:julia()`.

You can then run `CausalStructures::setup()` to download the Julia
packages needed.

## Graph types

The following graph types are supported, shown here following the
abstract type hierarchy from `CausalStructures.jl`:

    CausalGraph
    ├─ DAG            Directed Acyclic Graph
    ├─ UG             Undirected Graph
    ├─ AbstractPDAG   All Partially Directed Acyclic Graphs
    │  ├─ PDAG        Partially Directed Acyclic Graph
    │  ├─ CPDAG       Completed Partially Directed Acyclic Graph
    │  └─ MPDAG       Maximally Oriented Partially Directed Acyclic Graph
    ├─ ADMG           Acyclic Directed Mixed Graph
    ├─ AbstractAG     All Ancestral Graphs
    │  ├─ AG          Ancestral Graph
    │  └─ MAG         Maximal Ancestral Graph
    ├─ PAG            Partial Ancestral Graph
    └─ UNKNOWN        No structural constraints

Each graph class encodes structural constraints, such as no cycles,
closed under Meek’s rules, etc., and these constraints are verified on
construction.

## Example

``` r
library(CausalStructures)

dag <- cgraph("A --> X + Y, X --> M --> Y")
dag
#> DAG with 4 nodes and 4 edges:
#>   nodes: A, M, X, Y
#>   edges:
#>     A --> X, A --> Y, X --> M, M --> Y

parents(dag, "Y")
#> [1] "A" "M"
adjustment_set(dag, "X", "Y")
#> [1] "A"

plot(dag)
```

<img src="man/figures/README-example-1.png" alt="" width="100%" />

Convert it to the CPDAG representing its Markov equivalence class:

``` r
cpdag <- dag_to_cpdag(dag)
plot(cpdag)
```

<img src="man/figures/README-cpdag-1.png" alt="" width="100%" />

See the [pkgdown site](https://bjarkehautop.github.io/CausalStructures/)
for the documentation

## Multi-threading

Some algorithms (`all_backdoor_sets()`, `all_adjustment_sets()`,
`all_frontdoor_sets()`, `all_iv_sets()`, `enumerate_dags()`,
`count_dags()`) can use multiple threads. To do so you need to set the
`JULIA_NUM_THREADS` environment variable *before* calling any function:

``` r
Sys.setenv(JULIA_NUM_THREADS = "4")
```
