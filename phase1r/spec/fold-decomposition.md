# SRW3 Phase 1R — Fold Decomposition, Bounded Prefixes, and the Universal Safety Architecture

(spec/fold-decomposition.md)

Phase: 1R. Toolchain of record: K v7.1.337 + z3 4.13.3 (pinned).
Status: EXPERIMENT SPEC + RESULTS OF RECORD (results sections updated by
the run; every result carries its raw log under `transcripts/k/`).
Level III only; no consensus-integration claim.

---

## 1. The formal starting point (the Phase 1Q objects, unchanged)

* Machine of record: `phase1q/semantics/abs-machine-q.k` (generated,
  fail-closed; sha256 `2e938fcb…` at the 1Q generation). The exact
  constructor count `PoolCount ::= zeroP | succP(PoolCount)`; the tagged
  state `absStQ(tg, cfgP, catP, cntG, cntE, nSlot, safe, diag)`; the
  twelve-class step `absStepQ` with constructor pool patterns and NO pool
  requires; the branch-discriminated runner with the CONSTRUCTOR FORK; the
  conjunctive invariant `ABSInvQ` (+ `tagCoherentQ`).
* Program datatype (1Q §B, the 1P syntax verbatim):
  `APProg ::= aRunNilJ | aConsJ(ACmd, APProg)`;
  `ACmd ::= aInitJ(AOk) | aExecJ(AOk,ASrc) | aGateJ(AOk) | aCommitJ(AOk,AOk)`
  (8 ground command shapes).
* The fold: `absRunFQ(aRunNilJ, AX) = AX`;
  `absRunFQ(aConsJ(AC,R), AX) = absRunFQ(R, absStepQ(AX, AC))`.
* The domain predicate: `absExecutableQ` — the EQ-F′ explicit total
  constructor cover; it THREADS THE STATE: the exec row is
  `absExecutableQ(aConsJ(aExecJ(A1,A2), R), absStQ(1,C,T,G,E,N,SF,D))
   => absExecutableQ(R, absStepQ(absStQ(1,…), aExecJ(A1,A2)))`.
* The invariant safety predicate: `ABSInvQ` (conjunctive; the tag-1 pool
  conjuncts removed — structural nonnegativity is C1, still open in general).

## 2. The open central result and its failure mode

`1Q-UNIV-MACHINE-Q` — universal invariant preservation for every executable
program over the complete machine:

```
∀ RUN AX. ABSInvQ(AX) ∧ absExecutableQ(RUN, AX) → ABSInvQ(absRunFQ(RUN, AX))
```

stated as a `[circularity]` reachability claim over the runner. Its 1Q
failure is NOT a stuck guarded transition (the 1P failure): every covered
branch evaluates. The failure is non-terminating exploration of the
circular branch tree (560s foreground ceiling; a detached kore-exec phase
ran 35+ min at one core without terminating — `audit/baseline-1r.md` §2.2).

**The 1R diagnosis target.** Two structural facts distinguish the open
claim from the toy universal that DID close (`Q1F-TOY-UNIV-FORKED`, 4s,
same `[circularity]` architecture, 5 commands / 1 pool / no state
threading):

* (F1) **branch factor**: the Q runner forks every tag-1 gate/commit over
  the 2×2 pool-head grid — ~34 row shapes per unrolling vs the toy's ~7;
* (F2) **state-threading in the domain predicate**: `absExecutableQ`'s
  side condition after one unrolling is
  `absExecutableQ(R, absStepQ(AX′, AC))` — to VERIFY the circular axiom's
  side condition the checker must reduce `absStepQ` on the successor; if
  the successor's branch shape is not already pinned by a literal (e.g. on
  the `[owise]` identity branch, where the state stays the SYMBOLIC
  variable AX), the reduction is stuck and the side-condition check cannot
  complete — the engine's remaining move is to unroll again, and the
  exploration never terminates.

The tag-pinned PREFIX corollary (`1Q-UNIV-PREFIX-Q`, 18s) is consistent
with (F2): pinning `absTagOfQ(AX) ==Int 1` (and, critically, pinning it in
a form the side-condition check can USE at the fork — the rows pattern the
tag literal directly) makes every successor's branch shape literal, so the
threaded reductions complete and the circularity terminates.

## 3. The decomposition architecture under test

The proof strategy of record for the universal theorem, split into
mechanizable fragments (Experiments A–C of the mission):

