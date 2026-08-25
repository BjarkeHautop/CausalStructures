test_that("plot.cgraph draws with the default layout", {
  skip_if_no_julia()
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)

  expect_no_error(plot(test_dag()))
})

test_that("cgraph_layout works for every layout method", {
  skip_if_no_julia()
  methods <- c(
    "spring",
    "stress",
    "sfdp",
    "spectral",
    "shell",
    "squaregrid"
  )

  for (m in methods) {
    coords <- cgraph_layout(test_dag(), method = m)
    expect_equal(nrow(coords), 4)
    expect_setequal(coords$name, c("A", "X", "Y", "M"))
    expect_true(is.numeric(coords$x))
    expect_true(is.numeric(coords$y))
  }
})

test_that("plot.cgraph draws with every layout method", {
  skip_if_no_julia()
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)

  methods <- c(
    "spring",
    "stress",
    "sfdp",
    "spectral",
    "shell",
    "squaregrid"
  )
  for (m in methods) {
    expect_no_error(plot(test_dag(), layout = m))
  }
})

test_that("plot.cgraph draws with a pre-computed layout data.frame", {
  skip_if_no_julia()
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)

  coords <- cgraph_layout(test_dag(), method = "spring")
  expect_no_error(plot(test_dag(), layout = coords))
})

test_that("plot.cgraph draws with a layout function", {
  skip_if_no_julia()
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)

  expect_no_error(plot(test_dag(), layout = cgraph_layout))
})

test_that("plot.cgraph honors styling options without error", {
  skip_if_no_julia()
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)

  expect_no_error(plot(
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
  ))
})

test_that("plot.cgraph renders every edge type without error", {
  skip_if_no_julia()
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)

  g <- cgraph(
    "A --> B, C --- D, E <-> F, G o-> H, I o-- J, K o-o L",
    class = "UNKNOWN"
  )
  expect_no_error(plot(g, layout = "spring"))
})

test_that("plot.cgraph errors on an empty graph", {
  skip_if_no_julia()
  g <- cgraph("", class = "DAG")
  expect_error(plot(g), "empty graph")
})

test_that("plot.cgraph errors on a layout data.frame missing columns", {
  skip_if_no_julia()
  bad_layout <- data.frame(name = c("A", "X", "Y", "M"), x = 1:4)
  expect_error(
    plot(test_dag(), layout = bad_layout),
    "missing required column"
  )
})

test_that("print.cgraph_plot and plot.cgraph_plot redraw a saved plot", {
  skip_if_no_julia()
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)

  p <- plot(test_dag())
  expect_s3_class(p, "cgraph_plot")
  expect_no_error(print(p))
  expect_no_error(plot(p))
})

test_that("node_style shape draws square and per-node overrides without error", {
  skip_if_no_julia()
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)

  expect_no_error(plot(test_dag(), node_style = list(shape = "square")))
  expect_no_error(plot(
    test_dag(),
    node_style = list(by_node = list(A = list(shape = "square")))
  ))
})

test_that("node_style shape draws ellipse and rect without error", {
  skip_if_no_julia()
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)

  expect_no_error(plot(test_dag(), node_style = list(shape = "ellipse")))
  expect_no_error(plot(test_dag(), node_style = list(shape = "rect")))
})

test_that("node_style shape errors on an unknown shape", {
  skip_if_no_julia()
  expect_error(
    plot(test_dag(), node_style = list(shape = "hexagon")),
    "Unknown node shape"
  )
})

test_that("ellipse/rect force an oblong box even for a short label", {
  ellipse <- .plot_shape_half_extents("ellipse", "A", list(fontsize = 10), 2)
  expect_true(ellipse[1] / ellipse[2] <= 1.4 + 1e-8)

  rect <- .plot_shape_half_extents("rect", "A", list(fontsize = 10), 2)
  expect_true(rect[1] / rect[2] <= 1.4 + 1e-8)
})

test_that("node_style radius overrides label-based sizing", {
  skip_if_no_julia()
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)

  expect_no_error(plot(test_dag(), node_style = list(radius = 15)))
  expect_no_error(plot(
    test_dag(),
    node_style = list(by_node = list(A = list(radius = 20)))
  ))
})

