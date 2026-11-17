# Builds the package logo: the triangle DAG of CausalStructures.jl's logo
# (docs/generate-logo.jl there), in Julia's colors, drawn with this package's
# own plotting on an R hex sticker. Needs the compiled library and ragg.
#
#   Rscript data-raw/logo.R
#
# Writes man/figures/logo.png (dark) and man/figures/logo-light.png, the
# names quartodown looks for (logo-light.png is used in light mode).

pkgload::load_all(".")
library(grid)

jl_purple <- "#9558B2"
jl_red <- "#CB3C33"
jl_green <- "#389826"

dag <- cgraph(A %-->% B + C, B %-->% C)
# As in the Julia logo: an equilateral triangle, A on top.
layout <- list(A = c(0, 1), B = c(-0.87, -0.5), C = c(0.87, -0.5))

graph_plot <- function(ink) {
  colors <- c(A = jl_purple, B = jl_red, C = jl_green)
  p <- cgraph_plot(dag, layout = layout, asp = 1, outer_margin = unit(0, "mm"))
  for (node in names(colors)) {
    p <- p |>
      style_nodes(fill = colors[[node]], col = colors[[node]], nodes = node)
  }
  p |>
    label_nodes(A = "", B = "", C = "") |>
    style_nodes(radius = 3.2, lwd = 0) |>
    style_edges(col = ink, fill = ink, lwd = 2.4, arrow_size = 2.4, gap = 0.6)
}

# Pointy-top hexagon filling the viewport (sticker standard: 43.9 x 50.8 mm).
hexagon <- function(fill, border, lwd) {
  angles <- (30 + 60 * 0:5) * pi / 180
  polygonGrob(
    x = 0.5 + 0.5 * cos(angles) / cos(pi / 6),
    y = 0.5 + 0.5 * sin(angles),
    gp = gpar(fill = fill, col = border, lwd = lwd)
  )
}

make_logo <- function(path, bg, ink, border) {
  ragg::agg_png(
    path,
    width = 43.9,
    height = 50.8,
    units = "mm",
    res = 600,
    background = "transparent"
  )
  on.exit(grDevices::dev.off())
  grid.newpage()
  # The hexagon's border is drawn inside the device so it is not clipped.
  pushViewport(viewport(width = 0.95, height = 0.95))
  grid.draw(hexagon(bg, border, lwd = 6))
  # Graph in the upper part, name in the lower part.
  pushViewport(viewport(x = 0.5, y = 0.59, width = 0.62, height = 0.48))
  grid.draw(cgraph_grob(graph_plot(ink)))
  popViewport()
  grid.text(
    "CausalStructures",
    x = 0.5,
    y = 0.24,
    gp = gpar(col = ink, fontsize = 9.5, fontface = "bold")
  )
  popViewport()
}

make_logo(
  "man/figures/logo-light.png",
  bg = "#FFFFFF",
  ink = "#1C1A20",
  border = jl_purple
)
make_logo(
  "man/figures/logo.png",
  bg = "#1C1A20",
  ink = "#E4E1E8",
  border = jl_purple
)
