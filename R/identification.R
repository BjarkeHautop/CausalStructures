# --- Separation --------------------------------------------------------------

#' Test d-separation
#'
#' Two nodes are d-separated given a conditioning set `given` if every path
#' between them is blocked: a path is blocked if it contains either a
#' non-collider node in `given`, or a collider node (and all its descendants)
#' not in `given`.
#'
#' @param cg A DAG or PDAG-family (PDAG, CPDAG, MPDAG) graph created with
#'   [cgraph()].
#' @param x,y Node names.
#' @param given Character vector of conditioning node names (may be empty).
#' @return `TRUE` if `x` and `y` are d-separated given `given`.
#' @export
#' @examples
#' if (julia_ready()) {
#'   chain <- cgraph(A %-->% B, B %-->% C)
#'   list(
#'     open = d_separated(chain, "A", "C"), # chain A --> B --> C is open
#'     blocked = d_separated(chain, "A", "C", "B") # conditioning on B
#'   )
#' }
#'
#' if (julia_ready()) {
#'   collider <- cgraph(A %-->% C, B %-->% C)
#'   list(
#'     blocked = d_separated(collider, "A", "B"), # collider is blocked
#'     opened = d_separated(collider, "A", "B", "C") # conditioning opens it
#'   )
#' }
d_separated <- function(cg, x, y, given = character()) {
  fn("d_separated")(cg, x, y, as.character(given))
}

#' Test m-separation
#'
#' Generalizes d-separation to graphs with bidirected and undirected edges;
#' for a DAG, m-separation is equivalent to [d_separated()].
#'
#' @inheritParams d_separated
#' @param cg A DAG, ADMG, or AG-family (AG, MAG) graph created with
#'   [cgraph()].
#' @return `TRUE` if `x` and `y` are m-separated given `given`.
#' @export
#' @examples
#' if (julia_ready()) {
#'   admg <- cgraph(A %-->% B, A %<->% C, class = "ADMG")
#'   list(
#'     open = m_separated(admg, "B", "C"), # bidirected edge at A connects
#'     blocked = m_separated(admg, "B", "C", "A") # conditioning on A blocks
#'   )
#' }
m_separated <- function(cg, x, y, given = character()) {
  fn("m_separated")(cg, x, y, as.character(given))
}

