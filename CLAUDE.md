# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with
code in this repository.

## What this is

`CausalStructures` is an R package that binds to the Julia package
[CausalStructures.jl](https://github.com/BjarkeHautop/CausalStructures.jl) for
representing, validating, and reasoning about causal graphs (DAG, UG, PDAG,
CPDAG, MPDAG, ADMG, AG, MAG, PAG, UNKNOWN). CausalStructures.jl is compiled with
`juliac --trim=safe` into a shared library by
[jlbind](https://github.com/BjarkeHautop/jlbind) (users build it with
`jlbind::install_library()`), and every user-facing R function is a single call
into that library --- the actual algorithms live in the Julia package, not in
this repo. There is no embedded Julia session at run time.

## Common commands

```sh
# Build the compiled library for development (needs Julia >= 1.13 on the PATH
# and jlbind installed) into .jlbind/, which pkgload::load_all() uses instead of
# the one jlbind::install_library() makes, and rebuilds when inst/julia/ changes.
Rscript -e 'jlbind::build_library()'

# ... against a local CausalStructures.jl checkout instead of the release
Rscript -e 'jlbind::build_library(develop = "../CausalStructures.jl")'

# ... with the newest dependency versions [compat] allows, ignoring the manifest
Rscript -e 'jlbind::build_library(versions = "compat")'

# Report on Julia, the library and the packages bound to it
Rscript -e 'jlbind::jlbind_sitrep()'

# After adding, removing or changing the arguments of an @rcall declaration,
# regenerate R/jlbind-wrappers.R
Rscript -e 'jlbind::update_entrypoints()'

# Update the shipped manifest (e.g. for a new CausalStructures.jl release);
# resolve with the Julia version the package requires, then rebuild and test.
# Project.toml's [sources] points JLBind at jlbind's GitHub repo so Pkg can
# resolve this environment; builds strip that and use the installed jlbind's
# copy of JLBind instead. Pkg.update() moves every dependency to its newest
# version; to bump one, use Pkg.add(name = "CausalStructures", version = "x.y.z")
# and raise its [compat] entry.
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

# Re-render README.md from README.qmd after editing README.qmd
Rscript -e 'devtools::build_readme()'

# Build the documentation site locally into docs/ (quartodown, a Quarto website
# styled like pkgdown; function groups live in _quartodown/_quartodown.yml), then preview it
Rscript -e 'quartodown::build_site()'
Rscript -e 'quartodown::preview_site()'
```

Tests that need the compiled library call `skip_if_no_julia()` (see
`tests/testthat/helper-julia.R`) and are skipped otherwise. `julia_ready()`
checks that the library loads.

Pre-commit hooks (`.pre-commit-config.yaml`) enforce: `air` formatting,
`jarl`/`panache` linting, README.md being newer than README.qmd, and roxygen
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
  updating any such package means rebuilding. The package has no install
  function of its own: users call `jlbind::install_library()` directly.
- Installing the package builds nothing, so it installs (and passes CRAN's
  checks) without Julia; then every function errors, `julia_ready()` is `FALSE`,
  and examples and tests skip. CRAN's policy forbids downloading software and
  writing to the home directory (`~/.julia`) during installation.
- `.onLoad` calls `jlbind::bind_client(pkgname)`, which loads the library (once
  per process, setting the Julia thread count from `JULIA_NUM_THREADS` first)
  and binds this package's routines to it, if the library was built from this
  version of the package. `julia_ready()` is `jlbind::is_bound()`; a routine
  called while unbound errors and points to `jlbind::check_bound()`, which says
  why the library is unavailable. `JLBIND_LIBRARY` overrides the library path;
  CI builds with `jlbind::build_library()` and sets it.
- `inst/julia/Manifest.toml` is committed and shipped, so a package version
  builds against the dependency versions it was tested with: under
  `--trim=safe`, a dependency release that adds a dynamic call would otherwise
  break every user's build at once. jlbind starts the combined build from it
  (keeping its versions where the other packages' bounds allow, and reporting
  any it could not); `jlbind::install_library(versions = "compat")` resolves the
  newest versions `[compat]` allows instead.
- The library links against the runtime of the Julia that built it, so if that
  Julia is removed (e.g. by a juliaup update), loading fails and
  `jlbind::check_bound()` says to run `jlbind::install_library(force = TRUE)`.
- `.jlbind/` is the development build output of `jlbind::build_library()`:
  gitignored and in `.Rbuildignore`.

### The binding package (`inst/julia/`)

This is the code to read first for anything touching the R<->Julia boundary.

- `src/csjl.jl` (module `csjl`) uses JLBind: its `@rcall f(a::T, ...)::R`
  exports `SEXP csjl_f(SEXP *args, int n)` (checking the argument count itself),
  converting each argument with `from_sexp(T, a)`, calling `f`, and converting
  the result with `to_sexp`. `SEXP` passes an R object built in place through
  unchanged (`edges`, `jl_edge_marks`, `jl_simulate_data`, built with JLBind's
  `protect`, `alloc`, `mkchar`, ...).
- `jlbind::update_entrypoints()` writes an R function per `@rcall` into
  `R/jlbind-wrappers.R`, with the `#'` comments directly above the `@rcall`. A
  function that needs no R code is named as in R and exported from there
  (`#' @rdname node-queries` and `#' @export` above `@rcall parents(...)`); the
  help page itself stays in `R/`, on `NULL`, and the `@rcall` argument names are
  the public R argument names. A function that needs R code (coercion, a
  `getOption()` default, `match.arg()`) is `@rcall jl_name(...)`, called by a
  hand-written `name()`. Julia calls R's C API directly: the library is loaded
  into the R process.
- A graph crosses into R by reference: `GraphRef = RRef{CausalGraph}`, an
  external pointer of class `cgraph` (`JLBind.r_class`) to a graph in JLBind's
  registry, released by its finalizer. A function receiving one takes
  `@nospecialize(g::CausalGraph)`: a call with an abstractly typed argument
  stays dynamic otherwise, which `--trim` rejects. Inside, it branches on the
  concrete class with `@on "name" g (DAG, ADMG) body` (or `ALL`), a wrapper of
  JLBind's `@narrow`. List only the classes the CausalStructures.jl function has
  methods for; other classes get a clean "not supported for a <class>" error.
- Errors never unwind through Julia frames: a Julia exception is caught in the
  entrypoint and returned as a character vector with class `jlbind_error`, which
  jlbind's call routine raises. Only the messages of common exception types
  (`ArgumentError`, `ErrorException`, ...) are passed on, since rendering an
  arbitrary exception is a dynamic call `--trim` rejects.
- `--trim=safe` pitfalls already hit here (still so on Julia 1.13 and nightly
  1.15): an abstractly typed argument without `@nospecialize` (see above),
  splatting a vector into varargs (call the vector method instead, as for
  `add_edges`; applying items one at a time is wrong too, since every
  intermediate graph is validated), `nameof(typeof(g))` on an abstract graph
  (use `_class_name`), and a type passed as a keyword argument (`class = T`,
  inlined with `@inline` in `_generate`). Any number of `Union{Nothing,T}`
  arguments is fine: `@rcall` branches on each.
- A function of two graphs narrows both, nesting `@on`
  (`@on "f" g1 (DAG,   PDAG) @on "f" g2 (DAG, PDAG) body`); keep the pairs few,
  since each is compiled. `hd`/`shd` only read edges, so they compare both
  graphs as `UNKNOWN` (one specialization), and the s/c-metrics pair classes
  only within the same separation notion (`@on_same_separation`).
- A trim failure inside CausalStructures.jl itself (e.g. a boxed captured
  variable) is fixed there, with the call added to its `trim-check/entry.jl`,
  which only catches what it calls (keyword forms included).
- Adding a wrapped function: write the Julia function in `csjl.jl`, add an
  `@rcall` declaration (with its roxygen tags, or a `jl_` prefix and a
  hand-written R function calling `jl_name()`), and run
  `jlbind::update_entrypoints()` and `roxygen2::roxygenise()`. Then rebuild the
  library (and reload). A function defined in an `@eval` loop builds its name
  there, so keep that in step with the `@rcall`.

### Calling the library (no compiled code here)

- The package is pure R: it has no `src/`. `R/jlbind-wrappers.R` lists the
  entrypoint names (`.jlbind_entries`) and each wrapper calls
  `.External(.jlbind$.call, .jlbind$<name>, args...)`. `jlbind::bind_client()`
  fills `.jlbind` with pointers to the library's `csjl_<name>` functions and
  `.call` with jlbind's own C routine, which passes the arguments on and raises
  a returned `jlbind_error` as an R error once the Julia call has returned, so
  no R wrapper needs to check results. A function called before binding errors
  instead of crashing. Fixes to how clients call the library ship with jlbind.

### The R side

- Exported functions are either the generated wrappers or hand-written functions
  calling a generated `jl_name()`.
- Calls are microsecond-scale, so R-side overhead matters: keep R code out of
  the hot path where possible (an R function layer costs about 300 ns), and
  `match.arg()` (about 3.5 µs) is skipped when the argument is missing
  (`x <- if (missing(x)) x[[1L]] else match.arg(x)`).
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
store, since a finalizer can run mid-call). It survives `saveRDS()` and the like
through JLBind's `r_saved_by`: `.jlbind_saved_state()` (`R/session.R`) gives the
plain R data it is saved as, only when saved, and `r_restore` in `csjl.jl`
rebuilds it on first use after loading. Query functions (`R/queries.R`,
`R/identification.R`) return plain R vectors, lists and data frames; transform
functions (`R/transform.R`) return new `cgraph`s. `R/data.R` covers simulating
data from a graph.

