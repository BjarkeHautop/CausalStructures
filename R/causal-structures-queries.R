# --- Node-set queries --------------------------------------------------------

#' Node-set queries
#'
#' Relatives of a node: `parents()`, `children()`, `ancestors()`,
#' `descendants()`, `spouses()`, and `markov_blanket()`. See
#' [neighbors()] and [cs-possible-queries] for the remaining node-set
#' queries, which take extra arguments.
#'
#' @param cg A graph created with [cgraph()]. Supported classes vary by
#'   function: `parents()` and `children()` accept any class except
#'   UG; `ancestors()`, `descendants()`, and `markov_blanket()`
#'   accept DAG, PDAG-family (PDAG, CPDAG, MPDAG), ADMG, or AG-family (AG,
#'   MAG); `spouses()` accepts ADMG, AG-family, or PAG.
#' @param node Node name.
#' @return Sorted character vector of node names.
#' @name cs-node-queries
#' @examples
#' if (julia_available()) {
#'   dag <- cgraph(A %-->% X + Y, X %-->% M %-->% Y)
#'   parents(dag, "M")
#'   children(dag, "X")
#'   ancestors(dag, "Y")
#'   descendants(dag, "X")
#' }
NULL

#' @rdname cs-node-queries
#' @export
parents <- node_query("parents")

#' @rdname cs-node-queries
#' @export
children <- node_query("children")

#' @rdname cs-node-queries
#' @export
ancestors <- node_query("ancestors")

#' @rdname cs-node-queries
#' @export
descendants <- node_query("descendants")

#' @rdname cs-node-queries
#' @export
spouses <- node_query("spouses")

#' @rdname cs-node-queries
#' @export
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
#'   neighbors(dag, "B")
#'   neighbors(dag, "B", mode = "in")
#'   neighbors(dag, "A", mode = "out")
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
#' `possible_ancestors()` and `possible_descendants()` find nodes
#' reachable from `node` by a *possibly directed* path: one on which no edge
#' is compelled in the direction away from `node`, traversing an undirected
#' edge or a directed edge pointing the right way. `anteriors()` and
#' `posteriors()` are the corresponding notions for ancestral-graph
#' classes (traversing undirected edges too). When `open = TRUE` (default),
#' `node` itself is excluded from the result; when `FALSE`, it is included.
#'
#' @param cg A graph created with [cgraph()]. `possible_ancestors()`
#'   and `possible_descendants()` accept PDAG-family (PDAG, CPDAG, MPDAG)
#'   or PAG graphs; `anteriors()` and `posteriors()` accept PDAG-family
#'   or AG-family (AG, MAG) graphs.
#' @param node Node name.
#' @param open If `TRUE` (default), exclude `node` itself from the result.
#' @return Sorted character vector of node names.
#' @references
#' \insertRef{perkovic2018complete}{testpkg}
#' @name cs-possible-queries
#' @examples
#' if (julia_available()) {
#'   cpdag <- cgraph(A %---% B, B %---% C, class = "CPDAG")
#'   ancestors(cpdag, "C") # compelled ancestors: none
#'   possible_ancestors(cpdag, "C")
#'   possible_ancestors(cpdag, "C", open = FALSE) # C included too
#' }
NULL

#' @rdname cs-possible-queries
#' @export
possible_ancestors <- function(cg, node, open = TRUE) {
  fn("possible_ancestors")(cg, node, open)
}

#' @rdname cs-possible-queries
#' @export
possible_descendants <- function(cg, node, open = TRUE) {
  fn("possible_descendants")(cg, node, open)
}

#' @rdname cs-possible-queries
#' @export
anteriors <- function(cg, node, open = TRUE) {
  fn("anteriors")(cg, node, open)
}

#' @rdname cs-possible-queries
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
#' @name cs-predicates
#' @examples
#' if (julia_available()) {
#'   dag <- cgraph(A %-->% B, class = "UNKNOWN")
#'   is_dag(dag) # TRUE, even though dag is tagged UNKNOWN
#'   is_ug(dag)
#'   is_acyclic(dag)
#' }
NULL

#' @rdname cs-predicates
#' @export
is_dag <- graph_fn("is_dag")

#' @rdname cs-predicates
#' @export
is_pdag <- graph_fn("is_pdag")

#' @rdname cs-predicates
#' @export
is_cpdag <- graph_fn("is_cpdag")

#' @rdname cs-predicates
#' @export
is_mpdag <- graph_fn("is_mpdag")

#' @rdname cs-predicates
#' @export
is_ug <- graph_fn("is_ug")

#' @rdname cs-predicates
#' @export
is_admg <- graph_fn("is_admg")

#' @rdname cs-predicates
#' @export
is_ag <- graph_fn("is_ag")

#' @rdname cs-predicates
#' @export
is_mag <- graph_fn("is_mag")

#' @rdname cs-predicates
#' @export
is_pag <- graph_fn("is_pag")

#' @rdname cs-predicates
#' @export
is_simple <- graph_fn("is_simple")

#' @rdname cs-predicates
#' @export
is_acyclic <- graph_fn("is_acyclic")
