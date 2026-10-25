# SRW3 Phase 1S — Constructor-Count Semantics: the C1 Obligations (spec/count-semantics.md)

Status: the formal statements and dispositions of record for mission §3.
The lemmas live in `phase1s/proofs/n_s_count_semantics.k` (plus the
generated depth family `n_s_c12_family.k` from
`scripts/make_c12_family_1s.py`). Every disposition below is whatever the
checker actually did — nothing is relabeled.

The subject function is the frozen 1Q definition:

```
countToInt(zeroP)            = 0
countToInt(succP(p))         = countToInt(p) + 1
```

## C1.1 — The elimination equations

* `1S-C1.1-EQ0`: `countToInt(zeroP) ==Int 0`. **PROVED** by evaluation.
* `1S-C1.1-EQ1`: `countToInt(succP(P)) ==Int countToInt(P) +Int 1` for
  symbolic `P : PoolCount`. **PROVED** by evaluation — the rule matches on
  the CONSTRUCTOR-HEADED argument, so no induction is needed; the tail
  stays symbolic. (Frontend probe `PROBE-COUNT-SYMB` established the
  mechanism; the battery row is the of-record proof.)

## C1.2 — Nonnegativity (`countToInt(p) >=Int 0`)

The pivotal honesty obligation of the phase. Mechanical status on the
pinned toolchain (K v7.1.337 — no structural induction over
function-argument constructor variables; the boundary recorded since 1O
and re-confirmed by the 1R isolation ladder):

* `1S-C1.2-UNIV` — the universal `∀P:PoolCount. countToInt(P) >=Int 0`:
  **ATTEMPTED, FAILED-STUCK** (rc=1 in 10 s; residual retained) — the
  structural-induction boundary confirmed live on the pinned toolchain.
  Recorded, never relabeled, never counted as a counterexample.
* The two constructor cases, mechanized separately:
  - `1S-C1.2-CASE-ZERO`: `countToInt(zeroP) >=Int 0` — **PROVED** (evaluation).
  - `1S-C1.2-CASE-SUCC`: `countToInt(succP(P)) >=Int 0` requires
    `countToInt(P) >=Int 0` — **PROVED** (evaluation + arithmetic). This is
    the induction STEP as a CONDITIONAL lemma; the hypothesis IS the
    induction hypothesis. It is a lemma ABOUT the step, not the universal.
* `1S-C1.2-SLACK`: the wrapped-slack propagation
  (`countToInt(succP(succP(E0))) >=Int 0` from
  `countToInt(succP(E0)) >=Int 0`) — **PROVED**. This is the shape that
  discharges the mint classes of the invariant chain WITHOUT C1.2.
* `1S-C1.2-FAMILY-D0..D5` (generated): the depth-k family
  `countToInt(succP^k(zeroP)) >=Int 0` for k = 0..5 — **PROVED** each
  (evaluation) — the BOUNDED-PROVED evidence class.
* `1S-C1.2-SELF-ASSUMED` (negative control, `tests/n_s_neg.k`): the claim
  `countToInt(P) >=Int 0 requires countToInt(P) >=Int 0` — closes
  trivially and is classified **SELF-ASSUMED-NOT-A-PROOF** (the 1Q
  discipline). It is NEVER cited as evidence for C1.2.
* **The minimal counterexample-free induction experiment** (mission §3):
  (i) the two conditional case lemmas above (the step, mechanically
  closed); (ii) the depth family (the base chain, mechanically closed);
  (iii) the Python mirror sweep `scripts/mirror_c12_sweep.py`: every
  `PoolCount` term up to depth 5 (2^5 = 63 distinct shapes, generated
  canonically) evaluates to a nonneg integer — no counterexample exists in
  the bounded space; (iv) the falsity probe: substituting a HYPOTHETICAL
  negative-inhabiting interpretation is impossible BY SORT — `PoolCount`
  has exactly two constructors and no negative inhabitants, so the
  residual is a proof-engineering boundary, not a semantic doubt. The
  residual statement of record: *the universal C1.2 is true, has no
  counterexample at any explored depth, its induction step closes
  conditionally, and the pinned toolchain cannot compose them into the
  universal — the missing ingredient is structural induction over
  function-argument constructor variables.*
