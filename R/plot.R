# --- Plotting ------------------------------------------------------------
#
# Grid-graphics rendering adapted from caugi's plotting code (R/plot-core.R,
# R/plot-grobs.R by Frederik Fabricius-Bjerre and Johan Larsson), simplified
# to a single global edge style (no per-edge-type styling, no tier boxes).
# See inst/COPYRIGHTS for attribution and layout.cgraph() (causal-structures-
# layout.R) for the layout algorithm.
#
# Each edge carries a Tail/Arrow/Circle mark at each endpoint (see
# CausalStructures.jl's CausalEdge), covering directed, undirected,
# bidirected, and partially-marked (PAG-style) edges alike: an "Arrow" mark
# draws an arrowhead at that end, a "Circle" mark draws a small open circle,
# and "Tail" draws nothing (a plain line end).

# Edges with their per-endpoint Tail/Arrow/Circle marks, for drawing (as
# opposed to edges(), which collapses the two marks into a single `type`
# notation column, e.g. "-->").
.plot_edges <- function(cg) {
  mat <- fn("edge_marks")(cg)
  data.frame(
    from = mat[, 1],
    to = mat[, 2],
    src_mark = mat[, 3],
    dst_mark = mat[, 4],
    stringsAsFactors = FALSE
  )
}

.plot_gpar_params <- function(style) {
  gpar_names <- c(
    "fill",
    "col",
    "lwd",
    "lty",
    "alpha",
    "lineend",
    "linejoin",
    "linemitre",
    "fontsize",
    "fontface",
    "fontfamily",
    "cex",
    "lex"
  )
  params <- style[names(style) %in% gpar_names]
  if (length(params) == 0) {
    return(list())
  }
  params
}

.plot_make_styles <- function(
  node_style,
  edge_style,
  label_style,
  title_style
) {
  node_defaults <- list(
    fill = "white",
    col = "black",
    lwd = 1,
    padding = 2,
    size = 1
  )
  edge_defaults <- list(
    col = "black",
    lwd = 1,
    arrow_size = 3,
    circle_size = 1.5,
    route = TRUE
  )
  label_defaults <- list(col = "black", fontsize = 10)
  title_defaults <- list(col = "black", fontsize = 14, fontface = "bold")

  by_node <- node_style$by_node %||% list()
  node_style$by_node <- NULL

  by_edge <- edge_style$by_edge %||% list()
  edge_style$by_edge <- NULL

  list(
    node_style = list(
      global = utils::modifyList(node_defaults, node_style),
      by_node = by_node
    ),
    edge_style = list(
      global = utils::modifyList(edge_defaults, edge_style),
      by_edge = by_edge
    ),
    label_style = utils::modifyList(label_defaults, label_style),
    title_style = utils::modifyList(title_defaults, title_style)
  )
}

.plot_make_nodes <- function(coords, labels, node_style, label_style) {
  n_nodes <- nrow(coords)

  circle_grobs <- grid::gList()
  label_grobs <- grid::gList()
  node_radii <- vector("list", n_nodes)

  padding_global <- grid::unit(node_style$global$padding, "mm")

  for (i in seq_len(n_nodes)) {
    node_name <- coords$name[i]

    style <- node_style$global
    if (!is.null(node_style$by_node[[node_name]])) {
      style <- utils::modifyList(style, node_style$by_node[[node_name]])
    }

    padding <- grid::unit(style$padding %||% padding_global, "mm")
    r <- (0.5 * grid::stringWidth(labels[i]) + padding) * style$size

    x <- grid::unit(coords$x[i], "native")
    y <- grid::unit(coords$y[i], "native")

    node_gpar <- do.call(grid::gpar, .plot_gpar_params(style))
    circle_grobs[[i]] <- grid::circleGrob(
      x = x,
      y = y,
      r = r,
      gp = node_gpar,
      name = paste0("node.", i)
    )

    label_gpar <- do.call(grid::gpar, .plot_gpar_params(label_style))
    label_grobs[[i]] <- grid::textGrob(
      labels[i],
      x = x,
      y = y,
      gp = label_gpar,
      name = paste0("label.", i)
    )

    # Node stroke straddles the circle's path (half the line width falls
    # outside r), so edges must be trimmed at r plus that half-width or a
    # thick border can cover the line end (and any arrowhead on it). lwd is
    # in grid's 1/96-inch convention.
    node_radii[[i]] <- r + grid::unit(style$lwd / 192, "inches")
  }

  list(
    circle_grobs = circle_grobs,
    label_grobs = label_grobs,
    node_radii = node_radii
  )
}

