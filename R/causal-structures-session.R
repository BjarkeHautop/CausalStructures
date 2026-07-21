# Proof-of-concept binding to the local Julia package CausalStructures.jl
# via JuliaConnectoR. The Julia session is started lazily on first use and
# reused afterwards.
#
# Design notes:
# - Every wrapper is a single R-to-Julia round trip: one Julia helper per
#   function is defined at setup time, taking/returning plain Strings and
#   doing all Symbol conversion Julia-side.
# - Node-name vectors are returned as a single "\x1f"-joined string because
#   JuliaConnectoR deserializes each string element individually in
#   interpreted R (~15 us per element); one string + strsplit is ~constant.
#   Lists of node sets additionally join sets with "\x1e".

.cs <- new.env(parent = emptyenv())

# Helpers with a _testpkg_<name> Julia wrapper defined in cs_setup()
.cs_helpers <- c(
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
  "edge_marks"
)

# Functions called directly (graph proxy in, Bool or graph proxy out)
.cs_passthrough <- c(
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

#' Path to the local CausalStructures.jl checkout
#'
#' Defaults to the `CausalStructures.jl/` directory bundled next to this
#' package's source, and can be overridden with the
#' `testpkg.causalstructures_path` option.
#'
#' @return Absolute path to the Julia package directory.
#' @keywords internal
cs_pkg_path <- function() {
  path <- getOption(
    "testpkg.causalstructures_path",
    file.path(
      dirname(system.file("DESCRIPTION", package = "testpkg")),
      "CausalStructures.jl"
    )
  )
  normalizePath(path, mustWork = TRUE)
}

# Current JuliaConnectoR socket connection, or NULL if Julia is not running.
# The connection object changes identity every time Julia is (re)started, so
# comparing it to the one saved at setup time detects a restart without an
# extra round trip.
cs_julia_con <- function() {
  tryCatch(
    get("pkgLocal", envir = asNamespace("JuliaConnectoR"))$con,
    error = function(e) NULL
  )
}

cs_session_ok <- function() {
  !is.null(.cs$module) &&
    !is.null(.cs$con) &&
    identical(.cs$con, cs_julia_con())
}

#' Start (or reuse) the Julia session with CausalStructures loaded
#'
#' Activates the local CausalStructures.jl project, instantiates its
#' dependencies, and imports the module. Called automatically by the
#' wrapper functions; call it yourself to pay the startup cost up front.
#'
#' If the Julia process died since setup (e.g. \pkg{JuliaConnectoR} kills it when
#' an R interrupt arrives mid-call), the session is set up again from
#' scratch. Graph proxies created before the restart are lost and must be
#' recreated.
#'
#' @return The imported Julia module (invisibly).
#' @export
#' @examples
#' if (JuliaConnectoR::juliaSetupOk()) {
#'   cs_setup()
#' }
cs_setup <- function() {
  if (cs_session_ok()) {
    return(invisible(.cs$module))
  }
  .cs$module <- NULL
  if (!JuliaConnectoR::juliaSetupOk()) {
    stop(
      "Julia is not available. Install Julia and make sure it is on the PATH."
    )
  }
  path <- cs_pkg_path()
  Pkg <- JuliaConnectoR::juliaImport("Pkg")
  Pkg$activate(path)
  Pkg$instantiate()
  .cs$module <- JuliaConnectoR::juliaImport("CausalStructures")
  .cs$Random <- JuliaConnectoR::juliaImport("Random")
  # All wrapper helpers are defined here in a single juliaEval call, rather
  # than one juliaEval per helper, so their definitions cost one round trip
  # in total instead of one per helper. Each helper then does its Symbol
  # conversion and string-joining Julia-side, so its own per-call round trip
  # carries plain Strings rather than paying R's ~15us-per-element cost
  # to deserialize character vectors.
  JuliaConnectoR::juliaEval(
    '
    import CausalStructures
    const _testpkg_CS = CausalStructures
    import NetworkLayout
    # A length-1 R character vector arrives in Julia as a scalar String
    _testpkg_syms(x) = x isa AbstractString ? [Symbol(x)] : Symbol.(x)
    _testpkg_join(names) = join(names, \'\\x1f\')
    _testpkg_names(x) = _testpkg_join(sort!(String.(collect(x))))
    _testpkg_opt(s) = s === nothing ? nothing : _testpkg_names(s)
    _testpkg_sets(sets) =
        isempty(sets) ? nothing : join((_testpkg_names(s) for s in sets), \'\\x1e\')

    _testpkg_cgraph(spec, class, simple) =
        _testpkg_CS.cgraph(spec; class = getfield(_testpkg_CS, Symbol(class)), simple = simple)
    function _testpkg_generate_graph(n, m, p, class, rng)
        kwargs = (
            m = m === nothing ? nothing : Int(m), p = p,
            class = getfield(_testpkg_CS, Symbol(class)),
        )
        rng === nothing ? _testpkg_CS.generate_graph(Int(n); kwargs...) :
        _testpkg_CS.generate_graph(rng, Int(n); kwargs...)
    end
    _testpkg_topological_sort(g) = _testpkg_join(String.(_testpkg_CS.topological_sort(g)))
    _testpkg_nodes(g) = _testpkg_join(String.(_testpkg_CS.nodes(g)))
    function _testpkg_exogenous_nodes(g, undirected_as_parents)
        result = g isa _testpkg_CS.AbstractPDAG ?
            _testpkg_CS.exogenous_nodes(g; undirected_as_parents = undirected_as_parents) :
            _testpkg_CS.exogenous_nodes(g)
        _testpkg_names(result)
    end
    for f in (:parents, :children, :ancestors, :descendants, :spouses, :markov_blanket)
        @eval $(Symbol(:_testpkg_, f))(g, node) =
            _testpkg_names(_testpkg_CS.$f(g, Symbol(node)))
    end
    _testpkg_neighbors(g, node, mode) =
        _testpkg_names(_testpkg_CS.neighbors(g, Symbol(node); mode = Symbol(mode)))
    for f in (:possible_ancestors, :possible_descendants, :anteriors, :posteriors)
        @eval $(Symbol(:_testpkg_, f))(g, node, open) =
            _testpkg_names(_testpkg_CS.$f(g, Symbol(node); open = open))
    end
    _testpkg_has_edge(g, x, y) = _testpkg_CS.has_edge(g, Symbol(x), Symbol(y))
    for f in (:d_separated, :m_separated)
        @eval $(Symbol(:_testpkg_, f))(g, x, y, given) =
            _testpkg_CS.$f(g, Symbol(x), Symbol(y), _testpkg_syms(given))
    end
    function _testpkg_minimal_separator(g, x, y, include, restrict)
        _testpkg_opt(_testpkg_CS.minimal_separator(g, Symbol(x), Symbol(y);
            include = _testpkg_syms(include),
            restrict = restrict === nothing ? nothing : _testpkg_syms(restrict)))
    end
    function _testpkg_adjustment_set(g, x, y, type)
        result = if g isa Union{_testpkg_CS.DAG,_testpkg_CS.AbstractPDAG}
            _testpkg_CS.adjustment_set(g, Symbol(x), Symbol(y); type = Symbol(type))
        else
            # AbstractAG (MAG, AG) has no `type` kwarg: always the smallest valid set.
            _testpkg_CS.adjustment_set(g, Symbol(x), Symbol(y))
        end
        _testpkg_opt(result)
    end
    function _testpkg_frontdoor_set(g, x, y, include, restrict)
        _testpkg_opt(_testpkg_CS.frontdoor_set(g, Symbol(x), Symbol(y);
            include = _testpkg_syms(include),
            restrict = restrict === nothing ? nothing : _testpkg_syms(restrict)))
    end
    _testpkg_is_valid_backdoor(g, x, y, z) =
        _testpkg_CS.is_valid_backdoor(g, Symbol(x), Symbol(y), _testpkg_syms(z))
    function _testpkg_all_backdoor_sets(g, x, y, minimal, max_size)
        _testpkg_sets(_testpkg_CS.all_backdoor_sets(g, Symbol(x), Symbol(y);
            minimal = minimal, max_size = Int(max_size)))
    end
    function _testpkg_all_frontdoor_sets(g, x, y, include, restrict)
        _testpkg_sets(_testpkg_CS.all_frontdoor_sets(g, Symbol(x), Symbol(y);
            include = _testpkg_syms(include),
            restrict = restrict === nothing ? nothing : _testpkg_syms(restrict)))
    end
    _testpkg_subgraph(g, nodes) = _testpkg_CS.subgraph(g, _testpkg_syms(nodes))
    _testpkg_edges(g) = join((_testpkg_join([String(e.src), String(e.dst)]) for e in _testpkg_CS.edges(g)), \'\\x1e\')
    _testpkg_edge_marks(g) = join((_testpkg_join([String(e.src), String(e.dst), string(e.src_end), string(e.dst_end)]) for e in _testpkg_CS.edges(g)), \'\\x1e\')
    _testpkg_is_valid_adjustment(g, x, y, z) =
        _testpkg_CS.is_valid_adjustment(g, Symbol(x), Symbol(y), _testpkg_syms(z))
    function _testpkg_all_adjustment_sets(g, x, y, minimal, max_size)
        _testpkg_sets(_testpkg_CS.all_adjustment_sets(g, Symbol(x), Symbol(y);
            minimal = minimal, max_size = Int(max_size)))
    end
    _testpkg_is_valid_frontdoor(g, x, y, z) =
        _testpkg_CS.is_valid_frontdoor(g, Symbol(x), Symbol(y), _testpkg_syms(z))
    function _testpkg_simulate_data(g, n, rng, standardize, coef_range, error_sd)
        kwargs = (
            samples = Int(n),
            standardize = standardize,
            coef_range = (Float64(coef_range[1]), Float64(coef_range[2])),
            error_sd = Float64(error_sd),
        )
        d = rng === nothing ? _testpkg_CS.simulate_data(g; kwargs...) :
            _testpkg_CS.simulate_data(rng, g; kwargs...)
        names = sort!(collect(keys(d)))
        hcat((d[nm] for nm in names)...)
    end
    _testpkg_enumerate_dags(g) = _testpkg_CS.enumerate_dags(g)
    _testpkg_markov_equivalent(g1, g2) = _testpkg_CS.markov_equivalent(g1, g2)
    _testpkg_is_valid_iv(g, x, y, z) =
        _testpkg_CS.is_valid_iv(g, Symbol(x), Symbol(y), _testpkg_syms(z))
    function _testpkg_all_iv_sets(g, x, y, minimal, max_size)
        _testpkg_sets(_testpkg_CS.all_iv_sets(g, Symbol(x), Symbol(y);
            minimal = minimal, max_size = Int(max_size)))
    end
    _testpkg_enumerate_mags(g) = _testpkg_CS.enumerate_mags(g)
    _testpkg_latent_project(g, latents) = _testpkg_CS.latent_project(g, _testpkg_syms(latents))
    _testpkg_exogenize(g, nodes) = _testpkg_CS.exogenize(g, _testpkg_syms(nodes))
    _testpkg_normalize_latent_structure(g, latents) =
        _testpkg_CS.normalize_latent_structure(g, _testpkg_syms(latents))
    _testpkg_condition_marginalize(g, cond_vars, marg_vars) =
        _testpkg_CS.condition_marginalize(g;
            cond_vars = _testpkg_syms(cond_vars), marg_vars = _testpkg_syms(marg_vars))
    _testpkg_spec_edges(spec) =
        filter(x -> x isa _testpkg_CS.CausalEdge, _testpkg_CS._parse_graph_string(spec))
    _testpkg_add_edges(g, spec) = _testpkg_CS.add_edges(g, _testpkg_spec_edges(spec)...)
    _testpkg_remove_edges(g, spec) = _testpkg_CS.remove_edges(g, _testpkg_spec_edges(spec)...)
    _testpkg_add_nodes(g, nodes) = _testpkg_CS.add_nodes(g, _testpkg_syms(nodes)...)
    _testpkg_remove_nodes(g, nodes) = _testpkg_CS.remove_nodes(g, _testpkg_syms(nodes)...)
    function _testpkg_reclass(g, class, simple)
        T = getfield(_testpkg_CS, Symbol(class))
        T === _testpkg_CS.UNKNOWN ? _testpkg_CS.reclass(g, T; simple = simple) :
        _testpkg_CS.reclass(g, T)
    end
    function _testpkg_layout(g, method)
        pts = _testpkg_CS.layout(g, Symbol(method))
        join((_testpkg_join([string(p[1]), string(p[2])]) for p in pts), \'\\x1e\')
    end
    nothing
  '
  )
  for (f in .cs_helpers) {
    .cs[[f]] <- JuliaConnectoR::juliaFun(paste0("_testpkg_", f))
  }
  for (f in .cs_passthrough) {
    .cs[[f]] <- JuliaConnectoR::juliaFun(paste0("CausalStructures.", f))
  }
  .cs$con <- cs_julia_con()
  invisible(.cs$module)
}

cs_fn <- function(name) {
  cs_setup()
  .cs[[name]]
}

# Builds a Julia RNG proxy from an integer seed, or NULL if seed is NULL.
# Currently uses base Random.jl (Random.Xoshiro); see .github/TODO.md for the
# planned switch to StableRNGs.jl for cross-Julia-version reproducibility.
cs_make_rng <- function(seed) {
  if (is.null(seed)) {
    return(NULL)
  }
  cs_setup()
  .cs$Random$Xoshiro(as.integer(seed))
}

cs_split <- function(x) {
  x <- as.character(x)
  if (identical(x, "")) character(0) else strsplit(x, "\x1f", fixed = TRUE)[[1]]
}

cs_split_sets <- function(x) {
  if (is.null(x)) {
    return(list())
  }
  x <- as.character(x)
  if (identical(x, "")) {
    return(list(character(0)))
  }
  lapply(strsplit(x, "\x1e", fixed = TRUE)[[1]], cs_split)
}

# Wrapper factories
cs_node_query <- function(name) {
  force(name)
  function(graph, node) cs_split(cs_fn(name)(graph, node))
}

cs_graph_fn <- function(name) {
  force(name)
  function(graph) cs_fn(name)(graph)
}

#' Shut down the Julia session
#'
#' @return Called for its side effect; returns `NULL` invisibly.
#' @export
#' @examples
#' if (JuliaConnectoR::juliaSetupOk()) {
#'   cs_setup()
#'   cs_stop()
#' }
cs_stop <- function() {
  .cs$module <- NULL
  .cs$con <- NULL
  JuliaConnectoR::stopJulia()
  invisible(NULL)
}
