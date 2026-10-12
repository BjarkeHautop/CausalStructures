"""
    csjl

The binding layer that exposes CausalStructures.jl to R. It is compiled with
`juliac --trim=safe` into a shared library that R loads with `dyn.load` and
calls with `.Call`: each entrypoint takes and returns R objects (`SEXP`s) and
converts them itself through R's C API, so there is no marshalling layer in
between.

A graph cannot cross into R as a value, so each one lives in a registry on the
Julia side and R holds an integer handle to it. Every entrypoint looks its
graph up, then branches on the concrete graph class before calling into
CausalStructures, so that `--trim` sees only statically resolved calls.
"""
module csjl

import CausalStructures as CS
using CausalStructures:
    CausalGraph, CausalEdge, DAG, UG, PDAG, CPDAG, MPDAG, ADMG, AG, MAG, PAG, UNKNOWN
import Random

include("rapi.jl")

# --- Graph registry ----------------------------------------------------------

const GRAPHS = Dict{Int64,CausalGraph}()
const NEXT_HANDLE = Ref{Int64}(0)

# Handles released by R finalizers, dropped on the next store. A finalizer can
# run while another entrypoint is mid-call, so it never touches `GRAPHS`.
const RELEASED = Int64[]

function _store(g::CausalGraph)::Int64
    for h in RELEASED
        delete!(GRAPHS, h)
    end
    empty!(RELEASED)
    NEXT_HANDLE[] += 1
    GRAPHS[NEXT_HANDLE[]] = g
    return NEXT_HANDLE[]
end

function _graph(h::Int64)::CausalGraph
    g = get(GRAPHS, h, nothing)
    g === nothing && throw(ArgumentError("invalid or released graph handle $h"))
    return g
end

# --- Class dispatch ----------------------------------------------------------

const ALL_CLASSES = (:DAG, :UG, :PDAG, :CPDAG, :MPDAG, :ADMG, :AG, :MAG, :PAG, :UNKNOWN)

function _unsupported(fname::String, class::String)
    throw(ArgumentError(fname * "() is not supported for a " * class))
end

# `@on "f" g (DAG, ADMG) body` evaluates `body` with `g` narrowed to each
# listed concrete class in turn, and throws for any other class. `ALL` stands
# for every class.
macro on(fname, g, classes, body)
    Ts = classes === :ALL ? ALL_CLASSES : Tuple(classes.args)
    ex = :(_unsupported($fname, _class_name($g)))
    for T in reverse(Ts)
        ex = Expr(:if, :($g isa $T), :(
            let $g = $g::$T
                $body
            end
        ), ex)
    end
    return esc(ex)
end

# `@class cls T body` evaluates `body` with `T` bound to the graph type named
# by the string `cls`, restricted to the listed classes.
macro class(cls, T, classes, body)
    Ts = classes === :ALL ? ALL_CLASSES : Tuple(classes.args)
    ex = :(throw(ArgumentError("unsupported graph class " * $cls)))
    for C in reverse(Ts)
        ex = Expr(:if, :($cls == $(String(C))), :(
            let $T = $C
                $body
            end
        ), ex)
    end
    return esc(ex)
end

# The class name, branched out so it never needs a dynamic `nameof(typeof(g))`.
function _class_name(g::CausalGraph)::String
    g isa DAG && return "DAG"
    g isa UG && return "UG"
    g isa PDAG && return "PDAG"
    g isa CPDAG && return "CPDAG"
    g isa MPDAG && return "MPDAG"
    g isa ADMG && return "ADMG"
    g isa AG && return "AG"
    g isa MAG && return "MAG"
    g isa PAG && return "PAG"
    return "UNKNOWN"
end

# --- Conversions -------------------------------------------------------------

const SymSet = Vector{Symbol}

_set(xs)::SymSet = sort!(Symbol[x for x in xs])
_opt(xs)::Union{Nothing,SymSet} = xs === nothing ? nothing : _set(xs)
_sets(sets)::Vector{SymSet} = SymSet[_set(s) for s in sets]
_opt_sets(sets)::Vector{Union{Nothing,SymSet}} =
    Union{Nothing,SymSet}[s === nothing ? nothing : _set(s) for s in sets]

