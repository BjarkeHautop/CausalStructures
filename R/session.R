# Design notes:
# - One Julia helper per function, defined at setup time in a single
#   `begin...end` block (JuliaCall's eval_string() parses one top-level
#   expression at a time, so a bare sequence of definitions is a
#   ParseError). Helpers take/return plain Strings, doing Symbol conversion
#   Julia-side.
# - Flat name/set results (`nodes`, `parents`, `adjustment_set`, ...) return
#   a plain `Vector{String}`/`Nothing`, which JuliaCall auto-converts.
# - `edge_marks()`/`layout()`/`simulate_data()` return a native Matrix
#   directly, for the same reason. `edges()` (causal-structures-
#   construction.R) builds on the `edge_marks` helper's Matrix, turning its
#   (src_end, dst_end) mark columns into one `type` notation column
#   (e.g. `"-->"`, `"o-o"`).
# - Nested "list of sets" results (`all_backdoor_sets` and friends) still
#   need a joined-string convention, since `Vector{Vector{String}}` doesn't
#   auto-convert; see split_sets(). Each item is prefixed with a `\x01`
#   marker byte before joining (`_CausalStructures_mjoin()`), so that no
#   split fragment - including a trailing one - is ever literally "",
#   letting a genuine empty set round-trip even when it is the list's last
#   element (plain `strsplit()` silently drops a trailing empty match).
#   Three shapes reuse this: `_CausalStructures_sets()` (list of sets),
#   `_CausalStructures_opt_sets()` (list of optional sets, `\x02` marking a
#   `nothing` entry), and `_CausalStructures_sets_of_sets()` (list of lists
#   of sets, e.g. `possible_joint_parent_sets()`).
# - No session-restart detection: no separate process to reconnect to - if
#   the embedded Julia dies, so does R. setup() is a plain do-once guard.
# - JuliaCall exposes no way to tear down and restart the embedded runtime
#   within a session, so there is no stop()/teardown function.

.cs <- new.env(parent = emptyenv())

# Helpers with a _CausalStructures_<name> Julia wrapper defined in setup()
.helpers <- c(
  "cgraph",
  "generate_graph",
  "uniform_dag",
  "topological_sort",
  "nodes",
  "exogenous_nodes",
  "parents",
  "children",
  "ancestors",
  "descendants",
  "spouses",
  "neighbors",
  "markov_blanket",
  "possible_ancestors",
  "possible_descendants",
  "anteriors",
  "posteriors",
  "has_edge",
  "d_separated",
  "m_separated",
  "minimal_separator",
  "adjustment_set",
  "frontdoor_set",
  "is_valid_backdoor",
  "all_backdoor_sets",
  "all_frontdoor_sets",
  "subgraph",
  "is_valid_adjustment",
  "all_adjustment_sets",
  "is_valid_frontdoor",
  "simulate_data",
  "enumerate_dags",
  "markov_equivalent",
  "is_valid_iv",
  "all_iv_sets",
  "enumerate_mags",
  "latent_project",
  "exogenize",
  "normalize_latent_structure",
  "condition_marginalize",
  "add_edges",
  "remove_edges",
  "add_nodes",
  "remove_nodes",
  "reclass",
  "layout",
  "edge_marks",
  "show",
  "meek_closure",
  "id",
  "idc",
  "backdoor_set",
  "possible_parent_sets",
  "possible_joint_parent_sets",
  "possible_optimal_adjustment_sets",
  "possible_d_sep",
  "possible_local_structures",
  "maximal_local_mag",
  "pagcauses"
)

# Functions called directly (graph proxy in, Bool or graph proxy out)
.passthrough <- c(
  "is_dag",
  "is_pdag",
  "is_cpdag",
  "is_mpdag",
  "is_ug",
  "is_admg",
  "is_ag",
  "is_mag",
  "is_pag",
  "is_simple",
  "is_acyclic",
  "skeleton",
  "moralize",
  "dag_to_cpdag",
  "dag_from_pdag",
  "dag_to_mpdag",
  "count_dags",
  "ag_to_mag",
  "mag_to_pag",
  "mag_from_pag"
)