### Plotting (`R/plot.R`, `R/plot-compose.R`, `R/plot-options.R`, `R/plot-routing.R`, `R/layout.R`)

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
  random layouts get an explicit `StableRNG(seed)`: NetworkLayout's default RNG
  is a type only known at run time. Every seeded function uses `StableRNG`
  (`_rng`), so a seed gives the same result on every Julia version.
- Styling is composable: `cgraph_plot()` computes the layout and returns a
  `cgraph_plot` object, drawn only when printed (`cgraph_grob()` builds the
  grob). `cgraph_plot()` is the one documented entry point; `plot.cgraph()` is
  just `print(cgraph_plot(x, ...))`, so `plot(dag)` works. The verbs in
  `R/plot-compose.R` (`style_nodes()`, `style_edges()`, `style_labels()`,
  `label_nodes()`, `style_title()`) only record overrides on it --- per node,
  and per row of its `edges` --- which the renderer puts on top of the
  `plot_options()` defaults, later calls winning. There are deliberately no
  style-list arguments (`node_style =`, `by_edge`, ...): one way to style.
- The grid-graphics rendering (`cgraph_grob()` in `R/plot.R`, edge routing in
  `R/plot-routing.R`) is adapted from [caugi](https://github.com/) 's plotting
  code (see attribution comments in those files and `inst/COPYRIGHTS`) rather
  than written from scratch --- check there before assuming rendering behavior
  is bespoke to this package.
- `plot_options()`/`plot_default_options()` (`R/plot-options.R`) is a dedicated
  get/set/reset accessor for plot styling defaults (`node_style`, `edge_style`,
  `label_style`, `title_style`; the fields of the matching verbs), deliberately
  kept separate from base `options()` since it's a nested graphics-parameter
  list rather than a flat behavioral toggle.

### Documentation site

Built by quartodown from README, man/ and `vignettes/` (all `.Rbuildignore`d, so
site-only). `vignettes/CausalStructures.qmd` is the "Get started" page, and
`vignettes/articles/` holds the guides, mostly ported from CausalStructures.jl's
`docs/src/` (Documenter `!!! note` admonitions become Quarto callouts, `@cite`
keys resolve against `vignettes/articles/references.bib`). The navbar's article
order is set in `_quartodown/_quartodown.yml`.

## File organization

`DESCRIPTION`'s `Collate:` field defines load order (`session.R` first); keep
new files added to `R/` there if load order matters.
