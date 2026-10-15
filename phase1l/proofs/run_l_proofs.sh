#!/usr/bin/env bash
# SRW3 Phase 1L — run the universal-induction K proof ladder (kprove, Haskell
# backend).  One definition: the FROZEN J machine + the 1L proof-facing
# invariant definitions (no J semantic change — the audit's rule-inventory
# cross-check verifies the reachable rule set is the frozen machine's).
#
# Scoring convention (the R3 discipline, extended with EXPECTED outcomes):
# every claim is invoked EXACTLY ONCE per canonical run with its raw exit
# code and retained log.  Negative controls (L-EXP-DESTVAR-NEG,
# L-NEG-CONTROL-SAFEJ) are EXPECTED-FAIL: their failure is the required
# correct outcome (a proof of a negative control is a vacuity alarm and
# FAILS the gate).  score.txt counts CORRECT outcomes 1:1 over this
# inventory; the per-claim raw results are never relabeled.
# Usage: bash phase1l/proofs/run_l_proofs.sh [outdir] [chunk]
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
OUT="${1:-$REPO/phase1l/transcripts/k}"
CHUNK="${2:-}"  # optional comma-separated claim subset
mkdir -p "$OUT"

source /home/z/my-project/tools/env.sh

cd "$REPO"
DEF_L=/tmp/l-hs
INC="-I $REPO/phase1g/semantics -I $REPO/phase1f/semantics -I $REPO/phase1e/semantics -I $REPO/k/phase1d -I $REPO/k/kevm/kproj-e1e/plugin"

if [ ! -f "$DEF_L/definition.kore" ] || [ "${REKOMPILE:-0}" = "1" ]; then
  echo "[1/2] kompiling the FROZEN J definition + the 1L invariant definitions (Haskell backend)..."
  kompile "$HERE/../semantics/j_invariant.k" --backend haskell \
    --main-module SRW3L-INVARIANT $INC -o "$DEF_L" > "$OUT/kompile_l.log" 2>&1
  [ -f "$DEF_L/definition.kore" ] || { echo "KOMPILE (L) FAILED — see $OUT/kompile_l.log"; exit 9; }
fi
echo "[2/2] definition ready — running the L ladder"

# claim|expected   (expected: PASS = kprove must succeed; FAIL = kprove must
#                   fail — the negative controls)
CLAIMS=(
  "L-EXP-DESTVAR-POS|FAIL"
  "L-EXP-DESTVAR-NEG|FAIL"
  "L-INV-ANCHOR-FRAME-EXEC|PASS"
  "L-INV-ANCHOR-FRAME-GATE|FAIL"
  "L-INV-ANCHOR-FRAME-COMMIT-REJECT|FAIL"
  "L-INV-CATALOG-FRAME-EXEC|PASS"
  "L-INV-CATALOG-FRAME-COMMIT-REJECT|FAIL"
  "L-INV-PREINIT-INIT-REFUSES|PASS"
  "L-INV-PREINIT-COMMIT-REFUSES|PASS"
  "L-INV-INIT-BASE|FAIL"
  "L-INV-EXEC-OK-STEP-POOL|FAIL"
  "L-INV-EXEC-OK-STEP-FRESH|FAIL"
  "L-INV-EXEC-REFUSAL-UNSUPPORTED|PASS"
  "L-INV-EXEC-REFUSAL-BOUNDS|PASS"
  "L-INV-EXEC-REFUSAL-SOURCE|PASS"
  "L-INV-EXEC-DISPATCH-UNSUPPORTED|PASS"
  "L-INV-EXEC-DISPATCH-BOUNDS|PASS"
  "L-INV-EXEC-DISPATCH-SOURCE|FAIL"
  "L-INV-EXEC-SOURCE-NOCOMMIT|PASS"
  "L-INV-GATE-STEP-POOL|FAIL"
  "L-INV-GATE-STEP-FRESH|FAIL"
  "L-INV-COMMIT-ACCEPT-POSTSTATE|FAIL"
  "L-NEG-CONTROL-SAFEJ|FAIL"
  "L-INV-COMMIT-REJECT-STALE-SLOT|PASS"
  "L-INV-COMMIT-REJECT-REUSED-RECEIPT|PASS"
  "L-INV-COMMIT-REJECT-FORGED-VERDICT|PASS"
  "L-INV-COMMIT-HEAD-STATE-COHERENCE|PASS"
  "L-INV-ALLPATH-REACHABILITY|FAIL"
  "L-NEG-ALLPATH-WEAKSAFEJ|FAIL"
  "L-INV-COMMITTED-PREFIX-SAFE|FAIL"
)

PASS=0; FAIL=0; GATE=0
FAILED=""
# the status CSV ACCUMULATES across resumed invocations (the header is
# written only when the file does not exist); a canonical single-pass run
# starts from an empty OUT dir
if [ ! -f "$OUT/claims-status.csv" ]; then
  echo "claim,backend,invoked,expected,raw_result,correct,log" > "$OUT/claims-status.csv"
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
  timeout "${LCLAIM_TIMEOUT:-500}" kprove "$HERE/l_proofs.k" \
    $INC \
    -d "$DEF_L" --spec-module L-PROOFS --claims "$CL" > "$LOG" 2>&1
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
  echo "$CL,haskell,yes,$EXP,$RAW,$CORR,kprove_$CL.log" >> "$OUT/claims-status.csv"
done

echo
echo "L proof ladder: $PASS correct / $FAIL gate alarms (of $(grep -c "^L-" "$OUT/claims-status.csv" 2>/dev/null || echo 0) invoked)"
echo "gate alarms (negative controls proving, or expected-proved failing): $GATE"
echo "$PASS $GATE" > "$OUT/score.txt"
exit "$GATE"
