# Design notes:
# - CausalStructures.jl is compiled ahead of time with juliac into the `csjl`
#   shared library (built from `jlbuild/`, bundled with its Julia runtime in
#   `inst/csjl`). setup() loads it with dyn.load(); there is no Julia session
#   to start and nothing to precompile.
# - Each library entrypoint `csjl_r_<name>` takes and returns R objects and
#   converts them itself through R's C API, so a call is a single `.Call`.
#   A failure inside the library comes back as a `csjl_error` object and is
#   raised here, so R never unwinds through Julia frames.
# - A graph cannot cross into R as a value, so it lives in a registry in the
#   library and R holds an external pointer to it, created by the library
#   with class `cgraph` and a finalizer that releases the library's copy.
# - Every exported function is a single `.Call` on a native symbol resolved
#   once at load (`.sym`), checked by `.check()`, which raises a returned
#   error. Graphs go to the library as `cgraph`s, node sets as character
#   vectors.

.cs <- new.env(parent = emptyenv())

#' Package options
#'
#' `CausalStructures` reads the following [options()]:
#'
#' \describe{
#'   \item{`CausalStructures.open`}{Logical, default `TRUE`. Default for the
#'     `open` argument of [ancestors()], [descendants()],
#'     [possible_ancestors()], [possible_descendants()], [anteriors()], and
#'     [posteriors()]: `TRUE` (open definition) excludes the query node
#'     itself from the result, `FALSE` (closed definition) includes it.}
#' }
#'
#' The compiled library is looked up in the `CAUSALSTRUCTURES_LIBRARY`
#' environment variable first (a path to `csjl.so`), then in the installed
#' package's `csjl/lib` directory.
#'
#' @name CausalStructures_options
NULL

.library_path <- function() {
  override <- Sys.getenv("CAUSALSTRUCTURES_LIBRARY", unset = "")
  if (nzchar(override)) {
    return(override)
  }
  file <- paste0("csjl", .Platform$dynlib.ext)
  system.file("csjl", "lib", file, package = "CausalStructures")
}

#' Is the compiled CausalStructures.jl library available?
#'
#' @return A logical scalar.
#' @export
julia_ready <- function() {
  isTRUE(tryCatch(
    {
      setup()
      TRUE
    },
    error = function(e) FALSE
  ))
}

#' Load the compiled CausalStructures.jl library
#'
#' Called automatically by the wrapper functions; call it yourself to pay
#' the (small) library load cost up front. The library is compiled ahead of
#' time, so there is no Julia session to start and nothing to precompile.
#'
#' @return `NULL`, invisibly.
#' @export
#' @examples
#' if (julia_ready()) {
#'   setup()
#' }
setup <- function() {
  if (isTRUE(.cs$ready)) {
    return(invisible(NULL))
  }
  path <- .library_path()
  if (!nzchar(path) || !file.exists(path)) {
    stop(
      "The compiled CausalStructures.jl library was not found. Build it ",
      "with `julia jlbuild/build.jl`, or set CAUSALSTRUCTURES_LIBRARY.",
      call. = FALSE
    )
  }
  dll <- dyn.load(path, local = TRUE, now = TRUE)
  for (name in .entrypoints) {
    .sym[[name]] <- getNativeSymbolInfo(paste0("csjl_r_", name), dll)
  }
  .cs$ready <- TRUE
  invisible(NULL)
}

# Calls with no library entrypoint.
fn <- function(name) {
  switch(
    name,
    # NetworkLayout and Sugiyama do not compile under `juliac --trim`, so the
    # library carries no layout algorithms.
    layout = function(...) {
      stop(
        "cgraph_layout() is not available in the compiled library.",
        call. = FALSE
      )
    }
  )
}

# A seed for the library's RNG, or `NULL` for an unseeded one.
make_rng <- function(seed) {
  if (is.null(seed)) NULL else as.numeric(seed)
}

# --- Calls -------------------------------------------------------------------

# Native symbols of the library entrypoints, filled by setup().
.sym <- new.env(parent = emptyenv())

# A library failure is returned as a classed character vector, the only
# character result that carries a class.
.check <- function(res) {
  if (is.character(res) && is.object(res)) {
    stop(res[[1L]], call. = FALSE)
  }
  res
}

.onLoad <- function(libname, pkgname) {
  tryCatch(setup(), error = function(e) NULL)
}

# Library entrypoints, each exported as `csjl_r_<name>`.
.entrypoints <- c(
  "graph_count",
  "cgraph",
  "graph_string",
  "generate_graph",
  "uniform_dag",
  "nodes",
  "edge_marks",
  "edges",
  "topological_sort",
  "exogenous_nodes",
  "has_edge",
  "parents",
  "children",
  "spouses",
  "markov_blanket",
  "neighbors",
  "ancestors",
  "descendants",
  "anteriors",
  "posteriors",
  "possible_ancestors",
  "possible_descendants",
  "is_dag",
  "is_pdag",
  "is_cpdag",
  "is_mpdag",
  "is_ug",
  "is_admg",
  "is_ag",
  "is_mag",
  "is_pag",
  "is_simple",
  "is_acyclic",
  "is_dag_type",
  "markov_equivalent",
  "d_separated",
  "m_separated",
  "minimal_separator",
  "possible_d_sep",
  "adjustment_set",
  "backdoor_set",
  "frontdoor_set",
  "all_frontdoor_sets",
  "is_valid_backdoor",
  "all_backdoor_sets",
  "is_valid_adjustment",
  "all_adjustment_sets",
  "is_valid_frontdoor",
  "is_valid_iv",
  "all_iv_sets",
  "id",
  "idc",
  "possible_parent_sets",
  "possible_joint_parent_sets",
  "possible_optimal_adjustment_sets",
  "possible_local_structures",
  "pagcauses",
  "count_dags",
  "enumerate_dags",
  "enumerate_mags",
  "skeleton",
  "moralize",
  "dag_to_cpdag",
  "dag_from_pdag",
  "dag_to_mpdag",
  "ag_to_mag",
  "mag_to_pag",
  "mag_from_pag",
  "meek_closure",
  "subgraph",
  "latent_project",
  "exogenize",
  "normalize_latent_structure",
  "condition_marginalize",
  "maximal_local_mag",
  "reclass",
  "add_edges",
  "remove_edges",
  "add_nodes",
  "remove_nodes",
  "simulate_data"
)

# --- Wrapper factories -------------------------------------------------------

node_query <- function(name) {
  force(name)
  function(cg, node) .check(.Call(.sym[[name]], cg, node))
}

graph_fn <- function(name) {
  force(name)
  function(cg) .check(.Call(.sym[[name]], cg))
}

cgraph_fn <- graph_fn


#' @importFrom Rdpack reprompt
NULL
