#!/usr/bin/env bash
# SRW3 Phase 1J — run the security-closure K proof ladder (kprove, Haskell
# backend).  One definition: the ISOLATED J machine (+ inert fixtures).
# Scoring convention (the R3 discipline): score.txt = "<N_proved> <N_failed>"
# counted 1:1 over the claim inventory below (each label = exactly one
# kprove invocation = one log file); claims-status.csv records the per-claim
# machine-readable status.  J-REACHABLE-COMMITTED-SAFE is EXPECTED to fail
# (the kore circularity blocker); its failure is the retained NOT-MECHANIZED
# outcome, not a silent skip.
# Usage: bash phase1j/proofs/run_j_proofs.sh [outdir] [chunk]
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
OUT="${1:-$REPO/phase1j/transcripts/k}"
CHUNK="${2:-}"  # optional comma-separated claim subset
mkdir -p "$OUT"

source /home/z/my-project/tools/env.sh

cd "$REPO"
DEF_J=/tmp/j-hs
INC="-I $REPO/phase1g/semantics -I $REPO/phase1f/semantics -I $REPO/phase1e/semantics -I $REPO/k/phase1d -I $REPO/k/kevm/kproj-e1e/plugin"

if [ ! -f "$DEF_J/definition.kore" ] || [ "${REKOMPILE:-0}" = "1" ]; then
  echo "[1/2] kompiling the ISOLATED J definition + fixtures (Haskell backend)..."
  kompile "$HERE/j_fixtures.k" --backend haskell \
    --main-module SRW3CLOSURE-J-FIXTURES $INC -o "$DEF_J" > "$OUT/kompile_j.log" 2>&1
  [ -f "$DEF_J/definition.kore" ] || { echo "KOMPILE (J) FAILED — see $OUT/kompile_j.log"; exit 9; }
fi

J_CLAIMS=(
  J-CATALOG-CANON-FIXTURE
  J-CATALOG-DOMAIN-PREFIX
  J-CATALOG-BINDS-APPS
  J-CATALOG-BINDS-RESOURCES
  J-CATALOG-BINDS-GRAPH
  J-CATALOG-BINDS-POLICY
  J-CATALOG-KEYS-64BIT
  J-CATALOG-WF-OK
  J-CATALOG-WF-BAD-OWNER
  J-CATALOG-WF-DUP
  J-CATALOG-WF-DANGLING-HE
  J-CORRESPONDENCE-R3-CANON-PREFIX
  J-CORRESPONDENCE-CTX-TAG
  J-INIT-SAFE-BASE
  J-INIT-REFUSES-UNSAFE-GENESIS
  J-INIT-PINS-AUTHORIZED
  J-INIT-ROOT-MISMATCH-REJECTS
  J-INIT-REFUSES-GRAPH-MISMATCH
  J-INIT-REFUSES-BAD-CATALOG
  J-FRAG-TRACE-WRITE
  J-FRAG-TRACE-ORDER
  J-FRAG-READ-AFTER-WRITE
  J-FRAG-UNSUPPORTED
  J-FRAG-UNSUPPORTED-MIDPROGRAM
  J-FRAG-BOUNDS
  J-FOOTPRINT-PROJECTION
  J-EVIDENCE-STATE-CORRESPONDENCE
  J-CLOSURE-FIXTURE
  J-CLOSURE-EXHAUSTED
  J-FOOTPRINT-REGISTERED-OK
  J-FOOTPRINT-REGISTERED-UNKNOWN
  J-SAFE-HONEST
  J-SAFE-UNSAFE-COMPOSITION
  J-SAFE-GLOBAL-FAIL
  J-FRAME-PRESERVATION
  J-GATELINK-VALID
  J-DECISION-BOUND
  J-FORGED-VERDICT-REJECT
  J-COMMIT-NO-RECEIPT-REJECTS
  J-COMMIT-UNSAFE-COMPOSITION-REJECTS
  J-COMMIT-IMPLIES-SAFE-DESTINATION
  J-REACHABLE-COMMITTED-SAFE
)

echo "[2/2] proving ${#J_CLAIMS[@]} J claims..."
PASS=0; FAIL=0; FAILED=""
: > "$OUT/claims-status.csv"
echo "claim,backend,invoked,result,log" > "$OUT/claims-status.csv"
for CL in "${J_CLAIMS[@]}"; do
  if [ -n "$CHUNK" ] && ! echo ",$CHUNK," | grep -q ",$CL,"; then continue; fi
  LOG="$OUT/kprove_$CL.log"
  if [ -f "$OUT/.done_$CL" ]; then echo "SKIP     $CL (resumable marker)"; PASS=$((PASS+1)); continue; fi
  timeout 420 kprove "$HERE/j_proofs.k" \
    $INC \
    -d "$DEF_J" --spec-module J-PROOFS --claims "$CL" > "$LOG" 2>&1
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