* **A. Bounded diagnostics** — the depth ladder. For each concrete depth
  d, the claim `1R-BOUND-<d>-Q` states the universal over the symbolic
  command SPINE of length d
  (`aConsJ(AC1, aConsJ(AC2, … aConsJ(ACd, aRunNilJ)))`, every `ACi:ACmd`
  symbolic — the pool tails and all other state fields stay symbolic):
  requires `ABSInvQ(AX)` + executability of the spine, ensures
  `ABSInvQ(?AX2)`. These are FIXED-DEPTH THEOREMS (finite unrolling +
  evaluation; correctly labelled, never the universal). The ladder measures
  the growth of the finite exploration with depth — the empirical test of
  whether the full universal's failure is an unbounded-fold bottleneck.
* **B. One-step preservation** — `1R-STEP-ONE-Q`: the single transition-
  preservation claim over ALL commands
  (`∀ s c. Safe(s) ∧ Executable(cons(c,·), s) → Safe(step(s,c))`) in
  machine form, no circularity: the runner's finite fork + the covered
  step rows + the invariant evaluation per successor. Exhaustiveness: the
  runner's row structure (the `[owise]` complement is IN the explored
  relation) + the generator's cell-grid check + zero unexplored branches
  at the terminal. This is ONE STEP ONLY — by itself it proves nothing
  about arbitrary runs (the composition is Experiment C's obligation).
* **C. The fold decomposition** — the initialized/uninitialized split:
  1. `1R-UNIV-TAG1-Q` — the tag-1-pinned universal invariant theorem
     (PREFIX-Q's big sibling: same requires pins, ensures `ABSInvQ(?AX2)`
     instead of the destination shape). If (F2) is the blocker, this
     closes: every unrolling's successor has literal branch shape.
  2. `1R-UNIV-TAG0-Q` — the tag-0-pinned universal: from a coherent tag-0
     state, every executable step is an identity/diag row until the
     init-accept, whose successor is the FULLY CONCRETE
     `absStQ(1,true,true,zeroP,zeroP,0,true,D)`; the tag-1 tail is then
     governed by the PROVED `1R-UNIV-TAG1-Q` (in scope as a proved
     lemma — the trusted-lemma discipline: proved first, imported, its
     trust boundary is "the pinned checker accepted its proof").
  3. `1R-UNIV-COMPOSED-Q` — the UNPINNED universal with both pinned
     universals in scope: the start tag forks at the first unrolling
     (the rows pattern the tag literal), each branch is an instance of a
     pinned lemma. This is the mission's "state-branch decomposition with
     an explicit transition-to-initialized-suffix argument".
  If the composition is not supported by the checker, the exact failed
  obligation is retained and characterized (the fallback diagnosis: the
  bounded-fold definition makes the missing induction hypothesis explicit).

## 4. What would and would not be proved (the labeling contract)

* A depth-d spine claim is a **fixed-depth theorem**. The ladder is a
  **finite test** at every d. Neither is the universal.
* `1R-STEP-ONE-Q` (if closed) is a **non-trivial one-step theorem**; the
  full fold needs the composition (Experiment C) — never conflated.
* The composition (if closed) establishes the universal ONLY for the 1Q
  constructor-count model, under the disclosed C1-conditional fragment
  (the C1-DEP rows remain conditional) and the C5 grid-check discipline —
  the same boundary as the 1Q record.
* Timeouts are never refutations. Vacuous/no-arrow forms are forbidden
  (the 1Q holes remain fenced: arrow-form equalities only; Bool requires
  pinned with `==K true`).

## 5. Results of record

Filled by the run; every row cites its raw log (`transcripts/k/`) and its
ledger row (`claims/claims.csv`; the summarizer gate is GREEN —
`audit/summarizer-gate-1r.txt`).

* **The bounded ladder (Experiment A).** d=0,1,2,3 close as fixed-depth
  theorems in 10s / 12s / 32s / 287s (zero triviality warnings; real
  unrolling). d=4 exceeds the 560s sandbox ceiling (TIMEOUT — budget
  exceeded, never a refutation); d=5 unattempted with recorded rationale.
  The symbolic transition semantics are tractable at every fixed depth
  tested, and the cost growth is consistent with the unbounded-fold
  bottleneck hypothesis. d=1 is ALSO the correctly-scoped ONE-STEP
  preservation theorem (Experiment B): all 12 command shapes, both branch
  families, the fork, the complement — one claim, non-vacuous.
* **The naive one-step probe (Experiment B).** The cons-headed claim with
  a symbolic tail (`1R-STEP-ONE-Q`) TIMES OUT: the <k> tail is consumed
  without bound — that formulation is the full universal in disguise.
  Recorded as the scoping diagnostic; the one-step content of record is
  the d=1 ladder rung.
* **The tag-1-pinned universal (Experiment C).** `1R-UNIV-TAG1-Q` (1Q
  machine) and `1R-UNIV-TAG1-QS` (QS variant) close in 12s each,
  non-vacuously — the initialized fragment's universal invariant theorem
  is mechanized (strictly beyond the 1Q PREFIX destination corollary,
  whose start-state assumptions are the form of record and are reproduced).
* **The tag-0 fragment (Experiment C).** Three formulations attempted
  (symbolic pools; the disclosed normal form; the generated 12-member
  command-indexed family): NONE closes. The mechanized diagnosis:
  * the tag-0 rows preserve the pool variables, so the invariant's tag-0
    conjuncts (isZeroP on variables) are undecidable at the circular side
    conditions (`1R-UNIV-TAG0-Q`);
  * the pre-init STALL (commands with no step row at tag 0) creates
    [owise] branches whose negated-constructor-equality conditions never
    refine the command — the executable side conditions stay stuck and
    the engine unrolls without bound (the kore-exec sqlog of record:
    18,577 condition-evaluation Z3 checks in 100s, breadth-first);
  * even the proved-lemma hand-off (TAG1 trusted at the init-accept
    member) does not stop the tail exploration (`1R-T0F-1-QS-Q`).
* **The isolation toys (Experiment D).** The forked toy's universal with
  the state-THREADING domain predicate CLOSES (`QT-UNIV-THREADED`, 4s,
  non-trivial) — threading is NOT the trigger. Adding a STALL command
  (no step row at tag 0; the [owise] complement covers; the executable
  predicate excludes the run) flips the toy universal to FAILED-STUCK in
  5s (`QTS-UNIV`) with the exact residual: the implication check fails
  over the [owise] branch's negated constructor equalities
  (`#Not({C #Equals addC}) …`, 22 unexplored branches) — the toy-scale
  form of the 1Q attempt1 `DecidePredicateUnknown` phenomenon. THE
  PRE-INIT STALL IS THE ISOLATED TRIGGER. The unrestricted threading
  predicate's falsity witnesses behave as designed (the forger is
  admitted and the checker says so).