_rng(seed::Union{Int64,Nothing}) =
    seed === nothing ? Random.Xoshiro() : Random.Xoshiro(seed)

function _spec_edges(spec::String)
    es = CausalEdge[]
    for item in CS._parse_graph_string(spec)
        item isa CausalEdge && push!(es, item)
    end
    return es
end

# --- Construction and lifetime ----------------------------------------------

release_graph(h::Int64) = (push!(RELEASED, h); nothing)

graph_count() = Int64(length(GRAPHS) - length(RELEASED))

cgraph(spec::String, class::String) = @class class T ALL _store(T(spec))

# `m`, `p` and `seed` arrive unconverted: three optional arguments in one call
# exceed what the compiler union-splits.
function generate_graph(
    n::Int64, m::SEXP, p::SEXP, class::String, latents::Int64, seed::SEXP,
)
    rng = _rng(from_sexp(Union{Nothing,Int64}, seed))
    mm = from_sexp(Union{Nothing,Int64}, m)
    pp = from_sexp(Union{Nothing,Float64}, p)
    @class class T (DAG, CPDAG, ADMG, MAG, PAG) _store(_generate(rng, n, mm, pp, T, latents))
end

# A type passed as a keyword is stored as `DataType` in the keyword NamedTuple,
# so the keyword wrapper is inlined here, where `T` is still a constant.
function _generate(
    rng::Random.Xoshiro,
    n::Int64,
    m::Union{Nothing,Int64},
    p::Union{Nothing,Float64},
    ::Type{T},
    latents::Int64,
) where {T<:CausalGraph}
    if m !== nothing && p === nothing
        return @inline CS.generate_graph(rng, n; m = m, class = T, latents = latents)
    elseif p !== nothing && m === nothing
        return @inline CS.generate_graph(rng, n; p = p, class = T, latents = latents)
    end
    throw(ArgumentError("Supply exactly one of m or p"))
end

uniform_dag(n::Int64, seed::Union{Nothing,Int64}) = _store(CS.uniform_dag(_rng(seed), n))

function graph_string(h::Int64)
    g = _graph(h)
    @on "print" g ALL sprint(show, g)
end

# --- Graph-level queries -----------------------------------------------------

function nodes(h::Int64)
    g = _graph(h)
    @on "nodes" g ALL CS.nodes(g)
end

# An n-by-4 character matrix: from, to, and the two endpoint marks. Built in
# place, since an edge list can run to hundreds of thousands of rows.
function edge_marks(h::Int64)
    g = _graph(h)
    es = @on "edges" g ALL g.edges
    n = length(es)
    out = _protect(_alloc_matrix(STRSXP, n, 4))
    marks = _protect(_alloc(STRSXP, 3))
    _set_string_elt(marks, 0, _mkchar("Tail"))
    _set_string_elt(marks, 1, _mkchar("Arrow"))
    _set_string_elt(marks, 2, _mkchar("Circle"))
    for (i, e) in enumerate(es)
        _set_string_elt(out, i - 1, _mkchar(e.src))
        _set_string_elt(out, n + i - 1, _mkchar(e.dst))
        _set_string_elt(out, 2n + i - 1, _string_elt(marks, Int(e.src_end)))
        _set_string_elt(out, 3n + i - 1, _string_elt(marks, Int(e.dst_end)))
    end
    _unprotect(2)
    return out
end

