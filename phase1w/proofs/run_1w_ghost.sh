#!/bin/bash
# =============================================================================
# SRW3 Phase 1W — the ghost-fidelity regeneration + per-claim battery runner.
# (phase1w/proofs/run_1w_ghost.sh; a path-adjusted derivative of the audited
#  phase1v/proofs/run_1v_ghost.sh — the transformation is purely the evidence
#  locations (phase1w/...), the ledger name (-1w), the log prefixes (kpg_1w_),
#  the scratch dir (.1w-work), and this header; every check is byte-identical.)
#
# The 1W R9 closure changed the byte-pinned semantic core (k/srw3.k,
# k/srw3gen.k: `init` removed from the grammars, the initial committed state
# supplied as $INITSTATE), so the ghost-fidelity artifacts are REGENERATED
# from the corrected sources and EVERY per-claim verdict is re-established:
#   1. gen_ghost_artifact.py                — rebuild proofs/induction_ghost.k
#   2. audit_ghost_exact.py freeze --force  — refreeze the manifest
#   3. audit_ghost_exact.py verify          — exact byte-faithfulness check
#   4. gen_ghost_proofs.py                  — rebuild proofs/gen/* + manifest
#   5. split_ghost_claims.py                — per-claim specs (unique dir)
#   6. 12 isolated kprove runs (GH-BASE/A/R/SOUND-I/SOUND-F/GATE-AGREE/ISO/
#      T1/T/T2/M/T2-NEG) with EXPECTED verdicts asserted fail-closed:
#        PROVED (rc=0 + #Top): BASE, A, R, SOUND-I, SOUND-F, GATE-AGREE,
#                              ISO, T1, T2, M
#        FAILED (rc=1, designed): T (the documented stuck probe), T2-NEG
#                                 (non-vacuity)
#   7. the generalized per-claim batteries (cm2_alias/cm3_auth/gen_full) in
#      the historical invocation shape; *NEG claims are designed rc=1.
# Raw logs: phase1w/transcripts/ghost/. Verdict ledger:
# phase1w/claims/ghost-verdicts-1w.csv. Nonzero exit on ANY deviation.
#
# The 1U/1V classification precedent is preserved: the combined
# --spec-module SRW3-CLAIMS batch on the ghost copy is NOT the record
# (pre-existing checker behavior on unconstrained cells; per-claim runs are
# the record).
# Level III only.
# =============================================================================
set -u
cd "$(dirname "$0")/../.." || exit 1
REPO=$PWD

if [ -n "${KTOOLS:-}" ] && [ -f "$KTOOLS/env.sh" ]; then source "$KTOOLS/env.sh"
elif [ -f /home/z/my-project/tools1v/env.sh ]; then source /home/z/my-project/tools1v/env.sh
elif [ -f /home/z/my-project/tools/env.sh ]; then source /home/z/my-project/tools/env.sh
else echo "[1W-GHOST] FATAL: pinned toolchain env.sh not found"; exit 2; fi

OUTD=$REPO/phase1w/transcripts/ghost
CLMS=$REPO/phase1w/claims
mkdir -p "$OUTD" "$CLMS" "$REPO/.1w-work"
VCSV=$CLMS/ghost-verdicts-1w.csv
FAILURES=0
note() { echo "[1W-GHOST] $*"; }
record() { # tag class rc expected observed verdict note
  echo "$1,$2,$3,$4,$5,$6,$7" >> "$VCSV"
  [ "$6" = "OK" ] || { FAILURES=$((FAILURES+1)); note "ASSERTION FAILED: $1 (expected [$4], observed [$5])"; }
}

# Stages (default all): GEN KOM MAIN GENSPEC
#   GEN      artifact regeneration + fidelity certificates (steps 1-4)
#   KOM      ghost definition kompile (step 5)
#   MAIN     the 12 per-claim GH battery (step 6)
#   GENSPEC  the three generalized batteries (step 7)
# RUN_APPEND=1 appends to the existing verdict ledger (staged runs).
STAGES=${@:-GEN KOM MAIN GENSPEC}
for ST in $STAGES; do
case $ST in

GEN)
note "stage GEN: regenerate ghost artifacts from the corrected sources"
python3 "$REPO/scripts/gen_ghost_artifact.py" > "$OUTD/ghost_gen_1w.txt" 2>&1 || {
  note "FATAL: gen_ghost_artifact.py failed"; tail -5 "$OUTD/ghost_gen_1w.txt"; exit 3; }
tail -3 "$OUTD/ghost_gen_1w.txt"

python3 "$REPO/scripts/audit_ghost_exact.py" freeze --force > "$OUTD/ghost_manifest_freeze_1w.txt" 2>&1 || {
  note "FATAL: manifest freeze failed"; tail -5 "$OUTD/ghost_manifest_freeze_1w.txt"; exit 3; }

python3 "$REPO/scripts/audit_ghost_exact.py" verify > "$OUTD/ghost_manifest_verify_1w.txt" 2>&1
VRC=$?
tail -2 "$OUTD/ghost_manifest_verify_1w.txt"
if [ $VRC = 0 ]; then record ghost-exact-fidelity fidelity 0 "rc=0 PASS" "rc=0" OK "audit_ghost_exact.py verify"
else record ghost-exact-fidelity fidelity "$VRC" "rc=0 PASS" "rc=$VRC" FAIL "audit_ghost_exact.py verify"; fi

