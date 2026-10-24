# SRW3 Phase 1R — Baseline and Evidence Reconciliation (audit/baseline-1r.md)

Generated: 2026-10-24 (the session of record). All paths relative to the
repository root. Toolchain: **K v7.1.337 + z3 4.13.3** (versions printed at
rebuild time; the pinned recipe `scripts/reinstall_toolchain_1m_r3.sh`
re-executed as `/home/z/my-project/scripts/reinstall_toolchain_1r.sh` — a
sandbox-side copy with only the repo path adapted; NOT committed; log:
`/home/z/my-project/tool-results/toolchain_1r_rebuild.log`).

## 1. Repository state at phase start

* The eighth sandbox reset had wiped the workspace (`/home/z/my-project/SRW3`
  was absent; the previously recorded toolchain under
  `/home/z/my-project/tools/` was absent). The repo was re-cloned fresh from
  `github.com/Dannyednut/SRW3` and every checkpoint below was verified on
  the fresh clone BEFORE any file was created.
* Remote `refs/heads/phase1q-constructor-pools` = `f6c510685220e1e13ab94761e2593d3e3a8dc482`
  (verified by `git ls-remote`).
* Remote `refs/heads/phase1p-branch-tag-encoding` = `83dd01571adccb77e51adcf5499c9a2480caaeaf`.
* Ancestry verified: `git merge-base --is-ancestor
  83dd01571adccb77e51adcf5499c9a2480caaeaf
  f6c510685220e1e13ab94761e2593d3e3a8dc482` → OK (1Q descends from 1P;
  1Q's parent commit is the verified 1P commit; 1P's parent is the 1O
  freeze `cdb55568771d3fd1874741a845f75620b078ee35`).
* Branch of record: `phase1r-fold-decomposition`, created FROM the verified
  Phase 1Q commit: `git checkout -b phase1r-fold-decomposition f6c5106…`.
* Working tree clean at branch creation (the clone's only dirt is outside
  the repo: sandbox-side `download/` artifacts of Phase 1D, not repo files).
* The toolchain sanity block of record (from the rebuild log):
  `K version: v7.1.337`, `Z3 version 4.13.3 - 64 bit`, `TOOLCHAIN_R3_DONE`.

## 2. The Phase 1Q evidence inventory, reconciled (mission §3)

### 2.1 The claim-count discrepancy: REPORTED 81, LEDGER 83 — corrected total 83

Reproducible count (the raw CSV is comma-quoted; a naive field split
overcounts nothing but an `awk -F,` print of the last field garbles notes —
use a real CSV reader):

```
python3 - <<'EOF'
import csv
rows = list(csv.DictReader(open('phase1q/claims/claims.csv')))
print(len(rows), len(set(r['claim_id'] for r in rows)))
EOF
# -> 83 83
```

Source of the discrepancy, identified by differencing the claim inventory
against the proof runner's own claim list (`phase1q/proofs/run_q_univ.sh`,
all direct `run_claim` calls plus every `for C in …` list — 81 distinct
claim ids):

* The **runner lists exactly 81 claims** (12 toy-ladder + 47 lemma-family +
  2 universal attempts + 9 negative battery + 6 mutant battery + 4
  diagnostics + 1 baseline repro). The final report's §5 heading —
  "The proof ledger (81 claims; full inventory `claims/claims.csv` …)" —
  counts the RUNNER's list, not the ledger.
* `phase1q/claims/claims.csv` carries **83 rows, all distinct ids**. The
  two rows beyond the runner's list are `1Q-STRONG-EMPTY-REJECT-STEP-Q`
  and `1Q-WEAK-W2-STEP-EVAL-Q` — both are cited in the report's §6
  (controls 1 and 8), both have raw logs under `phase1q/transcripts/k/`
  (`kprove_1Q-STRONG-EMPTY-REJECT-STEP-Q.log`, 21,963 bytes;
  `kprove_1Q-WEAK-W2-STEP-EVAL-Q.log`, 22,744 bytes), and both were
  executed outside the staged runner (manual runs recorded last-wins).
  They are legitimate evidence rows that the report heading failed to
  count.
* The Phase 1Q **commit message** already says "83 claims" and its
  scoreline (6 PROVED / 46 PROVED-EVAL / 24 FAILED-STUCK / 5 TIMEOUT /
  1 SELF-ASSUMED / 1 UNSOUND-CLOSURE = 83) matches the ledger exactly.
* The summarizer of record (`phase1q/scripts/summarize_1q.py`) gates on
  the CSV and prints "83 claims listed"; re-run at 1R start on the
  retained evidence it reproduces **GATE GREEN** with the exact 1Q
  scoreline (exit 0, zero alarms).

**Correction of record: the Phase 1Q claim total is 83** (81
runner-listed + 2 manually executed, all with retained logs). The 1Q
report heading's "81" is a heading-counting error; the ledger, the commit
message, and the summarizer were already consistent at 83. NO claim row
was deleted, edited, or re-classified to produce this reconciliation.

