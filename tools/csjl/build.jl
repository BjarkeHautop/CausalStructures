# Compile the csjl binding layer into a shared library with juliac.
#
#     julia --startup-file=no tools/csjl/build.jl <output directory>
#
# Run by the R package's `configure` when it is installed, so the library is
# built by, and links against, the user's own Julia. Set
# CAUSALSTRUCTURES_JL_PATH to a local CausalStructures.jl checkout to build
# against it instead of the registered release.

import Pkg

const HERE = @__DIR__
const OUT = abspath(ARGS[1])
mkpath(OUT)

# The library project is instantiated from a scratch copy, so no manifest is
# ever written into the package sources.
project = mktempdir()
cp(joinpath(HERE, "Project.toml"), joinpath(project, "Project.toml"))
cp(joinpath(HERE, "src"), joinpath(project, "src"))
Pkg.activate(project)
dev = get(ENV, "CAUSALSTRUCTURES_JL_PATH", "")
isempty(dev) || Pkg.develop(Pkg.PackageSpec(path = dev))
Pkg.instantiate()

# JuliaC gets its own environment, so it is never compiled into the library.
Pkg.activate(; temp = true)
Pkg.add(Pkg.PackageSpec(name = "JuliaC", version = "0.3"))

using JuliaC

# The CLI's `--output-lib --trim=safe --experimental --compile-ccallable`,
# plus `set_threads.c`, which the CLI cannot add.
image = JuliaC.ImageRecipe(;
    output_type = "--output-lib",
    file = joinpath(project, "src", "csjl.jl"),
    project = project,
    trim_mode = "safe",
    add_ccallables = true,
    julia_args = ["--experimental"],
    c_sources = [joinpath(project, "src", "set_threads.c")],
)
JuliaC.compile_products(image)
JuliaC.link_products(JuliaC.LinkRecipe(; image_recipe = image, outname = joinpath(OUT, "csjl")))

# A Windows DLL has no RUNPATH, so record where the Julia runtime it links
# against lives; the R package puts it on the DLL search path before loading.
if Sys.iswindows()
    write(joinpath(OUT, "julia_bindir"), Sys.BINDIR)
end
