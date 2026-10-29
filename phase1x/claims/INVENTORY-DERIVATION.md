# Expected-inventory derivation record (Phase 1X)

Base commit of the derivation: `34ef2321f2875682bd03adf7eb5f601e256cf7ad`
(the verified Phase 1W head; branch `phase1x-ghost-runner-hardening` was cut
from it). Every list in `expected-ghost-inventory.json` was derived from the
COMMITTED claim-specification artifacts at that commit, NOT from splitter
runtime output and NOT from any ledger row count.

Provenance note: this is the SECOND derivation of the same inventories. The
first implementation (with an identical inventory) was destroyed by a sandbox
reset on 2026-10-29 before its commit could be pushed (register R14's
process risk, realized); it was re-derived from the same committed artifacts
by the same commands and cross-checked identically. The INVENTORIES are
deterministic functions of the committed artifacts, so the loss was fully
recoverable and no evidence was weakened.

## Derivation commands (executed 2026-10-29, in the Phase 1X working tree)

```sh
# main suite — 12 labels from the committed ghost artifact
grep -o 'label([A-Za-z0-9-]*)' proofs/induction_ghost.k
# → GH-BASE GH-A GH-R GH-SOUND-I GH-SOUND-F GATE-AGREE GH-ISO GH-T1
#    GH-T GH-T2 GH-M GH-T2-NEG            (12; order as committed)

# generalized suites — 12 / 12 / 11 labels from the committed gen artifacts
grep -o 'label([A-Za-z0-9-]*)' proofs/gen/cm2_alias.k   # GH2-… ×12 (incl. GH2-A1)
grep -o 'label([A-Za-z0-9-]*)' proofs/gen/cm3_auth.k    # GH3-… ×12 (incl. GH3-A1)
grep -o 'label([A-Za-z0-9-]*)' proofs/gen/gen_full.k    # GH4-… ×11 (NO GH4-A1)
```

The generalized label sets were then matched to their observation-module
prefixes (`SRW3G2`/`SRW3G3`/`SRW3G4`) via the artifacts' module declarations
and the historical GENSPEC invocation shape (`run_1w_ghost.sh` stage GENSPEC).

## Cross-checks performed at derivation time

1. **Ledger arithmetic**: 12 + 12 + 12 + 11 = 47 claim rows; +1
   `ghost-exact-fidelity` certificate row = 48 rows — matches the committed
   `phase1w/claims/ghost-verdicts-1w.csv` (48 data rows, all distinct tags).
   The 48 is a CONSEQUENCE of the inventory, never an input to it.
2. **Suite asymmetry pinned**: `gen_full` has no `A1` claim; `cm2_alias` and
   `cm3_auth` each do. A future artifact/splitter change in either direction
   must be REJECTED by the label check, not silently absorbed.
3. **Per-claim status evidence**: every expected status in the inventory is
   backed by the committed 1W transcripts
   (`phase1w/transcripts/ghost/kpg_1w_<CLAIM>.log`) and re-established by the
   fresh Phase 1X runs (see `phase1x/report`):
   - PROVED rows: rc=0, exactly one `#Top`, no prover `[Error]`, no
     `WarnStuckClaimState`;
   - `GH-T`, `GH-T2-NEG`, `GH2-NEG`, `GH3-NEG`, `GH4-NEG`: rc=1 WITH
     `WarnStuckClaimState` + `backend terminated` (the FAILED-STUCK
     signature) — the Phase 1W ledger recorded these under the coarser
     `FAILED` label; Phase 1X pins the specific status per the report's
     vocabulary (register R5 keeps GH-T FAILED-STUCK; correcting the
     runner's label does not change the theorem's status).
4. **Independence**: `expected-ghost-inventory.json` and
   `expected-model-inventory.json` are reviewed data files on the branch.
   They are the ONLY source of expected labels/IDs for the runner and the
   gate; neither tool derives expectations from runtime splitter output or
   row counts.

## Maintenance rule

Any change to a claim artifact (add/remove/rename a `label(...)`) MUST be
accompanied by a reviewed, committed update to this inventory on a phase
branch, with the derivation re-run and the cross-checks re-executed. A
mismatch between artifact and inventory is a hard failure by design.
