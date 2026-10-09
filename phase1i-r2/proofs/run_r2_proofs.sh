#!/usr/bin/env bash
# SRW3 Phase 1I-R2 — run the gate-provenance K proof ladder (kprove, Haskell
# backend).  Two definitions:
#   (1) the ISOLATED R2 machine (srw3proto-r2.k) — the R2 ladder + ported
#       frozen claims + correspondence claims;
#   (2) the UNMODIFIED R1 model (srw3proto-r1.k) — the old-model witness
#       claims (old_r1_witness.k; the before side).
# Usage: bash phase1i-r2/proofs/run_r2_proofs.sh [outdir]
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
OUT="${1:-$REPO/phase1i-r2/transcripts/k}"
CHUNK="${2:-}"  # optional comma-separated claim subset
mkdir -p "$OUT"

source /home/z/my-project/tools/env.sh

cd "$REPO"
DEF_R2=/tmp/r2-hs
DEF_R1=/tmp/r1-hs
INC="-I $REPO/phase1g/semantics -I $REPO/phase1f/semantics -I $REPO/phase1e/semantics -I $REPO/k/phase1d -I $REPO/k/kevm/kproj-e1e/plugin"

if [ ! -f "$DEF_R2/definition.kore" ] || [ "${REKOMPILE:-0}" = "1" ]; then
  echo "[1/3] kompiling the ISOLATED R2 definition (Haskell backend)..."
  kompile "$REPO/phase1i-r2/semantics/srw3proto-r2.k" --backend haskell \
    --main-module SRW3PROTO-R2 $INC -o "$DEF_R2" > "$OUT/kompile_r2.log" 2>&1
  [ -f "$DEF_R2/definition.kore" ] || { echo "KOMPILE (R2) FAILED — see $OUT/kompile_r2.log"; exit 9; }
fi
if [ ! -f "$DEF_R1/definition.kore" ] || [ "${REKOMPILE:-0}" = "1" ]; then
  echo "[2/3] kompiling the UNMODIFIED R1 definition (Haskell backend)..."
  kompile "$REPO/phase1i-r1/semantics/srw3proto-r1.k" --backend haskell \
    --main-module SRW3PROTO-R1 $INC -o "$DEF_R1" > "$OUT/kompile_r1.log" 2>&1
  [ -f "$DEF_R1/definition.kore" ] || { echo "KOMPILE (R1) FAILED — see $OUT/kompile_r1.log"; exit 9; }
fi

R2_CLAIMS=(
  R2-INIT-PINS
  R2-CONFIG-IMMUTABLE
  R2-MINT-SHAPE-EXISTING-POOL
  R2-MINT-SHAPE-EMPTY-POOL
  R2-CONFIG-FRAME-GATE
  R2-ACCEPT-IMPLIES-COMMITP
  R2-VALID-ACCEPT
  R2-DECISION-BOUND
  R2-GATELINK-VALID
  R2-GATELINK-REJECT1
  R2-GATELINK-REJECT2
  R2-GATELINK-REJECT3
  R2-FORGED-VERDICT-REJECT
  R2-FORGED-VERDICT-REJECT-AUTHTYPE
  R2-REJECT-NO-POOL
  R2-REJECT-EMPTY-POOL
  R2-REJECT-WRONG-CANDIDATE
  R2-REJECT-STALE-HEAD
  R2-REJECT-STALE-LINHEAD
  R2-REJECT-WRONG-SLOT
  R2-REJECT-GATE-INPUT-MISMATCH
  R2-CONFIG-SUB-REJECT
  R2-CONFIG-FRAME-ACCEPT
  R2-RECEIPT-SINGLE-USE
  R2-PIPELINE-HONEST
  R2-PIPELINE-FORGED
  PI1-COMMIT-SAFETY
  PI2-DECISION-REJECT
  PI2-DECISION-UNKNOWN
  PI2-EXEC-INVALID
  PI5-AUTHORITY-DESCENT
  PI7-BASE
  R2-CORRESPONDENCE-CONFIG-ROOT
  R2-CORRESPONDENCE-POLICY-COMMITMENT
  R2-CORRESPONDENCE-CTX-DIGEST
  R2-CORRESPONDENCE-BLOCK-COMMIT
  R2-ALL
)

OLD_CLAIMS=(
  OLD-R1-GATE-MINTS-CALLER-VERDICT
  OLD-R1-ACCEPTS-CALLER-VERDICT
  OLD-R1-PIPELINE-FORGED
)

echo "[3/3] proving ${#R2_CLAIMS[@]} R2 claims + ${#OLD_CLAIMS[@]} old-model witness claims..."
PASS=0; FAIL=0; FAILED=""
for CL in "${R2_CLAIMS[@]}"; do
  if [ -n "$CHUNK" ] && ! echo ",$CHUNK," | rg -q ",$CL,"; then continue; fi
  LOG="$OUT/kprove_$CL.log"
  if [ -f "$OUT/.done_$CL" ]; then echo "SKIP     $CL (resumable marker)"; PASS=$((PASS+1)); continue; fi
  timeout 300 kprove "$HERE/r2_proofs.k" \
    $INC \
    -d "$DEF_R2" --spec-module R2-PROOFS --claims "$CL" > "$LOG" 2>&1
  RC=$?
  if [ $RC -eq 0 ]; then
    echo "PROVED   $CL"; touch "$OUT/.done_$CL"
    PASS=$((PASS+1))
  else
    echo "FAILED   $CL  (rc=$RC; see $LOG)"
    FAIL=$((FAIL+1)); FAILED="$FAILED $CL"
  fi
done

for CL in "${OLD_CLAIMS[@]}"; do
  if [ -n "$CHUNK" ] && ! echo ",$CHUNK," | rg -q ",$CL,"; then continue; fi
  LOG="$OUT/kprove_$CL.log"
  if [ -f "$OUT/.done_$CL" ]; then echo "SKIP     $CL (resumable marker)"; PASS=$((PASS+1)); continue; fi
  timeout 300 kprove "$HERE/old_r1_witness.k" \
    $INC \
    -d "$DEF_R1" --spec-module OLD-R1-WITNESS --claims "$CL" > "$LOG" 2>&1
  RC=$?
  if [ $RC -eq 0 ]; then
    echo "WITNESSED $CL"; touch "$OUT/.done_$CL"
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
