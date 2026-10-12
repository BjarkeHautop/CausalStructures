# --- Plot layouts -------------------------------------------------------
#
# `cgraph_layout()` delegates to CausalStructures.jl's own `layout()` (Julia
# side: src/io/layout.jl + ext/NetworkLayoutExt.jl), which wraps
# NetworkLayout.jl's algorithms.
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
#'   * `"stress"`: stress majorization. A good general-purpose choice - well-
#'     spaced and deterministic for a given graph.
#'   * `"spring"`: Fruchterman-Reingold force-directed.
#'   * `"sfdp"`: scalable force-directed placement.
#'   * `"spectral"`: spectral layout.
#'   * `"shell"`: concentric shells.
#'   * `"squaregrid"`: square grid.
#'   * `"sugiyama"`: layered/hierarchical layout, `DAG` only. Provided by the
#'     [Sugiyama.jl](https://github.com/JuliaGraphs/Sugiyama.jl) package.
#'
#'   All other methods are provided by the
#'   [NetworkLayout.jl](https://github.com/JuliaGraphs/NetworkLayout.jl) package.
#'
#'   Defaults (`NULL`) to `"sugiyama"` when `x` was constructed (or
#'   [reclass()]ed) as a `DAG`, `"stress"` otherwise - matching
#'   CausalStructures.jl's own default. This checks `x`'s actual class, not
#'   its edge structure (see [predicates]) - a `PDAG` with only directed,
#'   acyclic edges still defaults to `"stress"`.
#' @param ... Additional arguments
#' @return A `data.frame` with columns `name`, `x`, and `y`.
#'
#' @family plotting
#' @export
#' @examples
#' if (julia_ready()) {
#'   dag <- cgraph(A %-->% B, B %-->% C)
#'   cgraph_layout(dag)
#' }
#'
#' if (julia_ready()) {
#'   dag <- cgraph(A %-->% B, B %-->% C)
#'   cgraph_layout(dag, method = "spring")
#' }
cgraph_layout <- function(x, method = NULL, ...) {
  if (!inherits(x, "cgraph")) {
    stop("`x` must be a causal graph created with cgraph()", call. = FALSE)
  }
  method <- method %||%
    if (.check(.Call(.sym$is_dag_type, x))) "sugiyama" else "stress"
  method <- match.arg(
    method,
    c("stress", "spring", "sfdp", "spectral", "shell", "squaregrid", "sugiyama")
  )

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