.helper_defs <- c(
  # A length-1 R character vector arrives in Julia as a scalar String, not
  # a 1-element vector; branch on both.
  '_CausalStructures_syms(x) = x isa AbstractString ? [Symbol(x)] : Symbol.(x)',
  '_CausalStructures_sorted(x) = sort!(String.(collect(x)))',
  '_CausalStructures_opt(s) = s === nothing ? nothing : _CausalStructures_sorted(s)',

  '_CausalStructures_mjoin(items, sep) = join(("\x01" * i for i in items), sep)',
  '_CausalStructures_leaf(s) = join(sort!(String.(collect(s))), "\x1f")',
  '_CausalStructures_sets(sets) = _CausalStructures_mjoin(_CausalStructures_leaf.(sets), "\x1e")',

  'function _CausalStructures_opt_sets(sets)
      _CausalStructures_mjoin(
          [s === nothing ? "\x02" : _CausalStructures_leaf(s) for s in sets], "\x1e"
      )
  end',

  'function _CausalStructures_sets_of_sets(groups)
      _CausalStructures_mjoin([_CausalStructures_sets(g) for g in groups], "\x1d")
  end',

  '_CausalStructures_cgraph(spec, class) = getfield(_CausalStructures_CS, Symbol(class))(spec)',

  'function _CausalStructures_generate_graph(n, m, p, class, latents, rng)
      kwargs = (
          m = m === nothing ? nothing : Int(m), p = p,
          class = getfield(_CausalStructures_CS, Symbol(class)),
          latents = Int(latents),
      )
      rng === nothing ? _CausalStructures_CS.generate_graph(Int(n); kwargs...) :
      _CausalStructures_CS.generate_graph(rng, Int(n); kwargs...)
  end',

  'function _CausalStructures_uniform_dag(n, rng)
      rng === nothing ? _CausalStructures_CS.uniform_dag(Int(n)) :
      _CausalStructures_CS.uniform_dag(rng, Int(n))
  end',

  '_CausalStructures_topological_sort(g) = String.(_CausalStructures_CS.topological_sort(g))',
  '_CausalStructures_nodes(g) = String.(_CausalStructures_CS.nodes(g))',

  'function _CausalStructures_exogenous_nodes(g, undirected_as_parents)
      result = g isa _CausalStructures_CS.AbstractPDAG ?
          _CausalStructures_CS.exogenous_nodes(g; undirected_as_parents = undirected_as_parents) :
          _CausalStructures_CS.exogenous_nodes(g)
      _CausalStructures_sorted(result)
  end',

  'for f in (:parents, :children, :spouses, :markov_blanket)
      @eval $(Symbol(:_CausalStructures_, f))(g, node) = _CausalStructures_sorted(_CausalStructures_CS.$f(g, Symbol(node)))
  end',

  '_CausalStructures_neighbors(g, node, mode) =
      _CausalStructures_sorted(_CausalStructures_CS.neighbors(g, Symbol(node); mode = Symbol(mode)))',

  'for f in (:ancestors, :descendants, :possible_ancestors, :possible_descendants, :anteriors, :posteriors)
      @eval $(Symbol(:_CausalStructures_, f))(g, node, open) =
          _CausalStructures_sorted(_CausalStructures_CS.$f(g, Symbol(node); open = open))
  end',

  '_CausalStructures_has_edge(g, x, y) = _CausalStructures_CS.has_edge(g, Symbol(x), Symbol(y))',

  'for f in (:d_separated, :m_separated)
      @eval $(Symbol(:_CausalStructures_, f))(g, x, y, given) =
          _CausalStructures_CS.$f(g, _CausalStructures_syms(x), _CausalStructures_syms(y), _CausalStructures_syms(given))
  end',

  'function _CausalStructures_minimal_separator(g, x, y, include, restrict)
      _CausalStructures_opt(_CausalStructures_CS.minimal_separator(g, _CausalStructures_syms(x), _CausalStructures_syms(y);
          include = _CausalStructures_syms(include),
          restrict = restrict === nothing ? nothing : _CausalStructures_syms(restrict)))
  end',

  'function _CausalStructures_adjustment_set(g, x, y, type)
      result = if g isa Union{_CausalStructures_CS.DAG,_CausalStructures_CS.AbstractPDAG}
          _CausalStructures_CS.adjustment_set(g, _CausalStructures_syms(x), _CausalStructures_syms(y); type = Symbol(type))
      else
          _CausalStructures_CS.adjustment_set(g, _CausalStructures_syms(x), _CausalStructures_syms(y))
      end
      _CausalStructures_opt(result)
  end',

  'function _CausalStructures_frontdoor_set(g, x, y, include, restrict)
      _CausalStructures_opt(_CausalStructures_CS.frontdoor_set(g, _CausalStructures_syms(x), _CausalStructures_syms(y);
          include = _CausalStructures_syms(include),
          restrict = restrict === nothing ? nothing : _CausalStructures_syms(restrict)))
  end',

  '_CausalStructures_is_valid_backdoor(g, x, y, z) =
      _CausalStructures_CS.is_valid_backdoor(g, _CausalStructures_syms(x), _CausalStructures_syms(y), _CausalStructures_syms(z))',

  'function _CausalStructures_all_backdoor_sets(g, x, y, minimal, max_size)
      _CausalStructures_sets(_CausalStructures_CS.all_backdoor_sets(g, _CausalStructures_syms(x), _CausalStructures_syms(y);
          minimal = minimal, max_size = Int(max_size)))
  end',

  'function _CausalStructures_all_frontdoor_sets(g, x, y, include, restrict)
      _CausalStructures_sets(_CausalStructures_CS.all_frontdoor_sets(g, _CausalStructures_syms(x), _CausalStructures_syms(y);
          include = _CausalStructures_syms(include),
          restrict = restrict === nothing ? nothing : _CausalStructures_syms(restrict)))
  end',

  '_CausalStructures_subgraph(g, nodes) = _CausalStructures_CS.subgraph(g, _CausalStructures_syms(nodes))',

  'function _CausalStructures_edge_marks(g)
      es = collect(_CausalStructures_CS.edges(g))
      m = Matrix{String}(undef, length(es), 4)
      for (i, e) in enumerate(es)
          m[i, 1] = String(e.src)
          m[i, 2] = String(e.dst)
          m[i, 3] = string(e.src_end)
          m[i, 4] = string(e.dst_end)
      end
      m
  end',

  '_CausalStructures_is_valid_adjustment(g, x, y, z) =
      _CausalStructures_CS.is_valid_adjustment(g, _CausalStructures_syms(x), _CausalStructures_syms(y), _CausalStructures_syms(z))',

  'function _CausalStructures_all_adjustment_sets(g, x, y, minimal, max_size)
      _CausalStructures_sets(_CausalStructures_CS.all_adjustment_sets(g, _CausalStructures_syms(x), _CausalStructures_syms(y);
          minimal = minimal, max_size = Int(max_size)))
  end',

  '_CausalStructures_is_valid_frontdoor(g, x, y, z) =
      _CausalStructures_CS.is_valid_frontdoor(g, _CausalStructures_syms(x), _CausalStructures_syms(y), _CausalStructures_syms(z))',

  'function _CausalStructures_simulate_data(g, n, rng, standardize, coef_range, error_sd)
      kwargs = (
          samples = Int(n),
          standardize = standardize,
          coef_range = (Float64(coef_range[1]), Float64(coef_range[2])),
          error_sd = Float64(error_sd),
      )
      d = rng === nothing ? _CausalStructures_CS.simulate_data(g; kwargs...) :
          _CausalStructures_CS.simulate_data(rng, g; kwargs...)
      names = sort!(String.(collect(keys(d))))
      out = Matrix{Float64}(undef, Int(n), length(names))
      for (j, nm) in enumerate(names)
          out[:, j] = d[Symbol(nm)]
      end
      out
  end',

  '_CausalStructures_enumerate_dags(g) = _CausalStructures_CS.enumerate_dags(g)',
  '_CausalStructures_markov_equivalent(g1, g2) = _CausalStructures_CS.markov_equivalent(g1, g2)',

  '_CausalStructures_is_valid_iv(g, x, y, z) =
      _CausalStructures_CS.is_valid_iv(g, Symbol(x), _CausalStructures_syms(y), _CausalStructures_syms(z))',

  'function _CausalStructures_all_iv_sets(g, x, y, minimal, max_size)
      _CausalStructures_sets(_CausalStructures_CS.all_iv_sets(g, Symbol(x), _CausalStructures_syms(y);
          minimal = minimal, max_size = Int(max_size)))
  end',

  '_CausalStructures_enumerate_mags(g) = _CausalStructures_CS.enumerate_mags(g)',
  '_CausalStructures_latent_project(g, latents) = _CausalStructures_CS.latent_project(g, _CausalStructures_syms(latents))',
  '_CausalStructures_exogenize(g, nodes) = _CausalStructures_CS.exogenize(g, _CausalStructures_syms(nodes))',

  '_CausalStructures_normalize_latent_structure(g, latents) =
      _CausalStructures_CS.normalize_latent_structure(g, _CausalStructures_syms(latents))',

  '_CausalStructures_condition_marginalize(g, cond_vars, marg_vars) =
      _CausalStructures_CS.condition_marginalize(g;
          cond_vars = _CausalStructures_syms(cond_vars), marg_vars = _CausalStructures_syms(marg_vars))',

  '_CausalStructures_spec_edges(spec) =
      filter(x -> x isa _CausalStructures_CS.CausalEdge, _CausalStructures_CS._parse_graph_string(spec))',

  '_CausalStructures_add_edges(g, spec) = _CausalStructures_CS.add_edges(g, _CausalStructures_spec_edges(spec)...)',
  '_CausalStructures_remove_edges(g, spec) = _CausalStructures_CS.remove_edges(g, _CausalStructures_spec_edges(spec)...)',
  '_CausalStructures_add_nodes(g, nodes) = _CausalStructures_CS.add_nodes(g, _CausalStructures_syms(nodes)...)',
  '_CausalStructures_remove_nodes(g, nodes) = _CausalStructures_CS.remove_nodes(g, _CausalStructures_syms(nodes)...)',

  'function _CausalStructures_reclass(g, class)
      T = getfield(_CausalStructures_CS, Symbol(class))
      _CausalStructures_CS.reclass(g, T)
  end',

  'function _CausalStructures_layout(g, method)
      d = _CausalStructures_CS.layout(g, Symbol(method))
      nms = String.(_CausalStructures_CS.nodes(g))
      m = Matrix{Float64}(undef, length(nms), 2)
      for (i, nm) in enumerate(nms)
          p = d[Symbol(nm)]
          m[i, 1] = p[1]
          m[i, 2] = p[2]
      end
      m
  end',

  '_CausalStructures_show(g) = sprint(show, g)',

  '_CausalStructures_meek_closure(g, check_cycles, r4) =
      _CausalStructures_CS.meek_closure(g; check_cycles = check_cycles, r4 = r4)',

  'function _CausalStructures_id(g, x, y)
      r = _CausalStructures_CS.id(g, _CausalStructures_syms(x), _CausalStructures_syms(y))
      r === nothing ? nothing : string(r)
  end',

  'function _CausalStructures_idc(g, x, y, given)
      r = _CausalStructures_CS.idc(g, _CausalStructures_syms(x), _CausalStructures_syms(y);
          given = _CausalStructures_syms(given))
      r === nothing ? nothing : string(r)
  end',

  '_CausalStructures_backdoor_set(g, x, y) =
      _CausalStructures_opt(_CausalStructures_CS.backdoor_set(g, Symbol(x), Symbol(y)))',

  '_CausalStructures_possible_parent_sets(g, x) =
      _CausalStructures_sets(_CausalStructures_CS.possible_parent_sets(g, Symbol(x)))',

  '_CausalStructures_possible_joint_parent_sets(g, xs) =
      _CausalStructures_sets_of_sets(_CausalStructures_CS.possible_joint_parent_sets(g, _CausalStructures_syms(xs)))',

  '_CausalStructures_possible_optimal_adjustment_sets(g, x, y) =
      _CausalStructures_opt_sets(_CausalStructures_CS.possible_optimal_adjustment_sets(g, Symbol(x), Symbol(y)))',

  '_CausalStructures_possible_d_sep(g, x, y) =
      _CausalStructures_sorted(_CausalStructures_CS.possible_d_sep(g, Symbol(x), _CausalStructures_syms(y)))',

  '_CausalStructures_possible_local_structures(g, x) =
      _CausalStructures_sets(_CausalStructures_CS.possible_local_structures(g, Symbol(x)))',

  '_CausalStructures_maximal_local_mag(g, x, c) =
      _CausalStructures_CS.maximal_local_mag(g, Symbol(x), _CausalStructures_syms(c))',

  '_CausalStructures_pagcauses(g, x, y) =
      _CausalStructures_sets(_CausalStructures_CS.pagcauses(g, Symbol(x), Symbol(y)))'
)

