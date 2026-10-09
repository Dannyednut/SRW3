#!/bin/bash
# SRW3 Phase 1I-R2 — LLVM backend + krypto shim rebuild (recipe per
# scripts/rebuild_1c_llvm_1d.sh / Phase-1C report §5 / 1D-R1 report).
# Produces the shim-linked LLVM interpreter for the R2 demo definition so the
# honest pipeline runs with REAL keccak-256 (and the gate computes real
# verdicts concretely).
set -u
source /home/z/my-project/tools/env.sh
REPO=/home/z/my-project/srw3b-work
T=/home/z/my-project/tools
P1D=$REPO/k/phase1d
LOG=$REPO/phase1i-r2/transcripts/k/r2_llvm_shim_build.log
: > "$LOG"
log() { echo "$@" | tee -a "$LOG"; }

log "=== SRW3 Phase 1I-R2 — LLVM + krypto shim rebuild ($(date -u)) ==="
CL=$T/extract/llvm/usr/bin/clang++-15
log "toolchain: $(kompile --version 2>&1 | head -1); clang $("$T/extract/llvm/usr/bin/clang-15" --version 2>/dev/null | head -1 || $CL --version | head -1)"

log ""
log "=== 1. krypto shim build (k/phase1d/shim — the multiblock-fix shim) ==="
cd "$P1D/shim" || exit 1
KRES="$T/extract/llvm/usr/lib/llvm-15/lib/clang/15.0.6/include"
"$CL" -std=c++20 -O2 -c krypto_shim.cpp \
  -isystem "$KRES" -nostdinc++ -isystem /usr/include/c++/14 -isystem /usr/include/x86_64-linux-gnu/c++/14 \
  -I"$T/extract/k/usr/include/kllvm" -I"$T/extract/k/usr/include" \
  -I"$T/extract/devheaders/usr/include" -I. >> "$LOG" 2>&1
S1=$?
"$CL" -std=c++20 -O2 -c plugin_util.cpp \
  -isystem "$KRES" -nostdinc++ -isystem /usr/include/c++/14 -isystem /usr/include/x86_64-linux-gnu/c++/14 \
  -I"$T/extract/k/usr/include/kllvm" -I"$T/extract/k/usr/include" \
  -I"$T/extract/devheaders/usr/include" >> "$LOG" 2>&1
S2=$?
log "shim objects: krypto_shim.o=$S1 plugin_util.o=$S2"
[ $S1 -eq 0 ] && [ $S2 -eq 0 ] || { log "SHIM BUILD FAILED"; tail -20 "$LOG"; exit 1; }
ar rcs libkrypto-shim.a krypto_shim.o plugin_util.o
log "libkrypto-shim.a: $(ls -la libkrypto-shim.a | awk '{print $5}') bytes"
cp -f "$T/extract/secp/usr/lib/x86_64-linux-gnu/libsecp256k1.so.2" libsecp256k1.so 2>/dev/null

# the marker check (1D-R1: the one-line keccak-multiblock fix present)
log "multiblock-fix marker: $(rg -c '136' krypto_shim.cpp) occurrences of the 136-byte block bound"

export NIX_LLVM_KOMPILE_LIBS="-L$P1D/shim -lkrypto-shim -lsecp256k1 -lgmp"
export LIBRARY_PATH="$T/extract/syslibs:$LIBRARY_PATH"

log ""
log "=== 2. R2 demo definition kompile (llvm + KRYPTO hooks + shim) ==="
INC="-I $REPO/phase1g/semantics -I $REPO/phase1f/semantics -I $REPO/phase1e/semantics -I $REPO/k/phase1d -I $REPO/k/kevm/kproj-e1e/plugin"
rm -rf /tmp/r2demo-llvm
timeout 590 kompile "$REPO/phase1i-r2/semantics/srw3proto-r2-demo.k" \
  --backend llvm --hook-namespaces KRYPTO \
  --main-module SRW3PROTO-R2-DEMO -o /tmp/r2demo-llvm $INC >> "$LOG" 2>&1
log "kompile r2demo-llvm exit=$? (0 = ok; nonzero = see log tail)"
if [ ! -x /tmp/r2demo-llvm/interpreter ]; then
  log "interpreter missing — attempting the manual two-step link (1C recipe)"
  cd /tmp/r2demo-llvm || exit 1
  timeout 300 "$T/extract/k/usr/bin/llvm-kompile" definition.kore dt main -o interpreter \
    "-L$P1D/shim" -lkrypto-shim -lsecp256k1 -lgmp >> "$LOG" 2>&1
  log "manual llvm-kompile exit=$? interpreter=$(ls -la interpreter 2>/dev/null | awk '{print $5}')"
fi

log ""
log "=== 3. probe run (init smoke test, real keccak) ==="
printf '%s\n' 'pConsR2(pInitR2(XCfgR2), runNilR2)' > /tmp/r2-probe.pgm
timeout 120 krun /tmp/r2-probe.pgm -d /tmp/r2demo-llvm > /tmp/r2_probe.txt 2>&1
log "probe krun exit=$?"
rg -o 'Keccak256raw' /tmp/r2_probe.txt | head -1 | xargs -I{} echo "unevaluated-keccak-terms: present" >> "$LOG" || log "no unevaluated keccak terms (concrete digests — the shim works)"
rg -o 'r2head' -A1 /tmp/r2_probe.txt | head -2 >> "$LOG" || true

log "R2_LLVM_REBUILD_DONE"
tail -5 "$LOG"
