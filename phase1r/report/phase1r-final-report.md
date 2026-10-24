# SRW3 Phase 1R — Fold Decomposition, Bounded Prefixes, and Universal Safety
## Final Report

**Phase:** 1R — a controlled proof-decomposition experiment on
K v7.1.337 + z3 4.13.3 (the pinned toolchain, rebuilt from the pinned
recipe after the eighth sandbox reset; `audit/baseline-1r.md` §1).
**Verdict: COMPLETE — the Phase 1Q baseline, evidence reconciliation, and
timeout disposition are reproduced exactly; the bounded ladder, the
one-step theorem, and the full decomposition diagnosis are mechanized;
and the central open result of Phase 1Q — the machine-form universal
invariant-preservation theorem `1Q-UNIV-MACHINE-Q` — is MECHANIZED on the
pinned toolchain as `1R-UNIV-COMPOSED-QS` over the disclosed, semantics-
identical QS stall-row variant of the Phase 1Q machine of record
(non-vacuous, standalone, 12s, genuineness probed by depth-limited runs
and by the negative battery). The result is Level III (the abstract
constructor-count model): no consensus-integration claim, and the
toolchain's circularity caveats remain fenced and reproduced.**

---

## 1. Verdict

`COMPLETE` — every mission obligation (§2 baseline; §3 reconciliation;
§4 formal starting point; §5 Experiment A; §6 Experiment B; §7
Experiment C including C1–C4; §8 Experiment D; §9 the ten soundness
controls; §10 the evidence discipline; §11 the deliverables; §12 the
acceptance criteria) is discharged with retained evidence. The positive
universal theorem was NOT a condition of the mission; it was
nevertheless established — with its exact scope recorded in §7 below.

## 2. Exact repository state and commit

* Remote: `github.com/Dannyednut/SRW3`. The eighth sandbox reset had
  wiped the workspace; the repo was re-cloned fresh and every checkpoint
  verified on the fresh clone before any file was created.
