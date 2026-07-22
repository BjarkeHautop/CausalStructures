# --- Data generation -------------------------------------------------------

#' Simulate data from a DAG
#'
#' Simulates observational data from a linear Gaussian structural causal
#' model over `cg`: each node is a linear function of its parents plus
#' independent Gaussian noise with standard deviation `error_sd`, with edge
#' coefficients drawn uniformly from `coef_range`. If `standardize = TRUE`
#' (default), each variable is standardized to zero mean and unit variance.
#'
#' @param cg A DAG created with [cs_cgraph()].
#' @param n Number of samples to generate.
#' @param standardize If `TRUE` (default), standardize each variable to zero
#'   mean and unit variance.
#' @param coef_range Length-2 numeric vector giving the range edge
#'   coefficients are drawn uniformly from.
#' @param error_sd Standard deviation of each node's Gaussian noise term.
#' @param seed Optional integer seed for reproducibility.
#' @return A data frame with `n` rows (samples) and one column per node,
#'   named and ordered as in [cs_nodes()].
#' @export
#' @examples
#' if (JuliaConnectoR::juliaSetupOk()) {
#'   dag <- cs_cgraph(A %-->% B, B %-->% C)
#'   data <- cs_simulate_data(dag, n = 100, seed = 1405)
#'   head(data)
#'
#'   data2 <- cs_simulate_data(
#'     dag,
#'     n = 100,
#'     standardize = FALSE,
#'     coef_range = c(0.5, 2),
#'     error_sd = 0.1,
#'     seed = 1405
#'   )
#'   head(data2)
#' }
cs_simulate_data <- function(
  cg,
  n,
  standardize = TRUE,
  coef_range = c(-1, 1),
  error_sd = 1,
  seed = NULL
) {
  raw <- cs_fn("simulate_data")(
    cg,
    n,
    cs_make_rng(seed),
    standardize,
    coef_range,
    error_sd
  )
  ns <- cs_nodes(cg)
  vals <- as.numeric(strsplit(raw, "\x1f", fixed = TRUE, useBytes = TRUE)[[1]])
  df <- as.data.frame(matrix(vals, nrow = n, ncol = length(ns)))
  names(df) <- ns
  df
}
