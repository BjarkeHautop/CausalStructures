# --- Transformations ---------------------------------------------------------

#' Drop edge marks to an undirected graph
#'
#' Returns the skeleton of `cg`: the undirected graph obtained by replacing
#' every directed or partially-directed edge with an undirected edge (a
#' node pair keeps a single edge regardless of how many marked edges
#' connected it).
#'
#' @param cg A DAG or PDAG-family (PDAG, CPDAG, MPDAG) graph created with
#'   [cgraph()].
#' @return A `UG` graph proxy.
#' @export
#' @examples
#' if (julia_ready()) {
#'   dag <- cgraph(A %-->% B, B %-->% C)
#'   skeleton(dag)
#' }
skeleton <- cgraph_fn("skeleton")

#' Moralize a graph
#'
#' Returns the moral graph of `cg`: an undirected graph with a "marriage"
#' edge added between every pair of directed parents that share a common
#' child, then every edge replaced with an undirected edge. For a
#' PDAG-family graph, only directed parents participate in marriage edges;
#' undirected neighbors are carried over but don't form a clique.
#'
#' @param cg A DAG or PDAG-family (PDAG, CPDAG, MPDAG) graph created with
#'   [cgraph()].
#' @return A `UG` graph proxy.
#' @export
#' @examples
#' if (julia_ready()) {
#'   dag <- cgraph(A %-->% C, B %-->% C)
#'   moralize(dag) # A and B are now married
#' }
moralize <- cgraph_fn("moralize")

#' Convert a DAG to its CPDAG
#'
#' Returns the CPDAG representing the Markov equivalence class (MEC) of the
#' DAG `cg`: unshielded colliders (v-structures) determine which edges are
#' compelled, an initial PDAG is built from the skeleton with those
#' orientations, and [meek_closure()] propagates the rest.
#'
#' @param cg A DAG created with [cgraph()].
#' @return A `CPDAG` graph proxy.
#' @export
#' @examples
#' if (julia_ready()) {
#'   dag <- cgraph(A %-->% B, B %-->% C)
#'   dag_to_cpdag(dag)
#' }
dag_to_cpdag <- cgraph_fn("dag_to_cpdag")

#' Extend a PDAG to a consistent DAG
#'
#' Orients every undirected edge of the PDAG-family graph `cg`, using the
#' Dor-Tarsi algorithm: repeatedly find a sink node (no directed children,
#' whose undirected neighbors form a clique), orient all its undirected
#' edges toward it, and remove it. Errors if no valid DAG extension exists.
#'
#' @param cg A PDAG-family (PDAG, CPDAG, MPDAG) graph created with
#'   [cgraph()].
#' @return A `DAG` graph proxy.
#' @references
#' \insertRef{dortarsi1992simple}{CausalStructures}
#' @export
#' @examples
#' if (julia_ready()) {
#'   pdag <- cgraph(A %---% B, B %---% C, class = "PDAG")
#'   dag_from_pdag(pdag)
#' }
dag_from_pdag <- cgraph_fn("dag_from_pdag")

#' Apply Meek's orientation rules
#'
#' Applies Meek's rules R1-R4 to the PDAG-family graph `cg` until no further
#' orientation is implied, returning the resulting MPDAG.
#'
#' * **R1**: `a --> b --- c`, `a` not adjacent to `c` implies `b --> c`.
#' * **R2**: `a --- b`, a directed path `a --> w --> b` exists implies
#'   `a --> b`.
#' * **R3**: `a --- b`, two non-adjacent parents `c, d` of `b` with
#'   `a --- c` and `a --- d` implies `a --> b`.
#' * **R4**: `a --- b`, a directed path `a -->...--> b` exists implies
#'   `a --> b`.
#'
#' @param cg A PDAG-family (PDAG, CPDAG, MPDAG) graph created with
#'   [cgraph()].
#' @return An `MPDAG` graph proxy.
#' @references
#' \insertRef{meek1995causal}{CausalStructures}
#' @export
#' @examples
#' if (julia_ready()) {
#'   pdag <- cgraph(A %-->% B, B %---% C, class = "PDAG")
#'   meek_closure(pdag)
#' }
meek_closure <- cgraph_fn("meek_closure")

#' Convert a DAG to its MPDAG
#'
#' Returns the MPDAG representing the DAGs Markov equivalent to `cg`: the
#' CPDAG of `cg` closed under [meek_closure()]'s rules R1-R4.
#'
#' @param cg A DAG created with [cgraph()].
#' @return An `MPDAG` graph proxy.
#' @references
#' \insertRef{meek1995causal}{CausalStructures}
#' @export
#' @examples
#' if (julia_ready()) {
#'   dag <- cgraph(A %-->% B, B %-->% C)
#'   dag_to_mpdag(dag)
#' }
dag_to_mpdag <- cgraph_fn("dag_to_mpdag")

