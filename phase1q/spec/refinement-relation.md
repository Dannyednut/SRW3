# SRW3 Phase 1Q — The Refinement Relation and the C-Obligations

**Phase:** 1Q — the correspondence between the constructor-count machine
(`SRW3N-ABS-Q`) and the Phase 1P integer-counter semantics.
Level III only; no consensus-integration claim. Every mechanized status in
this file is backed by a raw log under `phase1q/transcripts/k/`; where a
claim is open, its exact residual is the record.

---

## 1. The erasure target

`SRW3N-ABS-Q` declares a local mirror sort (the 1P edit-EG discipline — the
1P module cannot be imported without importing its runner rules, which
would contaminate the Q machine's reachability):

```
syntax AStateQE ::= absStQE ( cfgP:Bool, catP:Bool
                           , cntG:Int, cntE:Int      // the INTEGER image
                           , nSlot:Int, safe:Bool, diag:ADiag )
```

`absStQE` is field-isomorphic to the 1P TDRR state `absStT` minus the tag
(the same relationship `absStE` had to the 1N `AState`); the generator
verifies the field correspondence against the frozen TDRR rule table at
generation time. The Int-image step `absStepE` mirrors the 1P `absStepT`
TDRR rows verbatim (Int pools, the requires split, the [owise] tag
complement) so that the correspondence claims below compare against the
EXACT 1P integer semantics, not an approximation.

## 2. The maps

```
syntax Int ::= countToInt ( PoolCount ) [function, total]
rule countToInt(zeroP)              => 0
rule countToInt(succP(N:PoolCount)) => countToInt(N) +Int 1

syntax AStateQE ::= eraseQ ( AStateQ ) [function, total]
rule eraseQ(absStQ(_:Int, C:Bool, T:Bool, G:PoolCount, E:PoolCount,
                   N:Int, SF:Bool, D:ADiag))
  => absStQE(C, T, countToInt(G), countToInt(E), N, SF, D)

syntax AStateQ ::= tagQE ( AStateQE ) [function, total]
rule tagQE(absStQE(C:Bool, T:Bool, G:Int, E:Int, N:Int, SF:Bool, D:ADiag))
  => absStQ(branchTag(C, T), C, T, countToPool(G), countToPool(E), N, SF, D)
```

with `countToPool(0) = zeroP` and `countToPool(N +Int 1) = succP(countToPool(N))`
— the inverse direction. `branchTag(true,true)=1`, `branchTag(false,false)=0`
(the 1P map, carried verbatim).

The tag-dropping in `eraseQ` follows the 1P design: the tag is a function
of the bits (`branchTag`), so the erasure is faithful on coherent states
(TAGSOUND/TAGCOMPLETE below), and the roundtrip `tagQE(eraseQ(s)) ==K s`
holds exactly on the coherent fragment.

## 3. The correspondence invariant

```
CorrQ(s: AStateQ, x: AStateQE)
  ≡ eraseQ(s) ==K x  andBool  ABSInvQ(s)  andBool  ABSInvE(x)
```

where `ABSInvE` is the 1P invariant over the mirror (the generator-checked
translation of `ABSInvT` with `branchTag(C,T)` substituted for the tag) —
i.e. the refinement relates each Q state to the 1P state with the SAME
bits, slot count, safe bit, diagnostic, and the pools erased through
`countToInt`, BOTH sides satisfying their own invariant.

## 4. The obligations (mission C1–C5) and their declared proof vehicles

**C1 — Nonnegative count representation.**
`countToInt(N:PoolCount) >=Int 0` for all N.
* Vehicle: kprove attempt (the general claim).
* Expected mechanism: structural induction over the free constructor sort —
  which the pinned backend lacks (the 1N/1O/1P record: circularity does not
  self-apply at the function level). The claim is ATTEMPTED anyway; if it
  sticks, the residual is recorded and the obligation stays OPEN, with the
  concrete-depth witnesses (zeroP, succP^1..succP^5 → nonnegative literals,
  PROVED by evaluation as BOUNDED TESTS, classified as such) as the
  mechanized fragment.
* Discipline: any downstream claim that needs `countToInt(_) >=Int 0`
  carries it as an explicit disclosed hypothesis (marked C1-DEP), never as
  a silent assumption. A C1-DEP claim is NOT a proof of the C1-free form;
  both statuses are recorded separately in `claims/claims.csv`.

**C2 — Step correspondence (per class).**
For each of the twelve classes (and each pool-head branch of the
gate/commit classes):
`eraseQ(absStepQ(s, c)) ==K absStepE(eraseQ(s), c)`.
* Vehicle: per-class kprove claims patterned on the exact class shape
  (constructor heads in the state pattern, no pool requires on the Q side),
  with the C1-DEP coupling `countToInt(G0) >=Int 0 andBool countToInt(E0)
  >=Int 0` where the 1P row's own `>=Int 1` guard must evaluate against
  the erased symbolic count (it becomes `(countToInt(G0)+1) >=Int 1`, whose
  z3 validity needs exactly C1).
* A class whose correspondence claim cannot close is recorded as an
  INDEPENDENT OPEN OBLIGATION with its residual — per the mission, a
  passing Q-side invariant proof must never be presented as closing these.

**C3 — Acceptance correspondence.**
`isNonzeroQ(G) ≡ (countToInt(G) >=Int 1)` whenever the coupling holds —
more precisely both directions over the coupled fragment:
(a) `succP(G0)` ⇒ `countToInt(succP(G0)) >=Int 1` (needs C1 for the tail);
(b) `countToInt(G) >=Int 1` ⇒ G is `succP`-headed (contrapositive over the
`zeroP` case: `countToInt(zeroP) = 0` contradicts `>=Int 1` — mechanizable
by the constructor case split IF the engine performs it; attempted, residual
recorded otherwise).
Concrete-depth witnesses mechanized as bounded tests.

**C4 — Invariant correspondence.**
The Q invariant preserves the 1P invariant's safety meaning:
(a) TAGSOUND-Q: `ABSInvE(eraseQ(s))` (the erased 1P invariant holds) —
    the erased meaning of ABSInvQ on coherent states;
(b) TAGCOMPLETE-Q-B1/B2: conversely, the erased invariant + branch bits
    rebuild a Q-invariant state via `tagQE`;
(c) the general TAGCOMPLETE-Q form (no branch pin): ATTEMPTED, residual
    recorded — the 1P record predicts the disjunctive-form stick.
The re-encoding honesty: the 1P tag-1 conjuncts `G >=Int 0 andBool
E >=Int 0` are theorems of the representation (C1), not invariant content;
C4(a) over the coupled fragment is the exact statement that the Q
invariant's erased meaning CONTAINS the 1P invariant's content.

**C5 — Transition completeness.**
The partition is exhaustive and disjoint:
(a) GENERATOR-CHECKED (mechanical, deterministic, fail-closed): the cell
    grid {class × pool-head × bit-shape} is covered exactly once per
    reachable shape — the make_abs_q.py completeness check, recorded in
    `audit/`;
(b) the free-constructor exhaustiveness `G ==K zeroP orBool isSuccP(G)`:
    ATTEMPTED as a claim (it is the same function-argument constructor
    split the 1O record says the engine lacks; residual recorded);
(c) the OMIT-CASE control (mission §8 #10): a mutant with one partition
    row deleted must FAIL the correspondence/execution witness — proving
    the grid check is load-bearing, not decorative.
Disjointness: syntactic (distinct constructor heads at the discriminating
position); mechanized fragment: the per-class PRESV/COH families close
only because exactly one row matches each claimed shape.

## 5. What would and would not be proved

If the universal claim `1Q-UNIV-MACHINE-Q` closes non-trivially (real
rewriting through the fork, no vacuity alarm), THAT establishes:

* the UNIVERSAL THEOREM FOR THE CONSTRUCTOR-COUNT MODEL (the Q abstract
  machine): every `absExecutableQ` program run from an `ABSInvQ` state
  lands in an `ABSInvQ` state, on K v7.1.337, mechanized;

it does NOT by itself establish:

* the theorem for the 1P INTEGER model — that requires the C2/C3/C4
  refinement to be closed WITHOUT open obligations (any C1-DEP hypothesis
  left open keeps this a conditional result, stated exactly as
  conditional in the report);
* the concrete SRW3 commitment-boundary theorem — the 1N SIM gap (the
  B5'/cascade boundary) and the consensus-integration gap remain open,
  carried forward from 1N/1O/1P untouched.

These three results are different claims and are reported separately.
The 1P open obligations (universal theorem unproved there, the general
1P-TAGCOMPLETE not mechanized, branch results ≠ full refinement, timeout-
only unsafe-commit results, no consensus validation) remain open and are
not closed by any 1Q artifact.
