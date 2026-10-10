# SRW3 Phase 1I-R3 — Provenance

## Lineage

- Repair branch `phase1i-r3-config-root-binding` created from
  `82f06757db560545e0c844c6196c842426a760d8` (= tag `phase1i-r2-complete` =
  branch `phase1i-r2-gate-provenance`).
- No history rewriting: `phase1d-r1-complete` @ `668a651`, `phase1e` @
  `8b26cb7`, `phase1f` @ `b6c651e`, `phase1g` / `phase1g-complete` @
  `a71ba64`, `phase1h` / `phase1h-complete` @ `4cb9ab7`, `phase1h-r1-fix` /
  `phase1h-r1-complete` @ `bf78b8c`, `phase1i` / `phase1i-complete` @
  `e04fbb6`, `phase1i-r1-formal-binding` / `phase1i-r1-complete` @
  `0b667af`, `phase1i-r2-gate-provenance` / `phase1i-r2-complete` @
  `82f0675` are untouched (no amend, no rebase, no force-push).  The R3 tree
  adds only `phase1i-r3/`; verification performed before the commit:
  `git diff 82f0675 HEAD -- phase1g phase1h phase1h-r1-fix phase1i phase1i-r1
  phase1i-r2 k python-gen` is EMPTY (frozen paths byte-identical), and
  `git status` is clean for every tracked file outside `phase1i-r3/`.
- Two working-tree files that the regression re-runs regenerate in place
  (`phase1h-r1-fix/transcripts/repair/lineage_idempotence.json`,
  `phase1h-r1-fix/transcripts/repair/security_context_binding.json`) and the
  `kore-exec.tar.gz` bug-report artifact were RESTORED from the base commit
  byte-exact before committing (the same disclosed in-place-regeneration
  behavior as the R2 session); the R3-run copies of the regression outputs
  live under `phase1i-r3/transcripts/regression/`.  `k/phase1d/shim/
  libkrypto-shim.a` rebuilt this session proved byte-identical to the
  committed artifact (deterministic toolchain; no restore needed).
  Untracked shim side-products under `k/phase1c/shim/` (`.o`/`.a`/`.so`
  from a toolchain probe) are NOT part of the commit and are rebuildable.
- The final repair commit SHA is the tip of `phase1i-r3-config-root-binding`
  at push time; it is recorded in the repository worklog and the delivery
  record.  A file cannot contain its own commit hash; MANIFEST integrity is
  anchored at commit level (git objects) — following the 1H-R1/R2
  disclosure pattern.

## Input artifacts (the handoff pack)