# gTree whose children (a line between two node boundaries, with an
# arrowhead and/or endpoint circles per the edge's Tail/Arrow/Circle marks)
# are computed at draw time, so edges stay anchored to node centers under
# resizing/aspect changes.
.plot_edge_grob <- function(
  x0,
  y0,
  x1,
  y1,
  r_from,
  r_to,
  src_mark,
  dst_mark,
  arrow,
  gp,
  circle_size,
  name,
  obstacle_x = numeric(0),
  obstacle_y = numeric(0),
  obstacle_r = list(),
  route = TRUE
) {
  grid::gTree(
    x0 = x0,
    y0 = y0,
    x1 = x1,
    y1 = y1,
    r_from = r_from,
    r_to = r_to,
    src_mark = src_mark,
    dst_mark = dst_mark,
    arrow = arrow,
    gp = gp,
    circle_size = circle_size,
    name = name,
    obstacle_x = obstacle_x,
    obstacle_y = obstacle_y,
    obstacle_r = obstacle_r,
    route = route,
    cl = "cs_edge_grob"
  )
}

# Given the unit direction (mm space) pointing *into* an arrowhead's tip
# (i.e. the direction of travel arriving at it) and a grid::arrow() object,
# returns the two back-corner offsets from the tip (mm, still to be
# subtracted from the tip position) and how far back along that direction
# the arrowhead's base sits - grid::linesGrob(arrow=) always draws the
# connecting line all the way to the tip, which is fine for a filled
# arrowhead but leaves a visible stroke down the middle of an unfilled one;
# drawing the arrowhead as a separate polygon and stopping the shaft at its
# base avoids that.
.plot_arrowhead_geometry <- function(into_x_mm, into_y_mm, arrow) {
  length_mm <- grid::convertWidth(arrow$length, "mm", valueOnly = TRUE)
  theta <- arrow$angle * pi / 180
  perp_x <- -into_y_mm
  perp_y <- into_x_mm
  cos_t <- cos(theta)
  sin_t <- sin(theta)
  list(
    corner1 = c(
      length_mm * (cos_t * into_x_mm - sin_t * perp_x),
      length_mm * (cos_t * into_y_mm - sin_t * perp_y)
    ),
    corner2 = c(
      length_mm * (cos_t * into_x_mm + sin_t * perp_x),
      length_mm * (cos_t * into_y_mm + sin_t * perp_y)
    ),
    base_offset_mm = length_mm * cos_t
  )
}

# Shortens a sampled mm-space polyline by trim_start_mm/trim_end_mm of arc
# length at each end (interpolating a new endpoint rather than just
# dropping sample points), for trimming a routed edge's shaft back from an
# arrowhead's tip the same way the straight-line case does.
.plot_trim_polyline <- function(px, py, trim_start_mm, trim_end_mm) {
  n <- length(px)
  seg_dx <- diff(px)
  seg_dy <- diff(py)
  seg_len <- sqrt(seg_dx^2 + seg_dy^2)
  cum_len <- c(0, cumsum(seg_len))
  total_len <- cum_len[n]

  interp_at <- function(s) {
    s <- min(max(s, 0), total_len)
    i <- max(which(cum_len <= s))
    if (i >= n) {
      return(c(px[n], py[n]))
    }
    seg_total <- cum_len[i + 1] - cum_len[i]
    frac <- if (seg_total > 0) (s - cum_len[i]) / seg_total else 0
    c(px[i] + frac * seg_dx[i], py[i] + frac * seg_dy[i])
  }

  s_lo <- trim_start_mm
  s_hi <- total_len - trim_end_mm
  if (s_hi < s_lo) {
    mid <- (s_lo + s_hi) / 2
    s_lo <- mid
    s_hi <- mid
  }

  keep <- which(cum_len > s_lo & cum_len < s_hi)
  lo_pt <- interp_at(s_lo)
  hi_pt <- interp_at(s_hi)
  list(
    x = c(lo_pt[1], px[keep], hi_pt[1]),
    y = c(lo_pt[2], py[keep], hi_pt[2])
  )
}

