# SRW3 Phase 1P — Branch-Tagged Invariants and Universal Transition Preservation
## Final Report (RECONSTRUCTION r2)

**Phase:** 1P — a controlled proof experiment on the K v7.1.337 universal
transition-preservation theorem.
**Verdict: PHASE 1P (r2) COMPLETE AS AN EXPERIMENT — THE UNIVERSAL THEOREM
REMAINS NOT MECHANIZED, and the residual frontier is now located more
precisely than the 1O record left it. No completion tag. Level III only; no
consensus-integration claim.**

---

## 0. Reconstruction disclosure (read first)

The Phase 1P r1 working tree was lost to a sandbox reset before any commit
or push: the workspace reverted to its Phase-1D-era snapshot, the clone at
the 1O freeze (cdb5556) was destroyed, and the remote carried no phase1p
ref. A filesystem sweep and the persisted session artifacts confirmed that
no r1 byte survived. This r2 tree is a re-derivation from the recorded r1
design summary (the design was fully specified before the loss), executed
entirely fresh: fresh clone at cdb5556, toolchain rebuilt from the pinned
recipe (K v7.1.337 + z3 4.13.3, `TOOLCHAIN_R3_DONE`), every result below
produced by live kprove runs in this reconstruction. The r1 edit labels
E1–E8 are superseded by the disclosed r2 edit set EA–EH (+EE′). Where r2
and the r1 record agree, that agreement is reproduction evidence; where
they differ (§4, finding 1P-F2), the r2 raw log decides and the difference
is documented, not hidden. Full detail: `audit/baseline-1p.txt`,
`spec/branch-tag-design.md` §0/§9.

## 1. The question

Phase 1O located the exact blocker of the machine-form universal theorem:
kprove case-splits REWRITE-position constructor variables, never
function-argument ones, and its implication checker cannot evaluate a
pattern-matched function under a disjunctive state constraint (the 1O toy
probes R1–R10; the residual `ABSInv(absStepJ(state, ground-cmd))` retained
on the R machine). Phase 1P tests ONE mechanism: make the invariant's two
branches an explicit, solvable component of the state — an integer branch
tag — so that the invariant becomes CONJUNCTIVE (no disjunction for the
checker) and the branch becomes a first-class value the rewrite engine can
select on. The ladder adds exactly one mechanism per rung:

| rung | module | mechanism | r2 result |
|------|--------|-----------|-----------|
| T | `SRW3N-ABS-T` | the conjunctive tagged invariant alone; R-form runner (symbolic shadow) | stuck — the 1O signature |
| TD | `SRW3N-ABS-TD` | + rewrite-level tag discrimination (branch-patterned ground-command runner) | stuck PAST the 1O leaf — tag pinned; blocker moves to Int requires |
| TDR | `SRW3N-ABS-TDR` | + the function-level requires split (complete partition) | residual UNCHANGED from TD |
| TDRR | `SRW3N-ABS-TDRR` | + the runner-level requires fork | gate shapes RESOLVE; residual moves to the compound-guard commit shape |
| TLR | (TDR + trusted PRESV family) | the 1O trust discipline | dies at the identical leaf |

## 2. What was built (all generated, fail-closed, roundtrip-deterministic)

* `scripts/make_abs_t.py` — the generator (edits EA–EH + EE′): the tagged
  state space `absStT` (the branch tag `tg:Int` as the first field), the
  conjunctive `ABSInvT` + `tagCoherentT` (impliesBool, no disjunction, no
  if-then-else), `absStepT` (the twelve-class mirror; the init-accept is
  the ONLY legal re-tag 0→1), the three runner forms, `absExecutableT`/
  `absRunFT`, and the refinement map (`branchTag`/`tagStE`/`eraseT` over
  the disclosed `absStE` mirror sort). Six strong+weak variants with the
  generator-enforced pairwise discipline (T↔TD differ only in the runner;
  TD↔TDR only in the step).
