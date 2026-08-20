# --- Edge routing geometry -----------------------------------------------
#
# Adapted from caugi's edge routing (R/plot-routing.R by Frederik
# Fabricius-Bjerre and Johan Larsson; see inst/COPYRIGHTS). Pure functions
# operating on plain numeric coordinates in millimeters, with no grid state,
# so `makeContent.cs_edge_grob()` (causal-structures-plot.R) can call them at
# draw time to bend an edge around any non-incident node it would otherwise
# cross.

# Distance from point (px, py) to segment (ax, ay)--(bx, by), plus the
# clamped projection parameter t in [0, 1] locating the closest point.
.point_segment_dist <- function(px, py, ax, ay, bx, by) {
  dx <- bx - ax
  dy <- by - ay
  l2 <- dx * dx + dy * dy

  if (l2 <= 0) {
    t <- 0
    cx <- ax
    cy <- ay
  } else {
    t <- ((px - ax) * dx + (py - ay) * dy) / l2
    t <- max(0, min(1, t))
    cx <- ax + t * dx
    cy <- ay + t * dy
  }

  list(dist = sqrt((px - cx)^2 + (py - cy)^2), t = t)
}

# Locate the curve parameter where a monotone fraction function f crosses 1
# (f < 1 inside the node's shape, > 1 outside - see .shape_boundary_distance()
# and .radial_fraction() below), via bisection on [0, 1]. When
# increasing = TRUE, f grows from 0 at u = 0 and the smallest u with
# f(u) >= 1 is returned; when FALSE, f grows toward u = 0 (0 at u = 1) and
# the largest such u is returned.
.bisect_u <- function(f, increasing) {
  lo <- 0
  hi <- 1
  for (k in seq_len(40)) {
    mid <- (lo + hi) / 2
    inside <- f(mid) < 1
    if (increasing) {
      if (inside) lo <- mid else hi <- mid
    } else {
      if (inside) hi <- mid else lo <- mid
    }
  }
  if (increasing) hi else lo
}

# Distance from a node's center to its own shape boundary along unit
# direction (dx, dy): an ellipse for "round" (half-axes hw, hh), or an
# axis-aligned box for "box" (half-width hw, half-height hh). A circle is
# just the round case with hw == hh.
.shape_boundary_distance <- function(shape, hw, hh, dx, dy) {
  c <- abs(dx)
  s <- abs(dy)
  if (identical(shape, "box")) {
    tx <- if (c > 1e-9) hw / c else Inf
    ty <- if (s > 1e-9) hh / s else Inf
    min(tx, ty)
  } else {
    denom <- sqrt((hh * c)^2 + (hw * s)^2)
    if (denom < 1e-9) {
      return(min(hw, hh))
    }
    hw * hh / denom
  }
}

# < 1 inside the node's shape, > 1 outside, == 1 on the boundary - the
# quantity .bisect_u() bisects to clip a curve against a node's exact
# (possibly non-circular) boundary rather than a fixed radius.
.radial_fraction <- function(px, py, cx, cy, shape, hw, hh) {
  dx <- px - cx
  dy <- py - cy
  dist <- sqrt(dx * dx + dy * dy)
  if (dist < 1e-9) {
    return(0)
  }
  dist / .shape_boundary_distance(shape, hw, hh, dx / dist, dy / dist)
}

# Shared tail end of both bow_edge_path() and route_edge_path(): given a
# cubic Bezier's four control points, clip it to each endpoint node's shape
# boundary (by bisecting .radial_fraction() to 1 - see above) and sample it
# into n points. Returns NULL if a node is large enough to swallow the whole
# curve, or if the two clip points cross.
.clip_and_sample_bezier <- function(
  p0x,
  p0y,
  p1x,
  p1y,
  p2cx,
  p2cy,
  p2x,
  p2y,
  shape_from,
  hw_from,
  hh_from,
  shape_to,
  hw_to,
  hh_to,
  n
) {
  qx <- function(u) {
    (1 - u)^3 *
      p0x +
      3 * (1 - u)^2 * u * p1x +
      3 * (1 - u) * u^2 * p2cx +
      u^3 * p2x
  }
  qy <- function(u) {
    (1 - u)^3 *
      p0y +
      3 * (1 - u)^2 * u * p1y +
      3 * (1 - u) * u^2 * p2cy +
      u^3 * p2y
  }
  frac_from <- function(u) {
    .radial_fraction(qx(u), qy(u), p0x, p0y, shape_from, hw_from, hh_from)
  }
  frac_to <- function(u) {
    .radial_fraction(qx(u), qy(u), p2x, p2y, shape_to, hw_to, hh_to)
  }

  if (frac_from(1) <= 1 || frac_to(0) <= 1) {
    return(NULL)
  }

  u_start <- .bisect_u(frac_from, increasing = TRUE)
  u_end <- .bisect_u(frac_to, increasing = FALSE)
  if (u_start >= u_end) {
    return(NULL)
  }

  u <- seq(u_start, u_end, length.out = n)
  list(x = qx(u), y = qy(u))
}

