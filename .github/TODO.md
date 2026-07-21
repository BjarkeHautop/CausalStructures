# TODO

- Improve docs
- Capture errors to avoid long stacktrace.
  - Should this be done in JuliaconnectoR?
- Register Julia Pkg
- Ship Project.toml

## Maybe?

- Add StableRNGs to the Project.toml shipped with the R package and use it
  (instead of `Random.Xoshiro`/`Random.MersenneTwister`) to build the RNG passed
  from `cs_generate_graph()`/`cs_simulate_data()`'s `seed` arg, for
  reproducibility that's stable across Julia versions.
