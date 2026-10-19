#!/usr/bin/env bash
# SRW3 Phase 1M — run the Workstream-B proof ladder (kprove, Haskell backend).
#
# Two definitions:
#   DEF_KB  — j_invariant_m2.k (the M2 hash-redirect machine + the UNCHANGED
#             1L invariant definitions) — the KB-* claims;
#   DEF_OLD — kb_old_proofs.k over the M1 machine (NO redirect) — the fresh
#             OLD witness KB-OLD-CEIL-SYMBOLIC (EXPECTED FAIL with the
#             #Ceil residual; pairs with kprove_KB-CEIL-SYMBOLIC.log).
#
# Scoring convention (the R3 discipline, extended): every claim is invoked
# EXACTLY ONCE per canonical run with its raw exit code and retained log;
# raw results are never relabeled.  Expected outcomes:
#   PASS-expected : KB-VEC-ABC, KB-VEC-TWOBLOCK, KB-INIT-BASE-HEAD
#   FAIL-expected : KB-EXP-NO-RULE-STUCK, KB-EXP-NESTED-STUCK, KB-NEG-INJ,
#                   KB-NEG-WEAKSAFEJ, KB-OLD-CEIL-SYMBOLIC, KB-OLD-INIT-BASE
#                   (the DISCRIMINATING B1 pair: KB-OLD-INIT-BASE on M1
#                   reproduces the retained 1L #Ceil residual; KB-INIT-BASE
#                   on M2 is its NEW counterpart)
#   ATTEMPT       : ... KB-OLD-INIT-BASE-HEAD (mechanics: the bare
#                   head-advance shape does not surface the hook Ceil on M1)
#                   (a PROOF of a negative control is a GATE ALARM)
#   ATTEMPT       : KB-INIT-BASE, KB-EXEC-OK-STEP-POOL, KB-EXEC-OK-STEP-FRESH,
#                   KB-GATE-STEP-POOL, KB-GATE-STEP-FRESH,
#                   KB-COMMIT-ACCEPT-POSTSTATE — the 1L blocked claims
#                   re-run verbatim over M2; either resolution is recorded
#                   with its residual; never relabeled.
# Usage: bash phase1m/proofs/run_kb_proofs.sh [outdir] [chunk]
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
OUT="${1:-$REPO/phase1m/transcripts/k}"
CHUNK="${2:-}"
mkdir -p "$OUT"

source /home/z/my-project/tools/env.sh
export LIBRARY_PATH="$TOOLS/extract/syslibs:$LIBRARY_PATH"

cd "$REPO"
DEF_KB=/tmp/kb-m2-hs
DEF_OLD=/tmp/kb-old-m1-hs
INC="-I $REPO/phase1g/semantics -I $REPO/phase1f/semantics -I $REPO/phase1e/semantics -I $REPO/k/phase1d -I $REPO/k/kevm/kproj-e1e/plugin"

if [ ! -f "$DEF_KB/definition.kore" ] || [ "${REKOMPILE:-0}" = "1" ]; then
  echo "[1/3] kompiling the M2 invariant definition (Haskell backend)..."
  time kompile "$HERE/../semantics/j_invariant_m2.k" --backend haskell \
    --main-module SRW3L-INVARIANT-M2 $INC -o "$DEF_KB" > "$OUT/kompile_kb.log" 2>&1
  RC=$?
  [ $RC -ne 0 ] && { echo "KOMPILE (KB) FAILED rc=$RC — see $OUT/kompile_kb.log"; exit 9; }
  echo "      ok"
fi
if [ ! -f "$DEF_OLD/definition.kore" ] || [ "${REKOMPILE:-0}" = "1" ]; then
  echo "[2/3] kompiling the OLD (M1) machine definition (Haskell backend)..."
  time kompile "$HERE/../semantics/srw3closure-j-m1.k" --backend haskell \
    --main-module SRW3CLOSURE-J-M1 $INC -o "$DEF_OLD" > "$OUT/kompile_old.log" 2>&1
  RC=$?
  [ $RC -ne 0 ] && { echo "KOMPILE (OLD) FAILED rc=$RC — see $OUT/kompile_old.log"; exit 9; }
  echo "      ok"
fi

echo "[3/3] definition(s) ready — running the KB ladder"

