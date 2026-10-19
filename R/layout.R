# --- Plot layouts -------------------------------------------------------
#
# Every method is computed by the compiled library: `"sugiyama"` by
# Sugiyama.jl, the others by NetworkLayout.jl.
# The grid-graphics rendering in this file's companion
# (causal-structures-plot.R) is adapted from caugi's plotting code
# (R/plot-core.R, R/plot-grobs.R).

`%||%` <- function(x, y) if (is.null(x)) y else x

.layout_methods <- c(
  "sugiyama",
  "stress",
  "spring",
  "sfdp",
  "spectral",
  "shell",
  "squaregrid"
)

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
#'   * `"stress"`: stress majorization (Gansner, Koren and North, 2005).
#'     A good general-purpose choice.
#'   * `"spring"`: Fruchterman-Reingold force-directed layout.
#'   * `"sfdp"`: scalable force-directed placement (Hu, 2005).
#'   * `"spectral"`: spectral layout, from eigenvectors of the graph
#'     Laplacian.
#'   * `"shell"`: nodes evenly spaced on a circle, in [nodes()] order.
#'   * `"squaregrid"`: nodes on a square grid, row by row in [nodes()] order.
#'
#'   Every method except `"sugiyama"` is from
#'   [NetworkLayout.jl](https://github.com/JuliaGraphs/NetworkLayout.jl) and
#'   ignores edge direction.
#'
#'   Defaults (`NULL`) to `"sugiyama"` when `x` was constructed (or
#'   [reclass()]ed) as a `DAG`, `"stress"` otherwise. This checks `x`'s
#'   actual class, not its edge structure (see [predicates]) - a `PDAG`
#'   with only directed, acyclic edges still defaults to `"stress"`.
#' @param direction For `"sugiyama"`, which way the layers flow: `"right"`
#'   (the default, as in CausalStructures.jl), `"down"`, `"up"` or `"left"`.
#' @param seed For `"stress"`, `"spring"` and `"sfdp"`, the seed of the random
#'   initial positions. The layout is the same for the same seed.
#' @param ... Ignored, so that [plot.cgraph()] can pass its `...` through.
#' @return A `data.frame` with columns `name`, `x`, and `y`.
#'
#' @family plotting
#' @export
#' @examples
#' if (julia_ready()) {
#'   dag <- cgraph(A %-->% B, B %-->% C)
#'   cgraph_layout(dag)
#'   cgraph_layout(dag, method = "stress")
#' }
cgraph_layout <- function(
  x,
  method = NULL,
  direction = c("right", "down", "up", "left"),
  seed = 1L,
  ...
) {
  if (!inherits(x, "cgraph")) {
    stop("`x` must be a causal graph created with cgraph()", call. = FALSE)
  }
  method <- method %||%
    if (.Call(C_jl_is_dag_type, x)) "sugiyama" else "stress"
  method <- match.arg(method, .layout_methods)

  nm <- nodes(x)
  n <- length(nm)
  if (n == 0) {
    return(data.frame(name = character(), x = numeric(), y = numeric()))
  }

  coords <- if (method == "sugiyama") {
    .Call(C_jl_sugiyama_layout, x, match.arg(direction))
  } else {
    .Call(C_jl_network_layout, x, method, as.integer(seed))
  }

  data.frame(
    name = nm,
    x = coords[, 1],
    y = coords[, 2],
    stringsAsFactors = FALSE
  )
}
