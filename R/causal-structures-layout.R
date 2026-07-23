# --- Plot layouts -------------------------------------------------------
#
# `layout.cgraph()` delegates to CausalStructures.jl's own `layout()` (Julia
# side: src/io/layout.jl + ext/NetworkLayoutExt.jl), which wraps
# NetworkLayout.jl's algorithms. `layout()` itself is a generic re-declared
# here (base's `graphics::layout()` isn't one) so `layout.cgraph()` can hook
# in; `layout.default()` forwards to `graphics::layout()` so plain-matrix
# usage is unaffected by attaching this package.
#
# The grid-graphics rendering in this file's companion
# (causal-structures-plot.R) is adapted from caugi's plotting code
# (R/plot-core.R, R/plot-grobs.R).

`%||%` <- function(x, y) if (is.null(x)) y else x

#' Compute a graph layout
#'
#' A generic function. `layout.cgraph()` computes node coordinates for
#' [plot.cgraph()]. `layout.default()` forwards to [graphics::layout()], so
#' attaching this package does not change the behavior of `layout()` on
#' ordinary matrices.
#'
#' @param x For `layout.cgraph()`, a graph created with [cgraph()], of any
#'   class. For `layout.default()`, passed on to [graphics::layout()].
#' @param ... Passed on to the method.
#'
#' @return `layout.cgraph()` returns a `data.frame` with columns `name`,
#'   `x`, and `y`. `layout.default()` returns whatever
#'   [graphics::layout()] returns.
#'
#' @family plotting
#' @export
layout <- function(x, ...) {
  UseMethod("layout")
}

#' @rdname layout
#' @export
layout.default <- function(x, ...) {
  graphics::layout(x, ...)
}

#' @rdname layout
#' @param method Character string specifying the layout method:
#'   * `"stress"` (default): stress majorization. A good general-purpose
#'     choice - well-spaced and deterministic for a given graph.
#'   * `"spring"`: Fruchterman-Reingold force-directed.
#'   * `"sfdp"`: scalable force-directed placement.
#'   * `"spectral"`: spectral layout.
#'   * `"shell"`: concentric shells.
#'   * `"squaregrid"`: square grid.
#'   * `"circle"`: nodes evenly spaced on a circle, ignoring edge structure.
#'
#'   All methods are provided by the
#'   [NetworkLayout.jl](https://github.com/JuliaGraphs/NetworkLayout.jl) package.
#' @export
#' @examples
#' if (julia_available()) {
#'   dag <- cgraph(A %-->% B, B %-->% C)
#'   layout(dag)
#' }
#'
#' if (julia_available()) {
#'   dag <- cgraph(A %-->% B, B %-->% C)
#'   layout(dag, method = "circle")
#' }
layout.cgraph <- function(
  x,
  method = c(
    "stress",
    "spring",
    "sfdp",
    "spectral",
    "shell",
    "squaregrid",
    "circle"
  ),
  ...
) {
  method <- match.arg(method)

  nm <- nodes(x)
  n <- length(nm)
  if (n == 0) {
    return(data.frame(name = character(), x = numeric(), y = numeric()))
  }

  coords <- fn("layout")(x, method)

  data.frame(
    name = nm,
    x = coords[, 1],
    y = coords[, 2],
    stringsAsFactors = FALSE
  )
}
