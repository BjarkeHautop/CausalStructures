# --- Separation --------------------------------------------------------------

#' Test d-separation
#'
#' Two nodes are d-separated given a conditioning set `given` if every path
#' between them is blocked. A path is blocked if it contains either a
#' non-collider node in `given`, or a collider node (and all its descendants)
#' not in `given`.
#'
#' @param cg A DAG or PDAG-family (PDAG, CPDAG, MPDAG) graph created with
#'   [cgraph()].
#' @param x,y Node name, or character vector of node names (to test whether
#'   the two *sets* are separated).
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
  .Call(
    C_jl_d_separated,
    cg,
    as.character(x),
    as.character(y),
    as.character(given)
  )
}

#' Test m-separation
#'
#' Generalizes d-separation to graphs with bidirected and undirected edges;
#' for a DAG, m-separation is equivalent to [d_separated()]. For a PAG,
#' circle marks collapse to tails, as for
#' [possible_ancestors()][possible-queries].
#'
#' @inheritParams d_separated
#' @param cg A DAG, ADMG, AG-family (AG, MAG), or PAG graph created with
#'   [cgraph()].
#' @param x,y Node name, or character vector of node names (to test whether
#'   the two *sets* are separated).
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
#'
#' if (julia_ready()) {
#'   pag <- cgraph(A %o->% B, C %o->% B, class = "PAG")
#'   m_separated(pag, "A", "C")
#' }
m_separated <- function(cg, x, y, given = character()) {
  .Call(
    C_jl_m_separated,
    cg,
    as.character(x),
    as.character(y),
    as.character(given)
  )
}

#' Find a minimal separator
#'
#' Finds a minimal d-separator (DAG, PDAG classes) or m-separator
#' (ADMG, ancestral-graph classes, PAG) between `x` and `y`. No proper subset
#' (excluding forced `include` nodes) of the returned set still separates
#' them.
#'
#' @param cg A DAG, ADMG, AG-family (AG, MAG), PDAG-family (PDAG, CPDAG,
#'   MPDAG), or PAG graph created with [cgraph()].
#' @param x,y Node name, or character vector of node names (to separate the
#'   two *sets*).
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
  .Call(
    C_jl_minimal_separator,
    cg,
    as.character(x),
    as.character(y),
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
#'   \item{ADMG, MAG-family (AG, MAG), PAG}{`type` is ignored. The smallest
#'     valid adjustment set is returned by searching sets of increasing
#'     size.}
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
#' @param cg A DAG, ADMG, PDAG-family (PDAG, CPDAG, MPDAG), AG-family (AG,
#'   MAG), or PAG graph created with [cgraph()].
#' @param x,y Exposure and outcome node name, or character vector of node
#'   names (to identify the effect of a set of exposures on a set of
#'   outcomes).
#' @param type Adjustment set type: `"optimal"` (default), `"parents"`, or
#'   `"backdoor"`. Ignored for ADMG, MAG-family, and PAG graphs; `"backdoor"`
#'   is not supported for PDAG-family graphs.
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
  type <- if (missing(type)) type[[1L]] else match.arg(type)
  .Call(C_jl_adjustment_set, cg, as.character(x), as.character(y), type)
}

#' Find a frontdoor adjustment set
#'
#' Returns a set `Z` with `include ⊆ Z ⊆ restrict` satisfying all three
#' front-door conditions (Algorithm 1 of the reference below) for the causal
#' effect of `x` on `y`. Validate a candidate set directly with
#' [is_valid_frontdoor()].
#'
#' @param cg A DAG or ADMG created with [cgraph()]. For an ADMG, the backdoor
#'   and condition-3 checks use m-separation, with bidirected edges treated
#'   as latent-confounder edges (a spouse contributes an arrowhead into a
#'   node just like a directed parent does).
#' @param x,y Exposure and outcome node name, or character vector of node
#'   names.
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
  .Call(
    C_jl_frontdoor_set,
    cg,
    as.character(x),
    as.character(y),
    as.character(include),
    restrict_arg
  )
}

