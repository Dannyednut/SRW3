#!/bin/bash
# SRW3 Phase 1D-R1-FINAL — Part 7 (K demo stages B): Phase-1C crypto layer
# (live shim rebuild + krypto probe 8/8 + ck demos) and Phase-1D abstract
# lineage demos (live re-kompile + 6 lin demos). All outputs go to NEW
# transcript files; no historical transcript is modified.
set -u
source /home/z/my-project/tools/env.sh
SRC=/home/z/my-project/srw3-work
T=/home/z/my-project/tools
OUT=$SRC/transcripts/audit/phase1d_r1/final_regression_1c_1d.txt
: > "$OUT"
log() { echo "$@" | tee -a "$OUT"; }

log "=== SRW3 Phase 1D-R1-FINAL — Part 7: REGRESSION, 1C crypto + 1D lineage ==="
log "=== generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC') ==="
log ""

CL="$T/extract/llvm/usr/bin/clang++-15"
KRES="$T/extract/llvm/usr/lib/llvm-15/lib/clang/15.0.6/include"

build_shim() { # $1 = shim dir
  cd "$1" || return 1
  rm -f krypto_shim.o plugin_util.o libkrypto-shim.a
  $CL -std=c++20 -O2 -c krypto_shim.cpp \
    -isystem "$KRES" -nostdinc++ -isystem /usr/include/c++/14 \
    -isystem /usr/include/x86_64-linux-gnu/c++/14 \
    -I"$KROOT/usr/include/kllvm" -I"$KROOT/usr/include" \
    -I"$T/extract/devheaders/usr/include" -I. 2>&1 | tail -2
  $CL -std=c++20 -O2 -c plugin_util.cpp \
    -isystem "$KRES" -nostdinc++ -isystem /usr/include/c++/14 \
    -isystem /usr/include/x86_64-linux-gnu/c++/14 \
    -I"$KROOT/usr/include/kllvm" -I"$KROOT/usr/include" \
    -I"$T/extract/devheaders/usr/include" 2>&1 | tail -2
  ar rcs libkrypto-shim.a krypto_shim.o plugin_util.o
  cp -f "$T/extract/secp/usr/lib/x86_64-linux-gnu/libsecp256k1.so.2" libsecp256k1.so
  echo "libkrypto-shim.a $(stat -c %s libkrypto-shim.a) bytes in $1"
}

# ---------- [C1] Phase-1C krypto probe (live shim, 8/8) ----------
log "--- [C1] Phase-1C krypto probe (8/8 ok=true expected) ---"
log "shim: $(build_shim $SRC/k/phase1c/shim)"
cd "$SRC/k/phase1c" || exit 1
rm -rf probe-out
export NIX_LLVM_KOMPILE_LIBS="-L$SRC/k/phase1c/shim -lkrypto-shim -lsecp256k1 -lgmp"
timeout 600 kompile krypto-probe.k --backend llvm --hook-namespaces KRYPTO \
  --main-module PHASE1C-PROBE -o probe-out -I "$PLUGIN" > /tmp/p1c_probe_komp.txt 2>&1
EK=$?
timeout 120 krun probe.pgm -d probe-out > /tmp/p1c_probe.txt 2>&1
ER=$?
NOK=$(grep -c 'ok=true' /tmp/p1c_probe.txt || true)
log "[C1] kompile exit=$EK; krun exit=$ER; probe ok-count: $NOK / 8"
grep -o 'IV-[a-z0-9-]* ok=[a-z]*\|IX-[a-z0-9-]* ok=[a-z]*' /tmp/p1c_probe.txt | sort -u >> "$OUT"
log ""

# ---------- [C2] Phase-1C ck gate demos ----------
log "--- [C2] Phase-1C ck demos (commit / reject / commit expected) ---"
rm -rf ck-out
timeout 600 kompile srw3ck.k --backend llvm --hook-namespaces KRYPTO \
  --main-module SRW3CK -o ck-out -I "$PLUGIN" > /tmp/p1c_ck_komp.txt 2>&1
EK=$?
log "[C2] kompile srw3ck.k exit=$EK"
for d in ck_chain_positive ck_tamper_reject ck_recover; do
  timeout 120 krun "$SRC/k/phase1c/$d.ck" -d ck-out > "/tmp/final_$d.txt" 2>&1
  EX=$?
  RES=$(grep -o '"commit"\|"reject"' "/tmp/final_$d.txt" | tail -1 | tr -d '"')
  log "  $d: krun exit=$EX result=$RES"
done
log ""

# ---------- [D1] Phase-1D abstract lineage demos (live re-kompile) ----------
log "--- [D1] Phase-1D lin demos (6, live re-kompile, LLVM + fixed shim) ---"
log "kompile: srw3lin-demo.k --backend llvm --hook-namespaces KRYPTO --main-module SRW3LIN-DEMO -o lin-out -I <shim-include> -I \$PLUGIN"
cd "$SRC/k/phase1d" || exit 1
rm -rf lin-out
export NIX_LLVM_KOMPILE_LIBS="-L$SRC/k/phase1d/shim -lkrypto-shim -lsecp256k1 -lgmp"
timeout 600 kompile srw3lin-demo.k --backend llvm --hook-namespaces KRYPTO \
  --main-module SRW3LIN-DEMO -o lin-out -I "$PLUGIN" > /tmp/p1d_lin_komp.txt 2>&1
EK=$?
log "[D1] kompile exit=$EK"
for d in lin_chain_positive lin_true_effects lin_tamper_matrix lin_impersonate \
         lin_replay_same_chain lin_replay_fresh_chain; do
  timeout 120 krun "$SRC/k/phase1d/$d.lin" -d lin-out > "/tmp/final_$d.txt" 2>&1
  EX=$?
  V=$(grep -o '"[a-z-]*:[a-zA-Z-]*[a-z]"' "/tmp/final_$d.txt" | head -6 | tr '\n' ' ' | cut -c1-150)
  log "  $d: krun exit=$EX verdicts: $V"
done
log ""

log "PART7_1C_1D_DONE"
