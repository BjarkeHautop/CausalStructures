test_that("cs_plot draws with the default layout", {
  skip_if_no_julia()
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)

  expect_no_error(print(cs_plot(test_dag())))
})

test_that("cs_layout works for every layout method", {
  skip_if_no_julia()
  methods <- c(
    "circle",
    "spring",
    "stress",
    "sfdp",
    "spectral",
    "shell",
    "squaregrid"
  )

  for (m in methods) {
    coords <- cs_layout(test_dag(), method = m)
    expect_equal(nrow(coords), 4)
    expect_setequal(coords$name, c("A", "X", "Y", "M"))
    expect_true(is.numeric(coords$x))
    expect_true(is.numeric(coords$y))
  }
})

test_that("cs_plot draws with every layout method", {
  skip_if_no_julia()
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)

  methods <- c(
    "circle",
    "spring",
    "stress",
    "sfdp",
    "spectral",
    "shell",
    "squaregrid"
  )
  for (m in methods) {
    expect_no_error(print(cs_plot(test_dag(), layout = m)))
  }
})

test_that("cs_plot draws with a pre-computed layout data.frame", {
  skip_if_no_julia()
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)

  coords <- cs_layout(test_dag(), method = "circle")
  expect_no_error(print(cs_plot(test_dag(), layout = coords)))
})

test_that("cs_plot draws with a layout function", {
  skip_if_no_julia()
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)

  expect_no_error(print(cs_plot(test_dag(), layout = cs_layout)))
})

test_that("cs_plot honors styling options without error", {
  skip_if_no_julia()
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)

  expect_no_error(print(cs_plot(
    test_dag(),
    main = "Quick guide DAG",
    node_style = list(
      fill = "lightblue",
      by_node = list(A = list(fill = "red"))
    ),
    edge_style = list(
      col = "darkgray",
      by_edge = list(A = list(X = list(col = "blue")))
    ),
    label_style = list(fontsize = 8),
    title_style = list(col = "blue"),
    asp = 1
  )))
})

test_that("cs_plot renders every edge type without error", {
  skip_if_no_julia()
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)

  g <- cgraph(
    "A --> B, C --- D, E <-> F, G o-> H, I o-- J, K o-o L",
    class = "UNKNOWN"
  )
  expect_no_error(print(cs_plot(g, layout = "circle")))
})

test_that("cs_plot errors on an empty graph", {
  skip_if_no_julia()
  g <- cgraph("", class = "DAG")
  expect_error(cs_plot(g), "empty graph")
})

test_that("cs_plot errors on a layout data.frame missing columns", {
  skip_if_no_julia()
  bad_layout <- data.frame(name = c("A", "X", "Y", "M"), x = 1:4)
  expect_error(
    cs_plot(test_dag(), layout = bad_layout),
    "missing required column"
  )
})
