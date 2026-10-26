#!/bin/bash
# =============================================================================
# SRW3 Phase 1T — the fail-closed runner (Workstreams A + C; Workstream B's
# Lean route is run by audit/lean and recorded in the ledger).
# (phase1t/proofs/run_1t.sh)
#
# Stages:
#   KD   the control-definition kompiles (weak machine, OMIT mutant)
#   WSA1 the 1S conditional-migration reproduction (1S-MIGRATE-UNIV-C12ASSUMED)
#   WSA2 the depth-limited genuineness probes d=1/2/3 on the same claim
#   WSA3 the false-goal controls INSIDE the C12 harness (must fail)
#   WSA4 the weak-machine + OMIT-mutant controls (must fail)
#   WC1  mechanism A: the unconditional universal under the trusted
#        Lean-checked C1.2 lemma
#   WC2  mechanism A: the genesis form (timeout expected per 1S record)
#   WC3  mechanism A: the five dropped-condition correspondence cells +
#        the three preservation cells + the NODEP strip-state probe
#   WC4  mechanism B: the derived-lemma-rule battery (same bodies as 1S
#        C12ASSUMED, epistemic status changed, disclosed)
# Every row's raw outcome (rc, wall, log) is recorded; nothing is relabeled.
# Level III only; no consensus-integration claim.
# =============================================================================
set -u
cd "$(dirname "$0")/../.." || exit 1
REPO=$PWD
source /home/z/my-project/tools/env.sh
INC="-I $REPO/phase1n/semantics -I $REPO/phase1m/semantics -I $REPO/phase1g/semantics -I $REPO/phase1f/semantics -I $REPO/phase1e/semantics -I $REPO/k/phase1d -I $REPO/k/kevm/kproj-e1e/plugin"
LOGS=$REPO/phase1t/transcripts/k
mkdir -p "$LOGS" "$REPO/phase1t/claims"
EC=$REPO/phase1t/claims/exit-codes-1t.csv
[ -f "$EC" ] || echo "claim_id,exit_code,budget_s,wall_s" > "$EC"

note() { echo "[1T] $*"; }
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
    > "/tmp/kompile-1t-$TAG.log" 2>&1
  local RC=$?
  note "  -> rc=$RC"
  return $RC
}

STAGES=${@:-KD WSA1 WSA2 WSA3 WSA4 WC1 WC2 WC3 WC4}
for ST in $STAGES; do
case $ST in
KD)
  kompile_def phase1q/semantics/abs-machine-weak-q.k SRW3N-ABS-WEAK-Q /tmp/p1t-weakq-def weakq || exit 1
  kompile_def phase1s/tests/abs-machine-mut-omit-gatemint-1s.k SRW3N-ABS-MUT-OMIT-GATEMINT /tmp/p1t-mut-def mut || exit 1
  ;;
WSA1)
  run_claim phase1s/proofs/n_s_migrate_c12.k S-MIGRATE-C12-PROOFS /tmp/p1s-rel-def 1S-MIGRATE-UNIV-C12ASSUMED 560
  ;;
WSA2)
  for D in 1 2 3; do
    run_depth phase1s/proofs/n_s_migrate_c12.k S-MIGRATE-C12-PROOFS /tmp/p1s-rel-def 1S-MIGRATE-UNIV-C12ASSUMED 300 $D
  done
  ;;
WSA3)
  run_claim phase1t/proofs/n_t_wsa_controls.k T-WSA-CONTROLS /tmp/p1s-rel-def 1T-WSA-CTRL-DEST-FALSE 150
  run_claim phase1t/proofs/n_t_wsa_controls.k T-WSA-CONTROLS /tmp/p1s-rel-def 1T-WSA-CTRL-SAFETY-FALSE 300
  ;;
WSA4)
  run_claim phase1s/tests/n_s_neg_weak.k S-NEG-WEAK-PROOFS /tmp/p1t-weakq-def 1S-NEG-WEAK-UNIV-Q 300
  run_claim phase1s/tests/n_s_neg_mut.k S-NEG-MUT-PROOFS /tmp/p1t-mut-def 1S-NEG-OMIT-GATEMINT 300
  ;;
