test_that("plot.cgraph draws with the default layout", {
  skip_if_no_julia()
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)

  expect_no_error(plot(test_dag()))
})

test_that("cgraph_layout works for every layout method", {
  skip_if_no_julia()
  methods <- c(
    "sugiyama",
    "stress",
    "spring",
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
    "sugiyama",
    "stress",
    "spring",
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

  coords <- cgraph_layout(test_dag(), method = "stress")
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
  expect_no_error(plot(g, layout = "stress"))
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
  styles <- .plot_make_styles(list(), by_type_style, list(), list())
  s1 <- .plot_edge_style(edges, 1, styles$edge_style)
  s2 <- .plot_edge_style(edges, 2, styles$edge_style)
  expect_false(identical(s1$col, s2$col))
  expect_setequal(c(s1$col, s2$col), c("red", "blue"))
})

test_that("sugiyama layers follow the edges in every direction", {
  skip_if_no_julia()
  g <- cgraph(A %-->% B, B %-->% C)
  pos <- function(direction) {
    coords <- cgraph_layout(g, method = "sugiyama", direction = direction)
    coords[match(c("A", "B", "C"), coords$name), ]
  }
  expect_true(all(diff(pos("right")$x) > 0))
  expect_true(all(diff(pos("left")$x) < 0))
  expect_true(all(diff(pos("down")$y) < 0))
  expect_true(all(diff(pos("up")$y) > 0))
  expect_error(cgraph_layout(g, method = "sugiyama", direction = "sideways"))
})

test_that("sugiyama works for graphs that are not DAGs", {
  skip_if_no_julia()
  cyclic <- cgraph("A --> B, B --> C, C --> A", class = "UNKNOWN")
  pag <- cgraph("A o-> B, B <-> C, C --- D", class = "UNKNOWN")
  for (g in list(cyclic, pag)) {
    coords <- cgraph_layout(g, method = "sugiyama")
    expect_setequal(coords$name, nodes(g))
    expect_true(all(is.finite(c(coords$x, coords$y))))
  }
})

test_that("the random layouts are deterministic for a given seed", {
  skip_if_no_julia()
  for (m in c("stress", "spring", "sfdp")) {
    expect_identical(
      cgraph_layout(test_dag(), method = m),
      cgraph_layout(test_dag(), method = m)
    )
    expect_false(identical(
      cgraph_layout(test_dag(), method = m, seed = 1),
      cgraph_layout(test_dag(), method = m, seed = 2)
    ))
  }
})

test_that("stress handles awkward graphs", {
  skip_if_no_julia()

  graphs <- list(
    single = cgraph("A", class = "UG"),
    pair = cgraph("A --- B", class = "UG"),
    path = cgraph("A --- B, B --- C, C --- D", class = "UG"),
    isolated = cgraph("A --> B, C, D", class = "DAG"),
    components = cgraph("A --> B, C <-> D, D <-> E", class = "ADMG")
  )
  for (g in graphs) {
    coords <- cgraph_layout(g, method = "stress")
    expect_setequal(coords$name, nodes(g))
    expect_true(all(is.finite(c(coords$x, coords$y))))
    if (nrow(coords) > 1) {
      # No two nodes on top of each other.
      expect_gt(min(stats::dist(coords[, c("x", "y")])), 1e-3)
    }
  }
})

test_that("shell and squaregrid place nodes in nodes() order", {
  skip_if_no_julia()
  shell <- cgraph_layout(test_dag(), method = "shell")
  expect_equal(shell$name, nodes(test_dag()))
  expect_equal(sqrt(shell$x^2 + shell$y^2), rep(1, 4))
  grid <- cgraph_layout(test_dag(), method = "squaregrid")
  expect_equal(grid$x, c(0, 1, 0, 1))
  expect_equal(grid$y, c(0, 0, -1, -1))
})

# The text grobs drawn for edge `i` of the plot on the current device; edge
# content is only built at draw time, so the display list is forced first.
drawn_edge_texts <- function(i) {
  grid::grid.force()
  e <- grid::grid.get(paste0("edge.", i), grep = TRUE, global = TRUE)
  if (is.list(e) && !inherits(e, "grob")) {
    e <- e[[1L]]
  }
  Filter(function(k) inherits(k, "text"), e$children)
}

test_that("edge_style label draws a label on the edges it is set for", {
  skip_if_no_julia()
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)

  g <- cgraph("A --> B, B --> C")
  plot(
    g,
    edge_style = list(
      label_col = "navy",
      by_edge = list(A = list(B = list(label = "hello", label_shift = 0.25)))
    )
  )
  texts <- drawn_edge_texts(1)
  expect_length(texts, 1)
  expect_identical(texts[[1]]$label, "hello")
  expect_identical(texts[[1]]$gp$col, "navy")
  expect_length(drawn_edge_texts(2), 0)

  # A fixed rotation, in degrees.
  plot(g, edge_style = list(label = "x", label_rotation = 30))
  expect_equal(drawn_edge_texts(1)[[1]]$rot, 30)
})

