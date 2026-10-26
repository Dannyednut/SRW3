# SRW3 Phase 1U — Model Hygiene, Proof Soundness, and Independent Revalidation

**Final report — the fail-closed record.** Branch `phase1u-model-hygiene`,
base commit `2247e68872d7a5f8bd8920db96db3ace290535b2` (the Phase 1T tip,
`phase1t-c12-induction-validation`, verified with `git rev-parse` before
branch creation; the remote branch head was confirmed in sync). Toolchain:
the rebuilt pinned pair **K v7.1.337** (jammy deb) + **Z3 4.13.3** (verified
live) and the pinned independent checker **Lean 4.16.0** (commit
`128a1e6b0a82`; archive sha256 `54d6cba2…b81c80c` — byte-verified on
download). Provisions: the sandbox was fresh; the toolchain was re-provisioned
from `scripts/reinstall_toolchain_1m_r3.sh` and Lean from the pinned release
before any run.

**Verdict: PARTIALLY COMPLETE.** The proof-soundness defect of record is
remedied and machine-evidenced; the two abstract model defects (T1, T2) are
reproduced by execution and fixed with permanent regression controls; the
ledger/erratum reconciliation is appended; the ghost-fidelity layer is
regenerated from the corrected sources with every per-claim verdict
identical to the historical record. The genesis form and the destination-
false control remain TIMEOUT (kept, never relabeled); the Level-III
boundaries remain open. No completion tag. Scope: Level III only; no
consensus-integration claim.

**Disclosed limitation of record:** the examiner document
`SRW3-Independent-Examiner-Report-v1.2.md` is not present in the repository
(searched: every commit of every branch, `git grep` across all trees, the
GitHub API listing). This phase validated each examiner finding as an
INDEPENDENT lead — every defect was re-derived from the source and from
execution before it was fixed (§A1/B/C below) — and treats the mandate's
finding statements as the working copy of the findings. The absence of the
report file itself is a repository-traceability gap, registered in §E.

---

## §A — Workstream A: the Phase 1T proof-rule soundness defect

### A0. Independent confirmation of the defect (not assumed from the report)

`phase1t/proofs/n_t_migrate_rule.k:57-58` carries:

```k
rule countToInt(succP(P:PoolCount)) >=Int I:Int => true requires I >=Int 1
  [simplification, label(1T-C1.5-PROVED-RULE)]
```

**Counterexample of record:** `P = zeroP`, `I = 2`. The left side becomes
`countToInt(succP(zeroP)) >=Int 2` = `1 >=Int 2` = **false**, while the
condition `2 >=Int 1` **holds** — the rule rewrites a false predicate to
`true`. Confirmed by source inspection, by the Lean falsity twin (below),
and by the concrete evaluation control `U-C15-COR-CONCRETE-GE2-FALSE`
(rc=0: the predicate evaluates to false under the corrected environment).

### A1. The full derived-rule audit (every rule in the module)

| Rule (1U label) | Exact K body | Mathematical proposition | Justification | Sound for every admitted substitution? | Depends on it |
|---|---|---|---|---|---|
| `1U-C12-LEAN-RULE` | `countToInt(P:PoolCount) >=Int 0 => true` | ∀P. countToInt(P) ≥ 0 | Lean `c12_nonneg` (kernel-checked, `[propext, Quot.sound]`) | YES — the rule body IS the checked statement, no extra condition | the universal (discharges the ≥Int 0 shapes), SHIFT/SHIFT1 |
| `1U-C12-LEAN-RULE-SHIFT` | `countToInt(P) +Int I:Int >=Int 0 => true requires I >=Int 0` | ∀P,∀I≥0. countToInt(P)+I ≥ 0 | C1.2 + unbounded-integer monotonicity (`c12_shift_ge0`) | YES — x≥0 ∧ I≥0 ⇒ x+I≥0 for all admitted (P,I) | the minted-state ≥Int 0 guard shapes |
| `1U-C1.5-PROVED-RULE` (**CORRECTED**) | `countToInt(succP(P:PoolCount)) >=Int 1 => true` (no requires) | ∀P. countToInt(succP(P)) ≥ 1 | machine equation (abs-machine-q.k:402) + C1.2 + monotonicity (`c15_succ_ge1`) | YES — the literal threshold | the folded ≥Int 1 guard shapes (see the liveness finding) |
| `1U-C12-LEAN-RULE-SHIFT1` | `countToInt(P) +Int I:Int >=Int 1 => true requires I >=Int 1` | ∀P,∀I≥1. countToInt(P)+I ≥ 1 | C1.2 + monotonicity (`c12_shift_ge1`) | YES | the unfolded `countToInt(P)+Int 1 >=Int 1` guard shapes (the E-side commit-accept rows) |

