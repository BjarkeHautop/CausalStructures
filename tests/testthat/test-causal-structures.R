# API smoke tests for the CausalStructures.jl binding. Known answers come
# from the quick-guide DAG: A --> X + Y, X --> M --> Y.

test_that("construction works", {
  skip_if_no_julia()
  dag <- cs_cgraph("A --> X + Y, X --> M --> Y")
  expect_s3_class(dag, "JuliaProxy")

  mag <- cs_cgraph("A <-> B, C --> B --> D", class = "MAG")
  expect_true(cs_is_mag(mag))

  g <- cs_generate_graph(50, p = 0.1, seed = 42)
  expect_length(cs_nodes(g), 50)
  g2 <- cs_generate_graph(50, m = 100, seed = 42)
  expect_true(cs_is_dag(g2))
})

test_that("invalid graphs error on construction", {
  skip_if_no_julia()
  expect_error(cs_cgraph("A --> B --> C --> A"), "cycle")
})

test_that("graph-level queries work", {
  skip_if_no_julia()
  dag <- cs_cgraph("A --> X + Y, X --> M --> Y")
  expect_setequal(cs_nodes(dag), c("A", "X", "Y", "M"))
  expect_identical(cs_topological_sort(dag), c("A", "X", "M", "Y"))
  expect_identical(cs_exogenous_nodes(dag), "A")
  expect_true(cs_has_edge(dag, "A", "X"))
  expect_true(cs_has_edge(dag, "X", "A")) # adjacency, not direction
  expect_false(cs_has_edge(dag, "A", "M"))
})

test_that("edge queries work", {
  skip_if_no_julia()
  dag <- cs_cgraph("A --> X + Y, X --> M --> Y")
  edges <- cs_edges(dag)
  expect_equal(nrow(edges), 4) # A->X, A->Y, X->M, M->Y
  expect_equal(ncol(edges), 2)
  expect_true(all(c("A", "X", "Y", "M") %in% edges))
})

test_that("node-set queries work", {
  skip_if_no_julia()
  dag <- cs_cgraph("A --> X + Y, X --> M --> Y")
  expect_identical(cs_parents(dag, "Y"), c("A", "M"))
  expect_identical(cs_parents(dag, "A"), character(0))
  expect_identical(cs_children(dag, "A"), c("X", "Y"))
  expect_identical(cs_ancestors(dag, "Y"), c("A", "M", "X"))
  expect_identical(cs_descendants(dag, "A"), c("M", "X", "Y"))
  expect_identical(cs_neighbors(dag, "M"), c("X", "Y"))
  expect_identical(cs_markov_blanket(dag, "X"), c("A", "M"))
  # possible_* are only defined for partially directed classes
  cp <- cs_dag_to_cpdag(dag)
  expect_true(all(c("A", "M") %in% cs_possible_ancestors(cp, "Y")))
  expect_true(all(c("X", "Y") %in% cs_possible_descendants(cp, "A")))
  expect_identical(cs_anteriors(dag, "M"), c("A", "X"))
  expect_identical(cs_posteriors(dag, "X"), c("M", "Y"))

  admg <- cs_cgraph("A <-> B, C --> B --> D", class = "ADMG")
  expect_identical(cs_spouses(admg, "A"), "B")
})

test_that("class predicates work", {
  skip_if_no_julia()
  # The is_* predicates test whether a graph satisfies a class's constraints,
  # not its declared class -- a DAG is also a valid PDAG, MPDAG, ADMG, AG,
  # and MAG.
  dag <- cs_cgraph("A --> X + Y, X --> M --> Y")
  expect_true(cs_is_dag(dag))
  expect_true(cs_is_pdag(dag))
  expect_true(cs_is_mpdag(dag))
  expect_true(cs_is_admg(dag))
  expect_true(cs_is_ag(dag))
  expect_true(cs_is_mag(dag))
  expect_false(cs_is_ug(dag))
  expect_false(cs_is_cpdag(dag))
  expect_false(cs_is_pag(dag))
  expect_true(cs_is_simple(dag))
  expect_true(cs_is_acyclic(dag))
})

