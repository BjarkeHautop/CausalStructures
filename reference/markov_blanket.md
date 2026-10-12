# Markov blanket of a node

Returns the Markov blanket of `node` in `cg`: the minimal set of nodes
that renders `node` conditionally independent of every other node in the
graph.

## Usage

``` r
markov_blanket(cg, node)
```

## Arguments

- cg:

  A DAG, PDAG-family (PDAG, CPDAG, MPDAG), ADMG, or AG-family (AG, MAG)
  graph created with
  [`cgraph()`](https://bjarkehautop.github.io/CausalStructures/reference/cgraph.md).

- node:

  Node name.

## Value

Sorted character vector of node names.

## Details

The Markov blanket returns the following, depending on the graph class:

- **DAG**: parents, children, and co-parents (other parents of `node`'s
  children).

- **PDAG-family** (PDAG, CPDAG, MPDAG): the DAG set, plus undirected
  neighbors.

- **ADMG**: the union of the parents of every node in `node`'s district
  (excluding `node` itself).

- **AG-family** (AG, MAG): parents, children, co-parents, spouses, and
  undirected neighbors.

## Examples

``` r
if (julia_ready()) {
  dag <- cgraph(A %-->% B, B %-->% C, D %-->% C)
  list(
    blanket_of_b = markov_blanket(dag, "B"), # A, C, D (D is a co-parent)
    blanket_of_c = markov_blanket(dag, "C")
  )
}
#> $blanket_of_b
#> [1] "A" "C" "D"
#> 
#> $blanket_of_c
#> [1] "B" "D"
#> 
```
