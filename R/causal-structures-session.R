# Binding to the local Julia package CausalStructures.jl via JuliaCall,
# which embeds Julia in the R process (dlopen on libjulia) rather than
# talking to an external process over a socket, as the earlier
# JuliaConnectoR-based binding did (see git history / the JuliaConnectoR and
# benchmark branches). The Julia session is started lazily on first use and
# reused afterwards.
#
# CRAN's JuliaCall (<= 0.17.6) segfaults R on any Julia exception, on Ubuntu
# + Julia 1.12: a libunwind version conflict, fixed upstream (JuliaCall
# PR #265/#282, libunwind/libunwind#637) but not yet released to CRAN.
# preload_julia_libunwind() applies the same fix until it is.
#
# Design notes:
# - One Julia helper per function, defined at setup time in a single
#   `begin...end` block (JuliaCall's eval_string() parses one top-level
#   expression at a time, so a bare sequence of definitions is a
#   ParseError). Helpers take/return plain Strings, doing Symbol conversion
#   Julia-side.
# - Flat name/set results (`nodes`, `parents`, `adjustment_set`, ...) return
#   a plain `Vector{String}`/`Nothing`, which JuliaCall auto-converts - no
#   joined-string convention needed (verified: no per-element deserialize
#   cost like JuliaConnectoR had).
# - `edges()`/`edge_marks()`/`layout()`/`simulate_data()` return a native
#   Matrix directly, for the same reason.
# - Nested "list of sets" results (`all_backdoor_sets` and friends) still
#   need a joined-string convention, since `Vector{Vector{String}}` doesn't
#   auto-convert; see split_sets().
# - No session-restart detection: no separate process to reconnect to - if
#   the embedded Julia dies, so does R. setup() is a plain do-once guard.
# - JuliaCall exposes no way to tear down and restart the embedded runtime
#   within a session, so there is no stop()/teardown function.

.cs <- new.env(parent = emptyenv())

# Helpers with a _testpkg_<name> Julia wrapper defined in setup()
.helpers <- c(
  "cgraph",
  "generate_graph",
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
  "edges",
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
  "show"
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
  "meek_closure",
  "dag_to_mpdag",
  "count_dags",
  "ag_to_mag",
  "mag_to_pag",
  "mag_from_pag"
)

