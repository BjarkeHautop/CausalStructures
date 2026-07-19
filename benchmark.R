# Benchmarks every testpkg wrapper (CausalStructures.jl via JuliaConnectoR)
# against its caugi counterpart, using bench::mark().
#
# Not part of the built package (listed in .Rbuildignore). Run with:
#   Rscript benchmark.R   (from the package root)
#
# Note: the query benchmarks use a random DAG with the same n, p, and seed on
# both sides, but the R and Julia RNGs differ, so the two graphs are not
# identical -- comparable in size/density only.
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

# --- Graphs ------------------------------------------------------------------
cs_setup()
jdag <- cs_generate_graph(n, p = p, seed = 1405L)

cg <- generate_graph(n = n, p = p, class = "DAG", seed = 1405)
cg <- build(cg)

node <- "V45"
x <- "V50"
y <- "V70"
z <- cs_adjustment_set(jdag, x, y)

spec_small <- "A --> X + Y, X --> M --> Y"
jdag_small <- cs_cgraph(spec_small)
cdag_small <- build(caugi(A %-->% X + Y, X %-->% M, M %-->% Y, class = "DAG"))

jadmg_small <- cs_reclass(jdag_small, "ADMG")
cadmg_small <- build(caugi(A %-->% X + Y, X %-->% M, M %-->% Y, class = "ADMG"))

jpdag_small <- cs_cgraph("A --- X, X --> Y", class = "PDAG")
cpdag_small <- build(caugi(A %---% X, X %-->% Y, class = "PDAG"))

