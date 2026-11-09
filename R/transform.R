# --- Transformations ---------------------------------------------------------

#' Drop edge marks to an undirected graph
#'
#' Returns the skeleton of `cg`, the undirected graph obtained by replacing
#' every edge, of any type, with an undirected edge. Parallel edges between two
#' nodes become one edge, and self-loops are dropped.
#'
#' @param cg A graph created with [cgraph()], of any class.
#' @return A `cgraph` of class `UG`.
#' @examples
#' if (julia_ready()) {
#'   dag <- cgraph(A %-->% B, B %-->% C)
#'   skeleton(dag)
#' }
#' @name skeleton
NULL

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
#' @return A `cgraph` of class `UG`.
#' @examples
#' if (julia_ready()) {
#'   dag <- cgraph(A %-->% C, B %-->% C)
#'   moralize(dag) # A and B are now married
#' }
#' @name moralize
NULL

#' Convert a DAG to its CPDAG
#'
#' Returns the CPDAG representing the Markov equivalence class (MEC) of the
#' DAG `cg`. Unshielded colliders (v-structures) determine which edges are
#' compelled, an initial PDAG is built from the skeleton with those
#' orientations, and [meek_closure()] propagates the rest.
#'
#' @param cg A DAG created with [cgraph()].
#' @return A `cgraph` of class `CPDAG`.
#' @examples
#' if (julia_ready()) {
#'   dag <- cgraph(A %-->% B, B %-->% C)
#'   dag_to_cpdag(dag)
#' }
#' @name dag_to_cpdag
NULL

#' Extend a PDAG to a consistent DAG
#'
#' Orients every undirected edge of the PDAG-family graph `cg`, using the
#' Dor-Tarsi algorithm. It repeatedly finds a sink node (no directed children,
#' whose undirected neighbors form a clique), orients all its undirected
#' edges toward it, and removes it. Errors if no valid DAG extension exists.
#'
#' @param cg A PDAG-family (PDAG, CPDAG, MPDAG) graph created with
#'   [cgraph()].
#' @return A `cgraph` of class `DAG`.
#' @references
#' \insertRef{dortarsi1992simple}{CausalStructures}
#' @examples
#' if (julia_ready()) {
#'   pdag <- cgraph(A %---% B, B %---% C, class = "PDAG")
#'   dag_from_pdag(pdag)
#' }
#' @name dag_from_pdag
NULL

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
#' * **R4**: `a --- b`, `a --- c`, and `c --> d --> b`, with `c` not adjacent to
#'   `b` and `a` adjacent to `d`, implies `a --> b`.
#'
#' @param cg A PDAG-family (PDAG, CPDAG, MPDAG) graph created with
#'   [cgraph()].
#' @param check_cycles If `TRUE` (default), check every orientation for a
#'   directed cycle it would close, and error if a rule implies one: every DAG
#'   consistent with `cg` would contain it, so `cg` has no consistent DAG
#'   extension and no MPDAG closes it. Disabling this can speed up closure when
#'   `cg` is known to admit no such cycle, but then the result is not checked
#'   to be acyclic.
#' @param r4 If `TRUE` (default), apply rule R4. Disabling this can speed up
#'   closure when `cg` is known not to need it (e.g. it has no background
#'   knowledge beyond the v-structures already encoded in it).
#' @return A `cgraph` of class `MPDAG`.
#' @references
#' \insertRef{meek1995causal}{CausalStructures}
#' @examples
#' if (julia_ready()) {
#'   pdag <- cgraph(A %-->% B, B %---% C, class = "PDAG")
#'   meek_closure(pdag)
#' }
#' @name meek_closure
NULL

#' Convert a DAG to its MPDAG
#'
#' Returns the MPDAG representing the DAGs Markov equivalent to `cg` and
#' consistent with any background knowledge: the CPDAG of `cg` with that
#' knowledge applied, closed under [meek_closure()]'s rules R1-R4. Errors if
#' `cg` itself violates the knowledge, i.e. it lacks a required edge or has a
#' forbidden one.
#'
#' @param cg A DAG created with [cgraph()].
#' @param ... Required (`%-->%`, `%<--%`) and forbidden (`%!-->%`,
#'   `%!<--%`) edges; see [edge-operators]. Mutually exclusive with `spec`.
#' @param spec Background knowledge as a string, e.g. `"A --> B, C !--> D"`,
#'   for programmatic use. Mutually exclusive with `...`.
#' @return A `cgraph` of class `MPDAG`.
#' @references
#' \insertRef{meek1995causal}{CausalStructures}
#' @export
#' @examples
#' if (julia_ready()) {
#'   dag <- cgraph(A %-->% B, B %-->% C)
#'   list(
#'     no_knowledge = dag_to_mpdag(dag),
#'     required = dag_to_mpdag(dag, A %-->% B)
#'   )
#' }
dag_to_mpdag <- function(cg, ..., spec = NULL) {
  knowledge <- if (...length() > 0L || !is.null(spec)) {
    .dots_or_spec(substitute(list(...)), spec)
  } else {
    ""
  }
  jl_dag_to_mpdag(cg, knowledge)
}