#' Validate a backdoor adjustment set
#'
#' Tests whether `given` is a valid backdoor set for the effect of `x` on
#' `y`. It is if (1) no node in `given` is a descendant of `x`, and (2)
#' `given` blocks every backdoor path from `x` to `y` (every parent of `x` is
#' d-separated from `y` given `given` together with `x`).
#'
#' @param cg A DAG or ADMG created with [cgraph()].
#' @param x,y Exposure and outcome node name, or character vector of node
#'   names.
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
  .Call(
    C_jl_is_valid_backdoor,
    cg,
    as.character(x),
    as.character(y),
    as.character(given)
  )
}

#' Enumerate backdoor adjustment sets
#'
#' Lists all sets (up to size `max_size`) satisfying the backdoor criterion;
#' see [is_valid_backdoor()]. When `minimal = TRUE` (default), only
#' inclusion-minimal sets are returned.
#'
#' @param cg A DAG or ADMG created with [cgraph()].
#' @param x,y Exposure and outcome node name, or character vector of node
#'   names.
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
  .Call(
    C_jl_all_backdoor_sets,
    cg,
    as.character(x),
    as.character(y),
    minimal,
    max_size
  )
}

#' Enumerate frontdoor adjustment sets
#'
#' Lists all sets `Z` with `include ⊆ Z ⊆ restrict` satisfying the
#' front-door criterion; see [frontdoor_set()] and
#' [is_valid_frontdoor()].
#'
#' @param cg A DAG or ADMG created with [cgraph()]. For an ADMG, see the note
#'   on m-separation in [frontdoor_set()].
#' @param x,y Exposure and outcome node name, or character vector of node
#'   names.
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
  .Call(
    C_jl_all_frontdoor_sets,
    cg,
    as.character(x),
    as.character(y),
    as.character(include),
    restrict_arg
  )
}

#' Validate an adjustment set
#'
#' Tests the Generalized Adjustment Criterion, which covers DAGs, ADMGs,
#' PDAG-family graphs, MAG-family graphs, and PAGs alike. `given` must
#' contain no forbidden node (a descendant of a proper causal node between
#' `x` and `y`, or `x` itself), and must m-separate `x` from `y` in the
#' proper backdoor graph.
#'
#' @param cg A DAG, ADMG, PDAG-family (PDAG, CPDAG, MPDAG), AG-family (AG,
#'   MAG), or PAG graph created with [cgraph()].
#' @param x,y Exposure and outcome node name, or character vector of node
#'   names.
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
  .Call(
    C_jl_is_valid_adjustment,
    cg,
    as.character(x),
    as.character(y),
    as.character(given)
  )
}

#' Enumerate all valid adjustment sets
#'
#' Lists all sets (up to size `max_size`) satisfying the Generalized
#' Adjustment Criterion; see [is_valid_adjustment()]. When
#' `minimal = TRUE` (default), only inclusion-minimal sets are returned.
#'
#' @param cg A DAG, ADMG, PDAG-family (PDAG, CPDAG, MPDAG), AG-family (AG,
#'   MAG), or PAG graph created with [cgraph()].
#' @param x,y Exposure and outcome node name, or character vector of node
#'   names.
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
  .Call(
    C_jl_all_adjustment_sets,
    cg,
    as.character(x),
    as.character(y),
    minimal,
    max_size
  )
}

#' Validate a frontdoor criterion set
#'
#' Tests whether `given` is a valid front-door set for the effect of `x` on
#' `y`. It is if (1) it intercepts every directed path
#' from `x` to `y`, (2) there is no unblocked backdoor path from `x` to any
#' node in `given`, and (3) for every node in `given`, all backdoor paths to
#' `y` are blocked by `x` together with the rest of `given`. When these hold,
#' the effect is identified via the front-door formula even with unmeasured
#' confounders between `x` and `y`.
#'
#' @param cg A DAG or ADMG created with [cgraph()].
#' @param x,y Exposure and outcome node name, or character vector of node
#'   names.
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
  .Call(
    C_jl_is_valid_frontdoor,
    cg,
    as.character(x),
    as.character(y),
    as.character(given)
  )
}

