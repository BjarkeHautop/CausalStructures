# R's C API, called directly: the library is loaded into the R process, so
# every symbol below resolves against the already-loaded libR. Entrypoints
# take and return `SEXP`s and are reached from R through `.Call`.
#
# R signals allocation failures by longjmp, which must never cross Julia
# frames; the only R calls made here that can do so are allocations, which
# fail only when R is out of memory. Every other failure is a Julia exception,
# returned to R as a `csjl_error` object and raised there.

const SEXP = Ptr{Cvoid}

const LGLSXP = Cint(10)
const INTSXP = Cint(13)
const REALSXP = Cint(14)
const STRSXP = Cint(16)
const VECSXP = Cint(19)
const EXTPTRSXP = Cint(22)
const CE_UTF8 = Cint(1)

_nil() = unsafe_load(cglobal(:R_NilValue, SEXP))
_typeof(x::SEXP) = ccall(:TYPEOF, Cint, (SEXP,), x)
_length(x::SEXP) = ccall(:Rf_xlength, Int, (SEXP,), x)
_protect(x::SEXP) = ccall(:Rf_protect, SEXP, (SEXP,), x)
_unprotect(n::Integer) = ccall(:Rf_unprotect, Cvoid, (Cint,), n)
_alloc(t::Cint, n::Integer) = ccall(:Rf_allocVector, SEXP, (Cint, Int), t, n)
_alloc_matrix(t::Cint, nrow::Integer, ncol::Integer) =
    ccall(:Rf_allocMatrix, SEXP, (Cint, Cint, Cint), t, nrow, ncol)
_string_elt(x::SEXP, i::Integer) = ccall(:STRING_ELT, SEXP, (SEXP, Int), x, i)
_set_string_elt(x::SEXP, i::Integer, v::SEXP) =
    ccall(:SET_STRING_ELT, Cvoid, (SEXP, Int, SEXP), x, i, v)
_set_vector_elt(x::SEXP, i::Integer, v::SEXP) =
    ccall(:SET_VECTOR_ELT, SEXP, (SEXP, Int, SEXP), x, i, v)
_real_ptr(x::SEXP) = ccall(:REAL, Ptr{Float64}, (SEXP,), x)
_utf8(charsxp::SEXP) = ccall(:Rf_translateCharUTF8, Ptr{UInt8}, (SEXP,), charsxp)
_int_ptr(x::SEXP) = ccall(:INTEGER, Ptr{Cint}, (SEXP,), x)
_r_global(name::Symbol) = unsafe_load(cglobal(name, SEXP))
_set_attrib(x::SEXP, name::SEXP, value::SEXP) =
    ccall(:Rf_setAttrib, SEXP, (SEXP, SEXP, SEXP), x, name, value)
_preserve(x::SEXP) = (ccall(:R_PreserveObject, Cvoid, (SEXP,), x); x)

_mkchar(p::Ptr{UInt8}, n::Integer) =
    ccall(:Rf_mkCharLenCE, SEXP, (Ptr{UInt8}, Cint, Cint), p, n, CE_UTF8)
_mkchar_uncached(s::Symbol) = ccall(:Rf_mkCharCE, SEXP, (Ptr{UInt8}, Cint), s, CE_UTF8)

# R string for each node name seen, preserved so R never collects it. Interning
# a string in R hashes it, which dominates the cost of returning node names;
# a symbol is looked up here by identity instead.
const _CHARSXPS = Dict{Symbol,SEXP}()
const _CHARSXP_CAP = 1_000_000

function _mkchar(s::Symbol)
    c = get(_CHARSXPS, s, C_NULL)
    c == C_NULL || return c
    c = _mkchar_uncached(s)
    length(_CHARSXPS) < _CHARSXP_CAP || return c
    _protect(c)
    ccall(:R_PreserveObject, Cvoid, (SEXP,), c)
    _unprotect(1)
    _CHARSXPS[s] = c
    return c
end
_mkchar(s::String) = GC.@preserve s _mkchar(pointer(s), sizeof(s))

# --- R -> Julia --------------------------------------------------------------

function _check_type(x::SEXP, t::Cint, what::String)
    _typeof(x) == t || throw(ArgumentError("expected " * what))
    return nothing
end

function _scalar_check(x::SEXP, t::Cint, what::String)
    _check_type(x, t, what)
    _length(x) == 1 || throw(ArgumentError("expected a single " * what))
    return nothing
end

from_sexp(::Type{SEXP}, x::SEXP) = x

function from_sexp(::Type{String}, x::SEXP)
    _scalar_check(x, STRSXP, "character string")
    return unsafe_string(_utf8(_string_elt(x, 0)))
