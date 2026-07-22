# --- Separation (JuliaCall backend; see jc-session.R) -----------------------

jc_d_separated <- function(cg, x, y, given = character()) {
  jc_fn("d_separated")(cg, x, y, as.character(given))
}

jc_m_separated <- function(cg, x, y, given = character()) {
  jc_fn("m_separated")(cg, x, y, as.character(given))
}

# Unlike cs_minimal_separator(), no cs_split() needed: the Julia helper
# already returns Nothing or a plain (sorted) Vector{String}.
jc_minimal_separator <- function(
  cg,
  x,
  y,
  include = character(),
  restrict = NULL
) {
  restrict_arg <- if (is.null(restrict)) NULL else as.character(restrict)
  jc_fn("minimal_separator")(cg, x, y, as.character(include), restrict_arg)
}

# --- Causal identification ---------------------------------------------------

jc_adjustment_set <- function(
  cg,
  x,
  y,
  type = c("optimal", "parents", "backdoor")
) {
  type <- match.arg(type)
  jc_fn("adjustment_set")(cg, x, y, type)
}

jc_frontdoor_set <- function(
  cg,
  x,
  y,
  include = character(),
  restrict = NULL
) {
  restrict_arg <- if (is.null(restrict)) NULL else as.character(restrict)
  jc_fn("frontdoor_set")(cg, x, y, as.character(include), restrict_arg)
}

jc_is_valid_backdoor <- function(cg, x, y, given = character()) {
  jc_fn("is_valid_backdoor")(cg, x, y, as.character(given))
}

# Nested "list of sets" results still use the joined-string convention (see
# jc-session.R): Vector{Vector{String}} does not auto-convert via JuliaCall,
# so cs_split_sets() (plain string parsing, no Julia dependency) is reused
# as-is from the JuliaConnectoR binding.
jc_all_backdoor_sets <- function(cg, x, y, minimal = TRUE, max_size = 3) {
  cs_split_sets(jc_fn("all_backdoor_sets")(cg, x, y, minimal, max_size))
}

jc_all_frontdoor_sets <- function(
  cg,
  x,
  y,
  include = character(),
  restrict = NULL
) {
  restrict_arg <- if (is.null(restrict)) NULL else as.character(restrict)
  cs_split_sets(
    jc_fn("all_frontdoor_sets")(cg, x, y, as.character(include), restrict_arg)
  )
}

jc_is_valid_adjustment <- function(cg, x, y, given = character()) {
  jc_fn("is_valid_adjustment")(cg, x, y, as.character(given))
}

jc_all_adjustment_sets <- function(cg, x, y, minimal = TRUE, max_size = 3) {
  cs_split_sets(jc_fn("all_adjustment_sets")(cg, x, y, minimal, max_size))
}

jc_is_valid_frontdoor <- function(cg, x, y, given = character()) {
  jc_fn("is_valid_frontdoor")(cg, x, y, as.character(given))
}

jc_is_valid_iv <- function(cg, x, y, z = character()) {
  jc_fn("is_valid_iv")(cg, x, y, as.character(z))
}

jc_all_iv_sets <- function(cg, x, y, minimal = TRUE, max_size = 3) {
  cs_split_sets(jc_fn("all_iv_sets")(cg, x, y, minimal, max_size))
}

# --- Equivalence classes and counts ------------------------------------------

jc_count_dags <- jc_graph_fn("count_dags")

jc_enumerate_dags <- function(cg) {
  jc_fn("enumerate_dags")(cg)
}

jc_markov_equivalent <- function(g1, g2) {
  jc_fn("markov_equivalent")(g1, g2)
}

jc_enumerate_mags <- function(cg) {
  jc_fn("enumerate_mags")(cg)
}