#' Validate instrumental variables
#'
#' Tests whether a set of variables are valid instruments for identifying
#' the causal effect of exposure `x` on outcome `y`. Every node in `z` must
#' be d-/m-separated from `y` given `x` in the graph obtained by deleting
#' `x`'s incoming edges (exclusion restriction), and at least one node in
#' `z` must be d-/m-connected to `x` (relevance).
#'
#' @param cg A DAG or ADMG created with [cgraph()].
#' @param x Exposure node name.
#' @param y Outcome node name, or character vector of node names.
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
  .Call(C_jl_is_valid_iv, cg, x, as.character(y), as.character(z))
}

#' Enumerate all valid instrumental variable sets
#'
#' Finds all minimal (or all) sets of valid instruments for identifying
#' the causal effect of `x` on `y`; see [is_valid_iv()].
#'
#' @param cg A DAG or ADMG created with [cgraph()].
#' @param x Exposure node name.
#' @param y Outcome node name, or character vector of node names.
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
  .Call(C_jl_all_iv_sets, cg, x, as.character(y), minimal, max_size)
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
count_dags <- function(cg) .Call(C_jl_count_dags, cg)

#' @rdname equivalence
#' @export
enumerate_dags <- function(cg) {
  .Call(C_jl_enumerate_dags, cg)
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
  .Call(C_jl_markov_equivalent, g1, g2)
}

#' Enumerate MAGs in a PAG equivalence class
#'
#' Enumerates all Markov equivalent MAGs in the equivalence class
#' represented by a PAG (Partial Ancestral Graph). Each circle endpoint of
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
  .Call(C_jl_enumerate_mags, cg)
}

# --- Symbolic identification (ID/IDC) ----------------------------------------

#' Identify an interventional distribution
#'
#' `id()` returns the interventional distribution `P(y | do(x))` as a
#' formula in terms of the observational distribution, or `NULL` if the
#' effect is not identifiable. It implements Shpitser & Pearl's ID algorithm. `idc()`
#' additionally conditions on `given` (the IDC algorithm), reducing to `id()`
#' when `given` is empty.
#'
#' Bidirected edges represent latent confounders. To identify an effect in a
#' DAG with unobserved variables, project them out first with
#' [latent_project()].
#'
#' The rendered formula may mention variables outside `x`/`y`/`given`: the
#' algorithm can enlarge the intervention set whenever doing so provably
#' changes nothing, and the result is then a function of those extra values
#' too. This binding renders the resulting `Estimand` as a formatted
#' character string; it does not expose the underlying symbolic-algebra
#' representation (`Prob`, `Marginal`, `Product`, `Quotient` in
#' CausalStructures.jl) for programmatic manipulation.
#'
#' @param cg A DAG or ADMG created with [cgraph()].
#' @param x,y Intervention (exposure) and outcome node name, or character
#'   vector of node names. Must be disjoint from each other (and from
#'   `given`, for `idc()`).
#' @param given Character vector of node names to additionally condition on
#'   (`idc()` only).
#' @return A character scalar with the rendered formula, or `NULL` if the
#'   effect is not identifiable.
#' @references
#' \insertRef{shpitser2008complete}{CausalStructures}
#'
#' \insertRef{tian2002general}{CausalStructures}
#' @name id
#' @examples
#' if (julia_ready()) {
#'   # Back-door adjustment, recovered as the g-formula
#'   dag <- cgraph(Z %-->% X, X %-->% Y, Z %-->% Y)
#'   id(dag, "X", "Y")
#' }
#'
#' if (julia_ready()) {
#'   # Front-door graph: X and Y are confounded, but the effect is still
#'   # identifiable through the mediator M
#'   admg <- cgraph(X %-->% M, M %-->% Y, X %<->% Y, class = "ADMG")
#'   id(admg, "X", "Y")
#' }
#'
#' if (julia_ready()) {
#'   # The bow arc: the canonical unidentifiable effect
#'   bow <- cgraph(X %-->% Y, X %<->% Y, class = "ADMG")
#'   is.null(id(bow, "X", "Y"))
#' }
#'
#' if (julia_ready()) {
#'   dag <- cgraph(Z %-->% X, X %-->% Y, Z %-->% Y)
#'   idc(dag, "X", "Y", given = "Z")
#' }
NULL

