# SRW3 Phase 1L — The Universal Induction Proof Ladder: Raw Results

Definition: the FROZEN Phase 1J machine + the Phase 1L proof-facing invariant
definitions (`phase1l/semantics/j_invariant.k` — `[function, total]`
definitions and total wrappers ONLY; no J semantic change).  Backend:
Haskell (kprove, K v7.1.337, z3 4.13.3).  Runner:
`phase1l/proofs/run_l_proofs.sh` — every claim invoked exactly once in the
canonical pass, raw exit code + retained log.

## Canonical result (this pass, 30/30 claims invoked, 0 gate alarms)

14 PROVED / 16 failed-as-expected (blocked attempts + negative controls).
The per-claim scientific classification lives in
`claims-classification.csv`; the raw results are NEVER relabeled.

PROVED (14):
- L-INV-ANCHOR-FRAME-EXEC            (dispatch-step anchor frame)
- L-INV-CATALOG-FRAME-EXEC           (dispatch-step pinned-config/catalog frame)
- L-INV-PREINIT-INIT-REFUSES         (refused init from pre-init changes nothing)
- L-INV-PREINIT-COMMIT-REFUSES       (pre-init commit cannot reach accept)
- L-INV-EXEC-REFUSAL-UNSUPPORTED     (refusal writes only the diagnostic)
- L-INV-EXEC-REFUSAL-BOUNDS
- L-INV-EXEC-REFUSAL-SOURCE
- L-INV-EXEC-DISPATCH-UNSUPPORTED    (dispatch resolution into diagnostics)
- L-INV-EXEC-DISPATCH-BOUNDS
- L-INV-EXEC-SOURCE-NOCOMMIT         (no committed movement on ANY source-refusal path)
- L-INV-COMMIT-REJECT-STALE-SLOT     (freshness refutation, concrete)
- L-INV-COMMIT-REJECT-REUSED-RECEIPT (empty post-consumption pools refute accept)
- L-INV-COMMIT-REJECT-FORGED-VERDICT (fail-closed derived decision)
- L-INV-COMMIT-HEAD-STATE-COHERENCE  (exec-receipt slot freshness tie)

NOT MECHANIZED — blocked (11, each with its retained log + named blocker):
- L-INV-ANCHOR-FRAME-GATE, L-INV-ANCHOR-FRAME-COMMIT-REJECT,
  L-INV-CATALOG-FRAME-COMMIT-REJECT, L-INV-INIT-BASE,
  L-INV-EXEC-OK-STEP-POOL, L-INV-EXEC-OK-STEP-FRESH,
  L-INV-GATE-STEP-POOL, L-INV-GATE-STEP-FRESH,
  L-INV-COMMIT-ACCEPT-POSTSTATE, L-INV-ALLPATH-REACHABILITY,
  L-INV-COMMITTED-PREFIX-SAFE

FINDING WITNESS (1): L-INV-EXEC-DISPATCH-SOURCE (L-FINDING-1 — see
audit/findings.md; the frozen T11 transcript shows the same stuck
configuration).

NEGATIVE CONTROLS / EXPERIMENTS (4, all failed as designed):
- L-EXP-DESTVAR-POS / L-EXP-DESTVAR-NEG (the destination-constraint idiom
  is unusable — requires is evaluated at the source)
- L-NEG-CONTROL-SAFEJ (the accept-step safety conclusion depends on the
  guard's SafeJ conjunct)
- L-NEG-ALLPATH-WEAKSAFEJ (the all-path closure would be vacuous w.r.t.
  safety — the control failing confirms the blocker is the hash boundary,
  not the invariant)

## The fresh re-run of the FROZEN 1J ladder (regression context)

From the corrected Phase 1K base (`b1dbe90`), the frozen 1J kprove ladder
was re-run fresh with the rebuilt pinned toolchain: **38/38 claims that
PROVED at 1J reproduced PROVED** (logs + the runner's .done markers in this
directory, `kompile_j.log` is the fresh compile).  The 4 retained-class
claims (J-EVIDENCE-STATE-CORRESPONDENCE, J-COMMIT-UNSAFE-COMPOSITION-REJECTS,
J-COMMIT-IMPLIES-SAFE-DESTINATION, J-REACHABLE-COMMITTED-SAFE) were re-run
bounded at the re-run wrapper's per-claim budget (rc=124 entries in
`claims-status.csv` is the 1L ladder's CSV; the 1J re-run used the frozen
runner whose CSV truncates per invocation — the .done markers + logs are the
per-claim record); their FROZEN full-run logs remain the authoritative
record of the retained class, exactly as disclosed at Phase 1K.

## Reproduction

```sh
source /home/z/my-project/tools/env.sh
REKOMPILE=1 bash phase1l/proofs/run_l_proofs.sh <outdir>
# per-claim budget: LCLAIM_TIMEOUT=<seconds> (the canonical pass used 400)
```
