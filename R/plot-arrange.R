# --- Arranging several plots in one figure ----------------------------------
#
# `cgraph_plot_grid()` and the `|` / `/` operators (adapted from caugi's plot
# composition; see inst/COPYRIGHTS) put several plots on one page. Like a
# `cgraph_plot`, the arrangement is a lazy object: its panels are rendered only
# when it is printed, so they keep picking up plot_options() at draw time. It
# is a separate class (`cgraph_plots`) because the style verbs act on one
# graph's nodes and edges, which an arrangement does not have.

#' Arrange several plots in one figure
#'
#' Put plots built with [cgraph_plot()] side by side, stacked, or in a grid.
#' `p1 | p2` places plots side by side and `p1 / p2` stacks them; chains like
#' `p1 | p2 | p3` give equal columns, and the two nest: `(p1 | p2) / p3` puts
#' two plots above a third. `cgraph_plot_grid()` lays out any number of plots
#' in rows and columns, e.g. a list of them.
#'
#' The arrangement is drawn when printed, like a single plot: print it with
#' `newpage = FALSE` to draw it into the current grid viewport, or get its grob
#' with [cgraph_grob()]. Style each plot before arranging it.
#'
#' @param ... Plots from [cgraph_plot()], graphs from [cgraph()] (plotted with
#'   the defaults), or arrangements from `cgraph_plot_grid()`, `|` or `/`; or
#'   a single list of them.
#' @param nrow,ncol The number of rows and columns. With neither, the grid is
#'   as square as possible; with one, the other fits all the plots.
#' @param byrow Fill the grid row by row (default) rather than column by
#'   column.
#' @param widths,heights Relative column widths and row heights, e.g.
#'   `widths = c(2, 1)` makes the first column twice as wide. Default equal.
#' @param spacing Grid unit for the gap between plots. Default
#'   `plot_options("spacing")`, initially `grid::unit(1, "lines")`.
#' @param e1,e2 Plots (or graphs, or arrangements) to combine.
#'
#' @returns A `cgraph_plots` object, drawn when printed.
#'
#' @examples
#' if (julia_ready()) {
#'   dag <- cgraph(A %-->% X + Y, X %-->% Y, class = "DAG")
#'   admg <- cgraph(A %-->% X, X %-->% Y, X %<->% Y, class = "ADMG")
#'   p1 <- cgraph_plot(dag, main = "DAG")
#'   p2 <- cgraph_plot(admg, main = "ADMG") |> style_nodes(fill = "salmon")
#'
#'   p1 | p2
#'   p1 / p2
#'   (p1 | p2) / p1
#'
#'   dags <- lapply(1:6, function(i) generate_graph(5, p = 0.4, seed = i))
#'   cgraph_plot_grid(lapply(dags, cgraph_plot), ncol = 3)
#' }
#' @seealso [plot_options()] to change the default `spacing`.
#' @family plotting
#' @export
cgraph_plot_grid <- function(
  ...,
  nrow = NULL,
  ncol = NULL,
  byrow = TRUE,
  widths = NULL,
  heights = NULL,
  spacing = NULL
) {
  plots <- list(...)
  if (
    length(plots) == 1L &&
      is.list(plots[[1L]]) &&
      !inherits(plots[[1L]], c("cgraph_plot", "cgraph_plots"))
  ) {
    plots <- plots[[1L]]
  }
  n <- length(plots)
  if (n == 0L) {
    stop("Give at least one plot to arrange.", call. = FALSE)
  }
  plots <- lapply(unname(plots), .as_plot_panel)

  count <- function(x, name) {
    if (is.null(x)) {
      return(NULL)
    }
    if (!is.numeric(x) || length(x) != 1L || is.na(x) || x < 1 || x %% 1) {
      stop("`", name, "` must be a positive whole number.", call. = FALSE)
    }
    as.integer(x)
  }
  nrow <- count(nrow, "nrow")
  ncol <- count(ncol, "ncol")
  if (is.null(nrow) && is.null(ncol)) {
    ncol <- as.integer(ceiling(sqrt(n)))
  }
  if (is.null(nrow)) {
    nrow <- as.integer(ceiling(n / ncol))
  } else if (is.null(ncol)) {
    ncol <- as.integer(ceiling(n / nrow))
  }
  if (nrow * ncol < n) {
    stop(
      "A ",
      nrow,
      " x ",
      ncol,
      " grid has room for ",
      nrow * ncol,
      " plot(s), not ",
      n,
      ".",
      call. = FALSE
    )
  }

  relative <- function(x, k, name) {
    if (is.null(x)) {
      return(rep(1, k))
    }
    if (!is.numeric(x) || length(x) != k || anyNA(x) || any(x <= 0)) {
      stop(
        "`",
        name,
        "` must be ",
        k,
        " positive number(s), one per ",
        if (name == "widths") "column" else "row",
        ".",
        call. = FALSE
      )
    }
    x
  }
  widths <- relative(widths, ncol, "widths")
  heights <- relative(heights, nrow, "heights")
  if (!is.null(spacing) && !grid::is.unit(spacing)) {
    stop("`spacing` must be a grid::unit().", call. = FALSE)
  }
  stopifnot(isTRUE(byrow) || isFALSE(byrow))

  structure(
    list(
      plots = plots,
      nrow = nrow,
      ncol = ncol,
      byrow = byrow,
      widths = widths,
      heights = heights,
      spacing = spacing,
      # "|" or "/" when built by that operator, so a chain of the same
      # operator flattens into one row or column instead of nesting.
      op = NULL
    ),
    class = "cgraph_plots"
  )
}

