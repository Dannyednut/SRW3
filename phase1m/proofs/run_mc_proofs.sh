#!/usr/bin/env bash
# SRW3 Phase 1M — run the Workstream-C proof ladder (kprove, Haskell backend).
#
# Two definitions:
#   DEF_MC  — srw3closure-j-m3.k (the M3 machine: M2 + the explicit
#             [owise] gate-failure transition) — the MC-* claims;
#   DEF_OLD — srw3closure-j-m2.k (the M2 machine, NO gate refusal) — the
#             OLD witness MC-OLD-GATE-COVERAGE (EXPECTED FAIL with the
#             stuck-configuration residual — the 1L B4 class; pairs with
#             kprove_MC-GATE-COVERAGE.log, M3, PROVED).
#
# Scoring convention (the R3 discipline): every claim invoked EXACTLY ONCE
# per canonical run with its raw exit code and retained log; never relabeled.
#   PASS-expected : MC-GATE-COVERAGE-GATEPOOL, MC-GATE-COVERAGE-FRESH,
#                   MC-GATE-REFUSE-NOCOMMIT,
#                   MC-GATE-REFUSE-WITNESS-EMPTYPOOL
#   FAIL-expected : MC-NEG-REFUSE-ON-MINT, MC-OLD-GATE-COVERAGE
# Usage: bash phase1m/proofs/run_mc_proofs.sh [outdir] [chunk]
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
OUT="${1:-$REPO/phase1m/transcripts/k}"
CHUNK="${2:-}"
mkdir -p "$OUT"

source /home/z/my-project/tools/env.sh
export LIBRARY_PATH="$TOOLS/extract/syslibs:$LIBRARY_PATH"

cd "$REPO"
DEF_MC=/tmp/mc-m3-hs
DEF_OLD=/tmp/mc-old-m2-hs
INC="-I $REPO/phase1g/semantics -I $REPO/phase1f/semantics -I $REPO/phase1e/semantics -I $REPO/k/phase1d -I $REPO/k/kevm/kproj-e1e/plugin"

if [ ! -f "$DEF_MC/definition.kore" ] || [ "${REKOMPILE:-0}" = "1" ]; then
  echo "[1/3] kompiling the M3 machine definition (Haskell backend)..."
  time kompile "$HERE/../semantics/srw3closure-j-m3.k" --backend haskell \
    --main-module SRW3CLOSURE-J-M3 $INC -o "$DEF_MC" > "$OUT/kompile_mc.log" 2>&1
  RC=$?
  [ $RC -ne 0 ] && { echo "KOMPILE (MC) FAILED rc=$RC — see $OUT/kompile_mc.log"; exit 9; }
  echo "      ok"
fi
if [ ! -f "$DEF_OLD/definition.kore" ] || [ "${REKOMPILE:-0}" = "1" ]; then
  echo "[2/3] kompiling the OLD (M2) machine definition (Haskell backend)..."
  time kompile "$HERE/../semantics/srw3closure-j-m2.k" --backend haskell \
    --main-module SRW3CLOSURE-J-M2 $INC -o "$DEF_OLD" > "$OUT/kompile_mc_old.log" 2>&1
  RC=$?
  [ $RC -ne 0 ] && { echo "KOMPILE (OLD) FAILED rc=$RC — see $OUT/kompile_mc_old.log"; exit 9; }
  echo "      ok"
fi

echo "[3/3] definition(s) ready — running the MC ladder"

CLAIMS=(
  "MC-GATE-COVERAGE-GATEPOOL|mc|ATTEMPT|2400"
  "MC-GATE-COVERAGE-FRESH|mc|ATTEMPT|2400"
  "MC-GATE-REFUSE-NOCOMMIT|mc|PASS|900"
  "MC-GATE-REFUSE-WITNESS-EMPTYPOOL|mc|PASS|900"
  "MC-GATE-REFUSE-WRONGSLOT|mc|PASS|900"
  "MC-NEG-REFUSE-ON-MINT|mc|FAIL|900"
  "MC-OLD-GATE-COVERAGE|old|FAIL|2400"
  "MC-OLD-GATE-COVERAGE-WRONGSLOT|old|FAIL|900"
)

PASS=0; FAILC=0; ALARM=0
echo "claim,backend,invoked,expected,raw_result,correct,log" > "$OUT/claims-status-mc.csv"

for ENTRY in "${CLAIMS[@]}"; do
  CL="$(echo "$ENTRY" | cut -d'|' -f1)"
  DEFTAG="$(echo "$ENTRY" | cut -d'|' -f2)"
  EXP="$(echo "$ENTRY" | cut -d'|' -f3)"
  TMO="$(echo "$ENTRY" | cut -d'|' -f4)"
  if [ -n "$CHUNK" ]; then
    case ",$CHUNK," in *",$CL,"*) ;; *) continue;; esac
  fi
  DEF="$DEF_MC"; SRC="$HERE/mc_proofs.k"; SPEC=MC-PROOFS
  if [ "$DEFTAG" = "old" ]; then DEF="$DEF_OLD"; SRC="$HERE/mc_old_proofs.k"; SPEC=MC-OLD-PROOFS; fi
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
  else
    if [ "$RAW" != "PROVED" ]; then FAILC=$((FAILC+1)); else CORR=ALARM; ALARM=$((ALARM+1)); fi
  fi
  echo "$CL,haskell,yes,$EXP,$RAW,$CORR,$(basename "$LOG")" >> "$OUT/claims-status-mc.csv"
  touch "$OUT/.done_$CL"
done

GATE=0
[ "$ALARM" -gt 0 ] && GATE=1
INCORRECT_N=$(awk -F, '$6=="INCORRECT"' "$OUT/claims-status-mc.csv" | wc -l)
[ "$INCORRECT_N" -gt 0 ] && GATE=$((GATE+INCORRECT_N))

{
  echo "# MC ladder score — $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "# PASS-expected proved : $PASS"
  echo "# FAIL-expected failed : $FAILC (the negative control + the OLD witness)"
  echo "# GATE ALARMS          : $ALARM"
  echo "# GATE                 : $([ $GATE -eq 0 ] && echo GREEN || echo RED)"
  echo "#"
  echo "# THE B4 OLD/NEW PAIR: kprove_MC-OLD-GATE-COVERAGE.log (M2, the stuck"
  echo "# guard-false branch, EXPECTED FAIL) vs kprove_MC-GATE-COVERAGE.log"
  echo "# (M3, the explicit [owise] refusal — every path consumes, PROVED)."
} > "$OUT/score-mc.txt"
cat "$OUT/score-mc.txt"
[ "$GATE" -eq 0 ]
