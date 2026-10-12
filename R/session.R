# Design notes:
# - CausalStructures.jl is compiled with juliac into the `csjl` shared library
#   when the package is installed (`configure` runs `tools/csjl/build.jl` with
#   the user's Julia), and the library links against that Julia's runtime.
#   setup() loads it with dyn.load(); there is no Julia session to start and
#   nothing to precompile.
# - Each library entrypoint `csjl_r_<name>` takes and returns R objects and
#   converts them itself through R's C API, so a call is a single `.Call`.
#   A failure inside the library comes back as a `csjl_error` object and is
#   raised here, so R never unwinds through Julia frames.
# - A graph cannot cross into R as a value, so it lives in a registry in the
#   library and R holds an external pointer to it, created by the library
#   with class `cgraph` and a finalizer that releases the library's copy.
# - Every exported function is a single `.Call(C_<name>, ...)` on a routine
#   registered by the package's own shared object (src/init.c), which
#   forwards to the library's `csjl_r_<name>` and raises a returned error;
#   setup() binds those once the library is loaded. Graphs go to the library
#   as `cgraph`s, node sets as character vectors.

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
#' The number of Julia threads is read from the `JULIA_NUM_THREADS`
#' environment variable (a number or `"auto"`) when the package is loaded, so
#' set it before `library(CausalStructures)`. More than one thread also turns
#' on Julia's signal handling in the R process, which Julia's garbage collector
#' needs for multi-threading.
#'
#' The compiled library is looked up in the `CAUSALSTRUCTURES_LIBRARY`
#' environment variable first (a path to the `csjl` shared library), then in
#' the installed package's `csjl` directory, where installation builds it.
#'
#' @name CausalStructures_options
NULL

.library_path <- function() {
  override <- Sys.getenv("CAUSALSTRUCTURES_LIBRARY", unset = "")
  if (nzchar(override)) {
    return(override)
  }
  ext <- switch(
    Sys.info()[["sysname"]],
    Darwin = ".dylib",
    Windows = ".dll",
    ".so"
  )
  system.file("csjl", paste0("csjl", ext), package = "CausalStructures")
}

# On Windows the library has no RUNPATH, so the directory of the Julia
# runtime it links against (recorded by build.jl next to it) is put on the
# PATH, where Windows finds libjulia.dll and its dependencies.
.add_julia_bindir <- function(path) {
  if (.Platform$OS.type != "windows") {
    return(invisible(NULL))
  }
  record <- file.path(dirname(path), "julia_bindir")
  if (!file.exists(record)) {
    return(invisible(NULL))
  }
  bindir <- normalizePath(
    readLines(record, warn = FALSE)[[1L]],
    mustWork = FALSE
  )
  dirs <- strsplit(Sys.getenv("PATH"), ";", fixed = TRUE)[[1L]]
  if (!tolower(bindir) %in% tolower(normalizePath(dirs, mustWork = FALSE))) {
    Sys.setenv(PATH = paste(c(bindir, dirs), collapse = ";"))
  }
  invisible(NULL)
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
      "The compiled CausalStructures.jl library was not found. Reinstall ",
      "the package, or for development build it with ",
      "`julia tools/csjl/build.jl inst/csjl`.",
      call. = FALSE
    )
  }
  # The library links against the Julia that built it, so it stops loading
  # if that Julia is removed (e.g. by a juliaup update).
  .add_julia_bindir(path)
  dll <- tryCatch(
    dyn.load(path, local = TRUE, now = TRUE),
    error = function(e) {
      stop(
        "The compiled CausalStructures.jl library could not be loaded; the ",
        "Julia it was built with may have been removed or updated. ",
        "Reinstall CausalStructures to rebuild it.\n",
        conditionMessage(e),
        call. = FALSE
      )
    }
  )
  # Must run before the first entrypoint call, which initializes Julia.
  threads <- .julia_threads()
  if (threads > 1L) {
    status <- .Call(C_csjl_set_threads, dll[["name"]], threads)
    if (status != 0L) {
      warning(
        "Could not set ",
        threads,
        " Julia threads; using one.",
        call. = FALSE
      )
    }
  }
  .Call(C_csjl_bind, dll[["name"]])
  .cs$ready <- TRUE
  invisible(NULL)
}

# The Julia thread count from JULIA_NUM_THREADS: a count or "auto". A juliac
# library ignores the variable itself, so setup() passes it on. Anything after
# a comma (the interactive threadpool) is ignored.
.julia_threads <- function() {
  value <- sub(",.*", "", Sys.getenv("JULIA_NUM_THREADS", unset = ""))
  if (!nzchar(value)) {
    return(1L)
  }
  n <- if (value == "auto") {
    parallel::detectCores()
  } else {
    suppressWarnings(as.integer(value))
  }
  if (is.na(n) || n < 1L) {
    warning(
      "Ignoring JULIA_NUM_THREADS = \"",
      value,
      "\"; using one Julia thread.",
      call. = FALSE
    )
    return(1L)
  }
  n
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

.onLoad <- function(libname, pkgname) {
  tryCatch(setup(), error = function(e) NULL)
}

#' @importFrom Rdpack reprompt
#' @useDynLib CausalStructures, .registration = TRUE, .fixes = "C_"
NULL
