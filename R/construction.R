# --- Construction ------------------------------------------------------------

#' Create a causal graph
#'
#' Builds a graph from edge expressions using the operators documented at
#' [edge-operators], e.g. `A %-->% X + Y, X %-->% M %-->% Y`. A bare node
#' name (or `+`-combination of names) declares isolated node(s).
#'
#' For programmatic construction (e.g. from an edge list assembled at
#' runtime), pass a spec string directly via `spec` instead of `...`, using
#' the same syntax as the operators expand to (e.g.
#' `"A --> X + Y, X --> M --> Y"`).
#'
#' @param ... Edge expressions (see [edge-operators]) and/or bare node
#'   declarations. Mutually exclusive with `spec`.
#' @param spec Graph specification string, for programmatic construction.
#'   Mutually exclusive with `...`.
#' @param class Graph class: `"DAG"`, `"UG"`, `"PDAG"`, `"CPDAG"`, `"MPDAG"`,
#'   `"ADMG"`, `"AG"`, `"MAG"`, `"PAG"`, or `"UNKNOWN"` (no structural
#'   constraints; accepts all edge types, including multiple edges between
#'   the same pair of nodes).
#' @return A Julia proxy object representing the graph.
#' @export
#' @examples
#' if (julia_ready()) {
#'   dag <- cgraph(A %-->% X + Y, X %-->% M %-->% Y, class = "DAG")
#'   cpdag <- cgraph(A %---% B %---% C, class = "CPDAG")
#'
#'   # equivalent to the dag above, built from a spec string
#'   dag2 <- cgraph(spec = "A --> X + Y, X --> M --> Y", class = "DAG")
#'
#'   cgraph(A %-->% B, A %<->% B, class = "UNKNOWN")
#' }
cgraph <- function(
  ...,
  spec = NULL,
  class = c(
    "DAG",
    "UG",
    "PDAG",
    "CPDAG",
    "MPDAG",
    "ADMG",
    "AG",
    "MAG",
    "PAG",
    "UNKNOWN"
  )
) {
  class <- if (missing(class)) class[[1L]] else match.arg(class)
  .Call(C_cgraph, .dots_or_spec(substitute(list(...)), spec), class)
}

#' @export
print.cgraph <- function(x, ...) {
  cat(sub("^CausalStructures\\.", "", .Call(C_graph_string, x)))
  invisible(x)
}

#' Generate a random graph
#'
#' Generates a random graph on `n` observed nodes named `V1, ..., Vn`. Edges
#' are sampled uniformly at random over all possible pairs using
#' Erdős–Rényi and oriented by a random topological ordering, guaranteeing
#' acyclicity. This samples uniformly over graphs of a given size/density,
#' but *not* uniformly over the space of DAGs (some DAGs correspond to more
#' topological orderings than others). For an exact uniform draw from all
#' labelled DAGs on `n` nodes regardless of edge count, use [uniform_dag()]
#' instead.
#'
#' Exactly one of `m` (exact edge count) or `p` (edge probability) must be
#' given. For `class = "CPDAG"`, the sampled DAG is converted with
#' [dag_to_cpdag()]. For `class = "ADMG"`, `"MAG"`, or `"PAG"`, `latents`
#' additional nodes `L1, ..., Lk` are added to the underlying random DAG and
#' then marginalized out via [latent_project()]; `m`/`p` are applied to the
#' full `n + latents` node set before projection. `latents` must be `0`
#' (the default) for `class = "DAG"` or `class = "CPDAG"`.
#'
#' Unlike ADMGs, MAGs (and PAGs, which are derived from a sampled MAG)
#' additionally require the *ancestral* constraint (no bidirected edge
#' between a node and its own ancestor), which a naive latent projection can
#' violate whenever a marginalized common cause and a separate directed path
#' connect the same pair of observed nodes. For `class = "MAG"` or
#' `class = "PAG"`, each candidate is checked and, if invalid, resampled (up
#' to an internal retry limit) until a valid MAG is found; this errors if
#' none is found, which can happen for very dense graphs with many latents.
#' For `class = "PAG"`, the resulting MAG is then converted to its
#' equivalence class with [mag_to_pag()].
#'
#' @param n Number of observed nodes.
#' @param m Number of edges (supply exactly one of `m` and `p`); drawn from
#'   the full `n + latents` node set when `latents > 0`.
#' @param p Edge probability (supply exactly one of `m` and `p`); applied to
#'   the full `n + latents` node set when `latents > 0`.
#' @param class Graph class: `"DAG"`, `"CPDAG"`, `"ADMG"`, `"MAG"`, or
#'   `"PAG"`.
#' @param latents Number of latent nodes to sample alongside the `n` observed
#'   nodes and then project out. Only supported for `class = "ADMG"`,
#'   `"MAG"`, or `"PAG"`; must be `0` (default) otherwise.
#' @param seed Optional integer seed for reproducibility.
#' @return A Julia proxy object representing the graph.
#' @export
#' @examples
#' if (julia_ready()) {
#'   cg <- generate_graph(4, m = 3, seed = 1405)
#'   cg
#' }
#'
#' if (julia_ready()) {
#'   admg <- generate_graph(6, p = 0.3, class = "ADMG", latents = 2, seed = 1405)
#'   admg
#' }
#'
#' if (julia_ready()) {
#'   pag <- generate_graph(6, p = 0.3, class = "PAG", latents = 2, seed = 1405)
#'   pag
#' }
generate_graph <- function(
  n,
  m = NULL,
  p = NULL,
  class = c("DAG", "CPDAG", "ADMG", "MAG", "PAG"),
  latents = 0,
  seed = NULL
) {
  class <- if (missing(class)) class[[1L]] else match.arg(class)
  .Call(
    C_generate_graph,
    as.integer(n),
    m,
    p,
    class,
    as.integer(latents),
    make_rng(seed)
  )
}

