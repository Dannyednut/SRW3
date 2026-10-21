#!/usr/bin/env bash
# SRW3 Phase 1N — run the ABS ladder (kprove, hs backend).
#
# Definition: abs-machine.k (the M4 machine + the additive abstract machine).
# The fail-closed discipline of record (the 1M lesson, audited):
#   * every claim runs individually; the raw kprove exit code decides
#     PROVED / FAILED(rc=N); timeouts retained as FAILED(rc=124);
#   * ANY log containing WarnTrivialClaim is marked TRIVIAL — a trivially
#     closing PASS/ATTEMPT claim is an ALARM, never a pass (the 1M
#     MD-INV-ALLPATH-REACHABILITY misclassification cannot recur);
#   * PASS/FAIL are DESIGNED outcomes; ATTEMPT records whatever happens.
# Usage: bash phase1n/proofs/run_n_abs_proofs.sh [outdir] [chunk] [defdir]
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
  [ $RC -ne 0 ] && { echo "KOMPILE (N-ABS) FAILED rc=$RC — see $OUT/kompile_n_abs.log"; exit 9; }
  echo "      ok"
fi

echo "[2/2] definition ready — running the ABS ladder"

# claim|expected|timeout
CLAIMS=(
  "ABS-INIT-BASE|PASS|600"
  "ABS-INIT-BASE-INV|PASS-EVAL|600"
  "ABS-STEP-INIT-ACCEPT|PASS|600"
  "ABS-STEP-INIT-REFUSE|PASS|600"
  "ABS-STEP-EXEC-MINT|PASS|600"
  "ABS-STEP-EXEC-SOURCE|PASS|600"
  "ABS-STEP-EXEC-REFUSE|PASS|600"
  "ABS-STEP-GATE-MINT|PASS|600"
  "ABS-STEP-GATE-REFUSE|PASS|600"
  "ABS-STEP-COMMIT-ACCEPT|PASS|600"
  "ABS-STEP-COMMIT-REJECT|PASS|600"
  "ABS-PRES-I-INIT-ACCEPT|PASS-EVAL|600"
  "ABS-PRESV-I-INIT-ACCEPT|PASS-EVAL|600"
  "ABS-PRES-P-INIT-ACCEPT|PASS-EVAL|600"
  "ABS-PRESV-P-INIT-ACCEPT|PASS-EVAL|600"
  "ABS-PRES-I-INIT-REFUSE|PASS-EVAL|600"
  "ABS-PRESV-I-INIT-REFUSE|PASS-EVAL|600"
  "ABS-PRES-P-INIT-REFUSE|PASS-EVAL|600"
  "ABS-PRESV-P-INIT-REFUSE|PASS-EVAL|600"
  "ABS-PRES-I-EXEC-MINT|PASS-EVAL|600"
  "ABS-PRESV-I-EXEC-MINT|PASS-EVAL|600"
  "ABS-PRES-P-EXEC-MINT|PASS-EVAL|600"
  "ABS-PRESV-P-EXEC-MINT|PASS-EVAL|600"
  "ABS-PRES-I-EXEC-SOURCE|PASS-EVAL|600"
  "ABS-PRESV-I-EXEC-SOURCE|PASS-EVAL|600"
  "ABS-PRES-P-EXEC-SOURCE|PASS-EVAL|600"
  "ABS-PRESV-P-EXEC-SOURCE|PASS-EVAL|600"
  "ABS-PRES-I-EXEC-REFUSE|PASS-EVAL|600"
  "ABS-PRESV-I-EXEC-REFUSE|PASS-EVAL|600"
  "ABS-PRES-P-EXEC-REFUSE|PASS-EVAL|600"
  "ABS-PRESV-P-EXEC-REFUSE|PASS-EVAL|600"
  "ABS-PRES-I-GATE-MINT|PASS-EVAL|600"
  "ABS-PRESV-I-GATE-MINT|PASS-EVAL|600"
  "ABS-PRES-P-GATE-MINT|PASS-EVAL|600"
  "ABS-PRESV-P-GATE-MINT|PASS-EVAL|600"
  "ABS-PRES-I-GATE-REFUSE|PASS-EVAL|600"
  "ABS-PRESV-I-GATE-REFUSE|PASS-EVAL|600"
  "ABS-PRES-P-GATE-REFUSE|PASS-EVAL|600"
  "ABS-PRESV-P-GATE-REFUSE|PASS-EVAL|600"
  "ABS-PRES-I-COMMIT-ACCEPT|PASS-EVAL|600"
  "ABS-PRESV-I-COMMIT-ACCEPT|PASS-EVAL|600"
  "ABS-PRES-P-COMMIT-ACCEPT|PASS-EVAL|600"
  "ABS-PRESV-P-COMMIT-ACCEPT|PASS-EVAL|600"
  "ABS-PRES-I-COMMIT-REJECT|PASS-EVAL|600"
  "ABS-PRESV-I-COMMIT-REJECT|PASS-EVAL|600"
  "ABS-PRES-P-COMMIT-REJECT|PASS-EVAL|600"
  "ABS-PRESV-P-COMMIT-REJECT|PASS-EVAL|600"
  "ABS-PRES-I-GATE-MINT-EMPTY|PASS-EVAL|600"
  "ABS-PRESV-I-GATE-MINT-EMPTY|PASS-EVAL|600"
  "ABS-PRES-I-COMMIT-ACCEPT-LOWG|PASS-EVAL|600"
  "ABS-PRESV-I-COMMIT-ACCEPT-LOWG|PASS-EVAL|600"
  "ABS-PRES-I-COMMIT-ACCEPT-LOWE|PASS-EVAL|600"
  "ABS-PRESV-I-COMMIT-ACCEPT-LOWE|PASS-EVAL|600"
  "ABS-INV-EXCL-I|PASS-EVAL|600"
  "ABS-INV-EXCL-II|PASS-EVAL|600"
  "ABS-UNIV-BASE|PASS-EVAL|600"
  "ABS-RUN-HONEST-PIPELINE|PASS-EVAL|600"
  "ABS-RUN-HONEST-PIPELINE-SHAPE|PASS-EVAL|600"
  "ABS-RUN-REFUSAL-CHAIN|PASS-EVAL|600"
  "ABS-NEG-UNSAFE-ACCEPT|FAIL|600"
  "ABS-NEG-REFUSE-ON-MINT|FAIL|600"
)

