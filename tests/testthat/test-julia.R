test_that("every exported wrapper runs", {
  skip_if_no_julia()

  dag <- cgraph(spec = "A --> X + Y, X --> M --> Y")
  pdag <- cgraph(spec = "A --- X, X --> Y", class = "PDAG")
  cpdag <- cgraph(spec = "A --- B, B --- C", class = "CPDAG")
  admg <- cgraph(spec = "A --> B, A <-> C", class = "ADMG")
  ag <- cgraph(spec = "A --> B, B --> C", class = "AG")
  mag <- cgraph(spec = "A <-> X, A --> Y, X --> Y", class = "MAG")
  pag <- cgraph(spec = "A o-o B, B o-o C", class = "PAG")

  expect_output(print(dag))

  expect_no_error(list(
    # --- Construction / graph-level queries ---------------------------------
    generate_graph(4, p = 0.5, seed = 1L),
    uniform_dag(4, seed = 1L),
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
    condition_marginalize(dag, index = "M"),

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

    # --- Data generation --------------------------------------------
    simulate_data(dag, 5, seed = 1L),

    # --- Layout ---------------------------------------------------------------
    cgraph_layout(dag),
    cgraph_layout(pag, method = "sugiyama"),

    # --- Added in CausalStructures.jl 1.0-1.1 ---------------------------------
    districts(admg),
    dag == dag,
    apply_background_knowledge(cpdag, A %-->% B),
    iv_set(dag, "X", "Y"),
    idp(mag_to_pag(mag), "X", "Y"),
    cidp(mag_to_pag(mag), "X", "Y"),
    hd(dag, dag),
    shd(dag, dag),
    aid(dag, dag),
    separation_distance(dag, dag),
    sc_metric(dag, dag),
    markov_metric(dag, dag),
    faithfulness_metric(dag, dag)
  ))
})

# API smoke tests for the CausalStructures.jl binding. Known answers come
# from the quick-guide DAG: A --> X + Y, X --> M --> Y.

