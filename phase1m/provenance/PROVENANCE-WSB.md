# SRW3 Phase 1M — Workstream B provenance (the hash-redirect commit)

- Base: origin/phase1m-proof-backend-closure @ a6ca829 (the Workstream-A
  L-FINDING-1 repair commit; the required starting point 0aee3ee + one
  commit; re-verified bit-exact after sandbox reset #7 recovery).
- Sandbox reset #7 recovery: repo re-cloned (PAT auth); toolchain rebuilt
  from the recorded recipe by scripts/reinstall_toolchain_1m_r3.sh
  (persisted in the repo): K v7.1.337 jammy deb (+prelude.md include-root
  symlink), z3 4.13.3-1, LLVM-15 15.0.6-4+b1 chain (bookworm pool),
  libsecp256k1-2 0.5.0-2+b1 + dev headers, syslibs dev symlinks, the
  llvm-kompile-clang driver's ONE path substitution (the 1K fix of record;
  the driver is a '#!/bin/bash -e' arg-parsing script — a naive exec
  wrapper breaks llvm-kompile), krypto shim rebuilt (libkrypto-shim.a,
  18022 B).  Validation gate of record: the frozen 1L definition kompile
  reproduces (25.6s vs the recorded 25.4s + noise).
- Generators (roundtrip-verified): scripts/gen_keccak_total_packed.py
  (the packed-Int evaluator; the three fixes of record are in its
  docstring), scripts/make_m2.py (M2 = M1 + exactly 5 disclosed edits),
  scripts/make_j_invariant_m2.py (the 1L invariant definitions over the M2
  machine; 3 disclosed edits), scripts/kek_ref.py (the independent Python
  reference; cross-checked against pycryptodome), scripts/kek-tools/
  (decode_kbytes.py, kek_vector_run.sh), scripts/kek_packed_mirror.py
  (the packed-stage Python oracle).
- Machines: phase1m/semantics/keccak256_total.k (KECCAK256-TOTAL; no hooks),
  srw3closure-j-m2.k + srw3closure-j-m2-demo.k (the M2 redirect machine;
  the redirect equation: rule Keccak256raw(B:Bytes) => Keccak256T(B)),
  j_invariant_m2.k (SRW3L-INVARIANT-M2).
- Ladder: phase1m/proofs/kb_proofs.k (KB-*), kb_old_proofs.k (the OLD
  witnesses over M1), run_kb_proofs.sh, recert_kb_proved.sh; the inventory
  + score: transcripts/k/claims-status-kb.csv, score-kb.txt; per-claim raw
  logs: transcripts/k/kprove_KB-*.log.
- Vector validation: transcripts/k/kek-vectors-{llvm,hs}.txt (7/7 + 7/7).
- LLVM tier: transcripts/run_demos_m2.sh; anchor-m2.txt (BYTE-IDENTICAL to
  the frozen record 295e0b6d...); T11-M2 (the corrected refusal on M2);
  T1-M2 (the honest pipeline commits on M2).  The M2 LLVM kompile requires
  --hook-namespaces KRYPTO + the shim (the attribute-dropped kompile of the
  redirect machine segfaults the interpreter — audit/m2-hash-redirect.md §6,
  gdb backtrace of record).
- Toolchain: K v7.1.337, z3 4.13.3-1, LLVM-15 15.0.6-4+b1, mpfr 4.2.2 (the
  sandbox's current mpfr — the 1M-1 record said 6.2.2; the HOST libmpfr.so.6
  is what syslibs links — disclosed deviation, no behavioral effect on the
  recorded results), libsecp256k1 0.5.0-2+b1.
- Workstream A artifacts: byte-stable from a6ca829 (the frozen-tree check
  below).  Level III only; no consensus-integration claim.
