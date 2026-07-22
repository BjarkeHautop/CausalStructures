# --- Data generation (JuliaCall backend; see jc-session.R) ------------------

# Unlike cs_simulate_data(), no strsplit()/as.numeric() reconstruction: the
# Julia helper returns a native Matrix{Float64} directly. Benchmarked as
# faster here than the joined-string convention (the opposite of the
# JuliaConnectoR case - see jc-session.R), as well as simpler.
jc_simulate_data <- function(
  cg,
  n,
  standardize = TRUE,
  coef_range = c(-1, 1),
  error_sd = 1,
  seed = NULL
) {
  mat <- jc_fn("simulate_data")(
    cg,
    n,
    jc_make_rng(seed),
    standardize,
    coef_range,
    error_sd
  )
  df <- as.data.frame(mat)
  names(df) <- jc_nodes(cg)
  df
}