python3 "$REPO/scripts/gen_ghost_proofs.py" > "$OUTD/ghost_gen_proofs_1w.txt" 2>&1 || {
  note "FATAL: gen_ghost_proofs.py failed"; tail -5 "$OUTD/ghost_gen_proofs_1w.txt"; exit 3; }
tail -2 "$OUTD/ghost_gen_proofs_1w.txt"
;;

KOM)
note "stage KOM: kompile the ghost definition"
rm -rf "$REPO/.1w-work/ghost-out"
timeout 900 kompile "$REPO/proofs/induction_ghost.k" --backend haskell --main-module SRW3-GHOST-OBS -o "$REPO/.1w-work/ghost-out" > "$OUTD/kompile_ghost.log" 2>&1
RC=$?
[ $RC = 0 ] || { note "FATAL: ghost kompile rc=$RC"; tail -5 "$OUTD/kompile_ghost.log"; exit 3; }
note "  ghost definition compiled"
;;

MAIN)
note "stage MAIN: per-claim ghost battery (isolated kprove runs)"
GDIR=$(mktemp -d /tmp/srw3-1v-ghost-XXXXXX)
GHOST_CLAIMS_DIR="$GDIR" python3 "$REPO/scripts/split_ghost_claims.py" > "$GDIR/labels.txt" 2>&1 || {
  note "FATAL: split_ghost_claims.py failed"; cat "$GDIR/labels.txt"; exit 3; }
LABELS=$(cat "$GDIR/labels.txt")
note "  claims: $LABELS"
for L in $LABELS; do
  T0=$(date +%s)
  timeout 1200 kprove "$GDIR/c_$L.k" -d "$REPO/.1w-work/ghost-out" -I "$GDIR" \
    --spec-module "SRW3-GC-$L" > "$OUTD/kpg_1w_$L.log" 2>&1
  E=$?; TS=$(( $(date +%s) - T0 ))
  TOPS=$(grep -c '#Top' "$OUTD/kpg_1w_$L.log" || true)
  case $L in
    GH-T|GH-T2-NEG) EXP_RC=1; EXP_V=FAILED;;   # designed failures (never relabel)
    *)              EXP_RC=0; EXP_V=PROVED;;
  esac
  if [ "$E" = "$EXP_RC" ] && { [ "$EXP_RC" != "0" ] || [ "${TOPS:-0}" -ge 1 ]; }; then V=OK; else V=FAIL; fi
  record "ghost-$L" kprove "$E" "rc=$EXP_RC ($EXP_V)" "rc=$E #Top=${TOPS:-0}" "$V" "wall=${TS}s"
done
rm -rf "$GDIR"
;;

GENSPEC)
note "stage GENSPEC: generalized per-claim batteries (cm2_alias, cm3_auth, gen_full)"
# historical invocation shape (scripts/audit_ghost_gen.sh): kompile with
# --main-module/--syntax-module <PRE>-GHOST-OBS -I k; per-claim kprove over
# the split specs (<PRE>-GC-<LABEL>); *NEG claims are designed rc=1.
GDIR=$(mktemp -d /tmp/srw3-1v-ghostgen-XXXXXX)
for SPEC in "proofs/gen/cm2_alias.k SRW3G2 out-cm2" "proofs/gen/cm3_auth.k SRW3G3 out-cm3" "proofs/gen/gen_full.k SRW3G4 out-gen"; do
  ART=$(echo "$SPEC" | cut -d' ' -f1); PRE=$(echo "$SPEC" | cut -d' ' -f2); OD=$(echo "$SPEC" | cut -d' ' -f3)
  timeout 900 kompile "$REPO/$ART" --backend haskell --main-module "$PRE-GHOST-OBS" --syntax-module "$PRE-GHOST-OBS" -I "$REPO/k" -o "$REPO/.1w-work/ghost-gen-$OD" > "$OUTD/kompile_gen_$PRE.log" 2>&1
  RC=$?
  if [ $RC != 0 ]; then note "FATAL: gen ghost $PRE kompile rc=$RC"; tail -5 "$OUTD/kompile_gen_$PRE.log"; rm -rf "$GDIR"; exit 3; fi
  GL=$(python3 "$REPO/scripts/split_gen_claims.py" "$REPO/$ART" "$PRE" "$PRE" "$GDIR/gen-$PRE")
  note "  $PRE claims: $GL"
  for L in $GL; do
    T0=$(date +%s)
    timeout 3600 kprove "$GDIR/gen-$PRE/${PRE}_${L}.k" -d "$REPO/.1w-work/ghost-gen-$OD" -I "$GDIR/gen-$PRE" -I "$REPO/k" \
      --spec-module "${PRE}-GC-${L}" > "$OUTD/kpg_1w_${PRE}_${L}.log" 2>&1
    E=$?; TS=$(( $(date +%s) - T0 ))
    case $L in
      *NEG*) EXP_RC=1; EXP_V=FAILED;; *) EXP_RC=0; EXP_V=PROVED;;
    esac
    if [ "$E" = "$EXP_RC" ]; then V=OK; else V=FAIL; fi
    record "ghost-$PRE-$L" kprove "$E" "rc=$EXP_RC ($EXP_V)" "rc=$E" "$V" "wall=${TS}s"
  done
done
rm -rf "$GDIR"
;;

*) note "unknown stage $ST"; exit 1;;
esac
done
note "ghost battery done: $VCSV"
if [ "$FAILURES" != "0" ]; then note "TOTAL FAILURES: $FAILURES"; exit 1; fi
note "ALL GHOST VERDICTS AS EXPECTED"
exit 0