.as_plot_panel <- function(x) {
  if (inherits(x, "cgraph_plots")) x else .as_cgraph_plot(x)
}

# The `|` and `/` operators. One function serves as the Ops method of both
# classes: when the two operands' classes have different methods, R warns and
# falls back to the internal operator.
.plot_arrange_ops <- function(e1, e2) {
  op <- .Generic
  if (missing(e2) || !op %in% c("|", "/")) {
    stop(
      "Plots combine only with `|` (side by side) and `/` (stacked).",
      call. = FALSE
    )
  }
  chain <- function(x) {
    if (inherits(x, "cgraph_plots") && identical(x$op, op)) {
      x$plots
    } else {
      list(.as_plot_panel(x))
    }
  }
  plots <- c(chain(e1), chain(e2))
  out <- if (op == "|") {
    cgraph_plot_grid(plots, nrow = 1L)
  } else {
    cgraph_plot_grid(plots, ncol = 1L)
  }
  out$op <- op
  out
}

#' @rdname cgraph_plot_grid
#' @export
Ops.cgraph_plot <- .plot_arrange_ops

#' @rdname cgraph_plot_grid
#' @export
Ops.cgraph_plots <- .plot_arrange_ops

# The grob of an arrangement: a grid layout with a spacer row/column between
# the plots, each plot's grob drawn in its cell.
.plot_arrange_grob <- function(x) {
  spacing <- x$spacing %||% plot_options("spacing")
  interleave <- function(rel) {
    sizes <- grid::unit(rel[1L], "null")
    for (r in rel[-1L]) {
      sizes <- grid::unit.c(sizes, spacing, grid::unit(r, "null"))
    }
    sizes
  }
  layout <- grid::grid.layout(
    nrow = 2L * x$nrow - 1L,
    ncol = 2L * x$ncol - 1L,
    widths = interleave(x$widths),
    heights = interleave(x$heights)
  )

  children <- lapply(seq_along(x$plots), function(i) {
    k <- i - 1L
    if (x$byrow) {
      row <- k %/% x$ncol
      col <- k %% x$ncol
    } else {
      row <- k %% x$nrow
      col <- k %/% x$nrow
    }
    grid::gTree(
      children = grid::gList(cgraph_grob(x$plots[[i]])),
      vp = grid::viewport(
        layout.pos.row = 2L * row + 1L,
        layout.pos.col = 2L * col + 1L
      ),
      name = paste0("cs.panel.", i)
    )
  })

  grid::gTree(
    children = do.call(grid::gList, children),
    vp = grid::viewport(layout = layout),
    name = "cs.arranged"
  )
}

#' @export
print.cgraph_plots <- function(x, ...) {
  plot(x, ...)
}

#' @export
plot.cgraph_plots <- function(x, newpage = TRUE, ...) {
  if (newpage) {
    grid::grid.newpage()
  }
  grid::grid.draw(cgraph_grob(x))
  invisible(x)
}

#' @exportS3Method grid::grid.draw
grid.draw.cgraph_plots <- function(x, recording = TRUE) {
  grid::grid.draw(cgraph_grob(x), recording = recording)
}