#' @rdname id
#' @export
id <- function(cg, x, y) {
  .Call(C_jl_id, cg, as.character(x), as.character(y))
}

#' @rdname id
#' @export
idc <- function(cg, x, y, given = character()) {
  .Call(
    C_jl_idc,
    cg,
    as.character(x),
    as.character(y),
    as.character(given)
  )
}

# --- Generalized backdoor criterion and local IDA ----------------------------

#' Find a generalized backdoor set
#'
#' Returns a generalized back-door set relative to `(x, y)` in `cg` using the
#' Generalized Backdoor Criterion (GBC), or `NULL` if none exists.
#'
#' @param cg A DAG, CPDAG, MAG, or PAG graph created with [cgraph()].
#' @param x,y Exposure and outcome node names.
#' @return Character vector with a generalized back-door set, or `NULL` if
#'   none exists.
#' @references
#' \insertRef{maathuiscolombo2015gbc}{CausalStructures}
#' @export
#' @examples
#' if (julia_ready()) {
#'   # A --> X <-- C protects both edges into X
#'   cpdag <- cgraph(A %-->% X, C %-->% X, X %-->% Y, class = "CPDAG")
#'   sort(backdoor_set(cpdag, "X", "Y"))
#' }
backdoor_set <- function(cg, x, y) {
  .Call(C_jl_backdoor_set, cg, x, y)
}

#' Find every possible D-SEP set
#'
#' Returns D-SEP(x, y, cg). It contains every vertex other than `x` for which
#' there is a collider path between `x` and the vertex in `cg` on which every
#' vertex, including the vertex itself, is an ancestor of `x` or of some
#' member of `y`. This is the plain graph-level primitive that [backdoor_set()] (for
#' MAG/PAG) uses internally to build its generalized back-door set.
#'
#' @param cg An AG-family (AG, MAG) or PAG graph created with [cgraph()].
#' @param x Node name.
#' @param y Node name, or character vector of node names.
#' @return Sorted character vector of node names.
#' @references
#' \insertRef{maathuiscolombo2015gbc}{CausalStructures}
#' @export
#' @examples
#' if (julia_ready()) {
#'   mag <- cgraph(A %<->% X, A %-->% M, M %-->% Y, X %-->% Y, class = "MAG")
#'   list(
#'     possible_d_sep = possible_d_sep(mag, "X", "Y"),
#'     backdoor_set = backdoor_set(mag, "X", "Y") # M_X drops X --> Y
#'   )
#' }
possible_d_sep <- function(cg, x, y) {
  .Call(C_jl_possible_d_sep, cg, x, as.character(y))
}

#' Enumerate possible parent sets (local IDA)
#'
#' Returns every possible parental set of `x` implied by `cg`: the
#' graph-only half of the local IDA algorithm. One entry is returned per
#' locally valid orientation of `x`'s undirected neighbors (not per DAG in
#' the Markov equivalence class of `cg` - the two collections agree when
#' read as sets, but their multiplicities differ in general).
#'
#' @param cg A PDAG-family (PDAG, CPDAG, MPDAG) graph created with
#'   [cgraph()].
#' @param x Node name.
#' @return List of character vectors, one per locally valid orientation.
#' @references
#' \insertRef{maathuis2009estimating}{CausalStructures}
#' @export
#' @examples
#' if (julia_ready()) {
#'   cpdag <- cgraph(
#'     X1 %---% X2, X1 %---% X3, X1 %---% X4, X3 %-->% Y, X4 %-->% Y,
#'     class = "CPDAG"
#'   )
#'   possible_parent_sets(cpdag, "X1")
#' }
possible_parent_sets <- function(cg, x) {
  .Call(C_jl_possible_parent_sets, cg, x)
}