#' @importFrom grid makeContent
#' @export
makeContent.cs_edge_grob <- function(x) {
  x0_unit <- grid::unit(x$x0, "native")
  y0_unit <- grid::unit(x$y0, "native")
  x1_unit <- grid::unit(x$x1, "native")
  y1_unit <- grid::unit(x$y1, "native")

  dx_mm <- grid::convertWidth(x1_unit - x0_unit, "mm", valueOnly = TRUE)
  dy_mm <- grid::convertHeight(y1_unit - y0_unit, "mm", valueOnly = TRUE)
  length_mm <- sqrt(dx_mm^2 + dy_mm^2)

  if (length_mm > 0) {
    ux_mm <- dx_mm / length_mm
    uy_mm <- dy_mm / length_mm

    r_from_mm <- grid::convertWidth(x$r_from, "mm", valueOnly = TRUE)
    r_to_mm <- grid::convertWidth(x$r_to, "mm", valueOnly = TRUE)

    # The node radii already add half the *node's* stroke width as clearance
    # (see .plot_make_nodes), but not half the *edge's* own stroke width.
    # With the round linejoin used throughout, the arrowhead's tip vertex
    # renders as a small rounded cap extending roughly half the edge's lwd
    # past the mathematical tip coordinate - back toward the node - so
    # without this, the tip's rendered ink oversteps the trimmed endpoint
    # and visibly overlaps the node's circle (confirmed by comparing exact
    # SVG path coordinates against the rendered output at high zoom: the gap
    # between the tip and the node's stroke was consistently short by almost
    # exactly half the edge's lwd).
    edge_lwd <- x$gp$lwd %||% 1
    half_edge_lwd_mm <- grid::convertWidth(
      grid::unit(edge_lwd / 192, "inches"),
      "mm",
      valueOnly = TRUE
    )
    r_from_mm <- r_from_mm + half_edge_lwd_mm
    r_to_mm <- r_to_mm + half_edge_lwd_mm

    x0_adj <- x0_unit +
      grid::convertWidth(grid::unit(ux_mm * r_from_mm, "mm"), "native")
    y0_adj <- y0_unit +
      grid::convertHeight(grid::unit(uy_mm * r_from_mm, "mm"), "native")
    x1_adj <- x1_unit -
      grid::convertWidth(grid::unit(ux_mm * r_to_mm, "mm"), "native")
    y1_adj <- y1_unit -
      grid::convertHeight(grid::unit(uy_mm * r_to_mm, "mm"), "native")
  } else {
    x0_adj <- x0_unit
    y0_adj <- y0_unit
    x1_adj <- x1_unit
    y1_adj <- y1_unit
  }

  # Route the edge around any non-incident nodes it would otherwise cross.
  # Detection and curve construction happen in mm, since the layout's native
  # [0, 1] space is aspect-distorted. The curve is built between node centers
  # and clipped to the borders, so the edge projects radially from each
  # center, matching the straight-line case below.
  path <- NULL
  # Endpoint tangents (mm): default to the straight-line direction.
  t0 <- c(ux_mm, uy_mm)
  t1 <- c(ux_mm, uy_mm)

  if (isTRUE(x$route) && length_mm > 0 && length(x$obstacle_x) > 0) {
    c0x <- grid::convertX(x0_unit, "mm", valueOnly = TRUE)
    c0y <- grid::convertY(y0_unit, "mm", valueOnly = TRUE)
    c1x <- grid::convertX(x1_unit, "mm", valueOnly = TRUE)
    c1y <- grid::convertY(y1_unit, "mm", valueOnly = TRUE)

    ox <- grid::convertX(
      grid::unit(x$obstacle_x, "native"),
      "mm",
      valueOnly = TRUE
    )
    oy <- grid::convertY(
      grid::unit(x$obstacle_y, "native"),
      "mm",
      valueOnly = TRUE
    )
    or <- vapply(
      x$obstacle_r,
      function(r) grid::convertWidth(r, "mm", valueOnly = TRUE),
      numeric(1)
    )

    lwd_pt <- x$gp$lwd %||% 1
    line_hw_mm <- (lwd_pt / 72.27 * 25.4) / 2
    clearance <- line_hw_mm + 1.0

    path <- route_edge_path(
      c0x,
      c0y,
      c1x,
      c1y,
      r_from_mm,
      r_to_mm,
      ox,
      oy,
      or,
      clearance
    )
  }

  # Endpoint tangents from the first/last sampled segments, computed before
  # any arrowhead trimming below (so endpoint circles, which aren't
  # trimmed, still sit tangent to the curve).
  if (!is.null(path)) {
    m <- length(path$x)
    d0 <- c(path$x[2] - path$x[1], path$y[2] - path$y[1])
    d1 <- c(path$x[m] - path$x[m - 1], path$y[m] - path$y[m - 1])
    n0 <- sqrt(sum(d0^2))
    n1 <- sqrt(sum(d1^2))
    if (n0 > 0) {
      t0 <- d0 / n0
    }
    if (n1 > 0) {
      t1 <- d1 / n1
    }
  }

  # "Arrow" marks are drawn as separate closed polygons rather than via
  # linesGrob(arrow=): that always draws the connecting line all the way to
  # the tip, which is invisible for a filled arrowhead but leaves a visible
  # stroke down the middle of ours, which is unfilled. The shaft is trimmed
  # back to each arrowhead's base (trim_start_mm/trim_end_mm) to match.
  arrow_grobs <- grid::gList()
  trim_start_mm <- 0
  trim_end_mm <- 0

  .arrowhead_grob <- function(tip_x, tip_y, into) {
    geo <- .plot_arrowhead_geometry(into[1], into[2], x$arrow)
    if (is.null(path)) {
      c1x <- tip_x -
        grid::convertWidth(grid::unit(geo$corner1[1], "mm"), "native")
      c1y <- tip_y -
        grid::convertHeight(grid::unit(geo$corner1[2], "mm"), "native")
      c2x <- tip_x -
        grid::convertWidth(grid::unit(geo$corner2[1], "mm"), "native")
      c2y <- tip_y -
        grid::convertHeight(grid::unit(geo$corner2[2], "mm"), "native")
      grob <- grid::polygonGrob(
        x = grid::unit.c(c1x, tip_x, c2x),
        y = grid::unit.c(c1y, tip_y, c2y),
        gp = x$gp
      )
    } else {
      grob <- grid::polygonGrob(
        x = grid::unit(
          c(tip_x - geo$corner1[1], tip_x, tip_x - geo$corner2[1]),
          "mm"
        ),
        y = grid::unit(
          c(tip_y - geo$corner1[2], tip_y, tip_y - geo$corner2[2]),
          "mm"
        ),
        gp = x$gp
      )
    }
    list(grob = grob, base_offset_mm = geo$base_offset_mm)
  }

  if (!is.null(x$arrow) && x$src_mark == "Arrow") {
    tip <- if (is.null(path)) {
      list(x0_adj, y0_adj)
    } else {
      list(path$x[1], path$y[1])
    }
    res <- .arrowhead_grob(tip[[1]], tip[[2]], -t0)
    arrow_grobs <- grid::gList(arrow_grobs, res$grob)
    trim_start_mm <- res$base_offset_mm
  }
  if (!is.null(x$arrow) && x$dst_mark == "Arrow") {
    tip <- if (is.null(path)) {
      list(x1_adj, y1_adj)
    } else {
      list(path$x[m], path$y[m])
    }
    res <- .arrowhead_grob(tip[[1]], tip[[2]], t1)
    arrow_grobs <- grid::gList(arrow_grobs, res$grob)
    trim_end_mm <- res$base_offset_mm
  }

  # Line grob: curved polyline if routed, straight line otherwise; shaft
  # stopped short of any arrowhead's tip at its base.
  if (is.null(path)) {
    x0_line <- x0_adj +
      grid::convertWidth(grid::unit(ux_mm * trim_start_mm, "mm"), "native")
    y0_line <- y0_adj +
      grid::convertHeight(grid::unit(uy_mm * trim_start_mm, "mm"), "native")
    x1_line <- x1_adj -
      grid::convertWidth(grid::unit(ux_mm * trim_end_mm, "mm"), "native")
    y1_line <- y1_adj -
      grid::convertHeight(grid::unit(uy_mm * trim_end_mm, "mm"), "native")
    line_grob <- grid::linesGrob(
      x = grid::unit.c(x0_line, x1_line),
      y = grid::unit.c(y0_line, y1_line),
      gp = x$gp
    )
  } else {
    trimmed <- .plot_trim_polyline(path$x, path$y, trim_start_mm, trim_end_mm)
    line_grob <- grid::linesGrob(
      x = grid::unit(trimmed$x, "mm"),
      y = grid::unit(trimmed$y, "mm"),
      gp = x$gp
    )
  }

  grob_list <- grid::gList(line_grob, arrow_grobs)

  # "Circle" marks (PAG-style unknown endpoints, e.g. o->, o-o) get a small
  # open circle drawn just outside the node boundary, in the gap left by the
  # radius trim above (or, for a routed edge, tangent to the curve); filled
  # white so it visually breaks the line beneath it.
  if (length_mm > 0 && (x$src_mark == "Circle" || x$dst_mark == "Circle")) {
    circle_radius <- grid::unit(x$circle_size, "mm")
    circle_radius_mm <- grid::convertWidth(
      circle_radius,
      "mm",
      valueOnly = TRUE
    )
    circle_gp <- grid::gpar(col = x$gp$col, fill = "white", lwd = x$gp$lwd)

    if (!is.null(path)) {
      circle_x0 <- grid::unit(path$x[1] + t0[1] * circle_radius_mm, "mm")
      circle_y0 <- grid::unit(path$y[1] + t0[2] * circle_radius_mm, "mm")
      circle_x1 <- grid::unit(path$x[m] - t1[1] * circle_radius_mm, "mm")
      circle_y1 <- grid::unit(path$y[m] - t1[2] * circle_radius_mm, "mm")
    } else {
      circle_x0 <- x0_adj +
        grid::convertWidth(grid::unit(t0[1] * circle_radius_mm, "mm"), "native")
      circle_y0 <- y0_adj +
        grid::convertHeight(
          grid::unit(t0[2] * circle_radius_mm, "mm"),
          "native"
        )
      circle_x1 <- x1_adj -
        grid::convertWidth(grid::unit(t1[1] * circle_radius_mm, "mm"), "native")
      circle_y1 <- y1_adj -
        grid::convertHeight(
          grid::unit(t1[2] * circle_radius_mm, "mm"),
          "native"
        )
    }

    if (x$src_mark == "Circle") {
      grob_list <- grid::gList(
        grob_list,
        grid::circleGrob(
          x = circle_x0,
          y = circle_y0,
          r = circle_radius,
          gp = circle_gp
        )
      )
    }
    if (x$dst_mark == "Circle") {
      grob_list <- grid::gList(
        grob_list,
        grid::circleGrob(
          x = circle_x1,
          y = circle_y1,
          r = circle_radius,
          gp = circle_gp
        )
      )
    }
  }

  grid::setChildren(x, grob_list)
}

