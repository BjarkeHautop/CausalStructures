# Default plot styling options

The built-in defaults for
[`plot_options()`](https://bjarkehautop.github.io/CausalStructures/reference/plot_options.md),
before any global customization. Useful for resetting after calling
[`plot_options()`](https://bjarkehautop.github.io/CausalStructures/reference/plot_options.md),
or as a base to build a custom style set from with
[`utils::modifyList()`](https://rdrr.io/r/utils/modifyList.html).

## Usage

``` r
plot_default_options()
```

## Value

A list with `node_style`, `edge_style`, `label_style`, and `title_style`
components - see
[`plot.cgraph()`](https://bjarkehautop.github.io/CausalStructures/reference/plot.md)
for their fields.

## See also

[`plot_options()`](https://bjarkehautop.github.io/CausalStructures/reference/plot_options.md)
for getting and setting these globally.

Other plotting:
[`cgraph_layout()`](https://bjarkehautop.github.io/CausalStructures/reference/cgraph_layout.md),
[`plot.cgraph()`](https://bjarkehautop.github.io/CausalStructures/reference/plot.md),
[`plot_options()`](https://bjarkehautop.github.io/CausalStructures/reference/plot_options.md)

## Examples

``` r
plot_default_options()
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

# Reset to defaults after changing them
plot_options(plot_default_options())
```