#' Package options
#'
#' `CausalStructures` reads the following [options()]:
#'
#' \describe{
#'   \item{`CausalStructures.auto_install`}{Logical, default `FALSE`. When
#'     [setup()] needs to install or update Julia package dependencies and R
#'     is running non-interactively, this must be set to `TRUE` beforehand
#'     for it to proceed automatically - otherwise it errors with
#'     instructions. Ignored interactively, where you're prompted instead.}
#'   \item{`CausalStructures.verbose_errors`}{Logical, default `FALSE`.
#'     Errors raised inside Julia are cleaned to just the underlying error
#'     message by default; set to `TRUE` to see the full Julia stacktrace
#'     instead.}
#'   \item{`CausalStructures.open`}{Logical, default `TRUE`. Default for the
#'     `open` argument of [ancestors()], [descendants()],
#'     [possible_ancestors()], [possible_descendants()], [anteriors()], and
#'     [posteriors()]: `TRUE` (open definition) excludes the query node
#'     itself from the result, `FALSE` (closed definition) includes it.}
#' }
#'
#' @name CausalStructures_options
NULL

#' Path to the Julia project [setup()] should activate
#'
#' The `CausalStructures` environment shipped in this package's `inst/`
#' directory (`Project.toml` + `Manifest.toml`), which pulls
#' CausalStructures.jl from the Julia General registry.
#'
#' @return Absolute path to the Julia project directory.
#' @keywords internal
pkg_path <- function() {
  normalizePath(
    dirname(system.file(
      "Project.toml",
      package = "CausalStructures",
      mustWork = TRUE
    )),
    mustWork = TRUE
  )
}

