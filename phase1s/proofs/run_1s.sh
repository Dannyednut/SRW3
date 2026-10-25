#!/bin/bash
# =============================================================================
# SRW3 Phase 1S — the fail-closed runner (stages GEN/CS/CF/CO/CV/MG/NG/NT/S).
# (phase1s/proofs/run_1s.sh)
#
# Every listed claim is attempted in a fixed order with its own budget; the
# raw log lands under phase1s/transcripts/k/kprove_<CLAIM>.log; wall time
# and exit code are appended to phase1s/claims/exit-codes-1s.csv (last-wins).
# The summarizer (scripts/summarize_1s.py) fails closed on missing logs,
# unrecognized terminals, and inconsistent classifications.
#
# Stages:
#   GEN  the generators + the static witnesses (row witness, coverage
#        battery, C1.2 family, the OMIT mutant) — fail-closed
#   KD   the definition kompiles (the rel module, the weak machine, the
#        OMIT mutant) — fail-closed
#   CS   the count-semantics battery (C1.1, the C1.2 attempt + cases +
#        slack, the StateRel/genesis lemmas, C1.5 backward)
#   CF   the generated C1.2 depth family (BOUNDED-PROVED)
#   CO   the per-class transition-correspondence battery + the invariant-
#        preservation cells
#   CV   the transition-coverage battery (the generated ground cells, the
#        guard grid, the exclusivity pairs, the domain anchors)
#   MG   the migration battery (the unconditional attempt, the C12ASSUMED
#        forms, the destination falsity control, the separation witness)
#   NG   the negative battery (n_s_neg.k) + the weak-machine control
#   NM   the OMIT-mutant detection control
#   NT   the timeout-discipline control (the 1Q machine-of-record universal
#        re-run; rc=124 expected; NEVER a refutation)
#   S    the summarizer gate
# Whatever the raw results, they are recorded and never relabeled.
# Level III only; no consensus-integration claim.
# =============================================================================
set -u
cd "$(dirname "$0")/../.." || exit 1
REPO=$PWD
source /home/z/my-project/tools/env.sh
INC="-I $REPO/phase1n/semantics -I $REPO/phase1m/semantics -I $REPO/phase1g/semantics -I $REPO/phase1f/semantics -I $REPO/phase1e/semantics -I $REPO/k/phase1d -I $REPO/k/kevm/kproj-e1e/plugin"
LOGS=$REPO/phase1s/transcripts/k
mkdir -p "$LOGS" "$REPO/phase1s/claims"
EC=$REPO/phase1s/claims/exit-codes-1s.csv
[ -f "$EC" ] || echo "claim_id,exit_code,budget_s,wall_s" > "$EC"

note() { echo "[1S] $*"; }
run_claim() { # run_claim <spec-file> <spec-module> <def> <claim> <budget> [trusted]
  local F=$1 M=$2 D=$3 C=$4 T=$5 TR=${6:-}
  local TRARG=""
  [ -n "$TR" ] && TRARG="--trusted $TR"
  note "kprove $C (budget ${T}s${TR:+, trusted: $TR})"
  local RC T0 T1
  T0=$(date +%s)
  timeout "$T" kprove "$F" $INC -d "$D" --spec-module "$M" --claims "$C" $TRARG \
    > "$LOGS/kprove_$C.log" 2>&1
  RC=$?
  T1=$(date +%s)
  echo "$C,$RC,$T,$((T1-T0))" >> "$EC"
  note "  -> rc=$RC wall=$((T1-T0))s"
}
kompile_def() { # kompile_def <src> <mainmod> <outdir> <tag>
  local SRC=$1 MM=$2 O=$3 TAG=$4
  [ -d "$O" ] && { note "HAVE $O"; return 0; }
  note "kompile $SRC -> $O"
  kompile "$SRC" --backend haskell --main-module "$MM" $INC -o "$O" \
    > "/tmp/kompile-1s-$TAG.log" 2>&1
  local RC=$?
  note "  -> rc=$RC"
  return $RC
}

STAGES=${@:-GEN KD CS CF CO CV MG1 MG2 MG3 MG3B MG4 NG NM NT S}
for ST in $STAGES; do
case $ST in
GEN)
  python3 phase1s/scripts/make_rel_1s.py            || exit 1
  python3 phase1s/scripts/make_c12_family_1s.py     || exit 1
  python3 phase1s/scripts/make_coverage_1s.py       || exit 1
  python3 phase1s/scripts/make_mutant_1s.py         || exit 1
  python3 phase1s/scripts/verify_rows_1s.py         || exit 1
  python3 phase1r/scripts/verify_grid_1r.py         || exit 1
  ;;
