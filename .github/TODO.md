# TODO

- Improve docs

- Capture errors to avoid long stacktrace. Fixed
  - Should this be done in JuliaconnectoR?

- Register Julia Pkg

- Ship Project.toml

- Implement background knowledg and extend the functions that accept it like
  `dag_to_mpdag()`.

- fix edges cg. It needs to show actual edge?

## Maybe?

- Add StableRNGs to the Project.toml shipped with the R package and use it
  (instead of `Random.Xoshiro`/`Random.MersenneTwister`) to build the RNG passed
  from `generate_graph()`/`simulate_data()`'s `seed` arg, for reproducibility
  that's stable across Julia versions.
