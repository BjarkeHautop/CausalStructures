# --- Construction ------------------------------------------------------------

#' Create a causal graph
#'
#' Builds a graph from edge expressions using the operators documented at
#' [cs-edge-operators], e.g. `A %-->% X + Y, X %-->% M %-->% Y`. A bare node
#' name (or `+`-combination of names) declares isolated node(s).
#'
#' For programmatic construction (e.g. from an edge list assembled at
#' runtime), pass a spec string directly via `spec` instead of `...`, using
#' the same syntax as the operators expand to (e.g.
#' `"A --> X + Y, X --> M --> Y"`).
#'
#' @param ... Edge expressions (see [cs-edge-operators]) and/or bare node
#'   declarations. Mutually exclusive with `spec`.
#' @param spec Graph specification string, for programmatic construction.
#'   Mutually exclusive with `...`.
#' @param class Graph class: `"DAG"`, `"UG"`, `"PDAG"`, `"CPDAG"`, `"MPDAG"`,
#'   `"ADMG"`, `"AG"`, `"MAG"`, `"PAG"`, or `"UNKNOWN"` (no structural
#'   constraints; accepts all edge types).
#' @param simple Only used when `class` is `"UNKNOWN"`. If `TRUE` (default),
#'   only one edge is allowed between any pair of nodes; if `FALSE`, multiple
#'   edges between the same pair are allowed.
#' @return A Julia proxy object representing the graph.
#' @export
#' @examples
#' if (JuliaConnectoR::juliaSetupOk()) {
#'   dag <- cs_cgraph(A %-->% X + Y, X %-->% M %-->% Y, class = "DAG")
#'   cpdag <- cs_cgraph(A %---% B %---% C, class = "CPDAG")
#'
#'   multi <- cs_cgraph(
#'     A %-->% B, A %<->% B,
#'     class = "UNKNOWN",
#'     simple = FALSE
#'   )
#'   nrow(cs_edges(multi))
#' }
cs_cgraph <- function(
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
  ),
  simple = TRUE
) {
  class <- match.arg(class)
  cs_fn("cgraph")(.cs_dots_or_spec(substitute(list(...)), spec), class, simple)
}

#' Generate a random graph
#'
#' Generates a random graph on `n` nodes named `V1, ..., Vn`. Edges are
#' sampled uniformly at random over all `n * (n - 1) / 2` possible pairs and
#' oriented by a random topological ordering, which guarantees acyclicity.
#'
#' Exactly one of `m` (exact edge count) or `p` (edge probability) must be
#' given. For `class = "CPDAG"`, the sampled DAG is converted with
#' [cs_dag_to_cpdag()].
#'
#' @param n Number of nodes.
#' @param m Number of edges (supply exactly one of `m` and `p`).
#' @param p Edge probability (supply exactly one of `m` and `p`).
#' @param class Graph class: `"DAG"` or `"CPDAG"`.
#' @param seed Optional integer seed for reproducibility.
#' @return A Julia proxy object representing the graph.
#' @export
#' @examples
#' if (JuliaConnectoR::juliaSetupOk()) {
#'   cg <- cs_generate_graph(4, m = 3, seed = 1405)
#'   cs_edges(cg)
#' }
cs_generate_graph <- function(
  n,
  m = NULL,
  p = NULL,
  class = c("DAG", "CPDAG"),
  seed = NULL
) {
  class <- match.arg(class)
  cs_fn("generate_graph")(as.integer(n), m, p, class, cs_make_rng(seed))
}

# --- Graph-level queries -----------------------------------------------------

#' Graph-level node queries
#'
#' `cs_nodes()` returns all node names in alphabetical order.
#' `cs_topological_sort()` returns the nodes of a DAG in topological
#' order: for every directed edge `u --> v`, `u` appears before `v`.
#' `cs_exogenous_nodes()` returns the nodes with no parents (for a UG,
#' the isolated nodes).
#'
#' @param graph A graph created with [cs_cgraph()].
#' @return Character vector of node names.
#' @name cs-graph-queries
#' @examples
#' if (JuliaConnectoR::juliaSetupOk()) {
#'   dag <- cs_cgraph(B %-->% A, A %-->% C)
#'   cs_nodes(dag)
#'   cs_topological_sort(dag)
#'   cs_exogenous_nodes(dag)
#'
#'   pdag <- cs_cgraph(A %-->% B, B %---% C, class = "PDAG")
#'   cs_exogenous_nodes(pdag)
#'   cs_exogenous_nodes(pdag, undirected_as_parents = TRUE)
#' }
NULL

#' @rdname cs-graph-queries
#' @export
cs_nodes <- function(graph) {
  cs_split(cs_fn("nodes")(graph))
}

#' @rdname cs-graph-queries
#' @export
cs_topological_sort <- function(graph) {
  cs_split(cs_fn("topological_sort")(graph))
}

#' @rdname cs-graph-queries
#' @param undirected_as_parents Only used for PDAG-family graphs. If `TRUE`,
#'   a node incident to any undirected edge is not considered exogenous.
#' @export
cs_exogenous_nodes <- function(graph, undirected_as_parents = FALSE) {
  cs_split(cs_fn("exogenous_nodes")(graph, undirected_as_parents))
}

#' Test whether two nodes are adjacent
#'
#' Tests adjacency, not directed reachability: `cs_has_edge(g, x, y)` and
#' `cs_has_edge(g, y, x)` always agree, even for a directed edge `x --> y`.
#'
#' @param graph A graph created with [cs_cgraph()].
#' @param x,y Node names.
#' @return `TRUE` if the graph has any edge between `x` and `y`,
#'   regardless of direction.
#' @export
#' @examples
#' if (JuliaConnectoR::juliaSetupOk()) {
#'   dag <- cs_cgraph(A %-->% B, C)
#'   cs_has_edge(dag, "A", "B")
#'   cs_has_edge(dag, "B", "A")
#'   cs_has_edge(dag, "A", "C")
#' }
cs_has_edge <- function(graph, x, y) {
  cs_fn("has_edge")(graph, x, y)
}

#' Get all edges in a graph
#'
#' @param graph A graph created with [cs_cgraph()].
#' @return A matrix with 2 columns (source, target) and one row per edge,
#'   or an empty matrix if the graph has no edges.
#' @export
#' @examples
#' if (JuliaConnectoR::juliaSetupOk()) {
#'   dag <- cs_cgraph(A %-->% B, B %-->% C)
#'   cs_edges(dag)
#' }
cs_edges <- function(graph) {
  res <- cs_fn("edges")(graph)
  if (identical(res, "")) {
    return(matrix(character(), nrow = 0, ncol = 2))
  }
  tokens <- strsplit(chartr("\x1f", "\x1e", res), "\x1e", fixed = TRUE)[[1]]
  matrix(tokens, ncol = 2, byrow = TRUE)
}