KD)
  kompile_def phase1s/semantics/rel-machine.k SRW3N-REL-S /tmp/p1s-rel-def rel || exit 1
  kompile_def phase1q/semantics/abs-machine-weak-q.k SRW3N-ABS-WEAK-Q /tmp/p1s-weakq-def weakq || exit 1
  kompile_def phase1s/tests/abs-machine-mut-omit-gatemint-1s.k SRW3N-ABS-MUT-OMIT-GATEMINT /tmp/p1s-mut-def mut || exit 1
  kompile_def phase1q/semantics/abs-machine-q.k SRW3N-ABS-Q /tmp/p1q-q-def q || exit 1
  kompile_def phase1s/tests/n_s_neg_defs.k SRW3N-NEG-DEFS-S /tmp/p1s-negdefs-def negdefs || exit 1
  ;;
CS)
  run_claim phase1s/proofs/n_s_count_semantics.k S-COUNT-PROOFS /tmp/p1s-rel-def 1S-C1.1-EQ0 120
  run_claim phase1s/proofs/n_s_count_semantics.k S-COUNT-PROOFS /tmp/p1s-rel-def 1S-C1.1-EQ1 120
  run_claim phase1s/proofs/n_s_count_semantics.k S-COUNT-PROOFS /tmp/p1s-rel-def 1S-C1.2-UNIV 300
  run_claim phase1s/proofs/n_s_count_semantics.k S-COUNT-PROOFS /tmp/p1s-rel-def 1S-C1.2-CASE-ZERO 120
  run_claim phase1s/proofs/n_s_count_semantics.k S-COUNT-PROOFS /tmp/p1s-rel-def 1S-C1.2-CASE-SUCC 120
  run_claim phase1s/proofs/n_s_count_semantics.k S-COUNT-PROOFS /tmp/p1s-rel-def 1S-C1.2-SLACK 120
  run_claim phase1s/proofs/n_s_count_semantics.k S-COUNT-PROOFS /tmp/p1s-rel-def 1S-STATEREL-IMAGE 120
  run_claim phase1s/proofs/n_s_count_semantics.k S-COUNT-PROOFS /tmp/p1s-rel-def 1S-INIT-CORR-REL 120
  run_claim phase1s/proofs/n_s_count_semantics.k S-COUNT-PROOFS /tmp/p1s-rel-def 1S-INIT-CORR-SAFEINT 120
  run_claim phase1s/proofs/n_s_count_semantics.k S-COUNT-PROOFS /tmp/p1s-rel-def 1S-INIT-CORR-SAFECOUNT 120
  run_claim phase1s/proofs/n_s_count_semantics.k S-COUNT-PROOFS /tmp/p1s-rel-def 1S-INIT-CORR-IMAGE 120
  run_claim phase1s/proofs/n_s_count_semantics.k S-COUNT-PROOFS /tmp/p1s-rel-def 1S-C1.5-BWD-COND 120
  ;;
CF)
  for D in 0 1 2 3 4 5; do
    run_claim phase1s/proofs/n_s_c12_family.k S-C12-FAMILY-PROOFS /tmp/p1s-rel-def 1S-C1.2-FAMILY-D$D-NN 120
  done
  ;;
