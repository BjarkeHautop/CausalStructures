# Benchmarks every testpkg wrapper (CausalStructures.jl via JuliaConnectoR)
# against its caugi counterpart, using bench::mark().
#
# Not part of the built package (listed in .Rbuildignore). Run with:
#   Rscript benchmark.R   (from the package root)
#
# Note: the query benchmarks use a random DAG with the same n, p, and seed on
# both sides, but the R and Julia RNGs differ, so the two graphs are not
# identical -- comparable in size/density only.

pkgload::load_all(".", quiet = TRUE)

library(caugi)

n <- 1000L
p <- 0.25

# --- Graphs ------------------------------------------------------------------
cs_setup()
jdag <- cs_generate_graph(n, p = p, seed = 1405L)

cg <- generate_graph(n = n, p = p, class = "DAG", seed = 1405)
cg <- build(cg)

node <- "V45"
x <- "V50"
y <- "V70"
z <- cs_adjustment_set(jdag, x, y)

spec_small <- "A --> X + Y, X --> M --> Y"

# Warm-up
invisible(cs_cgraph(spec_small))
invisible(cs_parents(jdag, node))
invisible(cs_topological_sort(jdag))
invisible(cs_d_separated(jdag, x, y, z))
invisible(cs_adjustment_set(jdag, x, y))

run <- function(name, expr_julia, expr_caugi) {
  res <- bench::mark(
    julia = expr_julia(),
    caugi = expr_caugi(),
    check = FALSE,
    min_iterations = 10
  )
  res$benchmark <- name
  res[, c("benchmark", "expression", "median", "itr/sec", "mem_alloc")]
}

results <- rbind(
  run(
    "cgraph (4-node DSL graph)",
    function() cs_cgraph(spec_small),
    function() build(caugi(A %-->% X + Y, X %-->% M, M %-->% Y, class = "DAG"))
  ),
  run(
    "parents",
    function() cs_parents(jdag, node),
    function() parents(cg, node)
  ),
  run(
    "topological_sort",
    function() cs_topological_sort(jdag),
    function() topological_sort(cg)
  ),
  run(
    "d_separated",
    function() cs_d_separated(jdag, x, y, z),
    function() d_separated(cg, x, y, z)
  ),
  run(
    "adjustment_set (backdoor)",
    function() cs_adjustment_set(jdag, x, y),
    function() adjustment_set(cg, x, y, type = "backdoor")
  )
)

print(results, n = nrow(results))

cs_stop()
