# --- Node-set queries --------------------------------------------------------

#' Node-set queries
#'
#' Relatives of a node: `cs_parents()`, `cs_children()`, `cs_ancestors()`,
#' `cs_descendants()`, `cs_spouses()`, and `cs_markov_blanket()`. See
#' [cs_neighbors()] and [cs-possible-queries] for the remaining node-set
#' queries, which take extra arguments.
#'
#' @param graph A graph created with [cs_cgraph()].
#' @param node Node name.
#' @return Sorted character vector of node names.
#' @name cs-node-queries
#' @examples
#' if (JuliaConnectoR::juliaSetupOk()) {
#'   dag <- cs_cgraph(A %-->% X + Y, X %-->% M %-->% Y)
#'   cs_parents(dag, "M")
#'   cs_children(dag, "X")
#'   cs_ancestors(dag, "Y")
#'   cs_descendants(dag, "X")
#' }
NULL

#' @rdname cs-node-queries
#' @export
cs_parents <- cs_node_query("parents")

#' @rdname cs-node-queries
#' @export
cs_children <- cs_node_query("children")

#' @rdname cs-node-queries
#' @export
cs_ancestors <- cs_node_query("ancestors")

#' @rdname cs-node-queries
#' @export
cs_descendants <- cs_node_query("descendants")

#' @rdname cs-node-queries
#' @export
cs_spouses <- cs_node_query("spouses")

#' @rdname cs-node-queries
#' @export
cs_markov_blanket <- cs_node_query("markov_blanket")

#' Neighbors of a node
#'
#' Nodes adjacent to `node` by some edge. `mode` restricts which edge types
#' count: `"in"` (parents / arrowheads at `node`), `"out"` (children / tails
#' at `node`), `"undirected"`, or `"bidirected"`; `"all"` (default) includes
#' every neighbor regardless of edge type. For a PAG, `"in"`, `"out"`,
#' `"undirected"`, and `"bidirected"` only match *definite* (circle-free)
#' edges; neighbors joined by a circle mark (`o->`, `o--`, `o-o`) are
#' reported by `"all"` only.
#'
#' @param graph A graph created with [cs_cgraph()].
#' @param node Node name.
#' @param mode Which edge types to include: `"all"` (default), `"in"`,
#'   `"out"`, `"undirected"`, or `"bidirected"`.
#' @return Sorted character vector of node names.
#' @export
#' @examples
#' if (JuliaConnectoR::juliaSetupOk()) {
#'   dag <- cs_cgraph(A %-->% B, C %-->% B)
#'   cs_neighbors(dag, "B")
#'   cs_neighbors(dag, "B", mode = "in")
#'   cs_neighbors(dag, "A", mode = "out")
#' }
cs_neighbors <- function(
  graph,
  node,
  mode = c("all", "in", "out", "undirected", "bidirected")
) {
  mode <- match.arg(mode)
  cs_split(cs_fn("neighbors")(graph, node, mode))
}

#' Possible-ancestor/descendant node-set queries
#'
#' `cs_possible_ancestors()` and `cs_possible_descendants()` find nodes
#' reachable from `node` by a *possibly directed* path: one on which no edge
#' is compelled in the direction away from `node`, traversing an undirected
#' edge or a directed edge pointing the right way. `cs_anteriors()` and
#' `cs_posteriors()` are the corresponding notions for ancestral-graph
#' classes (traversing undirected edges too). When `open = TRUE` (default),
#' `node` itself is excluded from the result; when `FALSE`, it is included.
#'
#' @param graph A graph created with [cs_cgraph()].
#' @param node Node name.
#' @param open If `TRUE` (default), exclude `node` itself from the result.
#' @return Sorted character vector of node names.
#' @references
#' \insertRef{perkovic2018complete}{testpkg}
#' @name cs-possible-queries
#' @examples
#' if (JuliaConnectoR::juliaSetupOk()) {
#'   cpdag <- cs_cgraph(A %---% B, B %---% C, class = "CPDAG")
#'   cs_ancestors(cpdag, "C") # compelled ancestors: none
#'   cs_possible_ancestors(cpdag, "C")
#'   cs_possible_ancestors(cpdag, "C", open = FALSE) # C included too
#' }
NULL

#' @rdname cs-possible-queries
#' @export
cs_possible_ancestors <- function(graph, node, open = TRUE) {
  cs_split(cs_fn("possible_ancestors")(graph, node, open))
}

#' @rdname cs-possible-queries
#' @export
cs_possible_descendants <- function(graph, node, open = TRUE) {
  cs_split(cs_fn("possible_descendants")(graph, node, open))
}

#' @rdname cs-possible-queries
#' @export
cs_anteriors <- function(graph, node, open = TRUE) {
  cs_split(cs_fn("anteriors")(graph, node, open))
}

#' @rdname cs-possible-queries
#' @export
cs_posteriors <- function(graph, node, open = TRUE) {
  cs_split(cs_fn("posteriors")(graph, node, open))
}


# --- Graph class predicates --------------------------------------------------

#' Graph class predicates
#'
#' Test which class a graph belongs to (`cs_is_dag()`, `cs_is_pdag()`,
#' `cs_is_cpdag()`, `cs_is_mpdag()`, `cs_is_ug()`, `cs_is_admg()`,
#' `cs_is_ag()`, `cs_is_mag()`, `cs_is_pag()`) or structural properties
#' (`cs_is_simple()`, `cs_is_acyclic()`).
#'
#' These test the actual edge structure of `graph`, independent of the
#' `class` it has.
#'
#' @param graph A graph created with [cs_cgraph()].
#' @return A logical scalar.
#' @name cs-predicates
#' @examples
#' if (JuliaConnectoR::juliaSetupOk()) {
#'   dag <- cs_cgraph(A %-->% B, class = "UNKNOWN")
#'   cs_is_dag(dag) # TRUE, even though dag is tagged UNKNOWN
#'   cs_is_ug(dag)
#'   cs_is_acyclic(dag)
#' }
NULL

#' @rdname cs-predicates
#' @export
cs_is_dag <- cs_graph_fn("is_dag")

#' @rdname cs-predicates
#' @export
cs_is_pdag <- cs_graph_fn("is_pdag")

#' @rdname cs-predicates
#' @export
cs_is_cpdag <- cs_graph_fn("is_cpdag")

#' @rdname cs-predicates
#' @export
cs_is_mpdag <- cs_graph_fn("is_mpdag")

#' @rdname cs-predicates
#' @export
cs_is_ug <- cs_graph_fn("is_ug")

#' @rdname cs-predicates
#' @export
cs_is_admg <- cs_graph_fn("is_admg")

#' @rdname cs-predicates
#' @export
cs_is_ag <- cs_graph_fn("is_ag")

#' @rdname cs-predicates
#' @export
cs_is_mag <- cs_graph_fn("is_mag")

#' @rdname cs-predicates
#' @export
cs_is_pag <- cs_graph_fn("is_pag")

#' @rdname cs-predicates
#' @export
cs_is_simple <- cs_graph_fn("is_simple")

#' @rdname cs-predicates
#' @export
cs_is_acyclic <- cs_graph_fn("is_acyclic")