#' Local CausalStructures.jl checkout, for local dev only
#'
#' When this R package is loaded from its source checkout (e.g. via
#' [pkgload::load_all()]) and a sibling `CausalStructures.jl` directory
#' exists next to it (i.e. the two repos are checked out side by side), that
#' local checkout is used instead of the registry version pinned in
#' `inst/Project.toml` - so local Julia-side changes are picked up without
#' publishing a release first. Returns `NULL` (falling back to the pinned
#' registry version) for an installed copy of this package, where no such
#' sibling directory exists.
#'
#' @return Absolute path to the local `CausalStructures.jl` checkout, or
#'   `NULL`.
#' @keywords internal
local_julia_dev_path <- function() {
  candidate <- file.path(
    dirname(dirname(pkg_path())),
    "CausalStructures.jl"
  )
  if (!file.exists(file.path(candidate, "Project.toml"))) {
    return(NULL)
  }
  normalizePath(candidate, mustWork = TRUE)
}

#' Julia project directory to activate for a local dev checkout
#'
#' `inst/Project.toml` pins `CausalStructures` to the latest *released*
#' version, so activating it directly would reject an unreleased/breaking
#' local checkout via a compat error. Instead, mirror `inst/Project.toml`'s
#' other dependencies (and their compat bounds) into a scratch project
#' outside the git working tree, with the `CausalStructures` compat entry
#' dropped, then [dev][setup()] the local checkout into it. Regenerated on
#' every [setup()] call, so edits to `inst/Project.toml`'s other deps are
#' always picked up; the resulting `Manifest.toml` persists across R
#' sessions like the regular `inst/Manifest.toml` does.
#'
#' @param dev_path Local `CausalStructures.jl` checkout, from
#'   [local_julia_dev_path()].
#' @return Absolute path to the scratch Julia project directory.
#' @keywords internal
dev_julia_project <- function(dev_path) {
  dir <- file.path(tools::R_user_dir("CausalStructures", "cache"), "julia-dev")
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  lines <- readLines(file.path(pkg_path(), "Project.toml"))
  lines <- lines[!grepl("^CausalStructures\\s*=", lines)]
  writeLines(lines, file.path(dir, "Project.toml"))
  normalizePath(dir, mustWork = TRUE)
}

