
<!-- README.md is generated from README.Rmd. Please edit that file -->

# CausalStructures

<!-- badges: start -->

[![Codecov test
coverage](https://codecov.io/gh/BjarkeHautop/CausalStructures/graph/badge.svg)](https://app.codecov.io/gh/BjarkeHautop/CausalStructures)
[![R-CMD-check](https://github.com/BjarkeHautop/CausalStructures/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/BjarkeHautop/CausalStructures/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

CausalStructures is an R binding to the Julia package
[CausalStructures.jl](https://github.com/BjarkeHautop/CausalStructures.jl),
for representing, validating, and reasoning about causal graphs

## Installation

Install CausalStructures from GitHub:

``` r
pak::pak("BjarkeHautop/CausalStructures")
```

Installing CausalStructures requires [Julia](https://julialang.org/)
(\>= 1.13); see <https://julialang.org/install/> for the recommended way
to install Julia. The first installation takes a few minutes while Julia
downloads and compiles the dependencies. Set the `JULIA` environment
variable to the path of a `julia` binary to use a Julia other than the
one on the `PATH`.

The compiled library uses the runtime of the Julia that built it, so
reinstall CausalStructures if that Julia is removed (for example by a
`juliaup` update).

## Graph types

The following graph types are supported, shown here following the
abstract type hierarchy from CausalStructures.jl:

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

First, we define a causal graph using the `cgraph()` function.
`cgraph("A --> X + Y, X --> M --> Y")`

``` r
library(CausalStructures)

dag <- cgraph("A --> X + Y, X --> M --> Y")

# Alternatively, wrap the edges in %...%, and then not use a string:
cgraph(A %-->% X + Y, X %-->% M %-->% Y)
#> DAG with 4 nodes and 4 edges:
#>   nodes: A, M, X, Y
#>   edges:
#>     A --> X, A --> Y, X --> M, M --> Y
```

You can then run a number of queries and transformations on the causal
graph:

``` r
parents(dag, "Y")
#> [1] "A" "M"
adjustment_set(dag, "X", "Y")
#> [1] "A"

cpdag <- dag_to_cpdag(dag)
cpdag
#> CPDAG with 4 nodes and 4 edges:
#>   nodes: A, M, X, Y
#>   edges:
#>     A --- X, M --- X, M --> Y, A --> Y
```

See the [pkgdown site](https://bjarkehautop.github.io/CausalStructures/)
for the full documentation.

## Multi-threading

Some algorithms (`all_backdoor_sets()`, `all_adjustment_sets()`,
`all_frontdoor_sets()`, `all_iv_sets()`, `enumerate_dags()`,
`count_dags()`) can use multiple threads. To do so, set the
`JULIA_NUM_THREADS` environment variable (a number, or `"auto"` for one
per core) *before* loading the package, for example in your `.Renviron`
file or with

``` r
Sys.setenv(JULIA_NUM_THREADS = "4")
library(CausalStructures)
```