test_that("construction works", {
  skip_if_no_julia()
  dag <- cgraph(A %-->% X + Y, X %-->% M %-->% Y)
  expect_s3_class(dag, "cgraph")

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

test_that("graphs survive saving and loading", {
  skip_if_no_julia()
  graphs <- list(
    cgraph(A %-->% X + Y, X %-->% M %-->% Y, E),
    cgraph(A %---% B, C, class = "UG"),
    cgraph(A %-->% B, B %---% C, class = "PDAG"),
    cgraph(A %---% B, B %---% C, class = "CPDAG"),
    dag_to_mpdag(cgraph(A %-->% B %-->% C), A %-->% B),
    cgraph(A %-->% B, A %<->% C, class = "ADMG"),
    cgraph(A %-->% B, B %-->% C, class = "AG"),
    cgraph(A %<->% X, A %-->% Y, X %-->% Y, class = "MAG"),
    cgraph(A %o->% B, C %o->% B, class = "PAG"),
    cgraph("A --> B, A <-> B, A o-o C", class = "UNKNOWN"),
    cgraph(A, B)
  )
  for (cg in graphs) {
    loaded <- unserialize(serialize(cg, NULL))
    expect_s3_class(loaded, "cgraph")
    expect_true(loaded == cg)
  }

  file <- tempfile(fileext = ".rds")
  on.exit(unlink(file))
  dag <- graphs[[1]]
  saveRDS(list(a = dag, b = dag, other = graphs[[2]]), file)
  gc()
  live <- jlbind::object_count()
  loaded <- readRDS(file)
  # Loading builds nothing, and two different graphs still differ.
  expect_identical(jlbind::object_count(), live)
  expect_false(identical(loaded$a, loaded$other))
  expect_identical(parents(loaded$a, "M"), "X")
  expect_identical(jlbind::object_count(), live + 1L)
  # Both copies of a graph are one object, rebuilt once.
  expect_identical(children(loaded$b, "A"), c("X", "Y"))
  expect_identical(jlbind::object_count(), live + 1L)
  expect_true(unserialize(serialize(loaded$a, NULL)) == dag)
  expect_true(skeleton(loaded$a) == skeleton(dag))

  old <- unserialize(serialize(dag, NULL, version = 2))
  expect_error(parents(old, "M"), "saved without its contents")
})

test_that("a uniform_dag_counts table does not survive saving and loading", {
  skip_if_no_julia()
  loaded <- unserialize(serialize(uniform_dag_counts(8), NULL))
  expect_error(uniform_dag(6, counts = loaded), "no longer exists")
  # A loaded graph is not mistaken for a table.
  graph <- unserialize(serialize(cgraph(A %-->% B), NULL))
  expect_error(uniform_dag(4, counts = graph), "uniform_dag_counts")
})

test_that("uniform_dag reuses a table from uniform_dag_counts", {
  skip_if_no_julia()
  table <- uniform_dag_counts(8)
  expect_s3_class(table, "uniform_dag_counts")
  expect_true(
    uniform_dag(6, seed = 1405, counts = table) == uniform_dag(6, seed = 1405)
  )
  expect_true(is_dag(uniform_dag(8, seed = 1, counts = table)))
  expect_error(uniform_dag(9, counts = table), "only covers")
  expect_error(uniform_dag(4, counts = cgraph(A %-->% B)), "uniform_dag_counts")
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

test_that("library errors carry just the underlying message", {
  skip_if_no_julia()
  dag <- cgraph(A %-->% X + Y, X %-->% M %-->% Y)

  err <- tryCatch(ancestors(dag, "NOT_A_NODE"), error = function(e) e)
  expect_identical(conditionMessage(err), "Unknown node: NOT_A_NODE")
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

  ug <- cgraph(A %---% B, C, class = "UG")
  expect_setequal(exogenous_nodes(ug), c("A", "B", "C"))
  expect_identical(exogenous_nodes(ug, undirected_as_parents = TRUE), "C")
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

  chain <- cgraph(A %-->% B %-->% C)
  oriented <- edges(dag_to_mpdag(chain, A %-->% B))
  expect_setequal(oriented$type, "-->")
  expect_equal(edges(dag_to_mpdag(chain, spec = "A --> B")), oriented)
  expect_error(dag_to_mpdag(chain, B %-->% A), "inconsistent")

  for (cg in list(
    cgraph(A %<->% B, B %-->% C, class = "ADMG"),
    cgraph(A %<->% B, B %-->% C, class = "MAG"),
    cgraph(A %o->% B, C %o->% B, class = "PAG"),
    cgraph(A %---% B, B %---% C, class = "UG"),
    cgraph("A --> B, A <-> B", class = "UNKNOWN")
  )) {
    expect_true(is_ug(skeleton(cg)))
    expect_identical(nodes(skeleton(cg)), nodes(cg))
  }
  parallel <- cgraph("A --> B, A <-> B", class = "UNKNOWN")
  expect_identical(nrow(edges(skeleton(parallel))), 1L)

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

  ag <- condition_marginalize(dag, given = "U")
  expect_setequal(nodes(ag), c("X", "Y"))
})

test_that("mutation applies every edge before validating", {
  skip_if_no_julia()
  # Neither edge alone is a valid CPDAG, but the v-structure is.
  empty <- cgraph(spec = "A, B, C", class = "CPDAG")
  cpdag <- add_edges(empty, A %-->% C, B %-->% C)
  expect_true(cpdag == cgraph(A %-->% C %<--% B, class = "CPDAG"))
  expect_true(remove_edges(cpdag, A %-->% C, B %-->% C) == empty)
  expect_error(add_edges(empty, A %-->% C), "strongly protected")
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

  # x/y accept a character vector of nodes (querying separation of sets)
  expect_false(d_separated(dag, "M", c("A", "X"))) # X --> M is a direct edge
  expect_true(d_separated(dag, "M", "A", "X")) # blocked by conditioning on X
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

  # x/y accept a character vector of nodes (querying a set of
  # treatments/outcomes)
  two_x <- cgraph(A %-->% X1 + X2, X1 %-->% Y, X2 %-->% Y)
  expect_identical(
    adjustment_set(two_x, c("X1", "X2"), "Y", type = "parents"),
    "A"
  )
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

  # adjustment_set() also supports ADMG (type is ignored, as for MAG/PAG)
  admg <- cgraph(A %-->% X, X %-->% Y, A %-->% Y, class = "ADMG")
  expect_identical(adjustment_set(admg, "X", "Y"), "A")
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
  expect_length(dags, count)
  expect_true(all(vapply(dags, is_dag, logical(1))))
})

test_that("MAG enumeration works", {
  skip_if_no_julia()

  pag <- cgraph(A %o->% B, C %o->% B, class = "PAG")
  mags <- enumerate_mags(pag)
  expect_true(length(mags) > 0)
  expect_true(all(vapply(mags, is_mag, logical(1))))
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

test_that("meek_closure accepts check_cycles/r4", {
  skip_if_no_julia()
  pdag <- cgraph(A %-->% X, X %---% Y, class = "PDAG")
  mpdag <- meek_closure(pdag, check_cycles = TRUE, r4 = FALSE)
  expect_s3_class(mpdag, "cgraph")
  expect_true(is_mpdag(mpdag))
})

test_that("a PDAG with no consistent DAG extension has no DAGs", {
  skip_if_no_julia()
  # R1 orients B --> C, closing the cycle A --> B --> C --> D --> A.
  pdag <- cgraph(A %-->% B, B %---% C, C %-->% D, D %-->% A, class = "PDAG")
  expect_identical(count_dags(pdag), 0L)
  expect_identical(enumerate_dags(pdag), list())
  expect_error(meek_closure(pdag), "no consistent DAG extension")
})

test_that("anteriors/posteriors and condition_marginalize accept ADMG", {
  skip_if_no_julia()
  admg <- cgraph(A %-->% X, X %-->% Y, class = "ADMG")
  # For an ADMG, anteriors()/posteriors() are equivalent to
  # ancestors()/descendants() (bidirected edges don't extend reachability).
  expect_identical(anteriors(admg, "Y"), ancestors(admg, "Y"))
  expect_identical(posteriors(admg, "A"), descendants(admg, "A"))
  expect_identical(anteriors(admg, "Y"), c("A", "X"))

  admg2 <- cgraph(A %-->% X, X %<->% Y, class = "ADMG")
  ag <- condition_marginalize(admg2, index = "X")
  expect_s3_class(ag, "cgraph")
})

test_that("id/idc identify interventional distributions", {
  skip_if_no_julia()
  dag <- cgraph(Z %-->% X, X %-->% Y, Z %-->% Y)
  expect_identical(id(dag, "X", "Y"), "Σ_{Z} P(Y | X, Z) P(Z)")
  expect_identical(idc(dag, "X", "Y", given = "Z"), "P(Y | X, Z)")

  admg <- cgraph(X %-->% M, M %-->% Y, X %<->% Y, class = "ADMG")
  expect_false(is.null(id(admg, "X", "Y")))

  bow <- cgraph(X %-->% Y, X %<->% Y, class = "ADMG")
  expect_null(id(bow, "X", "Y"))
})

test_that("backdoor_set and possible_d_sep work", {
  skip_if_no_julia()
  cpdag <- cgraph(A %-->% X, C %-->% X, X %-->% Y, class = "CPDAG")
  expect_identical(sort(backdoor_set(cpdag, "X", "Y")), c("A", "C"))

  cpdag2 <- cgraph(X %---% Y, class = "CPDAG")
  expect_null(backdoor_set(cpdag2, "X", "Y"))

  mag <- cgraph(A %<->% X, A %-->% M, M %-->% Y, X %-->% Y, class = "MAG")
  expect_identical(
    sort(possible_d_sep(mag, "X", "Y")),
    c("A", "M", "Y")
  )
})

test_that("possible_parent_sets/possible_optimal_adjustment_sets pair up", {
  skip_if_no_julia()
  cpdag <- cgraph(
    X1 %---% X2,
    X1 %---% X3,
    X1 %---% X4,
    X3 %-->% Y,
    X4 %-->% Y,
    class = "CPDAG"
  )
  parent_sets <- possible_parent_sets(cpdag, "X1")
  opt_sets <- possible_optimal_adjustment_sets(cpdag, "X1", "Y")

  expect_length(parent_sets, 4)
  expect_length(opt_sets, length(parent_sets))
  # A trailing/embedded empty set must round-trip correctly (regression test
  # for the joined-string encoding): the empty parental set is present.
  expect_true(any(vapply(parent_sets, function(s) length(s) == 0, logical(1))))
  # The orientation with an empty parent set has an empty optimal adjustment
  # set too (pairing by index).
  empty_idx <- which(vapply(
    parent_sets,
    function(s) length(s) == 0,
    logical(1)
  ))
  expect_identical(opt_sets[[empty_idx]], character(0))
})

test_that("possible_joint_parent_sets enumerates joint orientations", {
  skip_if_no_julia()
  cpdag <- cgraph(
    X1 %---% X2,
    X1 %---% A,
    X2 %---% B,
    A %-->% Y,
    B %-->% Y,
    class = "CPDAG"
  )
  groups <- possible_joint_parent_sets(cpdag, c("X1", "X2"))
  expect_length(groups, 4)
  for (g in groups) {
    expect_length(g, 2)
  }
})

test_that("possible_local_structures/maximal_local_mag/pagcauses work", {
  skip_if_no_julia()
  pag <- cgraph(
    X %o->% Y,
    X %o->% C,
    X %o->% A,
    Y %o-o% C,
    C %o-o% A,
    B %o->% C,
    B %o->% Y,
    B %o->% A,
    class = "PAG"
  )
  structures <- possible_local_structures(pag, "X")
  expect_true(length(structures) > 0)

  mag <- cgraph(A %<->% X, B %-->% X, A %<->% B, X %-->% Y, class = "MAG")
  small_pag <- mag_to_pag(mag)
  local_mag <- maximal_local_mag(small_pag, "X", "A")
  expect_s3_class(local_mag, "cgraph")

  causes <- pagcauses(pag, "X", "Y")
  expect_type(causes, "list")
})

test_that("cgraph_layout no longer accepts the removed circle method", {
  skip_if_no_julia()
  dag <- cgraph(A %-->% B, B %-->% C)
  expect_error(cgraph_layout(dag, method = "circle"))
})

test_that("include and restrict constrain adjustment and backdoor sets", {
  skip_if_no_julia()
  dag <- cgraph(A %-->% B %-->% X + Y, A %-->% Y, X %-->% Y)
  expect_equal(
    adjustment_set(dag, "X", "Y", type = "backdoor", restrict = c("A", "B")),
    "B"
  )
  expect_true(all(
    vapply(
      all_adjustment_sets(dag, "X", "Y", include = "A"),
      `%in%`,
      NA,
      x = "A"
    )
  ))
  expect_true(all(
    vapply(all_backdoor_sets(dag, "X", "Y", include = "A"), `%in%`, NA, x = "A")
  ))
  expect_equal(backdoor_set(dag, "X", "Y", restrict = "B"), "B")
  expect_error(adjustment_set(dag, "X", "Y", include = "A"), "type = :backdoor")

  cpdag <- dag_to_cpdag(dag)
  expect_error(adjustment_set(cpdag, "X", "Y", include = "A"), "no include")
  expect_error(backdoor_set(cpdag, "X", "Y", restrict = "B"), "no include")
})

test_that("instruments can be conditional", {
  skip_if_no_julia()
  dag <- cgraph(W %-->% Z + Y, Z %-->% X %-->% Y, U %-->% X + Y)
  expect_false(is_valid_iv(dag, "X", "Y", "Z"))
  expect_true(is_valid_iv(dag, "X", "Y", "Z", given = "W"))
  expect_true("Z" %in% unlist(all_iv_sets(dag, "X", "Y", given = "W")))
  expect_equal(iv_set(dag, "X", "Y"), list(z = "Z", given = "W"))
  expect_null(iv_set(dag, "X", "Y", restrict = c("Z", "X", "Y")))

  dag2 <- cgraph(Z %-->% X %-->% Y, U %-->% X + Y)
  expect_equal(iv_set(dag2, "X", "Y"), list(z = "Z", given = character()))
})

test_that("idp and cidp identify effects from a PAG", {
  skip_if_no_julia()
  mag <- cgraph(B %-->% X, A %<->% X, A %-->% Y, X %-->% Y, class = "MAG")
  pag <- mag_to_pag(mag)
  expect_type(idp(pag, "X", "Y"), "character")
  expect_type(cidp(pag, "X", "Y", given = "A"), "character")
  expect_error(idp(mag, "X", "Y"), "not supported for a MAG")
})

test_that("districts, equality and background knowledge work", {
  skip_if_no_julia()
  admg <- cgraph(A %<->% B, B %<->% C, C %-->% D, class = "ADMG")
  expect_equal(districts(admg), list(c("A", "B", "C"), "D"))

  g1 <- cgraph(A %-->% B, B %-->% C)
  expect_true(g1 == cgraph(B %-->% C, A %-->% B))
  expect_false(g1 == reclass(g1, "UNKNOWN"))
  expect_true(g1 != cgraph(A %-->% B))

  cpdag <- cgraph(A %---% B %---% C, class = "CPDAG")
  expect_true(
    apply_background_knowledge(cpdag, C %-->% B) ==
      cgraph(B %-->% A, C %-->% B, class = "MPDAG")
  )
  expect_true(
    apply_background_knowledge(cpdag, C %!-->% B) ==
      cgraph(A %---% B, B %-->% C, class = "MPDAG")
  )
  expect_true(
    apply_background_knowledge(cpdag, spec = "C !--> B") ==
      apply_background_knowledge(cpdag, C %!-->% B)
  )
  expect_error(apply_background_knowledge(cpdag, A %-->% C))
})

test_that("enumerate_mags can exclude selection bias", {
  skip_if_no_julia()
  pag <- cgraph(A %o-o% B, B %o-o% C, class = "PAG")
  all_mags <- enumerate_mags(pag)
  no_sb <- enumerate_mags(pag, selection_bias = FALSE)
  expect_lt(length(no_sb), length(all_mags))
  expect_false(any(vapply(no_sb, \(m) any(edges(m)$type == "---"), NA)))
})

test_that("simulate_data takes random_sign and an error_sd range", {
  skip_if_no_julia()
  dag <- cgraph(A %-->% B %-->% C)
  d <- simulate_data(
    dag,
    50,
    standardize = FALSE,
    coef_range = c(0.5, 2),
    random_sign = TRUE,
    error_sd = c(0.5, 1.5),
    seed = 1
  )
  expect_equal(dim(d), c(50L, 3L))
  expect_error(simulate_data(dag, 5, error_sd = c(1, 2, 3)), "length 1 or 2")
  expect_error(
    simulate_data(dag, 5, coef_range = c(-1, 1), random_sign = TRUE),
    "random_sign"
  )
})

test_that("graph metrics match CausalStructures.jl", {
  skip_if_no_julia()
  chain <- cgraph(A %-->% B %-->% C)
  collider <- cgraph(A %-->% B, C %-->% B)
  expect_equal(hd(chain, collider), 0)
  expect_equal(shd(chain, collider), 1)
  expect_equal(shd(cgraph(A %-->% B), cgraph(A %<->% B, class = "ADMG")), 1)
  expect_equal(hd(cgraph(A %-->% B, C), chain, normalized = TRUE), 1 / 3)

  expect_equal(aid(chain, collider), 4)
  expect_equal(aid(chain, collider, normalized = TRUE), 2 / 3)
  truth <- cgraph(A %-->% B %-->% C, A %-->% C)
  expect_equal(aid(truth, chain, type = "parent"), 1)
  expect_equal(aid(truth, chain, type = "ancestor"), 0)

  expect_equal(separation_distance(collider, chain), 1)
  cg1 <- cgraph(A %-->% B %-->% C, A %-->% C, C %-->% D)
  cg2 <- cgraph(A %-->% B %-->% C %-->% D)
  expect_equal(separation_distance(cg1, cg2), 1)
  expect_equal(separation_distance(cg1, cg2, strategy = "zl"), 2)
  expect_equal(separation_distance(cg1, cg2, mb_enhanced = TRUE), 2)
  expect_equal(separation_distance(cg1, cg2, normalized = TRUE), 1 / 6)
  pag1 <- mag_to_pag(cgraph(
    A %-->% X %-->% M %-->% Y,
    A %-->% Y,
    class = "MAG"
  ))
  pag2 <- mag_to_pag(cgraph(A %-->% X %-->% M %-->% Y, class = "MAG"))
  expect_equal(separation_distance(pag1, pag2), 2)
  expect_error(separation_distance(pag1, pag2, strategy = "zl"), "two DAGs")
  expect_error(separation_distance(chain, pag2), "same class")

  test <- cgraph(A %-->% B, C %-->% B, C %-->% D)
  expect_equal(sc_metric(cg2, cg2), 0)
  expect_equal(sc_metric(cg2, test), 0.25)
  expect_equal(sc_metric(cg2, test, max_order = 0), 1 / 3)
  expect_equal(markov_metric(cg2, test), 0.1527777777777778)
  expect_type(faithfulness_metric(cg2, test), "double")
  expect_error(
    sc_metric(chain, cgraph(A %-->% B %-->% C, class = "ADMG")),
    "separation notion|not supported"
  )
})
