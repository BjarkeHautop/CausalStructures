test_that("warmup works", {
  skip_if_no_julia()
  warmup()
  expect_true(TRUE)
})

# API smoke tests for the CausalStructures.jl binding. Known answers come
# from the quick-guide DAG: A --> X + Y, X --> M --> Y.

test_that("construction works", {
  skip_if_no_julia()
  dag <- cgraph(A %-->% X + Y, X %-->% M %-->% Y)
  expect_s3_class(dag, "JuliaObject")

  mag <- cgraph(A %<->% B, C %-->% B %-->% D, class = "MAG")
  expect_true(is_mag(mag))

  g <- generate_graph(50, p = 0.1, seed = 1405)
  expect_length(nodes(g), 50)
  g2 <- generate_graph(50, m = 100, seed = 1405)
  expect_true(is_dag(g2))

  admg <- generate_graph(10, p = 0.2, class = "ADMG", latents = 3, seed = 1405)
  expect_true(is_admg(admg))
  expect_length(nodes(admg), 10)
  mag <- generate_graph(10, p = 0.2, class = "MAG", latents = 3, seed = 1405)
  expect_true(is_mag(mag))
  expect_length(nodes(mag), 10)
  pag <- generate_graph(10, p = 0.2, class = "PAG", latents = 3, seed = 1405)
  expect_true(is_pag(pag))
  expect_length(nodes(pag), 10)
  expect_error(
    generate_graph(4, m = 2, class = "DAG", latents = 1),
    "latents"
  )

  # UNKNOWN graphs always allow multiple edges between the same pair of nodes
  multi <- cgraph(A %-->% B, A %<->% B, class = "UNKNOWN")
  expect_equal(nrow(edges(multi)), 2)
})

test_that("uniform_dag works", {
  skip_if_no_julia()
  dag <- uniform_dag(6, seed = 1405)
  expect_s3_class(dag, "cgraph")
  expect_true(is_dag(dag))
  expect_length(nodes(dag), 6)

  # With seed, the same DAG should be produced
  dag2 <- uniform_dag(6, seed = 1405)
  expect_equal(edges(dag), edges(dag2))
})

test_that("print.cgraph strips the Julia module prefix", {
  skip_if_no_julia()
  g <- cgraph(A %-->% B, A %<->% B, class = "UNKNOWN")
  out <- capture.output(print(g))
  expect_equal(out[1], "UNKNOWN with 2 nodes and 2 edges:")
  expect_false(any(grepl("CausalStructures", out, fixed = TRUE)))
  expect_false(any(grepl("Julia Object", out, fixed = TRUE)))
})

test_that("invalid graphs error on construction", {
  skip_if_no_julia()
  expect_error(cgraph(A %-->% B %-->% C %-->% A), "cycle")
})

test_that("Julia errors are cleaned unless CausalStructures.verbose_errors is set", {
  skip_if_no_julia()
  dag <- cgraph(A %-->% X + Y, X %-->% M %-->% Y)

  withr::local_options(CausalStructures.verbose_errors = FALSE)
  err <- tryCatch(ancestors(dag, "NOT_A_NODE"), error = function(e) e)
  expect_match(conditionMessage(err), "Unknown node: NOT_A_NODE", fixed = TRUE)
  expect_false(grepl("Stacktrace", conditionMessage(err), fixed = TRUE))

  withr::local_options(CausalStructures.verbose_errors = TRUE)
  err_verbose <- tryCatch(ancestors(dag, "NOT_A_NODE"), error = function(e) {
    e
  })
  expect_match(conditionMessage(err_verbose), "Stacktrace", fixed = TRUE)
})

test_that("graph-level queries work", {
  skip_if_no_julia()
  dag <- cgraph(A %-->% X + Y, X %-->% M %-->% Y)
  expect_setequal(nodes(dag), c("A", "X", "Y", "M"))
  expect_identical(topological_sort(dag), c("A", "X", "M", "Y"))
  expect_identical(exogenous_nodes(dag), "A")
  expect_true(has_edge(dag, "A", "X"))
  expect_true(has_edge(dag, "X", "A")) # adjacency, not direction
  expect_false(has_edge(dag, "A", "M"))

  pdag <- cgraph(A %-->% B, B %---% C, class = "PDAG")
  expect_setequal(exogenous_nodes(pdag), c("A", "C"))
  expect_identical(exogenous_nodes(pdag, undirected_as_parents = TRUE), "A")
})

