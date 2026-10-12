# Get or set global default plot styles

Configure package-wide defaults for
[`plot.cgraph()`](https://bjarkehautop.github.io/CausalStructures/reference/plot.md)'s
`node_style`, `edge_style`, `label_style`, and `title_style` arguments,
so every plot picks them up without repeating the same style lists at
every call site. Arguments passed directly to
[`plot()`](https://rdrr.io/r/graphics/plot.default.html) still take
precedence over these global defaults.

## Usage

``` r
plot_options(...)
```

## Arguments

- ...:

  Named values to update options with (merged into the existing options
  via [`utils::modifyList()`](https://rdrr.io/r/utils/modifyList.html),
  so a partial style list only overrides the fields it mentions), or
  unnamed option names to retrieve. Multiple unnamed arguments drill
  down through nested options. Called with no arguments, returns all
  current plot options. Querying a non-existent option raises an error.

## Value

When setting, the previous values for the updated options, invisibly.
When getting, the requested options.

## Details

Fields, matching the corresponding
[`plot.cgraph()`](https://bjarkehautop.github.io/CausalStructures/reference/plot.md)
argument:

- `node_style`: `fill`, `col`, `lwd`, `padding` (mm), `size`
  (multiplier), `radius` (mm, fixed override), `shape` (`"circle"`,
  `"square"`, `"ellipse"`, or `"rect"`), `linestyle` (e.g. `"dashed"`)

- `edge_style`: `col`, `lwd`, `lty`, `fill` (arrowhead fill),
  `arrow_size` (mm), `circle_size` (mm), `gap` (mm), `curvature` (signed
  fraction of edge length; unset by default, so parallel edges between
  the same node pair fan out automatically - see
  [`plot.cgraph()`](https://bjarkehautop.github.io/CausalStructures/reference/plot.md)),
  and the edge label fields `label_col`, `label_fontsize`,
  `label_fontface`, `label_fontfamily`, `label_shift`, `label_distance`
  (mm), `label_rotation` (degrees)

- `label_style`: `col`, `fontsize`, `fontface`, `fontfamily`, `cex`

- `title_style`: same fields as `label_style`

See
[`plot.cgraph()`](https://bjarkehautop.github.io/CausalStructures/reference/plot.md)
for the full description of each field. Per-type (`edge_style$directed`,
...) and per-node/per-edge (`by_node`, `by_edge`, `label_style$by_node`)
overrides stay
[`plot()`](https://rdrr.io/r/graphics/plot.default.html)-call arguments
only - they are not part of these global defaults.

## See also

[`plot.cgraph()`](https://bjarkehautop.github.io/CausalStructures/reference/plot.md)
for per-plot style arguments and per-node/edge overrides,
[`plot_default_options()`](https://bjarkehautop.github.io/CausalStructures/reference/plot_default_options.md)
to inspect or reset to the built-in defaults.

Other plotting:
[`cgraph_layout()`](https://bjarkehautop.github.io/CausalStructures/reference/cgraph_layout.md),
[`plot.cgraph()`](https://bjarkehautop.github.io/CausalStructures/reference/plot.md),
[`plot_default_options()`](https://bjarkehautop.github.io/CausalStructures/reference/plot_default_options.md)

## Examples

``` r
# Query all current plot options
plot_options()
#> $node_style
#> $node_style$fill
#> [1] "white"
#> 
#> $node_style$col
#> [1] "black"
#> 
#> $node_style$lwd
#> [1] 1
#> 
#> $node_style$padding
#> [1] 2
#> 
#> $node_style$size
#> [1] 1
#> 
#> $node_style$shape
#> [1] "circle"
#> 
#> 
#> $edge_style
#> $edge_style$col
#> [1] "black"
#> 
#> $edge_style$lwd
#> [1] 1
#> 
#> $edge_style$arrow_size
#> [1] 3
#> 
#> $edge_style$circle_size
#> [1] 1.5
#> 
#> $edge_style$gap
#> [1] 0
#> 
#> $edge_style$label_col
#> [1] "black"
#> 
#> $edge_style$label_fontsize
#> [1] 9
#> 
#> $edge_style$label_shift
#> [1] 0.5
#> 
#> 
#> $label_style
#> $label_style$col
#> [1] "black"
#> 
#> $label_style$fontsize
#> [1] 10
#> 
#> 
#> $title_style
#> $title_style$col
#> [1] "black"
#> 
#> $title_style$fontsize
#> [1] 14
#> 
#> $title_style$fontface
#> [1] "bold"
#> 
#> 

# Query one option
plot_options("node_style")
#> $fill
#> [1] "white"
#> 
#> $col
#> [1] "black"
#> 
#> $lwd
#> [1] 1
#> 
#> $padding
#> [1] 2
#> 
#> $size
#> [1] 1
#> 
#> $shape
#> [1] "circle"
#> 

# Drill into a nested option
plot_options("node_style", "fill")
#> [1] "white"

# Set a global default node fill
plot_options(node_style = list(fill = "lightblue"))

# Set multiple defaults at once
plot_options(
  node_style = list(fill = "lightblue", col = "navy"),
  edge_style = list(col = "gray40", lwd = 1.5)
)

# Reset to defaults
plot_options(plot_default_options())
```