test_that("edge labels follow the edge's angle and read upright", {
  path <- list(x = c(10, 0), y = c(10, 0))
  grob <- .plot_edge_label_grob(path, "lbl", list(fontsize = 9))
  # The edge points down-left (-135 degrees), so the text is turned to 45.
  expect_equal(grob$rot, 45)
})

test_that("edge_style gap and label fields are validated", {
  skip_if_no_julia()
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)

  expect_error(
    plot(test_dag(), edge_style = list(gap = -1)),
    "`edge_style\\$gap` must be non-negative"
  )
  expect_error(
    plot(test_dag(), edge_style = list(label = "x", label_shift = 2)),
    "`edge_style\\$label_shift` must be between 0 and 1"
  )
  expect_error(
    plot(test_dag(), edge_style = list(arrow_size = -1)),
    "`edge_style\\$arrow_size` must be non-negative"
  )
  expect_error(
    plot(test_dag(), node_style = list(radius = 0)),
    "`node_style\\$radius` must be positive"
  )
  expect_error(
    plot(test_dag(), node_style = list(by_node = list(X = list(padding = -1)))),
    "`node_style\\$padding` must be non-negative, got -1 for node \"X\""
  )
  expect_no_error(plot(test_dag(), edge_style = list(gap = 2)))
})

test_that("label_style by_node styles single node labels", {
  skip_if_no_julia()
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)

  p <- plot(
    test_dag(),
    label_style = list(col = "black", by_node = list(A = list(col = "red")))
  )
  label_cols <- vapply(
    Filter(
      function(g) grepl("^label", g$name),
      p$grob$children$cs.graph$children$node_gtree$children
    ),
    function(g) g$gp$col,
    character(1)
  )
  expect_identical(unname(label_cols[nodes(test_dag()) == "A"]), "red")
  expect_true(all(label_cols[nodes(test_dag()) != "A"] == "black"))
})

test_that(".plot_waypoints accepts matrices, data.frames, and point lists", {
  expected <- matrix(c(0, 1, 2, 3), ncol = 2, byrow = TRUE)
  expect_identical(.plot_waypoints(expected), expected)
  expect_identical(.plot_waypoints(list(c(0, 1), c(2, 3))), expected)
  expect_identical(
    .plot_waypoints(data.frame(x = c(0, 2), y = c(1, 3))),
    expected
  )
  expect_identical(.plot_waypoints(c(0, 1)), matrix(c(0, 1), ncol = 2))
  expect_error(.plot_waypoints("a"), "two-column matrix")
})

test_that("a path set for the reversed node pair is flipped", {
  skip_if_no_julia()
  g <- cgraph("A --> B")
  edges <- .plot_edges(g)
  path <- list(c(0, 1), c(2, 3))
  forward <- .plot_make_styles(
    list(),
    list(by_edge = list(A = list(B = list(path = path)))),
    list(),
    list()
  )
  reversed <- .plot_make_styles(
    list(),
    list(by_edge = list(B = list(A = list(path = rev(path))))),
    list(),
    list()
  )
  expect_identical(
    .plot_edge_style(edges, 1, forward$edge_style)$path,
    .plot_edge_style(edges, 1, reversed$edge_style)$path
  )
})

test_that(".plot_clip_polyline clips a path at both node boundaries", {
  # From a circle of radius 1 at (0, 0) up through (0, 5) to a circle of
  # radius 1 at (5, 5).
  clipped <- .plot_clip_polyline(
    c(0, 0, 5),
    c(0, 5, 5),
    "circle",
    1,
    1,
    "circle",
    1,
    1
  )
  expect_equal(clipped$x, c(0, 0, 4), tolerance = 1e-6)
  expect_equal(clipped$y, c(1, 5, 5), tolerance = 1e-6)
  # Overlapping nodes leave nothing to draw.
  expect_null(.plot_clip_polyline(
    c(0, 0.5),
    c(0, 0),
    "circle",
    1,
    1,
    "circle",
    1,
    1
  ))
})

test_that("explicit edge paths draw and widen the plotted range", {
  skip_if_no_julia()
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)

  g <- cgraph("A --> B")
  p <- plot(
    g,
    layout = list(A = c(0, 0), B = c(1, 0)),
    edge_style = list(by_edge = list(A = list(B = list(path = c(0.5, 2)))))
  )
  expect_identical(p$grob$children$cs.graph$cs_y_range, c(0, 2))
})

test_that("sugiyama routes long edges through bend points", {
  skip_if_no_julia()
  g <- cgraph("A --> X, X --> Y, A --> Y")
  routed <- .plot_sugiyama(g, "right")
  edges <- .plot_edges(g)
  long <- which(edges$from == "A" & edges$to == "Y")
  expect_gt(nrow(routed$paths[[long]]), 0)
  expect_identical(nrow(routed$paths[[which(edges$to == "X")]]), 0L)
  expect_identical(routed$coords$name, nodes(g))

  # Parallel edges between one pair keep fanning out instead.
  admg <- cgraph("X --> Y, X <-> Y", class = "ADMG")
  expect_true(all(vapply(.plot_sugiyama(admg, "right")$paths, is.null, NA)))

  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  expect_no_error(plot(g, layout = "sugiyama", direction = "down"))
})
