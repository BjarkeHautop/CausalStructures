# Apply Meek's orientation rules

Applies Meek's rules R1-R4 to the PDAG-family graph `cg` until no
further orientation is implied, returning the resulting MPDAG.

## Usage

``` r
meek_closure(cg, check_cycles = TRUE, r4 = TRUE)
```

## Arguments

- cg:

  A PDAG-family (PDAG, CPDAG, MPDAG) graph created with
  [`cgraph()`](https://bjarkehautop.github.io/CausalStructures/reference/cgraph.md).

- check_cycles:

  If `TRUE` (default), reject an orientation that would introduce a
  directed cycle. Disabling this can speed up closure when `cg` is known
  to admit no such cycle.

- r4:

  If `TRUE` (default), apply rule R4. Disabling this can speed up
  closure when `cg` is known not to need it (e.g. it has no background
  knowledge beyond the v-structures already encoded in it).

## Value

An `MPDAG` graph proxy.

## Details

- **R1**: `a --> b --- c`, `a` not adjacent to `c` implies `b --> c`.

- **R2**: `a --- b`, a directed path `a --> w --> b` exists implies
  `a --> b`.

- **R3**: `a --- b`, two non-adjacent parents `c, d` of `b` with
  `a --- c` and `a --- d` implies `a --> b`.

- **R4**: `a --- b`, a directed path `a -->...--> b` exists implies
  `a --> b`.

## References

Meek C (1995). “Causal inference and causal explanation with background
knowledge.” In *Proceedings of UAI 1995*, 403–410.

## Examples

``` r
if (julia_ready()) {
  pdag <- cgraph(A %-->% B, B %---% C, class = "PDAG")
  meek_closure(pdag)
}
#> MPDAG with 3 nodes and 2 edges:
#>   nodes: A, B, C
#>   edges:
#>     A --> B, B --> C
```