.helper_defs <- c(
  # A length-1 R character vector arrives in Julia as a scalar String, not
  # a 1-element vector; branch on both.
  '_testpkg_syms(x) = x isa AbstractString ? [Symbol(x)] : Symbol.(x)',
  '_testpkg_sorted(x) = sort!(String.(collect(x)))',
  '_testpkg_opt(s) = s === nothing ? nothing : _testpkg_sorted(s)',
  '_testpkg_sets(sets) = isempty(sets) ? nothing :
      join((join(sort!(String.(collect(s))), "\x1f") for s in sets), "\x1e")',

  '_testpkg_cgraph(spec, class, simple) =
      _testpkg_CS.cgraph(spec; class = getfield(_testpkg_CS, Symbol(class)), simple = simple)',

  'function _testpkg_generate_graph(n, m, p, class, rng)
      kwargs = (
          m = m === nothing ? nothing : Int(m), p = p,
          class = getfield(_testpkg_CS, Symbol(class)),
      )
      rng === nothing ? _testpkg_CS.generate_graph(Int(n); kwargs...) :
      _testpkg_CS.generate_graph(rng, Int(n); kwargs...)
  end',

  '_testpkg_topological_sort(g) = String.(_testpkg_CS.topological_sort(g))',
  '_testpkg_nodes(g) = String.(_testpkg_CS.nodes(g))',

  'function _testpkg_exogenous_nodes(g, undirected_as_parents)
      result = g isa _testpkg_CS.AbstractPDAG ?
          _testpkg_CS.exogenous_nodes(g; undirected_as_parents = undirected_as_parents) :
          _testpkg_CS.exogenous_nodes(g)
      _testpkg_sorted(result)
  end',

  'for f in (:parents, :children, :ancestors, :descendants, :spouses, :markov_blanket)
      @eval $(Symbol(:_testpkg_, f))(g, node) = _testpkg_sorted(_testpkg_CS.$f(g, Symbol(node)))
  end',

  '_testpkg_neighbors(g, node, mode) =
      _testpkg_sorted(_testpkg_CS.neighbors(g, Symbol(node); mode = Symbol(mode)))',

  'for f in (:possible_ancestors, :possible_descendants, :anteriors, :posteriors)
      @eval $(Symbol(:_testpkg_, f))(g, node, open) =
          _testpkg_sorted(_testpkg_CS.$f(g, Symbol(node); open = open))
  end',

  '_testpkg_has_edge(g, x, y) = _testpkg_CS.has_edge(g, Symbol(x), Symbol(y))',

  'for f in (:d_separated, :m_separated)
      @eval $(Symbol(:_testpkg_, f))(g, x, y, given) =
          _testpkg_CS.$f(g, Symbol(x), Symbol(y), _testpkg_syms(given))
  end',

  'function _testpkg_minimal_separator(g, x, y, include, restrict)
      _testpkg_opt(_testpkg_CS.minimal_separator(g, Symbol(x), Symbol(y);
          include = _testpkg_syms(include),
          restrict = restrict === nothing ? nothing : _testpkg_syms(restrict)))
  end',

  'function _testpkg_adjustment_set(g, x, y, type)
      result = if g isa Union{_testpkg_CS.DAG,_testpkg_CS.AbstractPDAG}
          _testpkg_CS.adjustment_set(g, Symbol(x), Symbol(y); type = Symbol(type))
      else
          _testpkg_CS.adjustment_set(g, Symbol(x), Symbol(y))
      end
      _testpkg_opt(result)
  end',

  'function _testpkg_frontdoor_set(g, x, y, include, restrict)
      _testpkg_opt(_testpkg_CS.frontdoor_set(g, Symbol(x), Symbol(y);
          include = _testpkg_syms(include),
          restrict = restrict === nothing ? nothing : _testpkg_syms(restrict)))
  end',

  '_testpkg_is_valid_backdoor(g, x, y, z) =
      _testpkg_CS.is_valid_backdoor(g, Symbol(x), Symbol(y), _testpkg_syms(z))',

  'function _testpkg_all_backdoor_sets(g, x, y, minimal, max_size)
      _testpkg_sets(_testpkg_CS.all_backdoor_sets(g, Symbol(x), Symbol(y);
          minimal = minimal, max_size = Int(max_size)))
  end',

  'function _testpkg_all_frontdoor_sets(g, x, y, include, restrict)
      _testpkg_sets(_testpkg_CS.all_frontdoor_sets(g, Symbol(x), Symbol(y);
          include = _testpkg_syms(include),
          restrict = restrict === nothing ? nothing : _testpkg_syms(restrict)))
  end',

  '_testpkg_subgraph(g, nodes) = _testpkg_CS.subgraph(g, _testpkg_syms(nodes))',

  'function _testpkg_edges(g)
      es = collect(_testpkg_CS.edges(g))
      m = Matrix{String}(undef, length(es), 2)
      for (i, e) in enumerate(es)
          m[i, 1] = String(e.src)
          m[i, 2] = String(e.dst)
      end
      m
  end',

  'function _testpkg_edge_marks(g)
      es = collect(_testpkg_CS.edges(g))
      m = Matrix{String}(undef, length(es), 4)
      for (i, e) in enumerate(es)
          m[i, 1] = String(e.src)
          m[i, 2] = String(e.dst)
          m[i, 3] = string(e.src_end)
          m[i, 4] = string(e.dst_end)
      end
      m
  end',

  '_testpkg_is_valid_adjustment(g, x, y, z) =
      _testpkg_CS.is_valid_adjustment(g, Symbol(x), Symbol(y), _testpkg_syms(z))',

  'function _testpkg_all_adjustment_sets(g, x, y, minimal, max_size)
      _testpkg_sets(_testpkg_CS.all_adjustment_sets(g, Symbol(x), Symbol(y);
          minimal = minimal, max_size = Int(max_size)))
  end',

  '_testpkg_is_valid_frontdoor(g, x, y, z) =
      _testpkg_CS.is_valid_frontdoor(g, Symbol(x), Symbol(y), _testpkg_syms(z))',

  'function _testpkg_simulate_data(g, n, rng, standardize, coef_range, error_sd)
      kwargs = (
          samples = Int(n),
          standardize = standardize,
          coef_range = (Float64(coef_range[1]), Float64(coef_range[2])),
          error_sd = Float64(error_sd),
      )
      d = rng === nothing ? _testpkg_CS.simulate_data(g; kwargs...) :
          _testpkg_CS.simulate_data(rng, g; kwargs...)
      names = sort!(String.(collect(keys(d))))
      out = Matrix{Float64}(undef, Int(n), length(names))
      for (j, nm) in enumerate(names)
          out[:, j] = d[Symbol(nm)]
      end
      out
  end',

  '_testpkg_enumerate_dags(g) = _testpkg_CS.enumerate_dags(g)',
  '_testpkg_markov_equivalent(g1, g2) = _testpkg_CS.markov_equivalent(g1, g2)',

  '_testpkg_is_valid_iv(g, x, y, z) =
      _testpkg_CS.is_valid_iv(g, Symbol(x), Symbol(y), _testpkg_syms(z))',

  'function _testpkg_all_iv_sets(g, x, y, minimal, max_size)
      _testpkg_sets(_testpkg_CS.all_iv_sets(g, Symbol(x), Symbol(y);
          minimal = minimal, max_size = Int(max_size)))
  end',

  '_testpkg_enumerate_mags(g) = _testpkg_CS.enumerate_mags(g)',
  '_testpkg_latent_project(g, latents) = _testpkg_CS.latent_project(g, _testpkg_syms(latents))',
  '_testpkg_exogenize(g, nodes) = _testpkg_CS.exogenize(g, _testpkg_syms(nodes))',

  '_testpkg_normalize_latent_structure(g, latents) =
      _testpkg_CS.normalize_latent_structure(g, _testpkg_syms(latents))',

  '_testpkg_condition_marginalize(g, cond_vars, marg_vars) =
      _testpkg_CS.condition_marginalize(g;
          cond_vars = _testpkg_syms(cond_vars), marg_vars = _testpkg_syms(marg_vars))',

  '_testpkg_spec_edges(spec) =
      filter(x -> x isa _testpkg_CS.CausalEdge, _testpkg_CS._parse_graph_string(spec))',

  '_testpkg_add_edges(g, spec) = _testpkg_CS.add_edges(g, _testpkg_spec_edges(spec)...)',
  '_testpkg_remove_edges(g, spec) = _testpkg_CS.remove_edges(g, _testpkg_spec_edges(spec)...)',
  '_testpkg_add_nodes(g, nodes) = _testpkg_CS.add_nodes(g, _testpkg_syms(nodes)...)',
  '_testpkg_remove_nodes(g, nodes) = _testpkg_CS.remove_nodes(g, _testpkg_syms(nodes)...)',

  'function _testpkg_reclass(g, class, simple)
      T = getfield(_testpkg_CS, Symbol(class))
      T === _testpkg_CS.UNKNOWN ? _testpkg_CS.reclass(g, T; simple = simple) :
      _testpkg_CS.reclass(g, T)
  end',

  'function _testpkg_layout(g, method)
      pts = _testpkg_CS.layout(g, Symbol(method))
      m = Matrix{Float64}(undef, length(pts), 2)
      for (i, p) in enumerate(pts)
          m[i, 1] = p[1]
          m[i, 2] = p[2]
      end
      m
  end',

  '_testpkg_show(g) = sprint(show, g)'
)

