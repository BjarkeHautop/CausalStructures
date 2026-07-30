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
# Style defaults (node/edge/label/title/tier) are read from plot_options()
# (plot-options.R) in .plot_make_styles() below, so they can be overridden
# globally as well as per-call.

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

# Classifies an edge's style group from its endpoint marks: any "Circle" end
# makes it PAG-style "partial" (covers o->, o-o, --o) regardless of the other
# mark; otherwise two "Arrow" ends is "bidirected", one is "directed", and
# none is "undirected".
.plot_edge_type <- function(src_mark, dst_mark) {
  if (src_mark == "Circle" || dst_mark == "Circle") {
    "partial"
  } else if (src_mark == "Arrow" && dst_mark == "Arrow") {
    "bidirected"
  } else if (src_mark == "Arrow" || dst_mark == "Arrow") {
    "directed"
  } else {
    "undirected"
  }
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
  title_style,
  tier_style
) {
  # Global defaults come from plot_options() (plot-options.R), so
  # plot_options(node_style = list(fill = "lightblue")) et al. apply to every
  # subsequent plot() call without repeating style lists at each call site;
  # arguments passed directly here still take precedence, applied via
  # modifyList() below.
  opts <- plot_options()
  node_defaults <- opts$node_style
  edge_defaults <- opts$edge_style
  label_defaults <- opts$label_style
  title_defaults <- opts$title_style
  tier_defaults <- opts$tier_style

  by_node <- node_style$by_node %||% list()
  node_style$by_node <- NULL

  # Per-type overrides (edge_style$directed / $undirected / $bidirected /
  # $partial) layer on top of the global edge options; by_edge overrides are
  # applied later, per edge, in .plot_make_edges().
  edge_type_names <- c("directed", "undirected", "bidirected", "partial")
  by_edge <- edge_style$by_edge %||% list()
  global_edge_opts <- edge_style[
    setdiff(names(edge_style), c(edge_type_names, "by_edge"))
  ]
  edge_types <- list()
  for (type in edge_type_names) {
    edge_types[[type]] <- utils::modifyList(
      utils::modifyList(edge_defaults, global_edge_opts),
      edge_style[[type]] %||% list()
    )
  }

  by_tier <- tier_style$by_tier %||% list()
  tier_style$by_tier <- NULL

  list(
    node_style = list(
      global = utils::modifyList(node_defaults, node_style),
      by_node = by_node
    ),
    edge_style = list(
      types = edge_types,
      by_edge = by_edge
    ),
    label_style = utils::modifyList(label_defaults, label_style),
    title_style = utils::modifyList(title_defaults, title_style),
    tier_style = list(
      global = utils::modifyList(tier_defaults, tier_style),
      by_tier = by_tier
    )
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

    edge_type <- .plot_edge_type(edges$src_mark[i], edges$dst_mark[i])
    style <- edge_style$types[[edge_type]]

    # Precedence (highest to lowest): specific from->to/to->from override >
    # node-wide "to" override > node-wide "from" override > edge-type style >
    # global style.
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

# Resolves a `tiers` argument to a 1-indexed tier number per node (NA for
# nodes `tiers` doesn't mention) plus tier names, if the input format
# supplies them. Accepts:
#   * A named list of node-name vectors, e.g. list(exposures = c("A", "B"),
#     outcome = "Y") - tier order is list order, names become tier_names.
#   * A named numeric vector, e.g. c(A = 1, B = 1, Y = 2) - tiers are ordered
#     by ascending value, re-indexed to consecutive integers; no tier names.
#   * A data.frame with `name` and `tier` columns.
.plot_tier_index <- function(tiers, node_names) {
  assignments <- rep(NA_integer_, length(node_names))
  names(assignments) <- node_names
  tier_names <- NULL

  if (is.data.frame(tiers)) {
    matched <- as.character(tiers$name) %in% node_names
    assignments[as.character(tiers$name[matched])] <- as.integer(tiers$tier[
      matched
    ])
  } else if (is.list(tiers)) {
    for (i in seq_along(tiers)) {
      tier_nodes <- intersect(as.character(tiers[[i]]), node_names)
      assignments[tier_nodes] <- i
    }
    if (!is.null(names(tiers)) && any(names(tiers) != "")) {
      tier_names <- names(tiers)
    }
  } else if (is.numeric(tiers) && !is.null(names(tiers))) {
    matched <- intersect(names(tiers), node_names)
    assignments[matched] <- as.integer(tiers[matched])
  } else {
    stop(
      "`tiers` must be a named list of node vectors, a named numeric ",
      "vector, or a data.frame with `name`/`tier` columns",
      call. = FALSE
    )
  }

  tier_values <- sort(unique(assignments[!is.na(assignments)]))
  tier_index <- match(assignments, tier_values)
  names(tier_index) <- node_names

  list(index = tier_index, n_tiers = length(tier_values), names = tier_names)
}

# Arranges nodes into left-to-right columns by tier (tier 1 leftmost),
# spread evenly top-to-bottom within a column, so tier boxes actually
# enclose a coherent group instead of a decorative outline drawn over
# wherever an edge-based layout happened to scatter them. Nodes `tiers`
# doesn't mention are collected into one trailing column of their own so
# every node still gets a position.
.plot_tiered_layout <- function(node_names, tier_info) {
  tier_index <- tier_info$index
  n_tiers <- tier_info$n_tiers

  unassigned <- is.na(tier_index)
  if (any(unassigned)) {
    tier_index[unassigned] <- n_tiers + 1L
    n_tiers <- n_tiers + 1L
  }

  x <- numeric(length(node_names))
  y <- numeric(length(node_names))
  for (i in seq_len(n_tiers)) {
    idx <- which(tier_index == i)
    n_in_tier <- length(idx)
    x[idx] <- i
    y[idx] <- rev(seq_len(n_in_tier)) - (n_in_tier + 1) / 2
  }

  data.frame(name = node_names, x = x, y = y, stringsAsFactors = FALSE)
}

# Tier box/label geometry (x_min/x_max/y_min/y_max below) is built from
# grid::grobX/grobY on each tier's circle grobs, which stay lazy/symbolic
# until actually drawn - by then these grobs are children of graph_grob
# (vp = graph_vp), so "native" resolves against its xscale/yscale correctly.
# Don't reuse this pattern to size graph_vp itself (see the vp-sizing calc in
# plot.cgraph): that would need grobX/Y resolved *before* graph_vp's own
# native scale exists to define it, which resolves against whatever
# viewport happens to be active instead and produces garbage offsets.
.plot_make_tiers <- function(
  circle_grobs,
  tier_info,
  tier_style,
  default_label_style
) {
  tier_index <- tier_info$index
  n_tiers <- tier_info$n_tiers
  tier_names <- tier_info$names

  if (n_tiers == 0) {
    return(list(box_grobs = NULL, label_grobs = NULL))
  }

  global <- tier_style$global
  by_tier <- tier_style$by_tier
  do_boxes <- isTRUE(global$boxes)
  do_labels <- global$labels

  tier_labels <- NULL
  if (isTRUE(do_labels)) {
    if (!is.null(tier_names) && length(tier_names) >= n_tiers) {
      tier_labels <- tier_names[seq_len(n_tiers)]
    }
  } else if (is.character(do_labels)) {
    tier_labels <- rep_len(do_labels, n_tiers)
  }

  box_grobs <- grid::gList()
  label_grobs <- grid::gList()
  has_box <- FALSE
  has_label <- FALSE
  label_gap <- grid::unit(3, "mm")

  for (i in seq_len(n_tiers)) {
    ind <- which(tier_index == i)
    if (length(ind) == 0) {
      next
    }
    circle_grobs_i <- circle_grobs[ind]

    style <- global
    tier_name_i <- if (!is.null(tier_names) && i <= length(tier_names)) {
      tier_names[i]
    } else {
      NULL
    }
    override <- by_tier[[as.character(i)]]
    if (!is.null(tier_name_i) && !is.null(by_tier[[tier_name_i]])) {
      override <- utils::modifyList(
        override %||% list(),
        by_tier[[tier_name_i]]
      )
    }
    if (!is.null(override)) {
      style <- utils::modifyList(style, override)
    }

    padding <- grid::unit(style$padding %||% 4, "mm")
    x_min <- min(grid::grobX(circle_grobs_i, "west")) - padding
    x_max <- max(grid::grobX(circle_grobs_i, "east")) + padding
    y_min <- min(grid::grobY(circle_grobs_i, "south")) - padding
    y_max <- max(grid::grobY(circle_grobs_i, "north")) + padding
    y_mid <- (y_min + y_max) / 2
    w <- x_max - x_min
    h <- y_max - y_min

    if (do_boxes) {
      has_box <- TRUE
      box_grobs[[length(box_grobs) + 1]] <- grid::rectGrob(
        x = x_min,
        y = y_mid,
        width = w,
        height = h,
        just = c("left", "center"),
        gp = do.call(grid::gpar, .plot_gpar_params(style)),
        name = paste0("tier_box_", i)
      )
    }

    if (
      !is.null(tier_labels) &&
        i <= length(tier_labels) &&
        !is.na(tier_labels[i]) &&
        tier_labels[i] != ""
    ) {
      label_style <- utils::modifyList(
        default_label_style,
        style$label_style %||% list()
      )
      label_gpar <- do.call(grid::gpar, .plot_gpar_params(label_style))

      # Wide boxes read as horizontal bands (label above); tall boxes read
      # as vertical bands (label to the right) - inferred from the box's own
      # shape rather than a separate orientation argument.
      wide <- grid::convertWidth(w, "mm", valueOnly = TRUE) >=
        grid::convertHeight(h, "mm", valueOnly = TRUE)
      if (wide) {
        label_x <- (x_min + x_max) / 2
        label_y <- y_max + label_gap
        label_just <- c("center", "bottom")
      } else {
        label_x <- x_max + label_gap
        label_y <- y_mid
        label_just <- c("left", "center")
      }

      has_label <- TRUE
      label_grobs[[length(label_grobs) + 1]] <- grid::textGrob(
        label = tier_labels[i],
        x = label_x,
        y = label_y,
        just = label_just,
        gp = label_gpar,
        name = paste0("tier_label_", i)
      )
    }
  }

  list(
    box_grobs = if (has_box) box_grobs else NULL,
    label_grobs = if (has_label) label_grobs else NULL
  )
}

#' Plot a causal graph
#'
#' Plot method for `cgraph`. `node_style`, `edge_style`, `label_style`,
#' `title_style`, and `tier_style` each default to the corresponding entry
#' from [plot_options()] (which itself defaults to
#' [plot_default_options()]) - set those globally with `plot_options()` to
#' avoid repeating the same style lists at every call site; arguments passed
#' here still take precedence.
#'
#' @param x A graph created with [cgraph()], of any class.
#' @param layout Specifies the layout. Can be:
#'   * A character string passed to [cgraph_layout()] as `method`
#'     (`"circle"`, `"spring"`, `"stress"`, `"sfdp"`, `"spectral"`,
#'     `"shell"`, `"squaregrid"`).
#'   * A layout function, called with `x` and any `...`.
#'   * A pre-computed layout `data.frame` with columns `name`, `x`, `y`.
#' @param node_style List of node styling parameters: `fill`, `col`, `lwd`,
#'   `padding` (mm, default 2), `size` (multiplier, default 1), and `by_node`
#'   (named list of per-node overrides).
#' @param edge_style List of edge styling parameters. Can specify global
#'   options or per-type options via `directed`, `undirected`, `bidirected`,
#'   `partial` (the last covers `o->`/`o-o`/`--o`, i.e. any edge with a
#'   `Circle` endpoint mark). Fields: `col`, `lwd`, `fill` (arrowhead fill
#'   color; defaults to `col` so arrowheads render solid and match the edge -
#'   pass `fill = NA` for a hollow/outline arrowhead), `arrow_size` (mm,
#'   default 3), `circle_size` (mm, default 1.5, for `o->`/`o--`/`o-o`
#'   endpoints), `route` (logical, default `TRUE`; when `TRUE`, an edge that
#'   would otherwise cross a non-incident node bends around it as a Bezier
#'   curve), and `by_edge` (named list of per-edge or per-node overrides,
#'   keyed by node name(s)). Style precedence (highest to lowest): specific
#'   edge settings in `by_edge` > node-wide settings in `by_edge` > edge-type
#'   settings > global settings.
#' @param label_style List of label styling parameters: `col`, `fontsize`,
#'   `fontface`, `fontfamily`, `cex`.
#' @param tier_style List of tier box styling parameters, used only when
#'   `...` includes `tiers` (see below). Fields: `boxes` (logical, default
#'   `TRUE`; draw a box behind each tier's nodes), `labels` (logical or
#'   character vector; `TRUE` uses the names from a named-list `tiers`,
#'   a character vector supplies custom labels one per tier, `FALSE`/default
#'   shows no labels), `fill`, `col` (box border), `lwd`, `padding` (mm,
#'   default 4), `label_style` (list with `col`, `fontsize`, `fontface`, ...,
#'   applied to tier labels), and `by_tier` (named list keyed by tier name or
#'   1-based index, e.g. `by_tier = list(exposures = list(fill =
#'   "lightblue"))` or `by_tier = list("1" = list(fill = "lightblue"))`).
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
#'   Also where tier boxes are triggered from: pass `tiers` as a named list
#'   of node-name vectors (list order is tier order, names become tier
#'   labels), a named numeric vector (one tier number per node), or a
#'   data.frame with `name`/`tier` columns. Nodes `tiers` doesn't mention get
#'   no box. Passing `tiers` also arranges the nodes into tiers - left to
#'   right, in tier order - overriding `layout` when it's a string or
#'   function (an explicit pre-computed `layout` data.frame is left as-is).
#'   Box/label display itself still requires `tier_style$boxes` or
#'   `tier_style$labels` to be truthy (default: `boxes` on, `labels` off).
#'
#' @returns A `cgraph_plot` object, invisibly. Drawn immediately as a side
#'   effect; re-drawn if printed or passed to `plot()` again.
#'
#' @examples
#' if (julia_ready()) {
#'   dag <- cgraph("A --> X + Y, X --> M --> Y")
#'   plot(dag, main = "A DAG")
#' }
#' # Style nodes and edges globally, plus per-node/per-edge overrides.
#' if (julia_ready()) {
#'   dag <- cgraph("A --> X + Y, X --> M --> Y")
#'   plot(
#'     dag,
#'     node_style = list(
#'       fill = "lightblue",
#'       col = "navy",
#'       by_node = list(Y = list(fill = "gold"))
#'     ),
#'     edge_style = list(
#'       col = "gray40",
#'       lwd = 2,
#'       by_edge = list(X = list(M = list(col = "red", lwd = 3)))
#'     ),
#'     main = "Styled DAG"
#'   )
#' }
#' @seealso [plot_options()] to change the style defaults used above,
#'   globally, for every plot.
#' @rdname plot
#' @family plotting
#' @export
plot.cgraph <- function(
  x,
  layout = "stress",
  node_style = list(),
  edge_style = list(),
  label_style = list(),
  tier_style = list(),
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

  dots <- list(...)

  if (!is.null(dots$tiers) && (is.character(layout) || is.function(layout))) {
    # tiers implies a tiered arrangement - overrides the layout method
    # (string or function), but not an explicit pre-computed data.frame of
    # coordinates, which is left alone below.
    graph_node_names <- nodes(x)
    coords <- .plot_tiered_layout(
      graph_node_names,
      .plot_tier_index(dots$tiers, graph_node_names)
    )
  } else if (is.character(layout)) {
    coords <- cgraph_layout(x, method = layout, ...)
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

  styles <- .plot_make_styles(
    node_style,
    edge_style,
    label_style,
    title_style,
    tier_style
  )

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

  tier_box_grobs <- NULL
  tier_label_grobs <- NULL
  tier_global <- styles$tier_style$global
  if (
    !is.null(dots$tiers) &&
      (isTRUE(tier_global$boxes) ||
        isTRUE(tier_global$labels) ||
        is.character(tier_global$labels))
  ) {
    tier_info <- .plot_tier_index(dots$tiers, coords$name)
    tiers_res <- .plot_make_tiers(
      nodes_res$circle_grobs,
      tier_info,
      styles$tier_style,
      styles$label_style
    )
    tier_box_grobs <- tiers_res$box_grobs
    tier_label_grobs <- tiers_res$label_grobs
  }

  # Viewport sizing: shrink from [0, 1] x [0, 1] npc by the largest node
  # circle's radius so no node gets clipped at the plot edge. This only
  # works because grobWidth()/grobHeight() measure a grob's own size, not
  # its position - unlike grobX()/grobY(), they don't need to resolve the
  # "native" coordinates the graph_vp being sized here is what defines in
  # the first place, so there's no circularity. Tier boxes/labels extend
  # past the circles by their own padding/size, so their contribution is
  # added the same size-only way rather than via grobX()/grobY() bounds
  # (which would need graph_vp's own native scale to resolve, before it
  # exists).
  margin_x <- grid::unit(0, "mm")
  margin_y <- grid::unit(0, "mm")
  if (!is.null(tier_box_grobs) || !is.null(tier_label_grobs)) {
    tier_padding <- grid::unit(2 * (tier_global$padding %||% 4), "mm")
    margin_x <- tier_padding
    margin_y <- tier_padding
    if (!is.null(tier_label_grobs)) {
      margin_x <- margin_x + max(grid::grobWidth(tier_label_grobs))
      margin_y <- margin_y + max(grid::grobHeight(tier_label_grobs))
    }
  }

  vp_x <- grid::unit(0.5, "npc")
  vp_y <- grid::unit(0.5, "npc")
  vp_width <- grid::unit(1, "npc") -
    max(grid::grobWidth(nodes_res$circle_grobs)) -
    margin_x
  vp_height <- grid::unit(1, "npc") -
    max(grid::grobHeight(nodes_res$circle_grobs)) -
    margin_y

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

  graph_children <- grid::gList()
  if (!is.null(tier_box_grobs)) {
    graph_children <- grid::gList(graph_children, tier_box_grobs)
  }
  if (!is.null(tier_label_grobs)) {
    graph_children <- grid::gList(graph_children, tier_label_grobs)
  }
  graph_children <- grid::gList(graph_children, edge_grobs, node_gtree)

  graph_grob <- grid::gTree(
    children = graph_children,
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