end

function from_sexp(::Type{Symbol}, x::SEXP)
    _scalar_check(x, STRSXP, "character string")
    return ccall(:jl_symbol, Ref{Symbol}, (Ptr{UInt8},), _utf8(_string_elt(x, 0)))
end

function from_sexp(::Type{Vector{Symbol}}, x::SEXP)
    _check_type(x, STRSXP, "character vector")
    n = _length(x)
    out = Vector{Symbol}(undef, n)
    for i = 1:n
        p = _utf8(_string_elt(x, i - 1))
        out[i] = ccall(:jl_symbol, Ref{Symbol}, (Ptr{UInt8},), p)
    end
    return out
end

function from_sexp(::Type{Union{Nothing,Vector{Symbol}}}, x::SEXP)
    x == _nil() && return nothing
    return from_sexp(Vector{Symbol}, x)
end

function from_sexp(::Type{Bool}, x::SEXP)
    v = ccall(:Rf_asLogical, Cint, (SEXP,), x)
    v == typemin(Cint) && throw(ArgumentError("expected TRUE or FALSE, not NA"))
    return v != 0
end

function from_sexp(::Type{Int64}, x::SEXP)
    v = ccall(:Rf_asReal, Float64, (SEXP,), x)
    isnan(v) && throw(ArgumentError("expected a number, not NA"))
    return Int64(v)
end

function from_sexp(::Type{Float64}, x::SEXP)
    v = ccall(:Rf_asReal, Float64, (SEXP,), x)
    isnan(v) && throw(ArgumentError("expected a number, not NA"))
    return v
end

function from_sexp(::Type{Vector{Float64}}, x::SEXP)
    _check_type(x, REALSXP, "numeric vector")
    return copy(unsafe_wrap(Array, _real_ptr(x), _length(x)))
end

function from_sexp(::Type{Union{Nothing,Int64}}, x::SEXP)
    x == _nil() && return nothing
    return from_sexp(Int64, x)
end

function from_sexp(::Type{Union{Nothing,Float64}}, x::SEXP)
    x == _nil() && return nothing
    return from_sexp(Float64, x)
end

# --- Graphs ------------------------------------------------------------------

# A graph crosses into R as an external pointer whose address is its registry
# handle, classed `cgraph`, with a C finalizer that releases the handle.
struct GraphHandle end

function from_sexp(::Type{GraphHandle}, x::SEXP)::Int64
    _typeof(x) == EXTPTRSXP ||
        throw(ArgumentError("expected a causal graph created with cgraph()"))
    return Int64(UInt(ccall(:R_ExternalPtrAddr, Ptr{Cvoid}, (SEXP,), x)))
end

function _finalize_graph(x::SEXP)::Cvoid
    h = Int64(UInt(ccall(:R_ExternalPtrAddr, Ptr{Cvoid}, (SEXP,), x)))
    h == 0 || release_graph(h)
    ccall(:R_ClearExternalPtr, Cvoid, (SEXP,), x)
    return nothing
end

# Created on first use: a function pointer or a preserved R object cannot be
# baked into the compiled image.
const _FINALIZER = Ref{Ptr{Cvoid}}(C_NULL)
const _CGRAPH_CLASS = Ref{SEXP}(C_NULL)

function _graph_sexp(h::Int64)
    if _FINALIZER[] == C_NULL
        _FINALIZER[] = @cfunction(_finalize_graph, Cvoid, (SEXP,))
        _CGRAPH_CLASS[] = _preserve(to_sexp("cgraph"))
    end
    x = _protect(ccall(
        :R_MakeExternalPtr, SEXP, (Ptr{Cvoid}, SEXP, SEXP),
        Ptr{Cvoid}(UInt(h)), _nil(), _nil(),
    ))
    ccall(:R_RegisterCFinalizerEx, Cvoid, (SEXP, Ptr{Cvoid}, Cint), x, _FINALIZER[], 1)
    _set_attrib(x, _r_global(:R_ClassSymbol), _CGRAPH_CLASS[])
    _unprotect(1)
    return x
end

function _graph_list_sexp(hs::Vector{Int64})
    out = _protect(_alloc(VECSXP, length(hs)))
    for (i, h) in enumerate(hs)
        _set_vector_elt(out, i - 1, _graph_sexp(h))
    end
    _unprotect(1)
    return out
end

# --- Julia -> R --------------------------------------------------------------