#' Is Julia ready to use, with no setup needed?
#'
#' Checks that the `julia` binary is on the `PATH` and that [setup()] can
#' complete without erroring - in particular, without needing to install
#' Julia package dependencies.
#'
#' @return A logical scalar.
#' @export
julia_ready <- function() {
  if (isTRUE(.cs$ready)) {
    return(TRUE)
  }
  if (!nzchar(Sys.which("julia"))) {
    return(FALSE)
  }
  isTRUE(tryCatch(
    {
      setup()
      TRUE
    },
    error = function(e) FALSE
  ))
}

.make_caller <- function(fname) {
  force(fname)
  wrap_errors(function(...) JuliaCall::julia_call(fname, ...))
}

# Fixed upstream in JuliaCall PR#265 (merged 2025-10-27, not yet on CRAN);
# only apply our own copy of the workaround below that version.
needs_libunwind_workaround <- function() {
  tryCatch(
    utils::packageVersion("JuliaCall") <= "0.17.6",
    error = function(e) FALSE
  )
}

preload_julia_libunwind <- function() {
  if (!needs_libunwind_workaround()) {
    return(invisible(NULL))
  }
  tryCatch(
    {
      julia_bin <- Sys.which("julia")
      if (!nzchar(julia_bin)) {
        return(invisible(NULL))
      }
      bindir <- system2(
        julia_bin,
        args = c("-e", shQuote("print(Sys.BINDIR)")),
        stdout = TRUE,
        stderr = FALSE
      )
      libunwind <- file.path(dirname(bindir), "lib", "julia", "libunwind.so.8")
      if (file.exists(libunwind)) {
        dyn.load(libunwind, local = FALSE, now = TRUE)
      }
    },
    error = function(e) NULL,
    warning = function(w) NULL
  )
  invisible(NULL)
}