* `scripts/make_mutants_1p.py` — the stale-tag and tag-flip mutants (one
  mutant per kompile target — the r1 duplicate-syntax lesson).
* The proof modules: the universal ladder (`n_p_univ_{t,td,tdr,tdrr}.k`),
  the lemma families (`n_p_lemmas_tdr.k`: P1(3) + PRESV(23 with the LOW/HI
  splits) + COH(16) + CORR(15) + TLR; the 5-claim T smoke in
  `n_p_lemmas_t.k`), the diagnostics (`n_p_diag_tdr.k`), the soundness
  battery (`n_p_univ_weak_t.k`, `n_p_neg_mut_{stale,flip}.k`,
  `n_p_neg_self.k`), and the tagged toy (`repro/univ-repro-t.k`).
* `proofs/run_p_univ.sh` — the fail-closed runner (stages K/B/R/L/U/D/N/P;
  the sandbox reaps detached processes, so the run was driven in foreground
  batches with resume; the raw per-claim logs, the append-only CSV, and the
  last-wins score live under `transcripts/k/`).

## 3. The results (110 distinct claims, last-wins; GATE GREEN, 0 alarms,
### 0 incorrect)

**The baseline (stage B, live re-anchor).** The 1O residuals reproduce
exactly: R3-UNIV-CONS and R6-DOMAIN-RESTRICTED PROVED; R4-CMD-SPLIT,
R10-FUNC-DISPATCH-DOMAIN and 1O-UNIV-MACHINE-R rc=1 with the
WarnStuckClaimState signature; ABS-PRESV-I-INIT-ACCEPT PROVED
(WarnTrivialClaim, PASS-EVAL).

**The lemma families (the trust base, all green).** P1 tag facts (3),
PRESV (23 — every class × branch, including the 0→1 re-tag and the LOW/HI
guard splits), COH (16 — coherent in, coherent out, including the re-tag),
CORR (15 — TAGSOUND, TAGCOMPLETE-B1/B2 + the general-form ATTEMPT whose
disjunctive requires sticks exactly as the 1O evidence predicts, and the
ERASE-* per-class commutations against the frozen 1N rule table), and the
T-machine smoke (5). 76 PASS-expected claims proved; every
WarnTrivialClaim is confined to the PASS-EVAL class by construction.

**The ground execution evidence.** 1P-RUN-HONEST and 1P-RUN-INIT-EXEC
PROVED by real rewriting on T, TD, and TDRR — the honest pipeline
`init → exec → gate → commit` lands on `absStT(1, true, true, 0, 0, 1,
true, adNone)` on every rung.

**The soundness battery (16 negatives, all as designed).** The weak
universal FAILS (the presented-bit commit genuinely breaks the strong
invariant); the weak breaking run PROVES (`safe=false` reached — the K
port of the Python S4 control); the weak-inv ground witness FAILS the
preservation form; both mutants break COH/PRESV/the honest pipeline (five
controls); the destination controls fail on every rung; the ground
unsafe-commit controls fail (timeout, retained); the self-assumption probe
closes with WarnTrivialClaim and is recorded as SELF-ASSUMED-NOT-A-PROOF
(the 1O PASS-EVAL guard hole, reproduced deliberately and documented).

