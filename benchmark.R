# Benchmarks every testpkg wrapper (CausalStructures.jl via JuliaCall)
# against its caugi counterpart, using bench::mark().
#
# Not part of the built package (listed in .Rbuildignore). Run with:
#   Rscript benchmark.R   (from the package root)
#
# The query benchmarks run both sides on the *same* graph: a testpkg graph is
# generated once and converted to caugi with to_caugi() (R's and Julia's
# RNGs consume randomness differently, so generating on both sides from the
# same seed produces different graphs, not comparable instances). See
# to_caugi()/caugi_to_cs() below.
#
# caugi doesn't cover every testpkg operation. Where its exported name
# differs from the Julia one, the closest equivalent is used and noted below:
#   exogenous_nodes()      -> caugi::exogenous()
#   is_valid_adjustment()  -> caugi::is_valid_adjustment_admg()
#   all_adjustment_sets()  -> caugi::all_adjustment_sets_admg()
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
setup()
JuliaCall::julia_command(
  '
begin
  _testpkg_bench_class(g) = string(nameof(typeof(g)))
  _testpkg_bench_edges_typed(g) =
      join((join([String(e.src), _testpkg_CS._edge_display(e), String(e.dst)], "\x1f")
            for e in _testpkg_CS.edges(g)), "\x1e")
end
'
)
.bench_class <- function(g) JuliaCall::julia_call("_testpkg_bench_class", g)
.bench_edges_typed <- function(g) {
  JuliaCall::julia_call("_testpkg_bench_edges_typed", g)
}

to_caugi <- function(graph) {
  cls <- .bench_class(graph)
  ns <- nodes(graph)
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
  cgraph(spec = spec, class = cls)
}

# --- Graphs ------------------------------------------------------------------
jdag <- generate_graph(n, p = p, seed = 1405L)
cg <- to_caugi(jdag)

node <- "V45"
x <- "V50"
y <- "V70"
z <- adjustment_set(jdag, x, y)

spec_small <- "A --> X + Y, X --> M --> Y"
jdag_small <- cgraph(spec = spec_small)
cdag_small <- build(caugi(A %-->% X + Y, X %-->% M, M %-->% Y, class = "DAG"))

jadmg_small <- reclass(jdag_small, "ADMG")
cadmg_small <- build(caugi(A %-->% X + Y, X %-->% M, M %-->% Y, class = "ADMG"))

jpdag_small <- cgraph(A %---% X, X %-->% Y, class = "PDAG")
cpdag_small <- build(caugi(A %---% X, X %-->% Y, class = "PDAG"))

# Warm-up
invisible(cgraph(spec = spec_small))
invisible(parents(jdag, node))
invisible(topological_sort(jdag))
invisible(d_separated(jdag, x, y, z))
invisible(adjustment_set(jdag, x, y))