# Side-effect-free, no network: true if either
# (a) the manifest wasn't resolved from the current Project.toml - e.g. a
#     dependency was added/removed since the last resolve, detected via
#     Pkg.is_manifest_current() (compat-only edits don't count, only actual
#     [deps] drift), or
# (b) a dependency's source isn't actually present in the local Julia depot
#     (first run, or a depot that was wiped). `info.source` is `nothing` for
#     stdlibs (Random, ...), which ship with Julia itself and are never
#     "missing".
.needs_instantiate <- function(path) {
  current <- JuliaCall::julia_eval(sprintf(
    'Pkg.is_manifest_current("%s")',
    path
  ))
  if (!isTRUE(current)) {
    return(TRUE)
  }
  isTRUE(JuliaCall::julia_eval(paste(
    "try",
    "  any(info.source !== nothing && !isdir(info.source)",
    "      for (uuid, info) in Pkg.dependencies())",
    "catch",
    "  true",
    "end",
    sep = "\n"
  )))
}

# Installing Julia dependencies means downloading and precompiling several
# packages - slow and network-dependent - so setup() never does it silently.
# Interactively, ask; non-interactively (scripts, CI, tests), only proceed if
# the caller opted in via options(CausalStructures.auto_install = TRUE) - the
# default is to error with instructions rather than block on a prompt or
# silently download.
ensure_instantiated <- function(path) {
  if (!.needs_instantiate(path)) {
    return(invisible(NULL))
  }
  proceed <- if (interactive()) {
    utils::menu(
      c("Yes", "No"),
      title = paste(
        "CausalStructures needs to download and precompile Julia package",
        "dependencies. This can take a few minutes and requires network",
        "access. Proceed?"
      )
    ) ==
      1L
  } else {
    isTRUE(getOption("CausalStructures.auto_install", FALSE))
  }
  if (!proceed) {
    stop(
      "Julia dependencies for CausalStructures are not installed.\n",
      "Run setup() interactively to be prompted to install them, or set\n",
      "  options(CausalStructures.auto_install = TRUE)\n",
      "before calling setup() to install them automatically in ",
      "non-interactive sessions.",
      call. = FALSE
    )
  }
  JuliaCall::julia_command(
    "Pkg.resolve(); Pkg.instantiate(); Pkg.instantiate()"
  )
}

