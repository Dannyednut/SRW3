# SRW3 Phase 1L — Universal Induction Mechanization Report

**The induction step mechanized where the backend allows; the universal
theorem honestly NOT MECHANIZED, with the exact blockers**
Branch `phase1l-universal-induction` (from the corrected Phase 1K commit
`b1dbe90`, tag `phase1k-r1-complete`) · additive tree `phase1l/` · frozen
base `phase1k-implementation-package` @ `b1dbe90` (frozen 1J semantics
UNCHANGED)

---

## 1. Objective and outcome

Phase 1L's mandate (the handoff, PHASE1K_AUDIT_FINDINGS.md resolved first;
SRW3_Phase1L_Universal_Induction_Handoff.md): mechanize the Phase 1J
reachable-committed-state safety theorem for the already-declared finite
policy fragment and the already-declared four-operation `EVM_F` fragment —
with the explicit rule that the phase may be declared complete ONLY if the
universal theorem is actually mechanized, and that a blocked Haskell proof
must be RETAINED, its exact blocker identified, and the strongest truly
proved theorems reported.

**Outcome (Level III, exact):** the universal all-path theorem
(`J-REACHABLE-COMMITTED-SAFE` class) is **NOT MECHANIZED**.  The ladder
mechanizes the induction STRUCTURE around it: 14 claims PROVED over the
frozen J machine (the anchor/config/catalog frames, the pre-init family,
the refusal family, the no-commit content of the source-refusal class on
every resolution path, and the four commit-rejection/freshness theorems),
16 attempted claims retained with their raw failures and the blockers
named to the kore residual level, one FROZEN-SEMANTICS FINDING reported
with the frozen 1J T11 transcript as its counterexample witness, all
negative controls failing exactly as designed, and the concrete
substitutes (Python prefix enumeration, the fresh LLVM T-series
byte-identical to the frozen records) re-verified from the corrected
base.  No result is relabeled; no consensus-integration or full-EVM claim
is made.

## 2. What was built (additive `phase1l/` only)

```text
phase1l/
  semantics/j_invariant.k        the invariant predicate (JInvJ /
                                 JInvPreinitJ / JChainCoherentJ / JInvPlusJ)
                                 + the PROOF-FACING total wrappers (§5 — the
                                 explicit definedness assumption); imports the
                                 FROZEN J machine; NO semantic change
  proofs/l_proofs.k              the 30-claim ladder (§0 experiments, §A
                                 frames, §B pre-init, §C step lemmas,
                                 §C2 dispatch resolution, §D commit family,
                                 §E the universal attempts)
  proofs/run_l_proofs.sh         the per-claim runner (expected-outcome
                                 gating; negative controls MUST fail)
  transcripts/k/                 30 kprove logs + claims-status.csv +
                                 claims-classification.csv + the fresh 1J
                                 re-run record + README
  transcripts/llvm/              the FULL frozen 1J T-series re-run fresh
                                 (T0-T13 + 5 kparse rejections + anchor) —
                                 byte-identical to the frozen records modulo
                                 header lines
  transcripts/attacks/           run_l_attacks.txt (56/56 PASS) + the fresh
                                 1J unittests (27/27) + attack matrix (48/48)
  audit/                         induction-diagnosis.md (the blocker census),
                                 rule-inventory.md, findings.md
                                 (L-FINDING-1), assumption-register.md
  python/run_l_attacks.py        the L-A01..L-A20 tier over the FROZEN mirror
  provenance/                    input hashes + reproduction commands
  report/                        this file (MD + PDF)
```

The reachable rule set of the 1L proof definition is byte-for-byte the
frozen J machine's (`audit/rule-inventory.md` cross-checks every rule;
the 1L module adds `[function, total]` definitions only).

## 3. The K/LLVM toolchain and the fresh regression record

- Toolchain rebuilt from the pinned recipe of record after the sandbox
  reset: K v7.1.337 (jammy deb), z3 4.13.3, flex 2.6.4, clang/LLVM-15
  15.0.6-4+b1 (+ `libclang-common-15-dev` extraction, `lld-15`,
  `libmpfr-dev`/`libsecp256k1-dev` headers), pristine
  `llvm-kompile-clang` driver with the single path substitution (the R2
  patch NOT applied).  Environment repairs recorded: a java wrapper
  capping the frozen build scripts' `-Xmx6g` (this 4-GiB container OOMs);
  `LIBRARY_PATH` defaulted in env.sh (`set -u`).