* **The QS variant and the composed universal (Experiment C, the central
  result).** The additive stall-row variant (`abs-machine-qs.k`, ER-1:
  the four explicit pre-init stall rows — semantics-identical to the 1Q
  machine by construction and by the 5-claim battery, including the
  honest-pipeline ground execution) removes the stall branch's symbolic
  negation conditions. On QS the UNPINNED universal
  (`1R-UNIV-COMPOSED-QS`: requires `ABSInvQ(AX)` +
  `absExecutableQ(RUN,AX)`, ensures `ABSInvQ(?AX2)`, [circularity], NO
  tag pin, NO normal form, NO trusted lemmas) closes **non-vacuously in
  12s, standalone**. Genuineness is probed, not assumed: `--depth 1` and
  `--depth 2` FAIL while the full proof closes — real unrolling happens;
  the PREFIX-UNPATCHED self-application pattern is excluded; the falsity
  controls (destination, prefix-CEX, weak-machine universal, the EQFORM
  pair) all fail exactly as designed.
* **The fold-form exhibits.** Without circularity the fold-form universal
  sticks with the residual = the missing structural induction over
  APProg (`1R-FOLD-FORM-OPEN-Q`, 11s); WITH circularity it ALSO sticks —
  the circular axiom does not self-apply at the fold level on this
  toolchain (`1R-NEG-FOLD-SELF-Q`) — the fold form is simply not
  provable, neither soundly nor unsoundly.
* **The universal disposition.** `1Q-UNIV-MACHINE-Q`'s timeout disposition
  reproduces live (rc=124, 560s, empty log). Its obstruction is
  RESOLVED on the semantics-identical QS variant by the composed
  universal: the machine-form universal invariant-preservation theorem
  for arbitrary executable programs over the complete constructor-count
  machine is MECHANIZED on the pinned toolchain — at Level III, on the
  abstract model, with the QS refinement disclosed and battery-proved,
  and with the toolchain's circularity caveats (the UNPATCHED hole
  reproduces and remains fenced) recorded.
