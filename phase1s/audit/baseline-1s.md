# SRW3 Phase 1S — Baseline Verification and Reproduction (audit/baseline-1s.md)

Date of record: 2026-10-25. Toolchain: **K v7.1.337 + z3 4.13.3** (pinned
recipe re-executed from `scripts/reinstall_toolchain_1b.sh` after the ninth
sandbox reset; `kompile --version` → `K version: v7.1.337`,
`z3 --version` → `Z3 version 4.13.3 - 64 bit`, `kore-exec --version` →
`0.1.155`). Sandbox-side rebuild log: `/tmp/kompile-1s/` (kompile rc=0 for
both definitions of record).

## 1. Repository state at phase start (mission §1.1)

* Remote verified after a fresh fetch from `github.com/Dannyednut/SRW3`:
  `refs/heads/phase1r-fold-decomposition` = **`29e7cee92acf572fb1094e2db5289dc3f65794d3`**
  (exact match to the commit of record).
* Ancestry verified on the fetched objects:
  `git merge-base --is-ancestor f6c510685220e1e13ab94761e2593d3e3a8dc482 29e7cee…` → OK
  (1Q is an ancestor of 1R); `git merge-base --is-ancestor
  83dd01571adccb77e51adcf5499c9a2480caaeaf 29e7cee…` → OK (1P descends to 1R
  through 1Q; 1P's parent is the 1O freeze `cdb5556…`).
* Working tree: a fresh detached worktree was created at the verified 1R
  commit (`git worktree add … --detach 29e7cee…`); the checkout is clean.
  The branch of record **`phase1s-refinement-coverage`** was created from
  that commit after the checks below; the 1N–1R trees are untouched
  (`git status` shows only untracked `phase1s/` additions).
* Frozen artifacts verified by re-execution, not by trust:
  * `phase1r/scripts/verify_grid_1r.py` → `VERIFY-GRID: ALL CHECKS PASS`
    (G1/G2 sha anchors, G3–G6 structural checks).
  * `phase1r/scripts/make_abs_qs.py` → S1–S4 OK, roundtrip deterministic
    (2089 bytes); the regenerated `phase1r/semantics/abs-machine-qs.k` is
    **byte-identical** to the frozen file (`git diff` empty).
  * `phase1r/scripts/make_tag0_family_1r.py` → F1–F4 OK, roundtrip
    deterministic; both regenerated proof files byte-identical.
  * The 1Q generator's anchor re-executed: 1P TDRR sha256 =
    `448db6a46101d1f848a7ad364fc07a06cc99a903b4615afc0e5753ca0d8db511` —
    matches the recorded anchor exactly.

## 2. Reproduction of the 1R central theorem (mission §1.2)

Definitions kompiled fresh on the pinned toolchain (rc=0 for both):

```
kompile phase1q/semantics/abs-machine-q.k  --backend haskell --main-module SRW3N-ABS-Q  $INC -o /tmp/p1q-q-def
kompile phase1r/semantics/abs-machine-qs.k --backend haskell --main-module SRW3N-ABS-QS $INC -o /tmp/p1r-qs-def
```

The central theorem (standalone, no `--trusted`, budget 560 s):

```
kprove phase1r/proofs/n_r_univ_qs.k $INC -d /tmp/p1r-qs-def \
  --spec-module R-UNIV-QS-PROOFS --claims 1R-UNIV-COMPOSED-QS
```

Result: **rc=0, wall 12 s** (record: 12 s). Log retained:
`phase1s/transcripts/1r-repro/kprove_1R-UNIV-COMPOSED-QS.log`.

## 3. Reproduction of the depth-1/2/3 genuineness probes (mission §1.3)

Same claim, `--depth D`, logs retained under `phase1s/transcripts/1r-repro/`:

| probe | rc | wall | disposition |
|---|---|---|---|
| `--depth 1` | 1 (FAIL) | 10 s | cannot close at depth 1 — genuine unrolling required |
| `--depth 2` | 1 (FAIL) | 11 s | cannot close at depth 2 |
| `--depth 3` | 0 (close) | 12 s | closes at depth 3 |
| full (no depth) | 0 | 12 s | the theorem of record |

The recorded genuineness signature reproduces exactly: the bounded forms
FAIL while the full proof closes — real unrolling happens; the
PREFIX-UNPATCHED vacuous self-application pattern is excluded. The raw
logs are NEW evidence (the 1R session ran the probes but did not retain
separate depth-probe transcripts; this session retains them).

## 4. Source hashes of record (mission §1.4)

See `phase1s/audit/source-hashes-1r.txt` for the full sha256 list. Anchors:

| file | sha256 (first 16) |
|---|---|
| `phase1p/semantics/abs-machine-tdrr.k` | `448db6a46101d1f8` |
| `phase1q/semantics/abs-machine-q.k` | `2e938fcb8939e0ef` |
| `phase1r/semantics/abs-machine-qs.k` | `b526e2997e8f3f0d` |
| `phase1r/scripts/make_abs_qs.py` | `78e4049aca49697c` |
| `phase1r/proofs/n_r_univ_qs.k` | `528f1bcc7858cb1e` |

## 5. Reproduction-instruction reconciliation (mission §1.5)

`phase1r/report/phase1r-final-report.md` §10's command sequence was
executed as written, with two environment-level adaptations (documented,
no repo change): (a) the toolchain recipe script is sandbox-side and was
re-run from the repo's historical copy (`scripts/reinstall_toolchain_1b.sh`);
(b) `run_1r.sh` stage C's older claims re-run against the 1Q definition of
record were NOT re-executed wholesale — the central theorem, the depth
probes, and the gate (the mission §1 items) were re-executed exactly; the
summarizer gate over the frozen ledger reproduces
**GATE GREEN (53 claims, zero alarms), rc=0**. The one-command sequence
for the main theorem + control gate of record is therefore:

```
source /home/z/my-project/tools/env.sh
cd <repo-root>
INC="-I $PWD/phase1n/semantics -I $PWD/phase1m/semantics -I $PWD/phase1g/semantics \
     -I $PWD/phase1f/semantics -I $PWD/phase1e/semantics \
     -I $PWD/k/phase1d -I $PWD/k/kevm/kproj-e1e/plugin"
kompile phase1r/semantics/abs-machine-qs.k --backend haskell \
  --main-module SRW3N-ABS-QS $INC -o /tmp/p1r-qs-def
kprove phase1r/proofs/n_r_univ_qs.k $INC -d /tmp/p1r-qs-def \
  --spec-module R-UNIV-QS-PROOFS --claims 1R-UNIV-COMPOSED-QS   # rc=0
python3 phase1r/scripts/summarize_1r.py                          # GATE GREEN
```

No Phase 1R source file was modified; no existing commit was rewritten.
The raw exit/wall records are in `phase1s/claims/exit-codes-1s-baseline.csv`.
