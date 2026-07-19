skip_if_no_julia <- function() {
  testthat::skip_if_not(
    JuliaConnectoR::juliaSetupOk(),
    "Julia is not available"
  )
  has_pkg <- tryCatch(
    {
      cs_pkg_path()
      TRUE
    },
    error = function(e) FALSE
  )
  testthat::skip_if_not(has_pkg, "CausalStructures.jl checkout not found")
}

# Quick-guide DAG shared across tests, built once per test run
test_dag <- local({
  g <- NULL
  function() {
    if (is.null(g)) {
      g <<- cs_cgraph(A %-->% X + Y, X %-->% M %-->% Y)
    }
    g
  }
})
