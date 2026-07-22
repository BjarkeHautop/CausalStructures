# --- Plot layouts -------------------------------------------------------
#
# `cs_layout()` delegates to CausalStructures.jl's own `layout()` (Julia
# side: src/io/layout.jl + ext/NetworkLayoutExt.jl), which wraps
# NetworkLayout.jl's algorithms.
#
# The grid-graphics rendering in this file's companion
# (causal-structures-plot.R) is adapted from caugi's plotting code
# (R/plot-core.R, R/plot-grobs.R).

`%||%` <- function(x, y) if (is.null(x)) y else x

#' Compute a graph layout for plotting
#'
#' Computes node coordinates for [cs_plot()]. If the graph has not been built
#' yet, it will be built automatically before computing the layout.
#'
#' @param cg A graph created with [cs_cgraph()], of any class.
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
#'
#' @returns A `data.frame` with columns `name`, `x`, and `y`.
#'
#' @family plotting
#' @export
#' @examples
#' if (cs_julia_available()) {
#'   dag <- cs_cgraph(A %-->% B, B %-->% C)
#'   cs_layout(dag)
#'   cs_layout(dag, method = "circle")
#' }
cs_layout <- function(
  cg,
  method = c(
    "stress",
    "spring",
    "sfdp",
    "spectral",
    "shell",
    "squaregrid",
    "circle"
  )
) {
  method <- match.arg(method)

  nm <- cs_nodes(cg)
  n <- length(nm)
  if (n == 0) {
    return(data.frame(name = character(), x = numeric(), y = numeric()))
  }

  coords <- cs_fn("layout")(cg, method)

  data.frame(
    name = nm,
    x = coords[, 1],
    y = coords[, 2],
    stringsAsFactors = FALSE
  )
}