#' Enumerate possible joint parent sets (joint-IDA)
#'
#' Generalizes [possible_parent_sets()] from a single intervention node to a
#' set `xs` of simultaneous interventions. Every undirected edge incident to
#' at least one node of `xs` is jointly reoriented, keeping only orientations
#' that introduce no new v-structure and remain acyclic. Each returned entry
#' is a list of parent sets in the same order as `xs` (entry `i` gives a
#' valid parent set for `xs[i]` under that joint orientation).
#'
#' @param cg A PDAG-family (PDAG, CPDAG, MPDAG) graph created with
#'   [cgraph()].
#' @param xs Character vector of node names (the simultaneous interventions;
#'   must be non-empty with no duplicates).
#' @return List of lists of character vectors: one list per valid joint
#'   orientation, each containing one parent set per node of `xs`.
#' @references
#' \insertRef{maathuis2009estimating}{CausalStructures}
#'
#' \insertRef{nandy2017jointida}{CausalStructures}
#' @export
#' @examples
#' if (julia_ready()) {
#'   cpdag <- cgraph(
#'     X1 %---% X2, X1 %---% A, X2 %---% B, A %-->% Y, B %-->% Y,
#'     class = "CPDAG"
#'   )
#'   possible_joint_parent_sets(cpdag, c("X1", "X2"))
#' }
possible_joint_parent_sets <- function(cg, xs) {
  .Call(C_jl_possible_joint_parent_sets, cg, as.character(xs))
}

#' Enumerate possible optimal adjustment sets (O-set-based IDA)
#'
#' Returns the optimal adjustment set for each locally valid orientation of
#' `x`'s undirected neighbors in `cg`: the graph part of optimal-adjustment
#' IDA. Entries are in the same order (one per locally valid orientation) as
#' [possible_parent_sets()]`(cg, x)`, so pairing the two element-wise
#' recovers, for each orientation, both its parent set and its optimal
#' adjustment set. An entry is `NULL` when `y` is among the resulting parents
#' of `x` for that orientation.
#'
#' @param cg A PDAG-family (PDAG, CPDAG, MPDAG) graph created with
#'   [cgraph()].
#' @param x,y Exposure and outcome node names.
#' @return List of character vectors, or `NULL` entries, one per locally
#'   valid orientation of `x`'s undirected neighbors.
#' @references
#' \insertRef{maathuis2009estimating}{CausalStructures}
#'
#' \insertRef{henckel2022graphical}{CausalStructures}
#'
#' \insertRef{witte2020efficient}{CausalStructures}
#' @export
#' @examples
#' if (julia_ready()) {
#'   cpdag <- cgraph(
#'     X1 %---% X2, X1 %---% X3, X1 %---% X4, X3 %-->% Y, X4 %-->% Y,
#'     class = "CPDAG"
#'   )
#'   list(
#'     parent_sets = possible_parent_sets(cpdag, "X1"),
#'     optimal_adjustment_sets = possible_optimal_adjustment_sets(
#'       cpdag, "X1", "Y"
#'     )
#'   )
#' }
possible_optimal_adjustment_sets <- function(cg, x, y) {
  .Call(C_jl_possible_optimal_adjustment_sets, cg, x, y)
}

# --- PAGcauses and local MAG structures ---------------------------------------

