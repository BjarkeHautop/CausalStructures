# --- Graph comparison metrics ------------------------------------------------

#' Hamming distances between two graphs
#'
#' `hd()` is the skeleton Hamming distance: the number of node pairs on which
#' `cg1` and `cg2` disagree about whether an edge is present, ignoring edge
#' type and orientation. `shd()` is the Structural Hamming Distance: the
#' number of node pairs on which they disagree at all, about the presence of
#' an edge or about its marks, weighting both kinds of mismatch equally.
#'
#' The two graphs must have the same nodes, but may be of different classes.
#' SHD was originally defined for PDAGs; `shd()` extends it naturally to any
#' pair of graphs.
#'
#' @param cg1,cg2 Graphs created with [cgraph()], of any class, with the
#'   same nodes.
#' @param normalized If `TRUE`, divide by the number of node pairs,
#'   `n * (n - 1) / 2`, giving a value in `[0, 1]`.
#' @return A number: the count of disagreeing node pairs, or its share of all
#'   node pairs if `normalized = TRUE`.
#' @references
#' \insertRef{tsamardinos2006max}{CausalStructures}
#' @name hamming
#' @examples
#' if (julia_ready()) {
#'   chain <- cgraph(A %-->% B %-->% C)
#'   collider <- cgraph(A %-->% B, C %-->% B)
#'   list(
#'     hd = hd(chain, collider), # same skeleton
#'     shd = shd(chain, collider), # B -- C is oriented differently
#'     shd_normalized = shd(chain, collider, normalized = TRUE)
#'   )
#' }
NULL

#' Adjustment Identification Distance
#'
#' Counts the ordered pairs of distinct nodes `(t, y)` for which `cg_test`
#' leads to a wrong conclusion about the causal effect of `t` on `y`
#' relative to `cg_truth`. For each pair, an adjustment set is read off
#' `cg_test` with the strategy `type`, and it is a mistake if that set is
#' not a valid adjustment set in `cg_truth`.
#'
#' Outside the pairs its adjustment set applies to (`y` not a possible
#' descendant of `t` in `cg_test`, or, for `"parent"`, `y` a parent of `t`),
#' the strategy instead claims a zero effect, which is correct if `y` is not
#' a possible descendant of `t` in `cg_truth`. For a PDAG-family `cg_test`
#' where the effect is not identifiable, the strategy claims so, which is
#' correct if it is not identifiable in `cg_truth` either.
#'
#' @param cg_truth The ground-truth graph: a DAG or PDAG-family graph (PDAG,
#'   CPDAG, MPDAG) created with [cgraph()].
#' @param cg_test The graph to evaluate, of the same kinds and with the same
#'   nodes as `cg_truth`.
#' @param type The adjustment strategy: `"oset"` (default; the optimal
#'   adjustment set, see [adjustment_set()]), `"parent"` (the parents of
#'   `t`), or `"ancestor"` (the ancestors of `t`, which makes the distance
#'   zero whenever `cg_test` respects the causal order of `cg_truth`).
#' @param normalized If `TRUE`, divide by the number of ordered pairs,
#'   `n * (n - 1)`, giving a value in `[0, 1]`.
#' @return A number: the count of mistaken pairs, or its share of all ordered
#'   pairs if `normalized = TRUE`.
#' @references
#' \insertRef{henckel2024aid}{CausalStructures}
#' @export
#' @examples
#' if (julia_ready()) {
#'   truth <- cgraph(A %-->% B %-->% C, A %-->% C)
#'   guess <- cgraph(A %-->% B %-->% C)
#'   list(
#'     oset = aid(truth, guess),
#'     parent = aid(truth, guess, type = "parent"),
#'     ancestor = aid(truth, guess, type = "ancestor")
#'   )
#' }
aid <- function(
  cg_truth,
  cg_test,
  type = c("oset", "parent", "ancestor"),
  normalized = FALSE
) {
  type <- if (missing(type)) type[[1L]] else match.arg(type)
  jl_aid(cg_truth, cg_test, type, normalized)
}

