# Benchmarks every testpkg wrapper against its caugi counterpart, using
# bench::mark(), for both Julia backends this package binds
# CausalStructures.jl through: JuliaConnectoR (cs_* wrappers, external Julia
# process over a socket) and JuliaCall (jc_* wrappers, R/juliacall/, Julia
# embedded in-process). See R/juliacall/jc-session.R for the JuliaCall port.
#
# Not part of the built package (listed in .Rbuildignore). Run with:
#   Rscript benchmark.R   (from the package root)
#
# The query benchmarks run all three sides on *comparable* graphs: a testpkg
# graph is generated once via JuliaConnectoR and converted to caugi with
# cs_to_caugi() (R's and Julia's RNGs consume randomness differently, so
# generating on both sides from the same seed produces different graphs, not
# comparable instances) - see cs_to_caugi()/caugi_to_cs() below - and
# separately, the same DSL spec / generate_graph() call is repeated through
# the JuliaCall backend to build an equivalent graph for the jc_* timings.
#
# caugi doesn't cover every testpkg operation. Where its exported name
# differs from the Julia one, the closest equivalent is used and noted below:
#   cs_exogenous_nodes()      -> caugi::exogenous()
#   cs_is_valid_adjustment()  -> caugi::is_valid_adjustment_admg()
#   cs_all_adjustment_sets()  -> caugi::all_adjustment_sets_admg()
# Functions with no caugi counterpart at all (dag_to_cpdag, ag_to_mag,
# mag_to_pag, mag_from_pag, frontdoor/IV identification, equivalence-class
# enumeration, possible_ancestors/possible_descendants, has_edge, reclass)
# are left out of the comparison.

pkgload::load_all(".", quiet = TRUE)

library(caugi)

n <- 1000L
p <- 0.25

