# Design notes:
# - CausalStructures.jl is compiled with juliac by jlbind, into one library with
#   the binding packages of every installed package that uses jlbind; the
#   binding package is inst/julia (`csjl`). There is no Julia session to start
#   and nothing to precompile.
# - Each `@rcall` entrypoint `csjl_<name>` takes and returns R objects and
#   converts them itself through R's C API, so a call is a single
#   `.External(.jlbind$.call, .jlbind$<name>, ...)`, through jlbind's own
#   routine: the package has no compiled code of its own.
#   A failure inside the library comes back as a `jlbind_error` object and is
#   raised by that routine, so R never unwinds through Julia frames.
# - A graph cannot cross into R as a value, so R holds an external pointer to
#   it (`RRef{CausalGraph}`), with class `cgraph` and a finalizer that releases
#   the library's reference.
# - jlbind::bind_client() looks up the entrypoints in the library when the
#   package is loaded. Graphs go to the library as `cgraph`s, node sets as
#   character vectors.
# - jlbind generates an R function per entrypoint (R/jlbind-wrappers.R). One
#   that needs no R code is exported as it is, with its roxygen tags above the
#   `@rcall`. One that does is `jl_`-prefixed, and a hand-written function calls
#   it.

#' Package options
#'
#' Settings that change how `CausalStructures` behaves: one option, set with
#' [options()], and the number of threads, set with an environment variable.
#'
#' @section Options:
#' \describe{
#'   \item{`CausalStructures.open`}{Logical, default `TRUE`. Default for the
#'     `open` argument of [ancestors()], [descendants()],
#'     [possible_ancestors()], [possible_descendants()], [anteriors()], and
#'     [posteriors()]: `TRUE` (open definition) excludes the query node
#'     itself from the result, `FALSE` (closed definition) includes it.}
#' }
#'
#' @section Number of threads:
#' [count_dags()], [enumerate_dags()], [enumerate_mags()], [pagcauses()],
#' [all_backdoor_sets()], [all_adjustment_sets()], and [all_frontdoor_sets()]
#' can search in parallel. By default they use one thread. To use more, set
#' `JULIA_NUM_THREADS` to a number, or to `"auto"` for one thread per core,
#' before loading the package:
#'
#' ```r
#' Sys.setenv(JULIA_NUM_THREADS = "auto")
#' library(CausalStructures)
#' ```
#'
#' To make this permanent, set it in your `.Renviron` file instead. The number
#' cannot be changed once the package is loaded, so restart R to change it.
#'
#' @name CausalStructures_options
NULL

#' Is the compiled CausalStructures.jl library available?
#'
#' Every function of the package calls the library built by
#' [jlbind::install_library()], and errors if it is not available. When it is
#' not, `jlbind::check_bound("CausalStructures")` says why.
#'
#' @return A logical scalar.
#' @export
julia_ready <- function() {
  jlbind::is_bound("CausalStructures")
}

# Plain R data to save a graph as, called by jlbind when R serializes one (see
# `r_saved_by` in JLBind). Julia rebuilds the graph from it
# on first use after loading (`r_restore` in inst/julia/src/csjl.jl).
# jarl-ignore unused_function: called from C by jlbind (src/state.c) when saving
.jlbind_saved_state <- function(x) {
  marks <- jl_edge_marks(x)
  list(
    class = jl_class_name(x),
    nodes = nodes(x),
    from = marks[, 1L],
    to = marks[, 2L],
    src_mark = marks[, 3L],
    dst_mark = marks[, 4L]
  )
}

# A seed for the library's RNG, or `NULL` for an unseeded one.
make_rng <- function(seed) {
  if (is.null(seed)) NULL else as.numeric(seed)
}

.onLoad <- function(libname, pkgname) {
  jlbind::bind_client(pkgname)
}

.onAttach <- function(libname, pkgname) {
  if (!julia_ready()) {
    packageStartupMessage(
      "The compiled CausalStructures.jl library is not available. Run ",
      "jlbind::install_library() to build it."
    )
  }
}

#' @importFrom Rdpack reprompt
NULL