CO)
  run_claim phase1s/proofs/n_s_correspondence.k S-CORR-PROOFS /tmp/p1s-rel-def 1S-CORR-INIT-ACCEPT 150
  run_claim phase1s/proofs/n_s_correspondence.k S-CORR-PROOFS /tmp/p1s-rel-def 1S-CORR-INIT-REFUSE 150
  run_claim phase1s/proofs/n_s_correspondence.k S-CORR-PROOFS /tmp/p1s-rel-def 1S-CORR-REINIT 150
  run_claim phase1s/proofs/n_s_correspondence.k S-CORR-PROOFS /tmp/p1s-rel-def 1S-CORR-STALL 150
  run_claim phase1s/proofs/n_s_correspondence.k S-CORR-PROOFS /tmp/p1s-rel-def 1S-CORR-EXE-MINT 150
  run_claim phase1s/proofs/n_s_correspondence.k S-CORR-PROOFS /tmp/p1s-rel-def 1S-CORR-EXE-SRC 150
  run_claim phase1s/proofs/n_s_correspondence.k S-CORR-PROOFS /tmp/p1s-rel-def 1S-CORR-EXE-UNSUP 150
  run_claim phase1s/proofs/n_s_correspondence.k S-CORR-PROOFS /tmp/p1s-rel-def 1S-CORR-GATE-PRE 150
  run_claim phase1s/proofs/n_s_correspondence.k S-CORR-PROOFS /tmp/p1s-rel-def 1S-CORR-GATE-EMPTY 150
  run_claim phase1s/proofs/n_s_correspondence.k S-CORR-PROOFS /tmp/p1s-rel-def 1S-CORR-GATE-MINT-COND 150
  run_claim phase1s/proofs/n_s_correspondence.k S-CORR-PROOFS /tmp/p1s-rel-def 1S-CORR-GATE-MINT-NODEP 150
  run_claim phase1s/proofs/n_s_correspondence.k S-CORR-PROOFS /tmp/p1s-rel-def 1S-CORR-GATE-REFUSE-COND 150
  run_claim phase1s/proofs/n_s_correspondence.k S-CORR-PROOFS /tmp/p1s-rel-def 1S-CORR-COMMIT-PRE 150
  run_claim phase1s/proofs/n_s_correspondence.k S-CORR-PROOFS /tmp/p1s-rel-def 1S-CORR-COMMIT-ACCEPT-COND 150
  run_claim phase1s/proofs/n_s_correspondence.k S-CORR-PROOFS /tmp/p1s-rel-def 1S-CORR-COMMIT-ACCEPT-NODEP 150
  run_claim phase1s/proofs/n_s_correspondence.k S-CORR-PROOFS /tmp/p1s-rel-def 1S-CORR-COMMIT-C-COND 150
  run_claim phase1s/proofs/n_s_correspondence.k S-CORR-PROOFS /tmp/p1s-rel-def 1S-CORR-COMMIT-D-COND 150
  run_claim phase1s/proofs/n_s_correspondence.k S-CORR-PROOFS /tmp/p1s-rel-def 1S-CORR-COMMIT-GEMPTY 150
  run_claim phase1s/proofs/n_s_correspondence.k S-CORR-PROOFS /tmp/p1s-rel-def 1S-CORR-COMMIT-EEMPTY 150
  run_claim phase1s/proofs/n_s_correspondence.k S-CORR-PROOFS /tmp/p1s-rel-def 1S-PRESV-INT-EXE-MINT 200
  run_claim phase1s/proofs/n_s_correspondence.k S-CORR-PROOFS /tmp/p1s-rel-def 1S-PRESV-INT-GATE-MINT 200
  run_claim phase1s/proofs/n_s_correspondence.k S-CORR-PROOFS /tmp/p1s-rel-def 1S-PRESV-INT-COMMIT-ACCEPT-COND 200
  run_claim phase1s/proofs/n_s_correspondence.k S-CORR-PROOFS /tmp/p1s-rel-def 1S-PRESV-INT-COMMIT-ACCEPT-NODEP 200
  ;;
CV)
  for C in 1S-COV-Q-INIT-ACCEPT 1S-COV-Q-INIT-REFUSE 1S-COV-Q-REINIT 1S-COV-Q-STALL \
           1S-COV-Q-EXE-MINT 1S-COV-Q-EXE-SRC 1S-COV-Q-EXE-UNSUP \
           1S-COV-Q-GATE-PRE 1S-COV-Q-GATE-EMPTY 1S-COV-Q-GATE-MINT 1S-COV-Q-GATE-REFUSE \
           1S-COV-Q-COMMIT-PRE 1S-COV-Q-COMMIT-ACCEPT 1S-COV-Q-COMMIT-C 1S-COV-Q-COMMIT-D \
           1S-COV-Q-COMMIT-GEMPTY 1S-COV-Q-COMMIT-EEMPTY \
           1S-COV-Q-OWISE-INERT-aInitJaOkT 1S-COV-Q-OWISE-INERT-aExecJaOkTaSrcAuth \
           1S-COV-Q-OWISE-INERT-aGateJaOkF 1S-COV-Q-OWISE-INERT-aCommitJaOkTaOkF; do
    run_claim phase1s/proofs/n_s_coverage.k S-COVERAGE-PROOFS /tmp/p1s-rel-def $C 150
  done
  for C in 1S-COV-E-GATE-A-AT0 1S-COV-E-GATE-A-ATNEG 1S-COV-E-GATE-B-AT1 1S-COV-E-GATE-C-AT1 \
           1S-COV-E-COMMIT-B-AT11 1S-COV-E-COMMIT-A-AT0E 1S-COV-E-COMMIT-A-ATG0 \
           1S-COV-EXCL-GATE 1S-COV-EXCL-COMMIT 1S-COV-EXCL-PREINIT \
           1S-COV-DOMAIN-PREEXEC 1S-COV-DOMAIN-NIL 1S-COV-DOMAIN-HONEST-PIPELINE; do
    run_claim phase1s/proofs/n_s_coverage.k S-COVERAGE-PROOFS /tmp/p1s-rel-def $C 150
  done
  ;;
