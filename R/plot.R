# --- Plotting ------------------------------------------------------------
#
# Grid-graphics rendering adapted from caugi's plotting code (R/plot-core.R,
# R/plot-grobs.R by Frederik Fabricius-Bjerre and Johan Larsson). See
# inst/COPYRIGHTS for attribution and cgraph_layout() (causal-structures-
# layout.R) for the layout algorithm.
#
# Each edge carries a Tail/Arrow/Circle mark at each endpoint (see
# CausalStructures.jl's CausalEdge), covering directed, undirected,
# bidirected, and partially-marked (PAG-style) edges alike: an "Arrow" mark
# draws an arrowhead at that end, a "Circle" mark draws a small open circle,
# and "Tail" draws nothing (a plain line end).
#
# Style defaults (node/edge/label/title) are read from plot_options()
# (plot-options.R) in .plot_make_styles() below, so they can be overridden
# globally as well as per-call.

# Edges with their per-endpoint Tail/Arrow/Circle marks, for drawing (as
# opposed to edges(), which collapses the two marks into a single `type`
# notation column, e.g. "-->").
.plot_edges <- function(cg) {
  mat <- jl_edge_marks(cg)
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
  node_by = list(),
  label_by = list(),
  edge_overrides = list(),
  title_style = list()
) {
  # Defaults come from plot_options() (plot-options.R); the per-node and
  # per-edge overrides recorded by the style verbs (plot-compose.R) go on top.
  opts <- plot_options()
  label_style <- opts$label_style
  label_style$by_node <- label_by
  list(
    node_style = list(global = opts$node_style, by_node = node_by),
    edge_style = list(global = opts$edge_style, by_index = edge_overrides),
    label_style = label_style,
    title_style = utils::modifyList(opts$title_style, title_style)
  )
}

.NODE_SHAPES <- c("circle", "square", "ellipse", "rect")

# Range check for a resolved numeric style value, mirroring
# CausalStructures.jl's `_check_value`, e.g.
# `.plot_check_value(r > 0, "radius", r, "node \"A\"", "positive")`.
# A NULL value (unset) always passes.
.plot_check_value <- function(value, ok, name, target, requirement) {
  if (is.null(value) || isTRUE(ok(value))) {
    return(invisible(value))
  }
  stop(
    sprintf(
      "`%s` must be %s, got %s for %s.",
      name,
      requirement,
      format(value),
      target
    ),
    call. = FALSE
  )
}

.plot_check_node_style <- function(style, node_name) {
  target <- sprintf("node \"%s\"", node_name)
  positive <- function(v) is.numeric(v) && length(v) == 1 && v > 0
  non_negative <- function(v) is.numeric(v) && length(v) == 1 && v >= 0
  .plot_check_value(
    style$radius,
    positive,
    "radius",
    target,
    "positive"
  )
  .plot_check_value(
    style$padding,
    non_negative,
    "padding",
    target,
    "non-negative"
  )
  .plot_check_value(
    style$lwd,
    non_negative,
    "lwd",
    target,
    "non-negative"
  )
  .plot_check_value(style$size, positive, "size", target, "positive")
  invisible(style)
}

.plot_check_edge_style <- function(style, target) {
  non_negative <- function(v) is.numeric(v) && length(v) == 1 && v >= 0
  for (field in c(
    "lwd",
    "arrow_size",
    "circle_size",
    "gap",
    "label_distance"
  )) {
    .plot_check_value(
      style[[field]],
      non_negative,
      field,
      target,
      "non-negative"
    )
  }
  .plot_check_value(
    style$label_shift,
    function(v) is.numeric(v) && length(v) == 1 && v >= 0 && v <= 1,
    "label_shift",
    target,
    "between 0 and 1"
  )
  invisible(style)
}

.plot_is_boxy <- function(shape) shape %in% c("square", "rect")

.plot_shape_half_extents <- function(shape, label, label_style, padding_mm) {
  label_gpar <- do.call(grid::gpar, .plot_gpar_params(label_style))
  tg <- grid::textGrob(label, gp = label_gpar)
  w <- grid::convertWidth(grid::grobWidth(tg), "mm", valueOnly = TRUE)
  h <- grid::convertHeight(grid::grobHeight(tg), "mm", valueOnly = TRUE)

  if (.plot_is_boxy(shape)) {
    hw <- 0.5 * w + padding_mm
    hh <- 0.5 * h + padding_mm
  } else {
    hw <- w / sqrt(2) + padding_mm
    hh <- h / sqrt(2) + padding_mm
  }

  if (shape %in% c("ellipse", "rect")) {
    return(c(hw, hh))
  }

  m <- max(hw, hh)
  c(m, m)
}

# Ellipse (or, when hw == hh, a circle) as a closed polygon of n points,
# since grid has no native ellipse grob. Mirrors the sampled-polygon
# approach CausalStructures.jl's Makie `plot()` uses for the same shape
# (nodes.jl's `_shape_polygon`, n = 60 there too).
.plot_ellipse_grob <- function(x, y, hw, hh, gp, name, n = 60) {
  theta <- seq(0, 2 * pi, length.out = n + 1)[seq_len(n)]
  grid::polygonGrob(
    x = x + grid::unit(hw, "mm") * cos(theta),
    y = y + grid::unit(hh, "mm") * sin(theta),
    gp = gp,
    name = name
  )
}

