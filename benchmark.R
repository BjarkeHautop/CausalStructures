# Benchmarks every CausalStructures wrapper (CausalStructures.jl compiled into
# a shared library) against its caugi counterpart, using bench::mark().
#
# caugi doesn't cover every CausalStructures operation.
#   exogenous_nodes()      -> caugi::exogenous()
#   is_valid_adjustment()  -> caugi::is_valid_adjustment_admg()
#   all_adjustment_sets()  -> caugi::all_adjustment_sets_admg()
# Functions with no caugi counterpart at all (dag_to_cpdag, ag_to_mag,
# mag_to_pag, mag_from_pag, frontdoor/IV identification, equivalence-class
# enumeration, possible_ancestors/possible_descendants, has_edge, reclass)
# are left out of the comparison.

# Garbage collection inside the Julia library is invisible to bench::mark(),
# which can't filter it, so we only report the median.

pkgload::load_all(".", quiet = TRUE)
warmup()

n <- 1000L
p <- 0.25

# --- Graph conversion --------------------------------
# The benchmark graphs are DAGs; edges() already gives caugi's edge notation.
to_caugi <- function(graph, class = "DAG") {
  ns <- nodes(graph)
  ed <- edges(graph)
  if (nrow(ed) == 0) {
    return(caugi::build(caugi::caugi(nodes = ns, class = class)))
  }
  caugi::build(caugi::caugi(
    from = ed$from,
    edge = ed$type,
    to = ed$to,
    nodes = ns,
    class = class
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
cdag_small <- caugi::build(caugi::caugi(
  A %-->% X + Y,
  X %-->% M,
  M %-->% Y,
  class = "DAG"
))

jadmg_small <- reclass(jdag_small, "ADMG")
cadmg_small <- caugi::build(caugi::caugi(
  A %-->% X + Y,
  X %-->% M,
  M %-->% Y,
  class = "ADMG"
))

jpdag_small <- cgraph(A %---% X, X %-->% Y, class = "PDAG")
cpdag_small <- caugi::build(caugi::caugi(A %---% X, X %-->% Y, class = "PDAG"))

run <- function(name, expr_julia, expr_caugi) {
  print(name)
  res <- bench::mark(
    julia = expr_julia(),
    caugi = expr_caugi(),
    check = FALSE,
    min_time = 2
  )
  res$benchmark <- name
  res[, c("benchmark", "expression", "median")]
}

results <- rbind(
  # --- Construction ------------------------------------------------------
  run(
    "cgraph (4-node DSL graph)",
    function() cgraph(spec = spec_small),
    function() {
      caugi::build(caugi::caugi(
        A %-->% X + Y,
        X %-->% M,
        M %-->% Y,
        class = "DAG"
      ))
    }
  ),
  run(
    "generate_graph (n=1000)",
    function() generate_graph(n, p = p, seed = 1405L),
    function() {
      caugi::build(caugi::generate_graph(
        n = n,
        p = p,
        class = "DAG",
        seed = 1405
      ))
    }
  ),

  # --- Graph-level queries -------------------------------------------------
  run(
    "nodes",
    function() nodes(jdag),
    function() caugi::nodes(cg)
  ),
  run(
    "edges",
    function() edges(jdag),
    function() caugi::edges(cg)
  ),
  run(
    "topological_sort",
    function() topological_sort(jdag),
    function() caugi::topological_sort(cg)
  ),
  run(
    "exogenous_nodes (caugi: exogenous)",
    function() exogenous_nodes(jdag),
    function() caugi::exogenous(cg)
  ),

  # --- Node-set queries ------------------------------------------------------
  run(
    "parents",
    function() parents(jdag, node),
    function() caugi::parents(cg, node)
  ),
  run(
    "children",
    function() children(jdag, node),
    function() caugi::children(cg, node)
  ),
  run(
    "ancestors",
    function() ancestors(jdag, node),
    function() caugi::ancestors(cg, node)
  ),
  run(
    "descendants",
    function() descendants(jdag, node),
    function() caugi::descendants(cg, node)
  ),
  run(
    "spouses (ADMG, 4-node graph)",
    function() spouses(jadmg_small, "X"),
    function() caugi::spouses(cadmg_small, "X")
  ),
  run(
    "neighbors",
    function() neighbors(jdag, node),
    function() caugi::neighbors(cg, node)
  ),
  run(
    "markov_blanket",
    function() markov_blanket(jdag, node),
    function() caugi::markov_blanket(cg, node)
  ),
  run(
    "anteriors",
    function() anteriors(jdag, node),
    function() caugi::anteriors(cg, node)
  ),
  run(
    "posteriors",
    function() posteriors(jdag, node),
    function() caugi::posteriors(cg, node)
  ),

  # --- Predicates ------------------------------------------------------------
  run(
    "is_dag",
    function() is_dag(jdag),
    function() caugi::is_dag(cg)
  ),
  run(
    "is_acyclic",
    function() is_acyclic(jdag),
    function() caugi::is_acyclic(cg)
  ),

  # --- Transformations ---------------------------------------------------
  run(
    "skeleton (4-node graph)",
    function() skeleton(jdag_small),
    function() caugi::skeleton(cdag_small)
  ),
  run(
    "moralize (4-node graph)",
    function() moralize(jdag_small),
    function() caugi::moralize(cdag_small)
  ),
  run(
    "meek_closure (PDAG)",
    function() meek_closure(jpdag_small),
    function() caugi::meek_closure(cpdag_small)
  ),
  run(
    "dag_from_pdag (PDAG)",
    function() dag_from_pdag(jpdag_small),
    function() caugi::dag_from_pdag(cpdag_small)
  ),
  run(
    "subgraph (4-node graph)",
    function() subgraph(jdag_small, c("A", "X", "Y")),
    function() caugi::subgraph(cdag_small, c("A", "X", "Y"))
  ),
  run(
    "latent_project (4-node graph)",
    function() latent_project(jdag_small, "M"),
    function() caugi::latent_project(cdag_small, "M")
  ),
  run(
    "exogenize (4-node graph)",
    function() exogenize(jdag_small, "X"),
    function() caugi::exogenize(cdag_small, "X")
  ),
  run(
    "normalize_latent_structure (4-node graph)",
    function() normalize_latent_structure(jdag_small, "M"),
    function() caugi::normalize_latent_structure(cdag_small, "M")
  ),
  run(
    "condition_marginalize (4-node graph)",
    function() condition_marginalize(jdag_small, marg_vars = "M"),
    function() caugi::condition_marginalize(cdag_small, marg_vars = "M")
  ),

  # --- Separation --------------------------------------------------------
  run(
    "d_separated",
    function() d_separated(jdag, x, y, z),
    function() caugi::d_separated(cg, x, y, z)
  ),
  run(
    "m_separated",
    function() m_separated(jdag, x, y, z),
    function() caugi::m_separated(cg, X = x, Y = y, Z = z)
  ),
  run(
    "minimal_separator",
    function() minimal_separator(jdag, x, y),
    function() caugi::minimal_separator(cg, X = x, Y = y)
  ),

  # --- Identification ------------------------------------------------------
  run(
    "adjustment_set (backdoor)",
    function() adjustment_set(jdag, x, y),
    function() caugi::adjustment_set(cg, x, y, type = "backdoor")
  ),
  run(
    "is_valid_backdoor",
    function() is_valid_backdoor(jdag, x, y, z),
    function() caugi::is_valid_backdoor(cg, X = x, Y = y, Z = z)
  ),
  run(
    "all_backdoor_sets",
    function() all_backdoor_sets(jdag_small, "X", "Y"),
    function() caugi::all_backdoor_sets(cdag_small, X = "X", Y = "Y")
  ),
  run(
    "is_valid_adjustment (caugi: is_valid_adjustment_admg, ADMG)",
    function() is_valid_adjustment(jadmg_small, "X", "Y", "A"),
    function() {
      caugi::is_valid_adjustment_admg(cadmg_small, X = "X", Y = "Y", Z = "A")
    }
  ),
  run(
    "all_adjustment_sets (caugi: all_adjustment_sets_admg, ADMG)",
    function() all_adjustment_sets(jadmg_small, "X", "Y"),
    function() caugi::all_adjustment_sets_admg(cadmg_small, X = "X", Y = "Y")
  ),

  # --- Mutation ------------------------------------------------------------
  run(
    "add_edges (4-node graph)",
    function() add_edges(jdag_small, A %-->% M),
    function() caugi::add_edges(cdag_small, from = "A", edge = "-->", to = "M")
  ),
  run(
    "remove_edges (4-node graph)",
    function() remove_edges(jdag_small, X %-->% M),
    function() {
      caugi::remove_edges(cdag_small, from = "X", edge = "-->", to = "M")
    }
  ),
  run(
    "add_nodes (4-node graph)",
    function() add_nodes(jdag_small, "Z"),
    function() caugi::add_nodes(cdag_small, name = "Z")
  ),
  run(
    "remove_nodes (4-node graph)",
    function() remove_nodes(jdag_small, "A"),
    function() caugi::remove_nodes(cdag_small, name = "A")
  ),

  # --- Data generation ---------------------------------------------------
  run(
    "simulate_data (n=100)",
    function() simulate_data(jdag, 100, seed = 1L),
    function() caugi::simulate_data(cg, 100, seed = 1L)
  )
)

print(results, n = nrow(results))
