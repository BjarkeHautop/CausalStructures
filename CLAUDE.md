# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with
code in this repository.

## What this is

`CausalStructures` is an R package that binds to the Julia package
[CausalStructures.jl](https://github.com/BjarkeHautop/CausalStructures.jl) via
`JuliaCall`, for representing, validating, and reasoning about causal graphs
(DAG, UG, PDAG, CPDAG, MPDAG, ADMG, AG, MAG, PAG, UNKNOWN). Almost every
user-facing R function is a thin wrapper that marshals arguments to Julia, calls
into `CausalStructures.jl`, and unmarshals the result --- the actual algorithms
live in the Julia package, not in this repo.

## Common commands

```r
# Load package for interactive dev
pkgload::load_all(".")

# Run the full test suite
Rscript - e
'pkgload::load_all("."); testthat::test_dir("tests/testthat")'

# Run a single test file
Rscript - e
'pkgload::load_all("."); testthat::test_file("tests/testthat/test-julia.R")'

# Regenerate roxygen docs (NAMESPACE + man/) after touching R/ or roxygen comments
Rscript - e
'roxygen2::roxygenise()'

# Full R CMD check (mirrors CI)
Rscript - e
'devtools::check()'

# Re-knit README.md from README.Rmd after editing README.Rmd
Rscript - e
'devtools::build_readme()'

# Build pkgdown site locally
Rscript - e
'pkgdown::build_site(devel = TRUE)'
```

Tests that need a working Julia install call `skip_if_no_julia()` (see
`tests/testthat/helper-julia.R`) and are skipped otherwise --- `julia_ready()`
also runs `setup()` as a side effect the first time it's called, which can be
slow (Julia package precompilation).

Pre-commit hooks (`.pre-commit-config.yaml`) enforce: `air` formatting,
`jarl`/`panache` linting, README.md being newer than README.Rmd, and roxygen
docs being up to date (`roxygen2::needs_roxygenize()` must be `FALSE`) --- run
`roxygen2::roxygenise()` before committing if you touched `R/`, `DESCRIPTION`,
`NAMESPACE`, or `man/`.

## Architecture

### The Julia bridge (`R/session.R`)

This is the file to read first for anything touching the R↔Julia boundary.

- `setup()` lazily starts an embedded Julia session (via
  `JuliaCall::julia_setup()`), activates the Julia project shipped in `inst/`
  (`Project.toml` + `Manifest.toml`), installs/updates Julia deps if needed, and
  defines a block of Julia helper functions (`.helper_defs`) that get `eval`'d
  once. It's a do-once guard (`.cs$ready`) --- there's no teardown/restart,
  since JuliaCall doesn't support one and if the embedded Julia dies, so does R.
- Every exported R function that touches Julia goes through `fn(name)`, which
  calls `setup()` then looks up a caller closure in the `.cs` environment. Two
  families of wrapper are registered at setup time:
  - **`.helpers`**: functions with a hand-written `_CausalStructures_<name>`
    Julia wrapper in `.helper_defs`, needed to convert R args (character
    vectors) to Julia `Symbol`s/kwargs and coerce results back to plain,
    JuliaCall-auto-convertible types (`Vector{String}`, `Matrix`, scalars).
  - **`.passthrough`**: predicates and simple graph transforms called directly
    against `CausalStructures.<name>` with no wrapper needed (graph proxy in,
    `Bool` or graph proxy out).
- Adding a new wrapped Julia function means: add a `_CausalStructures_<name>`
  definition to `.helper_defs` (or just the bare name to `.passthrough` if no
  marshaling is needed), add the name to `.helpers`/`.passthrough`, and add the
  calling R function elsewhere in `R/` that invokes `fn("name")(...)`.
- **Nested "list of sets" results** (e.g. `all_backdoor_sets()`,
  `possible_optimal_adjustment_sets()`) don't auto-convert
  (`Vector{Vector{String}}` isn't a JuliaCall-native type), so they're joined
  into a single marker-delimited string Julia-side (`_CausalStructures_sets()`
  and friends, using `\x01`/`\x1e`/ `\x1f`/`\x1d` marker bytes) and split back
  apart R-side (`split_sets()`, `split_opt_sets()`, `split_sets_of_sets()` at
  the bottom of `session.R`). Read the comment block at the top of `session.R`
  before changing this convention --- the marker-byte scheme exists specifically
  to make empty sets and `nothing`/`NULL` entries round-trip correctly through
  `strsplit()`.
- Errors raised inside Julia are cleaned to just the underlying message by
  `wrap_errors()`/ `clean_error()` (set
  `options(CausalStructures.verbose_errors = TRUE)` to see the full Julia
  stacktrace).
- `julia_ready()` is the check-only counterpart to `setup()` --- used in
  examples/tests to skip cleanly when Julia isn't available, without erroring.

### The Julia project shipped in `inst/`

`inst/Project.toml` pins `CausalStructures.jl` (from the Julia General registry)
plus `NetworkLayout`, `Sugiyama`, `Random`, `Suppressor`. `inst/Manifest.toml`
is gitignored on purpose (see `.gitignore`) so that patch releases of pinned
deps get picked up automatically on `Pkg.instantiate()` rather than being frozen
at whatever was resolved at commit time; only the `[compat]` bound in
`Project.toml` is version-controlled.

Installing Julia deps is never silent: `ensure_instantiated()` prompts
interactively, and non-interactively requires
`options(CausalStructures.auto_install = TRUE)` to proceed (otherwise it errors
with instructions) --- see the `CausalStructures_options` help topic in
`session.R` for all package-level options.

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

A causal graph is a Julia proxy object (`JuliaObject`) tagged with an R S3 class
`"cgraph"` (`.tag_cgraph()` in `session.R`). Query functions (`R/queries.R`,
`R/identification.R`) call through to Julia and return plain R vectors/data
frames; transform functions (`R/transform.R`) return new tagged graph proxies.
`R/data.R` covers simulating data from a graph.

### Plotting (`R/plot.R`, `R/plot-options.R`, `R/plot-routing.R`, `R/layout.R`)

- `cgraph_layout()` (`R/layout.R`) delegates node-coordinate computation to
  `CausalStructures.jl`'s own `layout()` Julia-side (which wraps
  `NetworkLayout.jl` and `Sugiyama.jl`); it defaults to `"sugiyama"` for graphs
  constructed/reclassed as `DAG` and `"stress"` otherwise, based on the graph's
  actual class rather than its edge structure.
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

`warmup()` calls every exported wrapper once on small graphs to force Julia's
JIT to compile each method up front, since Julia compiles per argument-type
combination on first call. Update it when adding a new exported function so its
first real call isn't the slow one.

## File organization

`DESCRIPTION`'s `Collate:` field defines load order (`session.R` first, since
everything else calls `fn()`/`setup()`); keep new files added to `R/` there if
load order matters.