#' Path to the local CausalStructures.jl checkout
#'
#' Defaults to the `CausalStructures.jl/` directory bundled next to this
#' package's source, and can be overridden with the
#' `testpkg.causalstructures_path` option.
#'
#' @return Absolute path to the Julia package directory.
#' @keywords internal
pkg_path <- function() {
  path <- getOption(
    "testpkg.causalstructures_path",
    file.path(
      dirname(system.file("DESCRIPTION", package = "testpkg")),
      "CausalStructures.jl"
    )
  )
  normalizePath(path, mustWork = TRUE)
}

#' Is Julia available?
#'
#' A quick, side-effect-free check for use in `@examples`; unlike
#' [setup()] it does not start Julia.
#'
#' @return A logical scalar.
#' @export
julia_available <- function() {
  nzchar(Sys.which("julia"))
}

.make_caller <- function(fname) {
  force(fname)
  wrap_errors(function(...) JuliaCall::julia_call(fname, ...))
}

# Fixed upstream in JuliaCall PR #265 (merged 2025-10-27, not yet on CRAN);
# only apply our own copy of the workaround below that version.
needs_libunwind_workaround <- function() {
  tryCatch(
    utils::packageVersion("JuliaCall") <= "0.17.6",
    error = function(e) FALSE
  )
}

