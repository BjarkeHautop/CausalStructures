# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with
code in this repository.

## What this is

Proof-of-concept R package binding the local Julia package
`CausalStructures.jl/` (same repo, own CLAUDE.md) to R via JuliaCall, which
embeds Julia in the R process (dlopen on libjulia) rather than talking to an
external process over a socket. An earlier JuliaConnectoR-based version of this
binding lived on this branch; see the `JuliaConnectoR` and `benchmark` git
branches for that implementation and a head-to-head comparison of the two
approaches. All binding code lives in `R/causal-structures-*.R` (session/setup,
construction, queries, transform, identification, data --- load order fixed by
`Collate` in `DESCRIPTION` since `graph_fn()`/`node_query()` factories from the
session file run at source time). Exported functions are unprefixed (`cgraph()`,
`nodes()`, ...).

CausalStructures.jl is published to the Julia General registry. `pkg_path()`
resolves the Julia project `setup()` activates: it always defaults to the
`CausalStructures` environment shipped in this package's `inst/`
(`Project.toml`, a plain registry dependency), which is what an installed copy
of this package, CI, and normal local dev all use. There's no automatic
detection of a local `CausalStructures.jl/` checkout (deliberately - a single
default code path, no magic); to test unreleased Julia-side changes while
co-developing both packages in this monorepo, point `setup()` at the checkout
explicitly with
`options(CausalStructures.causalstructures_path = "CausalStructures.jl")`.