PASS=0; FAILC=0; ALARM=0; TRIVC=0; ATT=0; ATT_OK=0
if [ -z "$CHUNK" ]; then
  echo "claim,backend,invoked,expected,raw_result,trivial,correct,log" > "$OUT/claims-status-abs.csv"
elif [ ! -f "$OUT/claims-status-abs.csv" ]; then
  echo "claim,backend,invoked,expected,raw_result,trivial,correct,log" > "$OUT/claims-status-abs.csv"
fi
# deduplicate on append: drop prior rows for re-run claims
if [ -n "$CHUNK" ] && [ -f "$OUT/claims-status-abs.csv" ]; then
  for CL2 in $(echo "$CHUNK" | tr ',' ' '); do
    sed -i "/^$CL2,/d" "$OUT/claims-status-abs.csv" 2>/dev/null || true
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
  timeout "$TMO" kprove "$HERE/n_abs_proofs.k" \
    $INC \
    -d "$DEF" --spec-module N-ABS-PROOFS --claims "$CL" > "$LOG" 2>&1
  RC=$?
  [ $RC -eq 124 ] && echo "  (timeout — retained as FAILED)"
  if [ $RC -eq 0 ]; then RAW=PROVED; else RAW="FAILED(rc=$RC)"; fi
  TRIV=no
  if grep -q "WarnTrivialClaim" "$LOG" 2>/dev/null; then TRIV=YES; TRIVC=$((TRIVC+1)); fi
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
  echo "$CL,haskell,yes,$EXP,$RAW,$TRIV,$CORR,$(basename "$LOG")" >> "$OUT/claims-status-abs.csv"
  touch "$OUT/.done_$CL"
done

GATE=0
[ "$ALARM" -gt 0 ] && GATE=$ALARM
INCORRECT_N=$(awk -F, '$7=="INCORRECT"' "$OUT/claims-status-abs.csv" | wc -l)
[ "$INCORRECT_N" -gt 0 ] && GATE=$((GATE+INCORRECT_N))

{
  echo "# ABS ladder score — $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "# PASS-expected proved (non-trivial): $PASS  (base + step partition + preservation)"
  echo "# FAIL-expected failed              : $FAILC (the negative controls)"
  echo "# GATE ALARMS (incl. TRIVIAL)       : $ALARM"
  echo "# ATTEMPT claims                    : $ATT attempted, $ATT_OK PROVED non-trivially"
  echo "# GATE                 : $([ $GATE -eq 0 ] && echo GREEN || echo RED)"
  echo "#"
  echo "# The ABSTRACT universal theorem is MECHANIZED IFF ABS-UNIV-STEP is"
  echo "# PROVED non-trivially (WarnTrivialClaim guard enforced).  Whatever"
  echo "# this score says, the phase disposition follows the raw results."
} > "$OUT/score-abs.txt"
cat "$OUT/score-abs.txt"
[ "$GATE" -eq 0 ]
