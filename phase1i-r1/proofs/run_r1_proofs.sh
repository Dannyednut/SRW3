#!/usr/bin/env bash
# SRW3 Phase 1I-R1 — run the repaired K proof ladder (kprove, Haskell backend).
# Two definitions:
#   (1) the REPAIRED model (srw3proto-r1.k) — the R1 ladder + ported claims;
#   (2) the FROZEN model (srw3proto.k, unmodified) — the forged-verdict
#       witness claims (old_witness.k).
# Usage: bash phase1i-r1/proofs/run_r1_proofs.sh [outdir]
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
OUT="${1:-$REPO/phase1i-r1/transcripts/k}"
mkdir -p "$OUT"

source /home/z/my-project/tools/env.sh

cd "$REPO"
DEF_R1=/tmp/r1-hs
DEF_OLD=/tmp/proto-hs
INC="-I $REPO/phase1g/semantics -I $REPO/phase1f/semantics -I $REPO/phase1e/semantics -I $REPO/k/phase1d -I $REPO/k/kevm/kproj-e1e/plugin"

if [ ! -f "$DEF_R1/definition.kore" ] || [ "${REKOMPILE:-0}" = "1" ]; then
  echo "[1/3] kompiling the REPAIRED definition (Haskell backend)..."
  kompile "$REPO/phase1i-r1/semantics/srw3proto-r1.k" --backend haskell \
    --main-module SRW3PROTO-R1 $INC -o "$DEF_R1" > "$OUT/kompile_r1.log" 2>&1
  [ -f "$DEF_R1/definition.kore" ] || { echo "KOMPILE (R1) FAILED — see $OUT/kompile_r1.log"; exit 9; }
fi
if [ ! -f "$DEF_OLD/definition.kore" ] || [ "${REKOMPILE:-0}" = "1" ]; then
  echo "[2/3] kompiling the FROZEN definition (Haskell backend)..."
  kompile "$REPO/phase1i/semantics/srw3proto.k" --backend haskell \
    --main-module SRW3PROTO $INC -o "$DEF_OLD" > "$OUT/kompile_old.log" 2>&1
  [ -f "$DEF_OLD/definition.kore" ] || { echo "KOMPILE (frozen) FAILED — see $OUT/kompile_old.log"; exit 9; }
fi

R1_CLAIMS=(
  R1-INIT-PINS
  R1-CONFIG-IMMUTABLE
  R1-ACCEPT-IMPLIES-COMMITP
  R1-DECISION-BOUND
  R1-FORGED-VERDICT-REJECT
  R1-FORGED-VERDICT-REJECT-AUTHTYPE
  R1-REJECT-NO-POOL
  R1-REJECT-EMPTY-POOL
  R1-REJECT-WRONG-CANDIDATE
  R1-REJECT-STALE-HEAD
  R1-REJECT-WRONG-SLOT
  R1-CONFIG-FRAME-GATE
  R1-CONFIG-FRAME-ACCEPT
  R1-CONFIG-SUB-REJECT
  R1-VALID-ACCEPT
  R1-PIPELINE-HONEST
  R1-RECEIPT-SINGLE-USE
  R1-PIPELINE-FORGED
  PI1-COMMIT-SAFETY
  PI2-DECISION-REJECT
  PI2-DECISION-UNKNOWN
  PI2-EXEC-INVALID
  PIB-GATELINK-VALID
  PIB-GATELINK-REJECT1
  PIB-GATELINK-REJECT2
  PIB-GATELINK-REJECT3
  PI5-AUTHORITY-DESCENT
  PI7-BASE
  R1-ALL
)

OLD_CLAIMS=(
  OLD-ACCEPTS-FORGED
  OLD-ACCEPTS-INVALID-DECISION
  OLD-ACCEPTS-UNKNOWN-DECISION
)
# OLD-ACCEPTS-CALLER-CONFIG is NOT MECHANIZED on the hs backend (nested-keccak
# #Ceil blocker); the retained attempt log is
# transcripts/k/kprove_OLD-ACCEPTS-CALLER-CONFIG-attempt.log and the commented
# claim + blocker note live in old_witness.k.

echo "[3/3] proving ${#R1_CLAIMS[@]} repaired-model claims + ${#OLD_CLAIMS[@]} frozen-model witness claims..."
PASS=0; FAIL=0; FAILED=""
for CL in "${R1_CLAIMS[@]}"; do
  LOG="$OUT/kprove_$CL.log"
  timeout 300 kprove "$HERE/r1_proofs.k" \
    $INC \
    -d "$DEF_R1" --spec-module R1-PROOFS --claims "$CL" > "$LOG" 2>&1
  RC=$?
  if [ $RC -eq 0 ]; then
    echo "PROVED   $CL"
    PASS=$((PASS+1))
  else
    echo "FAILED   $CL  (rc=$RC; see $LOG)"
    FAIL=$((FAIL+1)); FAILED="$FAILED $CL"
  fi
done

for CL in "${OLD_CLAIMS[@]}"; do
  LOG="$OUT/kprove_$CL.log"
  timeout 300 kprove "$HERE/old_witness.k" \
    $INC \
    -d "$DEF_OLD" --spec-module OLD-WITNESS --claims "$CL" > "$LOG" 2>&1
  RC=$?
  if [ $RC -eq 0 ]; then
    echo "WITNESSED $CL"
    PASS=$((PASS+1))
  else
    echo "FAILED   $CL  (rc=$RC; see $LOG)"
    FAIL=$((FAIL+1)); FAILED="$FAILED $CL"
  fi
done

echo
echo "K proof ladder: $PASS PROVED / $FAIL FAILED"
[ -n "$FAILED" ] && echo "failed:$FAILED"
echo "$PASS $FAIL" > "$OUT/score.txt"
exit $FAIL