| Artifact | sha256 |
|---|---|
| `SRW3_Phase1I_R3_ConfigRoot_Binding_Handoff.md` | `51877762d4b244f65d42da74d19004dbe21950ed57c995f723cd9d238fa14251` |
| `srw3_r3_config_commitment.py` (reference encoder) | `f00e41a5e562f3bd3d9a884f387cb9c5bc3c4dd35339f16a30ace21dbe0080d3` |
| `test_srw3_r3_config_commitment.py` (reference tests) | `9f9945d3a8d66fcc0cdbb73a412b92126fc25fbd88a119bbc736cb0f97e689fa` |
| `TEST_RESULTS.txt` (pack's own 11/11 run) | `0883697114860f07fbba174dcba797a102819351f121c3e77981a53e5c865c45` |

The reference encoder is integrated VERBATIM at
`phase1i-r3/python/srw3_r3_config_commitment.py` (provenance header
prepended; the code body is byte-identical — the only project glue is the
`lin_h` argument, injected by `r3_model.py` as the frozen `lin_verify.H`).
The reference tests are integrated (semantics-preserving import-path
adaptation) at `phase1i-r3/tests/test_config_root_binding.py` Part 1.

## Pinned toolchain (rebuilt this session; all no-root, all verified)

| Component | Version / commit | Verification |
|---|---|---|
| K framework | v7.1.337 (jammy deb, extracted) | `kompile --version` |
| z3 | 4.13.3 (trixie deb) | `z3 --version` |
| flex | 2.6.4 (trixie deb; required by the K parser) | `flex --version` |
| clang/LLVM chain | 15.0.6-4+b1 (bookworm pool, incl. `libclang-common-15-dev` builtin headers re-extracted) | `clang-15 --version`; `llvm-kompile-clang` repointed to the extracted clang++-15 (original preserved as `.orig`); runtime shims for libtinfo/libmpfr/libjemalloc/libunwind in `tools/extract/syslibs` (the Phase-1A deviation register) |
| krypto shim | `k/phase1d/shim` (multiblock fix marker-checked: 3× 136-byte bound) | shim objects + `libkrypto-shim.a` (byte-identical to the committed artifact), log `phase1i-r3/transcripts/k/r3_llvm_shim_build.log` |
| blockchain-k-plugin | K sources @ `207ae5121e5178a09742ed746f2d15e34b1750cc` | fetched tarball |
| libsecp256k1 | 0.5.0 (trixie) + `.0/.1→.2` soname shims | symlinks |
| Python | 3.12.14 + pycryptodome + coincurve + eth-utils | pip record |

Build recipes (R3 scripts): `scripts/fetch_k_deb.sh` (resumable K deb
fetch), `scripts/finalize_toolchain_r3.sh` (env.sh + driver patch),
`scripts/build_shim_r3.sh`, `scripts/build_llvm_r3.sh`.  Session-scoped
definitions: `/tmp/r3-hs` (proofs), `/tmp/r3demo-llvm` (demos),
`/tmp/r3demo-hs` (hs boundary) — all rebuildable from the committed sources
and recipes.

## Exact commands (all run live this session)

```text
# toolchain
bash scripts/r2_rebuild_toolchain.sh && bash scripts/finalize_toolchain_r3.sh
bash scripts/build_shim_r3.sh && bash scripts/build_llvm_r3.sh

# K kompile (hs proof definition = fixtures module, see audit §F note)
kompile phase1i-r3/proofs/r3_fixtures.k --main-module SRW3PROTO-R3-FIXTURES \
  --backend haskell -o /tmp/r3-hs -I phase1g/semantics -I phase1f/semantics \
  -I phase1e/semantics -I k/phase1d -I k/kevm/kproj-e1e/plugin
# K kompile (hs demo definition — the hs init-check boundary, audit §F)
kompile phase1i-r3/semantics/srw3proto-r3-demo.k --backend haskell \
  --main-module SRW3PROTO-R3-DEMO -o /tmp/r3demo-hs <same -I flags>
# LLVM demo definition (krypto shim linked; real keccak)
kompile phase1i-r3/semantics/srw3proto-r3-demo.k --backend llvm \
  --hook-namespaces KRYPTO --main-module SRW3PROTO-R3-DEMO -o /tmp/r3demo-llvm \
  <same -I flags>   # with NIX_LLVM_KOMPILE_LIBS="-L k/phase1d/shim -lkrypto-shim -lsecp256k1 -lgmp"

# demos (LLVM primary; T12 = the hs init-check boundary)
bash phase1i-r3/transcripts/run_demos_r3.sh
# proof ladder (kprove, hs; chunked/foreground, resumable markers)
bash phase1i-r3/proofs/run_r3_proofs.sh            # 47 PROVED / 3 NOT MECHANIZED (retained)
python3 phase1i-r3/proofs/summarize_r3_status.py   # claims-status.csv + score.txt + classification

# golden vectors + tests + adversarial suite
python3 phase1i-r3/vectors/gen_vectors.py
python3 -m unittest discover -s phase1i-r3/tests                          # 21/21
python3 phase1i-r3/python/run_r3_attacks.py                               # 181/181

# regression (exact baselines; all PASS)
bash phase1i-r3/transcripts/run_regressions_r3.sh
#   test_lineage_r1 11/11 · test_security_context_r1 26/26 · attack matrix 30/30
#   determinism 15/15 · reorg/replay 17/17 · fork-choice 16/16
#   run_r1_attacks 48/48 (cwd=phase1i-r1/python) · run_r2_attacks 87/87 (PYTHONPATH
#   pre-seeded; the frozen script's hardcoded srw3b-work paths are stale here —
#   disclosed in the transcript header)
```

## Known failed runs and deviations (retained, not cleaned up)

1. `R3-PIPELINE-HONEST`, `R3-PIPELINE-FORGED`, `R3-ALL` — kprove FAILED on
   the Haskell backend (ErrorBottomTotalFunction / stuck configuration);
   classified NOT MECHANIZED with retained logs
   (`transcripts/k/kprove_R3-*.log`) and concrete substitutes (audit §F).
2. `T12-hs-init-root-check-boundary.txt` — the hs honest pipeline cannot
   execute through the R3 init root check (krun exit 124, unevaluated
   `Keccak256raw`); NEW boundary created by the very repair (disclosed,
   audit §F); LLVM T1 + Python are the concrete pipeline evidence.
3. The first `R3-ANCHOR-IMMUTABLE` kprove attempt FAILED ("configuration
   cannot be rewritten further" — the blanket symbolic-command form is not
   decidable); reclassified STRUCTURAL with the mechanical scan
   (`transcripts/legacy/anchor-immutability-scan.txt`) and per-rule frame
   conjuncts; the failed attempt log is RETAINED at
   `transcripts/k/kprove_R3-ANCHOR-IMMUTABLE.attempt1.log`.
4. Toolchain: `r2_rebuild_toolchain.sh` locate-layout section ran from a
   stale cwd (cosmetic; fixed by `finalize_toolchain_r3.sh`);
   `llvm-kompile-clang` was first wrongly overwritten wholesale (broke the
   K arg protocol), then RESTORED from `.orig` and repointed at the
   clang++-15 path only — matching the Phase-1A deviation register.
5. The LLVM demo T0 first ran without the `pConsR3(..., runNilR3)` program
   wrapper (kparse error, retained in the first `r3_demos_run.log` at the
   session worklog); fixed and re-run clean.
6. Python dependency provisioning required `eth-utils` for the frozen
   phase1i suites (recorded above); the two regression invocation
   adaptations (cwd, PYTHONPATH) are documented in the transcripts
   themselves.

## Source refs

- Handoff: `SRW3_Phase1I_R3_ConfigRoot_Binding_Handoff.md` (pack; §1 defect,
  §3 encoding, §4 two questions, §5 state/transitions, §6 claims, §7
  adversarial matrix, §8 cross-layer/score, §9 completion gates).
- Frozen bases: `phase1i-r2/semantics/srw3proto-r2.k` (the audited R2
  machine — its §1 `ProtoCfgCanonR2` is the alias source),
  `phase1i/semantics/srw3proto.k` (frozen 1I formulas, correspondence
  targets), `phase1g/semantics/srw3authz.k` (the frozen gate, imported).
