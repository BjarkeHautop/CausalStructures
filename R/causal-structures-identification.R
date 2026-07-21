# --- Separation --------------------------------------------------------------

#' Test d-separation
#'
#' Two nodes are d-separated given a conditioning set `given` if every path
#' between them is blocked: a path is blocked if it contains either a
#' non-collider node in `given`, or a collider node (and all its descendants)
#' not in `given`.
#'
#' @param cg A DAG or PDAG-family (PDAG, CPDAG, MPDAG) graph created with
#'   [cs_cgraph()].
#' @param x,y Node names.
#' @param given Character vector of conditioning node names (may be empty).
#' @return `TRUE` if `x` and `y` are d-separated given `given`.
#' @export
#' @examples
#' if (JuliaConnectoR::juliaSetupOk()) {
#'   chain <- cs_cgraph(A %-->% B, B %-->% C)
#'   cs_d_separated(chain, "A", "C") # chain A --> B --> C is open
#'   cs_d_separated(chain, "A", "C", "B") # conditioning on B blocks it
#'
#'   collider <- cs_cgraph(A %-->% C, B %-->% C)
#'   cs_d_separated(collider, "A", "B") # collider A --> C <-- B: blocked
#'   cs_d_separated(collider, "A", "B", "C") # conditioning on C opens it
#' }
cs_d_separated <- function(cg, x, y, given = character()) {
  cs_fn("d_separated")(cg, x, y, as.character(given))
}

#' Test m-separation
#'
#' Generalizes d-separation to graphs with bidirected and undirected edges;
#' for a DAG, m-separation is equivalent to [cs_d_separated()].
#'
#' @inheritParams cs_d_separated
#' @param cg A DAG, ADMG, or AG-family (AG, MAG) graph created with
#'   [cs_cgraph()].
#' @return `TRUE` if `x` and `y` are m-separated given `given`.
#' @export
#' @examples
#' if (JuliaConnectoR::juliaSetupOk()) {
#'   admg <- cs_cgraph(A %-->% B, A %<->% C, class = "ADMG")
#'   cs_m_separated(admg, "B", "C") # connected via the bidirected edge at A
#'   cs_m_separated(admg, "B", "C", "A") # conditioning on A blocks the path
#' }
cs_m_separated <- function(cg, x, y, given = character()) {
  cs_fn("m_separated")(cg, x, y, as.character(given))
}

#' Find a minimal separator
#'
#' Finds a minimal d-separator (DAG, PDAG classes) or m-separator
#' (ADMG, ancestral-graph classes) between `x` and `y`: no proper subset
#' (excluding forced `include` nodes) of the returned set still separates
#' them.
#'
#' @param cg A DAG, ADMG, AG-family (AG, MAG), or PDAG-family (PDAG, CPDAG,
#'   MPDAG) graph created with [cs_cgraph()].
#' @param x,y Node names.
#' @param include Character vector of nodes forced into the separator (must
#'   be a subset of `restrict`, if given).
#' @param restrict Character vector of candidate nodes the separator is
#'   drawn from. `NULL` (default) allows every node except `x` and `y`.
#' @return Character vector with a minimal separating set, or `NULL` if none
#'   exists.
#' @export
#' @examples
#' if (JuliaConnectoR::juliaSetupOk()) {
#'   dag <- cs_cgraph(A %-->% X, X %-->% M, M %-->% Y, A %-->% Y)
#'   cs_minimal_separator(dag, "X", "Y") # both A and M are needed
#'
#'   edge <- cs_cgraph(A %-->% B)
#'   cs_minimal_separator(edge, "A", "B") # direct edge: no separator exists
#'
#'   cs_minimal_separator(dag, "X", "Y", include = "M") # force M in
#'   cs_minimal_separator(dag, "X", "Y", restrict = "M") # M alone can't block
#' }
cs_minimal_separator <- function(
  cg,
  x,
  y,
  include = character(),
  restrict = NULL
) {
  restrict_arg <- if (is.null(restrict)) NULL else as.character(restrict)
  res <- cs_fn("minimal_separator")(
    cg,
    x,
    y,
    as.character(include),
    restrict_arg
  )
  if (is.null(res)) NULL else cs_split(res)
}

# --- Causal identification ---------------------------------------------------

