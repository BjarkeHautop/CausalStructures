# --- Transformations (JuliaCall backend; see jc-session.R) ------------------

jc_skeleton <- jc_graph_fn("skeleton")
jc_moralize <- jc_graph_fn("moralize")
jc_dag_to_cpdag <- jc_graph_fn("dag_to_cpdag")
jc_dag_from_pdag <- jc_graph_fn("dag_from_pdag")
jc_meek_closure <- jc_graph_fn("meek_closure")
jc_dag_to_mpdag <- jc_graph_fn("dag_to_mpdag")
jc_ag_to_mag <- jc_graph_fn("ag_to_mag")
jc_mag_to_pag <- jc_graph_fn("mag_to_pag")
jc_mag_from_pag <- jc_graph_fn("mag_from_pag")

jc_subgraph <- function(cg, nodes) {
  jc_fn("subgraph")(cg, as.character(nodes))
}

jc_latent_project <- function(cg, latents) {
  jc_fn("latent_project")(cg, as.character(latents))
}

jc_exogenize <- function(cg, nodes) {
  jc_fn("exogenize")(cg, as.character(nodes))
}

jc_normalize_latent_structure <- function(cg, latents) {
  jc_fn("normalize_latent_structure")(cg, as.character(latents))
}

jc_condition_marginalize <- function(
  cg,
  cond_vars = character(),
  marg_vars = character()
) {
  jc_fn("condition_marginalize")(
    cg,
    as.character(cond_vars),
    as.character(marg_vars)
  )
}

# --- Mutation ----------------------------------------------------------------

jc_add_edges <- function(cg, ..., spec = NULL) {
  jc_fn("add_edges")(cg, .cs_dots_or_spec(substitute(list(...)), spec))
}

jc_remove_edges <- function(cg, ..., spec = NULL) {
  jc_fn("remove_edges")(cg, .cs_dots_or_spec(substitute(list(...)), spec))
}

jc_add_nodes <- function(cg, nodes) {
  jc_fn("add_nodes")(cg, as.character(nodes))
}

jc_remove_nodes <- function(cg, nodes) {
  jc_fn("remove_nodes")(cg, as.character(nodes))
}

jc_reclass <- function(
  cg,
  class = c(
    "DAG",
    "UG",
    "PDAG",
    "CPDAG",
    "MPDAG",
    "ADMG",
    "AG",
    "MAG",
    "PAG",
    "UNKNOWN"
  ),
  simple = TRUE
) {
  class <- match.arg(class)
  jc_fn("reclass")(cg, class, simple)
}
