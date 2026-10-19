#' Build the compiled CausalStructures.jl library
#'
#' Compiles CausalStructures.jl with your Julia (>= 1.13) into the shared
#' library that every function of the package calls. Run it once after
#' installing or updating CausalStructures, and again (with `force = TRUE`) if
#' the Julia it was built with is removed, for example by a `juliaup` update.
#'
#' The library is built by 'jlbind' ([jlbind::install_library()]), which
#' compiles the Julia code of every installed package that uses it into one
#' library, since an R process can run only one: CausalStructures and any
#' such packages are built together. Julia downloads CausalStructures.jl and
#' its dependencies into its package depot (`~/.julia` unless
#' `JULIA_DEPOT_PATH` says otherwise) and compiles them, which takes several
#' minutes.
#'
#' By default the dependencies are the exact versions in the `Manifest.toml`
#' shipped with this version of CausalStructures, which are the versions it
#' was tested with. `update = TRUE` instead uses the newest versions the
#' shipped `Project.toml` allows, e.g. to get a CausalStructures.jl bug fix
#' before the next release of this package. `develop` builds with a local
#' checkout of CausalStructures.jl (or another Julia dependency) instead of
#' the release, e.g. to try a fix that is not released yet; run
#' `install_backend()` without it to go back to the release.
#'
#' Julia can only be started once per R process, so a library that replaces
#' one already loaded is used from the next R session on.
#'
#' @inheritParams jlbind::install_library
#' @param update If `TRUE`, ignore the shipped `Manifest.toml` and use the
#'   newest dependency versions the shipped `Project.toml` allows (jlbind's
#'   `versions = "compat"`). Always rebuilds.
#'
#' @return The path to the library (invisibly), or `NULL` if nothing was
#'   built.
#' @export
#' @examples
#' \dontrun{
#' install_backend()
#'
#' # The newest CausalStructures.jl release, instead of the tested one
#' install_backend(update = TRUE)
#'
#' # A local checkout of CausalStructures.jl
#' install_backend(develop = "~/dev/CausalStructures.jl")
#' }
install_backend <- function(
  julia = NULL,
  ask = interactive(),
  force = FALSE,
  update = FALSE,
  develop = NULL
) {
  jlbind::install_library(
    julia = julia,
    ask = ask,
    force = force,
    versions = if (isTRUE(update)) "compat" else "manifest",
    develop = develop
  )
}