# Warm-up
invisible(cs_cgraph(spec_small))
invisible(cs_parents(jdag, node))
invisible(cs_topological_sort(jdag))
invisible(cs_d_separated(jdag, x, y, z))
invisible(cs_adjustment_set(jdag, x, y))

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
    function() cs_cgraph(spec_small),
    function() build(caugi(A %-->% X + Y, X %-->% M, M %-->% Y, class = "DAG"))
  ),
  run(
    "generate_graph (n=1000)",
    function() cs_generate_graph(n, p = p, seed = 1405L),
    function() build(generate_graph(n = n, p = p, class = "DAG", seed = 1405))
  ),

  # --- Graph-level queries -------------------------------------------------
  run(
    "nodes",
    function() cs_nodes(jdag),
    function() nodes(cg)
  ),
  run(
    "edges",
    function() cs_edges(jdag),
    function() edges(cg)
  ),
  run(
    "topological_sort",
    function() cs_topological_sort(jdag),
    function() topological_sort(cg)
  ),
  run(
    "exogenous_nodes (caugi: exogenous)",
    function() cs_exogenous_nodes(jdag),
    function() exogenous(cg)
  ),

  # --- Node-set queries ------------------------------------------------------
  run(
    "parents",
    function() cs_parents(jdag, node),
    function() parents(cg, node)
  ),
  run(
    "children",
    function() cs_children(jdag, node),
    function() children(cg, node)
  ),
  run(
    "ancestors",
    function() cs_ancestors(jdag, node),
    function() ancestors(cg, node)
  ),
  run(
    "descendants",
    function() cs_descendants(jdag, node),
    function() descendants(cg, node)
  ),
  run(
    "spouses (ADMG, 4-node graph)",
    function() cs_spouses(jadmg_small, "X"),
    function() spouses(cadmg_small, "X")
  ),
  run(
    "neighbors",
    function() cs_neighbors(jdag, node),
    function() neighbors(cg, node)
  ),
  run(
    "markov_blanket",
    function() cs_markov_blanket(jdag, node),
    function() markov_blanket(cg, node)
  ),
  run(
    "anteriors",
    function() cs_anteriors(jdag, node),
    function() anteriors(cg, node)
  ),
  run(
    "posteriors",
    function() cs_posteriors(jdag, node),
    function() posteriors(cg, node)
  ),

  # --- Predicates ------------------------------------------------------------
  run(
    "is_dag",
    function() cs_is_dag(jdag),
    function() is_dag(cg)
  ),
  run(
    "is_acyclic",
    function() cs_is_acyclic(jdag),
    function() is_acyclic(cg)
  ),

  # --- Transformations ---------------------------------------------------
  run(
    "skeleton (4-node graph)",
    function() cs_skeleton(jdag_small),
    function() skeleton(cdag_small)
  ),
  run(
    "moralize (4-node graph)",
    function() cs_moralize(jdag_small),
    function() moralize(cdag_small)
  ),
  run(
    "meek_closure (PDAG)",
    function() cs_meek_closure(jpdag_small),
    function() meek_closure(cpdag_small)
  ),
  run(
    "dag_from_pdag (PDAG)",
    function() cs_dag_from_pdag(jpdag_small),
    function() dag_from_pdag(cpdag_small)
  ),
  run(
    "subgraph (4-node graph)",
    function() cs_subgraph(jdag_small, c("A", "X", "Y")),
    function() subgraph(cdag_small, c("A", "X", "Y"))
  ),
  run(
    "latent_project (4-node graph)",
    function() cs_latent_project(jdag_small, "M"),
    function() latent_project(cdag_small, "M")
  ),
  run(
    "exogenize (4-node graph)",
    function() cs_exogenize(jdag_small, "X"),
    function() exogenize(cdag_small, "X")
  ),
  run(
    "normalize_latent_structure (4-node graph)",
    function() cs_normalize_latent_structure(jdag_small, "M"),
    function() normalize_latent_structure(cdag_small, "M")
  ),
  run(
    "condition_marginalize (4-node graph)",
    function() cs_condition_marginalize(jdag_small, marg_vars = "M"),
    function() condition_marginalize(cdag_small, marg_vars = "M")
  ),

  # --- Separation --------------------------------------------------------
  run(
    "d_separated",
    function() cs_d_separated(jdag, x, y, z),
    function() d_separated(cg, x, y, z)
  ),
  run(
    "m_separated",
    function() cs_m_separated(jdag, x, y, z),
    function() m_separated(cg, X = x, Y = y, Z = z)
  ),
  run(
    "minimal_separator",
    function() cs_minimal_separator(jdag, x, y),
    function() minimal_separator(cg, X = x, Y = y)
  ),

  # --- Identification ------------------------------------------------------
  run(
    "adjustment_set (backdoor)",
    function() cs_adjustment_set(jdag, x, y),
    function() adjustment_set(cg, x, y, type = "backdoor")
  ),
  run(
    "is_valid_backdoor",
    function() cs_is_valid_backdoor(jdag, x, y, z),
    function() is_valid_backdoor(cg, X = x, Y = y, Z = z)
  ),
  run(
    "all_backdoor_sets",
    function() cs_all_backdoor_sets(jdag_small, "X", "Y"),
    function() all_backdoor_sets(cdag_small, X = "X", Y = "Y")
  ),
  run(
    "is_valid_adjustment (caugi: is_valid_adjustment_admg, ADMG)",
    function() cs_is_valid_adjustment(jadmg_small, "X", "Y", "A"),
    function() is_valid_adjustment_admg(cadmg_small, X = "X", Y = "Y", Z = "A")
  ),
  run(
    "all_adjustment_sets (caugi: all_adjustment_sets_admg, ADMG)",
    function() cs_all_adjustment_sets(jadmg_small, "X", "Y"),
    function() all_adjustment_sets_admg(cadmg_small, X = "X", Y = "Y")
  ),

  # --- Mutation ------------------------------------------------------------
  run(
    "add_edges (4-node graph)",
    function() cs_add_edges(jdag_small, "A --> M"),
    function() add_edges(cdag_small, from = "A", edge = "-->", to = "M")
  ),
  run(
    "remove_edges (4-node graph)",
    function() cs_remove_edges(jdag_small, "X --> M"),
    function() remove_edges(cdag_small, from = "X", edge = "-->", to = "M")
  ),
  run(
    "add_nodes (4-node graph)",
    function() cs_add_nodes(jdag_small, "Z"),
    function() add_nodes(cdag_small, name = "Z")
  ),
  run(
    "remove_nodes (4-node graph)",
    function() cs_remove_nodes(jdag_small, "A"),
    function() remove_nodes(cdag_small, name = "A")
  ),

  # --- Data generation ---------------------------------------------------
  run(
    "simulate_data (n=100)",
    function() cs_simulate_data(jdag, 100, seed = 1L),
    function() simulate_data(cg, 100, seed = 1L)
  )
)

print(results, n = nrow(results))

cs_stop()
