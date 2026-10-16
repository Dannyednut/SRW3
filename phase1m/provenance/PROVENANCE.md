# SRW3 Phase 1M — Workstream A provenance (the L-FINDING-1 repair commit)

- Base: origin/phase1l-universal-induction @ 0aee3eec2e26c2f75c1a6d8e4c4b4116b4169492 (the required starting point; verified bit-exact after sandbox reset #6)
- Branch: phase1m-proof-backend-closure
- Frozen machine: phase1j/semantics/srw3closure-j.k sha256 6abfec5478f899b5d2379c97533a9c7decd6d765ab88a80e546fd51dae34016f (re-verified post-run)
- M1 generator: scripts/make_m1.py (roundtrip byte-exact, 1-line semantic edit + header + module rename)
- Demo generator: scripts/make_m1_demo.py (roundtrip byte-exact)
- Toolchain: K v7.1.337, z3 4.13.3, LLVM-15 15.0.6-4+b1, libsecp256k1 0.5.0-2+b1, mpfr 6.2.2 (pinned recipe; rebuild script scripts/reinstall_toolchain_1m_r2.sh; environment repairs disclosed in audit/m1-repair.md §8)
- K ladder: phase1m/proofs/run_m1_repair.sh (6 claims, 6 correct / 0 gate alarms; logs + claims-status-m1.csv + score-m1.txt in transcripts/k/)
- OLD evidence: transcripts/k/kprove_OLD-L-INV-EXEC-DISPATCH-SOURCE.log (frozen stuck witness reproduced over the frozen definition)
- LLVM: phase1m/transcripts/run_demos_m1.sh (anchor 295e0b6d... byte-identical to the frozen record; T11-M1 CORRECTED + T1-M1 no-regression)
- Python: phase1m/python/run_m1_crosscheck.py (8/8; transcripts/attacks/m1_mirror_crosscheck.txt)
- Regressions: 1J attacks 48/48, 1J unittests 27/27, 1L tier 56/56 (transcripts/attacks/)