# --- Graph conversion (benchmark-only helpers) --------------------------------
# Bridges a testpkg (Julia) graph proxy and a caugi graph so both sides of a
# benchmark can run on the identical graph. Not part of the package API: these
# add a couple of introspection-only Julia helpers scoped to this script.
cs_setup()
JuliaConnectoR::juliaEval(
  "
  _testpkg_bench_class(g) = string(nameof(typeof(g)))
  _testpkg_bench_edges_typed(g) =
      join((_testpkg_join([String(e.src), _testpkg_CS._edge_display(e), String(e.dst)])
            for e in _testpkg_CS.edges(g)), \"\\x1e\")
"
)
.bench_class <- JuliaConnectoR::juliaFun("_testpkg_bench_class")
.bench_edges_typed <- JuliaConnectoR::juliaFun("_testpkg_bench_edges_typed")

cs_to_caugi <- function(graph) {
  cls <- .bench_class(graph)
  ns <- cs_nodes(graph)
  raw <- .bench_edges_typed(graph)
  if (identical(raw, "")) {
    return(build(caugi::caugi(nodes = ns, class = cls)))
  }
  tokens <- strsplit(chartr("\x1f", "\x1e", raw), "\x1e", fixed = TRUE)[[1]]
  m <- matrix(tokens, ncol = 3, byrow = TRUE)
  build(caugi::caugi(
    from = m[, 1],
    edge = m[, 2],
    to = m[, 3],
    nodes = ns,
    class = cls
  ))
}

caugi_to_cs <- function(cg) {
  cls <- cg@graph_class
  ns <- caugi::nodes(cg)$name
  ed <- caugi::edges(cg)
  if (nrow(ed) == 0) {
    spec <- paste(ns, collapse = ", ")
  } else {
    edge_terms <- paste(ed$from, ed$edge, ed$to)
    iso <- setdiff(ns, union(ed$from, ed$to))
    spec <- paste(c(edge_terms, iso), collapse = ", ")
  }
  cs_cgraph(spec = spec, class = cls)
}

# --- Graphs ------------------------------------------------------------------
jdag <- cs_generate_graph(n, p = p, seed = 1405L)
cg <- cs_to_caugi(jdag)

node <- "V45"
x <- "V50"
y <- "V70"
z <- cs_adjustment_set(jdag, x, y)

spec_small <- "A --> X + Y, X --> M --> Y"
jdag_small <- cs_cgraph(spec = spec_small)
cdag_small <- build(caugi(A %-->% X + Y, X %-->% M, M %-->% Y, class = "DAG"))

jadmg_small <- cs_reclass(jdag_small, "ADMG")
cadmg_small <- build(caugi(A %-->% X + Y, X %-->% M, M %-->% Y, class = "ADMG"))

jpdag_small <- cs_cgraph(A %---% X, X %-->% Y, class = "PDAG")
cpdag_small <- build(caugi(A %---% X, X %-->% Y, class = "PDAG"))

# Same fixtures again through the JuliaCall backend (jc_*; see
# R/juliacall/jc-session.R). Not converted from/to caugi or from the
# JuliaConnectoR graphs above - built independently from the same DSL specs
# and generate_graph() call, since graph proxies aren't interchangeable
# across backends (each is its own embedded/external Julia process).
jjdag <- jc_generate_graph(n, p = p, seed = 1405L)
jz <- jc_adjustment_set(jjdag, x, y)

jjdag_small <- jc_cgraph(spec = spec_small)
jjadmg_small <- jc_reclass(jjdag_small, "ADMG")
jjpdag_small <- jc_cgraph(A %---% X, X %-->% Y, class = "PDAG")

# Warm-up
invisible(cs_cgraph(spec = spec_small))
invisible(cs_parents(jdag, node))
invisible(cs_topological_sort(jdag))
invisible(cs_d_separated(jdag, x, y, z))
invisible(cs_adjustment_set(jdag, x, y))
invisible(jc_cgraph(spec = spec_small))
invisible(jc_parents(jjdag, node))
invisible(jc_topological_sort(jjdag))
invisible(jc_d_separated(jjdag, x, y, jz))
invisible(jc_adjustment_set(jjdag, x, y))

run <- function(name, expr_julia, expr_caugi, expr_juliacall) {
  print(name)
  res <- bench::mark(
    JuliaConnectoR = expr_julia(),
    caugi = expr_caugi(),
    JuliaCall = expr_juliacall(),
    check = FALSE,
    min_iterations = 10
  )
  res$benchmark <- name
  res[, c("benchmark", "expression", "median", "itr/sec", "mem_alloc")]
}

results <- rbind(
  # --- Construction ------------------------------------------------------
  run(
    "cgraph (4-node DSL graph)",
    function() cs_cgraph(spec = spec_small),
    function() build(caugi(A %-->% X + Y, X %-->% M, M %-->% Y, class = "DAG")),
    function() jc_cgraph(spec = spec_small)
  ),
  run(
    "generate_graph (n=1000)",
    function() cs_generate_graph(n, p = p, seed = 1405L),
    function() build(generate_graph(n = n, p = p, class = "DAG", seed = 1405)),
    function() jc_generate_graph(n, p = p, seed = 1405L)
  ),

  # --- Graph-level queries -------------------------------------------------
  run(
    "nodes",
    function() cs_nodes(jdag),
    function() nodes(cg),
    function() jc_nodes(jjdag)
  ),
  run(
    "edges",
    function() cs_edges(jdag),
    function() edges(cg),
    function() jc_edges(jjdag)
  ),
  run(
    "topological_sort",
    function() cs_topological_sort(jdag),
    function() topological_sort(cg),
    function() jc_topological_sort(jjdag)
  ),
  run(
    "exogenous_nodes (caugi: exogenous)",
    function() cs_exogenous_nodes(jdag),
    function() exogenous(cg),
    function() jc_exogenous_nodes(jjdag)
  ),

  # --- Node-set queries ------------------------------------------------------
  run(
    "parents",
    function() cs_parents(jdag, node),
    function() parents(cg, node),
    function() jc_parents(jjdag, node)
  ),
  run(
    "children",
    function() cs_children(jdag, node),
    function() children(cg, node),
    function() jc_children(jjdag, node)
  ),
  run(
    "ancestors",
    function() cs_ancestors(jdag, node),
    function() ancestors(cg, node),
    function() jc_ancestors(jjdag, node)
  ),
  run(
    "descendants",
    function() cs_descendants(jdag, node),
    function() descendants(cg, node),
    function() jc_descendants(jjdag, node)
  ),
  run(
    "spouses (ADMG, 4-node graph)",
    function() cs_spouses(jadmg_small, "X"),
    function() spouses(cadmg_small, "X"),
    function() jc_spouses(jjadmg_small, "X")
  ),
  run(
    "neighbors",
    function() cs_neighbors(jdag, node),
    function() neighbors(cg, node),
    function() jc_neighbors(jjdag, node)
  ),
  run(
    "markov_blanket",
    function() cs_markov_blanket(jdag, node),
    function() markov_blanket(cg, node),
    function() jc_markov_blanket(jjdag, node)
  ),
  run(
    "anteriors",
    function() cs_anteriors(jdag, node),
    function() anteriors(cg, node),
    function() jc_anteriors(jjdag, node)
  ),
  run(
    "posteriors",
    function() cs_posteriors(jdag, node),
    function() posteriors(cg, node),
    function() jc_posteriors(jjdag, node)
  ),

  # --- Predicates ------------------------------------------------------------
  run(
    "is_dag",
    function() cs_is_dag(jdag),
    function() is_dag(cg),
    function() jc_is_dag(jjdag)
  ),
  run(
    "is_acyclic",
    function() cs_is_acyclic(jdag),
    function() is_acyclic(cg),
    function() jc_is_acyclic(jjdag)
  ),

  # --- Transformations ---------------------------------------------------
  run(
    "skeleton (4-node graph)",
    function() cs_skeleton(jdag_small),
    function() skeleton(cdag_small),
    function() jc_skeleton(jjdag_small)
  ),
  run(
    "moralize (4-node graph)",
    function() cs_moralize(jdag_small),
    function() moralize(cdag_small),
    function() jc_moralize(jjdag_small)
  ),
  run(
    "meek_closure (PDAG)",
    function() cs_meek_closure(jpdag_small),
    function() meek_closure(cpdag_small),
    function() jc_meek_closure(jjpdag_small)
  ),
  run(
    "dag_from_pdag (PDAG)",
    function() cs_dag_from_pdag(jpdag_small),
    function() dag_from_pdag(cpdag_small),
    function() jc_dag_from_pdag(jjpdag_small)
  ),
  run(
    "subgraph (4-node graph)",
    function() cs_subgraph(jdag_small, c("A", "X", "Y")),
    function() subgraph(cdag_small, c("A", "X", "Y")),
    function() jc_subgraph(jjdag_small, c("A", "X", "Y"))
  ),
  run(
    "latent_project (4-node graph)",
    function() cs_latent_project(jdag_small, "M"),
    function() latent_project(cdag_small, "M"),
    function() jc_latent_project(jjdag_small, "M")
  ),
  run(
    "exogenize (4-node graph)",
    function() cs_exogenize(jdag_small, "X"),
    function() exogenize(cdag_small, "X"),
    function() jc_exogenize(jjdag_small, "X")
  ),
  run(
    "normalize_latent_structure (4-node graph)",
    function() cs_normalize_latent_structure(jdag_small, "M"),
    function() normalize_latent_structure(cdag_small, "M"),
    function() jc_normalize_latent_structure(jjdag_small, "M")
  ),
  run(
    "condition_marginalize (4-node graph)",
    function() cs_condition_marginalize(jdag_small, marg_vars = "M"),
    function() condition_marginalize(cdag_small, marg_vars = "M"),
    function() jc_condition_marginalize(jjdag_small, marg_vars = "M")
  ),

  # --- Separation --------------------------------------------------------
  run(
    "d_separated",
    function() cs_d_separated(jdag, x, y, z),
    function() d_separated(cg, x, y, z),
    function() jc_d_separated(jjdag, x, y, jz)
  ),
  run(
    "m_separated",
    function() cs_m_separated(jdag, x, y, z),
    function() m_separated(cg, X = x, Y = y, Z = z),
    function() jc_m_separated(jjdag, x, y, jz)
  ),
  run(
    "minimal_separator",
    function() cs_minimal_separator(jdag, x, y),
    function() minimal_separator(cg, X = x, Y = y),
    function() jc_minimal_separator(jjdag, x, y)
  ),

  # --- Identification ------------------------------------------------------
  run(
    "adjustment_set (backdoor)",
    function() cs_adjustment_set(jdag, x, y),
    function() adjustment_set(cg, x, y, type = "backdoor"),
    function() jc_adjustment_set(jjdag, x, y)
  ),
  run(
    "is_valid_backdoor",
    function() cs_is_valid_backdoor(jdag, x, y, z),
    function() is_valid_backdoor(cg, X = x, Y = y, Z = z),
    function() jc_is_valid_backdoor(jjdag, x, y, jz)
  ),
  run(
    "all_backdoor_sets",
    function() cs_all_backdoor_sets(jdag_small, "X", "Y"),
    function() all_backdoor_sets(cdag_small, X = "X", Y = "Y"),
    function() jc_all_backdoor_sets(jjdag_small, "X", "Y")
  ),
  run(
    "is_valid_adjustment (caugi: is_valid_adjustment_admg, ADMG)",
    function() cs_is_valid_adjustment(jadmg_small, "X", "Y", "A"),
    function() is_valid_adjustment_admg(cadmg_small, X = "X", Y = "Y", Z = "A"),
    function() jc_is_valid_adjustment(jjadmg_small, "X", "Y", "A")
  ),
  run(
    "all_adjustment_sets (caugi: all_adjustment_sets_admg, ADMG)",
    function() cs_all_adjustment_sets(jadmg_small, "X", "Y"),
    function() all_adjustment_sets_admg(cadmg_small, X = "X", Y = "Y"),
    function() jc_all_adjustment_sets(jjadmg_small, "X", "Y")
  ),

  # --- Mutation ------------------------------------------------------------
  run(
    "add_edges (4-node graph)",
    function() cs_add_edges(jdag_small, A %-->% M),
    function() add_edges(cdag_small, from = "A", edge = "-->", to = "M"),
    function() jc_add_edges(jjdag_small, A %-->% M)
  ),
  run(
    "remove_edges (4-node graph)",
    function() cs_remove_edges(jdag_small, X %-->% M),
    function() remove_edges(cdag_small, from = "X", edge = "-->", to = "M"),
    function() jc_remove_edges(jjdag_small, X %-->% M)
  ),
  run(
    "add_nodes (4-node graph)",
    function() cs_add_nodes(jdag_small, "Z"),
    function() add_nodes(cdag_small, name = "Z"),
    function() jc_add_nodes(jjdag_small, "Z")
  ),
  run(
    "remove_nodes (4-node graph)",
    function() cs_remove_nodes(jdag_small, "A"),
    function() remove_nodes(cdag_small, name = "A"),
    function() jc_remove_nodes(jjdag_small, "A")
  ),

  # --- Data generation ---------------------------------------------------
  run(
    "simulate_data (n=100)",
    function() cs_simulate_data(jdag, 100, seed = 1L),
    function() simulate_data(cg, 100, seed = 1L),
    function() jc_simulate_data(jjdag, 100, seed = 1L)
  )
)

cat("\n\n=== Combined results ===\n")
print(results, n = nrow(results))

cs_stop()
jc_stop() # no-op by design; see R/juliacall/jc-session.R
