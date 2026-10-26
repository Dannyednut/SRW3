#!/bin/bash
# =============================================================================
# SRW3 Phase 1U — the fail-closed runner (Workstream A: the corrected
# derived-lemma rule battery + the A4 rerun suite + the 1S reproductions).
# (phase1u/proofs/run_1u.sh)
#
# Stages:
#   KD    the control-definition kompiles (rel-machine, weak machine, OMIT
#         mutant) into FRESH /tmp/p1u-* directories (clean proof environment)
#   UA2   the isolated C1.5 counterexample exhibits (mutant / corrected /
#         liveness) — normally invoked directly; kept for one-command reruns
#   WSA1  the 1S conditional-migration reproduction + depth probes d=1/2/3
#   WSA4  the weak-machine + OMIT-mutant controls (must fail)
#   UC1   the corrected-rule unconditional universal 1U-MIGRATE-UNIV-LEANC12-RULE
#   UC1D  its genuineness depth probes d=1/2/3 (d=3 is NEW for the RULE form)
#   UC3   the five correspondence cells + NODEP strip-state probe + the three
#         preservation cells under the corrected rules
#   UC4   the corrected-rule genesis form (timeout expected per 1S/1T record)
#   UC5   the destination-false control under the corrected rules (timeout
#         expected per 1T record — kept classified TIMEOUT; the computationally
#         decisive false-goal control is the UA2 fixture)
# Every row's raw outcome (rc, wall, log) is recorded; nothing is relabeled.
# Level III only; no consensus-integration claim.
# =============================================================================
set -u
cd "$(dirname "$0")/../.." || exit 1
REPO=$PWD
source /home/z/my-project/tools/env.sh
INC="-I $REPO/phase1n/semantics -I $REPO/phase1m/semantics -I $REPO/phase1g/semantics -I $REPO/phase1f/semantics -I $REPO/phase1e/semantics -I $REPO/k/phase1d -I $REPO/k/kevm/kproj-e1e/plugin"
LOGS=$REPO/phase1u/transcripts/k
mkdir -p "$LOGS" "$REPO/phase1u/claims"
EC=$REPO/phase1u/claims/exit-codes-1u.csv
[ -f "$EC" ] || echo "claim_id,exit_code,budget_s,wall_s" > "$EC"

note() { echo "[1U] $*"; }
run_claim() { # run_claim <spec-file> <spec-module> <def> <claim> <budget> [trusted] [extra]
  local F=$1 M=$2 D=$3 C=$4 T=$5 TR=${6:-} EX=${7:-}
  local TRARG=""
  [ -n "$TR" ] && TRARG="--trusted $TR"
  note "kprove $C (budget ${T}s${TR:+, trusted: $TR}${EX:+, extra: $EX})"
  local RC T0 T1
  T0=$(date +%s)
  timeout "$T" kprove "$F" $INC -d "$D" --spec-module "$M" --claims "$C" $TRARG $EX \
    > "$LOGS/kprove_$C.log" 2>&1
  RC=$?
  T1=$(date +%s)
  echo "$C,$RC,$T,$((T1-T0))" >> "$EC"
  note "  -> rc=$RC wall=$((T1-T0))s"
}
run_depth() { # run_depth <spec> <module> <def> <claim> <budget> <depth>
  local F=$1 M=$2 D=$3 C=$4 T=$5 DP=$6
  note "kprove --depth $DP $C"
  local RC T0 T1
  T0=$(date +%s)
  timeout "$T" kprove "$F" $INC -d "$D" --spec-module "$M" --claims "$C" --depth "$DP" \
    > "$LOGS/kprove_$C-D$DP.log" 2>&1
  RC=$?
  T1=$(date +%s)
  echo "$C-D$DP,$RC,$T,$((T1-T0))" >> "$EC"
  note "  -> rc=$RC wall=$((T1-T0))s"
}
kompile_def() { # kompile_def <src> <mainmod> <outdir> <tag>
  local SRC=$1 MM=$2 O=$3 TAG=$4
  [ -d "$O" ] && { note "HAVE $O"; return 0; }
  note "kompile $SRC -> $O"
  kompile "$SRC" --backend haskell --main-module "$MM" $INC -o "$O" \
    > "/tmp/kompile-1u-$TAG.log" 2>&1
  local RC=$?
  note "  -> rc=$RC"
  return $RC
}

STAGES=${@:-KD WSA1 WSA4 UC1 UC1D UC3 UC4 UC5}
for ST in $STAGES; do
case $ST in
KD)
  kompile_def phase1s/semantics/rel-machine.k SRW3N-REL-S /tmp/p1u-rel-def rel || exit 1
  kompile_def phase1q/semantics/abs-machine-weak-q.k SRW3N-ABS-WEAK-Q /tmp/p1u-weakq-def weakq || exit 1
  kompile_def phase1s/tests/abs-machine-mut-omit-gatemint-1s.k SRW3N-ABS-MUT-OMIT-GATEMINT /tmp/p1u-mut-def mut || exit 1
  ;;
