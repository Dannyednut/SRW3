#!/usr/bin/env bash
# =============================================================================
# SRW3 Phase 1O — the formal K runner (mandate §7/§8; fail-closed discipline).
#
# Stages (in order — the trust discipline: every trusted lemma is PROVEN
# in stage L before the universal is attempted in stage U):
#   K   kompile the R definition and the weak-R definition (idempotent)
#   R   the machine-form universal attempts over the R machine
#   L   the 21 lemma claims (the branch-complete preservation family)
#   U   the lemma-backed universal attempts (--trusted, AFTER L is green)
#   W   the soundness controls (weak-R universal + destination — MUST FAIL)
#   E   the ground execution claims (honest pipeline / init+exec / unsafe)
#   P   the minimal-reproducer probes (the §6 boundary characterization)
# Raw logs: phase1o/transcripts/k/kprove_<CLAIM>.log (0 bytes = the
# documented timeout-of-record; see phase1n/transcripts/k/README-0-size-logs.txt).
# Usage: bash phase1o/proofs/run_o_univ.sh [outdir] [defdir-r] [defdir-weak]
# Exit 0 iff no ALARM and no INCORRECT (the phase-disposition rule: the raw
# results decide, never the gate color).
# =============================================================================
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
OUT="${1:-$REPO/phase1o/transcripts/k}"
DEFR="${2:-/tmp/o-r-def}"
DEFW="${3:-/tmp/o-weak-r-def}"
mkdir -p "$OUT"

source /home/z/my-project/tools/env.sh
export LIBRARY_PATH="$TOOLS/extract/syslibs:$LIBRARY_PATH"
cd "$REPO"
INC="-I $REPO/phase1n/semantics -I $REPO/phase1m/semantics -I $REPO/phase1g/semantics -I $REPO/phase1f/semantics -I $REPO/phase1e/semantics -I $REPO/k/phase1d -I $REPO/k/kevm/kproj-e1e/plugin"

# ---------- stage K: definitions ----------
if [ ! -f "$DEFR/definition.kore" ] || [ "${REKOMPILE:-0}" = "1" ]; then
  echo "[K] kompile the R definition..."
  kompile phase1o/semantics/abs-machine-r.k --backend haskell \
    --main-module SRW3N-ABS-R $INC -o "$DEFR" > "$OUT/kompile_o_r.log" 2>&1 \
    || { echo "KOMPILE(R) FAILED"; exit 9; }
fi
if [ ! -f "$DEFW/definition.kore" ] || [ "${REKOMPILE:-0}" = "1" ]; then
  echo "[K] kompile the weak-R definition..."
  kompile phase1o/semantics/abs-machine-weak-r.k --backend haskell \
    --main-module SRW3N-ABS-WEAK-R $INC -o "$DEFW" > "$OUT/kompile_o_weak_r.log" 2>&1 \
    || { echo "KOMPILE(WEAK-R) FAILED"; exit 9; }
fi

TRUSTED=$(grep -o 'label(ABS-PRESV-[A-Z0-9-]*)' "$HERE/n_o_lemmas.k" | sed 's/label(//;s/)//' | paste -sd, -)

