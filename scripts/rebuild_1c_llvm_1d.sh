#!/bin/bash
# SRW3 Phase 1D Part I — rebuild the Phase-1C LLVM cryptographic layer after
# the fourth sandbox reset, and re-run its evidence (probe 8/8 + ck demos 3/3).
# Recipe per Phase-1C report §5: shim build (clang-15, kllvm runtime headers,
# pinned libsecp256k1 0.5.0), kompile --backend llvm --hook-namespaces KRYPTO,
# shim-linked interpreter; commitments = real Keccak256raw via the shim.
set -u
source /home/z/my-project/tools/env.sh
P1C=$SRW3/k/phase1c
T=/home/z/my-project/tools
LOG=$SRW3/transcripts/audit/phase1d_part1_1c_rebuild.txt
: > "$LOG"

log() { echo "$@" | tee -a "$LOG"; }

log "=== SRW3 Phase 1D Part I — Phase-1C LLVM crypto layer rebuild ($(date -u)) ==="
log "toolchain: $(kompile --version 2>&1 | head -1); z3 $(z3 --version 2>&1); clang $("$T"/extract/llvm/usr/bin/clang-15 --version | head -1)"

log ""
log "=== 1. krypto shim build ==="
cd "$P1C/shim" || exit 1
KRES="$T/extract/llvm/usr/lib/llvm-15/lib/clang/15.0.6/include"
"$T/extract/llvm/usr/bin/clang++-15" -std=c++20 -O2 -c krypto_shim.cpp \
  -isystem "$KRES" -nostdinc++ -isystem /usr/include/c++/14 -isystem /usr/include/x86_64-linux-gnu/c++/14 \
  -I"$T/extract/k/usr/include/kllvm" -I"$T/extract/k/usr/include" \
  -I"$T/extract/devheaders/usr/include" -I. >> "$LOG" 2>&1
"$T/extract/llvm/usr/bin/clang++-15" -std=c++20 -O2 -c plugin_util.cpp \
  -isystem "$KRES" -nostdinc++ -isystem /usr/include/c++/14 -isystem /usr/include/x86_64-linux-gnu/c++/14 \
  -I"$T/extract/k/usr/include/kllvm" -I"$T/extract/k/usr/include" \
  -I"$T/extract/devheaders/usr/include" >> "$LOG" 2>&1
ar rcs libkrypto-shim.a krypto_shim.o plugin_util.o
log "libkrypto-shim.a: $(ls -la libkrypto-shim.a | awk '{print $5}') bytes"
cp -f "$T/extract/secp/usr/lib/x86_64-linux-gnu/libsecp256k1.so.2" libsecp256k1.so 2>/dev/null

export NIX_LLVM_KOMPILE_LIBS="-L$P1C/shim -lkrypto-shim -lsecp256k1 -lgmp"

log ""
log "=== 2. probe kompile (llvm + KRYPTO hooks + shim) ==="
cd "$P1C" || exit 1
timeout 600 kompile krypto-probe.k --backend llvm --hook-namespaces KRYPTO \
  --main-module PHASE1C-PROBE -o probe-out -I "$T/plugin-207ae512/plugin" >> "$LOG" 2>&1
log "kompile probe exit=$? (0 = ok)"

log ""
log "=== 3. probe run (expect 8/8 ok) ==="
timeout 120 krun probe.pgm -d probe-out > /tmp/p1d_probe.txt 2>&1
log "krun probe exit=$?"
grep -o '"[A-Z]*-[a-z0-9-]* ok=[a-z]*[^"]*"' /tmp/p1d_probe.txt | tr -d '"' | sed 's/got=.*ok=/... /' >> /dev/null
grep -o 'IV-[a-z0-9-]* ok=[a-z]*\|IX-[a-z0-9-]* ok=[a-z]*' /tmp/p1d_probe.txt | sort -u >> "$LOG"
NOK=$(grep -c 'ok=true' /tmp/p1d_probe.txt || true)
log "probe ok-count: $NOK / 8"

log ""
log "=== 4. ck gate definition kompile (llvm + shim) ==="
timeout 600 kompile srw3ck.k --backend llvm --hook-namespaces KRYPTO \
  --main-module SRW3CK -o ck-out -I "$T/plugin-207ae512/plugin" >> "$LOG" 2>&1
log "kompile ck exit=$? (0 = ok)"

log ""
log "=== 5. ck demos (expect commit / reject / commit) ==="
for d in ck_chain_positive ck_tamper_reject ck_recover; do
  timeout 120 krun "$P1C/$d.ck" -d ck-out > "/tmp/p1d_$d.txt" 2>&1
  EX=$?
  RES=$(grep -o '"commit"\|"reject"' "/tmp/p1d_$d.txt" | tail -1 | tr -d '"')
  log "--- $d: krun exit=$EX result=$RES"
done

log ""
log "REBUILD_1C_DONE (full kompile/link logs above)"
