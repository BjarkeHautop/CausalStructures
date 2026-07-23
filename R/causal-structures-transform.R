# --- Transformations ---------------------------------------------------------

#' Graph transformations
#'
#' `skeleton()` drops edge marks, `moralize()` moralizes a DAG,
#' `dag_to_cpdag()` and `dag_from_pdag()` convert between equivalence
#' classes, `meek_closure()` applies Meek's rules, `ag_to_mag()`
#' converts an AG to a Markov equivalent MAG, `mag_to_pag()` maps a MAG to
#' its PAG equivalence class representative, and `mag_from_pag()` resolves
#' a PAG back to a representative MAG. All return a new graph proxy; the
#' input graph is unchanged.
#'
#' @param cg A graph created with [cgraph()]. Required class depends on
#'   the function: `skeleton()` and `moralize()` take a DAG or
#'   PDAG-family (PDAG, CPDAG, MPDAG) graph; `dag_to_cpdag()` and
#'   `dag_to_mpdag()` take a DAG; `dag_from_pdag()` and
#'   `meek_closure()` take a PDAG-family graph; `ag_to_mag()` takes an
#'   AG; `mag_to_pag()` takes a MAG; `mag_from_pag()` takes a PAG.
#' @return A Julia proxy object representing the transformed graph.
#' @name transforms
#' @examples
#' if (julia_available()) {
#'   dag <- cgraph(A %-->% B, B %-->% C)
#'   skeleton(dag)
#' }
#'
#' if (julia_available()) {
#'   dag <- cgraph(A %-->% B, B %-->% C)
#'   cpdag <- dag_to_cpdag(dag)
#'   dag_from_pdag(cpdag)
#' }
NULL

#' @rdname transforms
#' @export
skeleton <- cgraph_fn("skeleton")

#' @rdname transforms
#' @export
moralize <- cgraph_fn("moralize")

#' @rdname transforms
#' @export
dag_to_cpdag <- cgraph_fn("dag_to_cpdag")

#' @rdname transforms
#' @export
dag_from_pdag <- cgraph_fn("dag_from_pdag")

#' @rdname transforms
#' @export
meek_closure <- cgraph_fn("meek_closure")

#' @rdname transforms
#' @export
dag_to_mpdag <- cgraph_fn("dag_to_mpdag")

#' @rdname transforms
#' @export
ag_to_mag <- cgraph_fn("ag_to_mag")

#' @rdname transforms
#' @export
mag_to_pag <- cgraph_fn("mag_to_pag")

#' @rdname transforms
#' @export
mag_from_pag <- cgraph_fn("mag_from_pag")

#' Induced subgraph
#'
#' @param cg A graph created with [cgraph()], of any class.
#' @param nodes Character vector of node names to keep.
#' @return A Julia proxy object representing the subgraph.
#' @export
#' @examples
#' if (julia_available()) {
#'   dag <- cgraph(A %-->% B, B %-->% C)
#'   nodes(subgraph(dag, c("A", "B")))
#' }
subgraph <- function(cg, nodes) {
  .tag_cgraph(fn("subgraph")(cg, as.character(nodes)))
}

#' Project out latent variables
#'
#' Eliminates each node in `latents` by vertex substitution, producing an
#' ADMG over the remaining (observed) variables that preserves the
#' conditional independence structure among them.
#'
#' @param cg A DAG created with [cgraph()].
#' @param latents Character vector of latent (unobserved) node names.
#' @return A Julia proxy object representing the resulting ADMG.
#' @export
#' @examples
#' if (julia_available()) {
#'   dag <- cgraph(U %-->% A, U %-->% B, A %-->% B)
#'   edges(latent_project(dag, "U"))
#' }
latent_project <- function(cg, latents) {
  .tag_cgraph(fn("latent_project")(cg, as.character(latents)))
}

#' Make nodes exogenous
#'
#' Returns a copy of `cg` with each node in `nodes` made exogenous: its
#' incoming edges are removed, and its parents are connected directly to its
#' children to preserve reachability.
#'
#' @param cg A DAG created with [cgraph()].
#' @param nodes Character vector of node names to exogenize.
#' @return A Julia proxy object representing the resulting DAG.
#' @export
#' @examples
#' if (julia_available()) {
#'   dag <- cgraph(A %-->% M, M %-->% Y)
#'   edges(exogenize(dag, "M"))
#' }
exogenize <- function(cg, nodes) {
  .tag_cgraph(fn("exogenize")(cg, as.character(nodes)))
}

#' Normalize latent structure
#'
#' Simplifies the latent nodes of `cg` while preserving the induced
#' marginal model over the observed variables (Evans 2016, Lemmas 1-3):
#' exogenizes each latent node, then drops latent nodes with at most one
#' active child or whose child set is a strict subset of another latent
#' node's child set.
#'
#' @param cg A DAG created with [cgraph()].
#' @param latents Character vector of latent (unobserved) node names.
#' @return A Julia proxy object representing the resulting DAG.
#' @export
#' @examples
#' if (julia_available()) {
#'   dag <- cgraph(U %-->% A, U %-->% B, A %-->% B)
#'   edges(normalize_latent_structure(dag, "U"))
#' }
normalize_latent_structure <- function(cg, latents) {
  .tag_cgraph(fn("normalize_latent_structure")(cg, as.character(latents)))
}