# A `data.frame` with columns `from`, `to` and `type` (the edge notation, e.g.
# "-->"), built in place.
function edges(h::Int64)
    g = _graph(h)
    es = @on "edges" g ALL g.edges
    n = length(es)
    from = _protect(_alloc(STRSXP, n))
    to = _protect(_alloc(STRSXP, n))
    type = _protect(_alloc(STRSXP, n))
    # Notation by (src mark, dst mark), indexed 3 * src + dst. Only the six
    # canonical mark pairs occur; the rest stay NA.
    notation = _protect(_alloc(STRSXP, 9))
    na = _r_global(:R_NaString)
    for k = 0:8
        _set_string_elt(notation, k, na)
    end
    _set_string_elt(notation, 1, _mkchar("-->"))
    _set_string_elt(notation, 0, _mkchar("---"))
    _set_string_elt(notation, 4, _mkchar("<->"))
    _set_string_elt(notation, 7, _mkchar("o->"))
    _set_string_elt(notation, 6, _mkchar("o--"))
    _set_string_elt(notation, 8, _mkchar("o-o"))
    for (i, e) in enumerate(es)
        _set_string_elt(from, i - 1, _mkchar(e.src))
        _set_string_elt(to, i - 1, _mkchar(e.dst))
        _set_string_elt(type, i - 1, _string_elt(notation, 3 * Int(e.src_end) + Int(e.dst_end)))
    end
    out = _data_frame(["from", "to", "type"], SEXP[from, to, type])
    _unprotect(4)
    return out
end

function topological_sort(h::Int64)
    g = _graph(h)
    @on "topological_sort" g (DAG,) CS.topological_sort(g)
end

function exogenous_nodes(h::Int64, undirected_as_parents::Bool)
    g = _graph(h)
    if g isa CS.AbstractPDAG
        @on "exogenous_nodes" g (PDAG, CPDAG, MPDAG) _set(
            CS.exogenous_nodes(g; undirected_as_parents = undirected_as_parents),
        )
    else
        @on "exogenous_nodes" g (DAG, UG, ADMG, AG, MAG) _set(CS.exogenous_nodes(g))
    end
end

function has_edge(h::Int64, x::Symbol, y::Symbol)
    g = _graph(h)
    @on "has_edge" g ALL CS.has_edge(g, x, y)
end

# --- Node-set queries --------------------------------------------------------

function parents(h::Int64, node::Symbol)
    g = _graph(h)
    @on "parents" g (DAG, PDAG, CPDAG, MPDAG, ADMG, AG, MAG, PAG, UNKNOWN) _set(
        CS.parents(g, node),
    )
end

function children(h::Int64, node::Symbol)
    g = _graph(h)
    @on "children" g (DAG, PDAG, CPDAG, MPDAG, ADMG, AG, MAG, PAG, UNKNOWN) _set(
        CS.children(g, node),
    )
end

function spouses(h::Int64, node::Symbol)
    g = _graph(h)
    @on "spouses" g (ADMG, AG, MAG, PAG) _set(CS.spouses(g, node))
end

function markov_blanket(h::Int64, node::Symbol)
    g = _graph(h)
    @on "markov_blanket" g (DAG, PDAG, CPDAG, MPDAG, ADMG, AG, MAG, PAG) _set(
        CS.markov_blanket(g, node),
    )
end

function neighbors(h::Int64, node::Symbol, mode::Symbol)
    g = _graph(h)
    @on "neighbors" g ALL _set(CS.neighbors(g, node; mode = mode))
end

function ancestors(h::Int64, node::Symbol, open::Bool)
    g = _graph(h)
    @on "ancestors" g (DAG, PDAG, CPDAG, MPDAG, ADMG, AG, MAG) _set(
        CS.ancestors(g, node; open = open),
    )
end

function descendants(h::Int64, node::Symbol, open::Bool)
    g = _graph(h)
    @on "descendants" g (DAG, PDAG, CPDAG, MPDAG, ADMG, AG, MAG) _set(
        CS.descendants(g, node; open = open),
    )
end

function anteriors(h::Int64, node::Symbol, open::Bool)
    g = _graph(h)
    @on "anteriors" g (DAG, PDAG, CPDAG, MPDAG, ADMG, AG, MAG) _set(
        CS.anteriors(g, node; open = open),
    )
end

function posteriors(h::Int64, node::Symbol, open::Bool)
    g = _graph(h)
    @on "posteriors" g (DAG, PDAG, CPDAG, MPDAG, ADMG, AG, MAG) _set(
        CS.posteriors(g, node; open = open),
    )
end

function possible_ancestors(h::Int64, node::Symbol, open::Bool)
    g = _graph(h)
    @on "possible_ancestors" g (PDAG, CPDAG, MPDAG, PAG) _set(
        CS.possible_ancestors(g, node; open = open),
    )
end