#' Find a minimal separator
#'
#' Finds a minimal d-separator (DAG, PDAG classes) or m-separator
#' (ADMG, ancestral-graph classes) between `x` and `y`: no proper subset
#' (excluding forced `include` nodes) of the returned set still separates
#' them.
#'
#' @param cg A DAG, ADMG, AG-family (AG, MAG), or PDAG-family (PDAG, CPDAG,
#'   MPDAG) graph created with [cgraph()].
#' @param x,y Node names.
#' @param include Character vector of nodes forced into the separator (must
#'   be a subset of `restrict`, if given).
#' @param restrict Character vector of candidate nodes the separator is
#'   drawn from. `NULL` (default) allows every node except `x` and `y`.
#' @return Character vector with a minimal separating set, or `NULL` if none
#'   exists.
#' @export
#' @examples
#' if (julia_ready()) {
#'   dag <- cgraph(A %-->% X, X %-->% M, M %-->% Y, A %-->% Y)
#'   list(
#'     default = minimal_separator(dag, "X", "Y"), # both A and M needed
#'     forced_include = minimal_separator(dag, "X", "Y", include = "M"),
#'     restricted = minimal_separator(dag, "X", "Y", restrict = "M")
#'   )
#' }
#'
#' if (julia_ready()) {
#'   edge <- cgraph(A %-->% B)
#'   minimal_separator(edge, "A", "B") # direct edge: no separator exists
#' }
minimal_separator <- function(
  cg,
  x,
  y,
  include = character(),
  restrict = NULL
) {
  restrict_arg <- if (is.null(restrict)) NULL else as.character(restrict)
  fn("minimal_separator")(
    cg,
    x,
    y,
    as.character(include),
    restrict_arg
  )
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
#'   \item{`"backdoor"`}{An inclusion-minimal set satisfying Pearl's backdoor
#'     criterion: a minimal separator of `x` and `y` among `x`'s
#'     non-descendants, after removing `x`'s outgoing edges (falls back to
#'     the parents of `x` if no such separator is found).}
#'   \item{`"optimal"`}{The O-set: the parents of causal nodes on a
#'     possibly causal path from `x` to `y`, excluding `x` and those
#'     causal nodes themselves.}
#' }
#'
#' Candidate adjustment sets can be validated with
#' [is_valid_adjustment()].
#'
#' @param cg A DAG, PDAG-family (PDAG, CPDAG, MPDAG), or AG-family (AG, MAG)
#'   graph created with [cgraph()].
#' @param x,y Exposure and outcome node names.
#' @param type Adjustment set type: `"optimal"` (default), `"parents"`, or
#'   `"backdoor"`. Ignored for MAG-family graphs; `"backdoor"` is not
#'   supported for PDAG-family graphs.
#' @return Character vector with a valid adjustment set, or `NULL` if none
#'   exists.
#' @references
#' \insertRef{henckel2022graphical}{CausalStructures} (`"optimal"`)
#'
#' \insertRef{pearl2009causality}{CausalStructures} (`"parents"` and `"backdoor"`)
#' @export
#' @examples
#' if (julia_ready()) {
#'   dag <- cgraph(
#'     C %-->% X, X %-->% F + D, A %-->% X + K, K %-->% Y,
#'     D %-->% Y + G, Y %-->% H
#'   )
#'   list(
#'     parents = sort(adjustment_set(dag, "X", "Y", type = "parents")),
#'     backdoor = adjustment_set(dag, "X", "Y", type = "backdoor"),
#'     optimal = adjustment_set(dag, "X", "Y", type = "optimal") # default
#'   )
#' }
#'
#' if (julia_ready()) {
#'   pdag <- cgraph(A %-->% X, X %-->% Y, A %-->% Y, class = "PDAG")
#'   list(
#'     adjustment_set = adjustment_set(pdag, "X", "Y"), # A
#'     is_valid = is_valid_adjustment(pdag, "X", "Y", "A")
#'   )
#' }
#'
#' if (julia_ready()) {
#'   mag <- cgraph(A %<->% X, A %-->% Y, X %-->% Y, class = "MAG")
#'   adjustment_set(mag, "X", "Y") # A; type is ignored
#' }
adjustment_set <- function(
  cg,
  x,
  y,
  type = c("optimal", "parents", "backdoor")
) {
  type <- match.arg(type)
  fn("adjustment_set")(cg, x, y, type)
}

#' Find a frontdoor adjustment set
#'
#' Returns a set `Z` with `include ⊆ Z ⊆ restrict` satisfying all three
#' front-door conditions (Algorithm 1 of the reference below) for the causal
#' effect of `x` on `y`; validate a candidate set directly with
#' [is_valid_frontdoor()].
#'
#' @param cg A DAG or ADMG created with [cgraph()]. For an ADMG, the backdoor
#'   and condition-3 checks use m-separation, with bidirected edges treated
#'   as latent-confounder edges (a spouse contributes an arrowhead into a
#'   node just like a directed parent does).
#' @param x,y Exposure and outcome node names.
#' @param include Character vector of nodes forced into the set.
#' @param restrict Character vector of candidate nodes the set is drawn
#'   from. `NULL` (default) allows every node except `x` and `y`.
#' @return Character vector with a valid frontdoor set, or `NULL` if none
#'   exists.
#' @references
#' \insertRef{jeong2022finding}{CausalStructures}
#' @export
#' @examples
#' if (julia_ready()) {
#'   dag <- cgraph(U %-->% X, U %-->% Y, X %-->% Z, Z %-->% Y)
#'   list(
#'     default = frontdoor_set(dag, "X", "Y"), # Z mediates X -> Y
#'     restricted = frontdoor_set(dag, "X", "Y", restrict = "Z")
#'   )
#' }
frontdoor_set <- function(
  cg,
  x,
  y,
  include = character(),
  restrict = NULL
) {
  restrict_arg <- if (is.null(restrict)) NULL else as.character(restrict)
  fn("frontdoor_set")(
    cg,
    x,
    y,
    as.character(include),
    restrict_arg
  )
}

#' Validate a backdoor adjustment set
#'
#' `given` is a valid backdoor set if (1) no node in `given` is a descendant
#' of `x`, and (2) `given` blocks every backdoor path from `x` to `y` (every
#' parent of `x` is d-separated from `y` given `given` together with `x`).
#'
#' @param cg A DAG or ADMG created with [cgraph()].
#' @param x,y Exposure and outcome node names.
#' @param given Character vector of adjustment node names (may be empty).
#' @return `TRUE` if `given` satisfies the backdoor criterion.
#' @export
#' @examples
#' if (julia_ready()) {
#'   dag <- cgraph(A %-->% X, X %-->% Y, A %-->% Y)
#'   list(
#'     empty = is_valid_backdoor(dag, "X", "Y"), # A --> Y left open
#'     conditioned_on_a = is_valid_backdoor(dag, "X", "Y", "A")
#'   )
#' }
is_valid_backdoor <- function(cg, x, y, given = character()) {
  fn("is_valid_backdoor")(cg, x, y, as.character(given))
}

#' Enumerate backdoor adjustment sets
#'
#' Lists all sets (up to size `max_size`) satisfying the backdoor criterion;
#' see [is_valid_backdoor()]. When `minimal = TRUE` (default), only
#' inclusion-minimal sets are returned.
#'
#' @param cg A DAG or ADMG created with [cgraph()].
#' @param x,y Exposure and outcome node names.
#' @param minimal If `TRUE` (default), return only minimal sets.
#' @param max_size Maximum adjustment set size to consider.
#' @return List of character vectors (empty list if none exist).
#' @export
#' @examples
#' if (julia_ready()) {
#'   dag <- cgraph(A %-->% X, X %-->% Y, A %-->% Y)
#'   all_backdoor_sets(dag, "X", "Y")
#' }
all_backdoor_sets <- function(cg, x, y, minimal = TRUE, max_size = 3) {
  split_sets(fn("all_backdoor_sets")(cg, x, y, minimal, max_size))
}

#' Enumerate frontdoor adjustment sets
#'
#' Lists all sets `Z` with `include ⊆ Z ⊆ restrict` satisfying the
#' front-door criterion; see [frontdoor_set()] and
#' [is_valid_frontdoor()].
#'
#' @param cg A DAG or ADMG created with [cgraph()]. For an ADMG, see the note
#'   on m-separation in [frontdoor_set()].
#' @param x,y Exposure and outcome node names.
#' @param include Character vector of nodes forced into every set.
#' @param restrict Character vector of candidate nodes sets are drawn from.
#'   `NULL` (default) allows every node except `x` and `y`.
#' @return List of character vectors (empty list if none exist).
#' @export
#' @examples
#' if (julia_ready()) {
#'   dag <- cgraph(U %-->% X, U %-->% Y, X %-->% Z, Z %-->% Y)
#'   all_frontdoor_sets(dag, "X", "Y", restrict = "Z")
#' }
all_frontdoor_sets <- function(
  cg,
  x,
  y,
  include = character(),
  restrict = NULL
) {
  restrict_arg <- if (is.null(restrict)) NULL else as.character(restrict)
  split_sets(
    fn("all_frontdoor_sets")(
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
#'   MAG) graph created with [cgraph()].
#' @param x,y Exposure and outcome node names.
#' @param given Character vector of adjustment node names (may be empty).
#' @return `TRUE` if `given` satisfies the adjustment criterion for
#'   identifying the causal effect of `x` on `y`.
#' @references
#' \insertRef{perkovic2018complete}{CausalStructures}
#' @export
#' @examples
#' if (julia_ready()) {
#'   admg <- cgraph(L %-->% X, X %-->% Y, L %-->% Y, class = "ADMG")
#'   list(
#'     empty = is_valid_adjustment(admg, "X", "Y"), # L --> Y not blocked
#'     conditioned_on_l = is_valid_adjustment(admg, "X", "Y", "L")
#'   )
#' }
is_valid_adjustment <- function(cg, x, y, given = character()) {
  fn("is_valid_adjustment")(cg, x, y, as.character(given))
}

#' Enumerate all valid adjustment sets
#'
#' Lists all sets (up to size `max_size`) satisfying the Generalized
#' Adjustment Criterion; see [is_valid_adjustment()]. When
#' `minimal = TRUE` (default), only inclusion-minimal sets are returned.
#'
#' @param cg An ADMG, PDAG-family (PDAG, CPDAG, MPDAG), or AG-family (AG,
#'   MAG) graph created with [cgraph()].
#' @param x,y Exposure and outcome node names.
#' @param minimal If `TRUE` (default), return only minimal sets.
#' @param max_size Maximum adjustment set size to consider.
#' @return List of character vectors (empty list if none exist).
#' @export
#' @examples
#' if (julia_ready()) {
#'   admg <- cgraph(L %-->% X, X %-->% Y, L %-->% Y, class = "ADMG")
#'   all_adjustment_sets(admg, "X", "Y")
#' }
all_adjustment_sets <- function(cg, x, y, minimal = TRUE, max_size = 3) {
  split_sets(fn("all_adjustment_sets")(cg, x, y, minimal, max_size))
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
#' @param cg A DAG or ADMG created with [cgraph()].
#' @param x,y Exposure and outcome node names.
#' @param given Character vector of conditioning node names (may be empty).
#' @return `TRUE` if the configuration satisfies the frontdoor criterion.
#' @export
#' @examples
#' if (julia_ready()) {
#'   dag <- cgraph(U %-->% X, X %-->% M, M %-->% Y, U %-->% Y)
#'   list(
#'     m_mediates = is_valid_frontdoor(dag, "X", "Y", "M"),
#'     empty = is_valid_frontdoor(dag, "X", "Y") # X -> M -> Y left open
#'   )
#' }
is_valid_frontdoor <- function(cg, x, y, given = character()) {
  fn("is_valid_frontdoor")(cg, x, y, as.character(given))
}

#' Validate instrumental variables
#'
#' Tests whether a set of variables are valid instruments for identifying
#' the causal effect of exposure `x` on outcome `y`: every node in `z` must
#' be d-/m-separated from `y` given `x` in the graph obtained by deleting
#' `x`'s incoming edges (exclusion restriction), and at least one node in
#' `z` must be d-/m-connected to `x` (relevance).
#'
#' @param cg A DAG or ADMG created with [cgraph()].
#' @param x,y Exposure and outcome node names.
#' @param z Character vector of instrument node names.
#' @return `TRUE` if `z` satisfies the instrumental variable criterion.
#' @export
#' @examples
#' if (julia_ready()) {
#'   # Classic IV graph: Z --> X --> Y with hidden confounder U --> X, U --> Y
#'   dag <- cgraph(Z %-->% X, X %-->% Y, U %-->% X, U %-->% Y)
#'   list(
#'     z = is_valid_iv(dag, "X", "Y", "Z"), # Z is a valid instrument
#'     u = is_valid_iv(dag, "X", "Y", "U") # U confounds X and Y
#'   )
#' }
is_valid_iv <- function(cg, x, y, z = character()) {
  fn("is_valid_iv")(cg, x, y, as.character(z))
}

#' Enumerate all valid instrumental variable sets
#'
#' Finds all minimal (or all) sets of valid instruments for identifying
#' the causal effect of `x` on `y`; see [is_valid_iv()].
#'
#' @param cg A DAG or ADMG created with [cgraph()].
#' @param x,y Exposure and outcome node names.
#' @param minimal If `TRUE` (default), return only minimal sets.
#' @param max_size Maximum number of instruments to consider.
#' @return List of character vectors (empty list if none exist).
#' @export
#' @examples
#' if (julia_ready()) {
#'   dag <- cgraph(
#'     Z1 %-->% X, Z2 %-->% X, X %-->% Y, U %-->% X, U %-->% Y
#'   )
#'   all_iv_sets(dag, "X", "Y")
#' }
all_iv_sets <- function(cg, x, y, minimal = TRUE, max_size = 3) {
  split_sets(fn("all_iv_sets")(cg, x, y, minimal, max_size))
}

# --- Equivalence classes and counts ------------------------------------------

#' Count and enumerate DAGs in a Markov equivalence class
#'
#' `cg` (a PDAG, CPDAG, or MPDAG) represents a Markov equivalence class
#' (MEC) of DAGs. `enumerate_dags()` lists every DAG in that class;
#' `count_dags()` counts them without materializing them, which is much
#' cheaper and useful for sizing the problem before calling
#' `enumerate_dags()`, since a MEC can be very large.
#'
#' Both apply Meek closure to `cg` first to normalize it, then branch on
#' each undirected edge in lexicographic order, rejecting orientations that
#' would introduce a new v-structure or a directed cycle, and propagating
#' forced orientations via Meek's rules at each step (Chickering's (2002)
#' recursive listing algorithm).
#'
#' @param cg A PDAG, CPDAG, or MPDAG created with [cgraph()].
#' @return For `count_dags()`, an integer count. For `enumerate_dags()`,
#'   a list of DAG proxies.
#' @references
#' \insertRef{chickering2002learning}{CausalStructures}
#' @name equivalence
#' @examples
#' if (julia_ready()) {
#'   pdag <- cgraph(A %---% B, B %---% C, class = "PDAG")
#'   count_dags(pdag)
#' }
#'
#' if (julia_ready()) {
#'   pdag <- cgraph(A %---% B, B %---% C, class = "PDAG")
#'   enumerate_dags(pdag)
#' }
NULL

#' @rdname equivalence
#' @export
count_dags <- graph_fn("count_dags")

#' @rdname equivalence
#' @export
enumerate_dags <- function(cg) {
  fn("enumerate_dags")(cg)
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
#' @param g1,g2 Graphs to compare, created with [cgraph()]. Both must be
#'   DAGs, or both must be MAGs.
#' @return A logical scalar.
#' @references
#' \insertRef{vermapearl1990equivalence}{CausalStructures}
#'
#' \insertRef{ali2009markov}{CausalStructures}
#' @export
#' @examples
#' if (julia_ready()) {
#'   g1 <- cgraph(A %-->% B, C %-->% B)
#'   g2 <- cgraph(A %-->% B, C %-->% B)
#'   g3 <- cgraph(A %-->% B, B %-->% C)
#'   list(
#'     same_skeleton_same_v_structures = markov_equivalent(g1, g2),
#'     different_v_structures = markov_equivalent(g1, g3)
#'   )
#' }
markov_equivalent <- function(g1, g2) {
  fn("markov_equivalent")(g1, g2)
}

#' Enumerate MAGs in a PAG equivalence class
#'
#' Enumerates all Markov equivalent MAGs in the equivalence class
#' represented by a PAG (Partial Ancestral Graph): each circle endpoint of
#' the PAG is independently resolved to a tail or an arrowhead, keeping only
#' assignments that validate as a MAG and map back to the same PAG under
#' [mag_to_pag()]. For a single representative instead of the whole
#' class, use [mag_from_pag()].
#'
#' @param cg A PAG (partially ancestral graph) created with [cgraph()].
#' @return A Julia proxy list of MAGs in the equivalence class.
#' @export
#' @examples
#' if (julia_ready()) {
#'   pag <- cgraph(A %o-o% B, B %o-o% C, class = "PAG")
#'   length(enumerate_mags(pag))
#' }
enumerate_mags <- function(cg) {
  fn("enumerate_mags")(cg)
}
