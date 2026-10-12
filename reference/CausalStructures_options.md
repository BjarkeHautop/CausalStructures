# Package options

`CausalStructures` reads the following
[`options()`](https://rdrr.io/r/base/options.html):

## Details

- `CausalStructures.open`:

  Logical, default `TRUE`. Default for the `open` argument of
  [`ancestors()`](https://bjarkehautop.github.io/CausalStructures/reference/node-queries.md),
  [`descendants()`](https://bjarkehautop.github.io/CausalStructures/reference/node-queries.md),
  [`possible_ancestors()`](https://bjarkehautop.github.io/CausalStructures/reference/possible-queries.md),
  [`possible_descendants()`](https://bjarkehautop.github.io/CausalStructures/reference/possible-queries.md),
  [`anteriors()`](https://bjarkehautop.github.io/CausalStructures/reference/anteriors.md),
  and
  [`posteriors()`](https://bjarkehautop.github.io/CausalStructures/reference/anteriors.md):
  `TRUE` (open definition) excludes the query node itself from the
  result, `FALSE` (closed definition) includes it.

The number of Julia threads is read from the `JULIA_NUM_THREADS`
environment variable (a number or `"auto"`) when the package is loaded,
so set it before
[`library(CausalStructures)`](https://github.com/BjarkeHautop/CausalStructures).
More than one thread also turns on Julia's signal handling in the R
process, which Julia's garbage collector needs for multi-threading.

The compiled library is looked up in the `CAUSALSTRUCTURES_LIBRARY`
environment variable first (a path to the `csjl` shared library), then
in the installed package's `csjl` directory (a development build), then
where
[`install_backend()`](https://bjarkehautop.github.io/CausalStructures/reference/install_backend.md)
builds it.