#' Find an adjustment set
#'
#' Computes a valid adjustment set for the total causal effect of `x` on `y`.
#'
#' @details
#' The supported adjustment set types depend on the graph class:
#' \describe{
#'   \item{DAG}{All three types are supported.}
#'   \item{PDAG-family (PDAG, CPDAG, MPDAG)}{Only `"parents"` and
#'     `"optimal"` are supported; `"backdoor"` raises an error.}
#'   \item{MAG-family (AG, MAG)}{`type` is ignored. The smallest valid
#'     adjustment set is returned by searching sets of increasing size.}
#' }
#'
#' The available adjustment set types are:
#' \describe{
#'   \item{`"parents"`}{The parents of `x`, excluding `x` and `y`.}
#'   \item{`"backdoor"`}{The adjustment set implied by Pearl's backdoor
#'     criterion (the parents of `x`).}
#'   \item{`"optimal"`}{The O-set: the parents of causal nodes on a
#'     possibly causal path from `x` to `y`, excluding `x` and those
#'     causal nodes themselves.}
#' }
#'
#' Candidate adjustment sets can be validated with
#' [cs_is_valid_adjustment()].
#'
#' @param cg A DAG, PDAG-family (PDAG, CPDAG, MPDAG), or AG-family (AG, MAG)
#'   graph created with [cs_cgraph()].
#' @param x,y Exposure and outcome node names.
#' @param type Adjustment set type: `"optimal"` (default), `"parents"`, or
#'   `"backdoor"`. Ignored for MAG-family graphs; `"backdoor"` is not
#'   supported for PDAG-family graphs.
#' @return Character vector with a valid adjustment set, or `NULL` if none
#'   exists.
#' @references
#' \insertRef{henckel2022graphical}{testpkg} (`"optimal"`)
#'
#' \insertRef{pearl2009causality}{testpkg} (`"parents"` and `"backdoor"`)
#' @export
#' @examples
#' if (JuliaConnectoR::juliaSetupOk()) {
#'   dag <- cs_cgraph(
#'     C %-->% X, X %-->% F + D, A %-->% X + K, K %-->% Y,
#'     D %-->% Y + G, Y %-->% H
#'   )
#'   sort(cs_adjustment_set(dag, "X", "Y", type = "parents")) # A, C
#'   cs_adjustment_set(dag, "X", "Y", type = "backdoor") # A
#'   cs_adjustment_set(dag, "X", "Y", type = "optimal") # K (default)
#'
#'   pdag <- cs_cgraph(A %-->% X, X %-->% Y, A %-->% Y, class = "PDAG")
#'   cs_adjustment_set(pdag, "X", "Y") # A
#'   cs_is_valid_adjustment(pdag, "X", "Y", "A")
#'
#'   mag <- cs_cgraph(A %<->% X, A %-->% Y, X %-->% Y, class = "MAG")
#'   cs_adjustment_set(mag, "X", "Y") # A; type is ignored
#' }
cs_adjustment_set <- function(
  cg,
  x,
  y,
  type = c("optimal", "parents", "backdoor")
) {
  type <- match.arg(type)
  res <- cs_fn("adjustment_set")(cg, x, y, type)
  if (is.null(res)) NULL else cs_split(res)
}

#' Find a frontdoor adjustment set
#'
#' Returns a set `Z` with `include ⊆ Z ⊆ restrict` satisfying all three
#' front-door conditions (Algorithm 1 of the reference below) for the causal
#' effect of `x` on `y`; validate a candidate set directly with
#' [cs_is_valid_frontdoor()].
#'
#' @param cg A DAG created with [cs_cgraph()].
#' @param x,y Exposure and outcome node names.
#' @param include Character vector of nodes forced into the set.
#' @param restrict Character vector of candidate nodes the set is drawn
#'   from. `NULL` (default) allows every node except `x` and `y`.
#' @return Character vector with a valid frontdoor set, or `NULL` if none
#'   exists.
#' @references
#' \insertRef{jeong2022finding}{testpkg}
#' @export
#' @examples
#' if (JuliaConnectoR::juliaSetupOk()) {
#'   dag <- cs_cgraph(U %-->% X, U %-->% Y, X %-->% Z, Z %-->% Y)
#'   cs_frontdoor_set(dag, "X", "Y") # Z mediates X -> Y
#'   cs_frontdoor_set(dag, "X", "Y", restrict = "Z")
#' }
cs_frontdoor_set <- function(
  cg,
  x,
  y,
  include = character(),
  restrict = NULL
) {
  restrict_arg <- if (is.null(restrict)) NULL else as.character(restrict)
  res <- cs_fn("frontdoor_set")(
    cg,
    x,
    y,
    as.character(include),
    restrict_arg
  )
  if (is.null(res)) NULL else cs_split(res)
}

