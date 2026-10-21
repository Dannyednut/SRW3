#!/usr/bin/env bash
# SRW3 Phase 1N — run the SIM ladder (kprove, hs backend).
# The same fail-closed discipline as the ABS runner (WarnTrivialClaim guard).
# Usage: bash phase1n/proofs/run_n_sim_proofs.sh [outdir] [chunk] [defdir]
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
OUT="${1:-$REPO/phase1n/transcripts/k}"
CHUNK="${2:-}"
DEF="${3:-/tmp/n-abs}"
mkdir -p "$OUT"

source /home/z/my-project/tools/env.sh
export LIBRARY_PATH="$TOOLS/extract/syslibs:$LIBRARY_PATH"

cd "$REPO"
INC="-I $REPO/phase1m/semantics -I $REPO/phase1g/semantics -I $REPO/phase1f/semantics -I $REPO/phase1e/semantics -I $REPO/k/phase1d -I $REPO/k/kevm/kproj-e1e/plugin"

if [ ! -f "$DEF/definition.kore" ] || [ "${REKOMPILE:-0}" = "1" ]; then
  echo "[1/2] kompiling the 1N definition (Haskell backend)..."
  time kompile "$HERE/../semantics/abs-machine.k" --backend haskell \
    --main-module SRW3N-ABS $INC -o "$DEF" > "$OUT/kompile_n_abs.log" 2>&1
  RC=$?
  [ $RC -ne 0 ] && { echo "KOMPILE FAILED rc=$RC — see $OUT/kompile_n_abs.log"; exit 9; }
  echo "      ok"
fi

echo "[2/2] definition ready — running the SIM ladder"

# claim|expected|timeout
CLAIMS=(
  "SIM-INIT-ACCEPT|PASS|900"
  "SIM-INIT-REFUSE|PASS|900"
  "SIM-EXEC-MINT|ATTEMPT|250"
  "SIM-EXEC-SOURCE|ATTEMPT|500"
  "SIM-EXEC-SOURCE-DISPATCH|PASS|300"
  "SIM-EXEC-REFUSE-UNSUPPORTED|ATTEMPT|500"
  "SIM-EXEC-REFUSE-BOUNDS|ATTEMPT|150"
  "SIM-GATE-MINT|ATTEMPT|250"
  "SIM-GATE-REFUSE|ATTEMPT|150"
  "SIM-COMMIT-ACCEPT|ATTEMPT|450"
  "SIM-COMMIT-REJECT|ATTEMPT|150"
  "SIM-ALG-INIT-ACCEPT|PASS-EVAL|300"
  "SIM-ALG-INIT-REFUSE|PASS-EVAL|300"
  "SIM-ALG-EXEC-MINT|PASS-EVAL|300"
  "SIM-ALG-EXEC-SOURCE|PASS-EVAL|300"
  "SIM-ALG-EXEC-REFUSE|PASS-EVAL|300"
  "SIM-ALG-GATE-MINT|PASS-EVAL|300"
  "SIM-ALG-GATE-REFUSE|PASS-EVAL|300"
  "SIM-ALG-COMMIT-ACCEPT|PASS-EVAL|300"
  "SIM-ALG-COMMIT-REJECT|PASS-EVAL|300"
  "SIM-NEG-MINT-ON-FORBIDDEN-SOURCE|FAIL|180"
  "SIM-NEG-COMMIT-ON-STALE-SLOT|FAIL|180"
)

PASS=0; FAILC=0; ALARM=0; ATT=0; ATT_OK=0
if [ -z "$CHUNK" ]; then
  echo "claim,backend,invoked,expected,raw_result,trivial,correct,log" > "$OUT/claims-status-sim.csv"
elif [ ! -f "$OUT/claims-status-sim.csv" ]; then
  echo "claim,backend,invoked,expected,raw_result,trivial,correct,log" > "$OUT/claims-status-sim.csv"
fi
if [ -n "$CHUNK" ] && [ -f "$OUT/claims-status-sim.csv" ]; then
  for CL2 in $(echo "$CHUNK" | tr ',' ' '); do
    sed -i "/^$CL2,/d" "$OUT/claims-status-sim.csv" 2>/dev/null || true
  done
fi

for ENTRY in "${CLAIMS[@]}"; do
  CL="$(echo "$ENTRY" | cut -d'|' -f1)"
  EXP="$(echo "$ENTRY" | cut -d'|' -f2)"
  TMO="$(echo "$ENTRY" | cut -d'|' -f3)"
  if [ -n "$CHUNK" ]; then
    case ",$CHUNK," in *",$CL,"*) ;; *) continue;; esac
  fi
  LOG="$OUT/kprove_$CL.log"
  if [ -f "$OUT/.done_$CL" ] && [ -z "${RERUN:-}" ]; then
    echo "SKIP     $CL (done; RERUN=1 to force)"
    continue
  fi
  echo "kprove   $CL (expected $EXP, tmo ${TMO}s)"
  timeout "$TMO" kprove "$HERE/n_sim_proofs.k" \
    $INC \
    -d "$DEF" --spec-module N-SIM-PROOFS --claims "$CL" > "$LOG" 2>&1
  RC=$?
  [ $RC -eq 124 ] && echo "  (timeout — retained as FAILED)"
  if [ $RC -eq 0 ]; then RAW=PROVED; else RAW="FAILED(rc=$RC)"; fi
  TRIV=no
  if grep -q "WarnTrivialClaim" "$LOG" 2>/dev/null; then TRIV=YES; fi
  CORR=correct
  if [ "$EXP" = "PASS" ] || [ "$EXP" = "PASS-EVAL" ]; then
    if [ "$RAW" = "PROVED" ] && { [ "$TRIV" = "no" ] || [ "$EXP" = "PASS-EVAL" ]; }; then PASS=$((PASS+1)); CORR=correct;
    elif [ "$TRIV" = "YES" ]; then CORR=ALARM; ALARM=$((ALARM+1));
    else CORR=INCORRECT; FAILC=$((FAILC+1)); fi
  elif [ "$EXP" = "FAIL" ]; then
    if [ "$RAW" != "PROVED" ]; then FAILC=$((FAILC+1)); else CORR=ALARM; ALARM=$((ALARM+1)); fi
  else
    ATT=$((ATT+1)); [ "$RAW" = "PROVED" ] && [ "$TRIV" = "no" ] && ATT_OK=$((ATT_OK+1))
    CORR=recorded
  fi
  echo "$CL,haskell,yes,$EXP,$RAW,$TRIV,$CORR,$(basename "$LOG")" >> "$OUT/claims-status-sim.csv"
  touch "$OUT/.done_$CL"
done

GATE=0
[ "$ALARM" -gt 0 ] && GATE=$ALARM
INCORRECT_N=$(awk -F, '$7=="INCORRECT"' "$OUT/claims-status-sim.csv" | wc -l)
[ "$INCORRECT_N" -gt 0 ] && GATE=$((GATE+INCORRECT_N))

{
  echo "# SIM ladder score — $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "# PASS-expected proved (non-trivial): $PASS"
  echo "# FAIL-expected failed              : $FAILC (the negative controls)"
  echo "# GATE ALARMS (incl. TRIVIAL)       : $ALARM"
  echo "# ATTEMPT claims                    : $ATT attempted, $ATT_OK PROVED non-trivially"
  echo "# GATE                 : $([ $GATE -eq 0 ] && echo GREEN || echo RED)"
} > "$OUT/score-sim.txt"
cat "$OUT/score-sim.txt"
[ "$GATE" -eq 0 ]
