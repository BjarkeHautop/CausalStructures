# --- Data generation -------------------------------------------------------

#' Simulate data from a DAG
#'
#' Simulates observational data from a linear Gaussian structural causal
#' model over `cg`. Each node is a linear function of its parents plus
#' independent Gaussian noise with standard deviation `error_sd`, with edge
#' coefficients drawn uniformly from `coef_range`. If `standardize = TRUE`
#' (default), each variable is standardized to zero mean and unit variance.
#'
#' A sign-symmetric coefficient range such as `c(-1, 1)` puts many
#' coefficients near zero, i.e. near-unfaithful edges. To keep every edge's
#' coefficient away from zero, use a positive range with `random_sign = TRUE`,
#' e.g. `coef_range = c(0.5, 2)`.
#'
#' @param cg A DAG created with [cgraph()].
#' @param n Number of samples to generate.
#' @param standardize If `TRUE` (default), standardize each variable to zero
#'   mean and unit variance.
#' @param coef_range Length-2 numeric vector giving the range edge
#'   coefficients are drawn uniformly from.
#' @param random_sign If `TRUE`, draw each coefficient's magnitude from
#'   `coef_range` and its sign independently at random, instead of drawing
#'   the signed coefficient from `coef_range`.
#' @param error_sd Standard deviation of each node's Gaussian noise term, or
#'   a length-2 range each node's standard deviation is drawn uniformly
#'   from.
#' @param seed Optional integer seed for reproducibility.
#' @return A data frame with `n` rows (samples) and one column per node,
#'   named and ordered as in [nodes()].
#' @export
#' @examples
#' if (julia_ready()) {
#'   dag <- cgraph(A %-->% B, B %-->% C)
#'   data <- simulate_data(dag, n = 100, seed = 1405)
#'   head(data)
#' }
#'
#' if (julia_ready()) {
#'   dag <- cgraph(A %-->% B, B %-->% C)
#'   data2 <- simulate_data(
#'     dag,
#'     n = 100,
#'     standardize = FALSE,
#'     coef_range = c(0.5, 2),
#'     random_sign = TRUE,
#'     error_sd = c(0.5, 1.5),
#'     seed = 1405
#'   )
#'   head(data2)
#' }
simulate_data <- function(
  cg,
  n,
  standardize = TRUE,
  coef_range = c(-1, 1),
  random_sign = FALSE,
  error_sd = 1,
  seed = NULL
) {
  mat <- jl_simulate_data(
    cg,
    n,
    make_rng(seed),
    standardize,
    as.numeric(coef_range),
    random_sign,
    as.numeric(error_sd)
  )
  df <- as.data.frame(mat)
  names(df) <- nodes(cg)
  df
}
