#!/bin/bash
# SRW3 Phase 1G — Part 4: K demo suite (LLVM backend, REAL krypto shim).
# The authority case study: the Oracle -> Lending -> Liquidator chain with
# per-record AuthorityCertificates (rel=1/1/2 + Mode B over R0), the CM-G
# countermodels, the BAL analysis, and the cross-layer byte source.
# Partitioned programs (the 3 GB sandbox constraint; 1F precedent).
set -u
source /home/z/my-project/tools/env.sh
SRC=/home/z/my-project/srw3-kevm
OUT=$SRC/phase1g/transcripts/part4_k_demo_suite.txt
: > "$OUT"
log() { echo "$@" | tee -a "$OUT"; }

log "=== SRW3 Phase 1G — Part 4: K DEMO SUITE (LLVM, real krypto) ==="
log "=== generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC') ==="
log "definition: phase1g/semantics/srw3authz-demo.k (module SRW3AUTHZ-DEMO)"
log "sha256(srw3authz-demo.k) = $(sha256sum $SRC/phase1g/semantics/srw3authz-demo.k | cut -d' ' -f1)"
log "sha256(srw3authz.k)      = $(sha256sum $SRC/phase1g/semantics/srw3authz.k | cut -d' ' -f1)"
log "backend: llvm (real keccak256 + secp256k1 via the pinned krypto shim)"
log "memory note: the concatenated suite exceeds the 3 GB sandbox when held in"
log "one term; programs below partition the SAME cases (no case is skipped)."
log ""

PASS=0; FAIL=0
run() { # run <pgm> <expected-substring>
  local PGM="$1" EXPECT="$2"
  echo "$PGM" > /tmp/x1g.pgm
  local T0=$(date +%s)
  timeout 300 krun /tmp/x1g.pgm -d "$SRC/phase1g/semantics/authz-out" > /tmp/x1g.out 2>&1
  local EX=$?
  local T1=$(date +%s)
  local GOT=$(grep -o '"[^"]*"' /tmp/x1g.out | head -1 | tr -d '"')
  log "--- $PGM (krun exit=$EX, $((T1-T0))s)"
  log "    got: $GOT"
  if [ "$GOT" = "$EXPECT" ]; then
    log "    EXPECTED MATCH: $EXPECT"; PASS=$((PASS+1))
  else
    log "    EXPECTED: $EXPECT"; log "    *** MISMATCH ***"; FAIL=$((FAIL+1))
  fi
  log ""
}

run xpos0 "valid-g"
run xchain "pos1=valid-g;pos2=valid-g;pos3=valid-g;certd0=89ffea587b63cc787989fe232899c98b6967eeed2e483247d17880dc8da68e95;childg0=4a02ea03827291e139d6307c2dc824c683172e169d83cbe0211ed60a610298f7"
run xcm1a "g1=invalid-authcircle;g2=invalid-authsrc"
run xcm1b "g3a=invalid-authlevel;g3b=invalid-authcircle"
run xcm2 "g4=invalid-authbind;g5=invalid-authbind;g6=invalid-authsrc;g7=invalid-authbind"
run xcm3 "g8=invalid-policy;g9=invalid-authsrc;g9b=invalid-authbind;g10=invalid-authtype;g11=invalid-authrel"
run xbal "bal1=true;bal2=false;bal3=balFootprint=true,balWrites=true,effbind=invalid-effbind;bal4a=true;bal4b=true;bal4diff=true"

# cross-layer bytes: recorded verbatim for the cross-layer comparison (the
# values are compared against the Python reference)
log "--- xbytes (cross-layer byte certificate source) ---"
echo "xbytes" > /tmp/x1g.pgm
timeout 300 krun /tmp/x1g.pgm -d "$SRC/phase1g/semantics/authz-out" > /tmp/x1g_bytes.out 2>&1
GOT=$(grep -o '"[^"]*"' /tmp/x1g_bytes.out | head -1 | tr -d '"')
log "$GOT" | tee -a "$OUT"
cp /tmp/x1g_bytes.out "$SRC/phase1g/transcripts/part4_xbytes_raw.txt"
log ""
log "SUMMARY: PASS=$PASS FAIL=$FAIL (bytes program checked in the cross-layer part)"
log "PART4_K_DEMO_DONE"