### 2.2 The `1Q-UNIV-MACHINE-Q` timeout evidence (mission §3.2)

Exactly three transcript artifacts + the audit record + the ledger rows
were inspected; all are preserved byte-identical (frozen):

| artifact | size | what it establishes |
|---|---|---|
| `phase1q/transcripts/k/kprove_1Q-UNIV-MACHINE-Q.log` | **0 bytes** | the form-of-record foreground attempt: `timeout 560` produced NO output — consistent with a process killed by the ceiling before/during any terminal report; with the runner's `rc=124` record in claims.csv (budget 560) this supports the **TIMEOUT disposition** and nothing stronger |
| `phase1q/transcripts/k/kprove_1Q-UNIV-MACHINE-Q-attempt1.log` | 24,929 bytes | NONEMPTY: the retained first attempt (run on the disclosed B-S-buggy machine, per `audit/baseline-1q.txt` §5) terminated `rc=1` with **`kore-exec: Error (DecidePredicateUnknown)`** — a real DECIDER residual (12 negated constructor equalities over the symbolic command, the `[owise]` domain predicate's owise condition at `abs-machine-q.k:340:8-341:43`). This artifact establishes the checker's decision boundary that motivated the EQ-F′ fix; it does NOT establish the form-of-record residual |
| `phase1q/transcripts/k/kprove_1Q-UNIV-MACHINE-Q-extended.log` | **0 bytes** | the extended detached attempt (~3600s budget): stopped while the kore-exec phase was still running (the process diagnostics — one full core, ~370 MB RSS, state R — are in `phase1q/audit/baseline-1q.txt` §6); empty log + the stop record support **NON-TERMINATION**, not any terminal residual |
| `phase1q/audit/baseline-1q.txt` §5–6 | — | the process/wall records: 560s foreground ceiling; the extended attempt's kore-exec phase 35+ min at ~83% CPU without terminating |
| `phase1q/claims/claims.csv` rows `1Q-UNIV-MACHINE-Q` | — | exit_code 124 recorded; note field discloses all three attempts and states "NOT MECHANIZED; no completion tag" |

**Evidentiary distinction kept explicit (mission §3.2):** the empty logs +
exit 124 support a timeout disposition ONLY because the runner and process
records justify it; they do NOT establish a proof residual or a
counterexample. The only residual ever recorded for this claim is the
attempt1 `DecidePredicateUnknown` — produced by the buggy pre-fix machine
and superseded by the EQ-F′ fix of record.

### 2.3 The 1R live reproduction of the timeout disposition

The form-of-record attempt was re-run live on the rebuilt pinned toolchain
(the definition of record `/tmp/p1q-q-def`, kompile rc=0):

```
timeout 560 kprove phase1q/proofs/n_q_univ_q.k $INC -d /tmp/p1q-q-def \
  --spec-module Q-UNIV-PROOFS --claims 1Q-UNIV-MACHINE-Q
```

Result: **rc=124, empty log** —
`phase1r/transcripts/k/kprove_1Q-UNIV-MACHINE-Q-1r-repro.log` +
`kprove_1Q-UNIV-MACHINE-Q-1r-repro.rc`. The 1Q timeout disposition
REPRODUCES on the rebuilt toolchain (same signature: no output within the
560s ceiling). Recorded as TIMEOUT; never as refutation or residual.

### 2.4 The Phase 1Q starting facts (mission §4), re-anchored on the retained evidence

* `Q1F-TOY-UNIV-FORKED` — PROVED, zero `WarnTrivialClaim` (log retained;
  re-run in the 1R ladder as a regression anchor).
* Per-class preservation 14/14, coherence 6/6 — PROVED (logs retained).
* `1Q-UNIV-PREFIX-Q` — PROVED, zero `WarnTrivialClaim`, start-tag-pinned
  form of record (re-run in the 1R ladder).
* C1 (general nonnegativity) and C5 (free-constructor exhaustiveness) —
  OPEN (rc=1 residuals retained); several C2 rows carry the disclosed
  C1-DEP hypothesis (the dependence was MEASURED by GATE-MINT-NODEP).
* `1Q-UNIV-MACHINE-Q` — OPEN (non-terminating circular exploration).
* NO theorem at the concrete SRW3 commitment boundary.
None of these were silently upgraded: per-class evaluation-closures remain
classified `PROVED-EVAL`, bounded tests remain `BOUNDED`.

## 3. Frozen-tree discipline

* Phase 1N/1O/1P/1Q files: untouched by construction (all 1R material
  under `phase1r/`; the only shared-file change is the root `worklog.md`
  1R entry, per the established shared-file protocol).
* `git status` at the 1R audit gate: new paths under `phase1r/` only.
* The 1Q generator's frozen-source check (`make_abs_q.py` prints the 1P
  TDRR sha256 `448db6a4…` on every run) re-executed in the 1R controls.
