# --- Transformations ---------------------------------------------------------

#' Graph transformations
#'
#' `cs_skeleton()` drops edge marks, `cs_moralize()` moralizes a DAG,
#' `cs_dag_to_cpdag()` and `cs_dag_from_pdag()` convert between equivalence
#' classes, `cs_meek_closure()` applies Meek's rules, `cs_ag_to_mag()`
#' converts an AG to a Markov equivalent MAG, `cs_mag_to_pag()` maps a MAG to
#' its PAG equivalence class representative, and `cs_mag_from_pag()` resolves
#' a PAG back to a representative MAG. All return a new graph proxy; the
#' input graph is unchanged.
#'
#' @param graph A graph created with [cs_cgraph()].
#' @return A Julia proxy object representing the transformed graph.
#' @name cs-transforms
#' @examples
#' if (JuliaConnectoR::juliaSetupOk()) {
#'   dag <- cs_cgraph(A %-->% B, B %-->% C)
#'   cs_skeleton(dag)
#'   cpdag <- cs_dag_to_cpdag(dag)
#'   cs_dag_from_pdag(cpdag)
#' }
NULL

#' @rdname cs-transforms
#' @export
cs_skeleton <- cs_graph_fn("skeleton")

#' @rdname cs-transforms
#' @export
cs_moralize <- cs_graph_fn("moralize")

#' @rdname cs-transforms
#' @export
cs_dag_to_cpdag <- cs_graph_fn("dag_to_cpdag")

#' @rdname cs-transforms
#' @export
cs_dag_from_pdag <- cs_graph_fn("dag_from_pdag")

#' @rdname cs-transforms
#' @export
cs_meek_closure <- cs_graph_fn("meek_closure")

#' @rdname cs-transforms
#' @export
cs_dag_to_mpdag <- cs_graph_fn("dag_to_mpdag")

#' @rdname cs-transforms
#' @export
cs_ag_to_mag <- cs_graph_fn("ag_to_mag")

#' @rdname cs-transforms
#' @export
cs_mag_to_pag <- cs_graph_fn("mag_to_pag")

#' @rdname cs-transforms
#' @export
cs_mag_from_pag <- cs_graph_fn("mag_from_pag")

#' Induced subgraph
#'
#' @param graph A graph created with [cs_cgraph()].
#' @param nodes Character vector of node names to keep.
#' @return A Julia proxy object representing the subgraph.
#' @export
#' @examples
#' if (JuliaConnectoR::juliaSetupOk()) {
#'   dag <- cs_cgraph(A %-->% B, B %-->% C)
#'   cs_nodes(cs_subgraph(dag, c("A", "B")))
#' }
cs_subgraph <- function(graph, nodes) {
  cs_fn("subgraph")(graph, as.character(nodes))
}

#' Project out latent variables
#'
#' Eliminates each node in `latents` by vertex substitution, producing an
#' ADMG over the remaining (observed) variables that preserves the
#' conditional independence structure among them.
#'
#' @param graph A DAG created with [cs_cgraph()].
#' @param latents Character vector of latent (unobserved) node names.
#' @return A Julia proxy object representing the resulting ADMG.
#' @export
#' @examples
#' if (JuliaConnectoR::juliaSetupOk()) {
#'   dag <- cs_cgraph(U %-->% A, U %-->% B, A %-->% B)
#'   cs_edges(cs_latent_project(dag, "U"))
#' }
cs_latent_project <- function(graph, latents) {
  cs_fn("latent_project")(graph, as.character(latents))
}

#' Make nodes exogenous
#'
#' Returns a copy of `graph` with each node in `nodes` made exogenous: its
#' incoming edges are removed, and its parents are connected directly to its
#' children to preserve reachability.
#'
#' @param graph A DAG created with [cs_cgraph()].
#' @param nodes Character vector of node names to exogenize.
#' @return A Julia proxy object representing the resulting DAG.
#' @export
#' @examples
#' if (JuliaConnectoR::juliaSetupOk()) {
#'   dag <- cs_cgraph(A %-->% M, M %-->% Y)
#'   cs_edges(cs_exogenize(dag, "M"))
#' }
cs_exogenize <- function(graph, nodes) {
  cs_fn("exogenize")(graph, as.character(nodes))
}

#' Normalize latent structure
#'
#' Simplifies the latent nodes of `graph` while preserving the induced
#' marginal model over the observed variables (Evans 2016, Lemmas 1-3):
#' exogenizes each latent node, then drops latent nodes with at most one
#' active child or whose child set is a strict subset of another latent
#' node's child set.
#'
#' @param graph A DAG created with [cs_cgraph()].
#' @param latents Character vector of latent (unobserved) node names.
#' @return A Julia proxy object representing the resulting DAG.
#' @export
#' @examples
#' if (JuliaConnectoR::juliaSetupOk()) {
#'   dag <- cs_cgraph(U %-->% A, U %-->% B, A %-->% B)
#'   cs_edges(cs_normalize_latent_structure(dag, "U"))
#' }
cs_normalize_latent_structure <- function(graph, latents) {
  cs_fn("normalize_latent_structure")(graph, as.character(latents))
}

