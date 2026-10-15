#!/bin/bash
# SRW3 Phase 1J — LLVM backend + krypto shim rebuild (recipe per
# scripts/r2_build_llvm.sh / Phase-1C report §5 / 1D-R1 multiblock fix).
# Produces the shim-linked LLVM interpreter for the J demo definition so the
# honest pipeline runs with REAL keccak-256 (the machine's canonical roots,
# state roots, evidence identities, and the frozen gate verdicts compute
# concretely).
set -u
source /home/z/my-project/tools/env.sh
REPO=/home/z/my-project/srw3-repo
T=/home/z/my-project/tools
P1D=$REPO/k/phase1d
OUT=/tmp/j-llvm
LOG=${1:-$REPO/phase1j/transcripts/k/j_llvm_shim_build.log}
mkdir -p "$(dirname "$LOG")"
: > "$LOG"
log() { echo "$@" | tee -a "$LOG"; }

log "=== SRW3 Phase 1J — LLVM + krypto shim rebuild ($(date -u)) ==="
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
log "multiblock-fix marker: $(grep -c '136' krypto_shim.cpp) occurrences of the 136-byte block bound"

# dev-symlink shims for the interpreter link (the 1B recorded deviations)
mkdir -p "$T/extract/syslibs"
for L in tinfo mpfr jemalloc unwind; do
  SRC=$(ldconfig -p | grep -m1 "lib$L\.so" | awk '{print $NF}')
  [ -n "$SRC" ] && [ -e "$T/extract/syslibs/lib$L.so" ] || ln -sf "$SRC" "$T/extract/syslibs/lib$L.so" 2>/dev/null
done
log "syslibs: $(ls "$T/extract/syslibs" 2>/dev/null | tr '\n' ' ')"

export NIX_LLVM_KOMPILE_LIBS="-L$P1D/shim -lkrypto-shim -lsecp256k1 -lgmp"
export LIBRARY_PATH="$T/extract/syslibs:$LIBRARY_PATH"

log ""
log "=== 2. J demo definition kompile (llvm + KRYPTO hooks + shim) ==="
INC="-I $REPO/phase1g/semantics -I $REPO/phase1f/semantics -I $REPO/phase1e/semantics -I $REPO/k/phase1d -I $REPO/k/kevm/kproj-e1e/plugin"
rm -rf "$OUT"
timeout 590 kompile "$REPO/phase1j/semantics/srw3closure-j-demo.k" \
  --backend llvm --hook-namespaces KRYPTO \
  --main-module SRW3CLOSURE-J-DEMO -o "$OUT" $INC >> "$LOG" 2>&1
log "kompile jdemo-llvm exit=$? (0 = ok; nonzero = see log tail)"
if [ ! -x "$OUT/interpreter" ] && [ -f "$OUT/definition.kore" ]; then
  log "interpreter missing — attempting the manual two-step link (1C recipe)"
  cd "$OUT" || exit 1
  timeout 300 "$T/extract/k/usr/bin/llvm-kompile" definition.kore dt main -o interpreter \
    "-L$P1D/shim" -lkrypto-shim -lsecp256k1 -lgmp >> "$LOG" 2>&1
  log "manual llvm-kompile exit=$? interpreter=$(ls -la interpreter 2>/dev/null | awk '{print $5}')"
fi
[ -x "$OUT/interpreter" ] && log "J LLVM INTERPRETER READY: $OUT/interpreter" || { log "J LLVM BUILD FAILED"; tail -30 "$LOG"; exit 1; }