WC1)
  run_claim phase1t/proofs/n_t_migrate_uncond.k T-MIGRATE-UNCOND-PROOFS /tmp/p1s-rel-def 1T-MIGRATE-UNIV-LEANC12 560 1T-C12-UNIV-LEAN
  ;;
WC2)
  run_claim phase1t/proofs/n_t_migrate_uncond.k T-MIGRATE-UNCOND-PROOFS /tmp/p1s-rel-def 1T-MIGRATE-GENESIS-LEANC12 560 1T-C12-UNIV-LEAN,1T-MIGRATE-UNIV-LEANC12
  ;;
WC3)
  for C in 1T-CORR-GATE-MINT-UNCOND 1T-CORR-GATE-REFUSE-UNCOND 1T-CORR-COMMIT-ACCEPT-UNCOND \
           1T-CORR-COMMIT-C-UNCOND 1T-CORR-COMMIT-D-UNCOND 1T-CORR-COMMIT-ACCEPT-NODEP-UNCOND \
           1T-PRESV-INT-EXE-MINT-LEANC12 1T-PRESV-INT-GATE-MINT-LEANC12 1T-PRESV-INT-COMMIT-ACCEPT-LEANC12; do
    run_claim phase1t/proofs/n_t_corr_uncond.k T-CORR-UNCOND-PROOFS /tmp/p1s-rel-def $C 200 1T-C12-UNIV-LEAN
  done
  ;;
WC4)
  run_claim phase1t/proofs/n_t_migrate_rule.k T-MIGRATE-RULE-PROOFS /tmp/p1s-rel-def 1T-MIGRATE-UNIV-LEANC12-RULE 560
  for C in 1T-CORR-GATE-MINT-RULE 1T-CORR-GATE-REFUSE-RULE 1T-CORR-COMMIT-ACCEPT-RULE \
           1T-CORR-COMMIT-C-RULE 1T-CORR-COMMIT-D-RULE 1T-CORR-NODEP-RULE; do
    run_claim phase1t/proofs/n_t_migrate_rule.k T-MIGRATE-RULE-PROOFS /tmp/p1s-rel-def $C 200
  done
  run_claim phase1t/proofs/n_t_migrate_rule.k T-MIGRATE-RULE-PROOFS /tmp/p1s-rel-def 1T-MIGRATE-GENESIS-LEANC12-RULE 560
  ;;
WC4B)
  for C in 1T-CORR-GATE-MINT-RULE 1T-CORR-GATE-REFUSE-RULE 1T-CORR-COMMIT-ACCEPT-RULE \
           1T-CORR-COMMIT-C-RULE 1T-CORR-COMMIT-D-RULE 1T-CORR-NODEP-RULE; do
    run_claim phase1t/proofs/n_t_migrate_rule.k T-MIGRATE-RULE-PROOFS /tmp/p1s-rel-def $C 200
  done
  run_claim phase1t/proofs/n_t_migrate_rule.k T-MIGRATE-RULE-PROOFS /tmp/p1s-rel-def 1T-WSA-CTRL-DEST-FALSE-RULE 300
  for D in 1 2; do
    run_depth phase1t/proofs/n_t_migrate_rule.k T-MIGRATE-RULE-PROOFS /tmp/p1s-rel-def 1T-MIGRATE-UNIV-LEANC12-RULE 300 $D
  done
  ;;
WC4C)
  for C in 1T-CORR-GATE-MINT-RULE 1T-CORR-GATE-REFUSE-RULE 1T-CORR-COMMIT-ACCEPT-RULE \
           1T-CORR-COMMIT-C-RULE 1T-CORR-COMMIT-D-RULE 1T-CORR-NODEP-RULE \
           1T-PRESV-INT-EXE-MINT-RULE 1T-PRESV-INT-GATE-MINT-RULE 1T-PRESV-INT-COMMIT-ACCEPT-RULE; do
    run_claim phase1t/proofs/n_t_migrate_rule.k T-MIGRATE-RULE-PROOFS /tmp/p1s-rel-def $C 200
  done
  ;;
*) note "unknown stage $ST"; exit 1;;
esac
done
note "stages done: $STAGES"