- **Fresh package verification from the corrected 1K base** (the
  sequencing precondition): `install.sh --adopt-quarantine` exit 0;
  `run_all.sh` exit 0 (unittests 27/27; 1J attacks 48/48 incl. the
  reachability enumeration 3474/386/0; R1 48/48, R2 87/87, R3 181/181
  with K↔Python cross-checks; 1E/1F/1G green); the vector
  semantic-equivalence check PASS (23/23 fields); `verify_all.sh` PASS
  post-restoration (55/55) — the Phase 1K-R1 corrective evidence.
- **The frozen 1J kprove ladder re-run fresh** from the corrected base:
  38/38 claims that PROVED at 1J reproduced PROVED (the 4 retained-class
  claims re-run bounded by the wrapper budget; their frozen full-run logs
  stand as the record — the 1K disclosure carried forward).
- **The frozen 1J LLVM T-series re-run fresh** from the package sources:
  14 executed demos + 5 kparse rejections, and the decisive T0
  certificate, T2 honest two-block pipeline, T6 unsafe-composition
  rejection, and the self-computed anchor are BYTE-IDENTICAL to the
  frozen 1J records modulo the header lines.
- **The 1J Python suites re-run fresh**: unittests 27/27 OK; the attack
  matrix 48/48 PASS.

## 4. The K proof ladder (the raw discipline)

30 claims, one definition, one canonical pass, per-claim exit codes and
retained logs (`transcripts/k/`, `claims-status.csv` + the scientific
classification in `claims-classification.csv`):

- **PROVED (14)** — the frames (anchor/config/catalog untouched by the
  dispatch step), the pre-init family (nothing pinned, no receipts, no
  committed history; refused commands change nothing), the refusal
  family (unsupported/bounds write only the diagnostic and mint nothing;
  the source-refusal class moves no committed cell and mints no receipt
  on EVERY resolution path — including the stuck path), and the
  commit-rejection family (stale slot, consumed receipts, forged
  verdicts, prior-slot exec receipts — the freshness ties decided
  CONCRETELY).
- **NOT MECHANIZED (11, blocked — attempts retained)** — the
  invariant-carrying steps that must materialize hash-rooted builders
  over symbolic arguments: the gate/exec mint steps, the accept-poststate
  step, the symbolic-config init base, and the two universal
  compositions (all-path, committed-prefix).
- **FINDING WITNESS (1)** — L-INV-EXEC-DISPATCH-SOURCE (see §6).
- **NEGATIVE CONTROLS / EXPERIMENTS (4, all failed as designed)** — the
  destination-constraint idiom pair (B2), the SafeJ-removal control, and
  the weakened-invariant all-path control (the pair that exposes a
  vacuous circular closure).

Score: 14 PROVED / 0 gate alarms over the full inventory; the runner
exits 0 when every raw outcome matches its expectation — the retained
failures are the DESIGNED honest outcomes, not silent skips.

## 5. Why the universal theorem is NOT MECHANIZED (the blocker census)

`audit/induction-diagnosis.md` carries the full census; the four blockers:

- **B1 — the hash-definedness boundary (dominant).**  kore discharges
  `#Ceil(Keccak256raw(x))` only over fully-literal arguments.  Every
  blocked claim's final residual is an undischargeable Ceil over a
  symbolic (or hash-containing) argument — probed minimally and
  confirmed by the ladder's own residuals.  Total wrappers and
  reflexivity hypotheses do NOT rescue it.  Every hash EQUALITY remains a
  claim hypothesis where it is one; the boundary is about materializing
  hash applications, not about any assumed hash property.
- **B2 — the destination-constraint idiom is unusable** (`requires` is
  evaluated at the source; destination-only variables make it stuck) —
  the experiment pair documents it; the ladder therefore carries the
  invariant by shared cells and exact destination terms.
- **B3 — the pool-Ceil class** — set well-formedness over symbolic
  receipt builders; concrete pool shapes (`.Set`) refute the accept
  unification and prove — the working convention applied systematically.
- **B4 — the stuck-gate path** — a pGateEvalJ with unmet mint
  preconditions matches NO rule (documented non-commit, handoff §3
  item 5); a stuck configuration does not match the all-path claim's
  source pattern, so the circular re-application dies.

The [circularity] forall-n recipe (the Phase 1B GH-T2 precedent) does
not transfer: 1B's invariant was decidable arithmetic on concrete cells,
so the circular re-application VERIFIED it; the J machine's `SafeJ` over
symbolic maps is a stuck term the re-application can only ASSUME — a
closure would be vacuous w.r.t. safety, exactly what the paired negative
control was run to detect.

## 6. The finding against the frozen semantics (L-FINDING-1)

