# Load the compiled CausalStructures.jl library

Called automatically by the wrapper functions; call it yourself to pay
the (small) library load cost up front. The library is compiled ahead of
time, so there is no Julia session to start and nothing to precompile.

## Usage

``` r
setup()
```

## Value

`NULL`, invisibly.

## Examples

``` r
if (julia_ready()) {
  setup()
}
```
