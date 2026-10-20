# --- Node-set queries --------------------------------------------------------

#' Node-set queries
#'
#' `parents()` and `children()` are the nodes directly connected to `node`
#' by a directed edge. `ancestors()` and `descendants()` are all nodes from
#' which (respectively, to which) `node` is reachable by following directed
#' edges. `spouses()` are the nodes connected to `node` by a bidirected edge
#' (`node <-> spouse`).
#'
#' See [neighbors()], [markov_blanket()], and [possible-queries] for the
#' remaining node-set queries, which take extra arguments.
#'
#' @param cg A graph created with [cgraph()]. Supported classes vary by
#'   function:
#'   * `parents()`, `children()`: any class except UG.
#'   * `ancestors()`, `descendants()`: DAG, PDAG-family (PDAG, CPDAG,
#'     MPDAG), ADMG, or AG-family (AG, MAG).
#'   * `spouses()`: ADMG, AG-family (AG, MAG), or PAG.
#' @param node Node name.
#' @param open If `TRUE` (default, from the `CausalStructures.open` option),
#'   exclude `node` itself from the result; if `FALSE`, include it.
#' @return Sorted character vector of node names.
#' @name node-queries
#' @examples
#' if (julia_ready()) {
#'   dag <- cgraph(A %-->% X + Y, X %-->% M %-->% Y)
#'   list(
#'     parents = parents(dag, "M"),
#'     children = children(dag, "X"),
#'     ancestors = ancestors(dag, "Y"),
#'     descendants = descendants(dag, "X"),
#'     descendants_closed = descendants(dag, "X", open = FALSE)
#'   )
#' }
NULL

#' @rdname node-queries
#' @export
parents <- function(cg, node) .Call(C_jl_parents, cg, node)

#' @rdname node-queries
#' @export
children <- function(cg, node) .Call(C_jl_children, cg, node)

#' @rdname node-queries
#' @export
ancestors <- function(
  cg,
  node,
  open = getOption("CausalStructures.open", TRUE)
) {
  .Call(C_jl_ancestors, cg, node, open)
}

#' @rdname node-queries
#' @export
descendants <- function(
  cg,
  node,
  open = getOption("CausalStructures.open", TRUE)
) {
  .Call(C_jl_descendants, cg, node, open)
}

#' @rdname node-queries
#' @export
spouses <- function(cg, node) .Call(C_jl_spouses, cg, node)

#' Markov blanket of a node
#'
#' Returns the Markov blanket of `node` in `cg`: the minimal set of nodes
#' that renders `node` conditionally independent of every other node in the
#' graph.
#'
#' The Markov blanket returns the following, depending on the graph
#' class:
#' * **DAG**: parents, children, and co-parents (other parents of `node`'s
#'   children).
#' * **PDAG-family** (PDAG, CPDAG, MPDAG): the DAG set, plus undirected
#'   neighbors.
#' * **ADMG**: the union of the parents of every node in `node`'s district
#'   (excluding `node` itself).
#' * **AG-family** (AG, MAG): parents, children, co-parents, spouses, and
#'   undirected neighbors.
#'
#' @param cg A DAG, PDAG-family (PDAG, CPDAG, MPDAG), ADMG, or AG-family
#'   (AG, MAG) graph created with [cgraph()].
#' @param node Node name.
#' @return Sorted character vector of node names.
#' @export
#' @examples
#' if (julia_ready()) {
#'   dag <- cgraph(A %-->% B, B %-->% C, D %-->% C)
#'   list(
#'     blanket_of_b = markov_blanket(dag, "B"), # A, C, D (D is a co-parent)
#'     blanket_of_c = markov_blanket(dag, "C")
#'   )
#' }
markov_blanket <- function(cg, node) .Call(C_jl_markov_blanket, cg, node)

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
#' @param cg A graph created with [cgraph()], of any class.
#' @param node Node name.
#' @param mode Which edge types to include: `"all"` (default), `"in"`,
#'   `"out"`, `"undirected"`, or `"bidirected"`.
#' @return Sorted character vector of node names.
#' @export
#' @examples
#' if (julia_ready()) {
#'   dag <- cgraph(A %-->% B, C %-->% B)
#'   list(
#'     all = neighbors(dag, "B"),
#'     "in" = neighbors(dag, "B", mode = "in"),
#'     out = neighbors(dag, "A", mode = "out")
#'   )
#' }
neighbors <- function(
  cg,
  node,
  mode = c("all", "in", "out", "undirected", "bidirected")
) {
  mode <- if (missing(mode)) mode[[1L]] else match.arg(mode)
  .Call(C_jl_neighbors, cg, node, mode)
}

