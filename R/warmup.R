#' Warm up Julia's JIT compiler
#'
#' Calls every exported wrapper once on small graphs. Julia
#' compiles each method the first time it's called for a given combination
#' of argument types.
#'
#' Calls [setup()] itself, so it can be used standalone right after
#' attaching the package to pay all cost upfront.
#'
#' @return `NULL`, invisibly.
#' @export
#' @examples
#' if (julia_available()) {
#'   warmup()
#' }
warmup <- function() {
  setup()

  dag <- cgraph(spec = "A --> X + Y, X --> M --> Y")
  pdag <- cgraph(spec = "A --- X, X --> Y", class = "PDAG")
  cpdag <- cgraph(spec = "A --- B, B --- C", class = "CPDAG")
  admg <- cgraph(spec = "A --> B, A <-> C", class = "ADMG")
  ag <- cgraph(spec = "A --> B, B --> C", class = "AG")
  mag <- cgraph(spec = "A <-> X, A --> Y, X --> Y", class = "MAG")
  pag <- cgraph(spec = "A o-o B, B o-o C", class = "PAG")

  invisible(utils::capture.output(print(dag)))

  invisible(list(
    # --- Construction / graph-level queries ---------------------------------
    generate_graph(4, p = 0.5, seed = 1L),
    nodes(dag),
    edges(dag),
    topological_sort(dag),
    exogenous_nodes(dag),
    has_edge(dag, "A", "X"),

    # --- Node-set queries ----------------------------------------------------
    parents(dag, "X"),
    children(dag, "A"),
    ancestors(dag, "Y"),
    descendants(dag, "A"),
    spouses(admg, "A"),
    neighbors(dag, "X"),
    markov_blanket(dag, "M"),
    possible_ancestors(cpdag, "C"),
    possible_descendants(cpdag, "A"),
    anteriors(pdag, "Y"),
    posteriors(pdag, "A"),

    # --- Predicates ------------------------------------------------------------
    is_dag(dag),
    is_pdag(dag),
    is_cpdag(dag),
    is_mpdag(dag),
    is_ug(dag),
    is_admg(dag),
    is_ag(dag),
    is_mag(dag),
    is_pag(dag),
    is_simple(dag),
    is_acyclic(dag),

    # --- Transformations ------------------------------------------------------
    skeleton(dag),
    moralize(dag),
    dag_to_cpdag(dag),
    dag_from_pdag(pdag),
    meek_closure(pdag),
    dag_to_mpdag(dag),
    ag_to_mag(ag),
    mag_to_pag(mag),
    mag_from_pag(pag),
    subgraph(dag, c("A", "X")),
    latent_project(dag, "M"),
    exogenize(dag, "M"),
    normalize_latent_structure(dag, "M"),
    condition_marginalize(dag, marg_vars = "M"),

    # --- Mutation --------------------------------------------------------------
    add_edges(dag, spec = "A --> M"),
    remove_edges(dag, spec = "A --> X"),
    add_nodes(dag, "Z"),
    remove_nodes(dag, "Y"),
    reclass(dag, class = "UNKNOWN"),

    # --- Separation / identification --------------------------------------
    d_separated(dag, "A", "Y"),
    m_separated(admg, "B", "C"),
    minimal_separator(dag, "X", "Y"),
    adjustment_set(dag, "X", "Y"),
    frontdoor_set(dag, "X", "Y"),
    is_valid_backdoor(dag, "X", "Y"),
    all_backdoor_sets(dag, "X", "Y"),
    all_frontdoor_sets(dag, "X", "Y"),
    is_valid_adjustment(admg, "A", "B"),
    all_adjustment_sets(admg, "A", "B"),
    is_valid_frontdoor(dag, "X", "Y"),
    is_valid_iv(dag, "X", "Y", "A"),
    all_iv_sets(dag, "X", "Y"),

    # --- Equivalence classes -------------------------------------------------
    count_dags(cpdag),
    enumerate_dags(cpdag),
    markov_equivalent(dag, dag),
    enumerate_mags(pag),

    # --- Data generation / layout --------------------------------------------
    simulate_data(dag, 5, seed = 1L),
    cgraph_layout(dag)
  ))
}
