#!/bin/bash
# SRW3 Phase 1D-R1-FINAL — Part 7 (K demo stages C): KEVM lineage composition.
# Live re-kompile of k/kevm/srw3-lin-evm.k (LLVM + krypto shim) and the two
# lineage demos: lin_evm_multi (COMMIT, n=1) / lin_evm_overflow (REJECT,
# 0 records, storages restored). krun exit=1 is the DESIGNED carrier terminal.
set -u
source /home/z/my-project/tools/env.sh
SRC=/home/z/my-project/srw3-work
OUT=$SRC/transcripts/audit/phase1d_r1/final_regression_kevm_lin.txt
: > "$OUT"
log() { echo "$@" | tee -a "$OUT"; }

log "=== SRW3 Phase 1D-R1-FINAL — Part 7: REGRESSION, KEVM lineage ==="
log "=== generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC') ==="
log "definition: k/kevm/srw3-lin-evm.k (module SRW3-LIN-EVM; additive over"
log "            frozen 1A/1B bindings; LinBuildRec shared with the abstract layer)"
log "toolchain : $(kompile --version 2>&1 | head -1); LLVM backend; krypto shim"
log ""

# ---------- [E1] kompile SRW3-LIN-EVM ----------
log "--- [E1] kompile srw3-lin-evm.k (llvm + shim) ---"
log "exact command:"
log "  kompile srw3-lin-evm.k --backend llvm --hook-namespaces KRYPTO \\"
log "    --main-module SRW3-LIN-EVM -o kevm-lin-llvm-out \\"
log "    -I . -I ../phase1d -I \$KEVMSRC/.../kproj -I \$KEVMSRC/.../kproj/evm-semantics -I \$PLUGIN"
cd "$SRC/k/kevm" || exit 1
export NIX_LLVM_KOMPILE_LIBS="-L$SRC/k/phase1d/shim -lkrypto-shim -lsecp256k1 -lgmp"
KPROJ=$KEVMSRC/kevm-pyk/src/kevm_pyk/kproj
if [ -x kevm-lin-llvm-out/interpreter ]; then
  log "[E1] kompile SKIPPED (kevm-lin-llvm-out/interpreter already built this session)"
else
  rm -rf kevm-lin-llvm-out
timeout 590 kompile srw3-lin-evm.k --backend llvm --hook-namespaces KRYPTO \
  --main-module SRW3-LIN-EVM -o kevm-lin-llvm-out \
  -I . -I ../phase1d -I "$KPROJ" \
  -I "$KPROJ/evm-semantics" \
  -I "$PLUGIN" > /tmp/kevmlin_komp.txt 2>&1
fi
EK=$?
log "[E1] kompile exit=$EK (interpreter: $(stat -c %s kevm-lin-llvm-out/interpreter 2>/dev/null || echo ABSENT) bytes)"
log ""

# ---------- [E2] lin_evm_multi (positive: COMMIT) ----------
log "--- [E2] demo lin_evm_multi (positive — expect 1B carrier commit n=1,"
log "     1D carrier n=1 head=Bytes, record 0 present) ---"
log "exact command:"
log "  krun demos/lin_evm_multi.srw3evm -d kevm-lin-llvm-out -cCHAINID=1 \\\n    -cMODE=NORMAL -cSCHEDULE=CANCUN -cUSEGAS=false"
timeout 300 krun "$SRC/k/kevm/demos/lin_evm_multi.srw3evm" -d kevm-lin-llvm-out \
  -cCHAINID=1 -cMODE=NORMAL -cSCHEDULE=CANCUN -cUSEGAS=false \
  > /tmp/kevmlin_multi.txt 2>&1
EX=$?
log "krun exit=$EX (1 = designed carrier terminal)"
log "1B carrier : $(grep -o '#w3State(.*' /tmp/kevmlin_multi.txt | tail -1 | cut -c1-100)"
log "1D carrier : $(grep -o '#w3LinState(.*' /tmp/kevmlin_multi.txt | tail -1 | cut -c1-140)"
NREC=$(grep -o 'w3lin (' /tmp/kevmlin_multi.txt | wc -l)
HEADB=$(grep -o 'head: b"[^"]*"' /tmp/kevmlin_multi.txt | tail -1)
log "records in chain: $NREC; $HEADB"
log ""

# ---------- [E3] lin_evm_overflow (negative: REJECT + restore) ----------
log "--- [E3] demo lin_evm_overflow (negative — expect NO record (n=0),"
log "     storages restored = commit/lineage atomicity) ---"
timeout 300 krun "$SRC/k/kevm/demos/lin_evm_overflow.srw3evm" -d kevm-lin-llvm-out \
  -cCHAINID=1 -cMODE=NORMAL -cSCHEDULE=CANCUN -cUSEGAS=false \
  > /tmp/kevmlin_over.txt 2>&1
EX=$?
log "krun exit=$EX (1 = designed carrier terminal)"
NREC2=$(grep -o 'w3lin (' /tmp/kevmlin_over.txt | wc -l)
log "records in chain: $NREC2 (expect 0 — no lineage record for a rejected transition)"
log "1B carrier : $(grep -o '#w3State(.*' /tmp/kevmlin_over.txt | tail -1 | cut -c1-100)"
log ""

log "PART7_KEVM_LIN_DONE"