#' Condition and marginalize a graph
#'
#' Removes `cond_vars` and `marg_vars` from `graph`, returning the AG over
#' the remaining nodes that represents the graphical effect of conditioning
#' on `cond_vars` and marginalizing out `marg_vars`. At least one of the two
#' must be non-empty, and they must be disjoint.
#'
#' @param graph A DAG or AG created with [cs_cgraph()].
#' @param cond_vars Character vector of node names to condition on.
#' @param marg_vars Character vector of node names to marginalize out.
#' @return A Julia proxy object representing the resulting AG.
#' @export
#' @examples
#' if (JuliaConnectoR::juliaSetupOk()) {
#'   dag <- cs_cgraph(A %-->% M, M %-->% Y, U %-->% A, U %-->% Y)
#'   cs_edges(cs_condition_marginalize(dag, marg_vars = "U"))
#' }
cs_condition_marginalize <- function(
  graph,
  cond_vars = character(),
  marg_vars = character()
) {
  cs_fn("condition_marginalize")(
    graph,
    as.character(cond_vars),
    as.character(marg_vars)
  )
}

# --- Mutation ----------------------------------------------------------------

#' Add or remove edges
#'
#' `cs_add_edges()` and `cs_remove_edges()` return a new graph of the same
#' class with the edges described by `...` added or removed, using the
#' operators documented at [cs-edge-operators] (e.g. `B %-->% C, C %-->% D`);
#' any isolated-node declarations in `...` are ignored. `cs_remove_edges()`
#' errors if an edge in `...` is not present in `graph`. For programmatic use,
#' pass a spec string via `spec` instead of `...`.
#'
#' @param graph A graph created with [cs_cgraph()].
#' @param ... Edge expressions; see [cs-edge-operators]. Mutually exclusive
#'   with `spec`.
#' @param spec Edge specification string, for programmatic use. Mutually
#'   exclusive with `...`.
#' @return A Julia proxy object representing the resulting graph.
#' @name cs-edge-mutation
#' @examples
#' if (JuliaConnectoR::juliaSetupOk()) {
#'   dag <- cs_cgraph(A %-->% B)
#'   cs_edges(cs_add_edges(dag, B %-->% C))
#'   cs_edges(cs_remove_edges(dag, A %-->% B))
#' }
NULL

#' @rdname cs-edge-mutation
#' @export
cs_add_edges <- function(graph, ..., spec = NULL) {
  cs_fn("add_edges")(graph, .cs_dots_or_spec(substitute(list(...)), spec))
}

#' @rdname cs-edge-mutation
#' @export
cs_remove_edges <- function(graph, ..., spec = NULL) {
  cs_fn("remove_edges")(graph, .cs_dots_or_spec(substitute(list(...)), spec))
}

#' Add or remove isolated nodes
#'
#' `cs_add_nodes()` returns a new graph of the same class with `nodes`
#' added as isolated nodes (nodes already present are ignored).
#' `cs_remove_nodes()` returns a new graph with `nodes` and all their
#' incident edges removed, and errors if a node is not present.
#'
#' @param graph A graph created with [cs_cgraph()].
#' @param nodes Character vector of node names.
#' @return A Julia proxy object representing the resulting graph.
#' @name cs-node-mutation
#' @examples
#' if (JuliaConnectoR::juliaSetupOk()) {
#'   dag <- cs_cgraph(A %-->% B)
#'   cs_nodes(cs_add_nodes(dag, "C"))
#'   cs_nodes(cs_remove_nodes(dag, "B"))
#' }
NULL

#' @rdname cs-node-mutation
#' @export
cs_add_nodes <- function(graph, nodes) {
  cs_fn("add_nodes")(graph, as.character(nodes))
}

#' @rdname cs-node-mutation
#' @export
cs_remove_nodes <- function(graph, nodes) {
  cs_fn("remove_nodes")(graph, as.character(nodes))
}

#' Reclassify a graph
#'
#' Returns a new graph of class `class` with the same nodes and edges as
#' `graph`. Errors if the edges violate the structural constraints of
#' `class`.
#'
#' @param graph A graph created with [cs_cgraph()].
#' @param class Target graph class: `"DAG"`, `"UG"`, `"PDAG"`, `"CPDAG"`,
#'   `"MPDAG"`, `"ADMG"`, `"AG"`, `"MAG"`, `"PAG"`, or `"UNKNOWN"` (no
#'   structural constraints; accepts all edge types).
#' @param simple Only used when `class` is `"UNKNOWN"`; see [cs_cgraph()].
#' @return A Julia proxy object representing the reclassified graph.
#' @export
#' @examples
#' if (JuliaConnectoR::juliaSetupOk()) {
#'   dag <- cs_cgraph(A %-->% B, class = "UNKNOWN")
#'   reclassed <- cs_reclass(dag, class = "DAG")
#'   cs_is_dag(reclassed)
#' }
cs_reclass <- function(
  graph,
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
  cs_fn("reclass")(graph, class, simple)
}