**The 1T rule's defect class:** the justification chain yields EXACTLY the
literal threshold `≥Int 1` and nothing stronger; the 1T rule generalized the
justified literal into a universally-quantified `I` under the too-weak
requires `I >=Int 1`. **The machine of record contains no legitimate ≥Int 2
guard shape over `countToInt`** (verified by inspection:
`phase1q/semantics/abs-machine-q.k` rows B/C/D carry `G >=Int 1 ∧ E >=Int 1`
on the integer side and constructor splits on the PoolCount side; the
invariant conjuncts are `>=Int 0`) — so the overgeneralization was never
load-bearing for any true goal, which the rerun battery confirms empirically.

**Rule-liveness finding (exposed, disclosed):** on the pinned toolchain the
folded succP-headed shape is INERT at claim-goal level — the defining
equation `countToInt(succP(N)) => countToInt(N) +Int 1` always unfolds
first (bottom-up evaluation; the 1T SHIFT1 comment documented the same
ordering). Evidence: the liveness probe `U-C15-LIVE-FOLDED-GE1` (folded
corrected rule ALONE, symbolic ≥Int 1 goal) is STUCK rc=1; the
`[priority(1)]` reordering probe is REJECTED by the compiler (`priority
attribute is not supported on simplification rules`, rc=113 — the same
tool-boundary class as the 1T `[induction]` rejection). Consequently the
>=Int 1 discharges in the batteries are carried by SHIFT1; the folded rule
is retained as the documented, Lean-checked projection (sound wherever it
may fire). The mutant's falsity is therefore demonstrated MATHEMATICALLY
(Lean) and by concrete evaluation, with the rewrite-level firing window on
this toolchain disclosed as nil at default priority.

### A2. The isolated counterexample fixture (direct controls, not a big theorem)

`phase1u/proofs/n_u_c15_fixture.k` — a minimal isolated definition (the two
constructor declarations and the two defining equations verbatim from
`abs-machine-q.k:31-32,400-402`, nothing else). Three spec modules:

| Module | Claim | Expected | Actual (rc, wall) | Interpretation |
|---|---|---|---|---|
| `n_u_c15_mutant.k` (the VERBATIM 1T rule, deliberately buggy) | `U-C15-MUT-SYMB-GE2-TRUE`: symbolic `countToInt(succP(P)) >=Int 2 => true` (semantically FALSE; witness P=zeroP) | close iff the mutant fires | **rc=1, 4s** | evaluation-order masking: the goal unfolds before the folded rule can match — the firing window is nil at default priority on this toolchain (disclosed) |
| same | `U-C15-MUT-SYMB-GE1-TRUE` | close | **rc=1, 4s** | same masking (consistent with the liveness finding) |
| `n_u_c15_corrected.k` (the corrected set) | `U-C15-COR-SYMB-GE2-TRUE` (the same false claim) | **must NOT close** | **rc=1, 4s** | THE DECISIVE NEGATIVE CONTROL — fast, computationally decisive, NOT a timeout; directly tests the dangerous generalization |
| same | `U-C15-COR-CONCRETE-GE2-FALSE`: `countToInt(succP(zeroP)) >=Int 2 => false` | close | **rc=0, 4s** | the ACTUAL result verified: the witness predicate evaluates to false |
| same | `U-C15-COR-CONCRETE-GE1-TRUE` | close | **rc=0, 4s** | threshold case: 1 ≥Int 1 |
| same | `U-C15-COR-SYMB-GE1-TRUE` | close | **rc=0, 4s** | the intended successor lower bound holds under the corrected rules |
| `n_u_c15_liveness.k` | `U-C15-LIVE-FOLDED-GE1` (folded rule alone) | record | **rc=1, 4s (stuck)** | the folded rule never fires at goal level |
| same | `U-C15-LIVE-UNFOLDED-NOSHIFT-MUST-STICK` | stick | **rc=1, 3s** | the fixture cannot close by evaluation alone (attribution control) |
| `n_u_c15_mutant_prio.k` | `U-C15-PRIO-SYMB-GE2-TRUE` | record | **rc=113, 2s** | `[priority]` rejected on simplification rules (tool boundary of record) |

Raw outputs: `phase1u/transcripts/k/kprove_U-C15-*.log` (10 logs), rows in
`phase1u/claims/exit-codes-1u.csv`, ledger rows in `claims-1u.csv`.

### A3. The Lean cross-checker boundary (strengthened)