#' Enumerate valid local structures at a node of a PAG
#'
#' Returns every valid local structure at `x` in the PAG `cg`. Each entry is
#' a subset of `x`'s circle-marked neighbors for which a MAG consistent with
#' `cg` exists with a bidirected edge to every node in the subset and a
#' directed edge away from `x` to every other circle-marked neighbor. Pair an
#' entry with [maximal_local_mag()] to get the corresponding graph; this is
#' the graph-only ingredient [pagcauses()] enumerates local structures with.
#'
#' Assumes `cg` has no selection bias (no undirected edges).
#'
#' @param cg A PAG created with [cgraph()].
#' @param x Node name.
#' @return List of character vectors, one per valid local structure.
#' @references
#' \insertRef{wang2023localbk}{CausalStructures}
#'
#' \insertRef{wang2025pagcauses}{CausalStructures}
#' @export
#' @examples
#' if (julia_ready()) {
#'   pag <- cgraph(
#'     X %o->% Y, X %o->% C, X %o->% A, Y %o-o% C, C %o-o% A,
#'     B %o->% C, B %o->% Y, B %o->% A,
#'     class = "PAG"
#'   )
#'   possible_local_structures(pag, "X")
#' }
possible_local_structures <- function(cg, x) {
  .Call(C_jl_possible_local_structures, cg, x)
}

#' Build the maximal local MAG for a local structure
#'
#' Returns the maximal local MAG for the local structure `c` at `x` in the
#' PAG `cg`. This is `cg` with a bidirected edge from `x` to every node in `c` and a
#' directed edge from `x` to every other circle-marked neighbor, treated as
#' local background knowledge and closed under the corresponding rule set.
#' `c` should be a valid local structure, i.e. an entry of
#' [possible_local_structures()]`(cg, x)`; passing an invalid one gives an
#' unsound result. The returned graph may still contain circles, which is why
#' it is returned as class `"UNKNOWN"` rather than validated as a MAG or PAG.
#'
#' Assumes `cg` has no selection bias (no undirected edges).
#'
#' @param cg A PAG created with [cgraph()].
#' @param x Node name.
#' @param c Character vector of node names: a valid local structure at `x`.
#' @return A Julia proxy object representing the resulting `"UNKNOWN"` graph.
#' @references
#' \insertRef{wang2023localbk}{CausalStructures}
#'
#' \insertRef{wang2025pagcauses}{CausalStructures}
#' @export
#' @examples
#' if (julia_ready()) {
#'   mag <- cgraph(
#'     A %<->% X, B %-->% X, A %<->% B, X %-->% Y,
#'     class = "MAG"
#'   )
#'   pag <- mag_to_pag(mag)
#'   maximal_local_mag(pag, "X", "A")
#' }
maximal_local_mag <- function(cg, x, c) {
  .Call(C_jl_maximal_local_mag, cg, x, as.character(c))
}

#' Find every possible causal effect in a PAG (PAGcauses)
#'
#' Returns every valid adjustment set relative to `(x, y)` in some MAG
#' consistent with the PAG `cg`, i.e. the possible causal effects of `x` on
#' `y` identifiable via covariate adjustment. It does so without enumerating
#' MAGs (PAGcauses, Algorithm 1). If `x` is not a possible ancestor of `y`,
#' returns an empty list (no causal effect). If the causal effect is already
#' identifiable directly in `cg` ([backdoor_set()]), returns that single set.
#' Otherwise, this searches every valid local structure at `x`
#' ([possible_local_structures()]) and its maximal local MAG
#' ([maximal_local_mag()]) for potential adjustment sets.
#'
#' Assumes `cg` has no selection bias (no undirected edges).
#'
#' @param cg A PAG created with [cgraph()].
#' @param x,y Exposure and outcome node names.
#' @return List of character vectors (empty list if `x` has no possible
#'   causal effect on `y`).
#' @references
#' \insertRef{wang2025pagcauses}{CausalStructures}
#' @export
#' @examples
#' if (julia_ready()) {
#'   pag <- cgraph(
#'     X %o->% Y, X %o->% C, X %o->% A, Y %o-o% C, C %o-o% A,
#'     B %o->% C, B %o->% Y, B %o->% A,
#'     class = "PAG"
#'   )
#'   pagcauses(pag, "X", "Y")
#' }
pagcauses <- function(cg, x, y) {
  .Call(C_jl_pagcauses, cg, x, y)
}
