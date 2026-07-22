# Experimental binding to CausalStructures.jl via JuliaCall, kept side by
# side with the JuliaConnectoR binding in causal-structures-*.R for
# comparison. Wrappers are prefixed `jc_` (vs. `cs_`). Not exported; load
# with pkgload::load_all().
#
# Differences from the JuliaConnectoR binding:
# - Flat name/set results auto-convert as plain `Vector{String}`/`Nothing`
#   (verified: no per-element cost like JuliaConnectoR's ~15us/element), so
#   no `cs_split()` convention is needed.
# - `edges()`/`simulate_data()` return a native Matrix directly - faster
#   than the joined-string convention here, unlike on the JuliaConnectoR side.
# - Nested "list of sets" results still need the joined-string convention
#   (`Vector{Vector{String}}` doesn't auto-convert); reuses `cs_split_sets()`.
# - No session-restart detection: no separate process to reconnect to.
# - No `jc_stop()` equivalent: JuliaCall can't tear down the embedded runtime.

.jc <- new.env(parent = emptyenv())

# Helpers with a _jctp_<name> Julia wrapper defined in jc_setup()
.jc_helpers <- c(
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
  "reclass"
)

# Functions called directly (graph proxy in, Bool or graph proxy out)
.jc_passthrough <- c(
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

.jc_helper_defs <- c(
  # A length-1 R character vector arrives in Julia as a scalar String, not
  # a 1-element vector (verified directly); branch on both, mirroring
  # _testpkg_syms() on the JuliaConnectoR side.
  '_jctp_syms(x) = x isa AbstractString ? [Symbol(x)] : Symbol.(x)',
  '_jctp_sorted(x) = sort!(String.(collect(x)))',
  '_jctp_opt(s) = s === nothing ? nothing : _jctp_sorted(s)',
  '_jctp_sets(sets) = isempty(sets) ? nothing :
      join((join(sort!(String.(collect(s))), "\x1f") for s in sets), "\x1e")',

  '_jctp_cgraph(spec, class, simple) =
      _jctpCS.cgraph(spec; class = getfield(_jctpCS, Symbol(class)), simple = simple)',

  'function _jctp_generate_graph(n, m, p, class, rng)
      kwargs = (
          m = m === nothing ? nothing : Int(m), p = p,
          class = getfield(_jctpCS, Symbol(class)),
      )
      rng === nothing ? _jctpCS.generate_graph(Int(n); kwargs...) :
      _jctpCS.generate_graph(rng, Int(n); kwargs...)
  end',

  '_jctp_topological_sort(g) = String.(_jctpCS.topological_sort(g))',
  '_jctp_nodes(g) = String.(_jctpCS.nodes(g))',

  'function _jctp_exogenous_nodes(g, undirected_as_parents)
      result = g isa _jctpCS.AbstractPDAG ?
          _jctpCS.exogenous_nodes(g; undirected_as_parents = undirected_as_parents) :
          _jctpCS.exogenous_nodes(g)
      _jctp_sorted(result)
  end',

  'for f in (:parents, :children, :ancestors, :descendants, :spouses, :markov_blanket)
      @eval $(Symbol(:_jctp_, f))(g, node) = _jctp_sorted(_jctpCS.$f(g, Symbol(node)))
  end',

  '_jctp_neighbors(g, node, mode) =
      _jctp_sorted(_jctpCS.neighbors(g, Symbol(node); mode = Symbol(mode)))',

  'for f in (:possible_ancestors, :possible_descendants, :anteriors, :posteriors)
      @eval $(Symbol(:_jctp_, f))(g, node, open) =
          _jctp_sorted(_jctpCS.$f(g, Symbol(node); open = open))
  end',

  '_jctp_has_edge(g, x, y) = _jctpCS.has_edge(g, Symbol(x), Symbol(y))',

  'for f in (:d_separated, :m_separated)
      @eval $(Symbol(:_jctp_, f))(g, x, y, given) =
          _jctpCS.$f(g, Symbol(x), Symbol(y), _jctp_syms(given))
  end',

  'function _jctp_minimal_separator(g, x, y, include, restrict)
      _jctp_opt(_jctpCS.minimal_separator(g, Symbol(x), Symbol(y);
          include = _jctp_syms(include),
          restrict = restrict === nothing ? nothing : _jctp_syms(restrict)))
  end',

  'function _jctp_adjustment_set(g, x, y, type)
      result = if g isa Union{_jctpCS.DAG,_jctpCS.AbstractPDAG}
          _jctpCS.adjustment_set(g, Symbol(x), Symbol(y); type = Symbol(type))
      else
          _jctpCS.adjustment_set(g, Symbol(x), Symbol(y))
      end
      _jctp_opt(result)
  end',

  'function _jctp_frontdoor_set(g, x, y, include, restrict)
      _jctp_opt(_jctpCS.frontdoor_set(g, Symbol(x), Symbol(y);
          include = _jctp_syms(include),
          restrict = restrict === nothing ? nothing : _jctp_syms(restrict)))
  end',

  '_jctp_is_valid_backdoor(g, x, y, z) =
      _jctpCS.is_valid_backdoor(g, Symbol(x), Symbol(y), _jctp_syms(z))',

  'function _jctp_all_backdoor_sets(g, x, y, minimal, max_size)
      _jctp_sets(_jctpCS.all_backdoor_sets(g, Symbol(x), Symbol(y);
          minimal = minimal, max_size = Int(max_size)))
  end',

  'function _jctp_all_frontdoor_sets(g, x, y, include, restrict)
      _jctp_sets(_jctpCS.all_frontdoor_sets(g, Symbol(x), Symbol(y);
          include = _jctp_syms(include),
          restrict = restrict === nothing ? nothing : _jctp_syms(restrict)))
  end',

  '_jctp_subgraph(g, nodes) = _jctpCS.subgraph(g, _jctp_syms(nodes))',

  'function _jctp_edges(g)
      es = collect(_jctpCS.edges(g))
      m = Matrix{String}(undef, length(es), 2)
      for (i, e) in enumerate(es)
          m[i, 1] = String(e.src)
          m[i, 2] = String(e.dst)
      end
      m
  end',

  '_jctp_is_valid_adjustment(g, x, y, z) =
      _jctpCS.is_valid_adjustment(g, Symbol(x), Symbol(y), _jctp_syms(z))',

  'function _jctp_all_adjustment_sets(g, x, y, minimal, max_size)
      _jctp_sets(_jctpCS.all_adjustment_sets(g, Symbol(x), Symbol(y);
          minimal = minimal, max_size = Int(max_size)))
  end',

  '_jctp_is_valid_frontdoor(g, x, y, z) =
      _jctpCS.is_valid_frontdoor(g, Symbol(x), Symbol(y), _jctp_syms(z))',

  'function _jctp_simulate_data(g, n, rng, standardize, coef_range, error_sd)
      kwargs = (
          samples = Int(n),
          standardize = standardize,
          coef_range = (Float64(coef_range[1]), Float64(coef_range[2])),
          error_sd = Float64(error_sd),
      )
      d = rng === nothing ? _jctpCS.simulate_data(g; kwargs...) :
          _jctpCS.simulate_data(rng, g; kwargs...)
      names = sort!(String.(collect(keys(d))))
      out = Matrix{Float64}(undef, Int(n), length(names))
      for (j, nm) in enumerate(names)
          out[:, j] = d[Symbol(nm)]
      end
      out
  end',

  '_jctp_enumerate_dags(g) = _jctpCS.enumerate_dags(g)',
  '_jctp_markov_equivalent(g1, g2) = _jctpCS.markov_equivalent(g1, g2)',

  '_jctp_is_valid_iv(g, x, y, z) =
      _jctpCS.is_valid_iv(g, Symbol(x), Symbol(y), _jctp_syms(z))',

  'function _jctp_all_iv_sets(g, x, y, minimal, max_size)
      _jctp_sets(_jctpCS.all_iv_sets(g, Symbol(x), Symbol(y);
          minimal = minimal, max_size = Int(max_size)))
  end',

  '_jctp_enumerate_mags(g) = _jctpCS.enumerate_mags(g)',
  '_jctp_latent_project(g, latents) = _jctpCS.latent_project(g, _jctp_syms(latents))',
  '_jctp_exogenize(g, nodes) = _jctpCS.exogenize(g, _jctp_syms(nodes))',

  '_jctp_normalize_latent_structure(g, latents) =
      _jctpCS.normalize_latent_structure(g, _jctp_syms(latents))',

  '_jctp_condition_marginalize(g, cond_vars, marg_vars) =
      _jctpCS.condition_marginalize(g;
          cond_vars = _jctp_syms(cond_vars), marg_vars = _jctp_syms(marg_vars))',

  '_jctp_spec_edges(spec) =
      filter(x -> x isa _jctpCS.CausalEdge, _jctpCS._parse_graph_string(spec))',

  '_jctp_add_edges(g, spec) = _jctpCS.add_edges(g, _jctp_spec_edges(spec)...)',
  '_jctp_remove_edges(g, spec) = _jctpCS.remove_edges(g, _jctp_spec_edges(spec)...)',
  '_jctp_add_nodes(g, nodes) = _jctpCS.add_nodes(g, _jctp_syms(nodes)...)',
  '_jctp_remove_nodes(g, nodes) = _jctpCS.remove_nodes(g, _jctp_syms(nodes)...)',

  'function _jctp_reclass(g, class, simple)
      T = getfield(_jctpCS, Symbol(class))
      T === _jctpCS.UNKNOWN ? _jctpCS.reclass(g, T; simple = simple) :
      _jctpCS.reclass(g, T)
  end'
)

.jc_make_caller <- function(fname) {
  force(fname)
  jc_wrap_errors(function(...) JuliaCall::julia_call(fname, ...))
}

# Fixed upstream in JuliaCall PR #265 (merged 2025-10-27, not yet on CRAN);
# only apply our own copy of the workaround below that version.
jc_needs_libunwind_workaround <- function() {
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
jc_preload_julia_libunwind <- function() {
  if (!jc_needs_libunwind_workaround()) {
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

# Wraps a julia_call()-backed closure once at setup time (rather than on
# every call) so Julia errors surface a clean message instead of the raw
# stacktrace; mirrors cs_wrap_errors() on the JuliaConnectoR side.
jc_wrap_errors <- function(fn) {
  force(fn)
  function(...) {
    tryCatch(fn(...), error = function(e) {
      stop(jc_clean_error(conditionMessage(e)), call. = FALSE)
    })
  }
}

# JuliaCall's error messages are "Error happens in Julia.\n<message>\n
# Stacktrace:\n...", vs. JuliaConnectoR's "...Original Julia error
# message:\n<message>\nStacktrace:...". Same idea, different wrapper text.
jc_clean_error <- function(msg) {
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

#' Start (or reuse) the JuliaCall-embedded Julia session with CausalStructures loaded
#'
#' Experimental counterpart to [cs_setup()] using the JuliaCall backend
#' instead of JuliaConnectoR. See the top of `R/juliacall/jc-session.R` for
#' the libunwind workaround this relies on to turn Julia errors into clean R
#' errors (`options(testpkg.verbose_errors = TRUE)` shows the full Julia
#' stacktrace instead, same as [cs_setup()]).
#'
#' @return `NULL`, invisibly.
#' @keywords internal
jc_setup <- function() {
  if (isTRUE(.jc$ready)) {
    return(invisible(NULL))
  }
  jc_preload_julia_libunwind()
  julia <- tryCatch(
    JuliaCall::julia_setup(installJulia = FALSE),
    error = function(e) {
      stop(
        "Julia is not available for JuliaCall. Install Julia and make sure ",
        "it is on the PATH.\n",
        conditionMessage(e),
        call. = FALSE
      )
    }
  )
  path <- cs_pkg_path()
  JuliaCall::julia_command(sprintf(
    'import Pkg; Pkg.activate("%s"); Pkg.instantiate()',
    path
  ))
  JuliaCall::julia_command("import CausalStructures")
  JuliaCall::julia_command("import Random")
  JuliaCall::julia_command("const _jctpCS = CausalStructures")
  # Wrapped in begin...end so the whole block is one top-level expression:
  # JuliaCall's eval_string() parses (and rejects, as multiple expressions)
  # a bare sequence of separate definitions.
  JuliaCall::julia_command(paste(
    c("begin", .jc_helper_defs, "end"),
    collapse = "\n"
  ))
  for (f in .jc_helpers) {
    .jc[[f]] <- .jc_make_caller(paste0("_jctp_", f))
  }
  for (f in .jc_passthrough) {
    .jc[[f]] <- .jc_make_caller(paste0("CausalStructures.", f))
  }
  .jc$ready <- TRUE
  invisible(NULL)
}

jc_fn <- function(name) {
  jc_setup()
  .jc[[name]]
}

# Builds a Julia RNG proxy from an integer seed, or NULL if seed is NULL.
jc_make_rng <- function(seed) {
  if (is.null(seed)) {
    return(NULL)
  }
  jc_setup()
  JuliaCall::julia_call("Random.Xoshiro", as.integer(seed))
}

# Wrapper factories. Unlike cs_node_query()/cs_graph_fn(), no cs_split()
# equivalent is needed: the Julia helpers already return plain
# Vector{String}/Nothing, which JuliaCall auto-converts.
jc_node_query <- function(name) {
  force(name)
  function(cg, node) jc_fn(name)(cg, node)
}

jc_graph_fn <- function(name) {
  force(name)
  function(cg) jc_fn(name)(cg)
}

#' Shut down the JuliaCall-embedded Julia session
#'
#' Unlike [cs_stop()], this is a no-op: JuliaCall embeds Julia in the R
#' process (dlopen on libjulia) and exposes no function to tear the embedded
#' runtime down and restart it within a session.
#'
#' @return `NULL`, invisibly.
#' @keywords internal
jc_stop <- function() {
  warning(
    "JuliaCall embeds Julia in the R process; there is no supported way to ",
    "shut it down and restart it within a session (unlike cs_stop() for ",
    "the JuliaConnectoR backend, which kills the external Julia process). ",
    "This call is a no-op.",
    call. = FALSE
  )
  invisible(NULL)
}