#' Validate a backdoor adjustment set
#'
#' `given` is a valid backdoor set if (1) no node in `given` is a descendant
#' of `x`, and (2) `given` blocks every backdoor path from `x` to `y` (every
#' parent of `x` is d-separated from `y` given `given` together with `x`).
#'
#' @param cg A DAG or ADMG created with [cs_cgraph()].
#' @param x,y Exposure and outcome node names.
#' @param given Character vector of adjustment node names (may be empty).
#' @return `TRUE` if `given` satisfies the backdoor criterion.
#' @export
#' @examples
#' if (JuliaConnectoR::juliaSetupOk()) {
#'   dag <- cs_cgraph(A %-->% X, X %-->% Y, A %-->% Y)
#'   cs_is_valid_backdoor(dag, "X", "Y") # empty set leaves A --> Y open
#'   cs_is_valid_backdoor(dag, "X", "Y", "A") # conditioning on A blocks it
#' }
cs_is_valid_backdoor <- function(cg, x, y, given = character()) {
  cs_fn("is_valid_backdoor")(cg, x, y, as.character(given))
}

#' Enumerate backdoor adjustment sets
#'
#' Lists all sets (up to size `max_size`) satisfying the backdoor criterion;
#' see [cs_is_valid_backdoor()]. When `minimal = TRUE` (default), only
#' inclusion-minimal sets are returned.
#'
#' @param cg A DAG or ADMG created with [cs_cgraph()].
#' @param x,y Exposure and outcome node names.
#' @param minimal If `TRUE` (default), return only minimal sets.
#' @param max_size Maximum adjustment set size to consider.
#' @return List of character vectors (empty list if none exist).
#' @export
#' @examples
#' if (JuliaConnectoR::juliaSetupOk()) {
#'   dag <- cs_cgraph(A %-->% X, X %-->% Y, A %-->% Y)
#'   cs_all_backdoor_sets(dag, "X", "Y")
#' }
cs_all_backdoor_sets <- function(cg, x, y, minimal = TRUE, max_size = 3) {
  cs_split_sets(cs_fn("all_backdoor_sets")(cg, x, y, minimal, max_size))
}

#' Enumerate frontdoor adjustment sets
#'
#' Lists all sets `Z` with `include ⊆ Z ⊆ restrict` satisfying the
#' front-door criterion; see [cs_frontdoor_set()] and
#' [cs_is_valid_frontdoor()].
#'
#' @param cg A DAG created with [cs_cgraph()].
#' @param x,y Exposure and outcome node names.
#' @param include Character vector of nodes forced into every set.
#' @param restrict Character vector of candidate nodes sets are drawn from.
#'   `NULL` (default) allows every node except `x` and `y`.
#' @return List of character vectors (empty list if none exist).
#' @export
#' @examples
#' if (JuliaConnectoR::juliaSetupOk()) {
#'   dag <- cs_cgraph(U %-->% X, U %-->% Y, X %-->% Z, Z %-->% Y)
#'   cs_all_frontdoor_sets(dag, "X", "Y", restrict = "Z")
#' }
cs_all_frontdoor_sets <- function(
  cg,
  x,
  y,
  include = character(),
  restrict = NULL
) {
  restrict_arg <- if (is.null(restrict)) NULL else as.character(restrict)
  cs_split_sets(
    cs_fn("all_frontdoor_sets")(
      cg,
      x,
      y,
      as.character(include),
      restrict_arg
    )
  )
}

#' Validate an adjustment set
#'
#' Tests the Generalized Adjustment Criterion, which covers ADMGs,
#' PDAG-family graphs, and MAG-family graphs alike: `given` must contain no
#' forbidden node (a descendant of a proper causal node between `x` and `y`,
#' or `x` itself), and must m-separate `x` from `y` in the proper backdoor
#' graph.
#'
#' @param cg An ADMG, PDAG-family (PDAG, CPDAG, MPDAG), or AG-family (AG,
#'   MAG) graph created with [cs_cgraph()].
#' @param x,y Exposure and outcome node names.
#' @param given Character vector of adjustment node names (may be empty).
#' @return `TRUE` if `given` satisfies the adjustment criterion for
#'   identifying the causal effect of `x` on `y`.
#' @references
#' \insertRef{perkovic2018complete}{testpkg}
#' @export
#' @examples
#' if (JuliaConnectoR::juliaSetupOk()) {
#'   admg <- cs_cgraph(L %-->% X, X %-->% Y, L %-->% Y, class = "ADMG")
#'   cs_is_valid_adjustment(admg, "X", "Y") # empty set does not block L --> Y
#'   cs_is_valid_adjustment(admg, "X", "Y", "L") # conditioning on L blocks it
#' }
cs_is_valid_adjustment <- function(cg, x, y, given = character()) {
  cs_fn("is_valid_adjustment")(cg, x, y, as.character(given))
}