function possible_descendants(h::Int64, node::Symbol, open::Bool)
    g = _graph(h)
    @on "possible_descendants" g (PDAG, CPDAG, MPDAG, PAG) _set(
        CS.possible_descendants(g, node; open = open),
    )
end

# --- Predicates --------------------------------------------------------------

for f in (
    :is_dag, :is_pdag, :is_cpdag, :is_mpdag, :is_ug, :is_admg, :is_ag, :is_mag,
    :is_pag, :is_simple, :is_acyclic,
)
    @eval function $f(h::Int64)
        g = _graph(h)
        @on $(String(f)) g ALL CS.$f(g)
    end
end

is_dag_type(h::Int64) = _graph(h) isa DAG

function markov_equivalent(h1::Int64, h2::Int64)
    g1 = _graph(h1)
    g2 = _graph(h2)
    g1 isa DAG && g2 isa DAG && return CS.markov_equivalent(g1, g2)
    g1 isa MAG && g2 isa MAG && return CS.markov_equivalent(g1, g2)
    throw(ArgumentError("markov_equivalent() needs two DAGs or two MAGs"))
end

# --- Separation --------------------------------------------------------------

function d_separated(h::Int64, x::SymSet, y::SymSet, z::SymSet)
    g = _graph(h)
    @on "d_separated" g (DAG, PDAG, CPDAG, MPDAG) CS.d_separated(g, x, y, z)
end

function m_separated(h::Int64, x::SymSet, y::SymSet, z::SymSet)
    g = _graph(h)
    @on "m_separated" g (DAG, ADMG, AG, MAG, PAG) CS.m_separated(g, x, y, z)
end

function minimal_separator(
    h::Int64, x::SymSet, y::SymSet, include::SymSet, restrict::Union{Nothing,SymSet},
)
    g = _graph(h)
    @on "minimal_separator" g (DAG, PDAG, CPDAG, MPDAG, ADMG, AG, MAG, PAG) _opt(
        CS.minimal_separator(g, x, y; include = include, restrict = restrict),
    )
end

function possible_d_sep(h::Int64, x::Symbol, y::SymSet)
    g = _graph(h)
    @on "possible_d_sep" g (AG, MAG) _set(CS.possible_d_sep(g, x, y))
end

# --- Identification ----------------------------------------------------------

function adjustment_set(h::Int64, x::SymSet, y::SymSet, type::Symbol)
    g = _graph(h)
    if g isa DAG || g isa CS.AbstractPDAG
        @on "adjustment_set" g (DAG, PDAG, CPDAG, MPDAG) _opt(
            CS.adjustment_set(g, x, y; type = type),
        )
    else
        @on "adjustment_set" g (ADMG, AG, MAG, PAG) _opt(CS.adjustment_set(g, x, y))
    end
end

function backdoor_set(h::Int64, x::Symbol, y::Symbol)
    g = _graph(h)
    @on "backdoor_set" g (DAG, CPDAG, ADMG, MAG, PAG) _opt(CS.backdoor_set(g, x, y))
end

function frontdoor_set(
    h::Int64, x::SymSet, y::SymSet, include::SymSet, restrict::Union{Nothing,SymSet},
)
    g = _graph(h)
    @on "frontdoor_set" g (DAG, ADMG) _opt(
        CS.frontdoor_set(g, x, y; include = include, restrict = restrict),
    )
end

function all_frontdoor_sets(
    h::Int64, x::SymSet, y::SymSet, include::SymSet, restrict::Union{Nothing,SymSet},
)
    g = _graph(h)
    @on "all_frontdoor_sets" g (DAG, ADMG) _sets(
        CS.all_frontdoor_sets(g, x, y; include = include, restrict = restrict),
    )
end

function is_valid_backdoor(h::Int64, x::SymSet, y::SymSet, z::SymSet)
    g = _graph(h)
    @on "is_valid_backdoor" g (DAG, ADMG) CS.is_valid_backdoor(g, x, y, z)
end

function all_backdoor_sets(h::Int64, x::SymSet, y::SymSet, minimal::Bool, max_size::Int64)
    g = _graph(h)
    @on "all_backdoor_sets" g (DAG, ADMG) _sets(
        CS.all_backdoor_sets(g, x, y; minimal = minimal, max_size = max_size),
    )
