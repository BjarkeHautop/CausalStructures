"""
    csjl

The binding layer that exposes CausalStructures.jl to R. It is compiled with
`juliac --trim=safe` into a shared library that R loads with `dyn.load` and
calls with `.Call`: each entrypoint takes and returns R objects (`SEXP`s) and
converts them itself through R's C API, so there is no marshalling layer in
between.

Entrypoints are declared with JLBind's `@rcall`, and jlbind compiles this
package into one library with the binding packages of every other installed R
package that uses it. A graph cannot cross into R as a value, so R holds it by
reference (`RRef{CausalGraph}`, an external pointer of class `cgraph`). Every
entrypoint branches on the concrete graph class before calling into
CausalStructures, so that `--trim` sees only statically resolved calls.
"""
module csjl

import CausalStructures as CS
using CausalStructures:
    CausalGraph, CausalEdge, DAG, UG, PDAG, CPDAG, MPDAG, ADMG, AG, MAG, PAG, UNKNOWN
import NetworkLayout
using StableRNGs: StableRNG
import Sugiyama

using JLBind
using JLBind:
    @R, @r_global, protect, unprotect, alloc, string_elt, set_string_elt,
    set_vector_elt, real_ptr, mkchar, data_frame, STRSXP, REALSXP, VECSXP

# An nrow-by-ncol R matrix of type `t`, which JLBind has no allocator for.
_alloc_matrix(t::Cint, nrow::Integer, ncol::Integer) =
    ccall(@R(Rf_allocMatrix), SEXP, (Cint, Cint, Cint), t, nrow, ncol)

# A graph in R: an external pointer of class `cgraph`. Functions take it as
# `@nospecialize(g::CausalGraph)`: a call with the abstract type would stay
# dynamic otherwise, which `--trim` rejects; `@on` narrows it inside.
const GraphRef = RRef{CausalGraph}
JLBind.r_class(::Type{CausalGraph}) = "cgraph"

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
function _class_name(@nospecialize(g::CausalGraph))::String
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

# StableRNG streams are the same on every Julia version, so a seed gives the same
# result whichever Julia built the library.
_rng(seed::Union{Int64,Nothing}) =
    StableRNG(seed === nothing ? rand(UInt64) : seed)

function _spec_edges(spec::String)
    es = CausalEdge[]
    for item in CS._parse_graph_string(spec)
        item isa CausalEdge && push!(es, item)
    end
    return es
end

# --- Construction and lifetime ----------------------------------------------

# The number of graphs R holds (every Julia object R holds, if other packages
# using jlbind hold some too).
jl_graph_count() = JLBind.object_count()

jl_cgraph(spec::String, class::String) = @class class T ALL T(spec)

# `m`, `p` and `seed` arrive unconverted: three optional arguments in one call
# exceed what the compiler union-splits.
function jl_generate_graph(
    n::Int64, m::SEXP, p::SEXP, class::String, latents::Int64, seed::SEXP,
)
    rng = _rng(from_sexp(Union{Nothing,Int64}, seed))
    mm = from_sexp(Union{Nothing,Int64}, m)
    pp = from_sexp(Union{Nothing,Float64}, p)
    @class class T (DAG, CPDAG, ADMG, MAG, PAG) _generate(rng, n, mm, pp, T, latents)
end

