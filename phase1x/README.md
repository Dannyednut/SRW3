# SRW3 Phase 1X — Ghost-Runner Integrity, Proof-Status Fidelity, and State-of-Record Repair

Branch `phase1x-ghost-runner-hardening`, cut from the verified Phase 1W head
`34ef2321f2875682bd03adf7eb5f601e256cf7ad` (the documentation-only landing
commit; the delivered 1W review state `19990a53f6d249871509d0a9875a1ac85c3d2b98`
is its parent and remains verbatim-reviewable).

**Verdict: PARTIALLY COMPLETE** (unchanged — a runner-integrity phase closes
tooling defects and evidence-classification gaps; it does not close theorems).

## Contents

| Path | What it is |
|---|---|
| `proofs/run_1x_ghost.sh` | the hardened ghost runner (R13 label pinning + status-aware per-claim classification + isolation hardening) |
| `scripts/classify_1x.py` | THE result classifier (one function, shared by runner + tests): PROVED / FAILED / FAILED-STUCK / TIMEOUT / NOT-RUN / INVALID-SUCCESS / UNKNOWN |
| `scripts/check_labels_1x.py` | the splitter-vs-inventory assertion tool (rejects missing/extra/duplicate/empty before any K invocation) |
| `scripts/build_ledgers_1x.py` | claims/exit-codes ledger builder (fixture-provenance-aware) |
| `scripts/summarize_1x.py` | the strict gate: exact per-ledger counts (46/48/94 each its OWN constant), exact claim-ID inventories, status vocabulary, non-relabelling, transcripts, last-wins |
| `claims/expected-ghost-inventory.json` | the PINNED expected label sets (12/12/12/11) + per-claim expected statuses + design roles |
| `claims/expected-model-inventory.json` | the PINNED 46-ID model inventory (from the immutable 1W ledger) |
| `claims/INVENTORY-DERIVATION.md` | how the inventories were derived (from committed artifacts, never from splitter runtime output or row counts) |
| `claims/*.csv` | the fresh Phase 1X verdict ledgers + built claims/exit-codes ledgers |
| `tests/run_1x_regressions.sh` | the adversarial regression suite (12-case mandate table + old-runner weakness reproduction; mutation cases run on sandbox copies only) |
| `transcripts/ghost/` | raw per-claim kprove logs of the fresh Phase 1X runs (`kpg_1x_*`), kompile logs, fidelity certificates |
| `transcripts/repro/` | runA/runB comparison artifacts, regression logs, hash manifests |
| `report/phase1x-final-report.md` | the fail-closed phase report (root cause, corrections, assumptions, limits, acceptance table) |

## The defects this phase closes (registered R13 + the B-finding)

1. **R13** — the 1V/1W ghost runners derived their claim list from
   `split_ghost_claims.py` output without pinning the expectation: a splitter
   regression dropping a claim would shorten the battery while the runner
   still exited green. Fixed: the expected label sets are pinned in a
   reviewed data file and asserted BEFORE any `kprove` invocation.
2. **Shared count set** — `summarize_1w.py` accepted `{46, 48, 94}` for
   EITHER verdict ledger. Fixed: each ledger is checked against its own
   exact constant AND its exact claim-ID inventory (count alone is not
   identity).
3. **GENSPEC closure evidence** — the 1W generalized loop classified a claim
   PROVED on exit code alone (no `#Top` check). Fixed: PROVED now requires
   rc=0 + `#Top` + a clean log, everywhere.
4. **GH-T status fidelity** — the 1W runner/ledger recorded the coarse
   `FAILED`; the report and register record `FAILED-STUCK` (the transcript
   carries the stuck signature). Fixed: `FAILED-STUCK` is asserted from the
   diagnostic signature (`WarnStuckClaimState` + prover backend termination),
   per claim, without rewriting any 1W file.

## Session note (R14 realized)

The first Phase 1X implementation (identical inventories + code, with its
complete Run A) was destroyed by a sandbox reset on 2026-10-29 BEFORE its
commit could be pushed. It was recovered by re-derivation from the committed
artifacts (the inventories are deterministic functions of them) and
re-execution of the full battery; see the worklog and
`claims/INVENTORY-DERIVATION.md`. This run's evidence is the recovered Run A.

## Reproduce

```sh
bash phase1x/proofs/run_1x_ghost.sh              # full battery (needs the pinned toolchain)
python3 phase1x/scripts/build_ledgers_1x.py
python3 phase1x/scripts/summarize_1x.py          # GATE GREEN expected
bash phase1x/tests/run_1x_regressions.sh         # the adversarial suite
```

Level III only. A green runner/gate is NOT a completeness claim.
