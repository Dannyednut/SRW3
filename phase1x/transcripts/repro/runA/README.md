# Phase 1X — reproducibility layout: runA / runB

Two independent executions of the hardened Phase 1X ghost battery
(`phase1x/proofs/run_1x_ghost.sh`), compared by
`phase1x/scripts/compare_runs_1x.py` (logical verdicts only; wall-clock and
environment-absolute paths excluded by design — the 1W-disclosed path-only
drift allowance).

## runA/ — the committed Phase 1X Run A (preserved in situ)

Run A's evidence is the ORIGINAL committed Phase 1X evidence set and is
preserved EXACTLY where it was committed at `e70e863` — the per-claim
transcripts live in `phase1x/transcripts/ghost/` and the verdict ledger in
`phase1x/claims/ghost-verdicts-1x.csv` (both still at their committed
content; nothing was re-run over them). This directory only carries
convenience copies for the parallel layout:

- `ghost-verdicts.csv` — copy of the committed Run A ghost verdict ledger
  (= `phase1x/claims/ghost-verdicts-1x.csv` at `e70e863`)
- `sha256.txt` — copy of the committed Run A transcript digest manifest
  (= `../runA-sha256.txt` at `e70e863`)

Provenance: Run A was executed in the Phase 1X session on the pinned
toolchain (K v7.1.337, Z3 4.13.3); it is the recovered run of the
sandbox-destroyed first implementation (see `phase1x/README.md` §Session
note, R14).

## runB/ — the follow-up Run B (independent clean environment)

Executed 2026-10-30 in a FRESH `git clone` of this branch at the follow-up
head `9e8e5ad` (clean checkout, fresh mktemp workspaces, no shared state
with Run A beyond the committed sources):

- `ghost-verdicts-1x.csv`, `claims-1x.csv`, `exit-codes-1x.csv` — Run B's
  fresh ledgers (built in the runB workspace by `build_ledgers_1x.py`)
- `transcripts/` — Run B's full raw evidence (48 per-claim kprove logs
  `kpg_1x_*`, 4 kompile logs, the GEN stage certificates
  `ghost_manifest_{freeze,verify}_1x.txt` and generator transcripts)
- `COMPARISON-runA-vs-runB.txt` — output of `compare_runs_1x.py`:
  **RUNS LOGICALLY IDENTICAL** (48/48 tags; census 12/12/12/11 + 1 fidelity)
- `regressions-from-runB-checkout.log` — the FULL sequence
  (runner → build → gate → regressions) executed in the runB clean
  checkout: `31 PASS / 0 FAIL`
- `toolchain-versions.txt` — live versions captured in the runB environment
  (K v7.1.337, Z3 4.13.3, OpenJDK 21.0.13, Python 3.12.16)
- `sha256.txt` — digests over this directory (see
  `../../transcripts/repro/evidence-manifest-1x.txt` for the full manifest)

Level III only. Logical identity of two independent runs is evidence about
the EVIDENCE PIPELINE's determinism, not a completeness claim (verdict
remains PARTIALLY COMPLETE).