* **Assumption discipline (mission §3's explicit allowance):** where a
  downstream claim NEEDS C1.2, the claim is run in a C12-ASSUMED form with
  the axiom `countToInt(P) >=Int 0` introduced via `--trusted`
  (`1S-C12-NONNEG-ASSUMED`, ledger class ASSUMPTION) and the dependent
  result is classified **PROVED-UNDER-C1.2-ASSUMPTION** — never as an
  unconditional theorem. The NODEP probes record exactly which classes do
  NOT need it.

## C1.3 — Exact increment correspondence (the mint classes)

Stated in the functional image form (`spec/state-correspondence.md` §3):
`eraseQ(absStepQ(SQ, c)) ==K absStepE(eraseQ(SQ), c)` with the class's
constructor pattern pinned on `SQ`.

* `1S-C1.3-EXE-MINT` (exec-mint, `E = succP(E0)`): LHS interprets
  `succP(succP(E0))` → `countToInt(E0) + 2`; RHS adds 1 to
  `countToInt(succP(E0))` → `countToInt(E0) + 2`. **PROVED** by evaluation
  + arithmetic (rc=0). No C1.2 dependence (the equality is exact for
  arbitrary symbolic tails; nonnegativity is not invoked).
* `1S-CORR-GATE-MINT-COND` (gate-mint, `E = succP(E0)`, `aOkT`): the G pool
  wraps (`succP(G)`); the E pool is kept. **PROVED** in the C12-CONDITIONAL
  form (rc=0; the requires carried as an explicit hypothesis on the WRAPPED
  count) and the unconditional `NODEP` probe is recorded with its exact
  residual (rc=1: the requires-fire needs `countToInt(E0) >=Int 0`).

## C1.4 — Exact decrement correspondence (commit-accept; the size-one boundary)

* `1S-CORR-COMMIT-ACCEPT-COND` (both pools successor-headed, accept bits):
  LHS strips both wrappers (`countToInt(G0)`, `countToInt(E0)`, `N + 1`,
  safe=true); RHS subtracts 1 from each wrapped interpretation
  (`(countToInt(G0)+1) -Int 1`, `(countToInt(E0)+1) -Int 1`). **PROVED**
  by evaluation + integer arithmetic (`(x+1)-1 == x`), in the
  C12-CONDITIONAL form (rc=0; the integer row-B requires
  `countToInt(succP(G0)) >=Int 1 ∧ countToInt(succP(E0)) >=Int 1` carried
  as an explicit hypothesis — which is EXACTLY the wrapped hypothesis, so
  the post-state nonnegativity `countToInt(G0) >=Int 0` follows by
  arithmetic from the hypothesis WITHOUT the universal C1.2).
  The preservation form `1S-PRESV-INT-COMMIT-ACCEPT-COND` closes the same
  way (rc=0).
* `1S-C1.4-SIZEONE` content is carried by the guard-grid row
  `1S-COV-E-COMMIT-B-AT11` (both pools exactly one: post counts 0, 0 on
  BOTH sides — rc=0, evaluation): the boundary where the Int decrement
  lands exactly on zero and the constructor strip lands exactly on
  `zeroP`.
* `1S-CORR-COMMIT-ACCEPT-NODEP` (the dependence probe): the same equality
  WITHOUT the wrapped hypothesis — rc=1 FAILED-STUCK (the mirror step is
  stuck between row B and row A; the divergence cell is NOT refutable
  without C1.2). The C1-dependence of the commit-accept class is thereby
  MEASURED, not assumed away (the 1Q GATE-MINT-NODEP discipline).

## C1.5 — Empty-pool correspondence

* `1S-C1.5-FWD` (⇐: structural emptiness → integer zero): `isZeroP(G)`
  with `G` pinned `zeroP` gives `countToInt(G) ==Int 0`. **PROVED**
  (evaluation). The constructor-pinned form is the honest general form:
  the unpinned Boolean-hypothesis form would need the solver to case-split
  a function-argument variable (not available).
* `1S-C1.5-BWD-COND` (⇒: integer zero → structural emptiness), the
  C1.2-conditional form: `isSuccP(P) andBool countToInt(P) +Int 1 ==Int 0`
  is contradictory GIVEN `countToInt(P) >=Int 0`. Mechanized as the
  wrapped-form lemma `countToInt(succP(P)) >=Int 1` requires
  `countToInt(P) >=Int 0` — **PROVED** (evaluation + arithmetic); the
  unconditional form depends on C1.2 and is recorded in the NODEP probe.
* `1S-C1.5-GATE-EMPTY-CORR` (the empty-cell correspondence, gate class):
  the Q row A-Z (`E = zeroP`) and the integer row A (`E' <=Int 0` with
  `E' = countToInt(zeroP) = 0`) agree exactly on the post-state
  (`adGate`, pools unchanged). **PROVED** by evaluation. This is the
  load-bearing direction for the coverage partition's cross-model
  agreement on the empty cell.
* The zeroP-has-no-decrement boundary is exercised as a negative control
  (`1S-NEG-DEC-FROM-ZERO`, `tests/n_s_neg.k`): the fabricated claim that
  the step strips a `zeroP` pool FAILS — no rule strips `zeroP`.

## The dependence ledger (measured, not assumed)

| class | closes WITHOUT C1.2? | reason |
|---|---|---|
| C1.1 both | YES | evaluation on constructor-headed arguments |
| mint classes (wrap) | YES | `PROBE-SLACK` arithmetic-slack propagation |
| init-accept / identity / diag classes | YES | concrete post-states |
| gate empty / pre-init cells | YES | `countToInt(zeroP) = 0` fires the Int rows by evaluation |
| commit-accept (strip × 2) | **NO** — C12-CONDITIONAL | the post-state nonnegativity is the inner count; the wrapped hypothesis gives only `>= -1`; the divergence cell (Q strips vs Int row-A stutter) is refuted only by C1.2 |
| gate-mint / gate-refuse requires-fire | **NO** — C12-CONDITIONAL | the Int requires `E' >=Int 1` from `succP(E0)` needs `countToInt(E0) >=Int 0` |
| C1.2 universal itself | — | the structural-induction boundary (residual of record) |