#' Enumerate all valid adjustment sets
#'
#' Lists all sets (up to size `max_size`) satisfying the Generalized
#' Adjustment Criterion; see [cs_is_valid_adjustment()]. When
#' `minimal = TRUE` (default), only inclusion-minimal sets are returned.
#'
#' @param cg An ADMG, PDAG-family (PDAG, CPDAG, MPDAG), or AG-family (AG,
#'   MAG) graph created with [cs_cgraph()].
#' @param x,y Exposure and outcome node names.
#' @param minimal If `TRUE` (default), return only minimal sets.
#' @param max_size Maximum adjustment set size to consider.
#' @return List of character vectors (empty list if none exist).
#' @export
#' @examples
#' if (JuliaConnectoR::juliaSetupOk()) {
#'   admg <- cs_cgraph(L %-->% X, X %-->% Y, L %-->% Y, class = "ADMG")
#'   cs_all_adjustment_sets(admg, "X", "Y")
#' }
cs_all_adjustment_sets <- function(cg, x, y, minimal = TRUE, max_size = 3) {
  cs_split_sets(cs_fn("all_adjustment_sets")(cg, x, y, minimal, max_size))
}

#' Validate a frontdoor criterion set
#'
#' `given` is a valid front-door set if (1) it intercepts every directed path
#' from `x` to `y`, (2) there is no unblocked backdoor path from `x` to any
#' node in `given`, and (3) for every node in `given`, all backdoor paths to
#' `y` are blocked by `x` together with the rest of `given`. When these hold,
#' the effect is identified via the front-door formula even with unmeasured
#' confounders between `x` and `y`.
#'
#' @param cg A DAG or ADMG created with [cs_cgraph()].
#' @param x,y Exposure and outcome node names.
#' @param given Character vector of conditioning node names (may be empty).
#' @return `TRUE` if the configuration satisfies the frontdoor criterion.
#' @export
#' @examples
#' if (JuliaConnectoR::juliaSetupOk()) {
#'   dag <- cs_cgraph(U %-->% X, X %-->% M, M %-->% Y, U %-->% Y)
#'   cs_is_valid_frontdoor(dag, "X", "Y", "M") # M mediates X -> Y
#'   cs_is_valid_frontdoor(dag, "X", "Y") # empty set leaves X -> M -> Y open
#' }
cs_is_valid_frontdoor <- function(cg, x, y, given = character()) {
  cs_fn("is_valid_frontdoor")(cg, x, y, as.character(given))
}

#' Validate instrumental variables
#'
#' Tests whether a set of variables are valid instruments for identifying
#' the causal effect of exposure `x` on outcome `y`: every node in `z` must
#' be d-/m-separated from `y` given `x` in the graph obtained by deleting
#' `x`'s incoming edges (exclusion restriction), and at least one node in
#' `z` must be d-/m-connected to `x` (relevance).
#'
#' @param cg A DAG or ADMG created with [cs_cgraph()].
#' @param x,y Exposure and outcome node names.
#' @param z Character vector of instrument node names.
#' @return `TRUE` if `z` satisfies the instrumental variable criterion.
#' @export
#' @examples
#' if (JuliaConnectoR::juliaSetupOk()) {
#'   # Classic IV graph: Z --> X --> Y with hidden confounder U --> X, U --> Y
#'   dag <- cs_cgraph(Z %-->% X, X %-->% Y, U %-->% X, U %-->% Y)
#'   cs_is_valid_iv(dag, "X", "Y", "Z") # Z is a valid instrument
#'   cs_is_valid_iv(dag, "X", "Y", "U") # U confounds X and Y
#' }
cs_is_valid_iv <- function(cg, x, y, z = character()) {
  cs_fn("is_valid_iv")(cg, x, y, as.character(z))
}

#' Enumerate all valid instrumental variable sets
#'
#' Finds all minimal (or all) sets of valid instruments for identifying
#' the causal effect of `x` on `y`; see [cs_is_valid_iv()].
#'
#' @param cg A DAG or ADMG created with [cs_cgraph()].
#' @param x,y Exposure and outcome node names.
#' @param minimal If `TRUE` (default), return only minimal sets.
#' @param max_size Maximum number of instruments to consider.
#' @return List of character vectors (empty list if none exist).
#' @export
#' @examples
#' if (JuliaConnectoR::juliaSetupOk()) {
#'   dag <- cs_cgraph(
#'     Z1 %-->% X, Z2 %-->% X, X %-->% Y, U %-->% X, U %-->% Y
#'   )
#'   cs_all_iv_sets(dag, "X", "Y")
#' }
cs_all_iv_sets <- function(cg, x, y, minimal = TRUE, max_size = 3) {
  cs_split_sets(cs_fn("all_iv_sets")(cg, x, y, minimal, max_size))
}

