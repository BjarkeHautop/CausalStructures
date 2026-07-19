# --- Data generation -------------------------------------------------------

#' Simulate data from a DAG
#'
#' Generates random data conforming to the causal structure of a DAG.
#' Edges receive random coefficients, and nodes receive random noise.
#'
#' @param graph A DAG created with [cs_cgraph()].
#' @param n Number of samples to generate.
#' @param seed Optional integer seed for reproducibility.
#' @return A data frame with `n` rows (samples) and one column per node.
#' @export
cs_simulate_data <- function(graph, n, seed = NULL) {
  cs_fn("simulate_data")(graph, n, seed)
}
