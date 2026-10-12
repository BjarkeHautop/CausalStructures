# Compile the csjl binding layer into a shared library with juliac.
#
#     julia --startup-file=no inst/julia/build.jl <output directory> [options]
#
# Run by the R package's install_backend() (from the installed package's
# `julia` directory), so the library is built by, and links against, the
# user's own Julia. By default the dependencies are the exact versions in the
# shipped Manifest.toml. Options:
#
#   --update          ignore the manifest and resolve the newest versions the
#                     Project.toml's [compat] allows
#   --project=<dir>   use the Project.toml (and Manifest.toml, if there is one)
#                     in <dir> instead of the shipped ones
#
# Set CAUSALSTRUCTURES_JL_PATH to a local CausalStructures.jl checkout to build
# against it instead of the registered release.

import Pkg

const HERE = @__DIR__
const OUT = abspath(ARGS[1])
const UPDATE = "--update" in ARGS
const SOURCE = let i = findfirst(startswith("--project="), ARGS)
    i === nothing ? HERE : abspath(chopprefix(ARGS[i], "--project="))
end
mkpath(OUT)

# The library project is instantiated from a scratch copy, so nothing is ever
# written into the package sources or the user's project. The copies are made
# writable, since an installed package's files may not be.
function copy_writable(src, dst)
    cp(src, dst)
    chmod(dst, 0o644)
end

project = mktempdir()
copy_writable(joinpath(SOURCE, "Project.toml"), joinpath(project, "Project.toml"))
manifest = joinpath(project, "Manifest.toml")
if !UPDATE && isfile(joinpath(SOURCE, "Manifest.toml"))
    copy_writable(joinpath(SOURCE, "Manifest.toml"), manifest)
end
cp(joinpath(HERE, "src"), joinpath(project, "src"))
Pkg.activate(project)
dev = get(ENV, "CAUSALSTRUCTURES_JL_PATH", "")
isempty(dev) || Pkg.develop(Pkg.PackageSpec(path = dev))
try
    Pkg.instantiate()
catch e
    # A manifest resolved with another Julia version can fail to instantiate
    # (e.g. on different standard library versions), so fall back to the
    # newest compatible versions rather than not building at all.
    isfile(manifest) || rethrow()
    @warn "Could not instantiate the Manifest.toml; resolving the newest " *
        "versions its Project.toml allows instead." exception = e
    rm(manifest)
    Pkg.instantiate()
end

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
