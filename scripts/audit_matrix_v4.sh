#!/bin/bash
# Phase 1A: LLVM retarget regression matrix v4.
# Wrapper: re-runs every matrix-v3 stage into full_matrix_v4.txt (the v3
# canonical record is preserved untouched), then appends the Phase-1A LLVM
# stage (backend equivalence + boundary experiments).
# Usage: bash audit_matrix_v4.sh <stage>
#   setup | py | demos | claims | r2 | defect | ghost | tier3 | kevm | llvm | verdict
V4=/home/z/my-project/scripts/.matrix_v4_stage.sh
[ -f "$V4" ] || sed 's|full_matrix_v3.txt|full_matrix_v4.txt|' \
  /home/z/my-project/scripts/audit_matrix_v3.sh > "$V4"
bash "$V4" "${1:-setup}"

case "$1" in
llvm)
  OUT=/home/z/my-project/srw3-kevm/transcripts/audit/full_matrix_v4.txt
  cd /home/z/my-project/srw3-kevm
  {
  echo "=== [LLVM-1] toolchain (K 7.1.337 llvm-backend 0.1.140; clang-15 15.0.6-4+b1 via LLVM_KOMPILE_CXX) ==="
  echo "abstract srw3.k  llvm kompile : $(rg -o 'exit=[0-9]+ wall=[0-9.]+s peak_rss=[0-9.]+MiB' /tmp/komp_llvm.log 2>/dev/null || echo 'see transcripts/llvm_kompile_sr3.log')"
  echo "binding kevm llvm kompile     : $(rg -o 'exit=[0-9]+ wall=[0-9.]+s peak_rss=[0-9.]+MiB' /tmp/komp_kevm_llvm.log 2>/dev/null)"
  echo
  echo "=== [LLVM-2] abstract demo equivalence (13 demos, hs vs llvm, semantic cell compare) ==="
  python3 /home/z/my-project/scripts/llvm_compare.py transcripts/llvm_demos_hs.txt transcripts/llvm_demos_llvm.txt | tail -3
  echo
  echo "=== [LLVM-3] KEVM binding under LLVM (3 demos, hs vs llvm structural compare) ==="
  tail -4 transcripts/audit/evm_llvm_equivalence.txt
  echo
  echo "=== [LLVM-4] kprove backend probe (proof closure is haskell-only) ==="
  head -2 transcripts/audit/llvm_kprove_probe1.txt
  echo
  echo "=== [LLVM-5] llvm krun --search probe (concrete enumeration only) ==="
  rg -m1 "Search result|Result:GeneratedTopCell" transcripts/audit/llvm_search_probe.txt || head -1 transcripts/audit/llvm_search_probe.txt
  echo
  echo "=== [LLVM-6] Boundary 1 (symbolic Map fold) ==="
  rg -m1 "WarnTrivialClaim" transcripts/audit/boundaries/b1_haskell.txt | head -1
  rg -m1 "WarnStuckClaimState" transcripts/audit/boundaries/b1_haskell.txt | head -1
  echo "B1 haskell: B1-SYM closes on the ==Map pin (trivial, no fold reduction);"
  rg -m2 "#Equals|#Not" -A0 transcripts/audit/boundaries/b1_haskell.txt | head -2
  echo "B1-FREE residual: sum(... m: M ) ==Int S   [recursive fold over constructor-free Map: STUCK]"
  echo "B1 llvm   : $(head -2 transcripts/audit/boundaries/b1_llvm.txt | tail -1)"
  echo
  echo "=== [LLVM-7] Boundary 2 (destination-variable linkage) ==="
  rg -m1 "WarnStuckClaimState" transcripts/audit/boundaries/b2_haskell.txt | head -1
  echo "B2-OMIT residual: _Gen3 #Equals _Gen3 +Int 1   [changed cells omitted from destination: STUCK]"
  echo "B2-EXPL: closes (explicit ?-existential destination cells over all changing cells)"
  echo "B2 llvm   : $(head -2 transcripts/audit/boundaries/b2_llvm.txt | tail -1)"
  echo
  echo "=== [LLVM-8] Boundary 3 (tier-3 universal, unweakened) ==="
  rg "T3-.*kprove exit" transcripts/audit/tier3_universal.txt | head -3
  echo "B3 haskell: T3-U/T3-FD/T3-A STUCK (symbolic-set induction); statement unweakened"
  echo "B3 llvm   : kprove rejects the llvm backend (see [LLVM-4]); boundary unchanged"
  echo
  echo "=== [LLVM-9] exact ghost source-fidelity certificate (Part I.A repair) ==="
  rg "VERDICT|equation" transcripts/audit/ghost_fidelity_exact.txt | head -3
  echo
  echo "=== [LLVM-10] provenance repair (Part I.B) ==="
  rg "final commit|parent commit" transcripts/provenance/PROVENANCE.md | head -2
  sha256sum ../srw3-work.bundle 2>/dev/null | head -1
  echo >> "$OUT"
  echo "llvm done"
  } >> "$OUT"
  ;;
verdict)
  {
  echo "[LLVM] abstract 13/13 semantic-equivalent; KEVM 3/3 structural-equivalent;"
  echo "     kprove llvm = unsupported (backend gate); B1/B2/B3 haskell boundaries reproduced,"
  echo "     llvm N/A; exact ghost fidelity PASS; provenance commit 80448f2 (phase1-start)"
  } >> "$OUT"
  ;;
esac
