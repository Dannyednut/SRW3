# SRW3 Phase 1R — Fold Decomposition, Bounded Prefixes, and Universal Safety

**Branch:** `phase1r-fold-decomposition` (from the verified Phase 1Q commit
`f6c510685220e1e13ab94761e2593d3e3a8dc482`).
**Toolchain:** K v7.1.337 + z3 4.13.3 (the pinned recipe, rebuilt after the
eighth sandbox reset; see `audit/baseline-1r.md` §1).
**Question of record:** can the per-transition guarantees and the
initialized-prefix result be turned into a sound proof for every finite
executable run, WITHOUT asking the checker to explore an unbounded
circular tree all at once?

## Layout

| path | content |
|---|---|
| `audit/baseline-1r.md` | the verified baseline, the 1Q claim-count reconciliation (83, not 81), the `1Q-UNIV-MACHINE-Q` evidentiary dispositions |
| `audit/grid-verification-1r.txt` | the structural exhaustiveness witness (frozen-source sha anchors, the 18-rule step partition, the single dispatch requires, the 4+16 fork cover) |
| `spec/fold-decomposition.md` | the formal starting point, the diagnosis targets (F1 branch factor, F2 state-threading), the decomposition architecture, the labeling contract |
| `proofs/n_r_bound_ladder.k` | Experiment A: the symbolic-command-spine depth ladder d=0..5 + the DEST control pair |
| `proofs/n_r_step_one.k` | Experiment B: the one-step preservation theorem (all commands, no circularity) |
| `proofs/n_r_univ_composed.k` | Experiment C: the tag-pinned universals, the composition, the fold-form exhibits |
| `proofs/run_1r.sh` | the fail-closed runner (stages B/A/AD/ST/C/FF/N/S) |
| `scripts/summarize_1r.py` | the fail-closed summarizer (the 1Q discipline + the BOUNDED-PROVED and extended SELF-ASSUMED rules) |
| `scripts/verify_grid_1r.py` | the pure-reader structural witness (never writes) |
| `claims/claims.csv` | the claim ledger (stable ids, exact propositions, budgets, exit codes, classifications) |
| `claims/exit-codes-1r.csv` | the runner's raw exit/wall records (last-wins) |
| `transcripts/k/` | every raw kprove log |
| `report/phase1r-final-report.md` | the 12-element final report |

## The experiments

* **A — bounded diagnostics**: for each concrete depth d, a universal claim
  over the SYMBOLIC command spine of length d (`aConsJ(AC1, …, aConsJ(ACd,
  aRunNilJ))`, every command position symbolic, both pool tails arbitrary).
  Each is a FIXED-DEPTH THEOREM (finite unrolling + evaluation). The ladder
  measures how proof cost grows with execution depth.
* **B — one-step preservation**: the single transition-preservation claim
  over all commands and both branch families, no circularity. The
  exhaustiveness evidence is behavioral (the closed terminal with zero
  residual, the [owise] complement inside the explored relation) plus the
  structural witness (`verify_grid_1r.py`).
* **C — the fold decomposition**: the tag-1-pinned universal (PREFIX-Q's
  big sibling), the tag-0-pinned universal (init-accept the only re-tag;
  the post-init tail governed by the proved TAG1 lemma), and the
  composition of both into the UNPINNED universal — with the fold-form
  exhibits recording exactly which induction hypothesis the checker cannot
  discharge (and why the fold-form circularity is a trap: it closes by
  zero-progress self-application, classified SELF-ASSUMED, never a proof).
* **D — backend/induction assessment**: only on the evidence of A–C (see
  the final report §11).

## Reproduction

```
bash scripts/reinstall_toolchain_1m_r3.sh          # the pinned recipe (idempotent)
source /home/z/my-project/tools/env.sh
export LIBRARY_PATH="$TOOLS/extract/syslibs:$LIBRARY_PATH"
python3 phase1r/scripts/verify_grid_1r.py          # structural witness
bash phase1r/proofs/run_1r.sh B A AD ST C FF N     # the ladder (foreground batches)
python3 phase1r/scripts/summarize_1r.py            # the gate
```
`INC="-I $PWD/phase1n/semantics -I $PWD/phase1m/semantics -I
$PWD/phase1g/semantics -I $PWD/phase1f/semantics -I $PWD/phase1e/semantics
-I $PWD/k/phase1d -I $PWD/k/kevm/kproj-e1e/plugin"` (baked into the
runner). Budgets are per-claim; timeouts are recorded as TIMEOUT, never as
refutations.

## The labeling contract (enforced by the summarizer)

`PROVED` = non-trivial mechanically proved theorem · `BOUNDED-PROVED` =
fixed-depth theorem (the ladder; NEVER the universal) · `PROVED-EVAL` =
evaluation closure · `TIMEOUT` = non-termination, never a refutation ·
`SELF-ASSUMED` = closed by circular self-application, never a proof ·
`UNSOUND-CLOSURE` = the hole exhibits. Frozen Phase 1N–1Q artifacts are
untouched; the only shared-file change is the root `worklog.md` entry.
Level III only; no consensus-integration claim.
