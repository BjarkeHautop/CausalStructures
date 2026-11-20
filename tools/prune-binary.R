# Removes what the pre-built library of CausalStructures doesn't load from its
# bundled Julia runtime, as described in jlbind's "Build options" vignette
# ("Removing more by hand"). jlbind::build_binary() (run by
# .github/workflows/binaries.yaml) calls the function this script returns with
# the library's directory, then tests the library on its own, so a library
# removed here that the package needs fails the build.
#
# CausalStructures.jl's dependencies declare LinearAlgebra, so JuliaC bundles
# the libraries of most of Julia's standard libraries, BLAS among them; this
# keeps only the runtime itself. Nothing calls BLAS: the stress layout of
# NetworkLayout.jl's no-blas-stress branch computes without it.

function(dir) {
  windows <- .Platform$OS.type == "windows"
  # By name without extension or version, and without the salt
  # (`jl<6 hex digits>_`) a private runtime's libjulia and libjulia-internal
  # start with. On Windows, also the MinGW runtime that the others link
  # against.
  keep <- c(
    "libjulia",
    "libjulia-internal",
    "libunwind",
    "libz",
    "libzstd",
    "libatomic",
    "libgcc_s",
    "libopenlibm",
    if (windows) {
      c(
        "libgcc_s_seh-1",
        "libstdc++-6",
        "libwinpthread-1",
        "libatomic-1",
        "libssp-0",
        "zlib1",
        "libzstd-1"
      )
    }
  )
  # The name up to the extension or version: libz.so.1.3.1,
  # libgcc_s.1.1.dylib, libopenblas64_.0.3.34.so, libstdc++-6.dll.
  stem <- function(file) {
    sub(
      "\\.(so|dylib|dll|[0-9]).*$",
      "",
      sub("^jl[0-9a-f]{6}_", "", basename(file))
    )
  }
  lib <- list.files(dir, "^jlbind\\.(so|dylib|dll)$", full.names = TRUE)
  # On Windows, the DLLs the library's private-runtime manifest lists must
  # stay: it fails to load without them.
  if (windows && length(lib)) {
    bytes <- readBin(lib, "raw", file.size(lib))
    text <- rawToChar(bytes[bytes != as.raw(0L)])
    listed <- regmatches(
      text,
      gregexpr("name=\"[^\"]+\\.dll\"", text, useBytes = TRUE)
    )[[1L]]
    keep <- c(keep, stem(sub("^name=\"(.*)\"$", "\\1", listed)))
  }

  bundle <- file.path(dir, "jlbind-bundle")
  unlink(file.path(bundle, "share"), recursive = TRUE)
  # On Windows, a private library's DLLs are at the top, next to it.
  dirs <- c(
    dir,
    file.path(bundle, c("lib", file.path("lib", "julia"), "bin")),
    file.path(bundle, "bin", "julia")
  )
  for (d in dirs[dir.exists(dirs)]) {
    files <- list.files(d, full.names = TRUE)
    files <- files[!dir.exists(files) & !files %in% lib]
    drop <- files[
      grepl("\\.(so|dylib|dll)(\\.|$)", basename(files)) &
        !stem(files) %in% keep
    ]
    for (f in drop) {
      message(
        "Removing ",
        f,
        if (nzchar(Sys.readlink(f))) {
          " (link)"
        } else {
          sprintf(" (%.1f MB)", file.size(f) / 1e6)
        }
      )
    }
    unlink(drop)
  }
}