#' Convert an AG to a Markov equivalent MAG
#'
#' Adds an edge between every pair of non-adjacent nodes in the AG `cg` that
#' cannot be m-separated by any subset of the remaining nodes, producing a
#' Markov equivalent MAG. For each such pair `(u, v)`, the edge is directed
#' toward whichever node is not an ancestor of the other, or bidirected if
#' neither is an ancestor of the other. Edges are added one at a time, with
#' the graph re-evaluated after each addition (a new edge can change
#' m-separation and ancestor relationships).
#'
#' @param cg An AG created with [cgraph()].
#' @return A `MAG` graph proxy.
#' @export
#' @examples
#' if (julia_ready()) {
#'   ag <- cgraph(A %-->% B, B %-->% C, class = "AG")
#'   ag_to_mag(ag)
#' }
ag_to_mag <- cgraph_fn("ag_to_mag")

#' Map a MAG to its PAG equivalence class
#'
#' Returns the PAG representing the Markov equivalence class of the MAG
#' `cg`: same skeleton, with each endpoint kept as an arrowhead or tail only
#' if that mark is shared by every MAG in the class (a circle mark
#' otherwise). Starts from the skeleton with all-circle marks, orients
#' unshielded colliders as they appear in `cg`, then applies Zhang's
#' complete orientation rules R1-R10 until no further mark is implied. The
#' input graph is unchanged; for a single representative MAG instead of the
#' whole class, use [mag_from_pag()].
#'
#' @param cg A MAG created with [cgraph()].
#' @return A `PAG` graph proxy.
#' @references
#' \insertRef{zhang2008completeness}{CausalStructures}
#' @export
#' @examples
#' if (julia_ready()) {
#'   mag <- cgraph(A %-->% B, B %-->% C, class = "MAG")
#'   mag_to_pag(mag)
#' }
mag_to_pag <- cgraph_fn("mag_to_pag")

#' Resolve a PAG to a representative MAG
#'
#' Returns one MAG belonging to the Markov equivalence class represented by
#' the PAG `cg`: a left inverse of [mag_to_pag()], so
#' `mag_to_pag(mag_from_pag(pag))` recovers `pag`. Every circle mark left
#' unresolved by the PAG is resolved to a tail or arrowhead following
#' Zhang's construction (2008, Theorem 2): a circle opposite a fixed mark
#' always becomes directed; an undirected edge (selection bias) is kept
#' unchanged; the remaining all-circle edges form a chordal component,
#' oriented into a DAG with no new unshielded colliders by Dor-Tarsi
#' simplicial elimination.
#'
#' @param cg A PAG created with [cgraph()].
#' @return A `MAG` graph proxy.
#' @references
#' \insertRef{zhang2008completeness}{CausalStructures}
#'
#' \insertRef{dortarsi1992simple}{CausalStructures}
#' @export
#' @examples
#' if (julia_ready()) {
#'   pag <- cgraph(A %o-o% B, B %o-o% C, class = "PAG")
#'   mag_from_pag(pag)
#' }
mag_from_pag <- cgraph_fn("mag_from_pag")

#' Induced subgraph
#'
#' @param cg A graph created with [cgraph()], of any class.
#' @param nodes Character vector of node names to keep.
#' @return A Julia proxy object representing the subgraph.
#' @export
#' @examples
#' if (julia_ready()) {
#'   dag <- cgraph(A %-->% B, B %-->% C)
#'   subgraph(dag, c("A", "B"))
#' }
subgraph <- function(cg, nodes) {
  .tag_cgraph(fn("subgraph")(cg, as.character(nodes)))
}

#' Project out latent variables
#'
#' Project out latent (unobserved) variables to produce an
#' ADMG over the observed variables only.
#'
#' @param cg A DAG created with [cgraph()].
#' @param latents Character vector of latent (unobserved) node names.
#' @return A Julia proxy object representing the resulting ADMG.
#' @export
#' @examples
#' if (julia_ready()) {
#'   dag <- cgraph(U %-->% A, U %-->% B, A %-->% B)
#'   latent_project(dag, "U")
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
#' if (julia_ready()) {
#'   dag <- cgraph(A %-->% M, M %-->% Y)
#'   exogenize(dag, "M")
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
#' if (julia_ready()) {
#'   dag <- cgraph(U %-->% A, U %-->% B, A %-->% B)
#'   normalize_latent_structure(dag, "U")
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
#' if (julia_ready()) {
#'   dag <- cgraph(A %-->% M, M %-->% Y, U %-->% A, U %-->% Y)
#'   condition_marginalize(dag, marg_vars = "U")
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
#' if (julia_ready()) {
#'   dag <- cgraph(A %-->% B)
#'   list(
#'     add_edges = add_edges(dag, B %-->% C),
#'     remove_edges = remove_edges(dag, A %-->% B)
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
#' if (julia_ready()) {
#'   dag <- cgraph(A %-->% B)
#'   list(
#'     add_nodes = add_nodes(dag, "C"),
#'     remove_nodes = remove_nodes(dag, "B")
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
#' @return A Julia proxy object representing the reclassified graph.
#' @export
#' @examples
#' if (julia_ready()) {
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
  )
) {
  class <- match.arg(class)
  .tag_cgraph(fn("reclass")(cg, class))
}
