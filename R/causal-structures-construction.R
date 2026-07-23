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
#'   constraints; accepts all edge types).
#' @param simple Only used when `class` is `"UNKNOWN"`. If `TRUE` (default),
#'   only one edge is allowed between any pair of nodes; if `FALSE`, multiple
#'   edges between the same pair are allowed.
#' @return A Julia proxy object representing the graph.
#' @export
#' @examples
#' if (julia_available()) {
#'   dag <- cgraph(A %-->% X + Y, X %-->% M %-->% Y, class = "DAG")
#'   cpdag <- cgraph(A %---% B %---% C, class = "CPDAG")
#'
#'   # equivalent to the dag above, built from a spec string
#'   dag2 <- cgraph(spec = "A --> X + Y, X --> M --> Y", class = "DAG")
#'
#'   cgraph(
#'     A %-->% B, A %<->% B,
#'     class = "UNKNOWN",
#'     simple = FALSE
#'   )
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
  ),
  simple = TRUE
) {
  class <- match.arg(class)
  .tag_cgraph(fn("cgraph")(
    .dots_or_spec(substitute(list(...)), spec),
    class,
    simple
  ))
}

#' @export
print.cgraph <- function(x, ...) {
  cat(sub("^CausalStructures\\.", "", fn("show")(x)))
  invisible(x)
}

#' Generate a random graph
#'
#' Generates a random graph on `n` nodes named `V1, ..., Vn`. Edges are
#' sampled uniformly at random over all `n * (n - 1) / 2` possible pairs and
#' oriented by a random topological ordering, which guarantees acyclicity.
#'
#' Exactly one of `m` (exact edge count) or `p` (edge probability) must be
#' given. For `class = "CPDAG"`, the sampled DAG is converted with
#' [dag_to_cpdag()].
#'
#' @param n Number of nodes.
#' @param m Number of edges (supply exactly one of `m` and `p`).
#' @param p Edge probability (supply exactly one of `m` and `p`).
#' @param class Graph class: `"DAG"` or `"CPDAG"`.
#' @param seed Optional integer seed for reproducibility.
#' @return A Julia proxy object representing the graph.
#' @export
#' @examples
#' if (julia_available()) {
#'   cg <- generate_graph(4, m = 3, seed = 1405)
#'   cg
#' }
generate_graph <- function(
  n,
  m = NULL,
  p = NULL,
  class = c("DAG", "CPDAG"),
  seed = NULL
) {
  class <- match.arg(class)
  .tag_cgraph(fn("generate_graph")(as.integer(n), m, p, class, make_rng(seed)))
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
#' if (julia_available()) {
#'   dag <- cgraph(B %-->% A, A %-->% C)
#'   list(
#'     nodes = nodes(dag),
#'     topological_sort = topological_sort(dag),
#'     exogenous_nodes = exogenous_nodes(dag)
#'   )
#' }
#'
#' if (julia_available()) {
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
  fn("nodes")(cg)
}

#' @rdname graph-queries
#' @export
topological_sort <- function(cg) {
  fn("topological_sort")(cg)
}

#' @rdname graph-queries
#' @param undirected_as_parents Only used for PDAG-family graphs. If `TRUE`,
#'   a node incident to any undirected edge is not considered exogenous.
#' @export
exogenous_nodes <- function(cg, undirected_as_parents = FALSE) {
  fn("exogenous_nodes")(cg, undirected_as_parents)
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
#' if (julia_available()) {
#'   dag <- cgraph(A %-->% B, C)
#'   list(
#'     "A,B" = has_edge(dag, "A", "B"),
#'     "B,A" = has_edge(dag, "B", "A"),
#'     "A,C" = has_edge(dag, "A", "C")
#'   )
#' }
has_edge <- function(cg, x, y) {
  fn("has_edge")(cg, x, y)
}

#' Get all edges in a graph
#'
#' @param cg A graph created with [cgraph()], of any class.
#' @return A matrix with 2 columns (source, target) and one row per edge,
#'   or an empty matrix if the graph has no edges.
#' @export
#' @examples
#' if (julia_available()) {
#'   dag <- cgraph(A %-->% B, B %-->% C)
#'   edges(dag)
#' }
edges <- function(cg) {
  fn("edges")(cg)
}
