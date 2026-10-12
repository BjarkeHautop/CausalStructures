#' Build the compiled CausalStructures.jl library
#'
#' Compiles CausalStructures.jl with your Julia (>= 1.13) into the shared
#' library that every function of the package calls. Run it once after
#' installing or updating CausalStructures, and again (with `force = TRUE`) if
#' the Julia it was built with is removed, for example by a `juliaup` update.
#'
#' The library is built by 'jlbind' ([jlbind::install_backend()]), which
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
#' before the next release of this package.
#'
#' Julia can only be started once per R process, so a library that replaces
#' one already loaded is used from the next R session on.
#'
#' @inheritParams jlbind::install_backend
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
  update = FALSE
) {
  jlbind::install_backend(
    julia = julia,
    ask = ask,
    force = force,
    update = update
  )
}
