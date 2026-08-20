# --- Global plot styling options ------------------------------------------
#
# A dedicated get/set/reset accessor for plot()'s style defaults, modeled on
# caugi::caugi_options() (see inst/COPYRIGHTS for attribution) but scoped to
# plotting only - the package's other settings (auto_install,
# verbose_errors, ...; see CausalStructures_options) stay on base
# options()/getOption(), since those are flat behavioral toggles rather than
# nested graphics-parameter lists.

.cs_plot_env <- new.env(parent = emptyenv())

#' Default plot styling options
#'
#' The built-in defaults for [plot_options()], before any global
#' customization. Useful for resetting after calling [plot_options()], or as
#' a base to build a custom style set from with [utils::modifyList()].
#'
#' @return A list with `node_style`, `edge_style`, `label_style`,
#'   `title_style`, and `tier_style` components - see [plot.cgraph()] for
#'   their fields.
#'
#' @seealso [plot_options()] for getting and setting these globally.
#' @family plotting
#' @export
#'
#' @examples
#' plot_default_options()
#'
#' # Reset to defaults after changing them
#' plot_options(plot_default_options())
plot_default_options <- function() {
  list(
    node_style = list(
      fill = "white",
      col = "black",
      lwd = 1,
      padding = 2,
      size = 1,
      shape = "round"
    ),
    edge_style = list(
      col = "black",
      lwd = 1,
      arrow_size = 3,
      circle_size = 1.5,
      curvature = 0
    ),
    label_style = list(col = "black", fontsize = 10),
    title_style = list(col = "black", fontsize = 14, fontface = "bold"),
    tier_style = list(
      boxes = TRUE,
      labels = FALSE,
      fill = "lightsteelblue",
      col = "transparent",
      lwd = 1,
      padding = 4,
      label_style = list()
    )
  )
}

#' Get or set global default plot styles
#'
#' Configure package-wide defaults for [plot.cgraph()]'s `node_style`,
#' `edge_style`, `label_style`, `title_style`, and `tier_style` arguments, so
#' every plot picks them up without repeating the same style lists at every
#' call site. Arguments passed directly to `plot()` still take precedence
#' over these global defaults.
#'
#' @param ... Named values to update options with (merged into the existing
#'   options via [utils::modifyList()], so a partial style list only
#'   overrides the fields it mentions), or unnamed option names to retrieve.
#'   Multiple unnamed arguments drill down through nested options. Called
#'   with no arguments, returns all current plot options. Querying a
#'   non-existent option raises an error.
#'
#' @return When setting, the previous values for the updated options,
#'   invisibly. When getting, the requested options.
#'
#' @details
#' Fields, matching the corresponding `plot.cgraph()` argument:
#'
#' - `node_style`: `fill`, `col`, `lwd`, `padding` (mm), `size` (multiplier),
#'   `shape` (`"round"` or `"box"`), `linestyle` (e.g. `"dashed"`)
#' - `edge_style`: `col`, `lwd`, `fill` (arrowhead fill), `arrow_size` (mm),
#'   `circle_size` (mm), `curvature` (signed fraction of edge length)
#' - `label_style`: `col`, `fontsize`, `fontface`, `fontfamily`, `cex`
#' - `title_style`: same fields as `label_style`
#' - `tier_style`: `boxes`, `labels`, `fill`, `col`, `lwd`, `padding` (mm),
#'   `label_style`
#'
#' See [plot.cgraph()] for the full description of each field. Per-type
#' (`edge_style$directed`, ...), per-node/per-edge (`by_node`, `by_edge`), and
#' per-tier (`by_tier`) overrides stay `plot()`-call arguments only - they are
#' not part of these global defaults.
#'
#' @seealso [plot.cgraph()] for per-plot style arguments and per-node/edge/
#'   tier overrides, [plot_default_options()] to inspect or reset to the
#'   built-in defaults.
#' @family plotting
#' @export
#'
#' @examples
#' # Query all current plot options
#' plot_options()
#'
#' # Query one option
#' plot_options("node_style")
#'
#' # Drill into a nested option
#' plot_options("node_style", "fill")
#'
#' # Set a global default node fill
#' plot_options(node_style = list(fill = "lightblue"))
#'
#' # Set multiple defaults at once
#' plot_options(
#'   node_style = list(fill = "lightblue", col = "navy"),
#'   edge_style = list(col = "gray40", lwd = 1.5)
#' )
#'
#' # Reset to defaults
#' plot_options(plot_default_options())
plot_options <- function(...) {
  new <- list(...)
  if (is.null(names(new)) && length(new) == 1L && is.list(new[[1L]])) {
    new <- new[[1L]]
  }

  old <- get0("options", .cs_plot_env, ifnotfound = plot_default_options())

  if (length(new) == 0L) {
    return(old)
  }

  nm <- names(new)

  if (is.null(nm)) {
    keys <- unlist(new)

    if (length(keys) == 1L) {
      if (!keys %in% names(old)) {
        stop(sprintf("Plot option '%s' does not exist", keys), call. = FALSE)
      }
      return(old[[keys]])
    }

    result <- old
    path <- character()
    for (key in keys) {
      path <- c(path, key)
      if (!is.list(result)) {
        stop(
          sprintf(
            "Cannot access '%s': '%s' is not a list",
            paste(path, collapse = "$"),
            paste(utils::head(path, -1L), collapse = "$")
          ),
          call. = FALSE
        )
      }
      if (!key %in% names(result)) {
        stop(
          sprintf(
            "Plot option '%s' does not exist",
            paste(path, collapse = "$")
          ),
          call. = FALSE
        )
      }
      result <- result[[key]]
    }
    return(result)
  }

  out <- old[nm]
  names(out) <- nm

  .cs_plot_env$options <- utils::modifyList(old, new)
  invisible(out)
}
