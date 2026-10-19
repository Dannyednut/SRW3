# SRW3 Phase 1M — transcript index (Workstream B)

## k/ (the proof-backend tier, Haskell backend)

- `kek-vectors-llvm.txt`, `kek-vectors-hs.txt` — the 7-vector validation of
  the packed-Int evaluator `Keccak256T` (7/7 + 7/7; references cross-checked
  between scripts/kek_ref.py and pycryptodome).  A `.failN` file next to a
  vector log retains the raw output of a failed vector (none in the final
  logs of record).
- `kompile_kb.log`, `kompile_old.log` — the definition kompiles of record
  (j_invariant_m2.k → /tmp/kb-m2-hs; srw3closure-j-m1.k → /tmp/kb-old-m1-hs).
- `kprove_KB-*.log` — the per-claim raw logs (the inventory:
  claims-status-kb.csv; the score: score-kb.txt).  CONVENTION: a log of size
  0 with raw_result FAILED(rc=124) is a runner-timeout witness (kprove
  buffers its output and the timeout kills it before any output); the exit
  code is the raw result.  The PROVED-class claims were re-certified with
  captured exit codes by proofs/recert_kb_proved.sh (all rc=0).
- `m2-hs-anchor-timeout.txt` — the retained witness of the M2-hs `krun` of
  the full certificate exceeding the 50-minute tool budget (the hs-side
  evidence is the kprove ladder; audit/m2-hash-redirect.md §6).

## llvm/ (the concrete-execution tier, LLVM + krypto shim + --hook-namespaces KRYPTO)

- `run_demos_m2.sh` — the M2 demo runner (the attribute-PRESENT kompile; see
  audit/m2-hash-redirect.md §6 for the attribute-dropped LLVM boundary).
- `anchor-m2.txt` — the machine-computed anchor: BYTE-IDENTICAL to the
  frozen record 295e0b6d2215e20662693a20e9af41d58f09b07b77dedd92924c2f6029d
  ec9df (the redirect is semantics-preserving on the demo data end-to-end).
- `T11-M2-llvm-unauthorized-source-refused.txt` — the Workstream-A corrected
  refusal, executed on the M2 hash-redirect machine (jrefusedSource()
  written, no movement; the frozen stuck T11 remains retained unchanged in
  phase1j/transcripts/llvm/).
- `T1-M2-llvm-honest-one-block-pipeline.txt` — the honest one-block pipeline
  COMMITS on the M2 machine (every machine hash computed by the total
  evaluator Keccak256T).

## attacks/ (the Workstream-A cross-layer and regression tier — unchanged)

- `m1_mirror_crosscheck.txt`, `regression-1j-attacks-fresh.txt`,
  `regression-1j-unittests-fresh.txt`, `regression-1l-tier-fresh.txt` — the
  Workstream-A records (commit a6ca829), byte-stable.