`phase1u/audit/lean/c12_helpers.lean` — four explicit helper lemmas, one per
K rule: `c12_nonneg`, `c15_succ_ge1`, `c12_shift_ge0`, `c12_shift_ge1`.
Ran on the pinned Lean 4.16.0: **exit 0 in 1s; `#print axioms` reports
`[propext, Quot.sound]` for ALL FOUR** (no `sorryAx`); transcript
`phase1u/transcripts/lean/transcript_c12_helpers.txt`.
`c12_helper_neg_controls.lean` — the falsity twins (the 1T generalization
`countToInt (succP p) ≥ i ∀ i≥1`, the `≥ 2` form, the sign-flipped form):
**exit 1 as designed** — omega machine-refutes the 1T overgeneralization
with the exact counterexample region (`i ≥ 1, countToInt p ≥ 0` with
`countToInt p + 1 ≥ i` unsatisfiable at p ↦ 0, i ↦ 2); transcript retained.
The 1T certificate re-verified on the rebuilt environment (rc=0, same axiom
report). **Boundary preserved:** a kernel-checked Lean theorem is NOT a K
kernel check; the lemma→rule correspondence and the K migration results
remain in the disclosed cross-language trust base (Lean kernel + core; the
source-correspondence argument (C-a)–(C-d); the K checker).

### A4. The rerun suite (clean proof environment: fresh `/tmp/p1u-*` defs)

| Item | Verdict (rc, wall, log) |
|---|---|
| Unconditional migration universal (corrected rules, NO assumption rules) | **CLOSES** rc=0, 14s, #Top — `kprove_1U-MIGRATE-UNIV-LEANC12-RULE.log` |
| Genuineness depth probes d=1/2/3 | d1 **FAIL** rc=1 11s; d2 **FAIL** rc=1 12s; d3 **CLOSES** rc=0 13s (NEW for the RULE form) — real unrolling, non-shallow |
| Five formerly-C12-COND correspondence cells | all **CLOSE** rc=0 (10–11s each) |
| Commit-accept strip-state residual probe (`1U-CORR-NODEP-RULE`) | **CLOSES** rc=0, 10s — the 1S residual of record `countToInt(G0)≥0 ∧ countToInt(E0)≥0` discharged under the corrected rules |
| Integer-model preservation chain (EXE-MINT/GATE-MINT/COMMIT-ACCEPT) | all **CLOSE** rc=0 |
| Genesis-grounded form | **TIMEOUT** rc=124, 560s, EMPTY log (the 1R TAG0-NF phenomenon, exactly as recorded; never relabeled) |
| Destination-false control under the corrected harness | **TIMEOUT** rc=124, 300s — KEPT classified TIMEOUT (a timeout is not evidence of soundness); the computationally decisive false-goal control is `U-C15-COR-SYMB-GE2-TRUE` (rc=1 in 4s) |
| The 1S conditional migration + depth probes | rc=0 12s; d1/d2 FAIL, d3 CLOSES — the exact 1T record, reproduced |
| The 1S negative controls (weak machine, OMIT mutant) | both **FAIL as designed** rc=1 (13s / 10s) |

