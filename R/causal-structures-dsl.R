# --- Edge-operator DSL --------------------------------------------------------
#
# Translates the operator syntax used by cgraph()/add_edges()/
# remove_edges() (e.g. `A %-->% X + Y, X %-->% M %-->% Y`) into
# CausalStructures.jl's string DSL (`"A --> X + Y, X --> M --> Y"`), which is
# what actually crosses the R-Julia boundary. The operators below are never
# evaluated: `...` is captured unevaluated via `substitute()`, so `%-->%` and
# friends only need to exist so R's parser accepts the infix syntax;
# they are not exported.
#
# `%any%` custom operators bind tighter than `+`, so `A %-->% B + C` actually
# parses as `(A %-->% B) + C` and `X + Y %-->% B` as `X + (Y %-->% B)`.

.edge_glyphs <- c(
  `%-->%` = "-->",
  `%<--%` = "<--",
  `%---%` = "---",
  `%<->%` = "<->",
  `%o->%` = "o->",
  `%<-o%` = "<-o",
  `%o--%` = "o--",
  `%--o%` = "--o",
  `%o-o%` = "o-o"
)

.is_edge_call <- function(expr) {
  is.call(expr) && deparse1(expr[[1L]]) %in% names(.edge_glyphs)
}

.is_node_expr <- function(expr) {
  if (is.symbol(expr) || (is.character(expr) && length(expr) == 1L)) {
    return(TRUE)
  }
  if (is.call(expr)) {
    fn <- deparse1(expr[[1L]])
    if (fn == "(") {
      return(.is_node_expr(expr[[2L]]))
    }
    if (fn == "c") {
      return(all(vapply(as.list(expr)[-1L], .is_node_expr, logical(1))))
    }
    if (fn == "+") {
      return(.is_node_expr(expr[[2L]]) && .is_node_expr(expr[[3L]]))
    }
  }
  FALSE
}

.contains_edge <- function(expr) {
  if (.is_edge_call(expr)) {
    return(TRUE)
  }
  if (is.call(expr)) {
    fn <- deparse1(expr[[1L]])
    if (fn == "(") {
      return(.contains_edge(expr[[2L]]))
    }
    if (fn == "+") {
      return(.contains_edge(expr[[2L]]) || .contains_edge(expr[[3L]]))
    }
  }
  FALSE
}

# Render a node-group expression (symbol, string, `+`-chain, `c(...)`, or
# parens around one of those) as DSL text, e.g. `X + Y`.
.node_group <- function(expr) {
  if (is.symbol(expr)) {
    return(deparse1(expr))
  }
  if (is.character(expr) && length(expr) == 1L) {
    return(expr)
  }
  if (is.call(expr)) {
    fn <- deparse1(expr[[1L]])
    if (fn == "(") {
      return(.node_group(expr[[2L]]))
    }
    if (fn == "+") {
      return(paste(
        .node_group(expr[[2L]]),
        .node_group(expr[[3L]]),
        sep = " + "
      ))
    }
    if (fn == "c") {
      return(paste(
        vapply(as.list(expr)[-1L], .node_group, character(1)),
        collapse = " + "
      ))
    }
  }
  stop("Unsupported node expression: ", deparse(expr), call. = FALSE)
}

# Split an expression on top-level `+` (the operator combining an edge unit
# with extra fan-out nodes attached alongside it, not the `+` inside a node
# group, which `.node_group()` handles separately once a unit is final).
.split_plus <- function(expr) {
  if (is.call(expr)) {
    fn <- deparse1(expr[[1L]])
    if (fn == "+") {
      return(c(.split_plus(expr[[2L]]), .split_plus(expr[[3L]])))
    }
    if (fn == "(") {
      return(.split_plus(expr[[2L]]))
    }
  }
  list(expr)
}

.combine_plus <- function(terms) {
  out <- terms[[1L]]
  for (i in seq_along(terms)[-1L]) {
    out <- call("+", out, terms[[i]])
  }
  out
}

# Peel a left-associative chain of edge calls (`A %-->% B %-->% C`) into its
# node-group terms and operator names, left to right.
.flatten_chain <- function(expr) {
  terms <- list()
  ops <- character()
  cur <- expr
  repeat {
    if (.is_edge_call(cur)) {
      ops <- c(deparse1(cur[[1L]]), ops)
      terms <- c(list(cur[[3L]]), terms)
      cur <- cur[[2L]]
    } else {
      terms <- c(list(cur), terms)
      break
    }
  }
  list(terms = terms, ops = ops)
}

