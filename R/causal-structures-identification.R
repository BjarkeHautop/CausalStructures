# --- Separation --------------------------------------------------------------

#' Test d-separation
#'
#' Two nodes are d-separated given a conditioning set `given` if every path
#' between them is blocked: a path is blocked if it contains either a
#' non-collider node in `given`, or a collider node (and all its descendants)
#' not in `given`.
#'
#' @param graph A graph created with [cs_cgraph()].
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
cs_d_separated <- function(graph, x, y, given = character()) {
  cs_fn("d_separated")(graph, x, y, as.character(given))
}

#' Test m-separation
#'
#' Generalizes d-separation to graphs with bidirected and undirected edges;
#' for a DAG, m-separation is equivalent to [cs_d_separated()].
#'
#' @inheritParams cs_d_separated
#' @return `TRUE` if `x` and `y` are m-separated given `given`.
#' @export
#' @examples
#' if (JuliaConnectoR::juliaSetupOk()) {
#'   admg <- cs_cgraph(A %-->% B, A %<->% C, class = "ADMG")
#'   cs_m_separated(admg, "B", "C") # connected via the bidirected edge at A
#'   cs_m_separated(admg, "B", "C", "A") # conditioning on A blocks the path
#' }
cs_m_separated <- function(graph, x, y, given = character()) {
  cs_fn("m_separated")(graph, x, y, as.character(given))
}

#' Find a minimal separator
#'
#' Finds a minimal d-separator (DAG, PDAG classes) or m-separator
#' (ADMG, ancestral-graph classes) between `x` and `y`: no proper subset
#' (excluding forced `include` nodes) of the returned set still separates
#' them.
#'
#' @param graph A graph created with [cs_cgraph()].
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
  graph,
  x,
  y,
  include = character(),
  restrict = NULL
) {
  restrict_arg <- if (is.null(restrict)) NULL else as.character(restrict)
  res <- cs_fn("minimal_separator")(
    graph,
    x,
    y,
    as.character(include),
    restrict_arg
  )
  if (is.null(res)) NULL else cs_split(res)
}

# --- Causal identification ---------------------------------------------------

#' Find a backdoor adjustment set
#'
#' Computes an adjustment set for the total causal effect of `x` on `y` on a
#' DAG or PDAG-family graph (`type` is ignored for MAGs,
#' which always return the smallest valid set). Three types are supported:
#' \describe{
#'   \item{`"parents"`}{The parents of `x`, excluding `x` and `y`.}
#'   \item{`"backdoor"`}{The Pearl backdoor formula (parents of `x`).}
#'   \item{`"optimal"`}{The O-set: parents of the causal nodes between `x`
#'     and `y` (nodes on a possibly-causal path), excluding `x` and those
#'     causal nodes themselves.}
#' }
#' Validate a candidate set directly with [cs_is_valid_adjustment()].
#'
#' @param graph A graph created with [cs_cgraph()].
#' @param x,y Exposure and outcome node names.
#' @param type Adjustment set type: `"optimal"` (default), `"parents"`, or
#'   `"backdoor"`.
#' @return Character vector with a valid adjustment set, or `NULL` if none
#'   exists.
#'
#' @details
#' For MAGs it searches for the smallest valid adjustment set by
#' trying sizes 0, 1, 2, ... in order and stopping at the first valid set.
#'
#' @references
#' Henckel, Y., Perković, E., & Maathuis, M. H. (2022). Graphical Criteria for
#' Efficient Total Effect Estimation Via Adjustment in Causal Linear Models.
#' *Journal of the Royal Statistical Society: Series B*, 84:579-599.
#' (`"optimal"`)
#'
#' Pearl, J. (2009). *Causality: Models, Reasoning and Inference* (2nd ed.).
#' Cambridge University Press. (`"parents"` and `"backdoor"`)
#' @export
#' @examples
#' if (JuliaConnectoR::juliaSetupOk()) {
#'   dag <- cs_cgraph(A %-->% X, X %-->% M, M %-->% Y, A %-->% Y)
#'   cs_adjustment_set(dag, "X", "Y")
#'   cs_adjustment_set(dag, "X", "Y", type = "parents")
#'   cs_adjustment_set(dag, "X", "Y", type = "backdoor")
#' }
cs_adjustment_set <- function(
  graph,
  x,
  y,
  type = c("optimal", "parents", "backdoor")
) {
  type <- match.arg(type)
  res <- cs_fn("adjustment_set")(graph, x, y, type)
  if (is.null(res)) NULL else cs_split(res)
}