test_that("edge queries work", {
  skip_if_no_julia()
  dag <- cgraph(A %-->% X + Y, X %-->% M %-->% Y)
  edges <- edges(dag)
  expect_equal(nrow(edges), 4) # A->X, A->Y, X->M, M->Y
  expect_identical(names(edges), c("from", "to", "type"))
  expect_true(all(edges$type == "-->"))
  expect_true(all(c("A", "X", "Y", "M") %in% c(edges$from, edges$to)))

  pag <- cgraph(A %o->% B, B %o-o% C, D %<->% E, F %---% G, class = "UNKNOWN")
  pag_edges <- edges(pag)
  expect_setequal(pag_edges$type, c("o->", "o-o", "<->", "---"))
})

test_that("node-set queries work", {
  skip_if_no_julia()
  dag <- cgraph(A %-->% X + Y, X %-->% M %-->% Y)
  expect_identical(parents(dag, "Y"), c("A", "M"))
  expect_identical(parents(dag, "A"), character(0))
  expect_identical(children(dag, "A"), c("X", "Y"))
  expect_identical(ancestors(dag, "Y"), c("A", "M", "X"))
  expect_identical(descendants(dag, "A"), c("M", "X", "Y"))
  expect_identical(ancestors(dag, "Y", open = FALSE), c("A", "M", "X", "Y"))
  expect_identical(descendants(dag, "A", open = FALSE), c("A", "M", "X", "Y"))
  expect_identical(neighbors(dag, "M"), c("X", "Y"))
  expect_identical(neighbors(dag, "M", mode = "in"), "X")
  expect_identical(neighbors(dag, "M", mode = "out"), "Y")
  expect_identical(markov_blanket(dag, "X"), c("A", "M"))
  # possible_* are only defined for partially directed classes
  cp <- dag_to_cpdag(dag)
  expect_true(all(c("A", "M") %in% possible_ancestors(cp, "Y")))
  expect_true(all(c("X", "Y") %in% possible_descendants(cp, "A")))
  expect_identical(anteriors(dag, "M"), c("A", "X"))
  expect_identical(posteriors(dag, "X"), c("M", "Y"))

  # open = FALSE includes the query node itself in the result
  fully_undirected <- cgraph(A %---% B, B %---% C, class = "CPDAG")
  expect_identical(possible_ancestors(fully_undirected, "C"), c("A", "B"))
  expect_identical(
    possible_ancestors(fully_undirected, "C", open = FALSE),
    c("A", "B", "C")
  )

  admg <- cgraph(A %<->% B, C %-->% B %-->% D, class = "ADMG")
  expect_identical(spouses(admg, "A"), "B")
})

test_that("CausalStructures.open option sets the default for open", {
  skip_if_no_julia()
  dag <- cgraph(A %-->% X + Y, X %-->% M %-->% Y)
  withr::local_options(CausalStructures.open = FALSE)
  expect_identical(ancestors(dag, "Y"), c("A", "M", "X", "Y"))
  expect_identical(descendants(dag, "A"), c("A", "M", "X", "Y"))
  expect_identical(anteriors(dag, "M"), c("A", "M", "X"))
  expect_identical(posteriors(dag, "X"), c("M", "X", "Y"))
  # an explicit open argument still overrides the option
  expect_identical(ancestors(dag, "Y", open = TRUE), c("A", "M", "X"))
})

test_that("class predicates work", {
  skip_if_no_julia()
  # The is_* predicates test whether a graph satisfies a class's constraints,
  # not its declared class -- a DAG is also a valid PDAG, MPDAG, ADMG, AG,
  # and MAG.
  dag <- cgraph(A %-->% X + Y, X %-->% M %-->% Y)
  expect_true(is_dag(dag))
  expect_true(is_pdag(dag))
  expect_true(is_mpdag(dag))
  expect_true(is_admg(dag))
  expect_true(is_ag(dag))
  expect_true(is_mag(dag))
  expect_false(is_ug(dag))
  expect_false(is_cpdag(dag))
  expect_false(is_pag(dag))
  expect_true(is_simple(dag))
  expect_true(is_acyclic(dag))
})