# A type passed as a keyword is stored as `DataType` in the keyword NamedTuple,
# so the keyword wrapper is inlined here, where `T` is still a constant.
function _generate(
    rng::StableRNG,
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

jl_uniform_dag(n::Int64, seed::Union{Nothing,Int64}) = CS.uniform_dag(_rng(seed), n)

function jl_graph_string(@nospecialize(g::CausalGraph))
    @on "print" g ALL sprint(show, g)
end

# --- Graph-level queries -----------------------------------------------------

function jl_nodes(@nospecialize(g::CausalGraph))
    @on "nodes" g ALL CS.nodes(g)
end

# An n-by-4 character matrix: from, to, and the two endpoint marks. Built in
# place, since an edge list can run to hundreds of thousands of rows.
function jl_edge_marks(@nospecialize(g::CausalGraph))
    es = @on "edges" g ALL g.edges
    n = length(es)
    out = protect(_alloc_matrix(STRSXP, n, 4))
    marks = protect(alloc(STRSXP, 3))
    set_string_elt(marks, 0, mkchar("Tail"))
    set_string_elt(marks, 1, mkchar("Arrow"))
    set_string_elt(marks, 2, mkchar("Circle"))
    for (i, e) in enumerate(es)
        set_string_elt(out, i - 1, mkchar(e.src))
        set_string_elt(out, n + i - 1, mkchar(e.dst))
        set_string_elt(out, 2n + i - 1, string_elt(marks, Int(e.src_end)))
        set_string_elt(out, 3n + i - 1, string_elt(marks, Int(e.dst_end)))
    end
    unprotect(2)
    return out
end

# A `data.frame` with columns `from`, `to` and `type` (the edge notation, e.g.
# "-->"), built in place.
function jl_edges(@nospecialize(g::CausalGraph))
    es = @on "edges" g ALL g.edges
    n = length(es)
    from = protect(alloc(STRSXP, n))
    to = protect(alloc(STRSXP, n))
    type = protect(alloc(STRSXP, n))
    # Notation by (src mark, dst mark), indexed 3 * src + dst. Only the six
    # canonical mark pairs occur; the rest stay NA.
    notation = protect(alloc(STRSXP, 9))
    na = @r_global(R_NaString)
    for k = 0:8
        set_string_elt(notation, k, na)
    end
    set_string_elt(notation, 1, mkchar("-->"))
    set_string_elt(notation, 0, mkchar("---"))
    set_string_elt(notation, 4, mkchar("<->"))
    set_string_elt(notation, 7, mkchar("o->"))
    set_string_elt(notation, 6, mkchar("o--"))
    set_string_elt(notation, 8, mkchar("o-o"))
    for (i, e) in enumerate(es)
        set_string_elt(from, i - 1, mkchar(e.src))
        set_string_elt(to, i - 1, mkchar(e.dst))
        set_string_elt(type, i - 1, string_elt(notation, 3 * Int(e.src_end) + Int(e.dst_end)))
    end
    out = data_frame(["from", "to", "type"], SEXP[from, to, type])
    unprotect(4)
    return out
end

function jl_topological_sort(@nospecialize(g::CausalGraph))
    @on "topological_sort" g (DAG,) CS.topological_sort(g)
end

function jl_exogenous_nodes(@nospecialize(g::CausalGraph), undirected_as_parents::Bool)
    if g isa CS.AbstractPDAG
        @on "exogenous_nodes" g (PDAG, CPDAG, MPDAG) _set(
            CS.exogenous_nodes(g; undirected_as_parents = undirected_as_parents),
        )
    else
        @on "exogenous_nodes" g (DAG, UG, ADMG, AG, MAG) _set(CS.exogenous_nodes(g))
    end
end

function jl_has_edge(@nospecialize(g::CausalGraph), x::Symbol, y::Symbol)
    @on "has_edge" g ALL CS.has_edge(g, x, y)
end

# --- Node-set queries --------------------------------------------------------

function jl_parents(@nospecialize(g::CausalGraph), node::Symbol)
    @on "parents" g (DAG, PDAG, CPDAG, MPDAG, ADMG, AG, MAG, PAG, UNKNOWN) _set(
        CS.parents(g, node),
    )
end

function jl_children(@nospecialize(g::CausalGraph), node::Symbol)
    @on "children" g (DAG, PDAG, CPDAG, MPDAG, ADMG, AG, MAG, PAG, UNKNOWN) _set(
        CS.children(g, node),
    )
end

function jl_spouses(@nospecialize(g::CausalGraph), node::Symbol)
    @on "spouses" g (ADMG, AG, MAG, PAG) _set(CS.spouses(g, node))
end

function jl_markov_blanket(@nospecialize(g::CausalGraph), node::Symbol)
    @on "markov_blanket" g (DAG, PDAG, CPDAG, MPDAG, ADMG, AG, MAG, PAG) _set(
        CS.markov_blanket(g, node),
    )
end

function jl_neighbors(@nospecialize(g::CausalGraph), node::Symbol, mode::Symbol)
    @on "neighbors" g ALL _set(CS.neighbors(g, node; mode = mode))
end

function jl_ancestors(@nospecialize(g::CausalGraph), node::Symbol, open::Bool)
    @on "ancestors" g (DAG, PDAG, CPDAG, MPDAG, ADMG, AG, MAG) _set(
        CS.ancestors(g, node; open = open),
    )
end

function jl_descendants(@nospecialize(g::CausalGraph), node::Symbol, open::Bool)
    @on "descendants" g (DAG, PDAG, CPDAG, MPDAG, ADMG, AG, MAG) _set(
        CS.descendants(g, node; open = open),
    )
end

function jl_anteriors(@nospecialize(g::CausalGraph), node::Symbol, open::Bool)
    @on "anteriors" g (DAG, PDAG, CPDAG, MPDAG, ADMG, AG, MAG) _set(
        CS.anteriors(g, node; open = open),
    )
end

function jl_posteriors(@nospecialize(g::CausalGraph), node::Symbol, open::Bool)
    @on "posteriors" g (DAG, PDAG, CPDAG, MPDAG, ADMG, AG, MAG) _set(
        CS.posteriors(g, node; open = open),
    )
end

function jl_possible_ancestors(@nospecialize(g::CausalGraph), node::Symbol, open::Bool)
    @on "possible_ancestors" g (PDAG, CPDAG, MPDAG, PAG) _set(
        CS.possible_ancestors(g, node; open = open),
    )
end

function jl_possible_descendants(@nospecialize(g::CausalGraph), node::Symbol, open::Bool)
    @on "possible_descendants" g (PDAG, CPDAG, MPDAG, PAG) _set(
        CS.possible_descendants(g, node; open = open),
    )
end

function jl_districts(@nospecialize(g::CausalGraph))
    _sets(sort!([_set(d) for d in @on "districts" g (ADMG, AG, MAG) CS.districts(g)]))
end

# --- Predicates --------------------------------------------------------------

for f in (
    :is_dag, :is_pdag, :is_cpdag, :is_mpdag, :is_ug, :is_admg, :is_ag, :is_mag,
    :is_pag, :is_simple, :is_acyclic,
)
    @eval function $(Symbol(:jl_, f))(@nospecialize(g::CausalGraph))
        @on $(String(f)) g ALL CS.$f(g)
    end
end

jl_is_dag_type(@nospecialize(g::CausalGraph)) = g isa DAG

# Structural equality: same class, nodes and edges. `g2` is narrowed to the
# class of `g1`, so only like pairs are compared.
_same(g1::T, @nospecialize(g2::CausalGraph)) where {T<:CausalGraph} = g2 isa T && g1 == g2::T

function jl_graph_equal(@nospecialize(g1::CausalGraph), @nospecialize(g2::CausalGraph))
    @on "==" g1 ALL _same(g1, g2)
end

function jl_markov_equivalent(@nospecialize(g1::CausalGraph), @nospecialize(g2::CausalGraph))
    g1 isa DAG && g2 isa DAG && return CS.markov_equivalent(g1, g2)
    g1 isa MAG && g2 isa MAG && return CS.markov_equivalent(g1, g2)
    throw(ArgumentError("markov_equivalent() needs two DAGs or two MAGs"))
end

# --- Separation --------------------------------------------------------------

function jl_d_separated(@nospecialize(g::CausalGraph), x::SymSet, y::SymSet, z::SymSet)
    @on "d_separated" g (DAG, PDAG, CPDAG, MPDAG) CS.d_separated(g, x, y, z)
end

function jl_m_separated(@nospecialize(g::CausalGraph), x::SymSet, y::SymSet, z::SymSet)
    @on "m_separated" g (DAG, ADMG, AG, MAG, PAG) CS.m_separated(g, x, y, z)
end

function jl_minimal_separator(
    @nospecialize(g::CausalGraph), x::SymSet, y::SymSet, include::SymSet, restrict::Union{Nothing,SymSet},
)
    @on "minimal_separator" g (DAG, PDAG, CPDAG, MPDAG, ADMG, AG, MAG, PAG) _opt(
        CS.minimal_separator(g, x, y; include = include, restrict = restrict),
    )
end

function jl_possible_d_sep(@nospecialize(g::CausalGraph), x::Symbol, y::SymSet)
    @on "possible_d_sep" g (AG, MAG) _set(CS.possible_d_sep(g, x, y))
end

# --- Identification ----------------------------------------------------------

# `include` and `restrict` are not keywords of every method, so the classes
# without them reject them here.
function _unconstrained(fname::String, class::String, include::SymSet, restrict)
    isempty(include) && restrict === nothing && return nothing
    throw(ArgumentError(fname * "() takes no include or restrict for a " * class))
end

function jl_adjustment_set(
    @nospecialize(g::CausalGraph), x::SymSet, y::SymSet, type::Symbol,
    include::SymSet, restrict::Union{Nothing,SymSet},
)
    if g isa DAG
        _opt(CS.adjustment_set(g::DAG, x, y; type = type, include = include, restrict = restrict))
    elseif g isa CS.AbstractPDAG
        _unconstrained("adjustment_set", _class_name(g), include, restrict)
        @on "adjustment_set" g (PDAG, CPDAG, MPDAG) _opt(
            CS.adjustment_set(g, x, y; type = type),
        )
    else
        @on "adjustment_set" g (ADMG, AG, MAG, PAG) _opt(
            CS.adjustment_set(g, x, y; include = include, restrict = restrict),
        )
    end
end

function jl_backdoor_set(
    @nospecialize(g::CausalGraph), x::Symbol, y::Symbol,
    include::SymSet, restrict::Union{Nothing,SymSet},
)
    if g isa DAG || g isa ADMG
        @on "backdoor_set" g (DAG, ADMG) _opt(
            CS.backdoor_set(g, x, y; include = include, restrict = restrict),
        )
    else
        _unconstrained("backdoor_set", _class_name(g), include, restrict)
        @on "backdoor_set" g (CPDAG, MAG, PAG) _opt(CS.backdoor_set(g, x, y))
    end
end

function jl_frontdoor_set(
    @nospecialize(g::CausalGraph), x::SymSet, y::SymSet, include::SymSet, restrict::Union{Nothing,SymSet},
)
    @on "frontdoor_set" g (DAG, ADMG) _opt(
        CS.frontdoor_set(g, x, y; include = include, restrict = restrict),
    )
end

function jl_all_frontdoor_sets(
    @nospecialize(g::CausalGraph), x::SymSet, y::SymSet, include::SymSet, restrict::Union{Nothing,SymSet},
)
    @on "all_frontdoor_sets" g (DAG, ADMG) _sets(
        CS.all_frontdoor_sets(g, x, y; include = include, restrict = restrict),
    )
end

function jl_is_valid_backdoor(@nospecialize(g::CausalGraph), x::SymSet, y::SymSet, z::SymSet)
    @on "is_valid_backdoor" g (DAG, ADMG) CS.is_valid_backdoor(g, x, y, z)
end

function jl_all_backdoor_sets(
    @nospecialize(g::CausalGraph), x::SymSet, y::SymSet, minimal::Bool, max_size::Int64,
    include::SymSet, restrict::Union{Nothing,SymSet},
)
    @on "all_backdoor_sets" g (DAG, ADMG) _sets(
        CS.all_backdoor_sets(
            g, x, y;
            minimal = minimal, max_size = max_size, include = include, restrict = restrict,
        ),
    )
end

function jl_is_valid_adjustment(@nospecialize(g::CausalGraph), x::SymSet, y::SymSet, z::SymSet)
    @on "is_valid_adjustment" g (DAG, PDAG, CPDAG, MPDAG, ADMG, AG, MAG, PAG) CS.is_valid_adjustment(
        g, x, y, z,
    )
end

function jl_all_adjustment_sets(
    @nospecialize(g::CausalGraph), x::SymSet, y::SymSet, minimal::Bool, max_size::Int64,
    include::SymSet, restrict::Union{Nothing,SymSet},
)
    @on "all_adjustment_sets" g (DAG, PDAG, CPDAG, MPDAG, ADMG, AG, MAG, PAG) _sets(
        CS.all_adjustment_sets(
            g, x, y;
            minimal = minimal, max_size = max_size, include = include, restrict = restrict,
        ),
    )
end

function jl_is_valid_frontdoor(@nospecialize(g::CausalGraph), x::SymSet, y::SymSet, z::SymSet)
    @on "is_valid_frontdoor" g (DAG, ADMG) CS.is_valid_frontdoor(g, x, y, z)
end

function jl_is_valid_iv(
    @nospecialize(g::CausalGraph), x::Symbol, y::SymSet, z::SymSet, given::SymSet,
)
    @on "is_valid_iv" g (DAG, ADMG) CS.is_valid_iv(g, x, y, z, given)
end

function jl_all_iv_sets(
    @nospecialize(g::CausalGraph), x::Symbol, y::SymSet, given::SymSet, minimal::Bool,
    max_size::Int64, include::SymSet, restrict::Union{Nothing,SymSet},
)
    @on "all_iv_sets" g (DAG, ADMG) _sets(
        CS.all_iv_sets(
            g, x, y, given;
            minimal = minimal, max_size = max_size, include = include, restrict = restrict,
        ),
    )
end

# An instrument and the conditioning set making it valid, as a list named `z`
# and `given` (the R name of CausalStructures.jl's `w`).
function jl_iv_set(
    @nospecialize(g::CausalGraph), x::Symbol, y::SymSet, restrict::Union{Nothing,SymSet},
)
    r = @on "iv_set" g (DAG, ADMG) CS.iv_set(g, x, y; restrict = restrict)
    r === nothing && return nothing
    return (z = _set(r.z), given = _set(r.w))
end

function jl_id(@nospecialize(g::CausalGraph), x::SymSet, y::SymSet)
    r = @on "id" g (DAG, ADMG) CS.id(g, x, y)
    return r === nothing ? nothing : string(r)
end

function jl_idc(@nospecialize(g::CausalGraph), x::SymSet, y::SymSet, given::SymSet)
    r = @on "idc" g (DAG, ADMG) CS.idc(g, x, y; given = given)
    return r === nothing ? nothing : string(r)
end

function jl_idp(@nospecialize(g::CausalGraph), x::SymSet, y::SymSet)
    r = @on "idp" g (PAG,) CS.idp(g, x, y)
    return r === nothing ? nothing : string(r)
end

function jl_cidp(@nospecialize(g::CausalGraph), x::SymSet, y::SymSet, given::SymSet)
    r = @on "cidp" g (PAG,) CS.cidp(g, x, y; given = given)
    return r === nothing ? nothing : string(r)
end

function jl_possible_parent_sets(@nospecialize(g::CausalGraph), x::Symbol)
    @on "possible_parent_sets" g (PDAG, CPDAG, MPDAG) _sets(CS.possible_parent_sets(g, x))
end

function jl_possible_joint_parent_sets(@nospecialize(g::CausalGraph), xs::SymSet)
    @on "possible_joint_parent_sets" g (PDAG, CPDAG, MPDAG) Vector{SymSet}[
        _sets(group) for group in CS.possible_joint_parent_sets(g, xs)
    ]
end

function jl_possible_optimal_adjustment_sets(@nospecialize(g::CausalGraph), x::Symbol, y::Symbol)
    @on "possible_optimal_adjustment_sets" g (PDAG, CPDAG, MPDAG) _opt_sets(
        CS.possible_optimal_adjustment_sets(g, x, y),
    )
end

function jl_possible_local_structures(@nospecialize(g::CausalGraph), x::Symbol)
    @on "possible_local_structures" g (PAG,) _sets(CS.possible_local_structures(g, x))
end

function jl_pagcauses(@nospecialize(g::CausalGraph), x::Symbol, y::Symbol)
    @on "pagcauses" g (PAG,) _sets(CS.pagcauses(g, x, y))
end

# --- Equivalence classes -----------------------------------------------------

function jl_count_dags(@nospecialize(g::CausalGraph))
    n = @on "count_dags" g (PDAG, CPDAG, MPDAG) CS.count_dags(g)
    return typemin(Int32) < n <= typemax(Int32) ? Int32(n) : Float64(n)
end

function jl_enumerate_dags(@nospecialize(g::CausalGraph))
    @on "enumerate_dags" g (PDAG, CPDAG, MPDAG) CausalGraph[d for d in CS.enumerate_dags(g)]
end

function jl_enumerate_mags(@nospecialize(g::CausalGraph), selection_bias::Bool)
    @on "enumerate_mags" g (PAG,) CausalGraph[
        d for d in CS.enumerate_mags(g; selection_bias = selection_bias)
    ]
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
    @eval function $(Symbol(:jl_, f))(@nospecialize(g::CausalGraph))
        @on $(String(f)) g $classes CS.$f(g)
    end
end

function jl_meek_closure(@nospecialize(g::CausalGraph), check_cycles::Bool, r4::Bool)
    @on "meek_closure" g (PDAG, CPDAG, MPDAG) (
        CS.meek_closure(g; check_cycles = check_cycles, r4 = r4)
    )
end

function jl_subgraph(@nospecialize(g::CausalGraph), nodes::SymSet)
    @on "subgraph" g ALL CS.subgraph(g, nodes)
end

function jl_latent_project(@nospecialize(g::CausalGraph), latents::SymSet)
    @on "latent_project" g (DAG,) CS.latent_project(g, latents)
end

function jl_exogenize(@nospecialize(g::CausalGraph), nodes::SymSet)
    @on "exogenize" g (DAG,) CS.exogenize(g, nodes)
end

function jl_normalize_latent_structure(@nospecialize(g::CausalGraph), latents::SymSet)
    @on "normalize_latent_structure" g (DAG,) CS.normalize_latent_structure(g, latents)
end

function jl_condition_marginalize(@nospecialize(g::CausalGraph), given::SymSet, index::SymSet)
    @on "condition_marginalize" g (DAG, ADMG, AG, MAG) (
        CS.condition_marginalize(g; given = given, index = index)
    )
end

function jl_maximal_local_mag(@nospecialize(g::CausalGraph), x::Symbol, c::SymSet)
    @on "maximal_local_mag" g (PAG,) CS.maximal_local_mag(g, x, c)
end

function jl_apply_background_knowledge(@nospecialize(g::CausalGraph), spec::String)
    bk = CS.BackgroundKnowledge(spec)
    @on "apply_background_knowledge" g (PDAG, CPDAG, MPDAG) CS.apply_background_knowledge(g, bk)
end

function jl_reclass(@nospecialize(g::CausalGraph), class::String)
    @on "reclass" g ALL @class class T ALL CS.reclass(g, T)
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

function jl_add_edges(@nospecialize(g::CausalGraph), spec::String)
    es = _spec_edges(spec)
    @on "add_edges" g ALL _fold(CS.add_edges, g, es)
end

function jl_remove_edges(@nospecialize(g::CausalGraph), spec::String)
    es = _spec_edges(spec)
    @on "remove_edges" g ALL _fold(CS.remove_edges, g, es)
end

function jl_add_nodes(@nospecialize(g::CausalGraph), nodes::SymSet)
    @on "add_nodes" g ALL _fold(CS.add_nodes, g, nodes)
end

function jl_remove_nodes(@nospecialize(g::CausalGraph), nodes::SymSet)
    @on "remove_nodes" g ALL _fold(CS.remove_nodes, g, nodes)
end

# --- Data generation ---------------------------------------------------------

# An n-by-p numeric matrix, one column per node in `nodes()` order, filled in
# place.
function jl_simulate_data(
    @nospecialize(g::CausalGraph),
    n::Int64,
    seed::Union{Nothing,Int64},
    standardize::Bool,
    coef_range::Vector{Float64},
    random_sign::Bool,
    error_sd::Vector{Float64},
)
    length(coef_range) == 2 || throw(ArgumentError("coef_range must have length 2"))
    coef = (coef_range[1], coef_range[2])
    g isa DAG || _unsupported("simulate_data", _class_name(g))
    # `error_sd` is one standard deviation, or the range each node's is drawn from.
    d = if length(error_sd) == 1
        CS.simulate_data(
            _rng(seed), g::DAG;
            samples = n, standardize = standardize, coef_range = coef,
            random_sign = random_sign, error_sd = error_sd[1],
        )
    elseif length(error_sd) == 2
        CS.simulate_data(
            _rng(seed), g::DAG;
            samples = n, standardize = standardize, coef_range = coef,
            random_sign = random_sign, error_sd = (error_sd[1], error_sd[2]),
        )
    else
        throw(ArgumentError("error_sd must have length 1 or 2"))
    end
    ns = (g::DAG).backend.nodes
    out = protect(_alloc_matrix(REALSXP, n, length(ns)))
    p = real_ptr(out)
    for (j, nd) in enumerate(ns)
        col = d[nd]
        GC.@preserve col unsafe_copyto!(p + (j - 1) * n * sizeof(Float64), pointer(col), n)
    end
    unprotect(1)
    return out
end

# --- Metrics -----------------------------------------------------------------

# hd and shd only read the node set and edge marks, so both graphs are compared
# as UNKNOWN: one specialization rather than one per pair of classes.
_as_unknown(@nospecialize(g::CausalGraph)) = @on "hd" g ALL CS.reclass(g, UNKNOWN)

function jl_hd(@nospecialize(g1::CausalGraph), @nospecialize(g2::CausalGraph), normalized::Bool)
    Float64(CS.hd(_as_unknown(g1), _as_unknown(g2); normalized = normalized))
end

function jl_shd(@nospecialize(g1::CausalGraph), @nospecialize(g2::CausalGraph), normalized::Bool)
    Float64(CS.shd(_as_unknown(g1), _as_unknown(g2); normalized = normalized))
end

function jl_aid(
    @nospecialize(g1::CausalGraph), @nospecialize(g2::CausalGraph), type::Symbol, normalized::Bool,
)
    @on "aid" g1 (DAG, PDAG, CPDAG, MPDAG) @on "aid" g2 (DAG, PDAG, CPDAG, MPDAG) Float64(
        CS.aid(g1, g2; type = type, normalized = normalized),
    )
end

# Both graphs must be of the same class (any AG with any AG, any PDAG with any
# PDAG); `strategy` is a keyword of the DAG method only.
function jl_separation_distance(
    @nospecialize(g1::CausalGraph), @nospecialize(g2::CausalGraph),
    strategy::Union{Nothing,Symbol}, mb_enhanced::Bool, symmetric::Bool, normalized::Bool,
)
    if g1 isa DAG && g2 isa DAG
        return Float64(
            CS.separation_distance(
                g1::DAG, g2::DAG;
                strategy = strategy === nothing ? :parents : strategy,
                mb_enhanced = mb_enhanced, symmetric = symmetric, normalized = normalized,
            ),
        )
    end
    strategy === nothing ||
        throw(ArgumentError("separation_distance() takes a strategy only for two DAGs"))
    if g1 isa CS.AbstractAG && g2 isa CS.AbstractAG
        @on "separation_distance" g1 (AG, MAG) @on "separation_distance" g2 (AG, MAG) Float64(
            CS.separation_distance(
                g1, g2; mb_enhanced = mb_enhanced, symmetric = symmetric, normalized = normalized,
            ),
        )
    elseif g1 isa CS.AbstractPDAG && g2 isa CS.AbstractPDAG
        @on "separation_distance" g1 (PDAG, CPDAG, MPDAG) @on "separation_distance" g2 (
            PDAG, CPDAG, MPDAG,
        ) Float64(
            CS.separation_distance(
                g1, g2; mb_enhanced = mb_enhanced, symmetric = symmetric, normalized = normalized,
            ),
        )
    elseif g1 isa PAG && g2 isa PAG
        Float64(
            CS.separation_distance(
                g1::PAG, g2::PAG; mb_enhanced = mb_enhanced, symmetric = symmetric, normalized = normalized,
            ),
        )
    else
        throw(
            ArgumentError(
                "separation_distance() needs two graphs of the same class, got a " *
                _class_name(g1) * " and a " * _class_name(g2),
            ),
        )
    end
end

# The s/c-metrics compare two graphs with the same separation notion: both
# d-separation (DAG and PDAGs) or both m-separation (ADMG, AGs and PAG).
macro on_same_separation(fname, g1, g2, body)
    d = :(DAG, PDAG, CPDAG, MPDAG)
    m = :(ADMG, AG, MAG, PAG)
    return esc(quote
        if $g1 isa DAG || $g1 isa CS.AbstractPDAG
            @on $fname $g1 $d @on $fname $g2 $d $body
        else
            @on $fname $g1 $m @on $fname $g2 $m $body
        end
    end)
end

for f in (:sc_metric, :markov_metric, :faithfulness_metric)
    @eval function $(Symbol(:jl_, f))(
        @nospecialize(g1::CausalGraph), @nospecialize(g2::CausalGraph),
        max_order::Union{Nothing,Int64},
    )
        @on_same_separation $(String(f)) g1 g2 CS.$f(g1, g2; max_order = max_order)
    end
end

# --- Layout ------------------------------------------------------------------

# Node positions from Sugiyama.jl's layered layout: an n-by-2 numeric matrix,
# one row per node in `nodes()` order. Every edge counts as pointing from `src`
# to `dst`; Sugiyama breaks any cycles itself, so this works for every class.
function jl_sugiyama_layout(@nospecialize(g::CausalGraph), direction::Symbol)
    ns, es, idx, A = _sugiyama_adjacency(g)
    return _points_matrix(Sugiyama.sugiyama(A; direction = direction))
end

# Like sugiyama_layout, plus each edge's route through Sugiyama's dummy nodes:
# a list of the n-by-2 position matrix and, per edge in `g.edges` order (the
# order of edge_marks), a k-by-2 matrix of its polyline from the source's
# position through any bend points to the destination's.
function jl_sugiyama_paths(@nospecialize(g::CausalGraph), direction::Symbol)
    ns, es, idx, A = _sugiyama_adjacency(g)
    pts, paths = Sugiyama.sugiyama_paths(A; direction = direction)
    out = protect(alloc(VECSXP, 2))
    set_vector_elt(out, 0, _points_matrix(pts))
    routes = alloc(VECSXP, length(es))
    set_vector_elt(out, 1, routes)
    for (k, e) in enumerate(es)
        set_vector_elt(routes, k - 1, _points_matrix(paths[(idx[e.src], idx[e.dst])]))
    end
    unprotect(1)
    return out
end

function _sugiyama_adjacency(@nospecialize(g::CausalGraph))
    ns = @on "sugiyama_layout" g ALL CS.nodes(g)
    es = @on "sugiyama_layout" g ALL g.edges
    n = length(ns)
    idx = Dict{Symbol,Int}(ns[i] => i for i in eachindex(ns))
    A = zeros(Int, n, n)
    for e in es
        A[idx[e.src], idx[e.dst]] = 1
    end
    return ns, es, idx, A
end

# Node positions from NetworkLayout.jl, as for sugiyama_layout, with every edge
# linking its two nodes regardless of direction (as in CausalStructures.jl's
# NetworkLayoutExt). The random layouts get an explicit RNG: their default,
# `DEFAULT_RNG[](seed)`, constructs a type only known at run time, which
# `--trim` rejects.
function jl_network_layout(@nospecialize(g::CausalGraph), method::Symbol, seed::Int64)
    ns, es, idx, A = _sugiyama_adjacency(g)
    U = Float64.((A .+ A') .> 0)
    if method === :stress
        return _points_matrix(NetworkLayout.stress(U; rng = StableRNG(seed)))
    elseif method === :spring
        return _points_matrix(NetworkLayout.spring(U; rng = StableRNG(seed)))
    elseif method === :sfdp
        return _points_matrix(NetworkLayout.sfdp(U; rng = StableRNG(seed)))
    elseif method === :spectral
        return _points_matrix(NetworkLayout.spectral(U))
    elseif method === :shell
        return _points_matrix(NetworkLayout.shell(U))
    elseif method === :squaregrid
        return _points_matrix(NetworkLayout.squaregrid(U))
    end
    throw(ArgumentError("unknown layout method " * String(method)))
end

# Points as an n-by-2 numeric matrix of x and y coordinates.
function _points_matrix(pts)
    n = length(pts)
    out = _alloc_matrix(REALSXP, n, 2)
    p = real_ptr(out)
    for (i, pt) in enumerate(pts)
        unsafe_store!(p, Float64(pt[1]), i)
        unsafe_store!(p, Float64(pt[2]), n + i)
    end
    return out
end

# --- R entrypoints -----------------------------------------------------------

@rcall jl_graph_count()::Int64
@rcall jl_cgraph(spec::String, class::String)::GraphRef
@rcall jl_generate_graph(
    n::Int64, m::SEXP, p::SEXP, class::String, latents::Int64, seed::SEXP,
)::GraphRef
@rcall jl_uniform_dag(n::Int64, seed::Union{Nothing,Int64})::GraphRef
@rcall jl_graph_string(g::GraphRef)::String

@rcall jl_nodes(g::GraphRef)::SymSet
@rcall jl_edge_marks(g::GraphRef)::SEXP
@rcall jl_edges(g::GraphRef)::SEXP
@rcall jl_topological_sort(g::GraphRef)::SymSet
@rcall jl_exogenous_nodes(g::GraphRef, undirected_as_parents::Bool)::SymSet
@rcall jl_has_edge(g::GraphRef, x::Symbol, y::Symbol)::Bool

@rcall jl_parents(g::GraphRef, node::Symbol)::SymSet
@rcall jl_children(g::GraphRef, node::Symbol)::SymSet
@rcall jl_spouses(g::GraphRef, node::Symbol)::SymSet
@rcall jl_markov_blanket(g::GraphRef, node::Symbol)::SymSet
@rcall jl_neighbors(g::GraphRef, node::Symbol, mode::Symbol)::SymSet
@rcall jl_ancestors(g::GraphRef, node::Symbol, open::Bool)::SymSet
@rcall jl_descendants(g::GraphRef, node::Symbol, open::Bool)::SymSet
@rcall jl_anteriors(g::GraphRef, node::Symbol, open::Bool)::SymSet
@rcall jl_posteriors(g::GraphRef, node::Symbol, open::Bool)::SymSet
@rcall jl_possible_ancestors(g::GraphRef, node::Symbol, open::Bool)::SymSet
@rcall jl_possible_descendants(g::GraphRef, node::Symbol, open::Bool)::SymSet
@rcall jl_districts(g::GraphRef)::Vector{SymSet}

@rcall jl_is_dag(g::GraphRef)::Bool
@rcall jl_is_pdag(g::GraphRef)::Bool
@rcall jl_is_cpdag(g::GraphRef)::Bool
@rcall jl_is_mpdag(g::GraphRef)::Bool
@rcall jl_is_ug(g::GraphRef)::Bool
@rcall jl_is_admg(g::GraphRef)::Bool
@rcall jl_is_ag(g::GraphRef)::Bool
@rcall jl_is_mag(g::GraphRef)::Bool
@rcall jl_is_pag(g::GraphRef)::Bool
@rcall jl_is_simple(g::GraphRef)::Bool
@rcall jl_is_acyclic(g::GraphRef)::Bool
@rcall jl_is_dag_type(g::GraphRef)::Bool
@rcall jl_graph_equal(g1::GraphRef, g2::GraphRef)::Bool
@rcall jl_markov_equivalent(g1::GraphRef, g2::GraphRef)::Bool

@rcall jl_d_separated(g::GraphRef, x::SymSet, y::SymSet, z::SymSet)::Bool
@rcall jl_m_separated(g::GraphRef, x::SymSet, y::SymSet, z::SymSet)::Bool
@rcall jl_minimal_separator(
    g::GraphRef, x::SymSet, y::SymSet, include::SymSet, restrict::Union{Nothing,SymSet},
)::Union{Nothing,SymSet}
@rcall jl_possible_d_sep(g::GraphRef, x::Symbol, y::SymSet)::SymSet

@rcall jl_adjustment_set(
    g::GraphRef, x::SymSet, y::SymSet, type::Symbol, include::SymSet,
    restrict::Union{Nothing,SymSet},
)::Union{Nothing,SymSet}
@rcall jl_backdoor_set(
    g::GraphRef, x::Symbol, y::Symbol, include::SymSet, restrict::Union{Nothing,SymSet},
)::Union{Nothing,SymSet}
@rcall jl_frontdoor_set(
    g::GraphRef, x::SymSet, y::SymSet, include::SymSet, restrict::Union{Nothing,SymSet},
)::Union{Nothing,SymSet}
@rcall jl_all_frontdoor_sets(
    g::GraphRef, x::SymSet, y::SymSet, include::SymSet, restrict::Union{Nothing,SymSet},
)::Vector{SymSet}
@rcall jl_is_valid_backdoor(g::GraphRef, x::SymSet, y::SymSet, z::SymSet)::Bool
@rcall jl_all_backdoor_sets(
    g::GraphRef, x::SymSet, y::SymSet, minimal::Bool, max_size::Int64, include::SymSet,
    restrict::Union{Nothing,SymSet},
)::Vector{SymSet}
@rcall jl_is_valid_adjustment(g::GraphRef, x::SymSet, y::SymSet, z::SymSet)::Bool
@rcall jl_all_adjustment_sets(
    g::GraphRef, x::SymSet, y::SymSet, minimal::Bool, max_size::Int64, include::SymSet,
    restrict::Union{Nothing,SymSet},
)::Vector{SymSet}
@rcall jl_is_valid_frontdoor(g::GraphRef, x::SymSet, y::SymSet, z::SymSet)::Bool
@rcall jl_is_valid_iv(g::GraphRef, x::Symbol, y::SymSet, z::SymSet, given::SymSet)::Bool
@rcall jl_all_iv_sets(
    g::GraphRef, x::Symbol, y::SymSet, given::SymSet, minimal::Bool, max_size::Int64,
    include::SymSet, restrict::Union{Nothing,SymSet},
)::Vector{SymSet}
@rcall jl_iv_set(
    g::GraphRef, x::Symbol, y::SymSet, restrict::Union{Nothing,SymSet},
)::Union{Nothing,@NamedTuple{z::SymSet, given::SymSet}}
@rcall jl_id(g::GraphRef, x::SymSet, y::SymSet)::Union{Nothing,String}
@rcall jl_idc(g::GraphRef, x::SymSet, y::SymSet, given::SymSet)::Union{Nothing,String}
@rcall jl_idp(g::GraphRef, x::SymSet, y::SymSet)::Union{Nothing,String}
@rcall jl_cidp(g::GraphRef, x::SymSet, y::SymSet, given::SymSet)::Union{Nothing,String}
@rcall jl_possible_parent_sets(g::GraphRef, x::Symbol)::Vector{SymSet}
@rcall jl_possible_joint_parent_sets(g::GraphRef, xs::SymSet)::Vector{Vector{SymSet}}
@rcall jl_possible_optimal_adjustment_sets(
    g::GraphRef, x::Symbol, y::Symbol,
)::Vector{Union{Nothing,SymSet}}
@rcall jl_possible_local_structures(g::GraphRef, x::Symbol)::Vector{SymSet}
@rcall jl_pagcauses(g::GraphRef, x::Symbol, y::Symbol)::Vector{SymSet}

@rcall jl_count_dags(g::GraphRef)::Union{Int32,Float64}
@rcall jl_enumerate_dags(g::GraphRef)::Vector{GraphRef}
@rcall jl_enumerate_mags(g::GraphRef, selection_bias::Bool)::Vector{GraphRef}

@rcall jl_skeleton(g::GraphRef)::GraphRef
@rcall jl_moralize(g::GraphRef)::GraphRef
@rcall jl_dag_to_cpdag(g::GraphRef)::GraphRef
@rcall jl_dag_from_pdag(g::GraphRef)::GraphRef
@rcall jl_dag_to_mpdag(g::GraphRef)::GraphRef
@rcall jl_ag_to_mag(g::GraphRef)::GraphRef
@rcall jl_mag_to_pag(g::GraphRef)::GraphRef
@rcall jl_mag_from_pag(g::GraphRef)::GraphRef
@rcall jl_meek_closure(g::GraphRef, check_cycles::Bool, r4::Bool)::GraphRef
@rcall jl_subgraph(g::GraphRef, nodes::SymSet)::GraphRef
@rcall jl_latent_project(g::GraphRef, latents::SymSet)::GraphRef
@rcall jl_exogenize(g::GraphRef, nodes::SymSet)::GraphRef
@rcall jl_normalize_latent_structure(g::GraphRef, latents::SymSet)::GraphRef
@rcall jl_condition_marginalize(g::GraphRef, given::SymSet, index::SymSet)::GraphRef
@rcall jl_maximal_local_mag(g::GraphRef, x::Symbol, c::SymSet)::GraphRef
@rcall jl_apply_background_knowledge(g::GraphRef, spec::String)::GraphRef
@rcall jl_reclass(g::GraphRef, class::String)::GraphRef

@rcall jl_add_edges(g::GraphRef, spec::String)::GraphRef
@rcall jl_remove_edges(g::GraphRef, spec::String)::GraphRef
@rcall jl_add_nodes(g::GraphRef, nodes::SymSet)::GraphRef
@rcall jl_remove_nodes(g::GraphRef, nodes::SymSet)::GraphRef

@rcall jl_simulate_data(
    g::GraphRef, n::Int64, seed::Union{Nothing,Int64}, standardize::Bool,
    coef_range::Vector{Float64}, random_sign::Bool, error_sd::Vector{Float64},
)::SEXP

@rcall jl_hd(g1::GraphRef, g2::GraphRef, normalized::Bool)::Float64
@rcall jl_shd(g1::GraphRef, g2::GraphRef, normalized::Bool)::Float64
@rcall jl_aid(g1::GraphRef, g2::GraphRef, type::Symbol, normalized::Bool)::Float64
@rcall jl_separation_distance(
    g1::GraphRef, g2::GraphRef, strategy::Union{Nothing,Symbol}, mb_enhanced::Bool,
    symmetric::Bool, normalized::Bool,
)::Float64
@rcall jl_sc_metric(g1::GraphRef, g2::GraphRef, max_order::Union{Nothing,Int64})::Float64
@rcall jl_markov_metric(g1::GraphRef, g2::GraphRef, max_order::Union{Nothing,Int64})::Float64
@rcall jl_faithfulness_metric(
    g1::GraphRef, g2::GraphRef, max_order::Union{Nothing,Int64},
)::Float64

@rcall jl_sugiyama_layout(g::GraphRef, direction::Symbol)::SEXP
@rcall jl_network_layout(g::GraphRef, method::Symbol, seed::Int64)::SEXP
@rcall jl_sugiyama_paths(g::GraphRef, direction::Symbol)::SEXP

end # module