# Arrow spec for an edge given its endpoint marks, or NULL for edges with no
# "Arrow" end (undirected `---`, or fully-circle `o-o`).
.plot_edge_arrow <- function(src_mark, dst_mark, arrow_size) {
  ends <- if (src_mark == "Arrow" && dst_mark == "Arrow") {
    "both"
  } else if (dst_mark == "Arrow") {
    "last"
  } else if (src_mark == "Arrow") {
    "first"
  } else {
    NA
  }
  if (identical(ends, NA)) {
    return(NULL)
  }
  grid::arrow(
    length = grid::unit(arrow_size, "mm"),
    ends = ends,
    type = "closed"
  )
}

.plot_make_edges <- function(edges, coords, node_radii, edge_style) {
  n_edges <- nrow(edges)
  edge_grobs <- grid::gList()

  by_edge <- edge_style$by_edge

  for (i in seq_len(n_edges)) {
    from_name <- edges$from[i]
    to_name <- edges$to[i]
    from_idx <- match(from_name, coords$name)
    to_idx <- match(to_name, coords$name)

    # Every other node is a candidate obstacle for routing. Exclude the two
    # endpoints by index (robust to duplicate coordinates).
    obstacle_idx <- setdiff(seq_len(nrow(coords)), c(from_idx, to_idx))

    style <- edge_style$global

    # Precedence (highest to lowest): specific from->to/to->from override >
    # node-wide "to" override > node-wide "from" override > global style.
    override <- list()

    if (!is.null(by_edge[[from_name]][[to_name]])) {
      override <- utils::modifyList(override, by_edge[[from_name]][[to_name]])
    } else if (!is.null(by_edge[[to_name]][[from_name]])) {
      override <- utils::modifyList(override, by_edge[[to_name]][[from_name]])
    }

    for (node_name in c(from_name, to_name)) {
      node_wide <- by_edge[[node_name]]
      if (!is.null(node_wide)) {
        node_wide <- node_wide[!vapply(node_wide, is.list, logical(1))]
        if (length(node_wide) > 0) {
          override <- utils::modifyList(node_wide, override)
        }
      }
    }

    if (length(override) > 0) {
      style <- utils::modifyList(style, override)
    }

    # Arrowheads are filled polygons (see .plot_edge_grob); default fill to
    # the edge's own resolved col so a recolored edge doesn't end up with a
    # mismatched black arrowhead. Set fill = NA explicitly for a hollow
    # arrowhead.
    if (is.null(style$fill)) {
      style$fill <- style$col
    }

    edge_gpar <- do.call(grid::gpar, .plot_gpar_params(style))
    arrow <- .plot_edge_arrow(
      edges$src_mark[i],
      edges$dst_mark[i],
      style$arrow_size
    )

    edge_grobs[[i]] <- .plot_edge_grob(
      x0 = coords$x[from_idx],
      y0 = coords$y[from_idx],
      x1 = coords$x[to_idx],
      y1 = coords$y[to_idx],
      r_from = node_radii[[from_idx]],
      r_to = node_radii[[to_idx]],
      src_mark = edges$src_mark[i],
      dst_mark = edges$dst_mark[i],
      arrow = arrow,
      gp = edge_gpar,
      circle_size = style$circle_size,
      name = paste0("edge.", i),
      obstacle_x = coords$x[obstacle_idx],
      obstacle_y = coords$y[obstacle_idx],
      obstacle_r = node_radii[obstacle_idx],
      route = isTRUE(style$route)
    )
  }

  edge_grobs
}