#' Start the Julia session with Julia packages loaded
#'
#' Called automatically by the wrapper functions; call it yourself to
#' pay the startup cost up front.
#'
#' The first time this runs on a machine, it may need to download and
#' precompile Julia package dependencies. Interactively, you'll be asked to
#' confirm before that happens. Non-interactively, it errors with
#' instructions unless `options(CausalStructures.auto_install = TRUE)` is
#' set beforehand.
#'
#' Errors raised inside Julia are reported with just the underlying Julia
#' error message; set `options(CausalStructures.verbose_errors = TRUE)` to see the
#' full Julia stacktrace instead.
#'
#' @seealso [CausalStructures_options] for all of the above, in one place.
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
  preload_julia_libunwind()
  tryCatch(
    JuliaCall::julia_setup(installJulia = FALSE),
    error = function(e) {
      stop(
        "Julia is not available. Install Julia and make sure it is on the ",
        "PATH.\n",
        conditionMessage(e),
        call. = FALSE
      )
    }
  )
  dev_path <- local_julia_dev_path()
  path <- if (is.null(dev_path)) pkg_path() else dev_julia_project(dev_path)
  JuliaCall::julia_command(sprintf('import Pkg; Pkg.activate("%s")', path))
  if (!is.null(dev_path)) {
    JuliaCall::julia_command(sprintf(
      'Pkg.develop(Pkg.PackageSpec(path = "%s"))',
      dev_path
    ))
  }
  ensure_instantiated(path)
  JuliaCall::julia_command("import CausalStructures")
  JuliaCall::julia_command("import Random")
  JuliaCall::julia_command("import NetworkLayout")
  JuliaCall::julia_command("const _CausalStructures_CS = CausalStructures;")
  # Wrapped in begin...end so the whole block is one top-level expression:
  # JuliaCall's eval_string() parses (and rejects, as multiple expressions)
  # a bare sequence of separate definitions.
  JuliaCall::julia_command(paste(
    c("begin", .helper_defs, "end;"),
    collapse = "\n"
  ))
  for (f in .helpers) {
    .cs[[f]] <- .make_caller(paste0("_CausalStructures_", f))
  }
  for (f in .passthrough) {
    .cs[[f]] <- .make_caller(paste0("CausalStructures.", f))
  }
  .cs$ready <- TRUE
  invisible(NULL)
}