end

function is_valid_adjustment(h::Int64, x::SymSet, y::SymSet, z::SymSet)
    g = _graph(h)
    @on "is_valid_adjustment" g (DAG, PDAG, CPDAG, MPDAG, ADMG, AG, MAG, PAG) CS.is_valid_adjustment(
        g, x, y, z,
    )
end

function all_adjustment_sets(
    h::Int64, x::SymSet, y::SymSet, minimal::Bool, max_size::Int64,
)
    g = _graph(h)
    @on "all_adjustment_sets" g (DAG, PDAG, CPDAG, MPDAG, ADMG, AG, MAG, PAG) _sets(
        CS.all_adjustment_sets(g, x, y; minimal = minimal, max_size = max_size),
    )
end

function is_valid_frontdoor(h::Int64, x::SymSet, y::SymSet, z::SymSet)
    g = _graph(h)
    @on "is_valid_frontdoor" g (DAG, ADMG) CS.is_valid_frontdoor(g, x, y, z)
end

function is_valid_iv(h::Int64, x::Symbol, y::SymSet, z::SymSet)
    g = _graph(h)
    @on "is_valid_iv" g (DAG, ADMG) CS.is_valid_iv(g, x, y, z)
end

function all_iv_sets(h::Int64, x::Symbol, y::SymSet, minimal::Bool, max_size::Int64)
    g = _graph(h)
    @on "all_iv_sets" g (DAG, ADMG) _sets(
        CS.all_iv_sets(g, x, y; minimal = minimal, max_size = max_size),
    )
end

function id(h::Int64, x::SymSet, y::SymSet)
    g = _graph(h)
    r = @on "id" g (DAG, ADMG) CS.id(g, x, y)
    return r === nothing ? nothing : string(r)
end

function idc(h::Int64, x::SymSet, y::SymSet, given::SymSet)
    g = _graph(h)
    r = @on "idc" g (DAG, ADMG) CS.idc(g, x, y; given = given)
    return r === nothing ? nothing : string(r)
end

function possible_parent_sets(h::Int64, x::Symbol)
    g = _graph(h)
    @on "possible_parent_sets" g (PDAG, CPDAG, MPDAG) _sets(CS.possible_parent_sets(g, x))
end

function possible_joint_parent_sets(h::Int64, xs::SymSet)
    g = _graph(h)
    @on "possible_joint_parent_sets" g (PDAG, CPDAG, MPDAG) Vector{SymSet}[
        _sets(group) for group in CS.possible_joint_parent_sets(g, xs)
    ]
end

function possible_optimal_adjustment_sets(h::Int64, x::Symbol, y::Symbol)
    g = _graph(h)
    @on "possible_optimal_adjustment_sets" g (PDAG, CPDAG, MPDAG) _opt_sets(
        CS.possible_optimal_adjustment_sets(g, x, y),
    )
end

function possible_local_structures(h::Int64, x::Symbol)
    g = _graph(h)
    @on "possible_local_structures" g (PAG,) _sets(CS.possible_local_structures(g, x))
end

function pagcauses(h::Int64, x::Symbol, y::Symbol)
    g = _graph(h)
    @on "pagcauses" g (PAG,) _sets(CS.pagcauses(g, x, y))
end

# --- Equivalence classes -----------------------------------------------------

function count_dags(h::Int64)
    g = _graph(h)
    n = @on "count_dags" g (PDAG, CPDAG, MPDAG) CS.count_dags(g)
    return typemin(Int32) < n <= typemax(Int32) ? Int32(n) : Float64(n)
end

function enumerate_dags(h::Int64)
    g = _graph(h)
    @on "enumerate_dags" g (PDAG, CPDAG, MPDAG) Int64[_store(d) for d in CS.enumerate_dags(g)]
end

function enumerate_mags(h::Int64)
    g = _graph(h)
    @on "enumerate_mags" g (PAG,) Int64[_store(d) for d in CS.enumerate_mags(g)]
end

# --- Transformations ---------------------------------------------------------