test_that("transformations work", {
  skip_if_no_julia()
  dag <- cs_cgraph("A --> X + Y, X --> M --> Y")
  expect_true(cs_is_ug(cs_skeleton(dag)))
  expect_true(cs_is_ug(cs_moralize(dag)))
  cp <- cs_dag_to_cpdag(dag)
  expect_true(cs_is_cpdag(cp))
  expect_true(cs_is_dag(cs_dag_from_pdag(cp)))
  expect_true(cs_is_pdag(cs_meek_closure(cp)))
  mp <- cs_dag_to_mpdag(dag)
  expect_true(cs_is_mpdag(mp))
  sub <- cs_subgraph(dag, c("X", "M", "Y"))
  expect_setequal(cs_nodes(sub), c("X", "M", "Y"))
})

test_that("separation queries work", {
  skip_if_no_julia()
  dag <- cs_cgraph("A --> X + Y, X --> M --> Y")
  expect_false(cs_d_separated(dag, "X", "Y"))
  expect_false(cs_d_separated(dag, "X", "Y", "M"))
  expect_true(cs_d_separated(dag, "X", "Y", c("A", "M")))
  expect_identical(cs_minimal_separator(dag, "A", "M"), "X")

  admg <- cs_cgraph("A <-> B, C --> B --> D", class = "ADMG")
  expect_false(cs_m_separated(admg, "A", "D"))
  expect_true(cs_m_separated(admg, "C", "A"))
})

test_that("identification works", {
  skip_if_no_julia()
  dag <- cs_cgraph("A --> X + Y, X --> M --> Y")
  expect_identical(cs_adjustment_set(dag, "X", "Y"), "A")
  expect_identical(cs_frontdoor_set(dag, "X", "Y"), "M")
  expect_true(cs_is_valid_backdoor(dag, "X", "Y", "A"))
  expect_false(cs_is_valid_backdoor(dag, "X", "Y"))
  expect_identical(cs_all_backdoor_sets(dag, "X", "Y"), list("A"))
  expect_identical(cs_all_frontdoor_sets(dag, "X", "Y"), list("M"))
  # Test frontdoor criterion on the appropriate graph
  expect_true(cs_is_valid_frontdoor(dag, "X", "Y", "M"))
  expect_false(cs_is_valid_frontdoor(dag, "X", "Y"))
})

test_that("adjustment criterion works", {
  skip_if_no_julia()
  pdag <- cs_cgraph("A --> X + Y, X --> M --> Y", class = "PDAG")
  expect_true(cs_is_valid_adjustment(pdag, "X", "Y", "A"))
  expect_false(cs_is_valid_adjustment(pdag, "X", "Y"))
  expect_identical(cs_all_adjustment_sets(pdag, "X", "Y"), list("A"))
})

test_that("instrumental variables work", {
  skip_if_no_julia()
  # Create a graph where A is a valid instrument for X -> Y
  dag <- cs_cgraph("A --> X --> Y")
  expect_true(cs_is_valid_iv(dag, "X", "Y", "A"))

  # TODO:
  # Error in `charToRaw()`:
  # argument must be a character vector of length 1
  # expect_false(cs_is_valid_iv(dag, "X", "Y", character()))

  sets <- cs_all_iv_sets(dag, "X", "Y", minimal = TRUE, max_size = 3)
  expect_type(sets, "list")
  expect_true(any(vapply(sets, function(s) identical(s, "A"), logical(1))))
})

test_that("equivalence class analysis works", {
  skip_if_no_julia()
  dag <- cs_cgraph("A --> X + Y, X --> M --> Y")
  cp <- cs_dag_to_cpdag(dag)

  count <- cs_count_dags(cp)
  expect_type(count, "integer")
  expect_true(count > 0)

  dags <- cs_enumerate_dags(cp)
  expect_s3_class(dags, "JuliaProxy")
  # Julia vector contains the enumerated DAGs
})

test_that("MAG enumeration works", {
  skip_if_no_julia()
  # TODO

  skip()

  # BROKEN? Is partial edges implemented?
  cs_cgraph("A --o B, B --o C", class = "PAG")
  pag <- cs_cgraph("A --o B, B --o C", class = "PAG")
  mags <- cs_enumerate_mags(pag)
  expect_s3_class(mags, "JuliaProxy")
  # Returns a Julia vector of MAGs
})

test_that("data simulation works", {
  skip_if_no_julia()
  dag <- cs_cgraph("A --> X + Y, X --> M --> Y")
  data <- cs_simulate_data(dag, n = 100, seed = 1405)
  expect_s3_class(data, "JuliaProxy")
  # Julia Dict contains the simulated data (node -> vector)
  # With seed, same data should be produced
  data2 <- cs_simulate_data(dag, n = 100, seed = 1405)
  expect_s3_class(data2, "JuliaProxy")
})
