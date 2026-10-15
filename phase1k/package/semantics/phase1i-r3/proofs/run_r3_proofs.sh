#!/usr/bin/env bash
# SRW3 Phase 1I-R3 — run the configuration-root-binding K proof ladder
# (kprove, Haskell backend).  One definition: the ISOLATED R3 machine.
# Scoring convention (handoff §8: R3 must not inherit an ambiguous score):
#   score.txt = "<N_proved> <N_failed>" counted 1:1 over the claim inventory
#   below (each label = exactly one kprove invocation = one log file);
#   claims-status.csv records the per-claim machine-readable status.
# R3-ALL is EXPECTED to fail (the kore circularity blocker); its failure is
# the recorded NOT-MECHANIZED outcome, not a silent skip.
# Usage: bash phase1i-r3/proofs/run_r3_proofs.sh [outdir] [chunk]
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
OUT="${1:-$REPO/phase1i-r3/transcripts/k}"
CHUNK="${2:-}"  # optional comma-separated claim subset
mkdir -p "$OUT"

source /home/z/my-project/tools/env.sh

cd "$REPO"
DEF_R3=/tmp/r3-hs
INC="-I $REPO/phase1g/semantics -I $REPO/phase1f/semantics -I $REPO/phase1e/semantics -I $REPO/k/phase1d -I $REPO/k/kevm/kproj-e1e/plugin"

# The proof DEFINITION is compiled from r3_fixtures.k (main module
# SRW3PROTO-R3-FIXTURES): the concrete canon fixture and the legacy witness
# oracle must live in the DEFINITION closure because K proof modules admit
# only claims/simplification rules.  The fixture module imports and adds
# NOTHING to the transition system of srw3proto-r3.k (inert constants; the
# audit cross-checks that the rule sets are identical).
if [ ! -f "$DEF_R3/definition.kore" ] || [ "${REKOMPILE:-0}" = "1" ]; then
  echo "[1/2] kompiling the ISOLATED R3 definition + fixtures (Haskell backend)..."
  kompile "$REPO/phase1i-r3/proofs/r3_fixtures.k" --backend haskell \
    --main-module SRW3PROTO-R3-FIXTURES $INC -o "$DEF_R3" > "$OUT/kompile_r3.log" 2>&1
  [ -f "$DEF_R3/definition.kore" ] || { echo "KOMPILE (R3) FAILED — see $OUT/kompile_r3.log"; exit 9; }
fi

R3_CLAIMS=(
  R3-CANON-FIELD-ORDER
  R3-CANON-DOMAIN-PREFIX
  R3-CANON-LENGTH-DELIMITED
  R3-BINDS-FIELDS-1-8
  R3-ROOT-BINDS-AUTHORITY-FIELDS-F09
  R3-ROOT-BINDS-AUTHORITY-FIELDS-F10
  R3-ROOT-BINDS-AUTHORITY-FIELDS-F11
  R3-ROOT-BINDS-AUTHORITY-FIELDS-F12
  R3-ROOT-BINDS-AUTHORITY-FIELDS-F13
  R3-R2-ALIAS-WITNESS
  R3-DOMAIN-SEPARATION
  R3-INIT-PINS-AUTHORIZED
  R3-INIT-ROOT-MISMATCH-REJECTS
  R3-CONFIG-IMMUTABLE
  R3-MINT-SHAPE-EXISTING-POOL
  R3-MINT-SHAPE-EMPTY-POOL
  R3-CONFIG-FRAME-GATE
  R3-ACCEPT-IMPLIES-COMMITP
  R3-VALID-ACCEPT
  R3-CONFIG-FRAME-ACCEPT
  R3-DECISION-BOUND
  R3-GATELINK-VALID
  R3-GATELINK-REJECT1
  R3-GATELINK-REJECT2
  R3-GATELINK-REJECT3
  R3-FORGED-VERDICT-REJECT
  R3-FORGED-VERDICT-REJECT-AUTHTYPE
  R3-REJECT-NO-POOL
  R3-REJECT-EMPTY-POOL
  R3-REJECT-WRONG-CANDIDATE
  R3-REJECT-STALE-HEAD
  R3-REJECT-STALE-LINHEAD
  R3-REJECT-WRONG-SLOT
  R3-REJECT-GATE-INPUT-MISMATCH
  R3-CONFIG-SUB-REJECT
  R3-REJECT-ANCHOR-MISMATCH
  R3-RECEIPT-SINGLE-USE
  R3-PIPELINE-HONEST
  R3-PIPELINE-FORGED
  PI1-COMMIT-SAFETY
  PI2-DECISION-REJECT
  PI2-DECISION-UNKNOWN
  PI2-EXEC-INVALID
  PI5-AUTHORITY-DESCENT
  PI7-BASE
  R3-CORRESPONDENCE-POLICY-COMMITMENT
  R3-CORRESPONDENCE-CTX-DIGEST
  R3-CORRESPONDENCE-BLOCK-COMMIT
  R3-CORRESPONDENCE-ROOT-R3
  R3-ALL
)

echo "[2/2] proving ${#R3_CLAIMS[@]} R3 claims..."
PASS=0; FAIL=0; FAILED=""
: > "$OUT/claims-status.csv"
echo "claim,backend,invoked,result,log" > "$OUT/claims-status.csv"
for CL in "${R3_CLAIMS[@]}"; do
  if [ -n "$CHUNK" ] && ! echo ",$CHUNK," | rg -q ",$CL,"; then continue; fi
  LOG="$OUT/kprove_$CL.log"
  if [ -f "$OUT/.done_$CL" ]; then echo "SKIP     $CL (resumable marker)"; PASS=$((PASS+1)); continue; fi
  timeout 420 kprove "$HERE/r3_proofs.k" \
    $INC \
    -d "$DEF_R3" --spec-module R3-PROOFS --claims "$CL" > "$LOG" 2>&1
  RC=$?
  if [ $RC -eq 0 ]; then
    echo "PROVED   $CL"; touch "$OUT/.done_$CL"
    echo "$CL,haskell,yes,PROVED,kprove_$CL.log" >> "$OUT/claims-status.csv"
    PASS=$((PASS+1))
  else
    echo "FAILED   $CL  (rc=$RC; see $LOG)"
    echo "$CL,haskell,yes,FAILED(rc=$RC),kprove_$CL.log" >> "$OUT/claims-status.csv"
    FAIL=$((FAIL+1)); FAILED="$FAILED $CL"
  fi
done

echo
echo "K proof ladder: $PASS PROVED / $FAIL FAILED"
[ -n "$FAILED" ] && echo "failed:$FAILED"
echo "$PASS $FAIL" > "$OUT/score.txt"
exit $FAIL