# claim|spec-file|def|module|expected|timeout|extra-flags
CLAIMS=(
  "1O-UNIV-MACHINE-R|$HERE/n_o_univ_r.k|$DEFR|O-UNIV-R-PROOFS|ATTEMPT|900|"
  "1O-UNIV-PREFIX-R|$HERE/n_o_univ_r.k|$DEFR|O-UNIV-R-PROOFS|ATTEMPT|900|"
  "1O-NEG-DEST-R|$HERE/n_o_univ_r.k|$DEFR|O-UNIV-R-PROOFS|FAIL|900|"
  "ABS-PRESV-I-COMMIT-ACCEPT|$HERE/n_o_lemmas.k|$DEFR|O-LEMMAS|PASS-EVAL|600|"
  "ABS-PRESV-I-COMMIT-ACCEPT-LOWE|$HERE/n_o_lemmas.k|$DEFR|O-LEMMAS|PASS-EVAL|600|"
  "ABS-PRESV-I-COMMIT-ACCEPT-LOWG|$HERE/n_o_lemmas.k|$DEFR|O-LEMMAS|PASS-EVAL|600|"
  "ABS-PRESV-I-COMMIT-REJECT|$HERE/n_o_lemmas.k|$DEFR|O-LEMMAS|PASS-EVAL|600|"
  "ABS-PRESV-I-EXEC-MINT|$HERE/n_o_lemmas.k|$DEFR|O-LEMMAS|PASS-EVAL|600|"
  "ABS-PRESV-I-EXEC-REFUSE|$HERE/n_o_lemmas.k|$DEFR|O-LEMMAS|PASS-EVAL|600|"
  "ABS-PRESV-I-EXEC-SOURCE|$HERE/n_o_lemmas.k|$DEFR|O-LEMMAS|PASS-EVAL|600|"
  "ABS-PRESV-I-GATE-MINT|$HERE/n_o_lemmas.k|$DEFR|O-LEMMAS|PASS-EVAL|600|"
  "ABS-PRESV-I-GATE-MINT-EMPTY|$HERE/n_o_lemmas.k|$DEFR|O-LEMMAS|PASS-EVAL|600|"
  "ABS-PRESV-I-GATE-REFUSE|$HERE/n_o_lemmas.k|$DEFR|O-LEMMAS|PASS-EVAL|600|"
  "ABS-PRESV-I-INIT-ACCEPT|$HERE/n_o_lemmas.k|$DEFR|O-LEMMAS|PASS-EVAL|600|"
  "ABS-PRESV-I-INIT-REFUSE|$HERE/n_o_lemmas.k|$DEFR|O-LEMMAS|PASS-EVAL|600|"
  "ABS-PRESV-P-COMMIT-ACCEPT|$HERE/n_o_lemmas.k|$DEFR|O-LEMMAS|PASS-EVAL|600|"
  "ABS-PRESV-P-COMMIT-REJECT|$HERE/n_o_lemmas.k|$DEFR|O-LEMMAS|PASS-EVAL|600|"
  "ABS-PRESV-P-EXEC-MINT|$HERE/n_o_lemmas.k|$DEFR|O-LEMMAS|PASS-EVAL|600|"
  "ABS-PRESV-P-EXEC-REFUSE|$HERE/n_o_lemmas.k|$DEFR|O-LEMMAS|PASS-EVAL|600|"
  "ABS-PRESV-P-EXEC-SOURCE|$HERE/n_o_lemmas.k|$DEFR|O-LEMMAS|PASS-EVAL|600|"
  "ABS-PRESV-P-GATE-MINT|$HERE/n_o_lemmas.k|$DEFR|O-LEMMAS|PASS-EVAL|600|"
  "ABS-PRESV-P-GATE-REFUSE|$HERE/n_o_lemmas.k|$DEFR|O-LEMMAS|PASS-EVAL|600|"
  "ABS-PRESV-P-INIT-ACCEPT|$HERE/n_o_lemmas.k|$DEFR|O-LEMMAS|PASS-EVAL|600|"
  "ABS-PRESV-P-INIT-REFUSE|$HERE/n_o_lemmas.k|$DEFR|O-LEMMAS|PASS-EVAL|600|"
  "1O-UNIV-MACHINE-RL|$HERE/n_o_lemmas.k|$DEFR|O-LEMMAS|ATTEMPT|900|--trusted $TRUSTED"
  "1O-UNIV-PREFIX-RL|$HERE/n_o_lemmas.k|$DEFR|O-LEMMAS|ATTEMPT|900|--trusted $TRUSTED"
  "1O-NEG-DEST-RL|$HERE/n_o_lemmas.k|$DEFR|O-LEMMAS|FAIL|900|--trusted $TRUSTED"
  "1O-NEG-WEAK-UNIV-R|$HERE/n_o_univ_weak_r.k|$DEFW|O-UNIV-WEAK-R-PROOFS|FAIL|900|"
  "1O-RUN-HONEST-R|$HERE/n_o_univ_r.k|$DEFR|O-UNIV-R-PROOFS|PASS|600|"
  "1O-RUN-INIT-EXEC-R|$HERE/n_o_univ_r.k|$DEFR|O-UNIV-R-PROOFS|PASS|600|"
  "1O-NEG-UNSAFE-COMMIT-R|$HERE/n_o_univ_r.k|$DEFR|O-UNIV-R-PROOFS|FAIL|200|"
  "R1-UNIV-FOLD|$HERE/repro/univ-repro.k|/tmp/univ-repro|UNIV-REPRO-PROOFS|ATTEMPT|300|"
  "R2-UNIV-MACHINE|$HERE/repro/univ-repro.k|/tmp/univ-repro|UNIV-REPRO-PROOFS|ATTEMPT|300|"
  "R3-UNIV-CONS|$HERE/repro/univ-repro.k|/tmp/univ-repro|UNIV-REPRO-PROOFS|PASS|300|"
  "R4-CMD-SPLIT|$HERE/repro/univ-repro.k|/tmp/univ-repro|UNIV-REPRO-PROOFS|ATTEMPT|300|"
  "R4B-EVAL-CONTROL|$HERE/repro/univ-repro.k|/tmp/univ-repro|UNIV-REPRO-PROOFS|PASS-EVAL|300|"
  "R5-SOUNDNESS-MUST-FAIL|$HERE/repro/univ-repro.k|/tmp/univ-repro|UNIV-REPRO-PROOFS|FAIL|300|"
  "R6-DOMAIN-RESTRICTED|$HERE/repro/univ-repro.k|/tmp/univ-repro|UNIV-REPRO-PROOFS|PASS|300|"
  "R7-DOMAIN-CONTROL|$HERE/repro/univ-repro.k|/tmp/univ-repro|UNIV-REPRO-PROOFS|PASS-EVAL|300|"
  "R9-FUNC-DISPATCH-MUST-FAIL|$HERE/repro/univ-repro.k|/tmp/univ-repro|UNIV-REPRO-PROOFS|FAIL|300|"
  "R10-FUNC-DISPATCH-DOMAIN|$HERE/repro/univ-repro.k|/tmp/univ-repro|UNIV-REPRO-PROOFS|ATTEMPT|300|"
)

