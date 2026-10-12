# Call every wrapper once

Calls every exported wrapper once on small graphs, as a quick check that
the compiled library works. The library is compiled ahead of time, so
there is nothing to warm up: the first call to a function is as fast as
any other.

## Usage

``` r
warmup()
```

## Value

`NULL`, invisibly.

## Details

Calls
[`setup()`](https://bjarkehautop.github.io/CausalStructures/reference/setup.md)
itself, so it can be used standalone right after attaching the package.

## Examples

``` r
if (julia_ready()) {
  warmup()
}
```
