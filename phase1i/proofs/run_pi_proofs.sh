#!/usr/bin/env bash
# SRW3 Phase 1I — run the K proof ladder (kprove, Haskell backend).
# Two-stage: (1) kompile the claims module once, (2) kprove per claim.
# Usage: bash phase1i/proofs/run_pi_proofs.sh [outdir]
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
OUT="${1:-$REPO/phase1i/transcripts/k}"
mkdir -p "$OUT"

source /home/z/my-project/tools/env.sh

cd "$REPO"
DEF=/tmp/proto-hs

if [ ! -f "$DEF/definition.kore" ] || [ "${REKOMPILE:-0}" = "1" ]; then
  echo "[1/2] kompiling the protocol definition (Haskell backend)..."
  kompile "$REPO/phase1i/semantics/srw3proto.k" --backend haskell \
    -I "$REPO/phase1g/semantics" -I "$REPO/phase1f/semantics" \
    -I "$REPO/phase1e/semantics" -I "$REPO/k/phase1d" \
    -I "$REPO/k/kevm/kproj-e1e/plugin" -o "$DEF" 2>&1 \
    | rg -v "Warning.*syntax-module" | tail -2
  [ -f "$DEF/definition.kore" ] || { echo "KOMPILE FAILED"; exit 9; }
fi

# The mechanizable ladder (13 claims — all PROVED).  PI2-POLICY-SUB /
# PI2-CTX-SUB (keccak-blocked) and PI7-ALL (circularity implication check)
# are NOT MECHANIZED and documented in pi_proofs.k.
CLAIMS=(
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
  PI7-STEP
  PI7-REJECT
)

echo "[2/2] proving ${#CLAIMS[@]} claims..."
PASS=0; FAIL=0; FAILED=""
for CL in "${CLAIMS[@]}"; do
  LOG="$OUT/kprove_$CL.log"
  timeout 300 kprove "$HERE/pi_proofs.k" \
    -I "$REPO/phase1g/semantics" -I "$REPO/phase1f/semantics" \
    -I "$REPO/phase1e/semantics" -I "$REPO/k/phase1d" \
    -I "$REPO/k/kevm/kproj-e1e/plugin" \
    -d "$DEF" --spec-module PI-PROOFS --claims "$CL" > "$LOG" 2>&1
  RC=$?
  if [ $RC -eq 0 ]; then
    echo "PROVED   $CL"
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
