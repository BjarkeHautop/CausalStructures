# Compile the csjl binding layer with juliac and copy the resulting bundle
# (the library plus its Julia runtime) into the R package's `inst/csjl`.
#
#     julia --project=jlbuild/build-env -e "using Pkg; Pkg.instantiate()"
#     julia jlbuild/build.jl
#
# The R package loads `inst/csjl/lib/csjl.so` with `dyn.load` and calls its
# `csjl_r_*` entrypoints with `.Call`.

const HERE = @__DIR__

push!(LOAD_PATH, joinpath(HERE, "build-env"))
using JuliaLibWrapping, JuliaC

out = joinpath(HERE, "out")
result = build_library(
    joinpath(HERE, "src", "csjl.jl"),
    [CTarget(out, "csjl")];
    project = HERE,
    libname = "csjl",
    libdir = out,
    bundle = true,
    verbose = true,
)

dest = joinpath(dirname(HERE), "inst", "csjl")
rm(dest; force = true, recursive = true)
cp(result.bundle_dir, dest)

@info "Built csjl" library = result.library bundle = dest