# Circumradius of a node's shape (mm): the radius of the smallest circle
# centered on the node that fully contains it. Used as a conservative
# bounding circle for non-incident-node obstacle avoidance (route_edge_path()
# tests obstacles as circles; an exact-shape obstacle test isn't done).
.plot_circumradius <- function(shape, hw, hh) {
  if (.plot_is_boxy(shape)) sqrt(hw^2 + hh^2) else max(hw, hh)
}

.plot_make_nodes <- function(coords, labels, node_style, label_style) {
  n_nodes <- nrow(coords)

  circle_grobs <- grid::gList()
  label_grobs <- grid::gList()
  node_geom <- vector("list", n_nodes)

  padding_global_mm <- node_style$global$padding

  for (i in seq_len(n_nodes)) {
    node_name <- coords$name[i]

    style <- node_style$global
    if (!is.null(node_style$by_node[[node_name]])) {
      style <- utils::modifyList(style, node_style$by_node[[node_name]])
    }
    if (!is.null(style$linestyle) && is.null(style$lty)) {
      style$lty <- style$linestyle
    }
    .plot_check_node_style(style, node_name)

    # label_style$by_node overrides the label text style per node, like
    # node_style$by_node does for the node itself.
    node_label_style <- label_style
    if (!is.null(label_style$by_node[[node_name]])) {
      node_label_style <- utils::modifyList(
        label_style,
        label_style$by_node[[node_name]]
      )
    }

    shape <- style$shape %||% "circle"
    if (!shape %in% .NODE_SHAPES) {
      stop(
        sprintf(
          "Unknown node shape %s for node %s. Available: %s.",
          dQuote(shape, q = FALSE),
          dQuote(node_name, q = FALSE),
          paste(dQuote(.NODE_SHAPES, q = FALSE), collapse = ", ")
        ),
        call. = FALSE
      )
    }
    padding_mm <- style$padding %||% padding_global_mm
    unscaled_extents <- if (!is.null(style$radius)) {
      c(style$radius, style$radius)
    } else {
      .plot_shape_half_extents(shape, labels[i], node_label_style, padding_mm)
    }
    half_extents <- unscaled_extents * style$size

    # Node stroke straddles the shape's path (half the line width falls
    # outside it), so edges must be trimmed past that half-width or a thick
    # border can cover the line end (and any arrowhead on it). lwd is in
    # grid's 1/96-inch convention; 1 inch = 25.4 mm.
    # The outline is drawn half a stroke out from the label's extents, so
    # its inner edge clears the label, and its outer edge lies another half
    # stroke beyond that: edges stop there (hw, hh).
    stroke_pad_mm <- style$lwd / 192 * 25.4
    draw_hw <- half_extents[1] + stroke_pad_mm
    draw_hh <- half_extents[2] + stroke_pad_mm
    hw <- draw_hw + stroke_pad_mm
    hh <- draw_hh + stroke_pad_mm

    x <- grid::unit(coords$x[i], "native")
    y <- grid::unit(coords$y[i], "native")

    node_gpar <- do.call(grid::gpar, .plot_gpar_params(style))
    circle_grobs[[i]] <- if (.plot_is_boxy(shape)) {
      grid::rectGrob(
        x = x,
        y = y,
        width = grid::unit(2 * draw_hw, "mm"),
        height = grid::unit(2 * draw_hh, "mm"),
        gp = node_gpar,
        name = paste0("node.", i)
      )
    } else if (isTRUE(all.equal(draw_hw, draw_hh))) {
      grid::circleGrob(
        x = x,
        y = y,
        r = grid::unit(draw_hw, "mm"),
        gp = node_gpar,
        name = paste0("node.", i)
      )
    } else {
      .plot_ellipse_grob(
        x,
        y,
        draw_hw,
        draw_hh,
        node_gpar,
        paste0("node.", i)
      )
    }

    label_gpar <- do.call(grid::gpar, .plot_gpar_params(node_label_style))
    label_grobs[[i]] <- grid::textGrob(
      labels[i],
      x = x,
      y = y,
      gp = label_gpar,
      name = paste0("label.", i)
    )

    node_geom[[i]] <- list(
      shape = shape,
      hw = hw,
      hh = hh,
      circumradius = .plot_circumradius(shape, hw, hh)
    )
  }

  list(
    circle_grobs = circle_grobs,
    label_grobs = label_grobs,
    node_geom = node_geom
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
  geom_from,
  geom_to,
  src_mark,
  dst_mark,
  arrow,
  gp,
  circle_size,
  curvature,
  fan_slot = 0,
  name,
  obstacle_x = numeric(0),
  obstacle_y = numeric(0),
  obstacle_r = numeric(0),
  gap = 0,
  path = NULL,
  label = NULL,
  label_style = list()
) {
  grid::gTree(
    x0 = x0,
    y0 = y0,
    x1 = x1,
    y1 = y1,
    geom_from = geom_from,
    geom_to = geom_to,
    src_mark = src_mark,
    dst_mark = dst_mark,
    arrow = arrow,
    gp = gp,
    circle_size = circle_size,
    curvature = curvature,
    fan_slot = fan_slot,
    name = name,
    obstacle_x = obstacle_x,
    obstacle_y = obstacle_y,
    obstacle_r = obstacle_r,
    gap = gap,
    path = path,
    label = label,
    label_style = label_style,
    cl = "cs_edge_grob"
  )
}

# Given the unit direction (mm space) pointing *into* an arrowhead's tip and
# a grid::arrow() object, returns the two back-corner offsets from the tip
# (mm, still to be subtracted from the tip position) and how far back along
# that direction the arrowhead's base sits.
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

    # The node geometry already adds half the *node's* stroke width as
    # clearance (see .plot_make_nodes), but not half the *edge's* own stroke
    # width. With the round linejoin used throughout, the arrowhead's tip
    # vertex renders as a small rounded cap extending roughly half the
    # edge's lwd past the mathematical tip coordinate - back toward the
    # node - so without this, the tip's rendered ink oversteps the trimmed
    # endpoint and visibly overlaps the node's shape.
    edge_lwd <- x$gp$lwd %||% 1
    half_edge_lwd_mm <- grid::convertWidth(
      grid::unit(edge_lwd / 192, "inches"),
      "mm",
      valueOnly = TRUE
    )
    # The user's `gap` (mm) is added on top, at both ends.
    gap_mm <- x$gap %||% 0
    hw_from <- x$geom_from$hw + half_edge_lwd_mm + gap_mm
    hh_from <- x$geom_from$hh + half_edge_lwd_mm + gap_mm
    hw_to <- x$geom_to$hw + half_edge_lwd_mm + gap_mm
    hh_to <- x$geom_to$hh + half_edge_lwd_mm + gap_mm

    r_from_mm <- .shape_boundary_distance(
      x$geom_from$shape,
      hw_from,
      hh_from,
      ux_mm,
      uy_mm
    )
    r_to_mm <- .shape_boundary_distance(
      x$geom_to$shape,
      hw_to,
      hh_to,
      -ux_mm,
      -uy_mm
    )

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

  # Route the edge around any non-incident nodes it would otherwise cross, or
  # bow it into a manually specified arc. Detection and curve construction
  # happen in mm, since the layout's native [0, 1] space is aspect-distorted.
  # An explicit non-zero curvature takes precedence and skips
  # obstacle-avoidance routing entirely.
  path <- NULL
  # Endpoint tangents (mm): default to the straight-line direction.
  t0 <- c(ux_mm, uy_mm)
  t1 <- c(ux_mm, uy_mm)

  if (length_mm > 0) {
    c0x <- grid::convertX(x0_unit, "mm", valueOnly = TRUE)
    c0y <- grid::convertY(y0_unit, "mm", valueOnly = TRUE)
    c1x <- grid::convertX(x1_unit, "mm", valueOnly = TRUE)
    c1y <- grid::convertY(y1_unit, "mm", valueOnly = TRUE)

    # Explicit waypoints (in layout coordinates) take precedence over every
    # automatic route: a polyline from node center to node center through
    # them, clipped to the two node boundaries.
    if (!is.null(x$path)) {
      waypoints_mm <- if (nrow(x$path) > 0) {
        list(
          x = grid::convertX(grid::unit(x$path[, 1], "native"), "mm", TRUE),
          y = grid::convertY(grid::unit(x$path[, 2], "native"), "mm", TRUE)
        )
      } else {
        list(x = numeric(0), y = numeric(0))
      }
      path <- .plot_clip_polyline(
        c(c0x, waypoints_mm$x, c1x),
        c(c0y, waypoints_mm$y, c1y),
        x$geom_from$shape,
        hw_from,
        hh_from,
        x$geom_to$shape,
        hw_to,
        hh_to
      )
    }

    curvature <- x$curvature
    if (is.null(path) && !is.null(curvature)) {
      path <- bow_edge_path(
        c0x,
        c0y,
        c1x,
        c1y,
        x$geom_from$shape,
        hw_from,
        hh_from,
        x$geom_to$shape,
        hw_to,
        hh_to,
        curvature * length_mm
      )
    }

    if (is.null(path) && length(x$obstacle_x) > 0) {
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
      or <- x$obstacle_r

      lwd_pt <- x$gp$lwd %||% 1
      line_hw_mm <- (lwd_pt / 72.27 * 25.4) / 2
      clearance <- line_hw_mm + 1.0

      path <- route_edge_path(
        c0x,
        c0y,
        c1x,
        c1y,
        x$geom_from$shape,
        hw_from,
        hh_from,
        x$geom_to$shape,
        hw_to,
        hh_to,
        ox,
        oy,
        or,
        clearance
      )
    }

    # No explicit curvature and no obstacle to route around: fan parallel
    # edges between the same node pair (e.g. an ADMG's X-->Y/X<->Y) apart so
    # they don't draw as overlapping lines - see .plot_edge_fan_slots().
    fan_slot <- x$fan_slot %||% 0
    if (is.null(path) && fan_slot != 0) {
      path <- bow_edge_path(
        c0x,
        c0y,
        c1x,
        c1y,
        x$geom_from$shape,
        hw_from,
        hh_from,
        x$geom_to$shape,
        hw_to,
        hh_to,
        fan_slot * 0.3 * length_mm
      )
    }
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

  if (length_mm > 0 && !is.null(x$label)) {
    label_path <- if (is.null(path)) {
      list(
        x = grid::convertX(grid::unit.c(x0_adj, x1_adj), "mm", TRUE),
        y = grid::convertY(grid::unit.c(y0_adj, y1_adj), "mm", TRUE)
      )
    } else {
      path
    }
    grob_list <- grid::gList(
      grob_list,
      .plot_edge_label_grob(label_path, x$label, x$label_style)
    )
  }

  grid::setChildren(x, grob_list)
}

# Point (mm) at arc-length fraction `f` along a polyline.
.plot_polyline_point <- function(px, py, f) {
  seg <- sqrt(diff(px)^2 + diff(py)^2)
  cum <- c(0, cumsum(seg))
  s <- f * cum[length(cum)]
  i <- min(max(which(cum <= s)), length(px) - 1L)
  frac <- if (seg[i] > 0) (s - cum[i]) / seg[i] else 0
  c(px[i] + frac * (px[i + 1] - px[i]), py[i] + frac * (py[i + 1] - py[i]))
}

# An edge's text label, mirroring CausalStructures.jl's Makie `plot()`: placed
# at fraction `label_shift` along the drawn path and offset perpendicular to
# its local tangent (to the left of the edge's direction) by
# `label_distance` mm, which defaults to the label's own font size. The text
# follows the edge's angle, turned to read upright, unless `label_rotation`
# (degrees) fixes it.
.plot_edge_label_grob <- function(path, label, style) {
  shift <- style$shift %||% 0.5
  mid <- .plot_polyline_point(path$x, path$y, shift)
  ahead <- .plot_polyline_point(path$x, path$y, min(shift + 0.02, 1))
  behind <- .plot_polyline_point(path$x, path$y, max(shift - 0.02, 0))
  tangent <- ahead - behind
  tangent <- tangent / max(sqrt(sum(tangent^2)), 1e-9)
  perp <- c(-tangent[2], tangent[1])

  fontsize <- style$fontsize %||% 9
  distance_mm <- style$distance %||% (fontsize / 72.27 * 25.4)
  pos <- mid + distance_mm * perp

  rotation <- style$rotation
  if (is.null(rotation)) {
    rotation <- atan2(tangent[2], tangent[1]) * 180 / pi
    if (rotation > 90) {
      rotation <- rotation - 180
    } else if (rotation < -90) {
      rotation <- rotation + 180
    }
  }

  gp <- Filter(
    Negate(is.null),
    list(
      col = style$col,
      fontsize = fontsize,
      fontface = style$fontface,
      fontfamily = style$fontfamily
    )
  )
  grid::textGrob(
    as.character(label),
    x = grid::unit(pos[1], "mm"),
    y = grid::unit(pos[2], "mm"),
    rot = rotation,
    gp = do.call(grid::gpar, gp)
  )
}

#' @importFrom grid makeContent
#' @export
makeContent.cs_graph_grob <- function(x) {
  vp_width_mm <- grid::convertWidth(
    grid::unit(1, "npc"),
    "mm",
    valueOnly = TRUE
  )
  vp_height_mm <- grid::convertHeight(
    grid::unit(1, "npc"),
    "mm",
    valueOnly = TRUE
  )

  padded <- .plot_curvature_padded_range(
    x$cs_edges,
    x$cs_coords,
    x$cs_edge_style,
    x$cs_node_geom,
    x$cs_x_range,
    x$cs_y_range,
    vp_width_mm,
    vp_height_mm
  )

  content_vp <- grid::viewport(
    xscale = padded$x_range,
    yscale = padded$y_range,
    name = paste0(x$name, ".scale")
  )

  content <- grid::gTree(
    children = x$children,
    vp = content_vp,
    name = paste0(x$name, ".content")
  )

  grid::setChildren(x, grid::gList(content))
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

# Resolves one edge's style: the plot_options() default with the edge's own
# overrides from style_edges() on top. Split out from .plot_make_edges() so it
# can be unit-tested directly.
.plot_edge_style <- function(edges, i, edge_style) {
  style <- edge_style$global
  by_index <- edge_style$by_index
  if (i <= length(by_index) && !is.null(by_index[[i]])) {
    style <- utils::modifyList(style, by_index[[i]])
  }

  # Arrowheads are filled polygons (see .plot_edge_grob); default fill to
  # the edge's own resolved col so a recolored edge doesn't end up with a
  # mismatched black arrowhead. Set fill = NA explicitly for a hollow
  # arrowhead.
  if (is.null(style$fill)) {
    style$fill <- style$col
  }

  style
}

# Waypoints of an edge `path` as a k-by-2 numeric matrix, from a two-column
# matrix, a data.frame with `x` and `y` columns, a list of `c(x, y)` points,
# or a single `c(x, y)` point.
.plot_waypoints <- function(path) {
  if (is.null(path)) {
    return(NULL)
  }
  if (is.data.frame(path)) {
    path <- cbind(path$x, path$y)
  } else if (is.list(path)) {
    path <- do.call(rbind, lapply(path, as.numeric))
  } else if (is.numeric(path) && is.null(dim(path))) {
    path <- matrix(path, ncol = 2, byrow = TRUE)
  }
  if (!is.matrix(path) || !is.numeric(path) || ncol(path) != 2 || anyNA(path)) {
    stop(
      "An edge `path` must be a two-column matrix, a data.frame with `x` ",
      "and `y` columns, or a list of c(x, y) points.",
      call. = FALSE
    )
  }
  unname(path)
}

# Assigns each edge a signed fan-out slot: 0 when it is the only edge on its
# (undirected) node pair, otherwise evenly spaced values centered on 0.
# Grouping ignores direction, so antiparallel edges fan out too - and since
# the slot is later applied as a bow along each edge's own from->to vector, a
# reversed edge needs its slot's sign flipped to land opposite its sibling
# rather than on top of it.
.plot_edge_fan_slots <- function(from, to) {
  n <- length(from)
  slots <- numeric(n)
  lo <- ifelse(from < to, from, to)
  hi <- ifelse(from < to, to, from)
  key <- paste(lo, hi, sep = "\r")

  for (k in unique(key)) {
    idx <- which(key == k)
    m <- length(idx)
    if (m <= 1) {
      next
    }
    for (rank in seq_along(idx)) {
      i <- idx[rank]
      raw <- (rank - 1) - (m - 1) / 2
      flip <- if (from[i] == lo[i]) 1 else -1
      slots[i] <- raw * flip
    }
  }

  slots
}

# Widens x_range/y_range so an explicit `curvature`'s Bezier bow fits inside
# the graph viewport instead of bowing out past the plot boundary - the
# curvature counterpart to the node-radius margin in cgraph_grob(). Traces
# each curved edge with the real bow_edge_path() geometry and iterates,
# since padding one axis changes that axis's native-to-mm scale, which
# changes how much mm bulge an edge running along the *other* axis produces.
.plot_curvature_padded_range <- function(
  edges,
  coords,
  edge_style,
  node_geom,
  x_range,
  y_range,
  vp_width_mm,
  vp_height_mm,
  n_iter = 8L
) {
  curved <- list()
  for (i in seq_len(nrow(edges))) {
    style <- .plot_edge_style(edges, i, edge_style)
    curvature <- style$curvature
    if (is.null(curvature) || curvature == 0) {
      next
    }
    curved[[length(curved) + 1]] <- list(
      from_idx = match(edges$from[i], coords$name),
      to_idx = match(edges$to[i], coords$name),
      curvature = curvature
    )
  }
  if (length(curved) == 0) {
    return(list(x_range = x_range, y_range = y_range))
  }

  for (iter in seq_len(n_iter)) {
    scale_x <- vp_width_mm / diff(x_range)
    scale_y <- vp_height_mm / diff(y_range)
    x_min <- x_range[1]
    x_max <- x_range[2]
    y_min <- y_range[1]
    y_max <- y_range[2]

    for (edge in curved) {
      geom_from <- node_geom[[edge$from_idx]]
      geom_to <- node_geom[[edge$to_idx]]
      p0x <- coords$x[edge$from_idx] * scale_x
      p0y <- coords$y[edge$from_idx] * scale_y
      p2x <- coords$x[edge$to_idx] * scale_x
      p2y <- coords$y[edge$to_idx] * scale_y
      length_mm <- sqrt((p2x - p0x)^2 + (p2y - p0y)^2)

      path <- bow_edge_path(
        p0x,
        p0y,
        p2x,
        p2y,
        geom_from$shape,
        geom_from$hw,
        geom_from$hh,
        geom_to$shape,
        geom_to$hw,
        geom_to$hh,
        edge$curvature * length_mm
      )
      if (is.null(path)) {
        next
      }

      path_x <- path$x / scale_x
      path_y <- path$y / scale_y
      x_min <- min(x_min, path_x)
      x_max <- max(x_max, path_x)
      y_min <- min(y_min, path_y)
      y_max <- max(y_max, path_y)
    }

    x_range <- c(x_min, x_max)
    y_range <- c(y_min, y_max)
  }

  list(x_range = x_range, y_range = y_range)
}

.plot_make_edges <- function(
  edges,
  coords,
  node_geom,
  edge_style,
  auto_paths = NULL
) {
  n_edges <- nrow(edges)
  edge_grobs <- grid::gList()
  fan_slots <- .plot_edge_fan_slots(edges$from, edges$to)

  for (i in seq_len(n_edges)) {
    from_name <- edges$from[i]
    to_name <- edges$to[i]
    from_idx <- match(from_name, coords$name)
    to_idx <- match(to_name, coords$name)

    # Every other node is a candidate obstacle for routing. Exclude the two
    # endpoints by index (robust to duplicate coordinates).
    obstacle_idx <- setdiff(seq_len(nrow(coords)), c(from_idx, to_idx))

    style <- .plot_edge_style(edges, i, edge_style)
    .plot_check_edge_style(
      style,
      sprintf(
        "edge %s %s %s",
        from_name,
        .plot_edge_notation(edges, i),
        to_name
      )
    )

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
      geom_from = node_geom[[from_idx]],
      geom_to = node_geom[[to_idx]],
      src_mark = edges$src_mark[i],
      dst_mark = edges$dst_mark[i],
      arrow = arrow,
      gp = edge_gpar,
      circle_size = style$circle_size,
      curvature = style$curvature,
      fan_slot = fan_slots[i],
      name = paste0("edge.", i),
      obstacle_x = coords$x[obstacle_idx],
      obstacle_y = coords$y[obstacle_idx],
      obstacle_r = vapply(
        node_geom[obstacle_idx],
        function(g) g$circumradius,
        numeric(1)
      ),
      gap = style$gap %||% 0,
      path = .plot_waypoints(style$path) %||% auto_paths[[i]],
      label = style$label,
      label_style = list(
        col = style$label_col,
        fontsize = style$label_fontsize,
        fontface = style$label_fontface,
        fontfamily = style$label_fontfamily,
        shift = style$label_shift,
        distance = style$label_distance,
        rotation = style$label_rotation
      )
    )
  }

  edge_grobs
}

# An edge's notation, e.g. "-->", for messages.
.plot_edge_notation <- function(edges, i) {
  unname(.edge_mark_types[
    paste(edges$src_mark[i], edges$dst_mark[i], sep = ".")
  ])
}

# Node positions and edge routes from Sugiyama.jl's layered layout. Each
# route is a k-by-2 matrix of layout coordinates from the edge's source to
# its destination, through Sugiyama's bend points. Node pairs with more than
# one edge (e.g. an ADMG's X --> Y and X <-> Y) get no route, so they fan out
# apart as usual instead of sharing one.
.plot_sugiyama <- function(x, direction) {
  res <- jl_sugiyama_paths(x, direction)
  edges <- .plot_edges(x)
  lo <- pmin(edges$from, edges$to)
  hi <- pmax(edges$from, edges$to)
  key <- paste(lo, hi, sep = "\r")
  routes <- lapply(res[[2L]], function(m) m[-c(1L, nrow(m)), , drop = FALSE])
  routes[key %in% key[duplicated(key)]] <- list(NULL)
  list(
    coords = data.frame(
      name = nodes(x),
      x = res[[1L]][, 1L],
      y = res[[1L]][, 2L],
      stringsAsFactors = FALSE
    ),
    paths = routes
  )
}

#' Plot a causal graph
#'
#' `cgraph_plot()` builds a plot of a `cgraph`, drawn with grid graphics when it
#' is printed. Style it first with [style_nodes()], [style_edges()],
#' [style_labels()], [label_nodes()] and [style_title()]. The
#' [plotting article](https://bjarkehautop.github.io/CausalStructures/vignettes/articles/plot.html)
#' explains the layouts and every style field, with examples.
#'
#' Unstyled nodes, edges, labels and titles use the defaults set with
#' [plot_options()]. `plot(x, ...)` is a shortcut for
#' `print(cgraph_plot(x, ...))`.
#'
#' @param x A graph created with [cgraph()], of any class.
#' @param layout Where to place the nodes:
#'   * `NULL` (default): `"sugiyama"` for a `DAG`, `"stress"` otherwise.
#'   * A method name for [cgraph_layout()]. With `"sugiyama"`, edges also follow
#'     the routes it computes; to use only its positions, pass
#'     `cgraph_layout(x, "sugiyama")` instead.
#'   * A function, called with `x` and `...`, that returns a layout.
#'   * A `data.frame` with columns `name`, `x`, and `y`.
#'   * A named list of `c(x, y)` positions, e.g.
#'     `list(A = c(0, 0), X = c(1, 0))`.
#' @param main Optional plot title, styled with [style_title()].
#' @param asp Optional y/x aspect ratio. `NA` (default) fills the available
#'   space; `asp = 1` makes one x-unit equal one y-unit.
#' @param outer_margin Grid unit for the outer margin. Default
#'   `grid::unit(2, "mm")`.
#' @param title_gap Grid unit for the gap between title and graph. Default
#'   `grid::unit(1, "lines")`.
#' @param ... Passed to `layout` when it is a method name (e.g. `direction` or
#'   `seed`; see [cgraph_layout()]) or a function. For `plot()`, the arguments
#'   of `cgraph_plot()`.
#'
#' @returns A `cgraph_plot` object, drawn when printed (`plot()` draws it and
#'   returns it invisibly). Printing it with `newpage = FALSE` draws it into
#'   the current grid viewport instead of a new page; [cgraph_grob()] gives its
#'   grid grob.
#'
#' @examples
#' if (julia_ready()) {
#'   dag <- cgraph("A --> X + Y, X --> M --> Y")
#'   cgraph_plot(dag, main = "A DAG")
#'   cgraph_plot(dag, layout = "sugiyama", direction = "down")
#'
#'   # Style it step by step; it is drawn when printed
#'   cgraph_plot(dag, main = "Styled DAG") |>
#'     style_nodes(fill = "lightblue", col = "navy") |>
#'     style_nodes(fill = "gold", nodes = "Y") |>
#'     style_edges(col = "gray40", lwd = 2) |>
#'     style_edges(col = "red", lwd = 3, from = "X", to = "M")
#' }
#' @seealso [plot-styling] for the style verbs, [plot_options()] to change the
#'   style defaults for every plot.
#' @family plotting
#' @export
cgraph_plot <- function(
  x,
  layout = NULL,
  main = NULL,
  asp = NA,
  outer_margin = grid::unit(2, "mm"),
  title_gap = grid::unit(1, "lines"),
  ...
) {
  if (!inherits(x, "cgraph")) {
    stop("`x` must be a graph created with cgraph().", call. = FALSE)
  }
  stopifnot(
    is.null(asp) ||
      is.na(asp) ||
      isTRUE(is.numeric(asp) && length(asp) == 1 && asp > 0)
  )
  placed <- .plot_place_nodes(x, layout, ...)
  edges <- .plot_edges(x)
  structure(
    list(
      graph = x,
      coords = placed$coords,
      auto_paths = placed$auto_paths,
      edges = edges,
      main = main,
      asp = asp,
      outer_margin = outer_margin,
      title_gap = title_gap,
      # Set by the style verbs (plot-compose.R): style overrides per node, per
      # node label and per row of `edges`, the label text, and the title style.
      node_by = list(),
      label_by = list(),
      edge_overrides = vector("list", nrow(edges)),
      labels = list(),
      title_style = list()
    ),
    class = "cgraph_plot"
  )
}

#' @rdname cgraph_plot
#' @export
plot.cgraph <- function(x, ...) {
  print(cgraph_plot(x, ...))
}

# Node positions (and, for "sugiyama", edge routes) from cgraph_plot()'s
# `layout` argument.
.plot_place_nodes <- function(x, layout, ...) {
  dots <- list(...)
  auto_paths <- NULL

  if (is.null(layout) || is.character(layout)) {
    method <- layout %||%
      if (jl_is_dag_type(x)) "sugiyama" else "stress"
    method <- match.arg(method, .layout_methods)
    if (method == "sugiyama") {
      # Unlike cgraph_layout(), which only returns positions, this also routes
      # each edge through Sugiyama's own bend points.
      direction <- match.arg(
        dots$direction %||% "right",
        c("right", "down", "up", "left")
      )
      sugiyama <- .plot_sugiyama(x, direction)
      coords <- sugiyama$coords
      auto_paths <- sugiyama$paths
    } else {
      coords <- cgraph_layout(x, method = method, ...)
    }
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
  } else if (is.list(layout)) {
    graph_nodes <- nodes(x)
    missing_nodes <- setdiff(graph_nodes, names(layout))
    if (length(missing_nodes) > 0) {
      stop(
        "layout is missing a position for node(s): ",
        paste(missing_nodes, collapse = ", "),
        call. = FALSE
      )
    }
    coords <- data.frame(
      name = graph_nodes,
      x = vapply(graph_nodes, function(nm) layout[[nm]][1], numeric(1)),
      y = vapply(graph_nodes, function(nm) layout[[nm]][2], numeric(1)),
      stringsAsFactors = FALSE
    )
  } else {
    stop(
      "layout must be a character string, function, data.frame, or named ",
      "list of node positions",
      call. = FALSE
    )
  }

  if (nrow(coords) == 0) {
    stop("Cannot plot an empty graph (0 nodes).", call. = FALSE)
  }
  list(coords = coords, auto_paths = auto_paths)
}

#' Grid grob of a causal graph plot
#'
#' The grid grob that draws a plot built with [cgraph_plot()] or [plot()], or
#' an arrangement of plots from [cgraph_plot_grid()], e.g. to embed it in
#' another grid-based figure. [grid::grid.draw()] also draws a `cgraph_plot`
#' directly.
#'
#' @param x A `cgraph_plot` or `cgraph_plots` object, or a graph created with
#'   [cgraph()] (plotted with the defaults).
#' @returns A grid grob (a `gTree`).
#' @examples
#' if (julia_ready()) {
#'   p <- cgraph_plot(cgraph("A --> X + Y, X --> Y"))
#'   g <- cgraph_grob(p)
#'   grid::grid.newpage()
#'   grid::grid.draw(g)
#' }
#' @family plotting
#' @export
cgraph_grob <- function(x) {
  if (inherits(x, "cgraph_plots")) {
    return(.plot_arrange_grob(x))
  }
  p <- .as_cgraph_plot(x)
  coords <- p$coords
  edges <- p$edges
  auto_paths <- p$auto_paths
  outer_margin <- p$outer_margin
  title_gap <- p$title_gap
  asp <- p$asp
  main <- p$main

  styles <- .plot_make_styles(
    p$node_by,
    p$label_by,
    p$edge_overrides,
    p$title_style
  )

  labels <- p$labels
  node_labels <- vapply(
    coords$name,
    function(nm) labels[[nm]] %||% nm,
    character(1),
    USE.NAMES = FALSE
  )

  # Explicit and Sugiyama-routed edge paths can leave the nodes' bounding box,
  # so their waypoints count towards the plotted range too.
  path_x <- coords$x
  path_y <- coords$y
  for (i in seq_len(nrow(edges))) {
    path <- .plot_waypoints(
      .plot_edge_style(edges, i, styles$edge_style)$path
    ) %||%
      auto_paths[[i]]
    path_x <- c(path_x, path[, 1])
    path_y <- c(path_y, path[, 2])
  }
  x_range <- range(path_x)
  y_range <- range(path_y)
  if (x_range[1] == x_range[2]) {
    x_range <- x_range + c(-1, 1)
  }
  if (y_range[1] == y_range[2]) {
    y_range <- y_range + c(-1, 1)
  }

  nodes_res <- .plot_make_nodes(
    coords,
    node_labels,
    styles$node_style,
    styles$label_style
  )
  edge_grobs <- .plot_make_edges(
    edges,
    coords,
    nodes_res$node_geom,
    styles$edge_style,
    auto_paths
  )

  # Shrink from [0, 1] x [0, 1] npc by the largest node's half-extent on each
  # side so no node gets clipped at the plot edge. The node geometry's hw/hh
  # reach the outer edge of its border, which the drawn shape's own
  # grobWidth()/grobHeight() leave out.
  vp_x <- grid::unit(0.5, "npc")
  vp_y <- grid::unit(0.5, "npc")
  vp_width <- grid::unit(1, "npc") -
    grid::unit(
      2 * max(vapply(nodes_res$node_geom, `[[`, numeric(1), "hw")),
      "mm"
    )
  vp_height <- grid::unit(1, "npc") -
    grid::unit(
      2 * max(vapply(nodes_res$node_geom, `[[`, numeric(1), "hh")),
      "mm"
    )

  # A fixed aspect ratio: a one-cell layout whose "null" width and height
  # are respected, so grid gives the cell the largest size with exactly that
  # physical ratio that fits the available space, whatever its shape.
  fixed_asp <- !is.null(asp) && !is.na(asp) && is.numeric(asp) && asp > 0
  asp_vp <- if (fixed_asp) {
    grid::viewport(
      x = vp_x,
      y = vp_y,
      width = vp_width,
      height = vp_height,
      layout = grid::grid.layout(
        1,
        1,
        widths = grid::unit(diff(x_range), "null"),
        heights = grid::unit(diff(y_range) * asp, "null"),
        respect = TRUE
      ),
      name = "cs.asp"
    )
  }

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

  # xscale/yscale here are an inert fallback; makeContent.cs_graph_grob()
  # computes the real, curvature-padded scale and applies it via a nested
  # viewport once this one is actually active on the device (needed for its
  # width/height to resolve to real mm).
  graph_vp <- if (fixed_asp) {
    grid::viewport(
      layout.pos.row = 1,
      layout.pos.col = 1,
      xscale = x_range,
      yscale = y_range,
      name = "cs.vp"
    )
  } else {
    grid::viewport(
      x = vp_x,
      y = vp_y,
      xscale = x_range,
      yscale = y_range,
      width = vp_width,
      height = vp_height,
      name = "cs.vp"
    )
  }

  node_gtree <- grid::grobTree(
    nodes_res$circle_grobs,
    nodes_res$label_grobs,
    name = "node_gtree"
  )

  graph_grob <- grid::gTree(
    children = grid::gList(edge_grobs, node_gtree),
    cs_edges = edges,
    cs_coords = coords,
    cs_edge_style = styles$edge_style,
    cs_node_geom = nodes_res$node_geom,
    cs_x_range = x_range,
    cs_y_range = y_range,
    vp = graph_vp,
    name = "cs.graph",
    cl = "cs_graph_grob"
  )

  title_grob$vp <- grid::vpStack(
    layout_vp,
    grid::viewport(layout.pos.row = 2, layout.pos.col = 2)
  )
  graph_grob$vp <- do.call(
    grid::vpStack,
    c(
      list(layout_vp, grid::viewport(layout.pos.row = 4, layout.pos.col = 2)),
      if (fixed_asp) list(asp_vp),
      list(graph_vp)
    )
  )

  grid::gTree(
    children = grid::gList(title_grob, graph_grob),
    name = "cs.titled"
  )
}

.as_cgraph_plot <- function(x) {
  if (inherits(x, "cgraph_plot")) {
    x
  } else if (inherits(x, "cgraph")) {
    cgraph_plot(x)
  } else if (inherits(x, "cgraph_plots")) {
    stop(
      "Style each plot before arranging it: this is an arrangement of ",
      "plots, not a single plot.",
      call. = FALSE
    )
  } else {
    stop(
      "Expected a plot from cgraph_plot() or a graph from cgraph().",
      call. = FALSE
    )
  }
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
  grid::grid.draw(cgraph_grob(x))
  invisible(x)
}

#' @exportS3Method grid::grid.draw
grid.draw.cgraph_plot <- function(x, recording = TRUE) {
  grid::grid.draw(cgraph_grob(x), recording = recording)
}