run <- function(name, expr_julia, expr_caugi) {
  print(name)
  res <- bench::mark(
    julia = expr_julia(),
    caugi = expr_caugi(),
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
    function() cgraph(spec = spec_small),
    function() build(caugi(A %-->% X + Y, X %-->% M, M %-->% Y, class = "DAG"))
  ),
  run(
    "generate_graph (n=1000)",
    function() generate_graph(n, p = p, seed = 1405L),
    function() build(generate_graph(n = n, p = p, class = "DAG", seed = 1405))
  ),

  # --- Graph-level queries -------------------------------------------------
  run(
    "nodes",
    function() nodes(jdag),
    function() nodes(cg)
  ),
  run(
    "edges",
    function() edges(jdag),
    function() edges(cg)
  ),
  run(
    "topological_sort",
    function() topological_sort(jdag),
    function() topological_sort(cg)
  ),
  run(
    "exogenous_nodes (caugi: exogenous)",
    function() exogenous_nodes(jdag),
    function() exogenous(cg)
  ),

  # --- Node-set queries ------------------------------------------------------
  run(
    "parents",
    function() parents(jdag, node),
    function() parents(cg, node)
  ),
  run(
    "children",
    function() children(jdag, node),
    function() children(cg, node)
  ),
  run(
    "ancestors",
    function() ancestors(jdag, node),
    function() ancestors(cg, node)
  ),
  run(
    "descendants",
    function() descendants(jdag, node),
    function() descendants(cg, node)
  ),
  run(
    "spouses (ADMG, 4-node graph)",
    function() spouses(jadmg_small, "X"),
    function() spouses(cadmg_small, "X")
  ),
  run(
    "neighbors",
    function() neighbors(jdag, node),
    function() neighbors(cg, node)
  ),
  run(
    "markov_blanket",
    function() markov_blanket(jdag, node),
    function() markov_blanket(cg, node)
  ),
  run(
    "anteriors",
    function() anteriors(jdag, node),
    function() anteriors(cg, node)
  ),
  run(
    "posteriors",
    function() posteriors(jdag, node),
    function() posteriors(cg, node)
  ),

  # --- Predicates ------------------------------------------------------------
  run(
    "is_dag",
    function() is_dag(jdag),
    function() is_dag(cg)
  ),
  run(
    "is_acyclic",
    function() is_acyclic(jdag),
    function() is_acyclic(cg)
  ),

  # --- Transformations ---------------------------------------------------
  run(
    "skeleton (4-node graph)",
    function() skeleton(jdag_small),
    function() skeleton(cdag_small)
  ),
  run(
    "moralize (4-node graph)",
    function() moralize(jdag_small),
    function() moralize(cdag_small)
  ),
  run(
    "meek_closure (PDAG)",
    function() meek_closure(jpdag_small),
    function() meek_closure(cpdag_small)
  ),
  run(
    "dag_from_pdag (PDAG)",
    function() dag_from_pdag(jpdag_small),
    function() dag_from_pdag(cpdag_small)
  ),
  run(
    "subgraph (4-node graph)",
    function() subgraph(jdag_small, c("A", "X", "Y")),
    function() subgraph(cdag_small, c("A", "X", "Y"))
  ),
  run(
    "latent_project (4-node graph)",
    function() latent_project(jdag_small, "M"),
    function() latent_project(cdag_small, "M")
  ),
  run(
    "exogenize (4-node graph)",
    function() exogenize(jdag_small, "X"),
    function() exogenize(cdag_small, "X")
  ),
  run(
    "normalize_latent_structure (4-node graph)",
    function() normalize_latent_structure(jdag_small, "M"),
    function() normalize_latent_structure(cdag_small, "M")
  ),
  run(
    "condition_marginalize (4-node graph)",
    function() condition_marginalize(jdag_small, marg_vars = "M"),
    function() condition_marginalize(cdag_small, marg_vars = "M")
  ),

  # --- Separation --------------------------------------------------------
  run(
    "d_separated",
    function() d_separated(jdag, x, y, z),
    function() d_separated(cg, x, y, z)
  ),
  run(
    "m_separated",
    function() m_separated(jdag, x, y, z),
    function() m_separated(cg, X = x, Y = y, Z = z)
  ),
  run(
    "minimal_separator",
    function() minimal_separator(jdag, x, y),
    function() minimal_separator(cg, X = x, Y = y)
  ),

  # --- Identification ------------------------------------------------------
  run(
    "adjustment_set (backdoor)",
    function() adjustment_set(jdag, x, y),
    function() adjustment_set(cg, x, y, type = "backdoor")
  ),
  run(
    "is_valid_backdoor",
    function() is_valid_backdoor(jdag, x, y, z),
    function() is_valid_backdoor(cg, X = x, Y = y, Z = z)
  ),
  run(
    "all_backdoor_sets",
    function() all_backdoor_sets(jdag_small, "X", "Y"),
    function() all_backdoor_sets(cdag_small, X = "X", Y = "Y")
  ),
  run(
    "is_valid_adjustment (caugi: is_valid_adjustment_admg, ADMG)",
    function() is_valid_adjustment(jadmg_small, "X", "Y", "A"),
    function() is_valid_adjustment_admg(cadmg_small, X = "X", Y = "Y", Z = "A")
  ),
  run(
    "all_adjustment_sets (caugi: all_adjustment_sets_admg, ADMG)",
    function() all_adjustment_sets(jadmg_small, "X", "Y"),
    function() all_adjustment_sets_admg(cadmg_small, X = "X", Y = "Y")
  ),

  # --- Mutation ------------------------------------------------------------
  run(
    "add_edges (4-node graph)",
    function() add_edges(jdag_small, A %-->% M),
    function() add_edges(cdag_small, from = "A", edge = "-->", to = "M")
  ),
  run(
    "remove_edges (4-node graph)",
    function() remove_edges(jdag_small, X %-->% M),
    function() remove_edges(cdag_small, from = "X", edge = "-->", to = "M")
  ),
  run(
    "add_nodes (4-node graph)",
    function() add_nodes(jdag_small, "Z"),
    function() add_nodes(cdag_small, name = "Z")
  ),
  run(
    "remove_nodes (4-node graph)",
    function() remove_nodes(jdag_small, "A"),
    function() remove_nodes(cdag_small, name = "A")
  ),

  # --- Data generation ---------------------------------------------------
  run(
    "simulate_data (n=100)",
    function() simulate_data(jdag, 100, seed = 1L),
    function() simulate_data(cg, 100, seed = 1L)
  )
)

print(results, n = nrow(results))