test_that("edge_style styles the three partial-mark edge types independently", {
  skip_if_no_julia()
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)

  g <- cgraph("A o-> B, C o-- D, E o-o F", class = "UNKNOWN")
  expect_no_error(plot(
    g,
    edge_style = list(
      partially_directed = list(col = "red"),
      partially_undirected = list(col = "blue"),
      partial = list(col = "green")
    )
  ))

  styles <- .plot_make_styles(
    list(),
    list(
      partially_directed = list(col = "red"),
      partially_undirected = list(col = "blue"),
      partial = list(col = "green")
    ),
    list(),
    list(),
    list()
  )
  expect_equal(styles$edge_style$types$partially_directed$col, "red")
  expect_equal(styles$edge_style$types$partially_undirected$col, "blue")
  expect_equal(styles$edge_style$types$partial$col, "green")
})

test_that("circle/square always equalize half-extents regardless of label length", {
  short <- .plot_shape_half_extents(
    "circle",
    "A",
    list(fontsize = 10),
    2
  )
  expect_equal(short[1], short[2])

  long <- .plot_shape_half_extents(
    "circle",
    "A very very long label indeed",
    list(fontsize = 10),
    2
  )
  expect_equal(long[1], long[2])

  square <- .plot_shape_half_extents(
    "square",
    "A very very long label indeed",
    list(fontsize = 10),
    2
  )
  expect_equal(square[1], square[2])
})

test_that("node_style linestyle draws without error", {
  skip_if_no_julia()
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)

  expect_no_error(plot(test_dag(), node_style = list(linestyle = "dashed")))
})

test_that("labels overrides node text, falling back to the node name", {
  skip_if_no_julia()
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)

  p <- plot(test_dag(), labels = c(A = "Confounder"))
  expect_s3_class(p, "cgraph_plot")

  label_texts <- vapply(
    p$grob$children$cs.graph$children$node_gtree$children,
    function(g) {
      if (grepl("^label", g$name)) as.character(g$label) else NA_character_
    },
    character(1)
  )
  label_texts <- label_texts[!is.na(label_texts)]
  expect_true("Confounder" %in% label_texts)
  # A node not in `labels` keeps its own name
  expect_true("X" %in% label_texts)
})

test_that("layout accepts a named list of node positions", {
  skip_if_no_julia()
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)

  dict_layout <- list(A = c(0, 1), X = c(1, 1), Y = c(2, 0.5), M = c(1.5, 0))
  expect_no_error(plot(test_dag(), layout = dict_layout))

  incomplete <- list(A = c(0, 0), X = c(1, 0))
  expect_error(
    plot(test_dag(), layout = incomplete),
    "missing a position"
  )
})

test_that("edge_style curvature draws globally and per-edge without error", {
  skip_if_no_julia()
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)

  expect_no_error(plot(test_dag(), edge_style = list(curvature = 0.3)))
  expect_no_error(plot(
    test_dag(),
    edge_style = list(by_edge = list(A = list(X = list(curvature = -0.2))))
  ))
})

test_that("by_edge .by_type disambiguates parallel edges of different types", {
  skip_if_no_julia()
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)

  admg <- cgraph("X --> Y, X <-> Y", class = "UNKNOWN")
  by_type_style <- list(
    by_edge = list(
      X = list(
        Y = list(
          .by_type = list(
            "-->" = list(col = "red"),
            "<->" = list(col = "blue")
          )
        )
      )
    )
  )
  expect_no_error(plot(admg, edge_style = by_type_style))

  edges <- .plot_edges(admg)
  styles <- .plot_make_styles(list(), by_type_style, list(), list(), list())
  s1 <- .plot_edge_style(edges, 1, styles$edge_style)
  s2 <- .plot_edge_style(edges, 2, styles$edge_style)
  expect_false(identical(s1$col, s2$col))
  expect_setequal(c(s1$col, s2$col), c("red", "blue"))
})