for (f, classes) in (
    (:skeleton, :(DAG, PDAG, CPDAG, MPDAG)),
    (:moralize, :(DAG, PDAG, CPDAG, MPDAG)),
    (:dag_to_cpdag, :(DAG,)),
    (:dag_from_pdag, :(PDAG, CPDAG, MPDAG)),
    (:dag_to_mpdag, :(DAG,)),
    (:ag_to_mag, :(AG,)),
    (:mag_to_pag, :(MAG,)),
    (:mag_from_pag, :(PAG,)),
)
    @eval function $f(h::Int64)
        g = _graph(h)
        @on $(String(f)) g $classes _store(CS.$f(g))
    end
end

function meek_closure(h::Int64, check_cycles::Bool, r4::Bool)
    g = _graph(h)
    @on "meek_closure" g (PDAG, CPDAG, MPDAG) _store(
        CS.meek_closure(g; check_cycles = check_cycles, r4 = r4),
    )
end

function subgraph(h::Int64, nodes::SymSet)
    g = _graph(h)
    @on "subgraph" g ALL _store(CS.subgraph(g, nodes))
end

function latent_project(h::Int64, latents::SymSet)
    g = _graph(h)
    @on "latent_project" g (DAG,) _store(CS.latent_project(g, latents))
end

function exogenize(h::Int64, nodes::SymSet)
    g = _graph(h)
    @on "exogenize" g (DAG,) _store(CS.exogenize(g, nodes))
end

function normalize_latent_structure(h::Int64, latents::SymSet)
    g = _graph(h)
    @on "normalize_latent_structure" g (DAG,) _store(
        CS.normalize_latent_structure(g, latents),
    )
end

function condition_marginalize(h::Int64, given::SymSet, index::SymSet)
    g = _graph(h)
    @on "condition_marginalize" g (DAG, ADMG, AG, MAG) _store(
        CS.condition_marginalize(g; given = given, index = index),
    )
end

function maximal_local_mag(h::Int64, x::Symbol, c::SymSet)
    g = _graph(h)
    @on "maximal_local_mag" g (PAG,) _store(CS.maximal_local_mag(g, x, c))
end

function reclass(h::Int64, class::String)
    g = _graph(h)
    @on "reclass" g ALL @class class T ALL _store(CS.reclass(g, T))
end

# --- Mutation ----------------------------------------------------------------

# `f(g, items...)` one item at a time: splatting a vector into varargs is a
# dynamic `_apply_iterate` call that `--trim` cannot resolve.
function _fold(f::F, g::G, items::Vector) where {F,G<:CausalGraph}
    for item in items
        g = f(g, item)::G
    end
    return g
end

function add_edges(h::Int64, spec::String)
    g = _graph(h)
    es = _spec_edges(spec)
    @on "add_edges" g ALL _store(_fold(CS.add_edges, g, es))
end

function remove_edges(h::Int64, spec::String)
    g = _graph(h)
    es = _spec_edges(spec)
    @on "remove_edges" g ALL _store(_fold(CS.remove_edges, g, es))
end

function add_nodes(h::Int64, nodes::SymSet)
    g = _graph(h)
    @on "add_nodes" g ALL _store(_fold(CS.add_nodes, g, nodes))
end

function remove_nodes(h::Int64, nodes::SymSet)
    g = _graph(h)
    @on "remove_nodes" g ALL _store(_fold(CS.remove_nodes, g, nodes))
end

# --- Data generation ---------------------------------------------------------

# An n-by-p numeric matrix, one column per node in `nodes()` order, filled in
# place.
function simulate_data(
    h::Int64,
    n::Int64,
    seed::Union{Nothing,Int64},
    standardize::Bool,
    coef_range::Vector{Float64},
    error_sd::Float64,
)
    length(coef_range) == 2 || throw(ArgumentError("coef_range must have length 2"))
    coef_lo, coef_hi = coef_range[1], coef_range[2]
    g = _graph(h)
    g isa DAG || _unsupported("simulate_data", _class_name(g))
    d = CS.simulate_data(
        _rng(seed), g::DAG;
        samples = n, standardize = standardize,
        coef_range = (coef_lo, coef_hi), error_sd = error_sd,
    )
    ns = (g::DAG).backend.nodes
    out = _protect(_alloc_matrix(REALSXP, n, length(ns)))
    p = _real_ptr(out)
    for (j, nd) in enumerate(ns)
        col = d[nd]
        GC.@preserve col unsafe_copyto!(p + (j - 1) * n * sizeof(Float64), pointer(col), n)
    end
    _unprotect(1)
    return out
