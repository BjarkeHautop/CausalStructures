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
  "enumerate_mags"
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
  "count_dags"
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
#' If the Julia process died since setup (e.g. JuliaConnectoR kills it when
#' an R interrupt arrives mid-call), the session is set up again from
#' scratch. Graph proxies created before the restart are lost and must be
#' recreated.
#'
#' @return The imported Julia module (invisibly).
#' @export
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
  JuliaConnectoR::juliaEval(
    '
    import CausalStructures
    const _testpkg_CS = CausalStructures
    # A length-1 R character vector arrives in Julia as a scalar String
    _testpkg_syms(x) = x isa AbstractString ? [Symbol(x)] : Symbol.(x)
    _testpkg_join(names) = join(names, \'\\x1f\')
    _testpkg_names(x) = _testpkg_join(sort!(String.(collect(x))))
    _testpkg_opt(s) = s === nothing ? nothing : _testpkg_names(s)
    _testpkg_sets(sets) =
        isempty(sets) ? nothing : join((_testpkg_names(s) for s in sets), \'\\x1e\')

    _testpkg_cgraph(spec, class) =
        _testpkg_CS.cgraph(spec; class = getfield(_testpkg_CS, Symbol(class)))
    function _testpkg_generate_graph(n, m, p, class, seed)
        _testpkg_CS.generate_graph(Int(n);
            m = m === nothing ? nothing : Int(m), p = p,
            class = getfield(_testpkg_CS, Symbol(class)),
            seed = seed === nothing ? nothing : Int(seed))
    end
    _testpkg_topological_sort(g) = _testpkg_join(String.(_testpkg_CS.topological_sort(g)))
    _testpkg_nodes(g) = _testpkg_join(String.(_testpkg_CS.nodes(g)))
    _testpkg_exogenous_nodes(g) = _testpkg_names(_testpkg_CS.exogenous_nodes(g))
    for f in (:parents, :children, :ancestors, :descendants, :spouses,
              :neighbors, :markov_blanket, :possible_ancestors,
              :possible_descendants, :anteriors, :posteriors)
        @eval $(Symbol(:_testpkg_, f))(g, node) =
            _testpkg_names(_testpkg_CS.$f(g, Symbol(node)))
    end
    _testpkg_has_edge(g, x, y) = _testpkg_CS.has_edge(g, Symbol(x), Symbol(y))
    for f in (:d_separated, :m_separated)
        @eval $(Symbol(:_testpkg_, f))(g, x, y, given) =
            _testpkg_CS.$f(g, Symbol(x), Symbol(y), _testpkg_syms(given))
    end
    _testpkg_minimal_separator(g, x, y) =
        _testpkg_opt(_testpkg_CS.minimal_separator(g, Symbol(x), Symbol(y)))
    _testpkg_adjustment_set(g, x, y) =
        _testpkg_opt(_testpkg_CS.adjustment_set(g, Symbol(x), Symbol(y)))
    _testpkg_frontdoor_set(g, x, y) =
        _testpkg_opt(_testpkg_CS.frontdoor_set(g, Symbol(x), Symbol(y)))
    _testpkg_is_valid_backdoor(g, x, y, z) =
        _testpkg_CS.is_valid_backdoor(g, Symbol(x), Symbol(y), _testpkg_syms(z))
    _testpkg_all_backdoor_sets(g, x, y) =
        _testpkg_sets(_testpkg_CS.all_backdoor_sets(g, Symbol(x), Symbol(y)))
    _testpkg_all_frontdoor_sets(g, x, y) =
        _testpkg_sets(_testpkg_CS.all_frontdoor_sets(g, Symbol(x), Symbol(y)))
    _testpkg_subgraph(g, nodes) = _testpkg_CS.subgraph(g, _testpkg_syms(nodes))
    _testpkg_edges(g) = join((_testpkg_join([String(e.src), String(e.dst)]) for e in _testpkg_CS.edges(g)), \'\\x1e\')
    _testpkg_is_valid_adjustment(g, x, y, z) =
        _testpkg_CS.is_valid_adjustment(g, Symbol(x), Symbol(y), _testpkg_syms(z))
    _testpkg_all_adjustment_sets(g, x, y) =
        _testpkg_sets(_testpkg_CS.all_adjustment_sets(g, Symbol(x), Symbol(y)))
    _testpkg_is_valid_frontdoor(g, x, y, z) =
        _testpkg_CS.is_valid_frontdoor(g, Symbol(x), Symbol(y), _testpkg_syms(z))
    function _testpkg_simulate_data(g, n, seed)
        if seed === nothing
            return _testpkg_CS.simulate_data(g; samples = Int(n))
        else
            return _testpkg_CS.simulate_data(g; samples = Int(n), seed = Int(seed))
        end
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

# cs_module <- function() {
#  cs_setup()
#  .cs$module
# }

cs_fn <- function(name) {
  cs_setup()
  .cs[[name]]
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

# --- Construction ------------------------------------------------------------

#' Create a causal graph
#'
#' Builds a graph from CausalStructures.jl's string DSL, e.g.
#' `"A --> X + Y, X --> M --> Y"`.
#'
#' @param spec Graph specification string.
#' @param class Graph class, e.g. `"DAG"`, `"PDAG"`, `"CPDAG"`, `"ADMG"`,
#'   `"MAG"`, `"UG"`.
#' @return A Julia proxy object representing the graph.
#' @export
#' @examples
#' \dontrun{
#' dag <- cs_cgraph("A --> X + Y, X --> M --> Y")
#' }
cs_cgraph <- function(spec, class = "DAG") {
  cs_fn("cgraph")(spec, class)
}

#' Generate a random graph
#'
#' @param n Number of nodes.
#' @param m Number of edges (supply exactly one of `m` and `p`).
#' @param p Edge probability (supply exactly one of `m` and `p`).
#' @param class Graph class: `"DAG"` or `"CPDAG"`.
#' @param seed Optional integer seed for reproducibility.
#' @return A Julia proxy object representing the graph.
#' @export
cs_generate_graph <- function(
  n,
  m = NULL,
  p = NULL,
  class = "DAG",
  seed = NULL
) {
  cs_fn("generate_graph")(as.integer(n), m, p, class, seed)
}

# --- Graph-level queries -----------------------------------------------------

#' Graph-level node queries
#'
#' `cs_nodes()` returns all node names (in graph order),
#' `cs_topological_sort()` a topological ordering, and
#' `cs_exogenous_nodes()` the nodes without parents.
#'
#' @param graph A graph created with [cs_cgraph()].
#' @return Character vector of node names.
#' @name cs-graph-queries
NULL

#' @rdname cs-graph-queries
#' @export
cs_nodes <- function(graph) {
  cs_split(cs_fn("nodes")(graph))
}

#' @rdname cs-graph-queries
#' @export
cs_topological_sort <- function(graph) {
  cs_split(cs_fn("topological_sort")(graph))
}

#' @rdname cs-graph-queries
#' @export
cs_exogenous_nodes <- function(graph) {
  cs_split(cs_fn("exogenous_nodes")(graph))
}

#' Test whether two nodes are adjacent
#'
#' @param graph A graph created with [cs_cgraph()].
#' @param x,y Node names.
#' @return `TRUE` if the graph has any edge between `x` and `y`,
#'   regardless of direction.
#' @export
cs_has_edge <- function(graph, x, y) {
  cs_fn("has_edge")(graph, x, y)
}

#' Get all edges in a graph
#'
#' @param graph A graph created with [cs_cgraph()].
#' @return A matrix with 2 columns (source, target) and one row per edge,
#'   or an empty matrix if the graph has no edges.
#' @export
cs_edges <- function(graph) {
  res <- cs_fn("edges")(graph)
  if (identical(res, "")) {
    return(matrix(character(), nrow = 0, ncol = 2))
  }
  edges_list <- strsplit(res, "\x1e", fixed = TRUE)[[1]]
  pairs <- lapply(edges_list, function(e) cs_split(e))
  do.call(rbind, pairs)
}

# --- Node-set queries --------------------------------------------------------

#' Node-set queries
#'
#' Relatives of a node: `cs_parents()`, `cs_children()`, `cs_ancestors()`,
#' `cs_descendants()`, `cs_spouses()`, `cs_neighbors()`,
#' `cs_markov_blanket()`, `cs_possible_ancestors()`,
#' `cs_possible_descendants()`, `cs_anteriors()`, and `cs_posteriors()`.
#'
#' @param graph A graph created with [cs_cgraph()].
#' @param node Node name.
#' @return Sorted character vector of node names.
#' @name cs-node-queries
NULL

#' @rdname cs-node-queries
#' @export
cs_parents <- cs_node_query("parents")

#' @rdname cs-node-queries
#' @export
cs_children <- cs_node_query("children")

#' @rdname cs-node-queries
#' @export
cs_ancestors <- cs_node_query("ancestors")

#' @rdname cs-node-queries
#' @export
cs_descendants <- cs_node_query("descendants")

#' @rdname cs-node-queries
#' @export
cs_spouses <- cs_node_query("spouses")

#' @rdname cs-node-queries
#' @export
cs_neighbors <- cs_node_query("neighbors")

#' @rdname cs-node-queries
#' @export
cs_markov_blanket <- cs_node_query("markov_blanket")

#' @rdname cs-node-queries
#' @export
cs_possible_ancestors <- cs_node_query("possible_ancestors")

#' @rdname cs-node-queries
#' @export
cs_possible_descendants <- cs_node_query("possible_descendants")

#' @rdname cs-node-queries
#' @export
cs_anteriors <- cs_node_query("anteriors")

#' @rdname cs-node-queries
#' @export
cs_posteriors <- cs_node_query("posteriors")


# --- Graph class predicates --------------------------------------------------

#' Graph class predicates
#'
#' Test which class a graph belongs to (`cs_is_dag()`, `cs_is_pdag()`,
#' `cs_is_cpdag()`, `cs_is_mpdag()`, `cs_is_ug()`, `cs_is_admg()`,
#' `cs_is_ag()`, `cs_is_mag()`, `cs_is_pag()`) or structural properties
#' (`cs_is_simple()`, `cs_is_acyclic()`).
#'
#' @param graph A graph created with [cs_cgraph()].
#' @return A logical scalar.
#' @name cs-predicates
NULL

#' @rdname cs-predicates
#' @export
cs_is_dag <- cs_graph_fn("is_dag")

#' @rdname cs-predicates
#' @export
cs_is_pdag <- cs_graph_fn("is_pdag")

#' @rdname cs-predicates
#' @export
cs_is_cpdag <- cs_graph_fn("is_cpdag")

#' @rdname cs-predicates
#' @export
cs_is_mpdag <- cs_graph_fn("is_mpdag")

#' @rdname cs-predicates
#' @export
cs_is_ug <- cs_graph_fn("is_ug")

#' @rdname cs-predicates
#' @export
cs_is_admg <- cs_graph_fn("is_admg")

#' @rdname cs-predicates
#' @export
cs_is_ag <- cs_graph_fn("is_ag")

#' @rdname cs-predicates
#' @export
cs_is_mag <- cs_graph_fn("is_mag")

#' @rdname cs-predicates
#' @export
cs_is_pag <- cs_graph_fn("is_pag")

#' @rdname cs-predicates
#' @export
cs_is_simple <- cs_graph_fn("is_simple")

#' @rdname cs-predicates
#' @export
cs_is_acyclic <- cs_graph_fn("is_acyclic")

# --- Transformations ---------------------------------------------------------

#' Graph transformations
#'
#' `cs_skeleton()` drops edge marks, `cs_moralize()` moralizes a DAG,
#' `cs_dag_to_cpdag()` and `cs_dag_from_pdag()` convert between equivalence
#' classes, and `cs_meek_closure()` applies Meek's rules. All return a new
#' graph proxy; the input graph is unchanged.
#'
#' @param graph A graph created with [cs_cgraph()].
#' @return A Julia proxy object representing the transformed graph.
#' @name cs-transforms
NULL

#' @rdname cs-transforms
#' @export
cs_skeleton <- cs_graph_fn("skeleton")

#' @rdname cs-transforms
#' @export
cs_moralize <- cs_graph_fn("moralize")

#' @rdname cs-transforms
#' @export
cs_dag_to_cpdag <- cs_graph_fn("dag_to_cpdag")

#' @rdname cs-transforms
#' @export
cs_dag_from_pdag <- cs_graph_fn("dag_from_pdag")

#' @rdname cs-transforms
#' @export
cs_meek_closure <- cs_graph_fn("meek_closure")

#' @rdname cs-transforms
#' @export
cs_dag_to_mpdag <- cs_graph_fn("dag_to_mpdag")

#' Induced subgraph
#'
#' @param graph A graph created with [cs_cgraph()].
#' @param nodes Character vector of node names to keep.
#' @return A Julia proxy object representing the subgraph.
#' @export
cs_subgraph <- function(graph, nodes) {
  cs_fn("subgraph")(graph, as.character(nodes))
}

# --- Separation --------------------------------------------------------------

#' Test d-separation
#'
#' @param graph A graph created with [cs_cgraph()].
#' @param x,y Node names.
#' @param given Character vector of conditioning node names (may be empty).
#' @return `TRUE` if `x` and `y` are d-separated given `given`.
#' @export
cs_d_separated <- function(graph, x, y, given = character()) {
  cs_fn("d_separated")(graph, x, y, as.character(given))
}

#' Test m-separation
#'
#' @inheritParams cs_d_separated
#' @return `TRUE` if `x` and `y` are m-separated given `given`.
#' @export
cs_m_separated <- function(graph, x, y, given = character()) {
  cs_fn("m_separated")(graph, x, y, as.character(given))
}

#' Find a minimal separator
#'
#' @param graph A graph created with [cs_cgraph()].
#' @param x,y Node names.
#' @return Character vector with a minimal separating set, or `NULL` if none
#'   exists.
#' @export
cs_minimal_separator <- function(graph, x, y) {
  res <- cs_fn("minimal_separator")(graph, x, y)
  if (is.null(res)) NULL else cs_split(res)
}

# --- Causal identification ---------------------------------------------------

#' Find a backdoor adjustment set
#'
#' @param graph A graph created with [cs_cgraph()].
#' @param x,y Exposure and outcome node names.
#' @return Character vector with a valid adjustment set, or `NULL` if none
#'   exists.
#' @export
cs_adjustment_set <- function(graph, x, y) {
  res <- cs_fn("adjustment_set")(graph, x, y)
  if (is.null(res)) NULL else cs_split(res)
}

#' Find a frontdoor adjustment set
#'
#' @inheritParams cs_adjustment_set
#' @return Character vector with a valid frontdoor set, or `NULL` if none
#'   exists.
#' @export
cs_frontdoor_set <- function(graph, x, y) {
  res <- cs_fn("frontdoor_set")(graph, x, y)
  if (is.null(res)) NULL else cs_split(res)
}

#' Validate a backdoor adjustment set
#'
#' @param graph A graph created with [cs_cgraph()].
#' @param x,y Exposure and outcome node names.
#' @param given Character vector of adjustment node names (may be empty).
#' @return `TRUE` if `given` satisfies the backdoor criterion.
#' @export
cs_is_valid_backdoor <- function(graph, x, y, given = character()) {
  cs_fn("is_valid_backdoor")(graph, x, y, as.character(given))
}

#' Enumerate adjustment sets
#'
#' `cs_all_backdoor_sets()` lists all minimal backdoor adjustment sets;
#' `cs_all_frontdoor_sets()` lists all frontdoor sets.
#'
#' @param graph A graph created with [cs_cgraph()].
#' @param x,y Exposure and outcome node names.
#' @return List of character vectors (empty list if none exist).
#' @name cs-all-sets
NULL

#' @rdname cs-all-sets
#' @export
cs_all_backdoor_sets <- function(graph, x, y) {
  cs_split_sets(cs_fn("all_backdoor_sets")(graph, x, y))
}

#' @rdname cs-all-sets
#' @export
cs_all_frontdoor_sets <- function(graph, x, y) {
  cs_split_sets(cs_fn("all_frontdoor_sets")(graph, x, y))
}

#' Validate an adjustment set
#'
#' @param graph A graph created with [cs_cgraph()].
#' @param x,y Exposure and outcome node names.
#' @param given Character vector of adjustment node names (may be empty).
#' @return `TRUE` if `given` satisfies the adjustment criterion for
#'   identifying the causal effect of `x` on `y`.
#' @export
cs_is_valid_adjustment <- function(graph, x, y, given = character()) {
  cs_fn("is_valid_adjustment")(graph, x, y, as.character(given))
}

#' Enumerate all valid adjustment sets
#'
#' @param graph A graph created with [cs_cgraph()].
#' @param x,y Exposure and outcome node names.
#' @return List of character vectors (empty list if none exist).
#' @export
cs_all_adjustment_sets <- function(graph, x, y) {
  cs_split_sets(cs_fn("all_adjustment_sets")(graph, x, y))
}

#' Validate a frontdoor criterion set
#'
#' @param graph A graph created with [cs_cgraph()].
#' @param x,y Exposure and outcome node names.
#' @param given Character vector of conditioning node names (may be empty).
#' @return `TRUE` if the configuration satisfies the frontdoor criterion.
#' @export
cs_is_valid_frontdoor <- function(graph, x, y, given = character()) {
  cs_fn("is_valid_frontdoor")(graph, x, y, as.character(given))
}

#' Validate instrumental variables
#'
#' Tests whether a set of variables are valid instruments for identifying
#' the causal effect of exposure `x` on outcome `y`.
#'
#' @param graph A graph created with [cs_cgraph()].
#' @param x,y Exposure and outcome node names.
#' @param z Character vector of instrument node names.
#' @return `TRUE` if `z` satisfies the instrumental variable criterion.
#' @export
cs_is_valid_iv <- function(graph, x, y, z = character()) {
  cs_fn("is_valid_iv")(graph, x, y, as.character(z))
}

#' Enumerate all valid instrumental variable sets
#'
#' Finds all minimal (or all) sets of valid instruments for identifying
#' the causal effect of `x` on `y`.
#'
#' @param graph A graph created with [cs_cgraph()].
#' @param x,y Exposure and outcome node names.
#' @param minimal If `TRUE` (default), return only minimal sets.
#' @param max_size Maximum number of instruments to consider.
#' @return List of character vectors (empty list if none exist).
#' @export
cs_all_iv_sets <- function(graph, x, y, minimal = TRUE, max_size = 3) {
  cs_split_sets(cs_fn("all_iv_sets")(graph, x, y, minimal, max_size))
}

# --- Equivalence classes and counts ------------------------------------------

#' Equivalence class analysis
#'
#' `cs_count_dags()` returns the count of distinct DAGs in a Markov equivalence
#' class represented by a CPDAG. `cs_enumerate_dags()` returns all DAGs in the
#' class. `cs_markov_equivalent()` tests whether two graphs are Markov equivalent.
#'
#' @param graph A graph created with [cs_cgraph()], typically a CPDAG.
#' @param g1,g2 Graphs to compare.
#' @return For `cs_count_dags()`, an integer count. For `cs_enumerate_dags()`,
#'   a list of DAG proxies. For `cs_markov_equivalent()`, a logical scalar.
#' @name cs-equivalence
NULL

#' @rdname cs-equivalence
#' @export
cs_count_dags <- cs_graph_fn("count_dags")

#' @rdname cs-equivalence
#' @export
cs_enumerate_dags <- function(graph) {
  cs_fn("enumerate_dags")(graph)
}

#' @rdname cs-equivalence
#' @export
cs_markov_equivalent <- function(g1, g2) {
  cs_fn("markov_equivalent")(g1, g2)
}

#' Enumerate MAGs in a PAG equivalence class
#'
#' Enumerates all Markov equivalent MAGs in the equivalence class
#' represented by a PAG (Partial Ancestral Graph).
#'
#' @param graph A PAG (partially ancestral graph) created with [cs_cgraph()].
#' @return A Julia proxy list of MAGs in the equivalence class.
#' @export
cs_enumerate_mags <- function(graph) {
  cs_fn("enumerate_mags")(graph)
}

# --- Data generation -------------------------------------------------------

#' Simulate data from a DAG
#'
#' Generates random data conforming to the causal structure of a DAG.
#' Edges receive random coefficients, and nodes receive random noise.
#'
#' @param graph A DAG created with [cs_cgraph()].
#' @param n Number of samples to generate.
#' @param seed Optional integer seed for reproducibility.
#' @return A data frame with `n` rows (samples) and one column per node.
#' @export
cs_simulate_data <- function(graph, n, seed = NULL) {
  cs_fn("simulate_data")(graph, n, seed)
}

# --- Session management ------------------------------------------------------

#' Shut down the Julia session
#'
#' @return Called for its side effect; returns `NULL` invisibly.
#' @export
cs_stop <- function() {
  .cs$module <- NULL
  .cs$con <- NULL
  JuliaConnectoR::stopJulia()
  invisible(NULL)
}
