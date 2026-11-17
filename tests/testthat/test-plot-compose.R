compose_dag <- function() cgraph("A --> X + Y, X --> M --> Y")

edge_index <- function(p, from, to) {
  which(p$edges$from == from & p$edges$to == to)
}

test_that("cgraph_plot() builds without drawing and draws when printed", {
  skip_if_no_julia()
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)

  p <- cgraph_plot(compose_dag())
  expect_s3_class(p, "cgraph_plot")
  expect_s3_class(cgraph_grob(p), "gTree")
  expect_no_error(print(p))
  expect_no_error(grid::grid.draw(p))
  expect_s3_class(plot(compose_dag()), "cgraph_plot")
})

test_that("verbs accept a graph and reject anything else", {
  skip_if_no_julia()
  expect_s3_class(style_nodes(compose_dag(), fill = "red"), "cgraph_plot")
  expect_error(style_nodes(1, fill = "red"), "cgraph_plot")
  expect_error(cgraph_plot(1), "cgraph")
})

test_that("style_nodes() merges per node, later calls winning", {
  skip_if_no_julia()
  p <- cgraph_plot(compose_dag()) |>
    style_nodes(col = "navy", nodes = "A") |>
    style_nodes(fill = "red") |>
    style_nodes(fill = "gold", nodes = c("A", "Y"))
  expect_identical(p$node_by$A, list(col = "navy", fill = "gold"))
  expect_identical(p$node_by$Y$fill, "gold")
  expect_identical(p$node_by$X$fill, "red")
})

test_that("style_title() styles the title", {
  skip_if_no_julia()
  p <- cgraph_plot(compose_dag(), main = "T") |>
    style_title(col = "navy") |>
    style_title(fontsize = 20)
  title <- cgraph_grob(p)$children$title
  expect_identical(title$gp$col, "navy")
  expect_identical(title$gp$fontsize, 20)
})

test_that("verbs validate fields and node names", {
  skip_if_no_julia()
  p <- cgraph_plot(compose_dag())
  expect_error(style_nodes(p, colour = "red"), "Unknown style field")
  expect_error(style_nodes(p, "red"), "must be named")
  expect_error(style_nodes(p, fill = "red", nodes = "Z"), "not in the graph")
  expect_error(style_edges(p, col = "red", from = "Z"), "not in the graph")
  expect_error(style_edges(p, col = "red", type = "->"), "Unknown edge type")
  expect_error(style_labels(p, fill = "red"), "Unknown style field")
  expect_error(label_nodes(p, Z = "z"), "not in the graph")
  expect_error(label_nodes(p, "z"), "must be named")
  expect_error(label_nodes(p, X = 1), "single string")
  expect_error(style_title(p, shape = "square"), "Unknown style field")
})

test_that("style_edges() selects by endpoints in either direction", {
  skip_if_no_julia()
  p <- cgraph_plot(compose_dag())
  q <- style_edges(p, col = "red", from = "Y", to = "X")
  expect_equal(sum(!vapply(q$edge_overrides, is.null, logical(1))), 0)

  q <- style_edges(p, col = "red", from = "M", to = "X")
  expect_identical(
    q$edge_overrides[[edge_index(p, "X", "M")]],
    list(col = "red")
  )
  expect_equal(sum(!vapply(q$edge_overrides, is.null, logical(1))), 1)

  # type fixes the direction
  expect_null(
    style_edges(
      p,
      col = "red",
      from = "M",
      to = "X",
      type = "-->"
    )$edge_overrides[[
      edge_index(p, "X", "M")
    ]]
  )
  expect_identical(
    style_edges(
      p,
      col = "red",
      from = "M",
      to = "X",
      type = "<--"
    )$edge_overrides[[
      edge_index(p, "X", "M")
    ]],
    list(col = "red")
  )

  # out-edges of X
  q <- style_edges(p, lwd = 2, from = "X", type = "-->")
  styled <- which(!vapply(q$edge_overrides, is.null, logical(1)))
  expect_setequal(styled, c(edge_index(p, "X", "M"), edge_index(p, "X", "Y")))
})

test_that("style_edges() selects by type, later calls winning", {
  skip_if_no_julia()
  admg <- cgraph("X --> Y, X <-> Y, Y <-> Z", class = "ADMG")
  p <- cgraph_plot(admg) |>
    style_edges(col = "blue", from = "X", to = "Y") |>
    style_edges(lty = "dashed", type = "<->") |>
    style_edges(col = "red", from = "X", to = "Y", type = "<->")
  styles <- .plot_make_styles(edge_overrides = p$edge_overrides)
  for (i in seq_len(nrow(p$edges))) {
    s <- .plot_edge_style(p$edges, i, styles$edge_style)
    bidirected <- p$edges$src_mark[i] == "Arrow" &&
      p$edges$dst_mark[i] == "Arrow"
    pair_xy <- setequal(c(p$edges$from[i], p$edges$to[i]), c("X", "Y"))
    expect_identical(s$lty, if (bidirected) "dashed" else NULL)
    expected_col <- if (bidirected && pair_xy) {
      "red"
    } else if (pair_xy) {
      "blue"
    } else {
      "black"
    }
    expect_identical(s$col, expected_col)
  }
})

test_that("label_nodes() and style_labels() reach the drawn labels", {
  skip_if_no_julia()
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)

  p <- cgraph_plot(compose_dag()) |>
    label_nodes(A = "Confounder", X = "Ex") |>
    label_nodes(X = "Exposure") |>
    style_labels(col = "red", nodes = "X")
  labels <- Filter(
    function(g) grepl("^label", g$name),
    cgraph_grob(p)$children$cs.graph$children$node_gtree$children
  )
  texts <- vapply(labels, function(g) as.character(g$label), character(1))
  cols <- vapply(labels, function(g) g$gp$col, character(1))
  expect_true(all(c("Confounder", "Exposure") %in% texts))
  expect_identical(unname(cols[texts == "Exposure"]), "red")
  expect_true(all(cols[texts != "Exposure"] == "black"))
})
