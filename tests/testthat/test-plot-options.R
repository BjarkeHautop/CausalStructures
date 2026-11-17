test_that("plot_options() returns defaults with no prior customization", {
  withr::defer(plot_options(plot_default_options()))

  expect_equal(plot_options(), plot_default_options())
})

test_that("plot_options() gets a single top-level option", {
  withr::defer(plot_options(plot_default_options()))

  expect_equal(plot_options("node_style"), plot_default_options()$node_style)
})

test_that("plot_options() drills down through nested options", {
  withr::defer(plot_options(plot_default_options()))

  expect_equal(plot_options("node_style", "fill"), "white")
})

test_that("plot_options() errors on an unknown top-level option", {
  withr::defer(plot_options(plot_default_options()))

  expect_error(plot_options("not_a_real_option"), "does not exist")
})

test_that("plot_options() errors drilling into a non-list", {
  withr::defer(plot_options(plot_default_options()))

  expect_error(
    plot_options("node_style", "fill", "deeper"),
    "is not a list"
  )
})

test_that("plot_options() sets and merges partial updates", {
  withr::defer(plot_options(plot_default_options()))

  old <- plot_options(node_style = list(fill = "lightblue"))
  expect_equal(old$node_style, plot_default_options()$node_style)

  updated <- plot_options("node_style")
  expect_equal(updated$fill, "lightblue")
  # Other node_style fields are untouched by the partial update.
  expect_equal(updated$col, plot_default_options()$node_style$col)
})

test_that("plot_options(plot_default_options()) resets to defaults", {
  withr::defer(plot_options(plot_default_options()))

  plot_options(node_style = list(fill = "red"), edge_style = list(lwd = 5))
  plot_options(plot_default_options())

  expect_equal(plot_options(), plot_default_options())
})

test_that("plots pick up global plot_options() defaults", {
  skip_if_no_julia()
  withr::defer(plot_options(plot_default_options()))
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)

  plot_options(
    node_style = list(fill = "lightblue"),
    edge_style = list(col = "gray40")
  )

  styles <- .plot_make_styles()
  expect_equal(styles$node_style$global$fill, "lightblue")
  expect_equal(styles$edge_style$global$col, "gray40")

  # A style verb still overrides the global default.
  p <- style_edges(test_dag(), col = "gold", from = "A", to = "X")
  styles <- .plot_make_styles(edge_overrides = p$edge_overrides)
  i <- which(p$edges$from == "A" & p$edges$to == "X")
  expect_equal(.plot_edge_style(p$edges, i, styles$edge_style)$col, "gold")
  expect_equal(
    .plot_edge_style(
      p$edges,
      setdiff(seq_len(nrow(p$edges)), i)[1],
      styles$edge_style
    )$col,
    "gray40"
  )

  expect_no_error(plot(test_dag()))
})