#' Plot a causal graph
#'
#' Plot method for `cgraph`.
#'
#' @param x A graph created with [cgraph()], of any class.
#' @param layout Specifies the layout. Can be:
#'   * A character string passed to [layout.cgraph()] as `method`
#'     (`"circle"`, `"spring"`, `"stress"`, `"sfdp"`, `"spectral"`,
#'     `"shell"`, `"squaregrid"`).
#'   * A layout function, called with `x` and any `...`.
#'   * A pre-computed layout `data.frame` with columns `name`, `x`, `y`.
#' @param node_style List of node styling parameters: `fill`, `col`, `lwd`,
#'   `padding` (mm, default 2), `size` (multiplier, default 1), and `by_node`
#'   (named list of per-node overrides).
#' @param edge_style List of edge styling parameters: `col`, `lwd`, `fill`
#'   (arrowhead fill color; defaults to `col` so arrowheads render solid and
#'   match the edge - pass `fill = NA` for a hollow/outline arrowhead),
#'   `arrow_size` (mm, default 3), `circle_size` (mm, default 1.5, for
#'   `o->`/`o--`/`o-o` endpoints), `route` (logical, default `TRUE`; when
#'   `TRUE`, an edge that would otherwise cross a non-incident node bends
#'   around it as a Bezier curve), and `by_edge` (named list of per-edge or
#'   per-node overrides, keyed by node name(s)).
#' @param label_style List of label styling parameters: `col`, `fontsize`,
#'   `fontface`, `fontfamily`, `cex`.
#' @param main Optional plot title.
#' @param title_style List of title styling parameters (same fields as
#'   `label_style`).
#' @param asp Optional y/x aspect ratio. `NA` (default) fills the available
#'   space; `asp = 1` makes one x-unit equal one y-unit.
#' @param outer_margin Grid unit for the outer margin. Default
#'   `grid::unit(2, "mm")`.
#' @param title_gap Grid unit for the gap between title and graph. Default
#'   `grid::unit(1, "lines")`.
#' @param newpage If `TRUE` (default), call [grid::grid.newpage()] before
#'   drawing.
#' @param ... Passed to `layout` when it is a character string or function.
#'
#' @returns A `cgraph_plot` object, invisibly. Drawn immediately as a side
#'   effect; re-drawn if printed or passed to `plot()` again.
#'
#' @examples
#' if (julia_available()) {
#'   dag <- cgraph("A --> X + Y, X --> M --> Y")
#'   plot(dag)
#'   plot(dag, layout = "circle", main = "Quick guide DAG")
#' }
#' @rdname plot
#' @family plotting
#' @export
plot.cgraph <- function(
  x,
  layout = "stress",
  node_style = list(),
  edge_style = list(),
  label_style = list(),
  main = NULL,
  title_style = list(),
  asp = NA,
  outer_margin = grid::unit(2, "mm"),
  title_gap = grid::unit(1, "lines"),
  newpage = TRUE,
  ...
) {
  stopifnot(
    is.null(asp) ||
      is.na(asp) ||
      isTRUE(is.numeric(asp) && length(asp) == 1 && asp > 0)
  )

  if (is.character(layout)) {
    # Calls layout.cgraph() directly rather than the layout() generic:
    # `layout` here is this function's own parameter (a string), so
    # layout(x, ...) would dispatch on that instead of on `x`.
    coords <- layout.cgraph(x, method = layout, ...)
  } else if (is.function(layout)) {
    coords <- layout(x, ...)
  } else if (is.data.frame(layout)) {
    required_cols <- c("name", "x", "y")
    missing_cols <- setdiff(required_cols, names(layout))
    if (length(missing_cols) > 0) {
      stop(
        "Layout data.frame is missing required column(s): ",
        paste(missing_cols, collapse = ", "),
        call. = FALSE
      )
    }
    graph_nodes <- nodes(x)
    if (nrow(layout) != length(graph_nodes)) {
      stop(
        "Layout has ",
        nrow(layout),
        " row(s) but graph has ",
        length(graph_nodes),
        " node(s)",
        call. = FALSE
      )
    }
    missing_nodes <- setdiff(graph_nodes, layout$name)
    if (length(missing_nodes) > 0) {
      stop(
        "Layout is missing coordinates for node(s): ",
        paste(missing_nodes, collapse = ", "),
        call. = FALSE
      )
    }
    coords <- layout[match(graph_nodes, layout$name), , drop = FALSE]
  } else {
    stop(
      "layout must be a character string, function, or data.frame",
      call. = FALSE
    )
  }

  if (nrow(coords) == 0) {
    stop("Cannot plot an empty graph (0 nodes).", call. = FALSE)
  }

  styles <- .plot_make_styles(node_style, edge_style, label_style, title_style)

  labels <- coords$name
  edges <- .plot_edges(x)

  x_range <- range(coords$x)
  y_range <- range(coords$y)
  if (x_range[1] == x_range[2]) {
    x_range <- x_range + c(-1, 1)
  }
  if (y_range[1] == y_range[2]) {
    y_range <- y_range + c(-1, 1)
  }

  nodes_res <- .plot_make_nodes(
    coords,
    labels,
    styles$node_style,
    styles$label_style
  )
  edge_grobs <- .plot_make_edges(
    edges,
    coords,
    nodes_res$node_radii,
    styles$edge_style
  )

  vp_x <- grid::unit(0.5, "npc")
  vp_y <- grid::unit(0.5, "npc")
  vp_width <- grid::unit(1, "npc") -
    max(grid::grobWidth(nodes_res$circle_grobs))
  vp_height <- grid::unit(1, "npc") -
    max(grid::grobHeight(nodes_res$circle_grobs))

  if (!is.null(asp) && !is.na(asp) && is.numeric(asp) && asp > 0) {
    data_width <- diff(x_range)
    data_height <- diff(y_range)
    data_asp <- data_height / data_width
    if (data_asp > asp) {
      vp_width <- vp_height * (data_width / data_height) * asp
    } else {
      vp_height <- vp_width * (data_height / data_width) / asp
    }
  }

  graph_vp <- grid::viewport(
    x = vp_x,
    y = vp_y,
    xscale = x_range,
    yscale = y_range,
    width = vp_width,
    height = vp_height,
    name = "cs.vp"
  )

  node_gtree <- grid::grobTree(
    nodes_res$circle_grobs,
    nodes_res$label_grobs,
    name = "node_gtree"
  )

  graph_grob <- grid::gTree(
    children = grid::gList(edge_grobs, node_gtree),
    vp = graph_vp,
    name = "cs.graph"
  )

  title_grob <- if (is.null(main)) {
    grid::nullGrob(name = "title")
  } else {
    title_gpar <- do.call(grid::gpar, .plot_gpar_params(styles$title_style))
    grid::textGrob(label = main, gp = title_gpar, name = "title")
  }

  title_height <- grid::unit(1, "grobheight", list(title_grob))
  if (is.null(main)) {
    title_gap <- grid::unit(0, "mm")
  }

  layout_vp <- grid::viewport(
    layout = grid::grid.layout(
      nrow = 5,
      ncol = 3,
      heights = grid::unit.c(
        outer_margin,
        title_height,
        title_gap,
        grid::unit(1, "null"),
        outer_margin
      ),
      widths = grid::unit.c(outer_margin, grid::unit(1, "null"), outer_margin)
    ),
    name = "layout"
  )

  title_grob$vp <- grid::vpStack(
    layout_vp,
    grid::viewport(layout.pos.row = 2, layout.pos.col = 2)
  )
  graph_grob$vp <- grid::vpStack(
    layout_vp,
    grid::viewport(layout.pos.row = 4, layout.pos.col = 2),
    graph_vp
  )

  final_grob <- grid::gTree(
    children = grid::gList(title_grob, graph_grob),
    name = "cs.titled"
  )

  result <- structure(list(grob = final_grob), class = "cgraph_plot")
  if (newpage) {
    grid::grid.newpage()
  }
  grid::grid.draw(result$grob)
  invisible(result)
}

#' @export
print.cgraph_plot <- function(x, ...) {
  plot(x, ...)
}

#' @export
plot.cgraph_plot <- function(x, newpage = TRUE, ...) {
  if (newpage) {
    grid::grid.newpage()
  }
  grid::grid.draw(x$grob)
  invisible(x)
}
