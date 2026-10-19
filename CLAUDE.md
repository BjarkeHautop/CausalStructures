# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with
code in this repository.

## What this is

`CausalStructures` is an R package that binds to the Julia package
[CausalStructures.jl](https://github.com/BjarkeHautop/CausalStructures.jl) for
representing, validating, and reasoning about causal graphs (DAG, UG, PDAG,
CPDAG, MPDAG, ADMG, AG, MAG, PAG, UNKNOWN). CausalStructures.jl is compiled with
`juliac --trim=safe` into a shared library by
[jlbind](https://github.com/BjarkeHautop/jlbind) (`install_backend()` wraps
`jlbind::install_library()`), and every user-facing R function is a single
`.Call` into that library --- the actual algorithms live in the Julia package,
not in this repo. There is no embedded Julia session at run time.

## Common commands

```sh
# Build the compiled library for development (needs Julia >= 1.13 on the PATH
# and jlbind installed) into .jlbind/, which pkgload::load_all() uses instead of
# the one install_backend() makes, and rebuilds when inst/julia/ changes.
Rscript -e 'jlbind::build_library()'

# ... against a local CausalStructures.jl checkout instead of the release
Rscript -e 'jlbind::build_library(develop = "../CausalStructures.jl")'

# ... with the newest dependency versions [compat] allows, ignoring the manifest
Rscript -e 'jlbind::build_library(versions = "compat")'

# Report on Julia, the library and the packages bound to it
Rscript -e 'jlbind::jlbind_sitrep()'

# After adding, removing or changing the arguments of an @rcall declaration,
# regenerate src/entrypoints.h and R/jlbind-wrappers.R
Rscript -e 'jlbind::update_entrypoints()'

# Update the shipped manifest (e.g. for a new CausalStructures.jl release);
# resolve with the Julia version the package requires, then rebuild and test.
# JLBind is not in the manifest (jlbind supplies it), so develop it into a
# throwaway copy of the environment if Pkg asks for it.
julia --startup-file=no --project=inst/julia -e 'import Pkg; Pkg.update()'

# Run the full test suite
Rscript -e 'pkgload::load_all("."); testthat::test_dir("tests/testthat")'

# Run a single test file
Rscript -e 'pkgload::load_all("."); testthat::test_file("tests/testthat/test-julia.R")'

# Regenerate roxygen docs (NAMESPACE + man/) after touching R/ or roxygen comments
Rscript -e 'roxygen2::roxygenise()'

# Full R CMD check. Installing does not build the library, so point the check
# at a build (as CI does), or the tests and examples needing it are skipped.
JLBIND_LIBRARY=$PWD/.jlbind/jlbind.so Rscript -e 'devtools::check()'

# Re-knit README.md from README.Rmd after editing README.Rmd
Rscript -e 'devtools::build_readme()'

# Build the documentation site locally into docs/ (altdown, an altdoc/Quarto
# theme styled like pkgdown; function groups live in altdoc/altdown.yml), then
# preview it
Rscript -e 'altdown::build_site(freeze = FALSE)'
Rscript -e 'altdoc::preview_docs()'
```

Tests that need the compiled library call `skip_if_no_julia()` (see
`tests/testthat/helper-julia.R`) and are skipped otherwise. `julia_ready()`
checks that the library loads.

Pre-commit hooks (`.pre-commit-config.yaml`) enforce: `air` formatting,
`jarl`/`panache` linting, README.md being newer than README.Rmd, and roxygen
docs being up to date (`roxygen2::needs_roxygenize()` must be `FALSE`) --- run
`roxygen2::roxygenise()` before committing if you touched `R/`, `DESCRIPTION`,
`NAMESPACE`, or `man/`.

## Architecture

### Building and loading the library (jlbind)

The generic machinery lives in the jlbind R package (and its Julia package
JLBind); see its `DESIGN.md`. In short:

- An R process can run only one juliac library, so jlbind compiles the binding
  packages of every installed package that uses it (a `Config/jlbind` field in
  `DESCRIPTION`; here `julia`, i.e. `inst/julia`) into one library, with the
  user's Julia, into `tools::R_user_dir("jlbind", "data")`. Installing or
  updating any such package means rebuilding. `install_backend()` here just
  calls `jlbind::install_library()` (`update = TRUE` is `versions = "compat"`).
- Installing the package builds nothing, so it installs (and passes CRAN's
  checks) without Julia; then every function errors, `julia_ready()` is `FALSE`,
  and examples and tests skip. CRAN's policy forbids downloading software and
  writing to the home directory (`~/.julia`) during installation.
- `.onLoad` calls `jlbind::bind_client(pkgname)`, which loads the library (once
  per process, setting the Julia thread count from `JULIA_NUM_THREADS` first)
  and binds this package's routines to it, if the library was built from this
  version of the package. `julia_ready()` is `jlbind::is_bound()`, `setup()` is
  `jlbind::check_bound()` (an error saying why the library is unavailable).
  `JLBIND_LIBRARY` overrides the library path; CI builds with
  `jlbind::build_library()` and sets it.
- `inst/julia/Manifest.toml` is committed and shipped, so a package version
  builds against the dependency versions it was tested with: under
  `--trim=safe`, a dependency release that adds a dynamic call would otherwise
  break every user's build at once. jlbind starts the combined build from it
  (keeping its versions where the other packages' bounds allow, and reporting
  any it could not); `install_backend(update = TRUE)` resolves the newest
  versions `[compat]` allows instead.
- The library links against the runtime of the Julia that built it, so if that
  Julia is removed (e.g. by a juliaup update), loading fails and `setup()` says
  to run `install_backend(force = TRUE)`.
- `.jlbind/` is the development build output of `jlbind::build_library()`:
  gitignored and in `.Rbuildignore`.

### The binding package (`inst/julia/`)

This is the code to read first for anything touching the R<->Julia boundary.

- `csjl.jl` (module `csjl`) uses JLBind: its `@rcall f(a::T, ...)::R` exports
  `csjl_f_<nargs>(a::SEXP, ...)::SEXP`, converting each argument with
  `from_sexp(T, a)`, calling `f`, and converting the result with `to_sexp`.
  `SEXP` passes an R object built in place through unchanged (`jl_edges`,
  `jl_edge_marks`, `jl_simulate_data`, built with JLBind's `protect`, `alloc`,
  `mkchar`, ...).
- Every entrypoint is named `jl_<R function>`. `jlbind::update_entrypoints()`
  also writes an R function per `@rcall` into `R/jlbind-wrappers.R`; the prefix
  keeps those from clashing with the hand-written exported functions, which call
  the routines directly (`.Call(C_jl_name, ...)`) and leave the generated ones
  unused. Julia calls R's C API directly: the library is loaded into the R
  process.
- A graph crosses into R by reference: `GraphRef = RRef{CausalGraph}`, an
  external pointer of class `cgraph` (`JLBind.r_class`) to a graph in JLBind's
  registry, released by its finalizer. A function receiving one takes
  `@nospecialize(g::CausalGraph)`: a call with an abstractly typed argument
  stays dynamic otherwise, which `--trim` rejects. Inside, it branches on the
  concrete class with `@on "name" g (DAG, ADMG) body` (or `ALL`). List only the
  classes the CausalStructures.jl function has methods for; other classes get a
  clean "not supported for a <class>" error.
- Errors never unwind through Julia frames: a Julia exception is caught in the
  entrypoint and returned as a character vector with class `jlbind_error`, which
  the shim in `src/` raises. Only the messages of common exception types
  (`ArgumentError`, `ErrorException`, ...) are passed on, since rendering an
  arbitrary exception is a dynamic call `--trim` rejects.
- `--trim=safe` pitfalls already hit here: an abstractly typed argument without
  `@nospecialize` (see above), splatting a vector into varargs (use `_fold`),
  `nameof(typeof(g))` on an abstract graph (use `_class_name`), more than two
  `Union{T,Nothing}` arguments in one call (take raw `SEXP` and convert inside,
  as `jl_generate_graph` does), and a type passed as a keyword argument
  (`class = T`, inlined with `@inline` in `_generate`).
- Adding a wrapped function: write the Julia function `jl_name` in `csjl.jl`,
  add an `@rcall` declaration, run `jlbind::update_entrypoints()`, and call it
  from the R wrapper as `.Call(C_jl_name, ...)`. Then rebuild the library (and
  reload, which recompiles `src/`).

### The registration shim (`src/`, generated by jlbind)

- `src/jlbind.c` (from `jlbind::use_jlbind()`) registers one `.Call` routine
  `C_<name>` per entry of `src/entrypoints.h` (from
  `jlbind::update_entrypoints()`), each forwarding to the library's
  `csjl_<name>_<nargs>` through a function pointer that `jlbind::bind_client()`
  resolves once the library is loaded. `src/Makevars` recompiles `jlbind.o` when
  `entrypoints.h` changes. A routine called before that raises an error instead
  of crashing; a returned `jlbind_error` is raised as an R error once the Julia
  call has returned, so no R wrapper needs to check results.
- This keeps every `.Call` in `R/` a registered routine of the package itself,
  so `R CMD check`'s foreign-function checks pass without workarounds.

### The R side

- Exported functions are a direct `.Call(C_jl_name, ...)`.
- Calls are microsecond-scale, so R-side overhead matters: avoid extra wrapper
  layers on the hot path, and `match.arg()` (about 3.5 µs) is skipped when the
  argument is missing (`x <- if (missing(x)) x[[1L]] else match.arg(x)`).
- Node sets go in and come out as character vectors. Results with no set come
  back as `NULL`; nested results (`all_backdoor_sets()`,
  `possible_joint_parent_sets()`, ...) come back as R lists built library-side.

### The edge-operator DSL (`R/dsl.R`, `R/construction.R`)

`cgraph(A %-->% X + Y, X %-->% M %-->% Y)` uses custom infix operators (`%-->%`,
`%<--%`, `%---%`, `%<->%`, `%o->%`, etc., listed in `.edge_glyphs`) that are
never evaluated --- `...` is captured unevaluated and walked as an unevaluated
call tree (`.is_edge_call`, `.is_node_expr`, `.contains_edge`), then translated
into `CausalStructures.jl`'s own string DSL (e.g.
`"A --> X + Y, X --> M --> Y"`). `cgraph(spec = "...")` bypasses the operator
DSL entirely for programmatic construction from a spec string built at runtime.
Note the custom-operator precedence gotcha documented at the top of `dsl.R`:
`%any%` operators bind tighter than `+`, so `A %-->% B + C` parses as
`(A %-->% B) + C`.

