# --- Node-set queries --------------------------------------------------------

#' Node-set queries
#'
#' Relatives of a node: `cs_parents()`, `cs_children()`, `cs_ancestors()`,
#' `cs_descendants()`, `cs_spouses()`, `cs_neighbors()`,
#' `cs_markov_blanket()`, `cs_possible_ancestors()`,
#' `cs_possible_descendants()`, `cs_anteriors()`, and `cs_posteriors()`.
#'
#' @param graph A graph created with [cs_cgraph()].
#' @param node Node name.
#' @return Sorted character vector of node names.
#' @name cs-node-queries
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
cs_neighbors <- cs_node_query("neighbors")

#' @rdname cs-node-queries
#' @export
cs_markov_blanket <- cs_node_query("markov_blanket")

#' @rdname cs-node-queries
#' @export
cs_possible_ancestors <- cs_node_query("possible_ancestors")

#' @rdname cs-node-queries
#' @export
cs_possible_descendants <- cs_node_query("possible_descendants")

#' @rdname cs-node-queries
#' @export
cs_anteriors <- cs_node_query("anteriors")

#' @rdname cs-node-queries
#' @export
cs_posteriors <- cs_node_query("posteriors")


# --- Graph class predicates --------------------------------------------------

#' Graph class predicates
#'
#' Test which class a graph belongs to (`cs_is_dag()`, `cs_is_pdag()`,
#' `cs_is_cpdag()`, `cs_is_mpdag()`, `cs_is_ug()`, `cs_is_admg()`,
#' `cs_is_ag()`, `cs_is_mag()`, `cs_is_pag()`) or structural properties
#' (`cs_is_simple()`, `cs_is_acyclic()`).
#'
#' @param graph A graph created with [cs_cgraph()].
#' @return A logical scalar.
#' @name cs-predicates
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