**The universal ladder (the experiment's core, all recorded).** Every
universal form ends rc=1:

```
1P-UNIV-MACHINE-T/TD/TDR/TDRR/TLR (+ all PREFIX forms): FAILED(rc=1)
1P-UNIV-NIL-TDR:  PROVED (non-trivially — the base case alone)
1P-UNIV-CONS-TDR: FAILED(rc=1) (the one-unfold + circularity diagnostic)
T1-TOY-TAG-UNIV:  FAILED(rc=1) — the same wall at toy scale
```

## 4. The findings

**1P-F1 (the incomplete partition).** The first r2 TDR split left the
(aGateJ(aOkF), E≥1) cell unmatched; the TDRR residual exposed it (the
stuck leaf moved to the aOkF shape). The corrected complete partition
(gate rows A/B/C; commit rows A/B/C/D) is the generated form of record,
and the lemma family forks with it. A first LOW-split draft that omitted
the invariant's lower bounds failed CORRECTLY — recorded as a negative
result before the fix.

**1P-F2 (the evaluation frontier — the phase's central result).**
* The branch-tag encoding DEFEATS the 1O obstacle at the constructor
  level: from TD onward the residual's tag is PINNED
  (`absStT(tg:1, cfgP:true, catP:true, ..., safe:true, ...)`) — the
  original disjunctive-invariant leaf is gone from every later rung.
* A function-level requires split CANNOT help: the engine does not fork
  on function-equation requires (TDR ≡ TD residual, two partition
  variants tested).
* A runner-level fork DOES propagate SINGLE-variable inequalities (the
  gate shapes resolve under TDRR) but NOT compound two-variable guards —
  the residual is exactly
  `absStepT(absStT(tg:1, ..., G, E symbolic ...), aCommitJ(aOkT, aOkF))`
  under the forked-but-unpropagated joint guard `G≥1 ∧ E≥1` /
  `G≤0 ∨ E≤0`.
* The trusted-lemma route dies at the identical leaf (TLR): the trusted
  PRESV facts cannot apply to a term the engine cannot evaluate.
* The toy reproduces the same wall (`tstep(stT(tag:S0, iv:S1), subC)`),
  answering the r1 session's UNREAD probe result: the blocker is
  architectural, not scale.
* Consequently the r1 record's "failed-budget at 280/560s" is superseded
  by a sharper characterization: with the fork mechanism pinned down, the
  wall is reached directly (rc=1 in ~13s). The difference from the r1
  record is disclosed; the r1 detail is unrecoverable.

## 5. Disposition

PHASE 1P = PARTIALLY COMPLETE — the controlled experiment is complete and
its infrastructure is mechanized end-to-end, but the universal transition-
preservation theorem is NOT MECHANIZED on K v7.1.337; no completion tag.
What 1P adds to the program: (a) the conjunctive tagged invariant and the
rewrite-level branch selection are mechanized and verified (the 1O
residual is eliminated); (b) the residual frontier is precisely located —
kprove evaluates a pinned-branch step function under a single-variable
rewrite fork and stops at compound guards; (c) the soundness battery
proves the encoding honest (the mutants and the weak machine break it
exactly where they should). Candidate next mechanisms (1Q, out of 1P
scope): constructor-valued pool occupancy (turning the remaining Int
guards into constructor splits), or a backend that propagates compound
rewrite-requires into function-argument evaluation.

## 6. Artifact index

| artifact | path |
|---|---|
| design + findings | `phase1p/spec/branch-tag-design.md`, `phase1p/spec/refinement-relation.md` |
| generators | `phase1p/scripts/make_abs_t.py`, `phase1p/scripts/make_mutants_1p.py` |
| semantics (generated) | `phase1p/semantics/abs-machine-{t,td,tdr,tdrr,weak-t,weak-td,weak-tdr}.k` |
| mutants (generated) | `phase1p/tests/abs-machine-mut-{stale,flip}.k` |
| proofs | `phase1p/proofs/n_p_*.k`, `phase1p/proofs/repro/univ-repro-t.k` |
| runner | `phase1p/proofs/run_p_univ.sh` |
| raw evidence | `phase1p/transcripts/k/` (110 per-claim logs, `claims-status-p.csv`, `score-p.txt`) |
| curated inventory | `phase1p/claims/claims.csv`, `phase1p/claims/generation-log.txt` |
| audit | `phase1p/audit/baseline-1p.txt` |
| reproduce | `python3 phase1p/scripts/make_abs_t.py && python3 phase1p/scripts/make_mutants_1p.py && bash phase1p/proofs/run_p_univ.sh` |

Toolchain: K v7.1.337 + z3 4.13.3 (the pinned recipe); base tree: the 1O
freeze cdb5556. Level III only; no consensus-integration claim.