#' Possible-ancestor/descendant node-set queries
#'
#' `possible_ancestors()` finds every node `V` that is an ancestor of `node`
#' in some DAG (for a PDAG-family `cg`) or MAG (for a PAG `cg`) in the
#' equivalence class represented by `cg`. These are the nodes reachable
#' from `node` by a *possibly directed* path, one on which no edge is
#' compelled in the direction away from `node` (traversing an undirected
#' edge, or a directed/circle edge oriented, or possibly orientable, toward
#' `node`). `possible_descendants()` is the mirror notion in the other
#' direction. Both are supersets of [ancestors()]/[descendants()], since
#' those only count edges *compelled* in the right direction.
#'
#' @param cg A PDAG-family (PDAG, CPDAG, MPDAG) or PAG graph created with
#'   [cgraph()].
#' @param node Node name.
#' @param open If `TRUE` (default, from the `CausalStructures.open` option),
#'   exclude `node` itself from the result; if `FALSE`, include it.
#' @return Sorted character vector of node names.
#' @references
#' \insertRef{perkovic2018complete}{CausalStructures}
#' @name possible-queries
#' @examples
#' if (julia_ready()) {
#'   cpdag <- cgraph(A %---% B, B %---% C, class = "CPDAG")
#'   list(
#'     ancestors = ancestors(cpdag, "C"),
#'     possible_ancestors = possible_ancestors(cpdag, "C"),
#'     possible_ancestors_including_self =
#'       possible_ancestors(cpdag, "C", open = FALSE)
#'   )
#' }
NULL

#' @rdname possible-queries
#' @export
possible_ancestors <- function(
  cg,
  node,
  open = getOption("CausalStructures.open", TRUE)
) {
  .Call(C_jl_possible_ancestors, cg, node, open)
}

#' @rdname possible-queries
#' @export
possible_descendants <- function(
  cg,
  node,
  open = getOption("CausalStructures.open", TRUE)
) {
  .Call(C_jl_possible_descendants, cg, node, open)
}

#' Anterior/posterior node-set queries
#'
#' `anteriors()` finds every node from which `node` is reachable by
#' following directed edges backward or traversing undirected edges;
#' `posteriors()` is the mirror notion following directed edges forward.
#' For a DAG, anteriors/posteriors are equivalent to
#' [ancestors()]/[descendants()] (no undirected edges exist to traverse);
#' for a PDAG-family or AG-family graph, undirected edges extend the
#' reachable set beyond strict ancestors/descendants.
#'
#' @param cg A DAG, ADMG, PDAG-family (PDAG, CPDAG, MPDAG), or AG-family (AG,
#'   MAG) graph created with [cgraph()].
#' @param node Node name.
#' @param open If `TRUE` (default, from the `CausalStructures.open` option),
#'   exclude `node` itself from the result; if `FALSE`, include it.
#' @return Sorted character vector of node names.
#' @name anteriors
#' @examples
#' if (julia_ready()) {
#'   pdag <- cgraph(A %-->% B, B %---% C, class = "PDAG")
#'   list(
#'     anteriors_of_a = anteriors(pdag, "A"),
#'     anteriors_of_c = anteriors(pdag, "C") # reaches B via undirected, A via directed
#'   )
#' }
NULL

#' @rdname anteriors
#' @export
anteriors <- function(
  cg,
  node,
  open = getOption("CausalStructures.open", TRUE)
) {
  .Call(C_jl_anteriors, cg, node, open)
}

#' @rdname anteriors
#' @export
posteriors <- function(
  cg,
  node,
  open = getOption("CausalStructures.open", TRUE)
) {
  .Call(C_jl_posteriors, cg, node, open)
}


# --- Graph class predicates --------------------------------------------------

#' Graph class predicates
#'
#' Test which class a graph belongs to, or its structural properties.
#' The class predicates are `is_dag()`, `is_pdag()`, `is_cpdag()`,
#' `is_mpdag()`, `is_ug()`, `is_admg()`, `is_ag()`, `is_mag()` and
#' `is_pag()`; the structural ones are `is_simple()` and `is_acyclic()`.
#'
#' These test the actual edge structure of `cg`, independent of the
#' `class` it has.
#'
#' @param cg A graph created with [cgraph()], of any class.
#' @return A logical scalar.
#' @name predicates
#' @examples
#' if (julia_ready()) {
#'   dag <- cgraph(A %-->% B, class = "PDAG")
#'   list(
#'     is_dag = is_dag(dag), # TRUE, even though assigned PDAG
#'     is_ug = is_ug(dag),
#'     is_acyclic = is_acyclic(dag)
#'   )
#' }
NULL

#' @rdname predicates
#' @export
is_dag <- function(cg) .Call(C_jl_is_dag, cg)

#' @rdname predicates
#' @export
is_pdag <- function(cg) .Call(C_jl_is_pdag, cg)

#' @rdname predicates
#' @export
is_cpdag <- function(cg) .Call(C_jl_is_cpdag, cg)

#' @rdname predicates
#' @export
is_mpdag <- function(cg) .Call(C_jl_is_mpdag, cg)

#' @rdname predicates
#' @export
is_ug <- function(cg) .Call(C_jl_is_ug, cg)

#' @rdname predicates
#' @export
is_admg <- function(cg) .Call(C_jl_is_admg, cg)

#' @rdname predicates
#' @export
is_ag <- function(cg) .Call(C_jl_is_ag, cg)

#' @rdname predicates
#' @export
is_mag <- function(cg) .Call(C_jl_is_mag, cg)

#' @rdname predicates
#' @export
is_pag <- function(cg) .Call(C_jl_is_pag, cg)

#' @rdname predicates
#' @export
is_simple <- function(cg) .Call(C_jl_is_simple, cg)

#' @rdname predicates
#' @export
is_acyclic <- function(cg) .Call(C_jl_is_acyclic, cg)