#' Find a frontdoor adjustment set
#'
#' Returns a set `Z` with `include ⊆ Z ⊆ restrict` satisfying all three
#' front-door conditions (Algorithm 1 of the reference below) for the causal
#' effect of `x` on `y`; validate a candidate set directly with
#' [cs_is_valid_frontdoor()].
#'
#' @param graph A graph created with [cs_cgraph()].
#' @param x,y Exposure and outcome node names.
#' @param include Character vector of nodes forced into the set.
#' @param restrict Character vector of candidate nodes the set is drawn
#'   from. `NULL` (default) allows every node except `x` and `y`.
#' @return Character vector with a valid frontdoor set, or `NULL` if none
#'   exists.
#' @references
#' Jeong, S., Tian, J., & Bareinboim, E. (2022). Finding and Listing
#' Front-Door Adjustment Sets. *Advances in Neural Information Processing
#' Systems*, 35.
#' @export
#' @examples
#' if (JuliaConnectoR::juliaSetupOk()) {
#'   dag <- cs_cgraph(U %-->% X, U %-->% Y, X %-->% Z, Z %-->% Y)
#'   cs_frontdoor_set(dag, "X", "Y") # Z mediates X -> Y
#'   cs_frontdoor_set(dag, "X", "Y", restrict = "Z")
#' }
cs_frontdoor_set <- function(
  graph,
  x,
  y,
  include = character(),
  restrict = NULL
) {
  restrict_arg <- if (is.null(restrict)) NULL else as.character(restrict)
  res <- cs_fn("frontdoor_set")(
    graph,
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
#' @param graph A graph created with [cs_cgraph()].
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
cs_is_valid_backdoor <- function(graph, x, y, given = character()) {
  cs_fn("is_valid_backdoor")(graph, x, y, as.character(given))
}

#' Enumerate backdoor adjustment sets
#'
#' Lists all sets (up to size `max_size`) satisfying the backdoor criterion;
#' see [cs_is_valid_backdoor()]. When `minimal = TRUE` (default), only
#' inclusion-minimal sets are returned.
#'
#' @param graph A graph created with [cs_cgraph()].
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
cs_all_backdoor_sets <- function(graph, x, y, minimal = TRUE, max_size = 3) {
  cs_split_sets(cs_fn("all_backdoor_sets")(graph, x, y, minimal, max_size))
}

#' Enumerate frontdoor adjustment sets
#'
#' Lists all sets `Z` with `include ⊆ Z ⊆ restrict` satisfying the
#' front-door criterion; see [cs_frontdoor_set()] and
#' [cs_is_valid_frontdoor()].
#'
#' @param graph A graph created with [cs_cgraph()].
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
  graph,
  x,
  y,
  include = character(),
  restrict = NULL
) {
  restrict_arg <- if (is.null(restrict)) NULL else as.character(restrict)
  cs_split_sets(
    cs_fn("all_frontdoor_sets")(
      graph,
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
#' @param graph A graph created with [cs_cgraph()].
#' @param x,y Exposure and outcome node names.
#' @param given Character vector of adjustment node names (may be empty).
#' @return `TRUE` if `given` satisfies the adjustment criterion for
#'   identifying the causal effect of `x` on `y`.
#' @references
#' Perković, E., Textor, J., Kalisch, M., & Maathuis, M. H. (2018). Complete
#' Graphical Characterization and Construction of Adjustment Sets in Markov
#' Equivalence Classes of Ancestral Graphs. *Journal of Machine Learning
#' Research*, 18:1-62.
#' @export
#' @examples
#' if (JuliaConnectoR::juliaSetupOk()) {
#'   admg <- cs_cgraph(L %-->% X, X %-->% Y, L %-->% Y, class = "ADMG")
#'   cs_is_valid_adjustment(admg, "X", "Y") # empty set does not block L --> Y
#'   cs_is_valid_adjustment(admg, "X", "Y", "L") # conditioning on L blocks it
#' }
cs_is_valid_adjustment <- function(graph, x, y, given = character()) {
  cs_fn("is_valid_adjustment")(graph, x, y, as.character(given))
}

#' Enumerate all valid adjustment sets
#'
#' Lists all sets (up to size `max_size`) satisfying the Generalized
#' Adjustment Criterion; see [cs_is_valid_adjustment()]. When
#' `minimal = TRUE` (default), only inclusion-minimal sets are returned.
#'
#' @param graph A graph created with [cs_cgraph()].
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
cs_all_adjustment_sets <- function(graph, x, y, minimal = TRUE, max_size = 3) {
  cs_split_sets(cs_fn("all_adjustment_sets")(graph, x, y, minimal, max_size))
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
#' @param graph A graph created with [cs_cgraph()].
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
cs_is_valid_frontdoor <- function(graph, x, y, given = character()) {
  cs_fn("is_valid_frontdoor")(graph, x, y, as.character(given))
}

#' Validate instrumental variables
#'
#' Tests whether a set of variables are valid instruments for identifying
#' the causal effect of exposure `x` on outcome `y`: every node in `z` must
#' be d-/m-separated from `y` given `x` in the graph obtained by deleting
#' `x`'s incoming edges (exclusion restriction), and at least one node in
#' `z` must be d-/m-connected to `x` (relevance).
#'
#' @param graph A graph created with [cs_cgraph()].
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
cs_is_valid_iv <- function(graph, x, y, z = character()) {
  cs_fn("is_valid_iv")(graph, x, y, as.character(z))
}

#' Enumerate all valid instrumental variable sets
#'
#' Finds all minimal (or all) sets of valid instruments for identifying
#' the causal effect of `x` on `y`; see [cs_is_valid_iv()].
#'
#' @param graph A graph created with [cs_cgraph()].
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
cs_all_iv_sets <- function(graph, x, y, minimal = TRUE, max_size = 3) {
  cs_split_sets(cs_fn("all_iv_sets")(graph, x, y, minimal, max_size))
}

# --- Equivalence classes and counts ------------------------------------------

#' Equivalence class analysis
#'
#' `cs_count_dags()` returns the count of distinct DAGs in a Markov equivalence
#' class represented by a CPDAG. `cs_enumerate_dags()` returns all DAGs in the
#' class. `cs_markov_equivalent()` tests whether two graphs are Markov
#' equivalent: they share the same skeleton and the same set of v-structures
#' (unshielded colliders `a --> b <-- c` with `a`, `c` non-adjacent).
#'
#' @param graph A graph created with [cs_cgraph()], typically a CPDAG.
#' @param g1,g2 Graphs to compare.
#' @return For `cs_count_dags()`, an integer count. For `cs_enumerate_dags()`,
#'   a list of DAG proxies. For `cs_markov_equivalent()`, a logical scalar.
#' @name cs-equivalence
#' @examples
#' if (JuliaConnectoR::juliaSetupOk()) {
#'   cpdag <- cs_cgraph(A %---% B, B %---% C, class = "CPDAG")
#'   cs_count_dags(cpdag)
#'   length(cs_enumerate_dags(cpdag))
#'
#'   g1 <- cs_cgraph(A %-->% B, C %-->% B)
#'   g2 <- cs_cgraph(A %-->% B, C %-->% B)
#'   cs_markov_equivalent(g1, g2)
#' }
NULL

#' @rdname cs-equivalence
#' @export
cs_count_dags <- cs_graph_fn("count_dags")

#' @rdname cs-equivalence
#' @export
cs_enumerate_dags <- function(graph) {
  cs_fn("enumerate_dags")(graph)
}

#' @rdname cs-equivalence
#' @export
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
#' @param graph A PAG (partially ancestral graph) created with [cs_cgraph()].
#' @return A Julia proxy list of MAGs in the equivalence class.
#' @export
#' @examples
#' if (JuliaConnectoR::juliaSetupOk()) {
#'   pag <- cs_cgraph(A %o-o% B, B %o-o% C, class = "PAG")
#'   length(cs_enumerate_mags(pag))
#' }
cs_enumerate_mags <- function(graph) {
  cs_fn("enumerate_mags")(graph)
}
