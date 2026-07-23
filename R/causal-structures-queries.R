# --- Node-set queries --------------------------------------------------------

#' Node-set queries
#'
#' `parents()` and `children()` are the nodes directly connected to `node`
#' by a directed edge. `ancestors()` and `descendants()` are all nodes from
#' which (respectively, to which) `node` is reachable by following directed
#' edges; `node` itself is always excluded (Julia's `ancestors()`/
#' `descendants()` support including it via `open = FALSE`, but that
#' argument isn't yet exposed on the R side). `spouses()` are the nodes
#' connected to `node` by a bidirected edge (`node <-> spouse`).
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
#' @return Sorted character vector of node names.
#' @name node-queries
#' @examples
#' if (julia_available()) {
#'   dag <- cgraph(A %-->% X + Y, X %-->% M %-->% Y)
#'   list(
#'     parents = parents(dag, "M"),
#'     children = children(dag, "X"),
#'     ancestors = ancestors(dag, "Y"),
#'     descendants = descendants(dag, "X")
#'   )
#' }
NULL

#' @rdname node-queries
#' @export
parents <- node_query("parents")

#' @rdname node-queries
#' @export
children <- node_query("children")

#' @rdname node-queries
#' @export
ancestors <- node_query("ancestors")

#' @rdname node-queries
#' @export
descendants <- node_query("descendants")

#' @rdname node-queries
#' @export
spouses <- node_query("spouses")

#' Markov blanket of a node
#'
#' Returns the Markov blanket of `node` in `cg`: the minimal set of nodes
#' that renders `node` conditionally independent of every other node in the
#' graph. What counts toward it depends on `cg`'s class:
#'
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
#' if (julia_available()) {
#'   dag <- cgraph(A %-->% B, B %-->% C, D %-->% C)
#'   list(
#'     blanket_of_b = markov_blanket(dag, "B"), # A, C, D (D is a co-parent)
#'     blanket_of_c = markov_blanket(dag, "C")
#'   )
#' }
markov_blanket <- node_query("markov_blanket")

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
#' if (julia_available()) {
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
  mode <- match.arg(mode)
  fn("neighbors")(cg, node, mode)
}

#' Possible-ancestor/descendant node-set queries
#'
#' `possible_ancestors()` finds every node `V` for which some DAG (for a
#' PDAG-family `cg`) or MAG (for a PAG `cg`) in the equivalence class
#' represented by `cg` has `V` as an ancestor of `node`: nodes reachable
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
#' @param open If `TRUE` (default), exclude `node` itself from the result;
#'   if `FALSE`, include it.
#' @return Sorted character vector of node names.
#' @references
#' \insertRef{perkovic2018complete}{testpkg}
#' @name possible-queries
#' @examples
#' if (julia_available()) {
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
possible_ancestors <- function(cg, node, open = TRUE) {
  fn("possible_ancestors")(cg, node, open)
}

#' @rdname possible-queries
#' @export
possible_descendants <- function(cg, node, open = TRUE) {
  fn("possible_descendants")(cg, node, open)
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
#' @param cg A DAG, PDAG-family (PDAG, CPDAG, MPDAG), or AG-family (AG,
#'   MAG) graph created with [cgraph()].
#' @param node Node name.
#' @param open If `TRUE` (default), exclude `node` itself from the result;
#'   if `FALSE`, include it.
#' @return Sorted character vector of node names.
#' @name anteriors
#' @examples
#' if (julia_available()) {
#'   pdag <- cgraph(A %-->% B, B %---% C, class = "PDAG")
#'   list(
#'     anteriors_of_a = anteriors(pdag, "A"),
#'     anteriors_of_c = anteriors(pdag, "C") # reaches B via undirected, A via directed
#'   )
#' }
NULL

#' @rdname anteriors
#' @export
anteriors <- function(cg, node, open = TRUE) {
  fn("anteriors")(cg, node, open)
}

#' @rdname anteriors
#' @export
posteriors <- function(cg, node, open = TRUE) {
  fn("posteriors")(cg, node, open)
}


# --- Graph class predicates --------------------------------------------------

#' Graph class predicates
#'
#' Test which class a graph belongs to (`is_dag()`, `is_pdag()`,
#' `is_cpdag()`, `is_mpdag()`, `is_ug()`, `is_admg()`,
#' `is_ag()`, `is_mag()`, `is_pag()`) or structural properties
#' (`is_simple()`, `is_acyclic()`).
#'
#' These test the actual edge structure of `cg`, independent of the
#' `class` it has.
#'
#' @param cg A graph created with [cgraph()], of any class.
#' @return A logical scalar.
#' @name predicates
#' @examples
#' if (julia_available()) {
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
is_dag <- graph_fn("is_dag")

#' @rdname predicates
#' @export
is_pdag <- graph_fn("is_pdag")

#' @rdname predicates
#' @export
is_cpdag <- graph_fn("is_cpdag")

#' @rdname predicates
#' @export
is_mpdag <- graph_fn("is_mpdag")

#' @rdname predicates
#' @export
is_ug <- graph_fn("is_ug")

#' @rdname predicates
#' @export
is_admg <- graph_fn("is_admg")

#' @rdname predicates
#' @export
is_ag <- graph_fn("is_ag")

#' @rdname predicates
#' @export
is_mag <- graph_fn("is_mag")

#' @rdname predicates
#' @export
is_pag <- graph_fn("is_pag")

#' @rdname predicates
#' @export
is_simple <- graph_fn("is_simple")

#' @rdname predicates
#' @export
is_acyclic <- graph_fn("is_acyclic")