# Bows a straight center-to-center chord into a cubic Bezier by perpendicular
# offset h (positive = left of the p0->p2 direction of travel), independent
# of any obstacle - the manual/explicit-curvature counterpart to
# route_edge_path()'s automatic obstacle-avoidance bow. Uses the same
# handle_frac = 0.2 control-point placement so both read as the same family
# of curve, then clips to each node's shape boundary and samples n points.
bow_edge_path <- function(
  p0x,
  p0y,
  p2x,
  p2y,
  shape_from,
  hw_from,
  hh_from,
  shape_to,
  hw_to,
  hh_to,
  h,
  n = 40L
) {
  dx <- p2x - p0x
  dy <- p2y - p0y
  seg_len <- sqrt(dx * dx + dy * dy)
  if (seg_len <= 0) {
    return(NULL)
  }

  nperp_x <- -dy / seg_len
  nperp_y <- dx / seg_len

  handle_frac <- 0.2
  p1x <- p0x + handle_frac * dx + h * nperp_x
  p1y <- p0y + handle_frac * dy + h * nperp_y
  p2cx <- p0x + (1 - handle_frac) * dx + h * nperp_x
  p2cy <- p0y + (1 - handle_frac) * dy + h * nperp_y

  .clip_and_sample_bezier(
    p0x,
    p0y,
    p1x,
    p1y,
    p2cx,
    p2cy,
    p2x,
    p2y,
    shape_from,
    hw_from,
    hh_from,
    shape_to,
    hw_to,
    hh_to,
    n
  )
}

# Compute a routed edge path that avoids obstructing nodes, working entirely
# in millimeters. The curve is built between the two node *centers* (p0x,
# p0y) and (p2x, p2y) so that, after clipping to the node borders, it appears
# to project radially from each center. The straight center-to-center
# segment is tested against obstacle nodes (circle centers ox/oy, each
# treated as its bounding circumradius `or` for this proximity test - an
# approximation for non-circular "box" nodes, which callers must already
# have padded by half their stroke width so a thick node border is treated
# as part of its footprint). If no obstacle is closer than or + clearance,
# no routing is needed and NULL is returned. Otherwise a cubic Bezier is
# bowed perpendicular to the chord, away from the worst-violating obstacle,
# by enough to clear it, then clipped to each endpoint's exact shape
# boundary (.shape_from/.shape_to, possibly non-circular) and sampled into n
# points.
route_edge_path <- function(
  p0x,
  p0y,
  p2x,
  p2y,
  shape_from,
  hw_from,
  hh_from,
  shape_to,
  hw_to,
  hh_to,
  ox,
  oy,
  or,
  clearance,
  n = 40L
) {
  n_obs <- length(ox)
  if (n_obs == 0) {
    return(NULL)
  }

  dx <- p2x - p0x
  dy <- p2y - p0y
  seg_len <- sqrt(dx * dx + dy * dy)
  if (seg_len <= 0) {
    return(NULL)
  }

  # Worst violator: the obstacle whose required clearance is most exceeded
  # by its proximity to the center-to-center segment.
  worst_k <- 0L
  worst_violation <- 0
  worst_side <- 1
  worst_t <- 0.5

  for (i in seq_len(n_obs)) {
    ps <- .point_segment_dist(ox[i], oy[i], p0x, p0y, p2x, p2y)
    needed <- or[i] + clearance
    violation <- needed - ps$dist
    if (violation > worst_violation) {
      worst_violation <- violation
      worst_k <- i
      worst_t <- ps$t
      # Signed side of the obstacle relative to the directed chord P0->P2
      # (cross product z-component): +1 left, -1 right.
      worst_side <- sign(dx * (oy[i] - p0y) - dy * (ox[i] - p0x))
      if (worst_side == 0) {
        worst_side <- 1
      }
    }
  }

  if (worst_k == 0L) {
    return(NULL)
  }

  # Unit perpendicular to the chord, pointing away from the obstacle.
  bend <- -worst_side
  nperp_x <- bend * -dy / seg_len
  nperp_y <- bend * dx / seg_len

  # Cubic Bezier bowed away from the obstacle. Placing the control handles
  # only partway along the chord (handle_frac) makes the curve leave each
  # node at a steeper angle, so it reads as projecting from the center. h is
  # the perpendicular offset of the control points, sized so the curve
  # clears the obstacle (required displacement worst_violation) at its
  # projection worst_t, where the cubic reaches 3 * t * (1 - t) * h.
  handle_frac <- 0.2
  tt <- max(0.15, min(0.85, worst_t))
  h <- (worst_violation + 0.5) / (3 * tt * (1 - tt))
  # Bow at least a little so short, barely-grazing edges still curve
  # visibly rather than looking kinked.
  h <- max(h, 0.06 * seg_len)

  p1x <- p0x + handle_frac * dx + h * nperp_x
  p1y <- p0y + handle_frac * dy + h * nperp_y
  p2cx <- p0x + (1 - handle_frac) * dx + h * nperp_x
  p2cy <- p0y + (1 - handle_frac) * dy + h * nperp_y

  .clip_and_sample_bezier(
    p0x,
    p0y,
    p1x,
    p1y,
    p2cx,
    p2cy,
    p2x,
    p2y,
    shape_from,
    hw_from,
    hh_from,
    shape_to,
    hw_to,
    hh_to,
    n
  )
}
