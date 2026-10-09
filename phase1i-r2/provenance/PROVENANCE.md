# SRW3 Phase 1I-R2 — Provenance

## Lineage

- Repair branch `phase1i-r2-gate-provenance` created from `0b667af79659b783f
  813a416aad84d641b168034` (= tag `phase1i-r1-complete` = branch
  `phase1i-r1-formal-binding`).
- No history rewriting: `phase1d-r1-complete` @ `668a651`, `phase1e` @
  `8b26cb7`, `phase1f` @ `b6c651e`, `phase1g` / `phase1g-complete` @
  `a71ba64`, `phase1h` / `phase1h-complete` @ `4cb9ab7`,
  `phase1h-r1-fix` / `phase1h-r1-complete` @ `bf78b8c`, `phase1i` /
  `phase1i-complete` @ `e04fbb6`, `phase1i-r1-formal-binding` /
  `phase1i-r1-complete` @ `0b667af` are untouched (no amend, no rebase, no
  force-push).  The R2 tree adds only `phase1i-r2/` and the two R2 toolchain
  scripts; `git diff 0b667af HEAD -- phase1g phase1h phase1h-r1-fix phase1i
  phase1i-r1 k python-gen` is EMPTY (frozen paths byte-identical), verified
  before the commit.  Two working-tree files that the regression re-runs
  regenerate in place (`phase1h-r1-fix/transcripts/repair/*.json`) and the
  `kore-exec.tar.gz` bug-report artifact were RESTORED from the base commit
  byte-exact before committing; the R2-run copies of the regression outputs
  live under `phase1i-r2/transcripts/regression/`.
- The final repair commit SHA is the tip of `phase1i-r2-gate-provenance` at
  push time; it is recorded in the repository worklog and the delivery
  record.  A file cannot contain its own commit hash; MANIFEST integrity is
  anchored at commit level (git objects) — following the 1H-R1 disclosure
  pattern.

## Pinned toolchain (rebuilt this session; all no-root, all verified)

| Component | Version / commit | Verification |
|---|---|---|
| K framework | v7.1.337 (jammy deb, extracted) | `kompile --version` |
| z3 | 4.13.3 (trixie deb) | `z3 --version` |
| clang/LLVM chain | 15.0.6-4+b1 (bookworm pool, incl. `libclang-common-15-dev` builtin headers) | `clang-15 --version`; driver paths patched (repointed to the extracted prefix; originals `.orig` preserved) |
| krypto shim | `k/phase1d/shim` (multiblock fix marker-checked: 3× 136-byte bound) | shim objects + `libkrypto-shim.a` built by `scripts/r2_build_llvm.sh`, log `transcripts/k/r2_llvm_shim_build.log` |
| blockchain-k-plugin | K sources @ `207ae5121e5178a09742ed746f2d15e34b1750cc` | fetched tarball |
| libsecp256k1 | 0.5.0 (trixie) + `.0/.1→.2` soname shims | symlinks |
| Python | 3.12.14 (`/home/z/.venv`) + pycryptodome + coincurve + eth-utils/eth-account | pip record |

Build recipes: `scripts/r2_rebuild_toolchain.sh` (K/hs + LLVM chain + env.sh),
`scripts/r2_build_llvm.sh` (shim + LLVM kompile + probe).  Known-good LLVM
definition for the demos: `/tmp/r2demo-llvm` (session-scoped; rebuildable
from the scripts).

## Exact commands (all run live this session)

```text
# K kompile (hs) + krun demos + kprove ladder
bash scripts/r2_rebuild_toolchain.sh
kompile phase1i-r2/semantics/srw3proto-r2.k --main-module SRW3PROTO-R2 \
  --backend haskell -o /tmp/r2-hs -I phase1g/semantics -I phase1f/semantics \
  -I phase1e/semantics -I k/phase1d -I k/kevm/kproj-e1e/plugin
bash phase1i-r2/transcripts/run_demos.sh            # T1-T12 (LLVM primary, hs boundary)
bash phase1i-r2/proofs/run_r2_proofs.sh             # 37 PROVED / 3 NOT MECHANIZED (chunked, resumable)
# LLVM + shim
bash scripts/r2_build_llvm.sh                       # shim + llvm kompile + probe (exit 0, concrete keccak)
# Python
/home/z/.venv/bin/python phase1i-r2/python/run_r2_attacks.py   # 87/87
# regression (exact baselines)
/home/z/.venv/bin/python phase1h/python/test_lineage_r1.py            # 11/11
/home/z/.venv/bin/python phase1h/python/test_security_context_r1.py   # 26/26
/home/z/.venv/bin/python phase1i/python/run_attack_matrix.py          # 30/30
/home/z/.venv/bin/python phase1i/python/run_determinism_i.py          # 15/15
/home/z/.venv/bin/python phase1i/python/run_reorg_replay.py           # 17/17
/home/z/.venv/bin/python phase1i/python/run_forkchoice_compare.py     # 16/16
(cd phase1i-r1/python && /home/z/.venv/bin/python run_r1_attacks.py)  # 48/48
```

## Known failed runs and retries (retained, per the no-overwrite rule)

- The hs-backend honest-pipeline krun attempts hit the accept-side stuck
  verdict and were bounded by timeout (exit 124/143); raw streams reached
  61 MB of the repeated Keccak warning block.  Retained (filtered, disclosed)
  as `transcripts/demos/T11-hs-mint-computed-verdict-boundary.txt`; the
  kprove full-pipeline attempts are `kprove_R2-PIPELINE-{HONEST,FORGED}.log.gz`
  and `kprove_R2-ALL.log.gz` / `kprove_R2-ALL.log` (NOT MECHANIZED).
- The first kore-exec probe of the LLVM definition failed (libsecp256k1.so.0
  not on LD_LIBRARY_PATH), and the first llvm-kompile link failed
  (/usr/bin/clang++-15 hardcoded in the kompile driver) — both fixed by
  LD_LIBRARY_PATH and the driver path patches; the failed-attempt logs are in
  `transcripts/k/r2_llvm_shim_build.log` (the iteration history).
- The background proof-runner was reaped twice by the sandbox; the ladder was
  completed in resumable chunks (`run_r2_proofs.sh` chunk mode) — the
  resumable markers were session artifacts and are not committed.
- Early demo transcripts with unbalanced program strings were regenerated
  (the runner rewrites its own outputs; no frozen transcript was overwritten).

## Source references

- Frozen gate: `phase1g/semantics/srw3authz.k` (`VerifyLineageG`, L23-L30)
- Frozen protocol: `phase1i/semantics/srw3proto.k` (`CommitP`, `ProtoCfg`,
  `PolicyCommitmentI`, tags 0x9C/0x9D/0x9E/0x9F/0xA5/0xA6)
- R1 (the repaired-but-still-open surface): `phase1i-r1/semantics/srw3proto-r1.k`
  (`pGateEval` verdict parameter, lines 178-184/216-235)
- R2 machine: `phase1i-r2/semantics/srw3proto-r2.k`
- Handoff: `SRW3_Phase1I_R2_Gate_Provenance_Handoff.md` (user-provided)