#' Generate a uniformly random DAG
#'
#' Generates a random [DAG][cgraph()] on `n` observed nodes named
#' `V1, ..., Vn`, sampled uniformly at random from the space of all labelled
#' DAGs on `n` nodes, using the recursive-enumeration algorithm of Kuipers &
#' Moffa (2015).
#'
#' Unlike [generate_graph()], which samples edges independently (uniform over
#' graphs of a given size/density but *not* uniform over the space of DAGs),
#' this samples uniformly over the full space of labelled DAGs on `n` nodes.
#'
#' @param n Number of observed nodes.
#' @param seed Optional integer seed for reproducibility.
#' @return A Julia proxy object representing the graph.
#' @export
#' @examples
#' if (julia_ready()) {
#'   dag <- uniform_dag(6, seed = 1405)
#'   dag
#' }
uniform_dag <- function(n, seed = NULL) {
  .Call(C_uniform_dag, as.integer(n), make_rng(seed))
}

# --- Graph-level queries -----------------------------------------------------

#' Graph-level node queries
#'
#' `nodes()` returns all node names in alphabetical order.
#' `topological_sort()` returns the nodes of a DAG in topological
#' order: for every directed edge `u --> v`, `u` appears before `v`.
#' `exogenous_nodes()` returns the nodes with no parents (for a UG,
#' the isolated nodes).
#'
#' @param cg A graph created with [cgraph()]. Supported classes vary by
#'   function:
#'   * `nodes()`: any class.
#'   * `topological_sort()`: DAG.
#'   * `exogenous_nodes()`: any class except PAG.
#' @return Character vector of node names.
#' @name graph-queries
#' @examples
#' if (julia_ready()) {
#'   dag <- cgraph(B %-->% A, A %-->% C)
#'   list(
#'     nodes = nodes(dag),
#'     topological_sort = topological_sort(dag),
#'     exogenous_nodes = exogenous_nodes(dag)
#'   )
#' }
#'
#' if (julia_ready()) {
#'   pdag <- cgraph(A %-->% B, B %---% C, class = "PDAG")
#'   list(
#'     exogenous_nodes = exogenous_nodes(pdag),
#'     exogenous_nodes_undirected_as_parents =
#'       exogenous_nodes(pdag, undirected_as_parents = TRUE)
#'   )
#' }
NULL

#' @rdname graph-queries
#' @export
nodes <- function(cg) {
  .Call(C_nodes, cg)
}

#' @rdname graph-queries
#' @export
topological_sort <- function(cg) {
  .Call(C_topological_sort, cg)
}

#' @rdname graph-queries
#' @param undirected_as_parents Only used for PDAG-family graphs. If `TRUE`,
#'   a node incident to any undirected edge is not considered exogenous.
#' @export
exogenous_nodes <- function(cg, undirected_as_parents = FALSE) {
  .Call(C_exogenous_nodes, cg, undirected_as_parents)
}

#' Test whether two nodes are adjacent
#'
#' Tests adjacency, not directed reachability: `has_edge(g, x, y)` and
#' `has_edge(g, y, x)` always agree, even for a directed edge `x --> y`.
#'
#' @param cg A graph created with [cgraph()], of any class.
#' @param x,y Node names.
#' @return `TRUE` if the graph has any edge between `x` and `y`,
#'   regardless of direction.
#' @export
#' @examples
#' if (julia_ready()) {
#'   dag <- cgraph(A %-->% B, C)
#'   list(
#'     "A,B" = has_edge(dag, "A", "B"),
#'     "B,A" = has_edge(dag, "B", "A"),
#'     "A,C" = has_edge(dag, "A", "C")
#'   )
#' }
has_edge <- function(cg, x, y) {
  .Call(C_has_edge, cg, x, y)
}

# Maps a (src_end, dst_end) mark pair (as returned by the Julia
# `edge_marks` helper) to its notation, e.g. `("Tail", "Arrow")` -> `"-->"`.
# CausalStructures.jl only ever constructs edges in these 6 canonical
# orders (never e.g. `("Arrow", "Tail")`; see CausalStructures.jl's
# core/graph-string.jl, which swaps src/dst rather than store a
# non-canonical mark pair), so this covers every edge the Julia side can
# produce.
.edge_mark_types <- c(
  "Tail.Arrow" = "-->",
  "Tail.Tail" = "---",
  "Arrow.Arrow" = "<->",
  "Circle.Arrow" = "o->",
  "Circle.Tail" = "o--",
  "Circle.Circle" = "o-o"
)

#' Get all edges in a graph
#'
#' @param cg A graph created with [cgraph()], of any class.
#' @return A data frame with one row per edge and columns `from`, `to` (node
#'   names) and `type` (the edge's notation, e.g. `"-->"`, `"---"`,
#'   `"<->"`, `"o->"`, `"o--"`, or `"o-o"` — see [edge-operators]),
#'   or zero rows if the graph has no edges.
#' @export
#' @examples
#' if (julia_ready()) {
#'   dag <- cgraph(A %-->% B, B %-->% C)
#'   edges(dag)
#'
#'   pag <- cgraph(A %o-o% B, class = "PAG")
#'   edges(pag)
#' }
edges <- function(cg) {
  .Call(C_edges, cg)
}
