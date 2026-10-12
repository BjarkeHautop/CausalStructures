skip_if_no_julia <- function() {
  testthat::skip_if_not(
    julia_ready(),
    "Julia is not ready (not installed, or dependencies not instantiated)"
  )
}

# NetworkLayout and Sugiyama do not compile under `juliac --trim`, so the
# compiled library has no layout algorithms and plotting is unavailable.
skip_if_no_layout <- function() {
  testthat::skip("graph layout is not available in the compiled library")
}

# Quick-guide DAG shared across tests, built once per test run
test_dag <- local({
  g <- NULL
  function() {
    if (is.null(g)) {
      g <<- cgraph(A %-->% X + Y, X %-->% M %-->% Y)
    }
    g
  }
})