# Parse one `...` argument that contains at least one edge operator into a
# list of `(lhs, rhs, glyph)` units, handling chains (`A --> B --> C`) and
# `+`-attached fan-out nodes on either side (`A --> B + C`, `X + Y --> B`).
.parse_edge_arg <- function(expr) {
  terms <- .split_plus(expr)
  is_edge <- vapply(terms, .is_edge_call, logical(1))
  edge_idx <- which(is_edge)
  units <- list()

  for (k in seq_along(edge_idx)) {
    i <- edge_idx[k]
    edge_term <- terms[[i]]
    prev_idx <- if (k > 1L) edge_idx[k - 1L] else 0L
    next_idx <- if (k < length(edge_idx)) {
      edge_idx[k + 1L]
    } else {
      length(terms) + 1L
    }
    left_idx <- if (prev_idx + 1L <= i - 1L) {
      seq.int(prev_idx + 1L, i - 1L)
    } else {
      integer()
    }
    right_idx <- if (i + 1L <= next_idx - 1L) {
      seq.int(i + 1L, next_idx - 1L)
    } else {
      integer()
    }
    left_nodes <- terms[left_idx]
    right_nodes <- terms[right_idx]

    if (!.is_edge_call(edge_term[[2L]])) {
      lhs <- edge_term[[2L]]
      rhs <- edge_term[[3L]]
      if (length(left_nodes)) {
        lhs <- call("+", .combine_plus(left_nodes), lhs)
      }
      if (length(right_nodes)) {
        rhs <- call("+", rhs, .combine_plus(right_nodes))
      }
      units[[length(units) + 1L]] <- list(
        lhs = lhs,
        rhs = rhs,
        glyph = .edge_glyphs[[deparse1(edge_term[[1L]])]]
      )
      next
    }

    chain <- .flatten_chain(edge_term)
    chain_terms <- chain$terms
    if (length(left_nodes)) {
      chain_terms[[1L]] <- call(
        "+",
        .combine_plus(left_nodes),
        chain_terms[[1L]]
      )
    }
    if (length(right_nodes)) {
      last <- length(chain_terms)
      chain_terms[[last]] <- call(
        "+",
        chain_terms[[last]],
        .combine_plus(right_nodes)
      )
    }
    for (j in seq_along(chain$ops)) {
      units[[length(units) + 1L]] <- list(
        lhs = chain_terms[[j]],
        rhs = chain_terms[[j + 1L]],
        glyph = .edge_glyphs[[chain$ops[[j]]]]
      )
    }
  }
  units
}

# Render one `...` argument (edge expression or bare node declaration) as a
# fragment of CausalStructures.jl's string DSL.
.stmt_dsl <- function(expr) {
  if (.contains_edge(expr)) {
    units <- .parse_edge_arg(expr)
    texts <- vapply(
      units,
      function(u) paste(.node_group(u$lhs), u$glyph, .node_group(u$rhs)),
      character(1)
    )
    return(paste(texts, collapse = ", "))
  }
  if (.is_node_expr(expr)) {
    return(.node_group(expr))
  }
  stop(
    "Expected an edge expression (e.g. `A %-->% B`) or a node declaration ",
    "(e.g. `E`, `D + E`); got: ",
    deparse(expr),
    call. = FALSE
  )
}

# Build a full graph-string-DSL spec from the unevaluated `...` of
# cgraph()/add_edges()/remove_edges().
.spec_from_calls <- function(calls) {
  if (length(calls) == 0L) {
    stop("Provide at least one edge or node expression.", call. = FALSE)
  }
  paste(vapply(calls, .stmt_dsl, character(1)), collapse = ", ")
}

# Resolve the operator-DSL `...` (captured unevaluated as `substitute(list(...))`
# by the caller) or an explicit `spec` string, whichever was supplied.
.dots_or_spec <- function(list_call, spec) {
  calls <- as.list(list_call)[-1L]
  if (!is.null(spec)) {
    if (length(calls) > 0L) {
      stop(
        "Provide edges via `...` or via `spec`, but not both.",
        call. = FALSE
      )
    }
    return(spec)
  }
  .spec_from_calls(calls)
}

#' Edge specification operators
#'
#' Infix operators used inside [cgraph()], [add_edges()], and
#' [remove_edges()] to specify edges, e.g. `A %-->% X + Y`. Multiple edges
#' fan out from (or into) a single marker with `+`: `A %-->% X + Y` means `A
#' --> X` and `A --> Y`; chaining connects consecutive nodes pairwise, so `X
#' %-->% M %-->% Y` means `X --> M` and `M --> Y`.
#'
#' | Operator  | Meaning                        |
#' |:----------|:--------------------------------|
#' | `%-->%`   | directed, `src --> dst`         |
#' | `%<--%`   | directed, `dst --> src`         |
#' | `%---%`   | undirected                      |
#' | `%<->%`   | bidirected                      |
#' | `%o->%`   | partially directed, `src o-> dst` |
#' | `%<-o%`   | partially directed, `dst o-> src` |
#' | `%o--%`   | partially undirected, `src o-- dst` |
#' | `%--o%`   | partially undirected, `dst o-- src` |
#' | `%o-o%`   | partial (both ends circle)      |
#'
#' These operators only make sense inside the `...` of `cgraph()`,
#' `add_edges()`, or `remove_edges()`, which capture their arguments
#' unevaluated; they are not exported and are not meant to be called
#' directly.
#'
#' @param lhs,rhs Node name(s): a bare symbol, a string, or a `+`-combination
#'   or `c()` of either.
#' @return Not meaningful on its own; see the Description.
#' @name cs-edge-operators
#' @keywords internal
#' @examples
#' if (julia_available()) {
#'   dag <- cgraph(A %-->% X + Y, X %-->% M %-->% Y)
#'   edges(dag)
#' }
NULL

#' @rdname cs-edge-operators
`%-->%` <- function(lhs, rhs) .stmt_dsl(sys.call())

#' @rdname cs-edge-operators
`%<--%` <- function(lhs, rhs) .stmt_dsl(sys.call())

#' @rdname cs-edge-operators
`%---%` <- function(lhs, rhs) .stmt_dsl(sys.call())

#' @rdname cs-edge-operators
`%<->%` <- function(lhs, rhs) .stmt_dsl(sys.call())

#' @rdname cs-edge-operators
`%o->%` <- function(lhs, rhs) .stmt_dsl(sys.call())

#' @rdname cs-edge-operators
`%<-o%` <- function(lhs, rhs) .stmt_dsl(sys.call())

#' @rdname cs-edge-operators
`%o--%` <- function(lhs, rhs) .stmt_dsl(sys.call())

#' @rdname cs-edge-operators
`%--o%` <- function(lhs, rhs) .stmt_dsl(sys.call())

#' @rdname cs-edge-operators
`%o-o%` <- function(lhs, rhs) .stmt_dsl(sys.call())