to_sexp(x::SEXP) = x
to_sexp(::Nothing) = _nil()
to_sexp(x::Bool) = ccall(:Rf_ScalarLogical, SEXP, (Cint,), x)
to_sexp(x::Int64) = ccall(:Rf_ScalarReal, SEXP, (Float64,), Float64(x))
to_sexp(x::Int32) = ccall(:Rf_ScalarInteger, SEXP, (Cint,), x)
to_sexp(x::Float64) = ccall(:Rf_ScalarReal, SEXP, (Float64,), x)

function to_sexp(s::String)
    out = _protect(_alloc(STRSXP, 1))
    _set_string_elt(out, 0, _mkchar(s))
    _unprotect(1)
    return out
end

function to_sexp(xs::Union{Vector{Symbol},Vector{String}})
    out = _protect(_alloc(STRSXP, length(xs)))
    for (i, x) in enumerate(xs)
        _set_string_elt(out, i - 1, _mkchar(x))
    end
    _unprotect(1)
    return out
end

function to_sexp(xs::Vector{Int64})
    out = _protect(_alloc(REALSXP, length(xs)))
    p = _real_ptr(out)
    for (i, x) in enumerate(xs)
        unsafe_store!(p, Float64(x), i)
    end
    _unprotect(1)
    return out
end

# A `data.frame` from equal-length columns.
function _data_frame(names::Vector{String}, columns::Vector{SEXP})
    n = length(columns) == 0 ? 0 : _length(columns[1])
    out = _protect(_alloc(VECSXP, length(columns)))
    for (i, col) in enumerate(columns)
        _set_vector_elt(out, i - 1, col)
    end
    _set_attrib(out, _r_global(:R_NamesSymbol), to_sexp(names))
    _set_attrib(out, _r_global(:R_ClassSymbol), to_sexp("data.frame"))
    rownames = _protect(_alloc(INTSXP, 2))
    unsafe_store!(_int_ptr(rownames), typemin(Cint), 1)
    unsafe_store!(_int_ptr(rownames), Cint(-n), 2)
    _set_attrib(out, _r_global(:R_RowNamesSymbol), rownames)
    _unprotect(2)
    return out
end

# A list, one element per item.
function to_sexp(xs::Vector{T}) where {T<:Union{Vector,Nothing}}
    out = _protect(_alloc(VECSXP, length(xs)))
    for (i, x) in enumerate(xs)
        _set_vector_elt(out, i - 1, to_sexp(x))
    end
    _unprotect(1)
    return out
end

function _error_sexp(msg::String)
    out = _protect(to_sexp(msg))
    class = _protect(to_sexp("csjl_error"))
    ccall(
        :Rf_setAttrib, SEXP, (SEXP, SEXP, SEXP),
        out, unsafe_load(cglobal(:R_ClassSymbol, SEXP)), class,
    )
    _unprotect(2)
    return out
end

# The message of the exception kinds CausalStructures throws. Anything else is
# summarized, since rendering an arbitrary exception is a dynamic call.
function _error_message(@nospecialize(e))::String
    e isa ArgumentError && return _msg(e.msg)
    e isa ErrorException && return _msg(e.msg)
    e isa DimensionMismatch && return _msg(e.msg)
    e isa OverflowError && return _msg(e.msg)
    e isa KeyError && return "key not found"
    e isa BoundsError && return "index out of bounds"
    e isa DomainError && return "domain error"
    e isa InexactError && return "inexact conversion"
    return "internal error in the compiled CausalStructures library"
end

_msg(@nospecialize(m::AbstractString))::String = m isa String ? m : "error"

# `@rcall f(a::T, ...)::R` exports `csjl_r_f(a::SEXP, ...)::SEXP`, which
# converts each argument with `from_sexp`, calls `f`, and converts the result
# with `to_sexp`; a Julia exception comes back as a `csjl_error` object.
macro rcall(sig)
    sig.head === :(::) || error("@rcall needs a return type")
    call, R = sig.args
    fname = call.args[1]
    argnames = Symbol[]
    argtypes = Any[]
    for a in call.args[2:end]
        push!(argnames, a.args[1])
        push!(argtypes, a.args[2])
    end
    cname = Symbol(:csjl_r_, fname)
    params = [:($n::SEXP) for n in argnames]
    converted = [:(from_sexp($T, $n)) for (n, T) in zip(argnames, argtypes)]
    value = :($fname($(converted...)))
    result = if R === :GraphHandle
        :(_graph_sexp($value::Int64))
    elseif R == :(Vector{GraphHandle})
        :(_graph_list_sexp($value::Vector{Int64}))
    else
        :(to_sexp($value::$R))
    end
    return esc(quote
        Base.@ccallable function $cname($(params...))::SEXP
            try
                return $result
            catch e
                return _error_sexp(_error_message(e))
            end
        end
    end)
end
