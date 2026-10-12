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

test_that("plot.cgraph picks up global plot_options() defaults", {
  skip_if_no_layout()
  skip_if_no_julia()
  withr::defer(plot_options(plot_default_options()))
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)

  plot_options(
    node_style = list(fill = "lightblue"),
    edge_style = list(col = "gray40")
  )

  styles <- .plot_make_styles(list(), list(), list(), list(), list())
  expect_equal(styles$node_style$global$fill, "lightblue")
  expect_equal(styles$edge_style$types$directed$col, "gray40")

  # An explicit plot() argument still overrides the global default.
  styles_override <- .plot_make_styles(
    list(fill = "gold"),
    list(),
    list(),
    list(),
    list()
  )
  expect_equal(styles_override$node_style$global$fill, "gold")

  expect_no_error(plot(test_dag()))
})
