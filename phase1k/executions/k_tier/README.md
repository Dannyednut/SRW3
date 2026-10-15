# SRW3 Phase 1K — fresh K/LLVM tier (package-level concrete execution)

Environment: the pinned toolchain rebuilt in the reset container (K v7.1.337,
z3 4.13.3, clang/LLVM-15 15.0.6-4+b1, libsecp256k1 0.5.0; recipe
`scripts/r2_rebuild_toolchain.sh` with the recorded deviations, plus the
1K fixes recorded below).  Definition: `srw3closure-j-demo.k` **from the
PACKAGE** (`package/semantics/phase1j/semantics/` — certified byte-identical
to the frozen tree by `executions/byte-identity.txt`), kompiled `--backend
llvm --hook-namespaces KRYPTO` with the multiblock-fix krypto shim
(`k/phase1d/shim`, marker: 3 occurrences of the 136-byte block bound).

What was run:

1. `build_llvm.log` — shim objects + `kompile` (exit 0) + interpreter link.
   The interpreter is `/tmp/j-llvm-1k/interpreter`.
2. `run_demos_stdout.txt` — the FULL 1J demonstration + attack suite
   (`phase1j/transcripts/run_demos_j.sh`, output redirected to `llvm/`):
   14 executed demos (T0–T13) + 5 kparse ill-formedness rejections
   (T14a/b, T15a/b/c), all fresh, REAL Keccak-256.
3. `llvm/` — the fresh T-series transcripts.

Decisive byte-identity results (fresh vs the frozen 1J transcripts,
`phase1j/transcripts/llvm/`, compared modulo the `# definition` / `# anchor`
header lines):

- `T0-llvm-cross-layer-certificate.txt` — IDENTICAL (the 451-byte catalog
  canon, all roots, evidence identity, block commitment, computed verdicts,
  SafeJ evaluations: byte-for-byte the frozen values).
- `T2-llvm-honest-two-block-pipeline.txt` — IDENTICAL (the honest pipeline
  COMMITS twice; head state byte-identical to Python).
- `T6-llvm-unsafe-3app-composition-REJECTS.txt` — IDENTICAL (the unsafe
  third block REJECTS with state/head/counter unchanged, receipts
  unconsumed).
- `llvm/anchor.txt` — IDENTICAL (the self-computed authenticated anchor).

Toolchain deviations of record (this rebuild):

- `libclang-common-15-dev` must be extracted into the llvm tree (clang
  resource headers `stddef.h` etc.); the R2 recipe's extraction globs miss
  it.
- `flex` must be on PATH (kompile's scanner step execs it).
- The R2 recipe's `llvm-kompile-clang` patch is WRONG for K v7.1.337 — the
  pristine driver handles the internal `nolto` argv; the patch forwarded it
  to clang (`clang: error: no such file or directory: 'nolto'`).  The
  pristine driver was restored from `.orig` and only the hardcoded
  configure-time path `/usr/bin/clang++-15` was redirected to the extracted
  clang++-15 (surgical path substitution, driver logic untouched).
