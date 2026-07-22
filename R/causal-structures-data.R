# --- Data generation -------------------------------------------------------

#' Simulate data from a DAG
#'
#' Simulates observational data from a linear Gaussian structural causal
#' model over `cg`: each node is a linear function of its parents plus
#' independent Gaussian noise with standard deviation `error_sd`, with edge
#' coefficients drawn uniformly from `coef_range`. If `standardize = TRUE`
#' (default), each variable is standardized to zero mean and unit variance.
#'
#' @param cg A DAG created with [cgraph()].
#' @param n Number of samples to generate.
#' @param standardize If `TRUE` (default), standardize each variable to zero
#'   mean and unit variance.
#' @param coef_range Length-2 numeric vector giving the range edge
#'   coefficients are drawn uniformly from.
#' @param error_sd Standard deviation of each node's Gaussian noise term.
#' @param seed Optional integer seed for reproducibility.
#' @return A data frame with `n` rows (samples) and one column per node,
#'   named and ordered as in [nodes()].
#' @export
#' @examples
#' if (julia_available()) {
#'   dag <- cgraph(A %-->% B, B %-->% C)
#'   data <- simulate_data(dag, n = 100, seed = 1405)
#'   head(data)
#'
#'   data2 <- simulate_data(
#'     dag,
#'     n = 100,
#'     standardize = FALSE,
#'     coef_range = c(0.5, 2),
#'     error_sd = 0.1,
#'     seed = 1405
#'   )
#'   head(data2)
#' }
simulate_data <- function(
  cg,
  n,
  standardize = TRUE,
  coef_range = c(-1, 1),
  error_sd = 1,
  seed = NULL
) {
  mat <- fn("simulate_data")(
    cg,
    n,
    make_rng(seed),
    standardize,
    coef_range,
    error_sd
  )
  df <- as.data.frame(mat)
  names(df) <- nodes(cg)
  df
}
