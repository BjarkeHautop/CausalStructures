# R packages only collate .R files directly under R/, not subdirectories
# (Writing R Extensions; pkgload::load_all() follows the same rule). The
# juliacall/ experiment lives in its own folder per request, so its files are
# sourced explicitly here instead of being picked up by normal collation.
# Load order matters: jc-session.R defines jc_setup()/jc_fn()/jc_graph_fn()/
# jc_node_query(), which every other file in R/juliacall/ calls at
# definition time (e.g. `jc_is_dag <- jc_graph_fn("is_dag")`) or call time.
.jc_collate <- c(
  "jc-session.R",
  "jc-construction.R",
  "jc-queries.R",
  "jc-transform.R",
  "jc-identification.R",
  "jc-data.R"
)

.onLoad <- function(libname, pkgname) {
  ns <- asNamespace(pkgname)
  # libname/pkgname (not system.file(), which pkgload's dev shim resolves
  # to inst/ when present) is the source-tree root in both load_all() and a
  # real install.
  dir <- file.path(libname, pkgname, "R", "juliacall")
  for (f in .jc_collate) {
    sys.source(file.path(dir, f), envir = ns)
  }
}