# claim|deftag|expected|timeout   (deftag: kb = M2 invariant def; old = M1)
CLAIMS=(
  "KB-VEC-ABC|kb|PASS|600"
  "KB-VEC-TWOBLOCK|kb|PASS|600"
  "KB-EXP-NO-RULE-STUCK|kb|FAIL|600"
  "KB-EXP-NESTED-STUCK|kb|FAIL|600"
  "KB-NEG-INJ|kb|FAIL|600"
  "KB-NEG-WEAKSAFEJ|kb|FAIL|900"
  "KB-INIT-BASE|kb|ATTEMPT|900"
  "KB-INIT-BASE-HEAD|kb|PASS|900"
  "KB-EXEC-OK-STEP-POOL|kb|ATTEMPT|900"
  "KB-EXEC-OK-STEP-FRESH|kb|ATTEMPT|900"
  "KB-GATE-STEP-POOL|kb|ATTEMPT|1200"
  "KB-GATE-STEP-FRESH|kb|ATTEMPT|1200"
  "KB-COMMIT-ACCEPT-POSTSTATE|kb|ATTEMPT|1200"
  "KB-OLD-CEIL-SYMBOLIC|old|FAIL|600"
  "KB-OLD-INIT-BASE|old|FAIL|900"
  "KB-OLD-INIT-BASE-HEAD|old|ATTEMPT|900"
)

PASS=0; FAILC=0; ALARM=0; ATT=0; ATT_OK=0
echo "claim,backend,invoked,expected,raw_result,correct,log" > "$OUT/claims-status-kb.csv"

for ENTRY in "${CLAIMS[@]}"; do
  CL="$(echo "$ENTRY" | cut -d'|' -f1)"
  DEFTAG="$(echo "$ENTRY" | cut -d'|' -f2)"
  EXP="$(echo "$ENTRY" | cut -d'|' -f3)"
  TMO="$(echo "$ENTRY" | cut -d'|' -f4)"
  if [ -n "$CHUNK" ]; then
    case ",$CHUNK," in *",$CL,"*) ;; *) continue;; esac
  fi
  DEF="$DEF_KB"; SRC="$HERE/kb_proofs.k"; SPEC=KB-PROOFS
  if [ "$DEFTAG" = "old" ]; then DEF="$DEF_OLD"; SRC="$HERE/kb_old_proofs.k"; SPEC=KB-OLD-PROOFS; fi
  LOG="$OUT/kprove_$CL.log"
  if [ -f "$OUT/.done_$CL" ] && [ -z "${RERUN:-}" ]; then
    echo "SKIP     $CL (done; RERUN=1 to force)"
    continue
  fi
  echo "kprove   $CL (expected $EXP, tmo ${TMO}s)"
  timeout "$TMO" kprove "$SRC" \
    $INC \
    -d "$DEF" --spec-module "$SPEC" --claims "$CL" > "$LOG" 2>&1
  RC=$?
  [ $RC -eq 124 ] && echo "  (timeout — retained as FAILED)"
  if [ $RC -eq 0 ]; then RAW=PROVED; else RAW="FAILED(rc=$RC)"; fi
  CORR=correct
  if [ "$EXP" = "PASS" ]; then
    if [ "$RAW" = "PROVED" ]; then PASS=$((PASS+1)); else CORR=INCORRECT; FAILC=$((FAILC+1)); fi
  elif [ "$EXP" = "FAIL" ]; then
    if [ "$RAW" != "PROVED" ]; then FAILC=$((FAILC+1)); else CORR=ALARM; ALARM=$((ALARM+1)); fi
  else # ATTEMPT
    ATT=$((ATT+1))
    if [ "$RAW" = "PROVED" ]; then ATT_OK=$((ATT_OK+1)); fi
    CORR="recorded"
  fi
  echo "$CL,haskell,yes,$EXP,$RAW,$CORR,$(basename "$LOG")" >> "$OUT/claims-status-kb.csv"
  touch "$OUT/.done_$CL"
done

# gate: PASS-expected must prove; FAIL-expected must fail (no alarms)
GATE=0
[ "$ALARM" -gt 0 ] && GATE=1
INCORRECT_N=$(awk -F, '$5=="PROVED" && $4=="PASS" {next} {if ($6=="INCORRECT") c++} END {print c+0}' "$OUT/claims-status-kb.csv")
[ "$INCORRECT_N" -gt 0 ] && GATE=$((GATE+INCORRECT_N))

ATT_PROVED=$(awk -F, '$4=="ATTEMPT" && $5=="PROVED"' "$OUT/claims-status-kb.csv" | wc -l)
{
  echo "# KB ladder score — $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "# PASS-expected proved : $PASS"
  echo "# FAIL-expected failed : $FAILC (negative controls + OLD witness)"
  echo "# GATE ALARMS          : $ALARM  (a proved negative control)"
  echo "# ATTEMPT claims       : $ATT attempted, $ATT_PROVED PROVED over M2"
  echo "# GATE                 : $([ $GATE -eq 0 ] && echo GREEN || echo RED)"
  echo "#"
  echo "# The B1 OLD/NEW pair: kprove_KB-OLD-CEIL-SYMBOLIC.log (M1, #Ceil"
  echo "# residual, EXPECTED FAIL) vs kprove_KB-CEIL-SYMBOLIC.log (M2, PROVED)."
} > "$OUT/score-kb.txt"
cat "$OUT/score-kb.txt"
[ "$GATE" -eq 0 ]
