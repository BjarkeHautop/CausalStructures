# --- Separation --------------------------------------------------------------

#' Test d-separation
#'
#' @param graph A graph created with [cs_cgraph()].
#' @param x,y Node names.
#' @param given Character vector of conditioning node names (may be empty).
#' @return `TRUE` if `x` and `y` are d-separated given `given`.
#' @export
cs_d_separated <- function(graph, x, y, given = character()) {
  cs_fn("d_separated")(graph, x, y, as.character(given))
}

#' Test m-separation
#'
#' @inheritParams cs_d_separated
#' @return `TRUE` if `x` and `y` are m-separated given `given`.
#' @export
cs_m_separated <- function(graph, x, y, given = character()) {
  cs_fn("m_separated")(graph, x, y, as.character(given))
}

#' Find a minimal separator
#'
#' @param graph A graph created with [cs_cgraph()].
#' @param x,y Node names.
#' @return Character vector with a minimal separating set, or `NULL` if none
#'   exists.
#' @export
cs_minimal_separator <- function(graph, x, y) {
  res <- cs_fn("minimal_separator")(graph, x, y)
  if (is.null(res)) NULL else cs_split(res)
}

# --- Causal identification ---------------------------------------------------

#' Find a backdoor adjustment set
#'
#' @param graph A graph created with [cs_cgraph()].
#' @param x,y Exposure and outcome node names.
#' @return Character vector with a valid adjustment set, or `NULL` if none
#'   exists.
#' @export
cs_adjustment_set <- function(graph, x, y) {
  res <- cs_fn("adjustment_set")(graph, x, y)
  if (is.null(res)) NULL else cs_split(res)
}

#' Find a frontdoor adjustment set
#'
#' @inheritParams cs_adjustment_set
#' @return Character vector with a valid frontdoor set, or `NULL` if none
#'   exists.
#' @export
cs_frontdoor_set <- function(graph, x, y) {
  res <- cs_fn("frontdoor_set")(graph, x, y)
  if (is.null(res)) NULL else cs_split(res)
}

#' Validate a backdoor adjustment set
#'
#' @param graph A graph created with [cs_cgraph()].
#' @param x,y Exposure and outcome node names.
#' @param given Character vector of adjustment node names (may be empty).
#' @return `TRUE` if `given` satisfies the backdoor criterion.
#' @export
cs_is_valid_backdoor <- function(graph, x, y, given = character()) {
  cs_fn("is_valid_backdoor")(graph, x, y, as.character(given))
}

#' Enumerate adjustment sets
#'
#' `cs_all_backdoor_sets()` lists all minimal backdoor adjustment sets;
#' `cs_all_frontdoor_sets()` lists all frontdoor sets.
#'
#' @param graph A graph created with [cs_cgraph()].
#' @param x,y Exposure and outcome node names.
#' @return List of character vectors (empty list if none exist).
#' @name cs-all-sets
NULL

#' @rdname cs-all-sets
#' @export
cs_all_backdoor_sets <- function(graph, x, y) {
  cs_split_sets(cs_fn("all_backdoor_sets")(graph, x, y))
}

#' @rdname cs-all-sets
#' @export
cs_all_frontdoor_sets <- function(graph, x, y) {
  cs_split_sets(cs_fn("all_frontdoor_sets")(graph, x, y))
}

#' Validate an adjustment set
#'
#' @param graph A graph created with [cs_cgraph()].
#' @param x,y Exposure and outcome node names.
#' @param given Character vector of adjustment node names (may be empty).
#' @return `TRUE` if `given` satisfies the adjustment criterion for
#'   identifying the causal effect of `x` on `y`.
#' @export
cs_is_valid_adjustment <- function(graph, x, y, given = character()) {
  cs_fn("is_valid_adjustment")(graph, x, y, as.character(given))
}

#' Enumerate all valid adjustment sets
#'
#' @param graph A graph created with [cs_cgraph()].
#' @param x,y Exposure and outcome node names.
#' @return List of character vectors (empty list if none exist).
#' @export
cs_all_adjustment_sets <- function(graph, x, y) {
  cs_split_sets(cs_fn("all_adjustment_sets")(graph, x, y))
}

#' Validate a frontdoor criterion set
#'
#' @param graph A graph created with [cs_cgraph()].
#' @param x,y Exposure and outcome node names.
#' @param given Character vector of conditioning node names (may be empty).
#' @return `TRUE` if the configuration satisfies the frontdoor criterion.
#' @export
cs_is_valid_frontdoor <- function(graph, x, y, given = character()) {
  cs_fn("is_valid_frontdoor")(graph, x, y, as.character(given))
}

#' Validate instrumental variables
#'
#' Tests whether a set of variables are valid instruments for identifying
#' the causal effect of exposure `x` on outcome `y`.
#'
#' @param graph A graph created with [cs_cgraph()].
#' @param x,y Exposure and outcome node names.
#' @param z Character vector of instrument node names.
#' @return `TRUE` if `z` satisfies the instrumental variable criterion.
#' @export
cs_is_valid_iv <- function(graph, x, y, z = character()) {
  cs_fn("is_valid_iv")(graph, x, y, as.character(z))
}

#' Enumerate all valid instrumental variable sets
#'
#' Finds all minimal (or all) sets of valid instruments for identifying
#' the causal effect of `x` on `y`.
#'
#' @param graph A graph created with [cs_cgraph()].
#' @param x,y Exposure and outcome node names.
#' @param minimal If `TRUE` (default), return only minimal sets.
#' @param max_size Maximum number of instruments to consider.
#' @return List of character vectors (empty list if none exist).
#' @export
cs_all_iv_sets <- function(graph, x, y, minimal = TRUE, max_size = 3) {
  cs_split_sets(cs_fn("all_iv_sets")(graph, x, y, minimal, max_size))
}

# --- Equivalence classes and counts ------------------------------------------

#' Equivalence class analysis
#'
#' `cs_count_dags()` returns the count of distinct DAGs in a Markov equivalence
#' class represented by a CPDAG. `cs_enumerate_dags()` returns all DAGs in the
#' class. `cs_markov_equivalent()` tests whether two graphs are Markov equivalent.
#'
#' @param graph A graph created with [cs_cgraph()], typically a CPDAG.
#' @param g1,g2 Graphs to compare.
#' @return For `cs_count_dags()`, an integer count. For `cs_enumerate_dags()`,
#'   a list of DAG proxies. For `cs_markov_equivalent()`, a logical scalar.
#' @name cs-equivalence
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
#' represented by a PAG (Partial Ancestral Graph).
#'
#' @param graph A PAG (partially ancestral graph) created with [cs_cgraph()].
#' @return A Julia proxy list of MAGs in the equivalence class.
#' @export
cs_enumerate_mags <- function(graph) {
  cs_fn("enumerate_mags")(graph)
}