end

# --- R entrypoints -----------------------------------------------------------

@rcall graph_count()::Int64
@rcall cgraph(spec::String, class::String)::GraphHandle
@rcall generate_graph(
    n::Int64, m::SEXP, p::SEXP, class::String, latents::Int64, seed::SEXP,
)::GraphHandle
@rcall uniform_dag(n::Int64, seed::Union{Nothing,Int64})::GraphHandle
@rcall graph_string(h::GraphHandle)::String

@rcall nodes(h::GraphHandle)::SymSet
@rcall edge_marks(h::GraphHandle)::SEXP
@rcall edges(h::GraphHandle)::SEXP
@rcall topological_sort(h::GraphHandle)::SymSet
@rcall exogenous_nodes(h::GraphHandle, undirected_as_parents::Bool)::SymSet
@rcall has_edge(h::GraphHandle, x::Symbol, y::Symbol)::Bool

@rcall parents(h::GraphHandle, node::Symbol)::SymSet
@rcall children(h::GraphHandle, node::Symbol)::SymSet
@rcall spouses(h::GraphHandle, node::Symbol)::SymSet
@rcall markov_blanket(h::GraphHandle, node::Symbol)::SymSet
@rcall neighbors(h::GraphHandle, node::Symbol, mode::Symbol)::SymSet
@rcall ancestors(h::GraphHandle, node::Symbol, open::Bool)::SymSet
@rcall descendants(h::GraphHandle, node::Symbol, open::Bool)::SymSet
@rcall anteriors(h::GraphHandle, node::Symbol, open::Bool)::SymSet
@rcall posteriors(h::GraphHandle, node::Symbol, open::Bool)::SymSet
@rcall possible_ancestors(h::GraphHandle, node::Symbol, open::Bool)::SymSet
@rcall possible_descendants(h::GraphHandle, node::Symbol, open::Bool)::SymSet

@rcall is_dag(h::GraphHandle)::Bool
@rcall is_pdag(h::GraphHandle)::Bool
@rcall is_cpdag(h::GraphHandle)::Bool
@rcall is_mpdag(h::GraphHandle)::Bool
@rcall is_ug(h::GraphHandle)::Bool
@rcall is_admg(h::GraphHandle)::Bool
@rcall is_ag(h::GraphHandle)::Bool
@rcall is_mag(h::GraphHandle)::Bool
@rcall is_pag(h::GraphHandle)::Bool
@rcall is_simple(h::GraphHandle)::Bool
@rcall is_acyclic(h::GraphHandle)::Bool
@rcall is_dag_type(h::GraphHandle)::Bool
@rcall markov_equivalent(h1::GraphHandle, h2::GraphHandle)::Bool

@rcall d_separated(h::GraphHandle, x::SymSet, y::SymSet, z::SymSet)::Bool
@rcall m_separated(h::GraphHandle, x::SymSet, y::SymSet, z::SymSet)::Bool
@rcall minimal_separator(
    h::GraphHandle, x::SymSet, y::SymSet, include::SymSet, restrict::Union{Nothing,SymSet},
)::Union{Nothing,SymSet}
@rcall possible_d_sep(h::GraphHandle, x::Symbol, y::SymSet)::SymSet