* `origin/phase1q-constructor-pools` = `f6c510685220e1e13ab94761e2593d3e3a8dc482`
  (the Phase 1Q checkpoint of record); `origin/phase1p-branch-tag-encoding`
  = `83dd01571adccb77e51adcf5499c9a2480caaeaf`; `git merge-base --is-ancestor`
  verified (1Q descends from 1P; 1P's parent is the 1O freeze `cdb5556…`).
* Branch of record: `phase1r-fold-decomposition`, created FROM the
  verified 1Q commit; clean tree at creation.
* Toolchain: K v7.1.337 + z3 4.13.3 (the pinned recipe re-executed;
  versions printed in the rebuild log; sandbox-side script only).
* All new material under `phase1r/`; the only shared-file change is the
  root `worklog.md` entry (the established shared-file protocol). Frozen
  1N/1O/1P/1Q trees untouched (checked at commit time).

## 3. Phase 1Q baseline and evidence corrections

* **The claim-count discrepancy is RECONCILED: the corrected total is 83.**
  The proof runner (`phase1q/proofs/run_q_univ.sh`) lists exactly 81
  claims — the report §5 heading counted the runner's list. The ledger
  (`phase1q/claims/claims.csv`) carries 83 distinct claim rows: the 81
  runner-listed plus TWO manually executed claims —
  `1Q-STRONG-EMPTY-REJECT-STEP-Q` and `1Q-WEAK-W2-STEP-EVAL-Q` — both
  cited in the 1Q report §6 (controls 1 and 8), both with retained raw
  logs (21,963 and 22,744 bytes). The 1Q commit message already said 83;
  the summarizer gates on the CSV at 83; the scoreline (6 PROVED /
  46 PROVED-EVAL / 24 FAILED-STUCK / 5 TIMEOUT / 1 SELF-ASSUMED /
  1 UNSOUND-CLOSURE) matches. NO row was deleted or re-classified; the
  correction is a heading-count error in the 1Q report, documented in
  `audit/baseline-1r.md` §2.1 with a reproducible count.
* **The `1Q-UNIV-MACHINE-Q` evidentiary dispositions are established
  exactly** (`audit/baseline-1r.md` §2.2): the form-of-record and
  extended attempt logs are EMPTY (0 bytes) — with the runner's rc=124
  and the process records they support a TIMEOUT disposition and nothing
  stronger; the attempt1 log is NONEMPTY (24,929 bytes) and carries a
  real `DecidePredicateUnknown` decider residual — produced by the
  disclosed B-S-buggy pre-fix machine and superseded by the EQ-F′ fix;
  it is the 1Q record's decider-boundary evidence, not the form-of-record
  residual. No artifact establishes a proof residual or a counterexample
  for this claim.
* **The timeout disposition REPRODUCES LIVE** on the rebuilt toolchain:
  rc=124, wall 560s, empty log
  (`phase1r/transcripts/k/kprove_1Q-UNIV-MACHINE-Q-1r-repro.log` + `.rc`).
* The 1Q starting facts re-anchor on the retained evidence and by re-run:
  `1Q-UNIV-PREFIX-Q` PROVED non-vacuously (12s), `Q1F-TOY-UNIV-FORKED`
  PROVED non-vacuously (4s), the strong empty-commit reject step closes
  by evaluation, the summarizer gate over the 1Q ledger reproduces GREEN.
  Nothing was silently upgraded; the C1-conditional and C5-open
  obligations remain exactly where 1Q left them.

## 4. Results for each tested depth and the observed cost trend

The bounded-run formulation of record: for each concrete depth d, a
universal claim over the SYMBOLIC COMMAND SPINE of length d (every
command position symbolic; both pool tails arbitrary; the state symbolic
under `ABSInvQ`; the executable domain predicate pruning the
non-executable branches). No machine change; no hard-coded pipelines.

| depth | claim | terminal | wall | classification |
|---|---|---|---|---|
| 0 | `1R-BOUND-0-Q` | rc=0, zero triviality | 10s | BOUNDED-PROVED (fixed-depth theorem) |
| 1 | `1R-BOUND-1-Q` | rc=0, zero triviality | 12s | BOUNDED-PROVED — **also the one-step preservation theorem** |
| 2 | `1R-BOUND-2-Q` | rc=0, zero triviality | 32s | BOUNDED-PROVED |
| 3 | `1R-BOUND-3-Q` | rc=0, zero triviality | 287s | BOUNDED-PROVED |
| 4 | `1R-BOUND-4-Q` | rc=124 at the 560s ceiling | 560s | TIMEOUT (budget exceeded; never a refutation) |
| 5 | `1R-BOUND-5-Q` | — | — | UNATTEMPTED (recorded rationale: the trend is established; deeper rungs are strictly more expensive) |

**Cost trend:** 10 → 12 → 32 → 287 → ≥560s — super-linear growth
consistent with an unbounded-fold bottleneck. The symbolic transition
semantics are TRACTABLE at every fixed depth tested; the ladder is a
FINITE TEST at every rung, and no rung is the universal theorem (the
summarizer's BOUNDED-PROVED class enforces the labeling).

Destination controls over the same family: the depth-0 destination goal
closes (`1R-BOUND-0-DEST-Q`, 10s) and the depth-1 destination goal does
NOT close (`1R-BOUND-1-DEST-Q`, TIMEOUT — recorded as
TIMEOUT-NOT-A-PROOF; the non-circular falsity witness `1Q-NEG-DEST-Q`
fails in 10s) — the bounded family is not vacuously closable.

## 5. One-step preservation status

* **PROVED, non-trivially, in machine form:** `1R-BOUND-1-Q` — the single
  claim quantifying over ALL 12 ground command shapes and both branch
  families (tag-0/tag-1), the constructor fork, and the [owise]
  complement: `∀ s, c. ABSInvQ(s) ∧ Executable(cons(c,·), s) →
  ABSInvQ(step(s,c))`, 12s, zero `WarnTrivialClaim`. Exhaustiveness is
  witnessed behaviorally (the closed terminal with zero residual; the
  [owise] complement is IN the explored relation) and structurally
  (`phase1r/scripts/verify_grid_1r.py`: the frozen-source sha anchors,
  the 18-rule step partition with all declared rows verbatim, the single
  dispatch requires, the 4+16 fork cover, no Int pool arithmetic —
  `audit/grid-verification-1r.txt`).
* **The scoping diagnostic:** the naive "one-step" claim with a symbolic
  tail (`1R-STEP-ONE-Q`) TIMES OUT — the tail is consumed without bound,
  so that formulation is the full universal in disguise. Recorded; the
  correctly-scoped content is the d=1 rung.
* Per the mission's explicit warning: one-step preservation alone proves
  nothing about the fold — the composition is §6's separate obligation.

## 6. Fold-decomposition and induction status

* **C1 (the program datatype).** `APProg ::= aRunNilJ | aConsJ(ACmd,
  APProg)`; the fold `absRunFQ` is the standard structural recursion; the
  required induction is over the cons structure with the induction
  hypothesis parameterized by the threaded state — documented in
  `spec/fold-decomposition.md` §1–2.
* **C2 (the initialized fragment).** `1Q-UNIV-PREFIX-Q` is used only
  under its actual proved assumptions (the start-tag pin form of record —
  `absCfgPinnedQ(AX) ==K true` AND `absTagOfQ(AX) ==Int 1` AND the
  invariant AND executability), reproduced live (12s). The unpatched
  prefix form remains classified UNSOUND-CLOSURE and reproduces on the
  rebuilt toolchain (rc=0, 12s, zero warnings, semantically FALSE — the
  falsity witness `1Q-NEG-PREFIX-CEX-Q` fails as designed). The 1R
  result beyond 1Q: the tag-1-pinned universal with the FULL invariant
  conclusion (`1R-UNIV-TAG1-Q`, 12s, non-vacuous) — the PREFIX
  destination shape is not the ceiling.
* **C3 (the uninitialized fragment).** The decomposition diagnosis is
  mechanized and precise:
  1. the tag-0-pinned universal with symbolic pools TIMES OUT — the
     invariant's tag-0 pool conjuncts (isZeroP on variables) are
     undecidable at the circular side conditions (`1R-UNIV-TAG0-Q`);
  2. the normal-form formulation (every tag-0 invariant state is exactly
     `absStQ(0,false,false,zeroP,zeroP,0,SF,D)` — a disclosed meta-step)
     TIMES OUT on the 1Q machine — the pre-init STALL chain: the [owise]
     branch conditions never refine the command, the executable side
     conditions stay stuck, the engine unrolls without bound
     (`1R-UNIV-TAG0-NF-Q`; the kore-exec sqlog of record: 18,577
     condition-evaluation Z3 checks in 100s, breadth-first);
  3. the generated 12-member command-indexed family (the structural-
     induction schema made explicit; fail-closed generator
     `make_tag0_family_1r.py`): the exec members close VACUOUSLY-BY-DESIGN
     (the stall discipline — pre-init exec runs are non-executable),
     the identity members and even the init-accept member with TAG1
     trusted TIME OUT (`1R-T0F-*`); refusals preserve the pre-init state
     and diagnostics exactly as the machine's rows declare; stalled
     commands are never counted as executed transitions (the domain
     discipline, mechanized by `1R-QS-STALL-NONEXEC-Q` and `QTS-DOMAIN-FALSE`).
* **C4 (the composition).** The composition that the checker CAN
  mechanize is the UNPINNED claim over the QS variant — see §7. The
  composition the checker CANNOT mechanize on the 1Q machine of record
  is recorded with its exact residuals: the fold-form universal without
  circularity sticks with the residual = the missing structural
  induction (`1R-FOLD-FORM-OPEN-Q`); with circularity it ALSO sticks —
  the fold-level circular axiom does not self-apply on this toolchain
  (`1R-NEG-FOLD-SELF-Q`) — the fold form is not provable, neither
  soundly nor unsoundly. No circularity was used to assume the
  arbitrary-run conclusion.

## 7. Exact disposition of `1Q-UNIV-MACHINE-Q`

**MECHANIZED — as `1R-UNIV-COMPOSED-QS` over the disclosed QS variant of
the machine of record.** The chain of evidence:

1. **The diagnosis.** The 1Q failure (non-terminating circular
   exploration) is isolated to the PRE-INIT STALL: the Experiment-D toys
   show the state-threading domain predicate closes at toy scale
   (`QT-UNIV-THREADED`, 4s, non-trivial) while adding a stall command
   (no step row at tag 0; the [owise] complement covers) flips the same
   universal to FAILED-STUCK in 5s (`QTS-UNIV`) with the exact residual —
   the implication check fails over the [owise] branch's negated
   constructor equalities (`#Not({C #Equals addC}) …`, 22 unexplored
   branches) — the toy-scale form of the 1Q attempt1
   `DecidePredicateUnknown` signature.
2. **The refinement.** `phase1r/semantics/abs-machine-qs.k` (edit set
   ER-1, generated fail-closed by `make_abs_qs.py`): the FOUR explicit
   pre-init stall rows — on those cells the 1Q machine's [owise]
   complement already produces the identical transition, so the
   relation is UNCHANGED; the rows only REFINE the branch conditions so
   the executable side conditions evaluate. The machine of record is
   NOT modified.
3. **The semantics-preservation battery (5/5 PROVED).** The stall
   transition is the identity (`1R-QS-STALL-STEP-Q`, real rewriting);
   the stall run is non-executable (`1R-QS-STALL-NONEXEC-Q`); the 1Q
   strong empty-commit reject step re-run (`1R-QS-EMPTY-REJECT-STEP-Q`);
   the init-then-exec and honest-pipeline ground executions land on the
   exact 1Q end states (`1R-QS-RUN-INIT-EXEC-Q`,
   `1R-QS-RUN-HONEST-Q` — real rewriting, zero triviality).
4. **The theorem.** Over QS, the UNPINNED universal
   (`1R-UNIV-COMPOSED-QS`: requires `ABSInvQ(AX)` and
   `absExecutableQ(RUN,AX)`; ensures `ABSInvQ(?AX2)`; [circularity]; NO
   tag pin, NO normal form, NO trusted lemmas) closes NON-VACUOUSLY in
   12s, STANDALONE (identical closure re-run without `--trusted`).
5. **Genuineness is probed, not assumed.** `--depth 1` and `--depth 2`
   FAIL while the full proof closes — real unrolling happens and the
   PREFIX-UNPATCHED zero-progress self-application pattern is excluded;
   the falsity controls fail exactly as designed (the destination
   control, the prefix-CEX, the EQFORM-FALSE pair, the weak-machine
   universal — the invariant and the domain predicate are load-bearing);
   the UNSOUND-CLOSURE hole reproduces and remains fenced (arrow-form
   equalities only; Bool requires pinned).
6. **Scope, stated exactly.** The theorem is over the QS variant — the
   1Q machine of record plus four transition-relation-identical
   explicit rows — hence over the 1Q machine's transition relation. It
   is the Level III abstract constructor-count model: arbitrary finite
   pool counts, all twelve transition classes (init accept/reject, the
   authorized mint, the unauthorized and unsupported refusals, gate
   mint/refusal, commit accept/rejection, the stall/stutter discipline,
   init-accept the only 0→1 re-tag), arbitrary executable programs. It
   is NOT: the 1P integer-model theorem (the refinement direction
   Int→PoolCount remains undefined by design), a full refinement
   theorem, or any concrete SRW3 commitment-boundary result. The C1
   general nonnegativity and C5 checked-exhaustiveness obligations
   remain open exactly as 1Q left them and are NOT implied by this
   result. The toolchain's circularity caveat is recorded: a [circularity]
   closure is a coinductive proof whose validity depends on the claim's
   truth and the constraining requires — the negative battery is the
   permanent guard.

The 1Q TIMEOUT disposition itself is preserved unchanged (reproduced
live; the 1Q machine of record still does not close the claim within
budget — the QS stall-row refinement is the enabler).

## 8. Every negative-control outcome

| # | control | result of record |
|---|---|---|
| 1 | the weak machine accepts an invariant-breaking execution | `1Q-NEG-WEAK-UNIV-Q` FAILED (12s); `1Q-WEAK-BREAKING-RUN-Q` PROVED (the violation reachable); `1Q-NEG-WEAK-INV-Q` FAILED — the invariant is load-bearing |
| 2 | a false invariant goal cannot be classified as a proof | `1Q-DIAG-EQFORM-FALSE` FAILED; `1Q-DIAG-FALSE-HYP` FAILED; `1Q-NEG-DEST-Q` FAILED; `QT-UNIV-UNRESTRICTED` and `QT-BOUND-1-UNRESTRICTED` FAILED-STUCK (the forger admitted — the checker says so) |
| 3 | equality claims are in checked form | the arrow-form discipline throughout; the EQFORM pair reproduces (TRUE closes by evaluation; FALSE fails) |
| 4 | circularity claims have genuinely constraining start-state premises | `1Q-UNIV-PREFIX-UNPATCHED-Q` reproduces as UNSOUND-CLOSURE (rc=0, zero warnings, FALSE claim — the hole of record, fenced); the 1R circular claims carry the real invariant + the domain predicate; the COMPOSED-QS genuineness is depth-probed |
| 5 | an uninitialized run can refuse initialization and stay uninitialized | `1Q-NEG-PREFIX-CEX-Q` FAILED as designed (10s) |
| 6 | init-accept is the only 0→1 re-tag | the step partition (verify_grid_1r.py G3: all declared rows verbatim) + the one-step theorem's covered fork + the 1Q PRESV family of record; the QS battery's honest pipeline includes the re-tag with the exact end state |
| 7 | empty/single-receipt pool commit semantics retained | `1Q-STRONG-EMPTY-REJECT-STEP-Q` re-run (evaluation); `1R-QS-EMPTY-REJECT-STEP-Q` over QS; the B-SS structural accept unchanged in the frozen machine |
| 8 | every declared command/constructor case represented | the generated family enumerates all 12 ground shapes (F2 fail-closed); the OMIT mutant battery reproduces (`1Q-NEG-MUT-OMIT-GATEMINT/-C2` FAILED as designed); the fork cover (G5) |
| 9 | timeouts are never counterexamples | every rc=124 recorded as TIMEOUT with its budget (9 in the ledger); the MACHINE-Q reproduction is TIMEOUT, never a refutation |
| 10 | a bounded theorem is never relabelled as the universal | the summarizer's BOUNDED-PROVED class (7 claims) is distinct from PROVED (11); the ladder rows state the labeling contract; no claim is moved between classes |

The two 1Q tool holes remain exhibited and fenced on the rebuilt
toolchain: the no-arrow `==K` vacuity (the EQFORM pair) and the
non-constraining-Bool-requires unsound closure (the UNPATCHED exhibit
with its falsity witness).

## 9. Remaining count-refinement and concrete-correspondence obligations

Carried forward UNCHANGED from 1Q, none implied closed by the 1R result:

1. **C1 (general nonnegativity `countToInt(n) ≥ 0`)** — open; needs
   structural induction over the free constructor sort; the mechanized
   fragment is the concrete-depth witness (1Q) and every C1-dependent
   claim carries the disclosed hypothesis.
2. **C5 (free-constructor exhaustiveness as a checked claim)** — open;
   the mechanical evidence remains the generator's grid check
   (re-verified: `verify_grid_1r.py`) plus the OMIT mutant control.
3. **C2 at the arithmetic rows** — proved only WITH the disclosed
   C1-DEP hypotheses (the 1Q measurement stands).
4. **C4's rebuild direction (Int→PoolCount TAGCOMPLETE)** — undefined by
   design; the C4 content is carried by TAGSOUND + the per-class C2
   commutations.
5. **The full refinement theorem** (all-classes composition to the 1P
   integer image) — not claimed; conditional on C1/C5.
6. **The 1P obligations** — untouched: the 1P universal remains unproved
   THERE; the general 1P-TAGCOMPLETE was not mechanized; branch results
   ≠ the full refinement theorem; timeout-only unsafe-commit results do
   not establish rejection; the model is not connected to Ethereum
   consensus validation.
7. **The concrete SRW3 commitment boundary** — NO theorem at that
   boundary; the 1N SIM gap and the consensus-integration gap remain
   exactly where 1N/1O/1P/1Q left them.

## 10. Exact reproduction commands

```
# environment (the pinned recipe, idempotent, sandbox-side):
bash scripts/reinstall_toolchain_1m_r3.sh
source /home/z/my-project/tools/env.sh
export LIBRARY_PATH="$TOOLS/extract/syslibs:$LIBRARY_PATH"
cd /home/z/my-project/SRW3
INC="-I $PWD/phase1n/semantics -I $PWD/phase1m/semantics -I $PWD/phase1g/semantics \
     -I $PWD/phase1f/semantics -I $PWD/phase1e/semantics \
     -I $PWD/k/phase1d -I $PWD/k/kevm/kproj-e1e/plugin"

# the structural witness (pure reader):
python3 phase1r/scripts/verify_grid_1r.py

# the generators (fail-closed, roundtrip-verified; NEVER edit outputs):
python3 phase1r/scripts/make_abs_qs.py
python3 phase1r/scripts/make_tag0_family_1r.py

# the definitions:
kompile phase1q/semantics/abs-machine-q.k  --backend haskell \
  --main-module SRW3N-ABS-Q  $INC -o /tmp/p1q-q-def
kompile phase1r/semantics/abs-machine-qs.k --backend haskell \
  --main-module SRW3N-ABS-QS $INC -o /tmp/p1r-qs-def
# (+ the weak/toy/mutant definitions — phase1r/proofs/run_1r.sh stage B/N)

# the ladder and the battery (foreground batches; per-claim budgets):
bash phase1r/proofs/run_1r.sh B A AD ST FF N
bash phase1r/proofs/run_tag0_family.sh 3   # the vacuous-by-design member

# the central theorem (the claim of record; the standalone form):
kprove phase1r/proofs/n_r_univ_qs.k $INC -d /tmp/p1r-qs-def \
  --spec-module R-UNIV-QS-PROOFS --claims 1R-UNIV-COMPOSED-QS

# the genuineness probes:
kprove phase1r/proofs/n_r_univ_qs.k $INC -d /tmp/p1r-qs-def \
  --spec-module R-UNIV-QS-PROOFS --claims 1R-UNIV-COMPOSED-QS --depth 1   # FAILS
kprove phase1r/proofs/n_r_univ_qs.k $INC -d /tmp/p1r-qs-def \
  --spec-module R-UNIV-QS-PROOFS --claims 1R-UNIV-COMPOSED-QS --depth 3   # closes

# the gate:
python3 phase1r/scripts/summarize_1r.py    # GATE: GREEN, 53 claims
```

## 11. Whether a backend experiment is justified, and why

**A backend/proof-engine change is NO LONGER justified for the universal
theorem itself** — the mission's central question is answered positively
on the pinned toolchain by the QS stall-row refinement plus the unpinned
claim form; no engine change was needed. A backend capability WOULD
still be justified for two narrower obligations that the decomposition
exposed and the pinned toolchain cannot mechanize:

* the general C1 nonnegativity and C5 checked exhaustiveness (the
  structural induction over a free constructor sort — the standing
  1N/1O/1Q capability gap);
* the fold-form statement of the universal (the compositional proof the
  mission's C4 list preferred) — its residual is the exact missing
  induction hypothesis, mechanized as a record (`1R-FOLD-FORM-OPEN-Q`).

The minimal standalone example for any such comparison is the stall toy
of record (`phase1r/proofs/n_r_toy_stall.k`, `QTS-UNIV`: FAILED-STUCK in
5s with the negated-equality implication-check residual) against its
stall-free twin (`n_r_toy_threaded.k`, `QT-UNIV-THREADED`: PROVED in 4s)
— any candidate mechanism must close `QTS-UNIV` without losing the
falsity witnesses. Any backend experiment must follow the mission's §8
protocol: isolated, version-recorded, the baseline reproduced, the
positive AND negative controls re-run, and no case-count relaxation.

## 12. The smallest next defensible research step

Erase the C1-DEP conditionality: mechanize the count-erasure
correspondence C2 at the arithmetic rows WITHOUT the disclosed
`countToInt(_) ≥ Int 0` hypotheses, by lifting the 1R composition
architecture (the QS-style explicit-row refinement + the unpinned
circular form) onto the ERASURE-level mirror `absStepE` — the 1P rows
are already the frozen target semantics, and the 1R result provides the
constructor-side theorem whose erasure image is the missing direction.
That single step would convert the per-class C2 family (13/14, C1-DEP)
into the C1-free correspondence and set up the full refinement theorem
— the last Level III gap before any concrete-boundary work.

---

*Level III only; no consensus-integration claim. The claim ledger is
`phase1r/claims/claims.csv` (53 rows; the summarizer gate GREEN with
zero alarms); every claim's raw log is under `phase1r/transcripts/k/`;
the frozen Phase 1N–1Q artifacts are untouched.*