# dyn.load()s Julia's own libunwind.so.8 before julia_setup(), so it wins
# dynamic-linker resolution ahead of Ubuntu's incompatible system copy
# (libunwind/libunwind#637) - same fix as JuliaCall PR #265. Best-effort:
# silently skipped if `julia` isn't on PATH or ships no libunwind.so.8 (e.g.
# non-Linux, or the conflict doesn't apply), since a missed mitigation
# should surface as the original segfault, not a confusing setup-time error.
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

#' Start (or reuse) the Julia session with CausalStructures loaded
#'
#' Activates the local CausalStructures.jl project, instantiates its
#' dependencies, and imports the module. Called automatically by the
#' wrapper functions; call it yourself to pay the startup cost up front.
#'
#' Errors raised inside Julia are reported with just the underlying Julia
#' error message; set `options(testpkg.verbose_errors = TRUE)` to see the
#' full Julia stacktrace instead.
#'
#' @return `NULL`, invisibly.
#' @export
#' @examples
#' if (julia_available()) {
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
  path <- pkg_path()
  JuliaCall::julia_command(sprintf(
    'import Pkg; Pkg.activate("%s"); Pkg.instantiate()',
    path
  ))
  JuliaCall::julia_command("import CausalStructures")
  JuliaCall::julia_command("import Random")
  JuliaCall::julia_command("import NetworkLayout")
  JuliaCall::julia_command("const _testpkg_CS = CausalStructures")
  # Wrapped in begin...end so the whole block is one top-level expression:
  # JuliaCall's eval_string() parses (and rejects, as multiple expressions)
  # a bare sequence of separate definitions.
  JuliaCall::julia_command(paste(
    c("begin", .helper_defs, "end"),
    collapse = "\n"
  ))
  for (f in .helpers) {
    .cs[[f]] <- .make_caller(paste0("_testpkg_", f))
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
  if (isTRUE(getOption("testpkg.verbose_errors", FALSE))) {
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

# Only used by split_sets() now (nested "list of sets" results); flat
# results return a plain Vector{String}, which JuliaCall auto-converts.
split <- function(x) {
  x <- as.character(x)
  if (identical(x, "")) {
    character(0)
  } else {
    strsplit(x, "\x1f", fixed = TRUE, useBytes = TRUE)[[1]]
  }
}

split_sets <- function(x) {
  if (is.null(x)) {
    return(list())
  }
  x <- as.character(x)
  if (identical(x, "")) {
    return(list(character(0)))
  }
  lapply(strsplit(x, "\x1e", fixed = TRUE, useBytes = TRUE)[[1]], split)
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

# Tags a graph proxy with the "cgraph" S3 class so plot()/layout() can
# dispatch on it. Kept separate from graph_fn() because that factory is also
# used for predicates and count_dags(), which don't return graphs.
.tag_cgraph <- function(g) {
  class(g) <- c("cgraph", class(g))
  g
}

cgraph_fn <- function(name) {
  force(name)
  function(cg) .tag_cgraph(fn(name)(cg))
}