MG1)
  run_claim phase1s/proofs/n_s_migrate.k S-MIGRATE-PROOFS /tmp/p1s-rel-def 1S-MIGRATE-UNIV 300
  run_claim phase1s/proofs/n_s_migrate.k S-MIGRATE-PROOFS /tmp/p1s-rel-def 1S-MIGRATE-DEST-NEG 150
  run_claim phase1s/proofs/n_s_migrate.k S-MIGRATE-PROOFS /tmp/p1s-rel-def 1S-SEP-INCOHERENT-NOT-RELATED 120
  ;;
MG2)
  run_claim phase1s/proofs/n_s_migrate_c12.k S-MIGRATE-C12-PROOFS /tmp/p1s-rel-def 1S-MIGRATE-UNIV-C12ASSUMED 560
  ;;
MG3)
  run_claim phase1s/proofs/n_s_migrate_c12.k S-MIGRATE-C12-PROOFS /tmp/p1s-rel-def 1S-MIGRATE-GENESIS-C12ASSUMED 560
  ;;
MG3B)
  run_claim phase1s/proofs/n_s_migrate_c12.k S-MIGRATE-C12-PROOFS /tmp/p1s-rel-def 1S-MIGRATE-GENESIS-C12ASSUMED 560 1S-MIGRATE-UNIV-C12ASSUMED
  ;;
MG4)
  run_claim phase1s/proofs/n_s_migrate.k S-MIGRATE-PROOFS /tmp/p1s-rel-def 1S-MIGRATE-DEST-NEG-CONCRETE 150
  run_claim phase1s/proofs/n_s_migrate.k S-MIGRATE-PROOFS /tmp/p1s-rel-def 1S-MIGRATE-DEST-NEG-STEP 150
  ;;
NG)
  for C in 1S-NEG-NEGCOUNT-UNSAFE 1S-NEG-NEGCOUNT-NOT-REPRESENTABLE 1S-NEG-STALE-MAP \
           1S-NEG-DEC-FROM-ZERO 1S-NEG-DEC-FROM-ONE-INT 1S-NEG-EMPTY-COMMIT \
           1S-NEG-BAD-AUTH-COMMIT 1S-NEG-TAGBREAK-INV 1S-NEG-TAGBREAK-CORR \
           1S-NEG-FAKE-CORR 1S-NEG-SELF-ASSUMED 1S-NEG-MIXED-BITS 1S-NEG-CONV-NEG-INT; do
    run_claim phase1s/tests/n_s_neg.k S-NEG-PROOFS /tmp/p1s-negdefs-def $C 150
  done
  run_claim phase1s/tests/n_s_neg_weak.k S-NEG-WEAK-PROOFS /tmp/p1s-weakq-def 1S-NEG-WEAK-IMAGE-UNSAFE 150
  run_claim phase1s/tests/n_s_neg_weak.k S-NEG-WEAK-PROOFS /tmp/p1s-weakq-def 1S-NEG-WEAK-UNIV-Q 300
  ;;
NM)
  run_claim phase1s/tests/n_s_neg_mut.k S-NEG-MUT-PROOFS /tmp/p1s-mut-def 1S-NEG-OMIT-GATEMINT 300
  ;;
NT)
  run_claim phase1q/proofs/n_q_univ_q.k Q-UNIV-PROOFS /tmp/p1q-q-def 1Q-UNIV-MACHINE-Q-1S 560
  ;;
S)
  python3 phase1s/scripts/summarize_1s.py
  ;;
*) note "unknown stage $ST"; exit 1;;
esac
done
note "stages done: $STAGES"
