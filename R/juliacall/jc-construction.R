# --- Construction (JuliaCall backend; see jc-session.R) ---------------------

jc_cgraph <- function(
  ...,
  spec = NULL,
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
  jc_fn("cgraph")(.cs_dots_or_spec(substitute(list(...)), spec), class, simple)
}

jc_generate_graph <- function(
  n,
  m = NULL,
  p = NULL,
  class = c("DAG", "CPDAG"),
  seed = NULL
) {
  class <- match.arg(class)
  jc_fn("generate_graph")(as.integer(n), m, p, class, jc_make_rng(seed))
}

# --- Graph-level queries -----------------------------------------------------

jc_nodes <- function(cg) {
  jc_fn("nodes")(cg)
}

jc_topological_sort <- function(cg) {
  jc_fn("topological_sort")(cg)
}

jc_exogenous_nodes <- function(cg, undirected_as_parents = FALSE) {
  jc_fn("exogenous_nodes")(cg, undirected_as_parents)
}

jc_has_edge <- function(cg, x, y) {
  jc_fn("has_edge")(cg, x, y)
}

# Unlike cs_edges(), no strsplit()/matrix() reconstruction: the Julia helper
# already returns a native Matrix{String} (n x 2, including the n = 0 case),
# which JuliaCall converts straight to an R character matrix.
jc_edges <- function(cg) {
  jc_fn("edges")(cg)
}