#' Separation distance between two graphs
#'
#' For every pair of nodes non-adjacent in `cg2`, picks a set separating them
#' in `cg2`, and counts the pairs that set fails to separate in `cg1`. This
#' measures how far `cg1` is from satisfying the independences `cg2`
#' implies, in the way a constraint-based analysis would test them.
#'
#' The separating set is picked by class:
#' \describe{
#'   \item{DAG}{By `strategy`: `"parents"` (the parents of both nodes),
#'     `"ancestors"` (their ancestors), or `"zl"` (a minimal separator, as
#'     [minimal_separator()]).}
#'   \item{AG, MAG, PAG}{A minimal separator.}
#'   \item{PDAG, CPDAG, MPDAG}{The possible parents of both nodes: their
#'     parents in any DAG consistent with `cg2`, which is invariant under
#'     Markov equivalence.}
#' }
#' `mb_enhanced = TRUE` uses the Markov blanket of the first node instead
#' wherever it separates them, which is often cheaper on sparse graphs.
#'
#' @param cg1 The graph the separating sets are tested in.
#' @param cg2 The graph the separating sets are read off: a DAG,
#'   PDAG-family (PDAG, CPDAG, MPDAG), AG-family (AG, MAG), or PAG graph
#'   created with [cgraph()], of the same kind as `cg1` and with the same
#'   nodes.
#' @param strategy The separating set strategy for two DAGs: `"parents"`
#'   (default), `"ancestors"`, or `"zl"`. Not available for other classes.
#' @param mb_enhanced If `TRUE`, use Markov blankets as separating sets where
#'   possible.
#' @param symmetric If `TRUE`, average the distance over both directions.
#' @param normalized If `TRUE`, divide by the number of node pairs,
#'   `n * (n - 1) / 2`, giving a value in `[0, 1]`.
#' @return A number: the count of failed separations, or its share of all
#'   node pairs if `normalized = TRUE`.
#' @references
#' \insertRef{wahlrunge2025separation}{CausalStructures}
#' @export
#' @examples
#' if (julia_ready()) {
#'   cg1 <- cgraph(A %-->% B %-->% C, A %-->% C, C %-->% D)
#'   cg2 <- cgraph(A %-->% B %-->% C %-->% D)
#'   list(
#'     parents = separation_distance(cg1, cg2),
#'     zl = separation_distance(cg1, cg2, strategy = "zl"),
#'     symmetric = separation_distance(cg1, cg2, symmetric = TRUE)
#'   )
#' }
separation_distance <- function(
  cg1,
  cg2,
  strategy = c("parents", "ancestors", "zl"),
  mb_enhanced = FALSE,
  symmetric = FALSE,
  normalized = FALSE
) {
  # `NULL` for a missing strategy, which only two DAGs take
  strategy <- if (missing(strategy)) NULL else match.arg(strategy)
  jl_separation_distance(cg1, cg2, strategy, mb_enhanced, symmetric, normalized)
}

#' Separation/connection metrics between two graphs
#'
#' Compare two graphs by every separation statement `(x, y, s)` they imply,
#' for every pair of nodes `x`, `y` and every set `s` of the other nodes with
#' at most `max_order` nodes. The share of statements on which the graphs
#' disagree is computed for each size of `s`, and the shares are averaged
#' over the sizes, so that the many large sets do not dominate.
#'
#' `sc_metric()` counts every disagreement, so it is symmetric in its
#' arguments. `markov_metric()` (the c-metric) counts only the statements
#' connected in `cg_truth` but separated in `cg_test`, the false-negative
#' rate for connections; it is `0` when `cg_test` is at least as connected as
#' `cg_truth`. `faithfulness_metric()` (the s-metric) counts only the
#' statements separated in `cg_truth` but connected in `cg_test`, the
#' false-positive rate. A size with no statements of the counted kind
#' contributes `0`.
#'
#' The number of statements grows exponentially with the number of nodes,
#' so limit `max_order` for larger graphs.
#'
#' @param cg1,cg2,cg_truth,cg_test Graphs created with [cgraph()], with the
#'   same nodes and the same notion of separation: both d-separation (DAG,
#'   PDAG, CPDAG, MPDAG) or both m-separation (ADMG, AG, MAG, PAG).
#' @param max_order Maximum size of the separating sets. `NULL` (default)
#'   uses every size, up to `n - 2`.
#' @return A number in `[0, 1]`.
#' @references
#' \insertRef{wahlrunge2025separation}{CausalStructures}
#' @name sc-metrics
#' @examples
#' if (julia_ready()) {
#'   truth <- cgraph(A %-->% B %-->% C %-->% D)
#'   test <- cgraph(A %-->% B, C %-->% B, C %-->% D)
#'   list(
#'     sc = sc_metric(truth, test),
#'     sc_marginal = sc_metric(truth, test, max_order = 0),
#'     markov = markov_metric(truth, test),
#'     faithfulness = faithfulness_metric(truth, test)
#'   )
#' }
NULL