test_that("transformations work", {
  skip_if_no_julia()
  dag <- cgraph(A %-->% X + Y, X %-->% M %-->% Y)
  expect_true(is_ug(skeleton(dag)))
  expect_true(is_ug(moralize(dag)))
  cp <- dag_to_cpdag(dag)
  expect_true(is_cpdag(cp))
  expect_true(is_dag(dag_from_pdag(cp)))
  expect_true(is_pdag(meek_closure(cp)))
  mp <- dag_to_mpdag(dag)
  expect_true(is_mpdag(mp))
  sub <- subgraph(dag, c("X", "M", "Y"))
  expect_setequal(nodes(sub), c("X", "M", "Y"))

  ag <- cgraph(A %-->% B %-->% C, class = "AG")
  mag <- ag_to_mag(ag)
  expect_true(is_mag(mag))
  pag <- mag_to_pag(mag)
  expect_true(is_pag(pag))
  mag2 <- mag_from_pag(pag)
  expect_true(is_mag(mag2))
})

test_that("latent variable transforms work", {
  skip_if_no_julia()
  dag <- cgraph(U %-->% X, U %-->% Y, X %-->% Y)
  admg <- latent_project(dag, "U")
  expect_setequal(nodes(admg), c("X", "Y"))
  expect_true(has_edge(admg, "X", "Y"))

  dag2 <- cgraph(A %-->% B, B %-->% C)
  dag3 <- exogenize(dag2, "B")
  expect_setequal(nodes(dag3), c("A", "B", "C"))
  expect_true(has_edge(dag3, "A", "C"))
  expect_identical(parents(dag3, "B"), character(0))

  dag4 <- cgraph(A %-->% U, U %-->% X, U %-->% Y)
  result <- normalize_latent_structure(dag4, "U")
  expect_setequal(nodes(result), c("A", "U", "X", "Y"))
  expect_true(has_edge(result, "A", "X"))
  expect_true(has_edge(result, "A", "Y"))

  ag <- condition_marginalize(dag, cond_vars = "U")
  expect_setequal(nodes(ag), c("X", "Y"))
})

test_that("mutation works", {
  skip_if_no_julia()
  dag <- cgraph(A %-->% B)
  dag2 <- add_edges(dag, B %-->% C, C %-->% D)
  expect_setequal(nodes(dag2), c("A", "B", "C", "D"))
  expect_true(has_edge(dag2, "C", "D"))

  dag3 <- remove_edges(dag2, C %-->% D)
  expect_false(has_edge(dag3, "C", "D"))
  expect_true(has_edge(dag3, "B", "C"))
  expect_error(remove_edges(dag3, C %-->% D))

  dag4 <- add_nodes(dag, c("C", "D"))
  expect_setequal(nodes(dag4), c("A", "B", "C", "D"))
  expect_identical(parents(dag4, "C"), character(0))

  dag5 <- remove_nodes(dag2, "C")
  expect_setequal(nodes(dag5), c("A", "B", "D"))
  expect_error(remove_nodes(dag5, "C"))

  pdag <- reclass(dag, "PDAG")
  expect_true(is_pdag(pdag))
})

test_that("separation queries work", {
  skip_if_no_julia()
  dag <- cgraph(A %-->% X + Y, X %-->% M %-->% Y)
  expect_false(d_separated(dag, "X", "Y"))
  expect_false(d_separated(dag, "X", "Y", "M"))
  expect_true(d_separated(dag, "X", "Y", c("A", "M")))
  expect_identical(minimal_separator(dag, "A", "M"), "X")
  expect_identical(
    minimal_separator(dag, "X", "Y", include = "M"),
    c("A", "M")
  )
  expect_null(minimal_separator(dag, "X", "Y", restrict = "M"))

  admg <- cgraph(A %<->% B, C %-->% B %-->% D, class = "ADMG")
  expect_false(m_separated(admg, "A", "D"))
  expect_true(m_separated(admg, "C", "A"))

  pag <- cgraph(A %o->% B, C %o->% B, class = "PAG")
  expect_true(m_separated(pag, "A", "C")) # collider at B is blocked
  expect_false(m_separated(pag, "A", "C", "B")) # conditioning opens it
  expect_identical(minimal_separator(pag, "A", "C"), character(0))
})

