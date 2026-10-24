# SRW3 Phase 1Q — The Constructor-Based Count Representation

**Phase:** 1Q — exact constructor-valued pool counts and universal transition
preservation, on the pinned toolchain K v7.1.337 + z3 4.13.3.
**Status:** design of record; every mechanized result is classified from raw
logs in `phase1q/transcripts/k/`; nothing in this file is a proof claim.
Level III only; no consensus-integration claim.

---

## 0. The obstruction being removed (from the 1P record)

Finding 1P-F2 (`phase1p/report/phase1p-final-report.md`): the branch-tag
encoding defeats the 1O disjunctive obstacle — from rung TD onward the
residual's tag is pinned — but the universal residual stops exactly at

```
absStepT(absStT(tg:1, cfgP:true, catP:true, cntG:AX3, cntE:AX4, nSlot:AX5,
                safe:true, diag:AX7), aCommitJ(aOkT, aOkF))
```

under the forked-but-unpropagated joint guard `G >=Int 1 andBool E >=Int 1`
versus its complement `G <=Int 0 orBool E <=Int 0`. The TDRR runner-level
fork propagates SINGLE-variable inequalities (the gate shapes resolve) but
not compound two-variable guards; a function-level requires split cannot
help (TDR ≡ TD residual). The toy reproduces the same wall at toy scale
(residual `tstep(stT(tag:S0, iv:S1), subC)`): the blocker is architectural,
not scale.

The 1O/1P diagnosis, made precise: the pinned checker discriminates
constructors at REWRITE positions (the `<absjshadow>` cell pattern — the tag
mechanism works), but it cannot evaluate a pattern-matched function whose
rows are separated by INT inequalities over a symbolic argument, and its
implication checker does not case-split function-argument variables on
free constructors or arithmetic.

## 1. The 1Q mechanism (the independent variable)

Replace the two integer pool counters `cntG:Int, cntE:Int` with an algebraic
exact count:

```
syntax PoolCount ::= "zeroP"          // exactly zero receipts
                    | succP(PoolCount) // exactly one more receipt than _
                    [ctor]
```

`PoolCount` is a FREE constructor sort: `zeroP` and `succP` are distinct
constructors, there are no equations between constructor terms, and every
well-sorted `PoolCount` term is built from exactly these two. The state
becomes `absStQ(tg:Int, cfgP:Bool, catP:Bool, cntG:PoolCount, cntE:PoolCount,
nSlot:Int, safe:Bool, diag:ADiag)` — the TDRR state with the two Int fields
replaced. Everything else (the tag, the bits, the twelve-class step, the
runner, the fold, the domain predicate) is the 1P TDRR architecture carried
over.

**Why this can remove the compound guard.** The 1P guard distinguished the
commit-accept row from the reject rows by an arithmetic fact about symbolic
Integers. The constructor encoding distinguishes the same rows by the HEAD
CONSTRUCTOR of the pool term:

* commit acceptance structurally requires both pools to have a successor
  constructor — the accept row's left-hand side contains `succP(G0),
  succP(E0)`;
* commit rejection covers every case with at least one `zeroP` — explicit
  rows `(zeroP, E)` and `(succP(G0), zeroP)` — plus the bits-failed rows
  over `(succP(G0), succP(E0))`.

No `requires` on any pool appears anywhere in the strong machine's step
function (the only `requires` left is the 1P incoherent-tag complement on
the tag, carried over verbatim). If the checker discriminates the pool
constructors — at the rewrite level via the runner fork (the proven TD/TDRR
mechanism, now applied to the pool positions), or inside function-argument
evaluation (the open question the toy probes first) — the compound
arithmetic guard is gone from the dispatch path entirely.

**What is preserved exactly.** The representation carries the same
information as the integers: `countToInt` (§3) is a bijection onto the
nonnegative integers (meta-level; see C1), `succP` is the successor, and
the machine never inspects anything about a pool but its head constructor
and its tail. Arbitrary finite pool sizes are represented: `succP^n(zeroP)`
for every n ∈ ℕ. This is NOT a Boolean-occupancy abstraction; the exact
count is recoverable and the erasure map (§3 of
`refinement-relation.md`) is count-exact.

## 2. The transition-table translation (the complete mapping)

The 1P TDRR rows (the generated `abs-machine-tdrr.k` of record) translate
row-for-row. `dec` is structural: `dec(succP(n)) = n`; **no decrement of
`zeroP` is permitted** — every row that decrements a pool is patterned on
`succP`, so the operation is undefined (unmatched) exactly where the 1P
machine's guard would have rejected. `inc(n) = succP(n)`.

| 1P TDRR row (Int form) | 1Q row (constructor form) |
|---|---|
| init-accept: `(0,false,false,_,_,_,_,D), aInitJ(aOkT) => (1,true,true,0,0,0,true,D)` | identical with `0,0` replaced by `zeroP,zeroP` (pools RESET to empty — the 1P row's `0,0,0` bookkeeping) |
| init-refuse, re-init refused, exec-stall, exec-mint, exec-source, exec-refuse, gate pre-init, commit pre-init | identical; pools carried as opaque `PoolCount` variables; exec-mint's `E +Int 1` becomes `succP(E)` |
| gate row A `requires E <=Int 0` | row A-Z: pool pattern `cntE = zeroP`, no requires |
| gate row B `aOkT, requires E >=Int 1` (mint `G +Int 1`) | row B-S: pool pattern `cntE = succP(E0)`, mint `cntG = succP(G)`, no requires |
| gate row C `aOkF, requires E >=Int 1` (refuse) | row C-S: pool pattern `cntE = succP(E0)`, refuse, no requires |
| commit row B `aOkT,aOkT requires G>=1 ∧ E>=1` (accept: `G-1, E-1, N+1, safe:=true`) | row B-SS: pattern `succP(G0), succP(E0)`, successor `G0, E0, N +Int 1, safe:=true`, no requires |
| commit rows C/D `aOkT,aOkF` / `aOkF,_` with pools ok (reject, identity) | rows C-SS/D-SS: pattern `succP(G0), succP(E0)`, reject, no requires |
| commit row A `requires G <=Int 0 orBool E <=Int 0` (the complement) | TWO rows, disjoint by constructors: row A-Z* (`cntG = zeroP`, any `cntE`) and row A-SZ (`cntG = succP(G0), cntE = zeroP`), both reject, no requires |
| incoherent-tag complement `[owise] requires TG >=Int 2 orBool TG <=Int -1` | carried verbatim (the tag stays an Int — the 1P mechanism is retained) |

The gate/commit partition over pool heads: for each ground command shape
the rows cover `{zeroP, succP} × {zeroP, succP}` exactly once per bit
shape: gate (aOkT): A-Z, B-S; gate (aOkF): A-Z, C-S; commit (aOkT,aOkT):
A-Z*, A-SZ, B-SS; commit (aOkT,aOkF)/(aOkF,aOkT)/(aOkF,aOkF): A-Z*, A-SZ,
C-SS/D-SS. Disjointness is syntactic (distinct constructor heads at a
common position); exhaustiveness is free-constructor totality. The
generator (`phase1q/scripts/make_abs_q.py`) fail-closed-checks this cell
grid at generation time — the mechanized form of the 1P-F1 lesson (the
r2 first draft left one cell unmatched; here no cell can be silently
missing).

The runner keeps the TDRR discipline (branch-discriminated ground-command
rows; the stall discipline: NO exec rule on the tag-0 shadow; the [owise]
complement for the incoherent fragment) and REPLACES the TDRR Int fork
with the **constructor fork**: every tag-1 gate/commit runner row is
forked on the pool head constructors — e.g. for `aCommitJ(aOkT,aOkT)`
the four rows pattern `(zeroP,zeroP)`, `(zeroP,succP(E0))`,
`(succP(G0),zeroP)`, `(succP(G0),succP(E0))` in the `<absjshadow>` cell —
a REWRITE position, the position at which 1O/1P proved the checker does
discriminate constructors. The fork is exhaustive by free-constructor
totality (no arithmetic completeness question), needs no `requires`, and
after a fork row matches, the term handed to `absStepQ` has CONCRETE
constructor heads at exactly the positions the step rows discriminate —
function evaluation becomes direct matching.

## 3. The erasure and the correspondence obligations

```
syntax Int ::= countToInt ( PoolCount ) [function, total]
rule countToInt(zeroP)         => 0
rule countToInt(succP(N:PoolCount)) => countToInt(N) +Int 1
```

The refinement map, the coupling, and the C1–C5 obligations are specified
in `refinement-relation.md`. Summary of the honesty boundaries declared
here:

* **C1 (nonnegative representation).** Every `PoolCount` erases to a
  nonnegative Int. This is a structural-induction fact; the pinned
  toolchain has no mechanized structural induction over free constructors
  (the 1N/1O record). The general claim is ATTEMPTED and its residual
  recorded; concrete-depth witnesses (depths 0–5) are mechanized as
  bounded tests; wherever a downstream claim needs `countToInt(G) >=Int 0`
  it is carried as an EXPLICIT, DISCLOSED hypothesis, never silently.
* **The invariant translation.** The 1P invariant's tag-1 conjuncts
  `G >=Int 0 andBool E >=Int 0` have no Q counterpart because they are
  THEOREMS of the representation (C1), not invariant content: no
  well-sorted Q state can hold a negative pool. This is a re-encoding of
  the same safety content, not a weakening — the obligation that the
  safety MEANING is preserved is C4, and the weak-machine/mutant battery
  (mission §8) must break exactly where the 1P battery broke.
* **The forbidden decrement.** `zeroP` has no decrement. Every 1P row
  guarded by `>=Int 1` becomes a `succP`-patterned row; the 1P row-A
  complements become explicit `zeroP`-patterned rows. There is no
  `[owise]` fallback on any pool-guarded class: a pool shape either
  matches a row exactly or the machine has no row for it (and the
  generator-checked grid says it always does).

## 4. Non-goals and disclosed deviations from the 1P artifact

* The tag stays an Int (the 1P mechanism); only the pools move to
  constructors. Mixing a constructor tag into `PoolCount`'s sort discipline
  is out of scope.
* The toy (`proofs/repro/univ-repro-q*.k`) mirrors the 1P toy with ONE
  disclosed deviation: the 1P toy's invariant broke via arithmetic
  underflow (`iv -Int 1 < 0`), which the constructor encoding makes
  inexpressible by design; the Q toy's breaking command forges a receipt
  pre-init (`stQ(0, _) -> stQ(0, succP(_))`), violating the tag-0
  `iv ==K== zeroP` conjunct — the same "the bookkeeping says a receipt
  exists when it must not" shape as the real machine's weak-commit break
  (safe=false), at toy scale. Disclosed in the toy header.
* The machine files are GENERATED (`make_abs_q.py`) from the frozen 1P
  TDRR artifact, never hand-edited; the generator is deterministic
  (roundtrip-verified) and fail-closed.
