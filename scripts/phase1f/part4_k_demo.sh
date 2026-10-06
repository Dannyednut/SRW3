#!/bin/bash
# SRW3 Phase 1F — Part 4: K demo suite (LLVM backend, REAL krypto shim).
# The abstract Level-3 case study: Oracle -> Lending -> Liquidator as a
# three-record LinRecF chain + the F-class negatives + cross-layer bytes.
# NOTE: the single concatenated suite string exceeds the sandbox memory
# (3 GB) when evaluated in ONE term; the suite therefore runs as FIVE
# programs over the same definition (pos / f8 / negs / bytes), each covering
# a disjoint subset of the same cases. Documented in the report.
set -u
source /home/z/my-project/tools/env.sh
SRC=/home/z/my-project/srw3-kevm
OUT=$SRC/phase1f/transcripts/part4_k_demo_suite.txt
: > "$OUT"
log() { echo "$@" | tee -a "$OUT"; }

log "=== SRW3 Phase 1F — Part 4: K DEMO SUITE (LLVM, real krypto) ==="
log "=== generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC') ==="
log "definition: phase1f/semantics/srw3exec-demo.k (module SRW3EXEC-DEMO)"
log "sha256(srw3exec-demo.k) = $(sha256sum $SRC/phase1f/semantics/srw3exec-demo.k | cut -d' ' -f1)"
log "sha256(srw3exec.k)      = $(sha256sum $SRC/phase1f/semantics/srw3exec.k | cut -d' ' -f1)"
log "backend: llvm (real keccak256 + secp256k1 via the pinned krypto shim)"
log "memory note: the concatenated suite exceeds the 3 GB sandbox when held in"
log "one term; programs below partition the SAME cases (no case is skipped)."
log ""

PASS=0; FAIL=0
run() { # run <pgm> <expected-substring>
  local PGM="$1" EXPECT="$2"
  echo "$PGM" > /tmp/x1f.pgm
  local T0=$(date +%s)
  timeout 300 krun /tmp/x1f.pgm -d "$SRC/phase1f/semantics/exec-out" > /tmp/x1f.out 2>&1
  local EX=$?
  local T1=$(date +%s)
  local GOT=$(grep -o '"[^"]*"' /tmp/x1f.out | head -1 | tr -d '"')
  log "--- $PGM (krun exit=$EX, $((T1-T0))s)"
  log "    got: $GOT"
  if [ "$GOT" = "$EXPECT" ]; then
    log "    EXPECTED MATCH: $EXPECT"; PASS=$((PASS+1))
  else
    log "    EXPECTED: $EXPECT"; log "    *** MISMATCH ***"; FAIL=$((FAIL+1))
  fi
  log ""
}

run xpos0 "valid-f"
run xchain "pos1=valid-f;pos2=valid-f"
run xf8 "f8a=valid-f;f8b=valid-f;f8diff=true"
run xnegs "neg1=invalid-effdecl;neg2=invalid-efftrace;neg3=invalid-anchor;neg4=invalid-execid;neg5=invalid-execconfig;neg6=invalid-witness;neg7=invalid-execbounds"
run xnegs2 "neg3x=valid-f;neg3xdiff=true;neg8=invalid-effbind"

# cross-layer bytes: recorded verbatim for the Part-6 comparison (the values
# are compared against the Python reference and the KEVM layer there)
log "--- xbytes (cross-layer byte certificate source) ---"
echo "xbytes" > /tmp/x1f.pgm
timeout 300 krun /tmp/x1f.pgm -d "$SRC/phase1f/semantics/exec-out" > /tmp/x1f_bytes.out 2>&1
GOT=$(grep -o '"[^"]*"' /tmp/x1f_bytes.out | head -1 | tr -d '"')
log "$GOT" | tee -a "$OUT"
cp /tmp/x1f_bytes.out "$SRC/phase1f/transcripts/part4_xbytes_raw.txt"
log ""
log "SUMMARY: PASS=$PASS FAIL=$FAIL (bytes program checked in Part 6)"
log "PART4_K_DEMO_DONE"