#' Apply background knowledge to a PDAG
#'
#' Orients `cg` according to background knowledge about direct causes:
#' required edges (`A %-->% B`, `A` must directly cause `B`) and forbidden
#' ones (`A %!-->% B`, `A` must not).
#'
#' Requiring `A --> B` orients `A --- B`
#' that way, and forbidding it orients `A --- B` as `B --> A`; after each,
#' Meek's rules propagate the orientations it implies. Background knowledge
#' only orients edges, so it errors when it would add or remove one: a
#' required edge between non-adjacent nodes or against an orientation `cg`
#' (or an earlier item) already has, or a forbidden edge `cg` already has.
#'
#' @param cg A PDAG-family graph (PDAG, CPDAG, MPDAG) created with [cgraph()].
#' @param ... Required (`%-->%`, `%<--%`) and forbidden (`%!-->%`,
#'   `%!<--%`) edges; see [edge-operators]. Mutually exclusive with `spec`.
#' @param spec Background knowledge as a string, e.g. `"A --> B, C !--> D"`,
#'   for programmatic use. Mutually exclusive with `...`.
#' @return A `cgraph` of class `MPDAG`.
#' @references
#' \insertRef{meek1995causal}{CausalStructures}
#' @export
#' @examples
#' if (julia_ready()) {
#'   cpdag <- cgraph(A %---% B %---% C, class = "CPDAG")
#'   list(
#'     required = apply_background_knowledge(cpdag, A %-->% B),
#'     forbidden = apply_background_knowledge(cpdag, C %!-->% B)
#'   )
#' }
apply_background_knowledge <- function(cg, ..., spec = NULL) {
  jl_apply_background_knowledge(cg, .dots_or_spec(substitute(list(...)), spec))
}

#' Convert an AG to a Markov equivalent MAG
#'
#' Adds an edge between every pair of non-adjacent nodes in the AG `cg` that
#' cannot be m-separated by any subset of the remaining nodes, producing a
#' Markov equivalent MAG.
#'
#' For each such pair `(u, v)`, the edge is directed
#' toward whichever node is not an ancestor of the other, or bidirected if
#' neither is an ancestor of the other. Edges are added one at a time, with
#' the graph re-evaluated after each addition (a new edge can change
#' m-separation and ancestor relationships).
#'
#' @param cg An AG created with [cgraph()].
#' @return A `cgraph` of class `MAG`.
#' @examples
#' if (julia_ready()) {
#'   ag <- cgraph(A %-->% B, B %-->% C, class = "AG")
#'   ag_to_mag(ag)
#' }
#' @name ag_to_mag
NULL

#' Map a MAG to its PAG equivalence class
#'
#' Returns the PAG representing the Markov equivalence class of the MAG
#' `cg`. It has the same skeleton, with each endpoint kept as an arrowhead or
#' tail only if that mark is shared by every MAG in the class (a circle mark
#' otherwise). To go back to a single MAG of the class, use [mag_from_pag()].
#'
#' Starts from the skeleton with all-circle marks, orients unshielded colliders
#' as they appear in `cg`, then applies Zhang's complete orientation rules
#' R1-R10 until no further mark is implied.
#'
#' @param cg A MAG created with [cgraph()].
#' @return A `cgraph` of class `PAG`.
#' @references
#' \insertRef{zhang2008completeness}{CausalStructures}
#' @examples
#' if (julia_ready()) {
#'   mag <- cgraph(A %-->% B, B %-->% C, class = "MAG")
#'   mag_to_pag(mag)
#' }
#' @name mag_to_pag
NULL

#' Resolve a PAG to a representative MAG
#'
#' Returns one MAG belonging to the Markov equivalence class represented by
#' the PAG `cg`: a left inverse of [mag_to_pag()], so
#' `mag_to_pag(mag_from_pag(pag))` recovers `pag`.
#'
#' Every circle mark left
#' unresolved by the PAG is resolved to a tail or arrowhead following
#' Zhang's construction (2008, Theorem 2): a circle opposite a fixed mark
#' always becomes directed; an undirected edge (selection bias) is kept
#' unchanged; the remaining all-circle edges form a chordal component,
#' oriented into a DAG with no new unshielded colliders by Dor-Tarsi
#' simplicial elimination.
#'
#' @param cg A PAG created with [cgraph()].
#' @return A `cgraph` of class `MAG`.
#' @references
#' \insertRef{zhang2008completeness}{CausalStructures}
#'
#' \insertRef{dortarsi1992simple}{CausalStructures}
#' @examples
#' if (julia_ready()) {
#'   pag <- cgraph(A %o-o% B, B %o-o% C, class = "PAG")
#'   mag_from_pag(pag)
#' }
#' @name mag_from_pag
NULL

