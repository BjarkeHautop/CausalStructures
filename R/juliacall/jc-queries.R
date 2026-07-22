# --- Node-set queries (JuliaCall backend; see jc-session.R) -----------------

jc_parents <- jc_node_query("parents")
jc_children <- jc_node_query("children")
jc_ancestors <- jc_node_query("ancestors")
jc_descendants <- jc_node_query("descendants")
jc_spouses <- jc_node_query("spouses")
jc_markov_blanket <- jc_node_query("markov_blanket")

jc_neighbors <- function(
  cg,
  node,
  mode = c("all", "in", "out", "undirected", "bidirected")
) {
  mode <- match.arg(mode)
  jc_fn("neighbors")(cg, node, mode)
}

jc_possible_ancestors <- function(cg, node, open = TRUE) {
  jc_fn("possible_ancestors")(cg, node, open)
}

jc_possible_descendants <- function(cg, node, open = TRUE) {
  jc_fn("possible_descendants")(cg, node, open)
}

jc_anteriors <- function(cg, node, open = TRUE) {
  jc_fn("anteriors")(cg, node, open)
}

jc_posteriors <- function(cg, node, open = TRUE) {
  jc_fn("posteriors")(cg, node, open)
}

# --- Graph class predicates --------------------------------------------------

jc_is_dag <- jc_graph_fn("is_dag")
jc_is_pdag <- jc_graph_fn("is_pdag")
jc_is_cpdag <- jc_graph_fn("is_cpdag")
jc_is_mpdag <- jc_graph_fn("is_mpdag")
jc_is_ug <- jc_graph_fn("is_ug")
jc_is_admg <- jc_graph_fn("is_admg")
jc_is_ag <- jc_graph_fn("is_ag")
jc_is_mag <- jc_graph_fn("is_mag")
jc_is_pag <- jc_graph_fn("is_pag")
jc_is_simple <- jc_graph_fn("is_simple")
jc_is_acyclic <- jc_graph_fn("is_acyclic")