`inst/Manifest.toml` is deliberately `.gitignore`d/`.Rbuildignore`d, not
committed: the only pin is the `[compat]` bound on `CausalStructures` in
`inst/Project.toml` (e.g. `"0.2"`, i.e. any `0.2.x`). This is intentional so
that every fresh install/CI run (no cached depot) resolves and picks up
non-breaking `0.2.x` CausalStructures.jl releases automatically, at the cost of
CI/first-run resolving against the registry instead of a pinned lockfile.
Locally, once `setup()` has instantiated once, the generated (untracked)
`inst/Manifest.toml` sticks around and is reused, so this isn't a per-call
resolve. Bump the compat bound by hand in `inst/Project.toml` only for a
breaking CausalStructures.jl release (i.e. a minor-version bump pre-1.0, per its
own CHANGELOG's "Breaking changes" sections) - patch releases need no change
here at all.

## Commands

```bash
# Run tests (skip automatically when Julia is unavailable)
Rscript -e 'pkgload::load_all("."); testthat::test_dir("tests/testthat")'

# Regenerate NAMESPACE + man/ after changing roxygen comments
Rscript -e 'roxygen2::roxygenise()'

# Run the benchmark vs caugi (from the package root; .Rbuildignore'd)
Rscript benchmark.R
```

Tests are API smoke tests with known answers from the quick-guide DAG
(`cgraph("A --> X + Y, X --> M --> Y")`); every `test_that` block starts with
`skip_if_no_julia()` (defined in `tests/testthat/helper-julia.R`). First Julia
startup takes several seconds; calls after that reuse the session. There's no
teardown (`setup-julia.R` is now a no-op comment) since JuliaCall can't actually
restart the embedded runtime --- see below.

CI (`R-CMD-check.yaml`, `test-coverage.yaml`) installs Julia via
`julia-actions/setup-julia` + `julia-actions/cache` (same pattern as
CausalStructures.jl's own workflows) and runs
`julia --project=inst -e 'using Pkg; Pkg.instantiate()'` before the R steps, so
the Julia depot is already populated when `setup()` runs and tests actually
execute in CI rather than skipping.

## Binding architecture

- `setup()` starts one shared Julia session lazily, activates the local project,
  and defines one Julia helper per wrapper (named `_testpkg_<fn>`, generated
  with `@eval` loops inside a single `begin...end` block sent via one
  `JuliaCall::julia_command()` call). R wrappers are built from factories
  (`node_query()`, `graph_fn()`).
- Helpers take plain Strings and do Symbol conversion Julia-side, but mostly
  *return* native types directly (`Vector{String}`, `Nothing`, `Matrix`), which
  JuliaCall auto-converts --- no joined-string convention needed except for
  nested "list of sets" results (`Vector{Vector{String}}` doesn't auto-convert;
  `split_sets()` handles that one case). Simple predicates/transforms (Bool or
  graph-proxy returns) call the Julia functions directly via
  `JuliaCall::julia_call("CausalStructures.<fn>", ...)`.
- Graphs cross the boundary as opaque `JuliaObject` proxies; pass them back into
  any wrapper. Every function that returns a graph (`cgraph()`,
  `generate_graph()`, the `cgraph_fn()`-built transforms, `subgraph()`, mutation
  functions, `reclass()`, ...) tags the result with an extra R-side `"cgraph"`
  S3 class via `.tag_cgraph()`, so `plot()` can dispatch on it and
  `cgraph_layout()` (a plain function, not a generic - see `layout.R`) can
  type-check for it. Functions that don't return a graph (predicates,
  `count_dags()`, node-set queries, ...) don't tag.
- No session-restart detection: JuliaCall embeds Julia in the R process, so
  there's no separate process to reconnect to --- if the embedded Julia dies, so
  does R. `setup()` is a plain do-once guard. There is no `stop()`/ teardown
  function: JuliaCall exposes no way to tear down and restart the embedded
  runtime within a session.

### CausalStructures semantics to remember

- `has_edge(g, x, y)` tests **adjacency** (any edge, either direction).
- `cgraph` classes are passed as strings (`"DAG"`, `"MAG"`, ...) and resolved
  Julia-side via `getfield`.

## Port progress (CausalStructures.jl exports → R)

Ported (69 R functions):

  | Group               | Functions                                                                                                                                                                                                                    |
  | ------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
  | Construction        | `cgraph`, `generate_graph`, `uniform_dag`                                                                                                                                                                                    |
  | Graph queries       | `nodes`, `topological_sort`, `exogenous_nodes`, `has_edge`, `edges`                                                                                                                                                          |
  | Node-set queries    | `parents`, `children`, `ancestors`, `descendants`, `spouses`, `neighbors`, `markov_blanket`, `possible_ancestors`, `possible_descendants`, `anteriors`, `posteriors`                                                         |
  | Predicates          | `is_dag`, `is_pdag`, `is_cpdag`, `is_mpdag`, `is_ug`, `is_admg`, `is_ag`, `is_mag`, `is_pag`, `is_simple`, `is_acyclic`                                                                                                      |
  | Transformations     | `skeleton`, `moralize`, `subgraph`, `dag_to_cpdag`, `dag_from_pdag`, `meek_closure`, `dag_to_mpdag`, `ag_to_mag`, `mag_to_pag`, `mag_from_pag`, `latent_project`, `exogenize`, `normalize_latent_structure`                  |
  | Separation          | `d_separated`, `m_separated`, `minimal_separator`                                                                                                                                                                            |
  | Identification      | `adjustment_set`, `frontdoor_set`, `is_valid_backdoor`, `all_backdoor_sets`, `all_frontdoor_sets`, `is_valid_adjustment`, `all_adjustment_sets`, `is_valid_frontdoor`, `is_valid_iv`, `all_iv_sets`, `condition_marginalize` |
  | Equivalence classes | `count_dags`, `enumerate_dags`, `markov_equivalent`, `enumerate_mags`                                                                                                                                                        |
  | Mutation            | `add_edges`, `remove_edges`, `add_nodes`, `remove_nodes`, `reclass`                                                                                                                                                          |
  | Data generation     | `simulate_data`                                                                                                                                                                                                              |
  | Plotting            | `cgraph_layout` (Julia: `layout`)                                                                                                                                                                                            |
  | Session             | `setup` (binding-specific, no Julia counterpart)                                                                                                                                                                             |

`frontdoor_set`/`all_frontdoor_sets` now accept ADMG as well as DAG (Julia
extended these from DAG-only); `generate_graph` now also accepts
`class = "ADMG"`/`"MAG"`/`"PAG"` plus a `latents` argument (samples a random DAG
with extra latent nodes, then latent-projects them out) -- the R wrappers and
docs reflect both.

CausalStructures.jl 0.2.0 dropped the `simple` keyword from `cgraph()`/
`reclass()` entirely (an `UNKNOWN` graph now always allows parallel edges, no
opt-in needed) and extended separation/adjustment to PAG: `m_separated`,
`minimal_separator`, `is_valid_adjustment`, and `all_adjustment_sets` now accept
a PAG graph (the latter two also gained a DAG method); `d_separated` and
`adjustment_set` were not extended. The R wrappers and docs reflect all of this.

Not yet ported:

- **Background knowledge**: `apply_background_knowledge`, `BackgroundKnowledge`,
  `RequiredEdge`, `ForbiddenEdge`, `required_directed`, `forbidden_directed`
- **Graph info**: `districts` (graph-level partition query, needs custom
  wrapper)
- **Not planned** (string DSL covers these): edge/type constructors `directed`,
  `undirected`, `bidirected`, `partially_directed`, `partially_undirected`,
  `partial`, `node`, and the graph-class types (`DAG`, `MAG`, ... are passed as
  strings)

When porting a new function, keep the checklist above in sync: add the Julia
helper (or pass-through name) in `setup()`, register it in `.helpers` /
`.passthrough`, add the R wrapper with roxygen docs (join an existing `@rdname`
group where one fits), regenerate docs, and extend the end-to-end check with a
known-answer assertion.