The frozen unauthorized-source dispatch rule's `<jlineage>` pattern is
the single-entry map `-1 |-> cfg` with NO tail variable: in a
fully-pinned machine the rule cannot match, so an unauthorized-source
execution is STUCK — the `jrefusedSource()` diagnostic never fires (the
frozen 1J T11 transcript shows exactly this stuck configuration).
Safety is preserved (stuck = no transition = no receipt = no committed
movement; PROVED as L-INV-EXEC-SOURCE-NOCOMMIT), but the documented
explicit-refusal expectation is impaired and the K machine diverges from
the Python mirror on this one resolution (both fail-closed).  Per the
handoff §3 protocol the model is NOT repaired inside Phase 1L (the 1J
tree is frozen); the repair (adding the map-tail variable) belongs to a
separately justified commit.

## 7. The theorem, stated exactly (and its boundary)

Under the assumptions of the frozen 1J surface (the authenticated
external anchor; Keccak collision resistance; frozen-gate soundness; the
registered finite invariant language; the declared execution-source
authenticity boundary — `audit/assumption-register.md`), and for the
DECLARED finite policy fragment and the four-operation `EVM_F` fragment:

- **MECHANIZED (this phase):** the invariant predicate over the actual
  machine configurations; the frame, pre-init, refusal, and
  commit-rejection/freshness step families; the freshness ties that rule
  out cross-commit receipt reuse; the structural rule inventory (only
  the accepted commit writes the state, and it writes exactly the term
  its guard certified).
- **NOT MECHANIZED (honest):** the universal composition — "for every
  finite execution beginning in the defined initial configuration with
  an authenticated anchor, every configuration reached after
  successful initialization satisfies the J safety invariant".  The
  base and the per-class steps are mechanized to the backend's boundary;
  the composition itself is blocked by B1-B4.  The 1J concrete
  substitutes (the 3,474-prefix enumeration with 386 unsafe derived
  states caught and 0 committed unsafe; the LLVM honest/unsafe
  pipelines) remain DEMONSTRATED evidence, not proof.
- **NOT CLAIMED:** full-EVM trace authenticity, arbitrary-policy
  closure, anchor governance, Ethereum consensus enforcement, or any
  statement that "Ethereum applications cannot weaken foundational
  security".  Level III only; no consensus-integration claim.

## 8. Completion gate (handoff §8), item by item

| gate item | disposition |
|---|---|
| 1K verification fresh clean install/run/verify; mismatch resolved; verify fails on required-field omissions | the Phase 1K-R1 corrective commit `b1dbe90` (tag `phase1k-r1-complete`; `phase1k-complete` preserved at `d32ad13`); PASS |
| 1L starts from the corrected 1K commit, additive `phase1l/` only | branch base `b1dbe90`; git diff outside `phase1l/` EMPTY (worklog update only) |
| frozen trees byte-identical to the 1K base | verified (`git status` clean; the transient in-place transcript regeneration for the LLVM re-run was restored byte-exact before commit — the established 1I/1J pattern) |
| every K claim: exit code, full log, raw result, classification | 30/30 (`claims-status.csv` + `claims-classification.csv`) |
| the invariant not assumed in its own induction step | SafeJ enters only via the computed guards / shared cells; the negative control verifies the dependency |
| all transition classes accounted for | rule-inventory.md + the per-class claims (init/exec/dispatch/gate/reject; the stuck gate case = B4 disclosure + L-A19) |
| all-path theorem mechanically proved, or explicitly NOT MECHANIZED with a minimal retained failure and a clear explanation | **NOT MECHANIZED**; the attempts retained; the blocker census at kore-residual level |
| Python enumeration and LLVM demos pass unchanged; not substituting for induction | 48/48 + 27/27 fresh; T0/T2/T6 + anchor byte-identical fresh; classified DEMONSTRATED only |
| proof reports distinguish PROVED / DEMONSTRATED / CHECKED / ASSUMED / NOT MECHANIZED | the classification CSV + this report |
| no consensus-integration or full-EVM claim | §7 |

## 9. Artifact index

`phase1l/semantics/j_invariant.k` · `phase1l/proofs/{l_proofs.k,
run_l_proofs.sh}` · `phase1l/transcripts/k/` (30 logs + status +
classification + the 1J fresh re-run record + README) ·
`phase1l/transcripts/llvm/` (the fresh T-series) ·
`phase1l/transcripts/attacks/` (L-attacks 56/56; the fresh 1J suites) ·
`phase1l/audit/` (induction-diagnosis, rule-inventory, findings,
assumption-register) · `phase1l/python/run_l_attacks.py` ·
`phase1l/provenance/` · this report (MD + PDF).