test_that("identification works", {
  skip_if_no_julia()
  dag <- cgraph(A %-->% X + Y, X %-->% M %-->% Y)
  expect_identical(adjustment_set(dag, "X", "Y"), "A")
  expect_identical(adjustment_set(dag, "X", "Y", type = "parents"), "A")
  expect_identical(adjustment_set(dag, "X", "Y", type = "backdoor"), "A")
  expect_identical(frontdoor_set(dag, "X", "Y"), "M")
  expect_identical(frontdoor_set(dag, "X", "Y", restrict = "M"), "M")
  expect_true(is_valid_backdoor(dag, "X", "Y", "A"))
  expect_false(is_valid_backdoor(dag, "X", "Y"))
  expect_identical(all_backdoor_sets(dag, "X", "Y"), list("A"))
  expect_identical(all_backdoor_sets(dag, "X", "Y", max_size = 0), list())
  expect_identical(all_frontdoor_sets(dag, "X", "Y"), list("M"))
  expect_identical(
    all_frontdoor_sets(dag, "X", "Y", restrict = "M"),
    list("M")
  )
  # Test frontdoor criterion on the appropriate graph
  expect_true(is_valid_frontdoor(dag, "X", "Y", "M"))
  expect_false(is_valid_frontdoor(dag, "X", "Y"))
})

test_that("adjustment criterion works", {
  skip_if_no_julia()
  pdag <- cgraph(A %-->% X + Y, X %-->% M %-->% Y, class = "PDAG")
  expect_true(is_valid_adjustment(pdag, "X", "Y", "A"))
  expect_false(is_valid_adjustment(pdag, "X", "Y"))
  expect_identical(all_adjustment_sets(pdag, "X", "Y"), list("A"))
  expect_identical(
    all_adjustment_sets(pdag, "X", "Y", max_size = 0),
    list()
  )

  dag <- cgraph(A %-->% X + Y, X %-->% M %-->% Y)
  expect_true(is_valid_adjustment(dag, "X", "Y", "A"))
  expect_false(is_valid_adjustment(dag, "X", "Y"))
  expect_identical(all_adjustment_sets(dag, "X", "Y"), list("A"))

  # B --> X is a witness (unconnected to Y) making A o-> X visible, so A's
  # confounding of X and Y can be resolved from the PAG alone.
  mag <- cgraph(B %-->% X, A %<->% X, A %-->% Y, X %-->% Y, class = "MAG")
  pag <- mag_to_pag(mag)
  expect_true(is_valid_adjustment(pag, "X", "Y", "A"))
  expect_false(is_valid_adjustment(pag, "X", "Y"))
  expect_identical(all_adjustment_sets(pag, "X", "Y"), list("A"))
})

test_that("instrumental variables work", {
  skip_if_no_julia()
  # Create a graph where A is a valid instrument for X -> Y
  dag <- cgraph(A %-->% X %-->% Y)
  expect_true(is_valid_iv(dag, "X", "Y", "A"))

  expect_false(is_valid_iv(dag, "X", "Y", character()))

  sets <- all_iv_sets(dag, "X", "Y", minimal = TRUE, max_size = 3)
  expect_type(sets, "list")
  expect_true(any(vapply(sets, function(s) identical(s, "A"), logical(1))))
})

test_that("equivalence class analysis works", {
  skip_if_no_julia()
  dag <- cgraph(A %-->% X + Y, X %-->% M %-->% Y)
  cp <- dag_to_cpdag(dag)

  count <- count_dags(cp)
  expect_type(count, "integer")
  expect_true(count > 0)

  dags <- enumerate_dags(cp)
  expect_s3_class(dags, "JuliaObject")
  # Julia vector contains the enumerated DAGs
})

test_that("MAG enumeration works", {
  skip_if_no_julia()

  pag <- cgraph(A %o->% B, C %o->% B, class = "PAG")
  mags <- enumerate_mags(pag)
  expect_s3_class(mags, "JuliaObject")
})

test_that("data simulation works", {
  skip_if_no_julia()
  dag <- cgraph(A %-->% X + Y, X %-->% M %-->% Y)
  data <- simulate_data(dag, n = 100, seed = 1405)
  expect_s3_class(data, "data.frame")
  expect_equal(dim(data), c(100, 4))
  expect_equal(names(data), nodes(dag))
  # With seed, the same data should be produced
  data2 <- simulate_data(dag, n = 100, seed = 1405)
  expect_equal(data, data2)
})
