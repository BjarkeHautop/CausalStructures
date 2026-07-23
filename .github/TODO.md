# TODO

- Improve docs

- Register Julia Pkg

- Ship Project.toml

- Implement background knowledg and extend the functions that accept it like
  `dag_to_mpdag()`.

- Make more options (plot/layout defaults, open vs closed, what random backend
  to use (see below) and so on?).

- Make vignettes+README.

- Improve plot
  - Composition
  - Tiered plots working better with uneven tier groups
  - Partially tiered plots (hard)

- Make some nice plot themes?

## Maybe?

- Add StableRNGs to the Project.toml shipped with the R package and use it
  (instead of `Random.Xoshiro`/`Random.MersenneTwister`) to build the RNG passed
  from `generate_graph()`/`simulate_data()`'s `seed` arg, for reproducibility
  that's stable across Julia versions.