**WarnTrivialClaim investigation (the three 1T warning-bearing rows):**
`1T-CORR-NODEP-RULE`, `1T-CORR-COMMIT-ACCEPT-RULE`,
`1T-PRESV-INT-COMMIT-ACCEPT-RULE` all logged `WarnTrivialClaim — Claim
proven without rewriting … #Top`. Examined: the warnings are the expected
closure MODE for these correspondence/preservation cells — both sides are
fully-defined functions on constructor-ground states with symbolic
parameters, and they normalize to the same normal form by simplification
(the cells' intended goal). Genuineness is corroborated three ways:
(i) the same cells FAILED in Phase 1S when the C1.2 guard could not be
discharged (the recorded 1S residual) — the closure is lemma-dependent, not
automatic; (ii) the mechanism-A 1T forms (no rules at all) failed with the
identical residual — the lemma content is load-bearing; (iii) under the
CORRECTED rule set every cell still closes (this phase) while the decisive
false-goal control refuses to close — the rule set does not prove falsehoods.
The warnings are therefore genuine evaluation-mode closures with the
corrected, audited rule dependency; the finding is disclosed rather than
ignored, and the corresponding 1U rows carry the same warnings (retained in
their logs).

### A5. What was NOT rerun, and why (scoping disclosure)

The mechanism-A modules (`n_t_migrate_uncond.k`, `n_t_corr_uncond.k`)
contain NO simplification rules — the correction cannot change their
behavior, and their 1T outcomes (recorded failures with the unchanged
residual) stand as the record. The correction-scoped rerun covers every
rule-harness claim plus the 1S reproductions and controls.

---

## §B — Workstream B: T1, obligations dropped after `bareEdge`

**Independent confirmation.** `k/srw3.k` (1T tip):

```k
rule applicable(SetItem(bareEdge(_Xs:Set)) Es:Set, _F:Set)
  => applicable(Es, .Set)   // 0D: the footprint RESET
```

The recursion resets the footprint to `.Set`, so every real edge decomposed
AFTER a bareEdge is tested against an empty footprint
(`nonemptyInter(Xs, .Set) = false`) and its obligation is silently dropped.
Because K `Set` is unordered, which edge comes "after" is a decomposition
choice — the buggy function's result was DEPENDENT on the engine's
decomposition (non-confluent in principle, masked by the concrete engine's
deterministic order).

**Reproduction (old model = the unmodified 1T-tip `k/srw3.k`, kompiled
fresh):**

- `OLD-t1-pairwise-violation` — registry `pairwiseOnly` (three real edges +
  one bareEdge), IOL violated (lending price 90 ≠ oracle 100):
  **IMPROPER COMMIT** — `result="commit"`, committed state contains
  `lending,0 → 90`, lineage advanced (`head=commit(0)`, `lineageNext=1`).
  The defect is live by execution.
- `OLD-t1-mixed-probe-violation` — the minimal 2-element mixed registry
  (one IOL edge + one bareEdge over the same dependency set): **REJECT** —
  the engine's decomposition checked the edge first here. Recorded verbatim:
  the same logical violation, two registry shapes, two outcomes — the
  order-dependence the mandate warned about, demonstrated WITHIN the old
  model. The probe-only controls
  (`OLD-t1-probe-only-{violation,ok}` → `false`/`true`) record the
  applicability verdict directly.

**Fix.** The corrected recursion preserves the footprint:

```k
rule applicable(SetItem(bareEdge(_Xs:Set)) Es:Set, F:Set)
  => applicable(Es, F)      // dependency known, no contract → no obligation
```

`bareEdge` means "this dependency carries no contract → no obligation FROM
THIS EDGE", not "stop checking obligations". All decompositions now agree
(the function is order-independent again). The generalized model's
`applicableGen` ALREADY preserved the footprint (`k/srw3gen.k:369-370` at
the 1T tip — verified by inspection); no change was needed there, and this
is recorded as the T1 scope: `srw3.k` only.

**Fixed-model controls (permanent regression matrix, `phase1u/tests/`):**
`NEW-t1-pairwise-violation` → **reject** (IOL enforced regardless of the
bareEdge); `NEW-t1-mixed-probe-violation` → reject with the probe recording
`false` (the violation IS detected); both honest controls (`*-ok`) still
commit. The classic demo `demo10_pairwise_only_threeway_hole` still commits
— unchanged, because the IOLD obligation there legitimately has NO contract
edge (the documented CM6 hole, not the T1 defect).

The 0D-era model files remain in git history verbatim; old-vs-fixed evidence
is retained under `phase1u/transcripts/model/` (krun raw + verdict lines).

---

## §C — Workstream C: T2, re-entrant gate erasure

**Independent confirmation.** After any gate path, `<prospective> := .Map`
and the footprints are cleared, but nothing prevents a SECOND `gate`:
`applicable(R, .Set) = .Set`, `allHold(.Set, .Map) = true`, and the actor is
still authorized → the accept rule commits the EMPTY map, appends a lineage
record, and advances the head. A `gate` with no preceding `begin` commits
the empty map from the initial configuration. Confirmed in BOTH abstract
layers (`k/srw3.k` accept/reject/reject-auth; `k/srw3gen.k` same shape over
`<committed>`/`<usage-c>`).

**Reproduction (old model):**

- `OLD-t2-double-gate` — `… begin , w(appB,0,2) , wfCheck , gate , gate`:
  first gate commits (7,2); the second gate **COMMITS THE EMPTY MAP**
  (`committed=.Map`, `head=commit(1)`, `lineageNext=2`). The erasure, live.
- `OLD-t2-gate-no-begin` — `… init(appA,0,7) , as(appB) , gate`:
  **COMMITS THE EMPTY MAP** (`committed=.Map`, `lineageNext=1`) — the
  initialized state is erased without any transition.

**Fix (one-shot gate state, both layers):**

- New cell `<gateopen> false </gateopen>` in both initial configurations.
- `begin` OPENS the interval (`false => true`) and requires it closed —
  a repeated/nested `begin` while open is BLOCKED terminal
  (`blocked-begin-open`; the pipeline is discarded; cannot bypass or restart
  the guard).
- EVERY gate path closes the interval: accept, reject, and reject-auth all
  carry `<gateopen> true => false </gateopen>`; the wfCheck block path also
  closes it (every path out of a transition closes the interval — no
  stale-open state survives).
- A closed-interval gate FAILS CLOSED: the new `gate-closed` rule touches
  nothing — `<committed>`, `<lineage>`, `<lineageNext>`, `<head>` and the
  success record are all unreachable from it. The guard is NOT accept-only:
  all four gate paths are explicitly partitioned (accept/reject/reject-auth
  on open; `gate-closed` on closed), and the interval discipline is
  propagated to the generalized model identically (including
  `<usage-p>/<usage-c>`).

**Fixed-model sequence controls (permanent):**

| Control | Outcome on the fixed model |
|---|---|
| `NEW-t2-valid-begin-gate` (normal begin→write→wfCheck→gate) | `commit` — existing behavior preserved |
| `NEW-t2-double-gate` | `gate-closed`; committed (7,2) INTACT; `lineageNext=1` |
| `NEW-t2-gate-no-begin` | `gate-closed`; committed {appA→7} intact; `lineageNext=0` |
| `NEW-t2-reject-then-gate` | `reject` then `gate-closed`; committed unchanged |
| `NEW-t2-double-begin` | `blocked-begin-open`; no commit |
| `NEW-gen-double-gate` / `NEW-gen-gate-no-begin` / `NEW-gen-double-begin` | `gate-closed` / `gate-closed` / `blocked-begin-open` on the generalized model |

**Old-implementation control retained:** the buggy behavior lives in the
git history (the 1T tip), is reproduced in `OLD-t2-*`, and is NOT shipped in
the fixed model. Whether other transition sequences can invoke `gate`
without a valid `begin`: the interval is opened ONLY by `begin` (the sole
rule writing `gateopen true`), and `gate` requires it — no other path exists
(the rule set is partitioned; verified by inspection and by the controls).

---

## §E — Workstream E: T3, T4, and the packaging register

### T3 — transition-mutable policy and registry

The examiner's lead was validated by execution BEFORE the fix:
`OLD-t3-policy-mid` — mid-transition `setPolicy(trust)` ADMITS a hidden
write into committed state (`appC → 11` COMMITTED);
`OLD-t3-registry-mid` — mid-transition `useRegistry(negative)` commits the
IAB violation (7+7=14 COMMITTED). The implemented disposition is the
SETUP-PHASE DISCIPLINE: `setPolicy`/`useRegistry( G)` fire only while the
gate interval is closed (`<gateopen> false`), and are BLOCKED terminal
mid-transition (`blocked-policy-mutable` / `blocked-registry-mutable`) —
the transition under evaluation cannot weaken enforcement or switch to an
incomplete registry. The added assumption is documented IN the models:
**A5** (srw3.k) / **A7** (srw3gen.k): *policy and registry are
protocol-authored configuration; a wrong or adversarially authored
policy/registry at deployment time is outside the evaluated model.* The
mandate's preferred option (removing the commands entirely) was NOT taken
because the demo/regression programs legitimately use them as setup
commands (every demo calls `useRegistry`/`setPolicy` before `begin`); the
setup-only discipline achieves the same mid-transition guarantee with a
disclosed assumption. Negative controls: `NEW-t3-policy-mid`,
`NEW-t3-registry-mid` (blocked, no commit). The stated threat model is not
downgraded: the gate-time guarantee is unchanged (Claims 1–4 close on the
fixed model); what changed is that the transition-internal mutation path is
now mechanically closed and the remaining trust is EXPLICIT (A5/A7) instead
of implicit.

### T4 — footprint granularity

Documented in `docs/research/t4-footprint-granularity.md`: the original
model claims APP-granular effect completeness; the generalized model claims
STORAGE-KEY-granular completeness with the alias closure. Neither implies
the other without a projection argument that is not established; no
cross-layer equivalence is claimed anywhere in the record.

### Packaging and traceability register (follow-up dispositions)

| Item | Disposition |
|---|---|
| Committed generated build output / missing `.gitignore` patterns | `.gitignore` extended (`*-out/`, `*-out2/`, `*.kore`, `k_HS/`, `k_llvm/`); historically committed `-out/` dirs RETAINED as provenance (deleting them would rewrite historical trees) — action: optional history-cleaning pass, owner: maintainer, reason: provenance risk |
| Missing/stale state-of-record and README surfaces | RESOLVED: top-level `STATE-OF-RECORD.md` + landing `README.md` added (workstream D1) |
| Default branch stale at `phase1b` | Attempted via the API with the provided PAT (see §D1 outcome below) — outcome recorded; if blocked, the exact manual action is documented |
| Tag gaps / naming inconsistency across late-phase reports | REGISTERED, deferred: tag creation is explicitly forbidden this phase (mission §Branch rules); the naming inconsistency is documented in the phase-branch table of the README; owner: maintainer, action: reconcile at the next phase boundary |
| Missing repository licence | REGISTERED, deferred with reason: choosing a licence is the author's decision; the README discloses the gap explicitly instead of silently picking one; owner: author |
| Missing traceability mechanized-claims ↔ P1/P2/P3 and A1–A4 | PARTIAL: the assumptions of record are now labeled A1–A5 (srw3.k) and A1–A7 (srw3gen.k) IN the sources; the P1–P6 framework predicates map to the 1O `spec/` layer of record; a consolidated cross-walk table is registered as follow-up (owner: next phase) |
| Consolidated FAILED-STUCK residual ledger | The per-phase ledgers remain append-only and complete (1S: 23 FAILED-STUCK rows; 1T: 10; 1U: 0 new — all 1U attempts closed or timed out as recorded); a consolidated cross-phase residual table is registered as follow-up (owner: next phase) |
| Examiner report file itself absent from the repo | REGISTERED as a traceability gap: the v1.2 report should be committed to the repository of record; owner: author/examiner |

---

## §D — Workstream D: repository state of record and audit integrity

### D1. Default branch and landing surfaces

Verified live first: the GitHub default branch IS `phase1b` (via
`git symbolic-ref refs/remotes/origin/HEAD` and the API), `main` is a
divergent early archive — both examiner claims CONFIRMED. Remediation
delivered: `STATE-OF-RECORD.md` (the authoritative pointer: current phase,
branch, commit, verdict, pins, residuals) and the top-level `README.md`
(landing page pointing at it, with the phase-branch topology and the
explicit stale-`phase1b`/archive-`main` labeling). **Default-branch action: BLOCKED (with evidence).** The switch was attempted
via the API (`PATCH /repos/Dannyednut/SRW3`, `{"default_branch":
"phase1u-model-hygiene"}`) with the provided PAT; the API returned
**"Resource not accessible by personal access token"** (the fine-grained
token lacks the Administration write permission), and a follow-up GET
confirmed the default branch is still `phase1b`. The exact MANUAL action
still required: *GitHub → Dannyednut/SRW3 → Settings → Branches → default
branch → `phase1u-model-hygiene`* (the validated state of record; never an
unvalidated working tree). No force-push, no history rewrite, no branch
deletion. S1 is NOT reported resolved: the landing surfaces exist at the
branch of record, but the default VIEW remains `phase1b` until the owner
performs the manual switch.

### D2. The Phase 1T ledger count discrepancy — resolved

Authoritative counts (recomputed from the committed CSVs, never from prose):
`claims-1t.csv` = **40 unique claim rows** (34 `1T-` + 6 reproduced `1S-`;
census: 12 proved/proved-derived-lemma, 1 PROVED-EXTERNAL,
1 reproduced-under-assumption, 1 depth-closure, 10 FAILED-STUCK,
1 tool-boundary, 2 TIMEOUT, 12 controls); `exit-codes-1t.csv` = **51
append-only attempt rows** (6 claim IDs have superseded first attempts,
retained). The README's "42 rows" and the report's prose census (which also
said "2 PROVED-EXTERNAL / 3 TIMEOUT") did not match the committed ledger —
both are corrected IN PLACE with self-identifying `[1U D2]` markers (the
original text is in git history; no CSV row was touched). The summary now
distinguishes claim IDs / unique claims / execution attempts / latest result
/ superseded-but-retained attempts (the 1U summarizer implements the same
distinctions). `summarize_1t.py` rerun: **GATE GREEN (0 alarms)**.

### D3. The Task 11 erratum — appended, never edited

The contradiction of record: one Task 11 entry says `pytest FIRST: PASSED=0
FAILED=0` and six byte-identical entries say `make test (unittest
discover): PASSED=15` — all against the SAME recorded zip sha256
(`2db8669f…e62955`). The appended erratum (`worklog.md`,
`1U-D3-ERRATUM`) establishes from the retained evidence: the baseline bytes
never changed; the canonical invocation is the baseline's own Makefile
target (`unittest discover`, corroborated by the retained
`full_matrix.txt` "Ran 15 tests" line and every later matrix run); the
zero-test row self-identifies as the non-canonical "pytest FIRST" draft
invocation; the five duplicate 15/15 entries are one operation logged six
times. **Limitation stated, not guessed:** the raw pytest transcript of the
zero-test attempt is not retained, so the precise pytest-side mechanism of
the zero collection cannot be re-established — what is established is
sufficient: the zero-test row measures the draft invocation, not the
baseline. Forward-looking task-ID rule adopted: no reuse, distinct sub-IDs,
the exact invocation named in every entry, non-canonical runners labeled at
entry time.

---

## §F — Fidelity and regression regeneration

The model remediation changed the byte-pinned semantic core
(`k/srw3.k` 530→607 lines; `k/srw3gen.k` 641→690 lines), so the
ghost-fidelity artifacts were REGENERATED from the corrected sources:

- `proofs/induction_ghost.k`: faithfulness **571/571 source lines matched in
  order PASS**; 14 `//GHOST:` lines, all declared; the GH*/GH2*/GH3*/GH4*
  claims now pin `<gateopen> false` (the pre-begin initial state of every
  `tB`/`tG` cycle — begin opens, gate closes, the cycle returns to false).
- `proofs/ghost_manifest.json`: refrozen — baseline slice lines 37..607
  (sha256 `dce1dfd9…`), 7 insertion blocks / 19 lines, extension region 298
  lines; `audit_ghost_exact.py verify` → **PASS (exact byte-faithfulness)**.
- `proofs/gen/{cm2_alias,cm3_auth,gen_full}.k` + `ghost_manifest_gen.json`:
  regenerated from the corrected `srw3gen.k` (the fragment claims carry the
  same pre-begin pins; `gen_ghost_proofs.py` anchors all verified unique).
- The slice-location logic in `gen_ghost_artifact.py`,
  `audit_ghost_faithful.py`, `audit_ghost_exact.py` is now DYNAMIC (locates
  `module SRW3-SYNTAX` .. the claims `endmodule`) with fail-closed
  assertions, so the pinning tooling no longer hard-codes line numbers.
- **Per-claim ghost batteries — every verdict identical to the historical
  record:** GH-BASE/A/R/SOUND-I/SOUND-F/GATE-AGREE/ISO/T1 PROVED; **GH-T2
  (the full ∀n theorem) PROVED; GH-M PROVED**; GH-T FAILED (the documented
  stuck probe); GH-T2-NEG FAILED (non-vacuity, as designed); and all 36
  generalized rows (11 PROVED + NEG FAILED per layer × 3).
- The combined `--spec-module SRW3-CLAIMS` batch on the ghost copy fails
  (unconstrained `<ghost>` cell in the copied claims); the OLD 1T-tip
  artifact fails the SAME batch IDENTICALLY — pre-existing checker behavior,
  NOT a 1U regression; the per-claim discipline is the record.
- The classic demo suite (13 programs) is **verdict-preserving** on the
  fixed model (D10's commit is the documented CM6 hole, unchanged).
- SRW3-CLAIMS Claims 1,2,3,4a,4b close on the fixed model (rc=0, #Top) with
  the DISCLOSED premise change (the claims pin the at-gate interval state
  `true => false`); the negative control still FAILS (rc=1). A superseded
  first attempt (initially pinned without the closing arrow) is retained
  append-only in the ledger.

---

## §G — Evidence index (raw, retained)

- Proof battery: `phase1u/transcripts/k/kprove_*.log` (37 logs — every row
  incl. failures/timeouts), `phase1u/claims/exit-codes-1u.csv` (58 rows,
  append-only incl. the superseded claims-battery attempt),
  `phase1u/claims/claims-1u.csv` (56 rows / 55 unique claims; the census and
  GATE GREEN from `phase1u/scripts/summarize_1u.py`).
- Model matrix: `phase1u/transcripts/model/krun_*.txt` (21 raw krun outputs
  old+new) + `verdict_*.txt` extractions + the kprove claims/negative-control
  logs + the ghost per-claim logs + `ghost_gen_1u.txt`.
- Lean: `phase1u/transcripts/lean/transcript_c12_helpers.txt` (rc=0, four
  axiom reports) + `transcript_c12_helper_neg.txt` (rc=1 as designed).
- Toolchain: `/tmp/toolchain_setup.log` + `kompile --version` / `z3
  --version` / `lean --version` captured live in the session of record
  (K v7.1.337, Z3 4.13.3, Lean 4.16.0 commit `128a1e6b0a82`; the Lean
  archive sha256 byte-verified at download).

## §H — The five Phase 1T obligations, re-stated at 1U

1. **C1.2 universal** — PROVED (Lean 4.16.0 kernel-checked structural
   induction; the 1U helper lemmas add a one-to-one checked source for every
   K derived rule). Unchanged by 1U; re-verified on the rebuilt environment.
2. **Conditional migration genuineness** — VALIDATED under the disclosed
   assumption (the 1S reproduction reproduces exactly; both false-goal
   controls refuse; the OMIT mutant and weak machine fail as designed).
3. **Unconditional migration theorem** — CLOSES under the CORRECTED
   derived-rule set with NO assumption rules (rc=0 14s; depth 1/2 fail,
   3 closes; the decisive false-goal control refuses; the genesis form
   remains TIMEOUT). Classification: PROVED with the disclosed
   cross-language trust dependency (the K checker + the Lean certificate +
   the source-correspondence argument + the derived-rule provenance) — NOT
   independently kernel-checked at the K level.
4. **Dependency correspondence & genesis** — the five formerly-conditional
   cells, the strip-state residual discharge, and the preservation chain all
   close under the corrected rules; the genesis-grounded form remains
   TIMEOUT (recorded, never relabeled).
5. **Remaining trust dependencies** — the K toolchain; the Lean kernel/core
   (`propext`, `Quot.sound`); the (C-a)–(C-d) correspondence argument; the
   derived-rule provenance (now audited rule-by-rule with the liveness
   finding disclosed); TCB-2 (the external coverage enumeration); and the
   Level-III boundaries (no bisimulation, no generator completeness, no
   concrete-protocol correspondence, no consensus integration).

---

## §I — Acceptance criteria — status table

| # | Acceptance criterion | Evidence path | Status |
|---|---|---|---|
| 1 | The invalid arbitrary-threshold rule is removed/replaced by a mathematically justified rule | `phase1u/proofs/n_u_migrate_rule.k` (the corrected rule; the 1T module byte-frozen); audit §A1 | **VERIFIED** |
| 2 | The isolated counterexample demonstrates the original defect and the corrected behavior | `phase1u/proofs/n_u_c15_*.k`; logs `kprove_U-C15-*.log`; Lean falsity twin rc=1; §A2 table | **VERIFIED** (the rewrite-level manifestation is order-masked on this toolchain — disclosed; the falsity is machine-checked) |
| 3 | All other proof simplification rules audited for overgeneralization | §A1 audit table (4/4 rules, justification + admitted-substitution soundness) | **VERIFIED** |
| 4 | The corrected unconditional migration theorem rerun without the old C1.2 assumption rules | `kprove_1U-MIGRATE-UNIV-LEANC12-RULE.log` (rc=0, #Top) | **VERIFIED** |
| 5 | Depth probes, decisive negative controls, dependent claims, warning-bearing logs examined | D1/D2 FAIL + D3 close; `U-C15-COR-SYMB-GE2-TRUE` rc=1; nine cells rc=0; the WarnTrivialClaim investigation §A4 | **VERIFIED** |
| 6 | Successful theorem claims classified per actual dependencies and the disclosed trust boundary | §H.3 (PROVED with the disclosed cross-language dependency; NOT K-kernel-checked) | **VERIFIED** |
| 7 | T1 independently reproduced and fixed, with a registry-order/set-decomposition control | `OLD-t1-pairwise-violation` (improper commit) vs `NEW-t1-*`; the mixed-registry order evidence; `phase1u/tests/` | **VERIFIED** |
| 8 | T2 independently reproduced and fixed, with double-gate and gate-without-begin controls | `OLD-t2-double-gate` (empty-map commit) / `OLD-t2-gate-no-begin` vs `NEW-t2-*` (gate-closed, state intact) | **VERIFIED** |
| 9 | The generalized model reviewed for analogous defects | T2 fixed in `srw3gen.k` (verified by inspection + `NEW-gen-*`); `applicableGen` already footprint-preserving (T1 N/A) | **VERIFIED** |
| 10 | Regression matrix and ghost-fidelity evidence regenerated and passing | 13 classic demos verdict-preserving; fidelity 571/571 PASS + manifest verify PASS; all ghost per-claim verdicts identical to history | **VERIFIED** |
| 11 | The default-view problem genuinely resolved (or precisely documented) | `STATE-OF-RECORD.md` + `README.md` delivered at the branch of record; API attempt BLOCKED ("Resource not accessible by personal access token"; GET confirms default still `phase1b`); exact manual action documented in §D1 | **BLOCKED** (surfaces VERIFIED; the switch itself requires the owner's manual action — precisely documented) |
| 12 | The state-of-record surface accurate and linked | `STATE-OF-RECORD.md` (branch, commit, pins, residuals) | **VERIFIED** |
| 13 | The ledger count mismatch fixed and the summarizer passing | §D2; `summarize_1t.py` GATE GREEN; `summarize_1u.py` GATE GREEN (0 alarms) | **VERIFIED** |
| 14 | Task 11 reconciled through an append-only erratum | `worklog.md` `1U-D3-ERRATUM` (no historical entry edited) | **VERIFIED** |
| 15 | T3/T4 and remaining findings implemented or in a concrete follow-up register | T3 implemented + A5/A7; T4 documented; §E register with owners/actions | **VERIFIED** (licence + tag reconciliation + cross-walk table = registered follow-ups with owners) |
| 16 | Genesis-grounded run form | `kprove_1U-MIGRATE-GENESIS-LEANC12-RULE.log` (rc=124, 560s, empty log) | **TIMEOUT** (unchanged classification) |
| 17 | Destination-false control under the derived-rule harness | `kprove_1U-WSA-CTRL-DEST-FALSE-RULE.log` (rc=124) | **TIMEOUT** (kept; the decisive control is #2/#5) |
| 18 | Level-III boundaries (bisimulation, generator completeness, concrete correspondence, consensus) | `STATE-OF-RECORD.md` §Open residuals | **NOT RUN** (out of scope by the mission; remain open) |

**Verdict policy honored:** the project remains PARTIALLY COMPLETE; nothing
was made green by weakening a property, changing the threat model without
disclosure (the claims' `gateopen` premise change is disclosed in A5/A7 and
§F), broadening an assumption, relabeling a timeout, or deleting a failed
attempt (the superseded claims-battery attempt is retained in the ledger).
