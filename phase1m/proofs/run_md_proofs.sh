#!/usr/bin/env bash
# SRW3 Phase 1M — run the Workstream-D induction ladder (kprove, hs backend).
#
# Definition: j_invariant_m3.k (the UNCHANGED 1L JInv definitions over the
# M3 machine).  The genuine universal-induction attempt over M3: the step
# partition (the 1L PROVED-class lemmas re-run + the NEW gate-refusal
# class), the base, the arbitrary-continuation composition, the
# committed-prefix corollary, and the vacuity controls.  Every raw result
# is recorded with its log; nothing is relabeled.
# Usage: bash phase1m/proofs/run_md_proofs.sh [outdir] [chunk]
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
OUT="${1:-$REPO/phase1m/transcripts/k}"
CHUNK="${2:-}"
mkdir -p "$OUT"

source /home/z/my-project/tools/env.sh
export LIBRARY_PATH="$TOOLS/extract/syslibs:$LIBRARY_PATH"

cd "$REPO"
DEF_MD=/tmp/md-m3-hs
INC="-I $REPO/phase1g/semantics -I $REPO/phase1f/semantics -I $REPO/phase1e/semantics -I $REPO/k/phase1d -I $REPO/k/kevm/kproj-e1e/plugin"

if [ ! -f "$DEF_MD/definition.kore" ] || [ "${REKOMPILE:-0}" = "1" ]; then
  echo "[1/2] kompiling the M3 invariant definition (Haskell backend)..."
  time kompile "$HERE/../semantics/j_invariant_m3.k" --backend haskell \
    --main-module SRW3L-INVARIANT-M3 $INC -o "$DEF_MD" > "$OUT/kompile_md.log" 2>&1
  RC=$?
  [ $RC -ne 0 ] && { echo "KOMPILE (MD) FAILED rc=$RC — see $OUT/kompile_md.log"; exit 9; }
  echo "      ok"
fi

echo "[2/2] definition ready — running the MD ladder"

# claim|expected|timeout   (PASS/FAIL are DESIGNED outcomes; ATTEMPT = the
# genuine attempt whose outcome is recorded, never relabeled)
CLAIMS=(
  "MD-INV-ANCHOR-FRAME-EXEC|PASS|900"
  "MD-INV-CATALOG-FRAME-EXEC|PASS|900"
  "MD-INV-PREINIT-INIT-REFUSES|PASS|900"
  "MD-INV-PREINIT-COMMIT-REFUSES|PASS|900"
  "MD-INV-EXEC-REFUSAL-SOURCE|PASS|900"
  "MD-INV-COMMIT-REJECT-STALE-SLOT|PASS|1200"
  "MD-INV-GATE-REFUSAL-PRESERVES|PASS|900"
  "MD-INV-INIT-BASE|ATTEMPT|1800"
  "MD-INV-ALLPATH-REACHABILITY|ATTEMPT|1800"
  "MD-INV-COMMITTED-PREFIX-SAFE|ATTEMPT|1200"
  "MD-NEG-CONTROL-SAFEJ|FAIL|1800"
)

PASS=0; FAILC=0; ALARM=0; ATT=0; ATT_OK=0
echo "claim,backend,invoked,expected,raw_result,correct,log" > "$OUT/claims-status-md.csv"

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
  timeout "$TMO" kprove "$HERE/md_proofs.k" \
    $INC \
    -d "$DEF_MD" --spec-module MD-PROOFS --claims "$CL" > "$LOG" 2>&1
  RC=$?
  [ $RC -eq 124 ] && echo "  (timeout — retained as FAILED)"
  if [ $RC -eq 0 ]; then RAW=PROVED; else RAW="FAILED(rc=$RC)"; fi
  CORR=correct
  if [ "$EXP" = "PASS" ]; then
    if [ "$RAW" = "PROVED" ]; then PASS=$((PASS+1)); else CORR=INCORRECT; FAILC=$((FAILC+1)); fi
  elif [ "$EXP" = "FAIL" ]; then
    if [ "$RAW" != "PROVED" ]; then FAILC=$((FAILC+1)); else CORR=ALARM; ALARM=$((ALARM+1)); fi
  else
    ATT=$((ATT+1)); [ "$RAW" = "PROVED" ] && ATT_OK=$((ATT_OK+1))
    CORR=recorded
  fi
  echo "$CL,haskell,yes,$EXP,$RAW,$CORR,$(basename "$LOG")" >> "$OUT/claims-status-md.csv"
  touch "$OUT/.done_$CL"
done

GATE=0
[ "$ALARM" -gt 0 ] && GATE=1
INCORRECT_N=$(awk -F, '$6=="INCORRECT"' "$OUT/claims-status-md.csv" | wc -l)
[ "$INCORRECT_N" -gt 0 ] && GATE=$((GATE+INCORRECT_N))

{
  echo "# MD ladder score — $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "# PASS-expected proved : $PASS  (the step-partition family over M3)"
  echo "# FAIL-expected failed : $FAILC (the vacuity controls)"
  echo "# GATE ALARMS          : $ALARM"
  echo "# ATTEMPT claims       : $ATT attempted, $ATT_OK PROVED"
  echo "# GATE                 : $([ $GATE -eq 0 ] && echo GREEN || echo RED)"
  echo "#"
  echo "# The universal reachable-committed-state theorem is MECHANIZED"
  echo "# IFF MD-INV-ALLPATH-REACHABILITY (and the committed-prefix"
  echo "# corollary) are PROVED.  Whatever this score says, the phase"
  echo "# disposition follows the raw results — never relabeled."
} > "$OUT/score-md.txt"
cat "$OUT/score-md.txt"
[ "$GATE" -eq 0 ]