#' Condition and marginalize a graph
#'
#' Removes `cond_vars` and `marg_vars` from `cg`, returning the AG over
#' the remaining nodes that represents the graphical effect of conditioning
#' on `cond_vars` and marginalizing out `marg_vars`. At least one of the two
#' must be non-empty, and they must be disjoint.
#'
#' @param cg A DAG or AG-family (AG, MAG) graph created with [cgraph()].
#' @param cond_vars Character vector of node names to condition on.
#' @param marg_vars Character vector of node names to marginalize out.
#' @return A Julia proxy object representing the resulting AG.
#' @export
#' @examples
#' if (julia_available()) {
#'   dag <- cgraph(A %-->% M, M %-->% Y, U %-->% A, U %-->% Y)
#'   edges(condition_marginalize(dag, marg_vars = "U"))
#' }
condition_marginalize <- function(
  cg,
  cond_vars = character(),
  marg_vars = character()
) {
  .tag_cgraph(fn("condition_marginalize")(
    cg,
    as.character(cond_vars),
    as.character(marg_vars)
  ))
}

# --- Mutation ----------------------------------------------------------------

#' Add or remove edges
#'
#' `add_edges()` and `remove_edges()` return a new graph of the same
#' class with the edges described by `...` added or removed, using the
#' operators documented at [edge-operators] (e.g. `B %-->% C, C %-->% D`);
#' any isolated-node declarations in `...` are ignored. `remove_edges()`
#' errors if an edge in `...` is not present in `cg`. For programmatic use,
#' pass a spec string via `spec` instead of `...`.
#'
#' @param cg A graph created with [cgraph()], of any class.
#' @param ... Edge expressions; see [edge-operators]. Mutually exclusive
#'   with `spec`.
#' @param spec Edge specification string, for programmatic use. Mutually
#'   exclusive with `...`.
#' @return A Julia proxy object representing the resulting graph.
#' @name edge-mutation
#' @examples
#' if (julia_available()) {
#'   dag <- cgraph(A %-->% B)
#'   list(
#'     add_edges = edges(add_edges(dag, B %-->% C)),
#'     remove_edges = edges(remove_edges(dag, A %-->% B))
#'   )
#' }
NULL

#' @rdname edge-mutation
#' @export
add_edges <- function(cg, ..., spec = NULL) {
  .tag_cgraph(fn("add_edges")(cg, .dots_or_spec(substitute(list(...)), spec)))
}

#' @rdname edge-mutation
#' @export
remove_edges <- function(cg, ..., spec = NULL) {
  .tag_cgraph(fn("remove_edges")(
    cg,
    .dots_or_spec(substitute(list(...)), spec)
  ))
}

#' Add or remove isolated nodes
#'
#' `add_nodes()` returns a new graph of the same class with `nodes`
#' added as isolated nodes (nodes already present are ignored).
#' `remove_nodes()` returns a new graph with `nodes` and all their
#' incident edges removed, and errors if a node is not present.
#'
#' @param cg A graph created with [cgraph()], of any class.
#' @param nodes Character vector of node names.
#' @return A Julia proxy object representing the resulting graph.
#' @name node-mutation
#' @examples
#' if (julia_available()) {
#'   dag <- cgraph(A %-->% B)
#'   list(
#'     add_nodes = nodes(add_nodes(dag, "C")),
#'     remove_nodes = nodes(remove_nodes(dag, "B"))
#'   )
#' }
NULL

#' @rdname node-mutation
#' @export
add_nodes <- function(cg, nodes) {
  .tag_cgraph(fn("add_nodes")(cg, as.character(nodes)))
}

#' @rdname node-mutation
#' @export
remove_nodes <- function(cg, nodes) {
  .tag_cgraph(fn("remove_nodes")(cg, as.character(nodes)))
}

#' Reclassify a graph
#'
#' Returns a new graph of class `class` with the same nodes and edges as
#' `cg`. Errors if the edges violate the structural constraints of
#' `class`.
#'
#' @param cg A graph created with [cgraph()], of any class.
#' @param class Target graph class: `"DAG"`, `"UG"`, `"PDAG"`, `"CPDAG"`,
#'   `"MPDAG"`, `"ADMG"`, `"AG"`, `"MAG"`, `"PAG"`, or `"UNKNOWN"` (no
#'   structural constraints; accepts all edge types).
#' @param simple Only used when `class` is `"UNKNOWN"`; see [cgraph()].
#' @return A Julia proxy object representing the reclassified graph.
#' @export
#' @examples
#' if (julia_available()) {
#'   dag <- cgraph(A %-->% B, class = "UNKNOWN")
#'   reclassed <- reclass(dag, class = "DAG")
#'   is_dag(reclassed)
#' }
reclass <- function(
  cg,
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
  .tag_cgraph(fn("reclass")(cg, class, simple))
}
