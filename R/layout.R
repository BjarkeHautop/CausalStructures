# --- Plot layouts -------------------------------------------------------
#
# `"sugiyama"` is computed by the compiled library (Sugiyama.jl); the other
# methods are small enough to implement here in R. Causal graphs are small,
# so plain dense-matrix code is fast enough.
# The grid-graphics rendering in this file's companion
# (causal-structures-plot.R) is adapted from caugi's plotting code
# (R/plot-core.R, R/plot-grobs.R).

`%||%` <- function(x, y) if (is.null(x)) y else x

#' Compute a graph layout
#'
#' Computes node coordinates for [plot.cgraph()].
#'
#' @param x A graph created with [cgraph()], of any class.
#' @param method Character string specifying the layout method:
#'   * `"sugiyama"`: layered/hierarchical layout, from the
#'     [Sugiyama.jl](https://github.com/BjarkeHautop/Sugiyama.jl) package.
#'     Every edge is layered from its first to its second node (`A --> B`
#'     puts `A` before `B`), and any cycles are broken, so it works for every
#'     graph class.
#'   * `"stress"`: stress majorization (Gansner, Koren and North, 2005),
#'     starting from classical multidimensional scaling. A good
#'     general-purpose choice - well-spaced and deterministic for a given
#'     graph.
#'   * `"shell"`: nodes evenly spaced on a circle, in [nodes()] order.
#'   * `"squaregrid"`: nodes on a square grid, row by row in [nodes()] order.
#'
#'   Defaults (`NULL`) to `"sugiyama"` when `x` was constructed (or
#'   [reclass()]ed) as a `DAG`, `"stress"` otherwise. This checks `x`'s
#'   actual class, not its edge structure (see [predicates]) - a `PDAG`
#'   with only directed, acyclic edges still defaults to `"stress"`.
#' @param direction For `"sugiyama"`, which way the layers flow: `"right"`
#'   (the default, as in CausalStructures.jl), `"down"`, `"up"` or `"left"`.
#' @param ... Ignored, so that [plot.cgraph()] can pass its `...` through.
#' @return A `data.frame` with columns `name`, `x`, and `y`.
#'
#' @family plotting
#' @export
#' @examples
#' dag <- cgraph(A %-->% B, B %-->% C)
#' cgraph_layout(dag)
#' cgraph_layout(dag, method = "stress")
cgraph_layout <- function(
  x,
  method = NULL,
  direction = c("right", "down", "up", "left"),
  ...
) {
  if (!inherits(x, "cgraph")) {
    stop("`x` must be a causal graph created with cgraph()", call. = FALSE)
  }
  method <- method %||%
    if (.Call(C_is_dag_type, x)) "sugiyama" else "stress"
  method <- match.arg(method, c("sugiyama", "stress", "shell", "squaregrid"))

  nm <- nodes(x)
  n <- length(nm)
  if (n == 0) {
    return(data.frame(name = character(), x = numeric(), y = numeric()))
  }

  coords <- switch(
    method,
    sugiyama = .Call(C_sugiyama_layout, x, match.arg(direction)),
    stress = .layout_stress(.graph_distances(x, nm)),
    shell = .layout_shell(n),
    squaregrid = .layout_squaregrid(n)
  )

  data.frame(
    name = nm,
    x = coords[, 1],
    y = coords[, 2],
    stringsAsFactors = FALSE
  )
}

# Shortest-path distances between the nodes `nm` of `x`, ignoring edge
# direction (Floyd-Warshall). Unreachable pairs are `Inf`.
.graph_distances <- function(x, nm) {
  n <- length(nm)
  d <- matrix(Inf, n, n)
  diag(d) <- 0
  e <- edges(x)
  if (nrow(e) > 0) {
    ij <- cbind(match(e$from, nm), match(e$to, nm))
    ij <- ij[ij[, 1] != ij[, 2], , drop = FALSE]
    d[ij] <- 1
    d[ij[, 2:1, drop = FALSE]] <- 1
  }
  for (k in seq_len(n)) {
    d <- pmin(d, outer(d[, k], d[k, ], `+`))
  }
  d
}

# Stress majorization (SMACOF) of the distance matrix `d`, as in Gansner,
# Koren and North (2005, doi:10.1007/978-3-540-31843-9_25), starting from
# classical multidimensional scaling so the result is deterministic.
.layout_stress <- function(d, maxit = 500L, reltol = 1e-5) {
  n <- nrow(d)
  if (n == 1L) {
    return(matrix(0, 1L, 2L))
  }

  # Pairs in different components are placed a little further apart than the
  # largest distance within a component.
  if (any(is.infinite(d))) {
    finite <- d[is.finite(d)]
    maxd <- max(1, finite)
    ncomp <- length(unique(apply(is.finite(d), 1L, which.max)))
    d[is.infinite(d)] <- maxd * ncomp^(1 / 3)
  }

  w <- d^-2
  diag(w) <- 0
  lw <- diag(rowSums(w)) - w
  # Lw is a connected graph's Laplacian, so its pseudo-inverse is
  # (Lw + J/n)^-1 - J/n.
  j <- matrix(1 / n, n, n)
  lw_pinv <- solve(lw + j) - j

  pos <- .classical_mds(d)
  stress <- function(pos) {
    dist <- as.matrix(stats::dist(pos))
    sum(w * (dist - d)^2) / 2
  }
  old <- stress(pos)
  for (it in seq_len(maxit)) {
    dist <- as.matrix(stats::dist(pos))
    b <- ifelse(dist > 0, -w * d / dist, 0)
    diag(b) <- -rowSums(b)
    pos <- lw_pinv %*% (b %*% pos)
    new <- stress(pos)
    if (abs(old - new) < reltol * new) {
      break
    }
    old <- new
  }
  pos
}

# Classical MDS coordinates in two dimensions. A dimension MDS cannot fill
# (e.g. a path, which is collinear) gets a small deterministic offset, so
# stress majorization is not stuck in a line.
.classical_mds <- function(d) {
  n <- nrow(d)
  pos <- suppressWarnings(stats::cmdscale(d, k = min(2L, n - 1L)))
  pos <- matrix(pos, nrow = n)
  pad <- 0.01 * max(d) * sin(seq_len(n))
  while (ncol(pos) < 2L) {
    pos <- cbind(pos, pad)
  }
  unname(pos)
}

.layout_shell <- function(n) {
  if (n == 1L) {
    return(matrix(0, 1L, 2L))
  }
  # Start at the top and go clockwise.
  theta <- pi / 2 - 2 * pi * (seq_len(n) - 1) / n
  cbind(cos(theta), sin(theta))
}

.layout_squaregrid <- function(n) {
  cols <- ceiling(sqrt(n))
  i <- seq_len(n) - 1
  cbind(i %% cols, -(i %/% cols))
}
