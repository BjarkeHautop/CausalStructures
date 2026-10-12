# Package index

## Construction

Build causal graphs.

- [`cgraph()`](https://bjarkehautop.github.io/CausalStructures/reference/cgraph.md)
  : Create a causal graph
- [`` `%-->%` ``](https://bjarkehautop.github.io/CausalStructures/reference/edge-operators.md)
  [`` `%<--%` ``](https://bjarkehautop.github.io/CausalStructures/reference/edge-operators.md)
  [`` `%---%` ``](https://bjarkehautop.github.io/CausalStructures/reference/edge-operators.md)
  [`` `%<->%` ``](https://bjarkehautop.github.io/CausalStructures/reference/edge-operators.md)
  [`` `%o->%` ``](https://bjarkehautop.github.io/CausalStructures/reference/edge-operators.md)
  [`` `%<-o%` ``](https://bjarkehautop.github.io/CausalStructures/reference/edge-operators.md)
  [`` `%o--%` ``](https://bjarkehautop.github.io/CausalStructures/reference/edge-operators.md)
  [`` `%--o%` ``](https://bjarkehautop.github.io/CausalStructures/reference/edge-operators.md)
  [`` `%o-o%` ``](https://bjarkehautop.github.io/CausalStructures/reference/edge-operators.md)
  : Edge specification operators

## Graph queries

Whole-graph queries: nodes, edges, and adjacency.

- [`nodes()`](https://bjarkehautop.github.io/CausalStructures/reference/graph-queries.md)
  [`topological_sort()`](https://bjarkehautop.github.io/CausalStructures/reference/graph-queries.md)
  [`exogenous_nodes()`](https://bjarkehautop.github.io/CausalStructures/reference/graph-queries.md)
  : Graph-level node queries
- [`has_edge()`](https://bjarkehautop.github.io/CausalStructures/reference/has_edge.md)
  : Test whether two nodes are adjacent
- [`edges()`](https://bjarkehautop.github.io/CausalStructures/reference/edges.md)
  : Get all edges in a graph

## Node-set queries

Relatives of a single node.

- [`parents()`](https://bjarkehautop.github.io/CausalStructures/reference/node-queries.md)
  [`children()`](https://bjarkehautop.github.io/CausalStructures/reference/node-queries.md)
  [`ancestors()`](https://bjarkehautop.github.io/CausalStructures/reference/node-queries.md)
  [`descendants()`](https://bjarkehautop.github.io/CausalStructures/reference/node-queries.md)
  [`spouses()`](https://bjarkehautop.github.io/CausalStructures/reference/node-queries.md)
  : Node-set queries
- [`markov_blanket()`](https://bjarkehautop.github.io/CausalStructures/reference/markov_blanket.md)
  : Markov blanket of a node
- [`neighbors()`](https://bjarkehautop.github.io/CausalStructures/reference/neighbors.md)
  : Neighbors of a node
- [`possible_ancestors()`](https://bjarkehautop.github.io/CausalStructures/reference/possible-queries.md)
  [`possible_descendants()`](https://bjarkehautop.github.io/CausalStructures/reference/possible-queries.md)
  : Possible-ancestor/descendant node-set queries
- [`anteriors()`](https://bjarkehautop.github.io/CausalStructures/reference/anteriors.md)
  [`posteriors()`](https://bjarkehautop.github.io/CausalStructures/reference/anteriors.md)
  : Anterior/posterior node-set queries
- [`possible_d_sep()`](https://bjarkehautop.github.io/CausalStructures/reference/possible_d_sep.md)
  : Find every possible D-SEP set

## Graph class predicates

Test structural properties of a graph.

- [`is_dag()`](https://bjarkehautop.github.io/CausalStructures/reference/predicates.md)
  [`is_pdag()`](https://bjarkehautop.github.io/CausalStructures/reference/predicates.md)
  [`is_cpdag()`](https://bjarkehautop.github.io/CausalStructures/reference/predicates.md)
  [`is_mpdag()`](https://bjarkehautop.github.io/CausalStructures/reference/predicates.md)
  [`is_ug()`](https://bjarkehautop.github.io/CausalStructures/reference/predicates.md)
  [`is_admg()`](https://bjarkehautop.github.io/CausalStructures/reference/predicates.md)
  [`is_ag()`](https://bjarkehautop.github.io/CausalStructures/reference/predicates.md)
  [`is_mag()`](https://bjarkehautop.github.io/CausalStructures/reference/predicates.md)
  [`is_pag()`](https://bjarkehautop.github.io/CausalStructures/reference/predicates.md)
  [`is_simple()`](https://bjarkehautop.github.io/CausalStructures/reference/predicates.md)
  [`is_acyclic()`](https://bjarkehautop.github.io/CausalStructures/reference/predicates.md)
  : Graph class predicates

## Transformations

Derive a new graph from an existing one.

- [`skeleton()`](https://bjarkehautop.github.io/CausalStructures/reference/skeleton.md)
  : Drop edge marks to an undirected graph
- [`moralize()`](https://bjarkehautop.github.io/CausalStructures/reference/moralize.md)
  : Moralize a graph
- [`dag_to_cpdag()`](https://bjarkehautop.github.io/CausalStructures/reference/dag_to_cpdag.md)
  : Convert a DAG to its CPDAG
- [`dag_from_pdag()`](https://bjarkehautop.github.io/CausalStructures/reference/dag_from_pdag.md)
  : Extend a PDAG to a consistent DAG
- [`meek_closure()`](https://bjarkehautop.github.io/CausalStructures/reference/meek_closure.md)
  : Apply Meek's orientation rules
- [`dag_to_mpdag()`](https://bjarkehautop.github.io/CausalStructures/reference/dag_to_mpdag.md)
  : Convert a DAG to its MPDAG
- [`ag_to_mag()`](https://bjarkehautop.github.io/CausalStructures/reference/ag_to_mag.md)
  : Convert an AG to a Markov equivalent MAG
- [`mag_to_pag()`](https://bjarkehautop.github.io/CausalStructures/reference/mag_to_pag.md)
  : Map a MAG to its PAG equivalence class
- [`mag_from_pag()`](https://bjarkehautop.github.io/CausalStructures/reference/mag_from_pag.md)
  : Resolve a PAG to a representative MAG
- [`subgraph()`](https://bjarkehautop.github.io/CausalStructures/reference/subgraph.md)
  : Induced subgraph
- [`latent_project()`](https://bjarkehautop.github.io/CausalStructures/reference/latent_project.md)
  : Project out latent variables
- [`exogenize()`](https://bjarkehautop.github.io/CausalStructures/reference/exogenize.md)
  : Make nodes exogenous
- [`normalize_latent_structure()`](https://bjarkehautop.github.io/CausalStructures/reference/normalize_latent_structure.md)
  : Normalize latent structure
- [`condition_marginalize()`](https://bjarkehautop.github.io/CausalStructures/reference/condition_marginalize.md)
  : Condition and marginalize a graph

## Mutation and reclassification

Add or remove edges/nodes, or change a graph’s tagged class.

- [`add_edges()`](https://bjarkehautop.github.io/CausalStructures/reference/edge-mutation.md)
  [`remove_edges()`](https://bjarkehautop.github.io/CausalStructures/reference/edge-mutation.md)
  : Add or remove edges
- [`add_nodes()`](https://bjarkehautop.github.io/CausalStructures/reference/node-mutation.md)
  [`remove_nodes()`](https://bjarkehautop.github.io/CausalStructures/reference/node-mutation.md)
  : Add or remove isolated nodes
- [`reclass()`](https://bjarkehautop.github.io/CausalStructures/reference/reclass.md)
  : Reclassify a graph

## Separation and identification

d-/m-separation and adjustment/frontdoor/IV identification.

- [`d_separated()`](https://bjarkehautop.github.io/CausalStructures/reference/d_separated.md)
  : Test d-separation
- [`m_separated()`](https://bjarkehautop.github.io/CausalStructures/reference/m_separated.md)
  : Test m-separation
- [`minimal_separator()`](https://bjarkehautop.github.io/CausalStructures/reference/minimal_separator.md)
  : Find a minimal separator
- [`adjustment_set()`](https://bjarkehautop.github.io/CausalStructures/reference/adjustment_set.md)
  : Find an adjustment set
- [`frontdoor_set()`](https://bjarkehautop.github.io/CausalStructures/reference/frontdoor_set.md)
  : Find a frontdoor adjustment set
- [`is_valid_backdoor()`](https://bjarkehautop.github.io/CausalStructures/reference/is_valid_backdoor.md)
  : Validate a backdoor adjustment set
- [`all_backdoor_sets()`](https://bjarkehautop.github.io/CausalStructures/reference/all_backdoor_sets.md)
  : Enumerate backdoor adjustment sets
- [`all_frontdoor_sets()`](https://bjarkehautop.github.io/CausalStructures/reference/all_frontdoor_sets.md)
  : Enumerate frontdoor adjustment sets
- [`is_valid_adjustment()`](https://bjarkehautop.github.io/CausalStructures/reference/is_valid_adjustment.md)
  : Validate an adjustment set
- [`all_adjustment_sets()`](https://bjarkehautop.github.io/CausalStructures/reference/all_adjustment_sets.md)
  : Enumerate all valid adjustment sets
- [`is_valid_frontdoor()`](https://bjarkehautop.github.io/CausalStructures/reference/is_valid_frontdoor.md)
  : Validate a frontdoor criterion set
- [`is_valid_iv()`](https://bjarkehautop.github.io/CausalStructures/reference/is_valid_iv.md)
  : Validate instrumental variables
- [`all_iv_sets()`](https://bjarkehautop.github.io/CausalStructures/reference/all_iv_sets.md)
  : Enumerate all valid instrumental variable sets
- [`backdoor_set()`](https://bjarkehautop.github.io/CausalStructures/reference/backdoor_set.md)
  : Find a generalized backdoor set
- [`id()`](https://bjarkehautop.github.io/CausalStructures/reference/id.md)
  [`idc()`](https://bjarkehautop.github.io/CausalStructures/reference/id.md)
  : Identify an interventional distribution

## Local IDA

Local structure-learning identification (IDA and its variants).

- [`possible_parent_sets()`](https://bjarkehautop.github.io/CausalStructures/reference/possible_parent_sets.md)
  : Enumerate possible parent sets (local IDA)
- [`possible_joint_parent_sets()`](https://bjarkehautop.github.io/CausalStructures/reference/possible_joint_parent_sets.md)
  : Enumerate possible joint parent sets (joint-IDA)
- [`possible_optimal_adjustment_sets()`](https://bjarkehautop.github.io/CausalStructures/reference/possible_optimal_adjustment_sets.md)
  : Enumerate possible optimal adjustment sets (O-set-based IDA)
- [`possible_local_structures()`](https://bjarkehautop.github.io/CausalStructures/reference/possible_local_structures.md)
  : Enumerate valid local structures at a node of a PAG
- [`maximal_local_mag()`](https://bjarkehautop.github.io/CausalStructures/reference/maximal_local_mag.md)
  : Build the maximal local MAG for a local structure
- [`pagcauses()`](https://bjarkehautop.github.io/CausalStructures/reference/pagcauses.md)
  : Find every possible causal effect in a PAG (PAGcauses)

## Equivalence classes

Count and enumerate Markov equivalent graphs.

- [`count_dags()`](https://bjarkehautop.github.io/CausalStructures/reference/equivalence.md)
  [`enumerate_dags()`](https://bjarkehautop.github.io/CausalStructures/reference/equivalence.md)
  : Count and enumerate DAGs in a Markov equivalence class
- [`markov_equivalent()`](https://bjarkehautop.github.io/CausalStructures/reference/markov_equivalent.md)
  : Test whether two graphs are Markov equivalent
- [`enumerate_mags()`](https://bjarkehautop.github.io/CausalStructures/reference/enumerate_mags.md)
  : Enumerate MAGs in a PAG equivalence class

## Generation and simulation

- [`simulate_data()`](https://bjarkehautop.github.io/CausalStructures/reference/simulate_data.md)
  : Simulate data from a DAG
- [`generate_graph()`](https://bjarkehautop.github.io/CausalStructures/reference/generate_graph.md)
  : Generate a random graph
- [`uniform_dag()`](https://bjarkehautop.github.io/CausalStructures/reference/uniform_dag.md)
  : Generate a uniformly random DAG

## Plotting

- [`plot(`*`<cgraph>`*`)`](https://bjarkehautop.github.io/CausalStructures/reference/plot.md)
  : Plot a causal graph
- [`cgraph_layout()`](https://bjarkehautop.github.io/CausalStructures/reference/cgraph_layout.md)
  : Compute a graph layout
- [`plot_options()`](https://bjarkehautop.github.io/CausalStructures/reference/plot_options.md)
  : Get or set global default plot styles
- [`plot_default_options()`](https://bjarkehautop.github.io/CausalStructures/reference/plot_default_options.md)
  : Default plot styling options

## Managing Julia

- [`install_backend()`](https://bjarkehautop.github.io/CausalStructures/reference/install_backend.md)
  : Build the compiled CausalStructures.jl library
- [`julia_ready()`](https://bjarkehautop.github.io/CausalStructures/reference/julia_ready.md)
  : Is the compiled CausalStructures.jl library available?
- [`setup()`](https://bjarkehautop.github.io/CausalStructures/reference/setup.md)
  : Load the compiled CausalStructures.jl library
- [`warmup()`](https://bjarkehautop.github.io/CausalStructures/reference/warmup.md)
  : Call every wrapper once
- [`CausalStructures_options`](https://bjarkehautop.github.io/CausalStructures/reference/CausalStructures_options.md)
  : Package options
