# --- Construction ------------------------------------------------------------

#' Create a causal graph
#'
#' Builds a graph from CausalStructures.jl's string DSL, e.g.
#' `"A --> X + Y, X --> M --> Y"`.
#'
#' @param spec Graph specification string.
#' @param class Graph class, e.g. `"DAG"`, `"PDAG"`, `"CPDAG"`, `"ADMG"`,
#'   `"MAG"`, `"UG"`.
#' @return A Julia proxy object representing the graph.
#' @export
#' @examples
#' \dontrun{
#' dag <- cs_cgraph("A --> X + Y, X --> M --> Y")
#' }
cs_cgraph <- function(spec, class = "DAG") {
  cs_fn("cgraph")(spec, class)
}

#' Generate a random graph
#'
#' @param n Number of nodes.
#' @param m Number of edges (supply exactly one of `m` and `p`).
#' @param p Edge probability (supply exactly one of `m` and `p`).
#' @param class Graph class: `"DAG"` or `"CPDAG"`.
#' @param seed Optional integer seed for reproducibility.
#' @return A Julia proxy object representing the graph.
#' @export
cs_generate_graph <- function(
  n,
  m = NULL,
  p = NULL,
  class = "DAG",
  seed = NULL
) {
  cs_fn("generate_graph")(as.integer(n), m, p, class, seed)
}

# --- Graph-level queries -----------------------------------------------------

#' Graph-level node queries
#'
#' `cs_nodes()` returns all node names (in graph order),
#' `cs_topological_sort()` a topological ordering, and
#' `cs_exogenous_nodes()` the nodes without parents.
#'
#' @param graph A graph created with [cs_cgraph()].
#' @return Character vector of node names.
#' @name cs-graph-queries
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
#' @export
cs_exogenous_nodes <- function(graph) {
  cs_split(cs_fn("exogenous_nodes")(graph))
}

#' Test whether two nodes are adjacent
#'
#' @param graph A graph created with [cs_cgraph()].
#' @param x,y Node names.
#' @return `TRUE` if the graph has any edge between `x` and `y`,
#'   regardless of direction.
#' @export
cs_has_edge <- function(graph, x, y) {
  cs_fn("has_edge")(graph, x, y)
}

#' Get all edges in a graph
#'
#' @param graph A graph created with [cs_cgraph()].
#' @return A matrix with 2 columns (source, target) and one row per edge,
#'   or an empty matrix if the graph has no edges.
#' @export
cs_edges <- function(graph) {
  res <- cs_fn("edges")(graph)
  if (identical(res, "")) {
    return(matrix(character(), nrow = 0, ncol = 2))
  }
  tokens <- strsplit(chartr("\x1f", "\x1e", res), "\x1e", fixed = TRUE)[[1]]
  matrix(tokens, ncol = 2, byrow = TRUE)
}
