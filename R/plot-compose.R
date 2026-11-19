# --- Composable plot styling ----------------------------------------------
#
# Verbs that add to a cgraph_plot (plot.R) and return it, so a plot can be
# built step by step with |>. Each one only records overrides - per node in
# `node_by`/`label_by`, per row of the plot's `edges` in `edge_overrides` -
# which the renderer puts on top of the plot_options() defaults. A later call
# wins over an earlier one for the fields both set.

.plot_gpar_fields <- c(
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

.plot_node_fields <- union(
  c("linestyle", "shape", "radius", "padding", "size"),
  .plot_gpar_fields
)

.plot_edge_fields <- union(
  c(
    "gap",
    "curvature",
    "path",
    "arrow_size",
    "circle_size",
    "label",
    "label_col",
    "label_fontsize",
    "label_fontface",
    "label_fontfamily",
    "label_shift",
    "label_distance",
    "label_rotation"
  ),
  .plot_gpar_fields
)

.plot_edge_notations <- c(
  "-->",
  "<--",
  "---",
  "<->",
  "o->",
  "<-o",
  "o--",
  "--o",
  "o-o"
)

# The style fields passed in a verb's `...`, checked against `fields`.
.plot_style_dots <- function(dots, fields, verb) {
  nm <- names(dots)
  if (length(dots) > 0 && (is.null(nm) || any(nm == ""))) {
    stop(
      sprintf("All style fields in %s() must be named.", verb),
      call. = FALSE
    )
  }
  unknown <- setdiff(nm, fields)
  if (length(unknown) > 0) {
    stop(
      sprintf(
        "Unknown style field(s) in %s(): %s. Available: %s.",
        verb,
        paste(unknown, collapse = ", "),
        paste(fields, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  dots
}

# `nodes`, checked against the plotted nodes; NULL selects every node.
.plot_select_nodes <- function(p, nodes, arg) {
  all_nodes <- p$coords$name
  if (is.null(nodes)) {
    return(all_nodes)
  }
  if (!is.character(nodes)) {
    stop(
      sprintf("`%s` must be a character vector of node names.", arg),
      call. = FALSE
    )
  }
  unknown <- setdiff(nodes, all_nodes)
  if (length(unknown) > 0) {
    stop(
      sprintf(
        "`%s` names node(s) not in the graph: %s.",
        arg,
        paste(unknown, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  nodes
}

# Merges `style` into the entry of each of `nodes` in the list `by`.
.plot_merge_by_node <- function(by, nodes, style) {
  for (nm in nodes) {
    by[[nm]] <- utils::modifyList(by[[nm]] %||% list(), style)
  }
  by
}

#' Style the nodes, edges and labels of a plot
#'
#' Style a plot built with [cgraph_plot()] one step at a time. Each function
#' returns the plot, so the steps chain with `|>`, and the plot is drawn when
#' it is printed. Passing a graph instead of a plot starts one with
#' [cgraph_plot()]'s defaults.
#'
#' Each call styles only the nodes or edges it selects. A later call wins over
#' an earlier one for the fields both set, and anything left unset uses the
#' defaults of [plot_options()]. The selectors take node sets, so the results
#' of query functions such as [parents()] or [adjustment_set()] can be passed
#' straight in.
#'
#' @section Node fields (`style_nodes()`):
#' * `fill`, `col`: fill and border color.
#' * `lwd`, `linestyle`: border width and line type (any `lty`).
#' * `shape`: `"circle"`, `"square"`, `"ellipse"`, or `"rect"`.
#' * `radius`: node size in mm. Unset, nodes fit their labels, with `padding`
#'   mm around the text, times `size`.
#'
#' @section Edge fields (`style_edges()`):
#' * `col`, `lwd`, `lty`: line color, width and type.
#' * `fill`: arrowhead fill, by default the edge's `col`; `NA` for hollow.
#' * `arrow_size`, `circle_size`: arrowhead length and endpoint circle radius,
#'   in mm.
#' * `gap`: space in mm between the edge ends and the nodes.
#' * `curvature`: how far the edge bows; positive to the left travelling from
#'   its first node to its second, as listed by [edges()]. `0` turns off the
#'   automatic routing around nodes in the way.
#' * `path`: waypoints the edge passes through, in layout coordinates, from
#'   the node in `from` to the node in `to`: a `c(x, y)` point, a two-column
#'   matrix, a `data.frame` with `x` and `y` columns, or a list of points.
#' * `label`: text drawn along the edge, styled with `label_col`,
#'   `label_fontsize`, `label_fontface` and `label_fontfamily`, and placed with
#'   `label_shift` (0 at the edge's first node to 1 at its second),
#'   `label_distance` (mm from the edge) and `label_rotation` (degrees; unset,
#'   it follows the edge).
#'
#' @section Text fields (`style_labels()`, `style_title()`):
#' `col`, `fontsize`, `fontface`, `fontfamily`, and `cex`.
#'
#' @param p A plot from [cgraph_plot()], or a graph created with [cgraph()].
#' @param ... Named style fields (see the sections below), or for
#'   `label_nodes()` the text to draw in each node, named by node, e.g.
#'   `X = "Exposure"`; `\n` starts a new line. Other nodes show their name.
#' @param nodes Character vector of the nodes to style. `NULL` (default) styles
#'   every node.
#' @param from,to Character vectors of nodes. An edge is styled if it joins a
#'   node in `from` to a node in `to`, in either direction unless `type` fixes
#'   it. `NULL` (default) allows any node.
#' @param type Character vector of edge notations to style, read from a node in
#'   `from` to a node in `to`: `"-->"`, `"<--"`, `"---"`, `"<->"`, `"o->"`,
#'   `"<-o"`, `"o--"`, `"--o"`, or `"o-o"`. `NULL` (default) allows every type.
#'   For example, `from = "X", type = "-->"` styles the edges out of `X`, and
#'   `type = "<->"` every bidirected edge.
#'
#' @returns The plot, a `cgraph_plot` object.
#'
#' @examplesIf julia_ready()
#' dag <- cgraph("A --> X + Y, X --> M --> Y")
#'
#' cgraph_plot(dag, main = "Mediation") |>
#'   style_nodes(fill = "lightblue", nodes = parents(dag, "Y")) |>
#'   style_nodes(shape = "square", nodes = "A") |>
#'   style_edges(col = "gray60") |>
#'   style_edges(col = "#DC143C", lwd = 2, from = "X", type = "-->") |>
#'   style_labels(fontface = "bold", nodes = c("X", "Y")) |>
#'   label_nodes(X = "Exposure", Y = "Outcome") |>
#'   style_title(col = "navy")
#'
#' # Dash every bidirected edge of an ADMG
#' admg <- cgraph("X --> Y, X <-> Y, Y <-> Z", class = "ADMG")
#' admg |> style_edges(lty = "dashed", type = "<->")
#' @seealso [cgraph_plot()] for the layout and title, [plot_options()] for the
#'   defaults.
#' @family plotting
#' @name plot-styling
NULL

#' @rdname plot-styling
#' @export
style_nodes <- function(p, ..., nodes = NULL) {
  p <- .as_cgraph_plot(p)
  style <- .plot_style_dots(list(...), .plot_node_fields, "style_nodes")
  if (!is.null(style$shape) && !isTRUE(style$shape %in% .NODE_SHAPES)) {
    stop(
      sprintf(
        "Unknown node shape %s. Available: %s.",
        dQuote(format(style$shape), q = FALSE),
        paste(dQuote(.NODE_SHAPES, q = FALSE), collapse = ", ")
      ),
      call. = FALSE
    )
  }
  nodes <- .plot_select_nodes(p, nodes, "nodes")
  p$node_by <- .plot_merge_by_node(p$node_by, nodes, style)
  p
}

.plot_text_fields <- c(
  "col",
  "fontsize",
  "fontface",
  "fontfamily",
  "cex",
  "alpha",
  "lex"
)

#' @rdname plot-styling
#' @export
style_labels <- function(p, ..., nodes = NULL) {
  p <- .as_cgraph_plot(p)
  style <- .plot_style_dots(list(...), .plot_text_fields, "style_labels")
  nodes <- .plot_select_nodes(p, nodes, "nodes")
  p$label_by <- .plot_merge_by_node(p$label_by, nodes, style)
  p
}

#' @rdname plot-styling
#' @export
style_title <- function(p, ...) {
  p <- .as_cgraph_plot(p)
  style <- .plot_style_dots(list(...), .plot_text_fields, "style_title")
  p$title_style <- utils::modifyList(p$title_style, style)
  p
}

#' @rdname plot-styling
#' @export
label_nodes <- function(p, ...) {
  p <- .as_cgraph_plot(p)
  labels <- list(...)
  nm <- names(labels)
  if (length(labels) > 0 && (is.null(nm) || any(nm == ""))) {
    stop("All labels in label_nodes() must be named by node.", call. = FALSE)
  }
  ok <- vapply(
    labels,
    function(l) is.character(l) && length(l) == 1L,
    logical(1)
  )
  if (!all(ok)) {
    stop("Each label in label_nodes() must be a single string.", call. = FALSE)
  }
  .plot_select_nodes(p, nm, "...")
  p$labels <- utils::modifyList(p$labels, labels)
  p
}

#' @rdname plot-styling
#' @export
style_edges <- function(p, ..., from = NULL, to = NULL, type = NULL) {
  p <- .as_cgraph_plot(p)
  style <- .plot_style_dots(list(...), .plot_edge_fields, "style_edges")
  if (!is.null(style$path)) {
    style$path <- .plot_waypoints(style$path)
  }
  from <- .plot_select_nodes(p, from, "from")
  to <- .plot_select_nodes(p, to, "to")
  if (!is.null(type)) {
    unknown <- setdiff(type, .plot_edge_notations)
    if (length(unknown) > 0) {
      stop(
        sprintf(
          "Unknown edge type(s) %s. Available: %s.",
          paste(dQuote(unknown, q = FALSE), collapse = ", "),
          paste(dQuote(.plot_edge_notations, q = FALSE), collapse = ", ")
        ),
        call. = FALSE
      )
    }
  }
  match <- .plot_match_edges(p$edges, from, to, type)
  for (i in which(match$forward | match$backward)) {
    edge_style <- style
    # A path runs from `from` to `to`; an edge matched only backward runs the
    # other way.
    if (!is.null(edge_style$path) && !match$forward[i]) {
      edge_style$path <- edge_style$path[
        rev(seq_len(nrow(edge_style$path))),
        ,
        drop = FALSE
      ]
    }
    p$edge_overrides[i] <- list(
      utils::modifyList(p$edge_overrides[[i]] %||% list(), edge_style)
    )
  }
  p
}

# Which edges join a node in `from` to a node in `to` with a notation in
# `type` (NULL: any), read in the edge's own direction (`forward`) and in the
# reverse one (`backward`).
.plot_match_edges <- function(edges, from, to, type) {
  left <- c(Tail = "-", Arrow = "<", Circle = "o")
  right <- c(Tail = "-", Arrow = ">", Circle = "o")
  forward <- paste0(left[edges$src_mark], "-", right[edges$dst_mark])
  backward <- paste0(left[edges$dst_mark], "-", right[edges$src_mark])
  type_ok <- function(notation) is.null(type) | notation %in% type
  list(
    forward = edges$from %in% from & edges$to %in% to & type_ok(forward),
    backward = edges$to %in% from & edges$from %in% to & type_ok(backward)
  )
}
