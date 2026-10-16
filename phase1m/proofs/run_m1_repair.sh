#!/usr/bin/env bash
# SRW3 Phase 1M — run the M1 repair ladder (kprove, Haskell backend).
#
# Scoring convention (the R3 discipline, extended with EXPECTED outcomes):
# every claim is invoked EXACTLY ONCE per canonical run with its raw exit
# code and retained log.  The two negative controls (M1-NEG-SOURCE-*) are
# EXPECTED-FAIL: their failure is the required correct outcome (a proof of
# a negative control is an over-application alarm and FAILS the gate).
# M1-EXEC-OK-MINT-POOL is EXPECTED-FAIL (the retained B3 boundary).
# score counts CORRECT outcomes 1:1 over this inventory; the per-claim raw
# results are never relabeled.
# Usage: bash phase1m/proofs/run_m1_repair.sh [outdir] [chunk]
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
OUT="${1:-$REPO/phase1m/transcripts/k}"
CHUNK="${2:-}"
mkdir -p "$OUT"

source /home/z/my-project/tools/env.sh

cd "$REPO"
DEF_M1=/tmp/m1-hs
INC="-I $REPO/phase1g/semantics -I $REPO/phase1f/semantics -I $REPO/phase1e/semantics -I $REPO/k/phase1d -I $REPO/k/kevm/kproj-e1e/plugin"

if [ ! -f "$DEF_M1/definition.kore" ] || [ "${REKOMPILE:-0}" = "1" ]; then
  echo "[1/2] kompiling the M1 REPAIRED definition (Haskell backend)..."
  kompile "$HERE/../semantics/srw3closure-j-m1.k" --backend haskell \
    --main-module SRW3CLOSURE-J-M1 $INC -o "$DEF_M1" > "$OUT/kompile_m1.log" 2>&1
  [ -f "$DEF_M1/definition.kore" ] || { echo "KOMPILE (M1) FAILED — see $OUT/kompile_m1.log"; exit 9; }
  echo "      ok ($(grep -c . "$OUT/kompile_m1.log" 2>/dev/null || echo 0) log lines)"
fi
echo "[2/2] definition ready — running the M1 ladder"

# claim|expected   (expected: PASS = kprove must succeed; FAIL = kprove must
#                   fail — the negative controls and the retained B3)
CLAIMS=(
  "M1-EXEC-DISPATCH-SOURCE|PASS"
  "M1-EXEC-DISPATCH-SOURCE-SINGLE-ENTRY|PASS"
  "M1-EXEC-SOURCE-NOCOMMIT|PASS"
  "M1-NEG-SOURCE-AUTHORIZED-DIAGNOSTIC|FAIL"
  "M1-NEG-SOURCE-DIAG-BOUNDS|FAIL"
  "M1-EXEC-OK-MINT-POOL|FAIL"
)

PASS=0; FAIL=0; GATE=0
if [ ! -f "$OUT/claims-status-m1.csv" ]; then
  echo "claim,backend,invoked,expected,raw_result,correct,log" > "$OUT/claims-status-m1.csv"
fi

for ENTRY in "${CLAIMS[@]}"; do
  CL="${ENTRY%%|*}"; EXP="${ENTRY##*|}"
  if [ -n "$CHUNK" ]; then
    case ",$CHUNK," in *",$CL,"*) ;; *) continue;; esac
  fi
  LOG="$OUT/kprove_$CL.log"
  if [ -f "$OUT/.done_$CL" ] && [ -z "${RERUN:-}" ]; then
    echo "SKIP     $CL (done; RERUN=1 to force)"
    continue
  fi
  echo "kprove   $CL (expected $EXP)"
  timeout "${M1CLAIM_TIMEOUT:-500}" kprove "$HERE/m1_repair.k" \
    $INC \
    -d "$DEF_M1" --spec-module M1-REPAIR --claims "$CL" > "$LOG" 2>&1
  RC=$?
  [ $RC -eq 124 ] && echo "  (timeout — retained as FAILED)"
  if [ $RC -eq 0 ]; then
    RAW=PROVED
  else
    RAW="FAILED(rc=$RC)"
  fi
  if [ "$RAW" = "PROVED" ] && [ "$EXP" = "PASS" ]; then CORR=correct
  elif [ "$RAW" != "PROVED" ] && [ "$EXP" = "FAIL" ]; then CORR=correct
  elif [ "$RAW" = "PROVED" ] && [ "$EXP" = "FAIL" ]; then CORR=ALARM
  else CORR=INCORRECT; GATE=$((GATE+1))
  fi
  if [ "$CORR" = "correct" ]; then
    PASS=$((PASS+1)); echo "  -> $RAW (correct for expected $EXP)"
  else
    FAIL=$((FAIL+1)); echo "  -> $RAW (EXPECTED $EXP — GATE ALARM)"
  fi
  touch "$OUT/.done_$CL"
  echo "$CL,haskell,yes,$EXP,$RAW,$CORR,kprove_$CL.log" >> "$OUT/claims-status-m1.csv"
done

echo
echo "M1 repair ladder: $PASS correct / $FAIL gate alarms (of $(grep -c "^M1-" "$OUT/claims-status-m1.csv" 2>/dev/null || echo 0) invoked)"
echo "gate alarms (negative controls proving, or expected-proved failing): $GATE"
echo "$PASS $GATE" > "$OUT/score-m1.txt"
exit "$GATE"
