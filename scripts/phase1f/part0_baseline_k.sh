#!/bin/bash
# SRW3 Phase 1F — Part 0: baseline regression (K side) before any Phase 1F work.
# Mandated by the Phase 1E handoff discipline: re-run the permanent suites so
# regressions are attributable to Phase 1F changes only.
#   (A) krypto shim rebuild from source (k/phase1d/shim, keccak-multiblock fix)
#   (B) fresh LLVM re-kompile of k/phase1d/srw3lin-r1-demo.k
#   (C) K composition suite: pos=valid; neg1=neg2=neg3=invalid-state-composition
# Python-side suites are run separately (they need no K).
set -u
source /home/z/my-project/tools/env.sh
SRC=/home/z/my-project/srw3-kevm
P1D=$SRC/k/phase1d
PLUGIN=/home/z/my-project/tools/plugin-207ae512/plugin
OUT=$SRC/phase1f/transcripts/part0_baseline_k_composition.txt
mkdir -p "$(dirname "$OUT")"
: > "$OUT"
log() { echo "$@" | tee -a "$OUT"; }

log "=== SRW3 Phase 1F — Part 0: BASELINE REGRESSION (K side) ==="
log "=== generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC') ==="
log "branch: $(git -C $SRC branch --show-current) @ $(git -C $SRC rev-parse HEAD)"
log ""

log "--- toolchain ---"
log "K:      $(kompile --version 2>&1 | head -1)"
log "z3:     $(z3 --version 2>&1)"
log "clang:  $(/home/z/my-project/tools/extract/llvm/usr/bin/clang++-15 --version 2>/dev/null | head -1)"
log "plugin: blockchain-k-plugin @ 207ae512 (pinned)"

# ---------- (A) shim rebuild ----------
log ""
log "=== (A) KRYPTO SHIM REBUILD (source: k/phase1d/shim/) ==="
cd "$P1D/shim" || exit 1
KRES="/home/z/my-project/tools/extract/llvm/usr/lib/llvm-15/lib/clang/15.0.6/include"
CL="/home/z/my-project/tools/extract/llvm/usr/bin/clang++-15"
rm -f krypto_shim.o plugin_util.o libkrypto-shim.a libsecp256k1.so
$CL -std=c++20 -O2 -c krypto_shim.cpp \
  -isystem "$KRES" -nostdinc++ -isystem /usr/include/c++/14 \
  -isystem /usr/include/x86_64-linux-gnu/c++/14 \
  -I"$KROOT/usr/include/kllvm" -I"$KROOT/usr/include" \
  -I"/home/z/my-project/tools/extract/devheaders/usr/include" -I. >> "$OUT" 2>&1
E1=$?
$CL -std=c++20 -O2 -c plugin_util.cpp \
  -isystem "$KRES" -nostdinc++ -isystem /usr/include/c++/14 \
  -isystem /usr/include/x86_64-linux-gnu/c++/14 \
  -I"$KROOT/usr/include/kllvm" -I"$KROOT/usr/include" \
  -I"/home/z/my-project/tools/extract/devheaders/usr/include" >> "$OUT" 2>&1
E2=$?
ar rcs libkrypto-shim.a krypto_shim.o plugin_util.o 2>> "$OUT"
cp -f /home/z/my-project/tools/extract/secp/usr/lib/x86_64-linux-gnu/libsecp256k1.so.2 libsecp256k1.so
log "clang++ krypto_shim.cpp exit=$E1 ; plugin_util.cpp exit=$E2"
log "libkrypto-shim.a: $(stat -c %s libkrypto-shim.a 2>/dev/null) bytes"
log "shim keccak-multiblock fix marker lines: $(grep -c '1D-R1-KECCAK-MULTIBLOCK FIX' krypto_shim.cpp)"

# ---------- (B) fresh kompile ----------
log ""
log "=== (B) FRESH LLVM RE-KOMPIle of srw3lin-r1-demo.k ==="
cd "$P1D" || exit 1
rm -rf r1-out-final
export NIX_LLVM_KOMPILE_LIBS="-L$P1D/shim -lkrypto-shim -lsecp256k1 -lgmp"
timeout 600 kompile srw3lin-r1-demo.k --backend llvm --hook-namespaces KRYPTO \
  --main-module SRW3LIN-R1-DEMO -o r1-out-final -I "$PLUGIN" >> "$OUT" 2>&1
log "kompile exit=$? (0 = ok)"

# ---------- (C) composition suite ----------
log ""
log "=== (C) K COMPOSITION SUITE (r1suite) ==="
echo 'r1suite' > /tmp/r1suite.pgm
timeout 300 krun /tmp/r1suite.pgm -d r1-out-final > /tmp/r1_1f_baseline.txt 2>&1
log "krun exit=$?"
log "--- verbatim krun output ---"
cat /tmp/r1_1f_baseline.txt >> "$OUT"
log "--- end verbatim ---"
V=$(grep -o '"pos=valid;neg1=invalid-state-composition;neg2=invalid-state-composition;neg3=invalid-state-composition"' /tmp/r1_1f_baseline.txt | head -1 | tr -d '"')
log ""
log "EXPECTED: pos=valid;neg1=invalid-state-composition;neg2=invalid-state-composition;neg3=invalid-state-composition"
log "GOT     : ${V:-<ABSENT — RUN FAILED>}"
[ "$V" = "pos=valid;neg1=invalid-state-composition;neg2=invalid-state-composition;neg3=invalid-state-composition" ] \
  && log "BASELINE K SUITE: PASS" || log "BASELINE K SUITE: FAIL"
log ""
log "PART0_BASELINE_K_DONE"
