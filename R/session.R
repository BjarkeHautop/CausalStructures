# Design notes:
# - CausalStructures.jl is compiled with juliac into the `csjl` shared library
#   by install_backend() (R/install.R), which runs the installed package's
#   `julia/build.jl` with the user's Julia; the library links against that
#   Julia's runtime. setup() loads it with dyn.load(); there is no Julia
#   session to start and nothing to precompile.
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
#' the installed package's `csjl` directory (a development build), then where
#' [install_backend()] builds it.
#'
#' @name CausalStructures_options
NULL

.library_file <- function() {
  ext <- switch(
    Sys.info()[["sysname"]],
    Darwin = ".dylib",
    Windows = ".dll",
    ".so"
  )
  paste0("csjl", ext)
}

# Where install_backend() builds the library: one directory per package version,
# so a library built for another version, whose entrypoints may differ from
# this version's src/entrypoints.h, is never loaded.
.user_library_root <- function() {
  file.path(tools::R_user_dir("CausalStructures", "data"), "csjl")
}

.user_library_dir <- function() {
  file.path(
    .user_library_root(),
    as.character(utils::packageVersion("CausalStructures"))
  )
}

.library_path <- function() {
  override <- Sys.getenv("CAUSALSTRUCTURES_LIBRARY", unset = "")
  if (nzchar(override)) {
    return(override)
  }
  # A development build: `julia inst/julia/build.jl inst/csjl`.
  dev <- system.file("csjl", .library_file(), package = "CausalStructures")
  if (nzchar(dev)) {
    return(dev)
  }
  file.path(.user_library_dir(), .library_file())
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
      "The compiled CausalStructures.jl library was not found. Run ",
      "install_backend() to build it (this needs Julia >= 1.13).",
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
        "Run install_backend(force = TRUE) in a new R session to rebuild it.\n",
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

# A seed for the library's RNG, or `NULL` for an unseeded one.
make_rng <- function(seed) {
  if (is.null(seed)) NULL else as.numeric(seed)
}

.onLoad <- function(libname, pkgname) {
  tryCatch(setup(), error = function(e) NULL)
}

.onAttach <- function(libname, pkgname) {
  if (!isTRUE(.cs$ready)) {
    packageStartupMessage(
      "The compiled CausalStructures.jl library is not available. Run ",
      "install_backend() to build it, or setup() for details."
    )
  }
}

#' @importFrom Rdpack reprompt
#' @useDynLib CausalStructures, .registration = TRUE, .fixes = "C_"
NULL