UA2)
  kompile_def phase1u/proofs/n_u_c15_fixture.k U-C15-FIXTURE /tmp/p1u-c15-def c15 || exit 1
  run_claim phase1u/proofs/n_u_c15_mutant.k U-C15-MUTANT-EXHIBIT /tmp/p1u-c15-def U-C15-MUT-SYMB-GE2-TRUE 120
  run_claim phase1u/proofs/n_u_c15_mutant.k U-C15-MUTANT-EXHIBIT /tmp/p1u-c15-def U-C15-MUT-SYMB-GE1-TRUE 120
  run_claim phase1u/proofs/n_u_c15_corrected.k U-C15-CORRECTED-EXHIBIT /tmp/p1u-c15-def U-C15-COR-SYMB-GE2-TRUE 120
  run_claim phase1u/proofs/n_u_c15_corrected.k U-C15-CORRECTED-EXHIBIT /tmp/p1u-c15-def U-C15-COR-CONCRETE-GE2-FALSE 120
  run_claim phase1u/proofs/n_u_c15_corrected.k U-C15-CORRECTED-EXHIBIT /tmp/p1u-c15-def U-C15-COR-CONCRETE-GE1-TRUE 120
  run_claim phase1u/proofs/n_u_c15_corrected.k U-C15-CORRECTED-EXHIBIT /tmp/p1u-c15-def U-C15-COR-SYMB-GE1-TRUE 120
  run_claim phase1u/proofs/n_u_c15_liveness.k U-C15-LIVENESS /tmp/p1u-c15-def U-C15-LIVE-FOLDED-GE1 120
  run_claim phase1u/proofs/n_u_c15_liveness.k U-C15-LIVENESS /tmp/p1u-c15-def U-C15-LIVE-UNFOLDED-NOSHIFT-MUST-STICK 120
  run_claim phase1u/proofs/n_u_c15_mutant_prio.k U-C15-MUTANT-PRIO /tmp/p1u-c15-def U-C15-PRIO-SYMB-GE2-TRUE 120
  run_claim phase1u/proofs/n_u_c15_mutant_prio.k U-C15-MUTANT-PRIO /tmp/p1u-c15-def U-C15-PRIO-SYMB-GE1-TRUE 120
  ;;
WSA1)
  run_claim phase1s/proofs/n_s_migrate_c12.k S-MIGRATE-C12-PROOFS /tmp/p1u-rel-def 1S-MIGRATE-UNIV-C12ASSUMED 560
  for D in 1 2 3; do
    run_depth phase1s/proofs/n_s_migrate_c12.k S-MIGRATE-C12-PROOFS /tmp/p1u-rel-def 1S-MIGRATE-UNIV-C12ASSUMED 300 $D
  done
  ;;
WSA4)
  run_claim phase1s/tests/n_s_neg_weak.k S-NEG-WEAK-PROOFS /tmp/p1u-weakq-def 1S-NEG-WEAK-UNIV-Q 300
  run_claim phase1s/tests/n_s_neg_mut.k S-NEG-MUT-PROOFS /tmp/p1u-mut-def 1S-NEG-OMIT-GATEMINT 300
  ;;
UC1)
  run_claim phase1u/proofs/n_u_migrate_rule.k U-MIGRATE-RULE-PROOFS /tmp/p1u-rel-def 1U-MIGRATE-UNIV-LEANC12-RULE 560
  ;;
UC1D)
  for D in 1 2 3; do
    run_depth phase1u/proofs/n_u_migrate_rule.k U-MIGRATE-RULE-PROOFS /tmp/p1u-rel-def 1U-MIGRATE-UNIV-LEANC12-RULE 300 $D
  done
  ;;
UC3)
  for C in 1U-CORR-GATE-MINT-RULE 1U-CORR-GATE-REFUSE-RULE 1U-CORR-COMMIT-ACCEPT-RULE \
           1U-CORR-COMMIT-C-RULE 1U-CORR-COMMIT-D-RULE 1U-CORR-NODEP-RULE \
           1U-PRESV-INT-EXE-MINT-RULE 1U-PRESV-INT-GATE-MINT-RULE 1U-PRESV-INT-COMMIT-ACCEPT-RULE; do
    run_claim phase1u/proofs/n_u_migrate_rule.k U-MIGRATE-RULE-PROOFS /tmp/p1u-rel-def $C 200
  done
  ;;
UC4)
  run_claim phase1u/proofs/n_u_migrate_rule.k U-MIGRATE-RULE-PROOFS /tmp/p1u-rel-def 1U-MIGRATE-GENESIS-LEANC12-RULE 560
  ;;
UC5)
  run_claim phase1u/proofs/n_u_migrate_rule.k U-MIGRATE-RULE-PROOFS /tmp/p1u-rel-def 1U-WSA-CTRL-DEST-FALSE-RULE 300
  ;;
*) note "unknown stage $ST"; exit 1;;
esac
done
note "stages done: $STAGES"