@rcall adjustment_set(h::GraphHandle, x::SymSet, y::SymSet, type::Symbol)::Union{Nothing,SymSet}
@rcall backdoor_set(h::GraphHandle, x::Symbol, y::Symbol)::Union{Nothing,SymSet}
@rcall frontdoor_set(
    h::GraphHandle, x::SymSet, y::SymSet, include::SymSet, restrict::Union{Nothing,SymSet},
)::Union{Nothing,SymSet}
@rcall all_frontdoor_sets(
    h::GraphHandle, x::SymSet, y::SymSet, include::SymSet, restrict::Union{Nothing,SymSet},
)::Vector{SymSet}
@rcall is_valid_backdoor(h::GraphHandle, x::SymSet, y::SymSet, z::SymSet)::Bool
@rcall all_backdoor_sets(
    h::GraphHandle, x::SymSet, y::SymSet, minimal::Bool, max_size::Int64,
)::Vector{SymSet}
@rcall is_valid_adjustment(h::GraphHandle, x::SymSet, y::SymSet, z::SymSet)::Bool
@rcall all_adjustment_sets(
    h::GraphHandle, x::SymSet, y::SymSet, minimal::Bool, max_size::Int64,
)::Vector{SymSet}
@rcall is_valid_frontdoor(h::GraphHandle, x::SymSet, y::SymSet, z::SymSet)::Bool
@rcall is_valid_iv(h::GraphHandle, x::Symbol, y::SymSet, z::SymSet)::Bool
@rcall all_iv_sets(
    h::GraphHandle, x::Symbol, y::SymSet, minimal::Bool, max_size::Int64,
)::Vector{SymSet}
@rcall id(h::GraphHandle, x::SymSet, y::SymSet)::Union{Nothing,String}
@rcall idc(h::GraphHandle, x::SymSet, y::SymSet, given::SymSet)::Union{Nothing,String}
@rcall possible_parent_sets(h::GraphHandle, x::Symbol)::Vector{SymSet}
@rcall possible_joint_parent_sets(h::GraphHandle, xs::SymSet)::Vector{Vector{SymSet}}
@rcall possible_optimal_adjustment_sets(
    h::GraphHandle, x::Symbol, y::Symbol,
)::Vector{Union{Nothing,SymSet}}
@rcall possible_local_structures(h::GraphHandle, x::Symbol)::Vector{SymSet}
@rcall pagcauses(h::GraphHandle, x::Symbol, y::Symbol)::Vector{SymSet}

@rcall count_dags(h::GraphHandle)::Union{Int32,Float64}
@rcall enumerate_dags(h::GraphHandle)::Vector{GraphHandle}
@rcall enumerate_mags(h::GraphHandle)::Vector{GraphHandle}

@rcall skeleton(h::GraphHandle)::GraphHandle
@rcall moralize(h::GraphHandle)::GraphHandle
@rcall dag_to_cpdag(h::GraphHandle)::GraphHandle
@rcall dag_from_pdag(h::GraphHandle)::GraphHandle
@rcall dag_to_mpdag(h::GraphHandle)::GraphHandle
@rcall ag_to_mag(h::GraphHandle)::GraphHandle
@rcall mag_to_pag(h::GraphHandle)::GraphHandle
@rcall mag_from_pag(h::GraphHandle)::GraphHandle
@rcall meek_closure(h::GraphHandle, check_cycles::Bool, r4::Bool)::GraphHandle
@rcall subgraph(h::GraphHandle, nodes::SymSet)::GraphHandle
@rcall latent_project(h::GraphHandle, latents::SymSet)::GraphHandle
@rcall exogenize(h::GraphHandle, nodes::SymSet)::GraphHandle
@rcall normalize_latent_structure(h::GraphHandle, latents::SymSet)::GraphHandle
@rcall condition_marginalize(h::GraphHandle, given::SymSet, index::SymSet)::GraphHandle
@rcall maximal_local_mag(h::GraphHandle, x::Symbol, c::SymSet)::GraphHandle
@rcall reclass(h::GraphHandle, class::String)::GraphHandle

@rcall add_edges(h::GraphHandle, spec::String)::GraphHandle
@rcall remove_edges(h::GraphHandle, spec::String)::GraphHandle
@rcall add_nodes(h::GraphHandle, nodes::SymSet)::GraphHandle
@rcall remove_nodes(h::GraphHandle, nodes::SymSet)::GraphHandle

@rcall simulate_data(
    h::GraphHandle, n::Int64, seed::Union{Nothing,Int64}, standardize::Bool,
    coef_range::Vector{Float64}, error_sd::Float64,
)::SEXP

end # module
