# Build the compiled CausalStructures.jl library

Compiles CausalStructures.jl with your Julia (\>= 1.13) into the shared
library that every function of the package calls. Run it once after
installing or updating CausalStructures, and again (with `force = TRUE`)
if the Julia it was built with is removed, for example by a `juliaup`
update.

## Usage

``` r
install_backend(
  julia = NULL,
  ask = interactive(),
  force = FALSE,
  update = FALSE,
  project = NULL
)
```

## Arguments

- julia:

  Path to the `julia` binary to build with. Defaults to the `JULIA`
  environment variable, else `julia` on the `PATH`.

- ask:

  Ask for confirmation before building? Defaults to
  [`interactive()`](https://rdrr.io/r/base/interactive.html).

- force:

  Rebuild even if a library for this version of CausalStructures already
  exists? Implied by `update` and `project`.

- update:

  Use the newest dependency versions the `Project.toml` allows instead
  of those in its `Manifest.toml`?

- project:

  Path to a directory with the `Project.toml` (and optionally a
  `Manifest.toml`) to build from, instead of the shipped ones.

## Value

The path to the library, invisibly.

## Details

Julia downloads CausalStructures.jl and its dependencies into its
package depot (`~/.julia` unless `JULIA_DEPOT_PATH` says otherwise) and
compiles them, which takes several minutes. The library is written to a
directory per package version under
`tools::R_user_dir("CausalStructures", "data")`, and libraries built for
other versions are removed from there.

By default the dependencies are the exact versions in the
`Manifest.toml` shipped with this version of CausalStructures, which are
the versions it was tested with. `update = TRUE` instead uses the newest
versions the shipped `Project.toml` allows, e.g. to get a
CausalStructures.jl bug fix before the next release of this package.
`project` builds from your own Julia environment: start from a copy of
`system.file("julia", "Project.toml", package = "CausalStructures")`,
keep its name, UUID and dependencies, and change e.g. the `[compat]`
bounds, or add a `[sources]` section to use a development version of
CausalStructures.jl.

Julia can only be started once per R process, so a library that replaces
one already loaded is used from the next R session on.

## Examples

``` r
if (FALSE) { # \dontrun{
install_backend()

# The newest CausalStructures.jl release, instead of the tested one
install_backend(update = TRUE)
} # }
```