# --- Equivalence classes and counts ------------------------------------------

#' Count and enumerate DAGs in a Markov equivalence class
#'
#' `cg` (a PDAG, CPDAG, or MPDAG) represents a Markov equivalence class
#' (MEC) of DAGs. `cs_enumerate_dags()` lists every DAG in that class;
#' `cs_count_dags()` counts them without materializing them, which is much
#' cheaper and useful for sizing the problem before calling
#' `cs_enumerate_dags()`, since a MEC can be very large.
#'
#' Both apply Meek closure to `cg` first to normalize it, then branch on
#' each undirected edge in lexicographic order, rejecting orientations that
#' would introduce a new v-structure or a directed cycle, and propagating
#' forced orientations via Meek's rules at each step (Chickering's (2002)
#' recursive listing algorithm).
#'
#' @param cg A PDAG, CPDAG, or MPDAG created with [cs_cgraph()].
#' @return For `cs_count_dags()`, an integer count. For `cs_enumerate_dags()`,
#'   a list of DAG proxies.
#' @references
#' \insertRef{chickering2002learning}{testpkg}
#' @name cs-equivalence
#' @examples
#' if (JuliaConnectoR::juliaSetupOk()) {
#'   pdag <- cs_cgraph(A %---% B, B %---% C, class = "PDAG")
#'   cs_count_dags(pdag)
#'   cs_enumerate_dags(pdag)
#' }
NULL

#' @rdname cs-equivalence
#' @export
cs_count_dags <- cs_graph_fn("count_dags")

#' @rdname cs-equivalence
#' @export
cs_enumerate_dags <- function(cg) {
  cs_fn("enumerate_dags")(cg)
}

#' Test whether two graphs are Markov equivalent
#'
#' Returns `TRUE` if `g1` and `g2` (both DAGs, or both MAGs) belong to the
#' same Markov equivalence class, i.e. they impose the same
#' (conditional-)independence constraints.
#'
#' For DAGs, this holds iff they share the same skeleton and the same set of
#' v-structures (unshielded colliders `a --> b <-- c` with `a`, `c`
#' non-adjacent) - the Verma-Pearl characterization. For MAGs, this holds iff
#' they map to the same PAG.
#'
#' @param g1,g2 Graphs to compare, created with [cs_cgraph()]. Both must be
#'   DAGs, or both must be MAGs.
#' @return A logical scalar.
#' @references
#' \insertRef{vermapearl1990equivalence}{testpkg}
#'
#' \insertRef{ali2009markov}{testpkg}
#' @export
#' @examples
#' if (JuliaConnectoR::juliaSetupOk()) {
#'   g1 <- cs_cgraph(A %-->% B, C %-->% B)
#'   g2 <- cs_cgraph(A %-->% B, C %-->% B)
#'   cs_markov_equivalent(g1, g2)
#'
#'   g3 <- cs_cgraph(A %-->% B, B %-->% C)
#'   cs_markov_equivalent(g1, g3)
#' }
cs_markov_equivalent <- function(g1, g2) {
  cs_fn("markov_equivalent")(g1, g2)
}

#' Enumerate MAGs in a PAG equivalence class
#'
#' Enumerates all Markov equivalent MAGs in the equivalence class
#' represented by a PAG (Partial Ancestral Graph): each circle endpoint of
#' the PAG is independently resolved to a tail or an arrowhead, keeping only
#' assignments that validate as a MAG and map back to the same PAG under
#' [cs_mag_to_pag()]. For a single representative instead of the whole
#' class, use [cs_mag_from_pag()].
#'
#' @param cg A PAG (partially ancestral graph) created with [cs_cgraph()].
#' @return A Julia proxy list of MAGs in the equivalence class.
#' @export
#' @examples
#' if (JuliaConnectoR::juliaSetupOk()) {
#'   pag <- cs_cgraph(A %o-o% B, B %o-o% C, class = "PAG")
#'   length(cs_enumerate_mags(pag))
#' }
cs_enumerate_mags <- function(cg) {
  cs_fn("enumerate_mags")(cg)
}