#' Induced subgraph
#'
#' Returns the graph on `nodes` with every edge of `cg` between them. Errors if
#' a node is not in `cg`.
#'
#' @param cg A graph created with [cgraph()], of any class.
#' @param nodes Character vector of node names to keep.
#' @return A `cgraph`.
#' @export
#' @examples
#' if (julia_ready()) {
#'   dag <- cgraph(A %-->% B, B %-->% C)
#'   subgraph(dag, c("A", "B"))
#' }
subgraph <- function(cg, nodes) {
  jl_subgraph(cg, as.character(nodes))
}

#' Project out latent variables
#'
#' Project out latent (unobserved) variables to produce an
#' ADMG over the observed variables only.
#'
#' @param cg A DAG created with [cgraph()].
#' @param latents Character vector of latent (unobserved) node names.
#' @return A `cgraph` of class `ADMG`.
#' @export
#' @examples
#' if (julia_ready()) {
#'   dag <- cgraph(U %-->% A, U %-->% B, A %-->% B)
#'   latent_project(dag, "U")
#' }
latent_project <- function(cg, latents) {
  jl_latent_project(cg, as.character(latents))
}

#' Make nodes exogenous
#'
#' Returns a copy of `cg` with each node in `nodes` made exogenous: its
#' incoming edges are removed, and its parents are connected directly to its
#' children to preserve reachability.
#'
#' @param cg A DAG created with [cgraph()].
#' @param nodes Character vector of node names to exogenize.
#' @return A `cgraph` of class `DAG`.
#' @export
#' @examples
#' if (julia_ready()) {
#'   dag <- cgraph(A %-->% M, M %-->% Y)
#'   exogenize(dag, "M")
#' }
exogenize <- function(cg, nodes) {
  jl_exogenize(cg, as.character(nodes))
}

#' Normalize latent structure
#'
#' Simplifies the latent nodes of `cg` while preserving the induced
#' marginal model over the observed variables (Lemmas 1-3 of the reference
#' below). It exogenizes each latent node, then drops latent nodes with at most
#' one active child or whose child set is a strict subset of another latent
#' node's child set.
#'
#' @param cg A DAG created with [cgraph()].
#' @param latents Character vector of latent (unobserved) node names.
#' @return A `cgraph` of class `DAG`.
#' @references
#' \insertRef{evans2016graphs}{CausalStructures}
#' @export
#' @examples
#' if (julia_ready()) {
#'   dag <- cgraph(U %-->% A, U %-->% B, A %-->% B)
#'   normalize_latent_structure(dag, "U")
#' }
normalize_latent_structure <- function(cg, latents) {
  jl_normalize_latent_structure(cg, as.character(latents))
}

#' Condition and marginalize a graph
#'
#' Removes `given` and `index` from `cg`, returning the AG over the
#' remaining nodes that represents the graphical effect of conditioning on
#' `given` and marginalizing out `index`. At least one of the two must be
#' non-empty, and they must be disjoint.
#'
#' @param cg A DAG, ADMG, or AG-family (AG, MAG) graph created with
#'   [cgraph()].
#' @param given Character vector of node names to condition on.
#' @param index Character vector of node names to marginalize out.
#' @return A `cgraph` of class `AG`.
#' @export
#' @examples
#' if (julia_ready()) {
#'   dag <- cgraph(A %-->% M, M %-->% Y, U %-->% A, U %-->% Y)
#'   condition_marginalize(dag, index = "U")
#' }
condition_marginalize <- function(
  cg,
  given = character(),
  index = character()
) {
  jl_condition_marginalize(cg, as.character(given), as.character(index))
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
#' @return A `cgraph`.
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
  jl_add_edges(cg, .dots_or_spec(substitute(list(...)), spec))
}

#' @rdname edge-mutation
#' @export
remove_edges <- function(cg, ..., spec = NULL) {
  jl_remove_edges(cg, .dots_or_spec(substitute(list(...)), spec))
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
#' @return A `cgraph`.
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
  jl_add_nodes(cg, as.character(nodes))
}

#' @rdname node-mutation
#' @export
remove_nodes <- function(cg, nodes) {
  jl_remove_nodes(cg, as.character(nodes))
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
#' @return A `cgraph`.
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
  class <- if (missing(class)) class[[1L]] else match.arg(class)
  jl_reclass(cg, class)
}
