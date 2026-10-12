#' Build the compiled CausalStructures.jl library
#'
#' Compiles CausalStructures.jl with your Julia (>= 1.13) into the shared
#' library that every function of the package calls. Run it once after
#' installing or updating CausalStructures, and again (with `force = TRUE`) if
#' the Julia it was built with is removed, for example by a `juliaup` update.
#'
#' Julia downloads CausalStructures.jl and its dependencies into its package
#' depot (`~/.julia` unless `JULIA_DEPOT_PATH` says otherwise) and compiles
#' them, which takes several minutes. The library is written to a directory
#' per package version under `tools::R_user_dir("CausalStructures", "data")`,
#' and libraries built for other versions are removed from there.
#'
#' By default the dependencies are the exact versions in the `Manifest.toml`
#' shipped with this version of CausalStructures, which are the versions it
#' was tested with. `update = TRUE` instead uses the newest versions the
#' shipped `Project.toml` allows, e.g. to get a CausalStructures.jl bug fix
#' before the next release of this package. `project` builds from your own
#' Julia environment: start from a copy of
#' `system.file("julia", "Project.toml", package = "CausalStructures")`,
#' keep its name, UUID and dependencies, and change e.g. the `[compat]`
#' bounds, or add a `[sources]` section to use a development version of
#' CausalStructures.jl.
#'
#' Julia can only be started once per R process, so a library that replaces
#' one already loaded is used from the next R session on.
#'
#' @param julia Path to the `julia` binary to build with. Defaults to the
#'   `JULIA` environment variable, else `julia` on the `PATH`.
#' @param ask Ask for confirmation before building? Defaults to
#'   [interactive()].
#' @param force Rebuild even if a library for this version of
#'   CausalStructures already exists? Implied by `update` and `project`.
#' @param update Use the newest dependency versions the `Project.toml` allows
#'   instead of those in its `Manifest.toml`?
#' @param project Path to a directory with the `Project.toml` (and optionally
#'   a `Manifest.toml`) to build from, instead of the shipped ones.
#'
#' @return The path to the library, invisibly.
#' @export
#' @examples
#' \dontrun{
#' install_backend()
#'
#' # The newest CausalStructures.jl release, instead of the tested one
#' install_backend(update = TRUE)
#' }
install_backend <- function(
  julia = NULL,
  ask = interactive(),
  force = FALSE,
  update = FALSE,
  project = NULL
) {
  if (!is.null(project)) {
    project <- normalizePath(project, mustWork = FALSE)
    if (!file.exists(file.path(project, "Project.toml"))) {
      stop("No Project.toml found in ", project, ".", call. = FALSE)
    }
  }
  dir <- .user_library_dir()
  path <- file.path(dir, .library_file())
  if (file.exists(path) && !force && !update && is.null(project)) {
    message(
      "The CausalStructures.jl library is already built (",
      path,
      "); use `force = TRUE` to rebuild it."
    )
    if (!isTRUE(.cs$ready)) {
      setup()
    }
    return(invisible(path))
  }

  julia <- .find_julia(julia)
  if (isTRUE(ask)) {
    choice <- utils::menu(
      c("Yes", "No"),
      title = paste0(
        "Compile CausalStructures.jl with ",
        julia,
        "? Julia downloads CausalStructures.jl and its dependencies into ",
        "its package depot, and compiling takes several minutes. The ",
        "library is written to ",
        dir,
        "."
      )
    )
    if (choice != 1L) {
      message("Cancelled.")
      return(invisible(NULL))
    }
  }

  # Built next to its final place, so it is moved in with a rename, and only
  # once the build has succeeded.
  root <- .user_library_root()
  dir.create(root, recursive = TRUE, showWarnings = FALSE)
  out <- tempfile("build-", tmpdir = root)
  on.exit(unlink(out, recursive = TRUE), add = TRUE)
  .run_build(julia, out, update = update, project = project)
  if (!file.exists(file.path(out, .library_file()))) {
    stop("Compiling CausalStructures.jl failed; see the output above.")
  }

  # A loaded library cannot be deleted on Windows, but it can be renamed, so
  # the old build is moved aside first; whatever cannot be removed now is
  # pruned on the next build.
  if (dir.exists(dir)) {
    old <- tempfile("old-", tmpdir = root)
    if (!file.rename(dir, old)) {
      stop("Could not replace the library in ", dir, ".")
    }
  }
  if (!file.rename(out, dir)) {
    stop("Could not move the library into ", dir, ".")
  }
  for (stale in setdiff(list.files(root, full.names = TRUE), dir)) {
    unlink(stale, recursive = TRUE)
  }

  if (isTRUE(.cs$ready)) {
    message(
      "Built the CausalStructures.jl library. Restart R to use it in place ",
      "of the library loaded in this session."
    )
  } else {
    message("Built the CausalStructures.jl library.")
    setup()
  }
  invisible(path)
}

# The julia binary to build with, checked to be at least 1.13.
.find_julia <- function(julia = NULL) {
  if (is.null(julia)) {
    julia <- Sys.getenv("JULIA", unset = "")
    if (!nzchar(julia)) {
      julia <- unname(Sys.which("julia"))
    }
  }
  if (!nzchar(julia)) {
    stop(
      "Julia was not found. Install Julia (>= 1.13), see ",
      "https://julialang.org/install/, or pass the path of a julia binary ",
      "as `julia` (or set the JULIA environment variable).",
      call. = FALSE
    )
  }
  output <- suppressWarnings(tryCatch(
    system2(julia, "--version", stdout = TRUE, stderr = FALSE),
    error = function(e) character()
  ))
  version <- regmatches(output, regexpr("[0-9]+\\.[0-9]+\\.[0-9]+", output))
  if (length(version) == 0L) {
    stop("Could not run `", julia, " --version`.", call. = FALSE)
  }
  if (package_version(version[[1L]]) < "1.13") {
    stop(
      "CausalStructures needs Julia >= 1.13, but ",
      julia,
      " is version ",
      version[[1L]],
      ". With juliaup: `juliaup add 1.13`, then pass its julia binary as ",
      "`julia`.",
      call. = FALSE
    )
  }
  julia
}

# Runs the installed package's julia/build.jl, writing the library to `out`.
.run_build <- function(julia, out, update = FALSE, project = NULL) {
  script <- system.file("julia", "build.jl", package = "CausalStructures")
  # R puts its own library directories on LD_LIBRARY_PATH, which overrides
  # the RUNPATH of Julia's bundled tools and makes e.g. Pkg's zstd load the
  # system libzstd instead of Julia's.
  ld_path <- Sys.getenv("LD_LIBRARY_PATH", unset = NA)
  if (!is.na(ld_path)) {
    Sys.unsetenv("LD_LIBRARY_PATH")
    on.exit(Sys.setenv(LD_LIBRARY_PATH = ld_path), add = TRUE)
  }
  status <- system2(
    julia,
    c(
      "--startup-file=no",
      shQuote(script),
      shQuote(out),
      if (isTRUE(update)) "--update",
      if (!is.null(project)) shQuote(paste0("--project=", project))
    )
  )
  if (!identical(status, 0L)) {
    stop("Compiling CausalStructures.jl failed; see the output above.")
  }
  invisible(NULL)
}