# Wraps a julia_call()-backed closure once at setup time (rather than on
# every call) so Julia errors surface a clean message instead of the raw
# stacktrace; see clean_error().
wrap_errors <- function(fn) {
  force(fn)
  function(...) {
    tryCatch(fn(...), error = function(e) {
      stop(clean_error(conditionMessage(e)), call. = FALSE)
    })
  }
}

# JuliaCall's error messages are "Error happens in Julia.\n<message>\n
# Stacktrace:\n...", which is noise for most R users.
clean_error <- function(msg) {
  if (isTRUE(getOption("CausalStructures.verbose_errors", FALSE))) {
    return(msg)
  }
  m <- regmatches(
    msg,
    regexpr(
      "(?s)(?<=^Error happens in Julia\\.\n).*?(?=\nStacktrace:|$)",
      msg,
      perl = TRUE
    )
  )
  if (length(m) == 1 && nzchar(m)) m else msg
}

fn <- function(name) {
  setup()
  .cs[[name]]
}

# Builds a Julia RNG proxy from an integer seed, or NULL if seed is NULL.
# Currently uses base Random.jl (Random.Xoshiro); see .github/TODO.md for the
# planned switch to StableRNGs.jl for cross-Julia-version reproducibility.
make_rng <- function(seed) {
  if (is.null(seed)) {
    return(NULL)
  }
  setup()
  JuliaCall::julia_call("Random.Xoshiro", as.integer(seed))
}

# Decode the marker-prefixed joins built by _CausalStructures_mjoin(): every
# item was prefixed with a "\x01" byte before joining on `sep`, so no split
# fragment - including a trailing one - is ever literally "", letting a
# genuine empty item round-trip even when it is the list's last element
# (plain strsplit() silently drops a trailing empty match). Zero items
# encodes to "", which strsplit() already turns into character(0).
.msplit <- function(x, sep) {
  x <- as.character(x)
  parts <- strsplit(x, sep, fixed = TRUE, useBytes = TRUE)[[1]]
  substring(parts, 2)
}

# A leaf set (Vector{Symbol}, sorted and joined on "\x1f" Julia-side).
split_leaf <- function(s) {
  if (identical(s, "")) {
    return(character(0))
  }
  strsplit(s, "\x1f", fixed = TRUE, useBytes = TRUE)[[1]]
}

# Nested "list of sets" results (`all_backdoor_sets` and friends).
split_sets <- function(x) {
  lapply(.msplit(x, "\x1e"), split_leaf)
}

# Nested "list of optional sets" (`possible_optimal_adjustment_sets()`):
# "\x02" marks an entry that was `nothing` Julia-side.
split_opt_sets <- function(x) {
  lapply(.msplit(x, "\x1e"), function(s) {
    if (identical(s, "\x02")) NULL else split_leaf(s)
  })
}

# Nested "list of lists of sets" (`possible_joint_parent_sets()`).
split_sets_of_sets <- function(x) {
  lapply(.msplit(x, "\x1d"), split_sets)
}

# Wrapper factories
node_query <- function(name) {
  force(name)
  function(cg, node) fn(name)(cg, node)
}

graph_fn <- function(name) {
  force(name)
  function(cg) fn(name)(cg)
}

# Kept separate from graph_fn() because that factory is
# also used for predicates and count_dags(), which don't return graphs.
.tag_cgraph <- function(g) {
  class(g) <- c("cgraph", class(g))
  g
}

cgraph_fn <- function(name) {
  force(name)
  function(cg) .tag_cgraph(fn(name)(cg))
}


#' @importFrom Rdpack reprompt
NULL