### Graph objects

A causal graph is an R external pointer with S3 class `"cgraph"`, created by the
library: its address is the graph's registry handle, and a C finalizer releases
the library's copy when R collects it (the release is deferred to the next graph
store, since a finalizer can run mid-call). Query functions (`R/queries.R`,
`R/identification.R`) return plain R vectors, lists and data frames; transform
functions (`R/transform.R`) return new `cgraph`s. `R/data.R` covers simulating
data from a graph.

### Plotting (`R/plot.R`, `R/plot-options.R`, `R/plot-routing.R`, `R/layout.R`)

- `cgraph_layout()` (`R/layout.R`) computes node positions. `"sugiyama"` is the
  library's `jl_sugiyama_layout` entrypoint, which calls
  [Sugiyama.jl](https://github.com/BjarkeHautop/Sugiyama.jl) directly on the
  adjacency matrix (every edge as `src -> dst`, so any class works) rather than
  through CausalStructures.jl's `layout()`, whose `Val(method)` dispatch and
  forwarded `kwargs...` `--trim` rejects. `plot()` uses the `jl_sugiyama_paths`
  entrypoint instead (Sugiyama.jl's `sugiyama_paths`), which also returns each
  edge's route through its bend points, drawn as an explicit edge `path` as in
  CausalStructures.jl; node pairs with parallel edges get no route, so they
  still fan out. The other methods (`"stress"`, `"spring"`, `"sfdp"`,
  `"spectral"`, `"shell"`, `"squaregrid"`, as in CausalStructures.jl) are the
  `jl_network_layout` entrypoint, calling
  [NetworkLayout.jl](https://github.com/JuliaGraphs/NetworkLayout.jl) on the
  undirected adjacency matrix. Released NetworkLayout.jl does not compile under
  `--trim`, so `inst/julia/Project.toml` takes it from the `trim-compat` branch
  of BjarkeHautop/NetworkLayout.jl (`[sources]`, pinned in the manifest). The
  random layouts get an explicit `MersenneTwister(seed)`: NetworkLayout's
  default RNG is a type only known at run time.
- The grid-graphics rendering (`plot.cgraph()` in `R/plot.R`, edge routing in
  `R/plot-routing.R`) is adapted from [caugi](https://github.com/) 's plotting
  code (see attribution comments in those files and `inst/COPYRIGHTS`) rather
  than written from scratch --- check there before assuming rendering behavior
  is bespoke to this package.
- `plot_options()`/`plot_default_options()` (`R/plot-options.R`) is a dedicated
  get/set/reset accessor for plot styling defaults (`node_style`, `edge_style`,
  `label_style`, `title_style`), deliberately kept separate from base
  `options()` since it's a nested graphics-parameter list rather than a flat
  behavioral toggle.

### Warmup (`R/warmup.R`)

`warmup()` calls every exported wrapper once on small graphs. The library is
compiled ahead of time, so there is no JIT to warm up; it now serves as a quick
smoke test of the whole API.

## File organization

`DESCRIPTION`'s `Collate:` field defines load order (`session.R` first); keep
new files added to `R/` there if load order matters.
