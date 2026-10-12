# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with
code in this repository.

## What this is

`CausalStructures` is an R package that binds to the Julia package
[CausalStructures.jl](https://github.com/BjarkeHautop/CausalStructures.jl) for
representing, validating, and reasoning about causal graphs (DAG, UG, PDAG,
CPDAG, MPDAG, ADMG, AG, MAG, PAG, UNKNOWN). CausalStructures.jl is compiled with
`juliac --trim=safe` into a shared library by `install_backend()`, and every
user-facing R function is a single `.Call` into that library --- the actual
algorithms live in the Julia package, not in this repo. There is no embedded
Julia session at run time.

## Common commands

```sh
# Build the compiled library for development (needs Julia >= 1.13 on the PATH).
# Do this once, and again after changing anything in inst/julia/; setup()
# prefers a build in inst/csjl over the one install_backend() makes.
julia --startup-file=no inst/julia/build.jl inst/csjl

# ... against a local CausalStructures.jl checkout instead of the release
CAUSALSTRUCTURES_JL_PATH=../CausalStructures.jl \
  julia --startup-file=no inst/julia/build.jl inst/csjl

# ... with the newest dependency versions [compat] allows, ignoring the manifest
julia --startup-file=no inst/julia/build.jl inst/csjl --update

# Update the shipped manifest (e.g. for a new CausalStructures.jl release);
# resolve with the Julia version the package requires, then rebuild and test
julia --startup-file=no --project=inst/julia -e 'import Pkg; Pkg.update()'

# Run the full test suite
Rscript -e 'pkgload::load_all("."); testthat::test_dir("tests/testthat")'

# Run a single test file
Rscript -e 'pkgload::load_all("."); testthat::test_file("tests/testthat/test-julia.R")'

# Regenerate roxygen docs (NAMESPACE + man/) after touching R/ or roxygen comments
Rscript -e 'roxygen2::roxygenise()'

# Full R CMD check. Installing does not build the library, so point the check
# at a build (as CI does), or the tests and examples needing it are skipped.
CAUSALSTRUCTURES_LIBRARY=$PWD/inst/csjl/csjl.so Rscript -e 'devtools::check()'

# Re-knit README.md from README.Rmd after editing README.Rmd
Rscript -e 'devtools::build_readme()'

# Build pkgdown site locally
Rscript -e 'pkgdown::build_site(devel = TRUE)'
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

### Building the library (`install_backend()`, `inst/julia/`)

- Installing the package builds nothing, so it installs (and passes CRAN's
  checks) without Julia; then every function errors, `julia_ready()` is `FALSE`,
  and examples and tests skip. CRAN's policy forbids downloading software and
  writing to the home directory (`~/.julia`) during installation, which an
  install-time build needs; a function the user calls explicitly may.
- `install_backend()` (`R/install.R`) finds Julia (`julia` argument, `$JULIA`,
  else `julia` on the PATH), requires >= 1.13, asks for confirmation when
  interactive, and runs the installed package's `julia/build.jl` in a child
  process. It writes `csjl.so` (`.dylib` on macOS, `.dll` on Windows) to
  `tools::R_user_dir("CausalStructures", "data")/csjl/<package version>/`, so a
  library built for another version (whose entrypoints may not match
  `src/entrypoints.h`) is never loaded; other versions' directories are pruned.
  It builds into a temporary sibling directory and renames it into place (a
  loaded DLL cannot be deleted on Windows but can be renamed), then loads it
  with `setup()`, unless a library is already loaded: Julia can only start once
  per process, so a rebuild is used from the next session.
- `setup()` looks for the library in `CAUSALSTRUCTURES_LIBRARY`, then
  `system.file("csjl")` (a development build in `inst/csjl`), then the
  `install_backend()` directory. CI builds with `build.jl` directly and sets
  `CAUSALSTRUCTURES_LIBRARY`.
- `inst/julia/build.jl` mirrors CausalStructures.jl's own `trim-check`: it
  instantiates the binding project (`inst/julia/Project.toml`, CausalStructures
  from the General registry, or `CAUSALSTRUCTURES_JL_PATH` via `Pkg.develop`) in
  a scratch copy, then compiles it from a separate temporary environment (so
  JuliaC is never compiled into the library) with JuliaC's recipe API: the
  equivalent of `--output-lib --trim=safe --experimental --compile-ccallable`,
  plus the C source `set_threads.c`, which the JuliaC CLI cannot add.
- `inst/julia/Manifest.toml` is committed and shipped, so a package version
  always builds against the dependency versions it was tested with: under
  `--trim=safe`, a dependency release that adds a dynamic call would otherwise
  break every user's build at once. `install_backend(update = TRUE)`
  (`--update`) resolves the newest versions `[compat]` allows instead, and
  `install_backend(project = dir)` (`--project=dir`) builds from a user's own
  `Project.toml`/`Manifest.toml` (same name, UUID and deps; e.g. a `[sources]`
  entry for a development CausalStructures.jl). If the manifest fails to
  instantiate (resolved with another Julia version), `build.jl` warns and
  resolves from `[compat]`. Copies are `chmod`ed writable, since an installed
  package's files may be read-only.
- The library links against the runtime of the Julia that built it (its RUNPATH
  points there), so nothing is bundled. If that Julia is removed (e.g. by a
  juliaup update), loading fails and `setup()` tells the user to run
  `install_backend(force = TRUE)`.
- `install_backend()` unsets `LD_LIBRARY_PATH` for the build: R puts its own
  library directories on it, which otherwise makes Julia's bundled tools (Pkg's
  `zstd`) load the system libraries instead of Julia's.
- A juliac library fixes its Julia options when compiled (one thread, Julia
  signal handling off) and ignores `JULIA_NUM_THREADS`
  ([JuliaC.jl#152](https://github.com/JuliaLang/JuliaC.jl/issues/152)).
  `set_threads.c` (adapted from Ribasim) exports `csjl_set_julia_threads`, which
  sets `jl_options` before Julia initializes; `setup()` calls it through the
  shim's `C_csjl_set_threads` after `dyn.load()` and before the first
  entrypoint, from `JULIA_NUM_THREADS` (a count or `"auto"`). More than one
  thread turns on Julia's signal handling, which multi-threaded GC needs.
- `inst/csjl/` is development build output: gitignored and in `.Rbuildignore`.
- Windows: a DLL has no RUNPATH, so `build.jl` records Julia's `Sys.BINDIR` in
  `julia_bindir` next to `csjl.dll` and `setup()` prepends it to the `PATH`
  before `dyn.load()`. A `ccall` without a library only searches Julia's own
  DLLs on Windows, so `rapi.jl` names every R symbol with `@R(sym)`, which adds
  `"R.dll"` there (and `@r_global(sym)` for R's global SEXPs).

### The binding layer (`inst/julia/src/`)

This is the code to read first for anything touching the R<->Julia boundary.

- `rapi.jl` is generic: Julia calls R's C API directly (the library is loaded
  into the R process, so `ccall(:Rf_allocVector, ...)` etc. resolve against
  libR). It holds the `from_sexp`/`to_sexp` conversions, graphs as external
  pointers (`GraphHandle`), the `csjl_error` error object, a preserved cache of
  R strings per node name, and the `@rcall` macro.
- `@rcall f(a::T, ...)::R` exports `csjl_r_f(a::SEXP, ...)::SEXP`: it converts
  each argument with `from_sexp(T, a)`, calls `f`, and converts the result. A
  return type of `GraphHandle`/`Vector{GraphHandle}` makes the result a new
  `cgraph` (or a list of them); `SEXP` passes an R object built in place through
  unchanged (`edges`, `edge_marks`, `simulate_data`).
- Errors never unwind through Julia frames: a Julia exception is caught in the
  entrypoint and returned as a character vector with class `csjl_error`, which
  the shim in `src/` raises. `_error_message` only reads the message of the
  exception types CausalStructures throws, since rendering an arbitrary
  exception is a dynamic call `--trim` rejects. R itself only longjmps out of
  allocations, i.e. when out of memory.
- `csjl.jl` is CausalStructures-specific: a registry of graphs keyed by an
  integer handle, and one function plus one `@rcall` declaration per exported R
  function. Graph functions take `h::Int64` and branch on the concrete class
  with `@on "name" g (DAG, ADMG) body` (or `ALL`), because a graph read from the
  registry is only known as `CausalGraph` and `--trim` rejects the dynamic
  dispatch. List only the classes the CausalStructures.jl function has methods
  for; other classes get a clean "not supported for a <class>" error.
- `--trim=safe` pitfalls already hit here: splatting a vector into varargs (use
  `_fold`), `nameof(typeof(g))` on an abstract graph (use `_class_name`), more
  than two `Union{T,Nothing}` arguments in one call (take raw `SEXP` and convert
  inside, as `generate_graph` does), and a type passed as a keyword argument
  (`class = T`, inlined with `@inline` in `_generate`).
- Adding a wrapped function: write the Julia function in `csjl.jl`, add an
  `@rcall` declaration, add `CSJL_ENTRY(name, nargs)` to `src/entrypoints.h`,
  and call it from the R wrapper as `.Call(C_name, ...)`. Then rebuild the
  library (and reload, which recompiles `src/`). A wrong `nargs` shows up as R's
  "Incorrect number of arguments" error on the first call.

### The registration shim (`src/`)

- The package has its own small shared object, `CausalStructures.so`, loaded by
  `useDynLib(CausalStructures, .registration = TRUE, .fixes = "C_")`.
  `src/init.c` registers one `.Call` routine per line of `src/entrypoints.h` (an
  X-macro list), each forwarding to the library's `csjl_r_<name>` through a
  function pointer, plus `csjl_bind` and `csjl_set_threads`. A routine raises a
  returned `csjl_error` as an R error itself, once the Julia call has returned,
  so no R wrapper needs to check results.
- The csjl library cannot be linked into it (it is built by `install_backend()`
  against the user's Julia and loaded later by `setup()`), so `csjl_bind`
  resolves every pointer with `R_FindSymbol` once the library is loaded. A
  routine called before that raises an error instead of crashing.
- This keeps every `.Call` in `R/` a registered routine of the package itself,
  so `R CMD check`'s foreign-function checks pass without workarounds.

### The R side (`R/session.R`)

- `setup()` (also run from `.onLoad`) `dyn.load()`s the library, sets the Julia
  thread count (see above), and binds the shim's routines to it
  (`.Call(C_csjl_bind, ...)`). Exported functions are a direct
  `.Call(C_name, ...)`. The library path can be overridden with
  `CAUSALSTRUCTURES_LIBRARY`.
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
  library's `sugiyama_layout` entrypoint, which calls
  [Sugiyama.jl](https://github.com/BjarkeHautop/Sugiyama.jl) directly on the
  adjacency matrix (every edge as `src -> dst`, so any class works) rather than
  through CausalStructures.jl's `layout()`, whose `Val(method)` dispatch and
  forwarded `kwargs...` `--trim` rejects. `"stress"`, `"shell"` and
  `"squaregrid"` are plain R: NetworkLayout.jl does not compile under `--trim`,
  and causal graphs are small enough that dense-matrix R code is fast. Stress
  starts from classical MDS (`stats::cmdscale()`), so it needs no RNG and is
  deterministic.
- The grid-graphics rendering (`plot.cgraph()` in `R/plot.R`, edge routing in
  `R/plot-routing.R`) is adapted from [caugi](https://github.com/) 's plotting
  code (see attribution comments in those files and `inst/COPYRIGHTS`) rather
  than written from scratch --- check there before assuming rendering behavior
  is bespoke to this package.
- `plot_options()`/`plot_default_options()` (`R/plot-options.R`) is a dedicated
  get/set/reset accessor for plot styling defaults (`node_style`, `edge_style`,
  `label_style`, `title_style`, `tier_style`), deliberately kept separate from
  base `options()` since it's a nested graphics-parameter list rather than a
  flat behavioral toggle.

### Warmup (`R/warmup.R`)

`warmup()` calls every exported wrapper once on small graphs. The library is
compiled ahead of time, so there is no JIT to warm up; it now serves as a quick
smoke test of the whole API.

## File organization

`DESCRIPTION`'s `Collate:` field defines load order (`session.R` first); keep
new files added to `R/` there if load order matters.