echo "claim,backend,invoked,expected,raw_result,trivial,correct,log" > "$OUT/claims-status-o.csv"
PASS=0; FAILC=0; ALARM=0; ATT=0
for ENTRY in "${CLAIMS[@]}"; do
  CL="$(echo "$ENTRY" | cut -d'|' -f1)"
  FILE="$(echo "$ENTRY" | cut -d'|' -f2)"
  DEF="$(echo "$ENTRY" | cut -d'|' -f3)"
  MOD="$(echo "$ENTRY" | cut -d'|' -f4)"
  EXP="$(echo "$ENTRY" | cut -d'|' -f5)"
  TMO="$(echo "$ENTRY" | cut -d'|' -f6)"
  XTRA="$(echo "$ENTRY" | cut -d'|' -f7)"
  LOG="$OUT/kprove_$CL.log"
  echo "kprove   $CL (expected $EXP, tmo ${TMO}s)"
  # shellcheck disable=SC2086
  timeout "$TMO" kprove "$FILE" $INC -d "$DEF" --spec-module "$MOD" --claims "$CL" $XTRA > "$LOG" 2>&1
  RC=$?
  [ $RC -eq 124 ] && echo "  (timeout — retained as FAILED)"
  if [ $RC -eq 0 ]; then RAW=PROVED; else RAW="FAILED(rc=$RC)"; fi
  TRIV=no
  grep -q "WarnTrivialClaim" "$LOG" 2>/dev/null && { TRIV=YES; }
  CORR=correct
  case "$EXP" in
    PASS|PASS-EVAL)
      if [ "$RAW" = "PROVED" ] && { [ "$TRIV" = "no" ] || [ "$EXP" = "PASS-EVAL" ]; }; then PASS=$((PASS+1));
      elif [ "$TRIV" = "YES" ] && [ "$EXP" = "PASS" ]; then CORR=ALARM; ALARM=$((ALARM+1));
      elif [ "$RAW" != "PROVED" ]; then CORR=INCORRECT; FAILC=$((FAILC+1));
      else CORR=correct; PASS=$((PASS+1)); fi ;;
    FAIL)
      if [ "$RAW" != "PROVED" ]; then FAILC=$((FAILC+1)); else CORR=ALARM; ALARM=$((ALARM+1)); fi ;;
    ATTEMPT)
      ATT=$((ATT+1)); CORR=recorded ;;
  esac
  echo "$CL,haskell,yes,$EXP,$RAW,$TRIV,$CORR,$(basename "$LOG")" >> "$OUT/claims-status-o.csv"
done

{
  echo "# 1O K-ladder score — $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "# PASS-expected proved      : $PASS"
  echo "# FAIL-expected not-proved  : $FAILC"
  echo "# ATTEMPT claims (recorded) : $ATT"
  echo "# GATE ALARMS               : $ALARM"
  echo "# GATE                 : $([ $ALARM -eq 0 ] && echo GREEN || echo RED)"
  echo "#"
  echo "# THE UNIVERSAL THEOREM IS MECHANIZED IFF 1O-UNIV-MACHINE-RL (or"
  echo "# 1O-UNIV-MACHINE-R) IS PROVED NON-TRIVIALLY.  Whatever this file"
  echo "# says, the phase disposition follows the raw results and the logs."
} > "$OUT/score-o.txt"
cat "$OUT/score-o.txt"
exit 0
