#!/bin/bash
# =============================================================================
# SRW3 Phase 1R — the fail-closed runner (stages B/A/AD/ST/C/FF/N/S).
# (phase1r/proofs/run_1r.sh)
#
# Every listed claim is attempted in a fixed order with its own budget; the
# raw log lands under phase1r/transcripts/k/kprove_<CLAIM>.log; wall time
# and exit code are appended to phase1r/claims/exit-codes-1r.csv (last-wins).
# The summarizer (scripts/summarize_1r.py) fails closed on missing logs,
# unrecognized terminals, and inconsistent classifications.
#
# Stages:
#   B   baseline re-anchors (1Q PREFIX of record, the strong empty-reject
#       step, the toy universal — all re-run on the rebuilt toolchain)
#   A   the bounded depth ladder d=0..5 (Experiment A)
#   AD  the bounded DEST control pair (Experiment A controls)
#   ST  the one-step preservation theorem (Experiment B)
#   C   the fold decomposition: TAG1, then TAG0 (with TAG1 trusted), then
#       COMPOSED (with both trusted) (Experiment C)
#   FF  the fold-form exhibits (the open form + the self-application trap)
#   N   the soundness battery re-runs (weak machine, diagnostics, the
#       PREFIX-UNPATCHED regression, the OMIT mutant)
#   S   the summarizer gate
# Whatever the raw results, they are recorded and never relabeled.
# Level III only; no consensus-integration claim.
# =============================================================================
set -u
cd "$(dirname "$0")/../.." || exit 1
REPO=$PWD
source /home/z/my-project/tools/env.sh
export LIBRARY_PATH="$TOOLS/extract/syslibs:$LIBRARY_PATH"
INC="-I $REPO/phase1n/semantics -I $REPO/phase1m/semantics -I $REPO/phase1g/semantics -I $REPO/phase1f/semantics -I $REPO/phase1e/semantics -I $REPO/k/phase1d -I $REPO/k/kevm/kproj-e1e/plugin"
LOGS=$REPO/phase1r/transcripts/k
mkdir -p "$LOGS" "$REPO/phase1r/claims"
EC=$REPO/phase1r/claims/exit-codes-1r.csv
[ -f "$EC" ] || echo "claim_id,exit_code,budget_s,wall_s" > "$EC"

note() { echo "[1R] $*"; }
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
    > "/tmp/kompile-1r-$TAG.log" 2>&1
  local RC=$?
  note "  -> rc=$RC"
  return $RC
}

STAGES=${@:-B A AD ST C FF N S}
for ST in $STAGES; do
case $ST in
B)
  kompile_def phase1q/semantics/abs-machine-q.k SRW3N-ABS-Q /tmp/p1q-q-def q || exit 1
  run_claim phase1q/proofs/n_q_univ_q.k Q-UNIV-PROOFS /tmp/p1q-q-def 1Q-UNIV-PREFIX-Q 300
  run_claim phase1q/proofs/n_q_univ_q.k Q-UNIV-PROOFS /tmp/p1q-q-def 1Q-STRONG-EMPTY-REJECT-STEP-Q 150
  kompile_def phase1q/proofs/repro/univ-repro-qf.k TOY-QF /tmp/p1q-toyf-def toyf || exit 1
  run_claim phase1q/proofs/repro/univ-repro-qf.k TOY-QF-PROOFS /tmp/p1q-toyf-def Q1F-TOY-UNIV-FORKED 240
  ;;
A)
  run_claim phase1r/proofs/n_r_bound_ladder.k R-BOUND-PROOFS /tmp/p1q-q-def 1R-BOUND-0-Q 150
  run_claim phase1r/proofs/n_r_bound_ladder.k R-BOUND-PROOFS /tmp/p1q-q-def 1R-BOUND-1-Q 150
  run_claim phase1r/proofs/n_r_bound_ladder.k R-BOUND-PROOFS /tmp/p1q-q-def 1R-BOUND-2-Q 200
  run_claim phase1r/proofs/n_r_bound_ladder.k R-BOUND-PROOFS /tmp/p1q-q-def 1R-BOUND-3-Q 300
  run_claim phase1r/proofs/n_r_bound_ladder.k R-BOUND-PROOFS /tmp/p1q-q-def 1R-BOUND-4-Q 450
  run_claim phase1r/proofs/n_r_bound_ladder.k R-BOUND-PROOFS /tmp/p1q-q-def 1R-BOUND-5-Q 560
  ;;
AD)
  run_claim phase1r/proofs/n_r_bound_ladder.k R-BOUND-PROOFS /tmp/p1q-q-def 1R-BOUND-0-DEST-Q 150
  run_claim phase1r/proofs/n_r_bound_ladder.k R-BOUND-PROOFS /tmp/p1q-q-def 1R-BOUND-1-DEST-Q 150
  ;;
ST)
  run_claim phase1r/proofs/n_r_step_one.k R-STEP-PROOFS /tmp/p1q-q-def 1R-STEP-ONE-Q 560
  ;;
C)
  run_claim phase1r/proofs/n_r_univ_composed.k R-COMPOSE-PROOFS /tmp/p1q-q-def 1R-UNIV-TAG1-Q 560
  run_claim phase1r/proofs/n_r_univ_composed.k R-COMPOSE-PROOFS /tmp/p1q-q-def 1R-UNIV-TAG0-NF-Q 560 1R-UNIV-TAG1-Q
  run_claim phase1r/proofs/n_r_univ_composed.k R-COMPOSE-PROOFS /tmp/p1q-q-def 1R-UNIV-TAG0-SYMB-Q 300 1R-UNIV-TAG1-Q
  run_claim phase1r/proofs/n_r_univ_composed.k R-COMPOSE-PROOFS /tmp/p1q-q-def 1R-UNIV-COMPOSED-Q 560 1R-UNIV-TAG1-Q,1R-UNIV-TAG0-NF-Q
  ;;
FF)
  run_claim phase1r/proofs/n_r_univ_composed.k R-COMPOSE-PROOFS /tmp/p1q-q-def 1R-FOLD-FORM-OPEN-Q 300
  run_claim phase1r/proofs/n_r_univ_composed.k R-COMPOSE-PROOFS /tmp/p1q-q-def 1R-NEG-FOLD-SELF-Q 300
  ;;
N)
  kompile_def phase1q/semantics/abs-machine-weak-q.k SRW3N-ABS-WEAK-Q /tmp/p1q-weakq-def weakq || exit 1
  run_claim phase1q/proofs/n_q_neg_weak_q.k Q-NEG-WEAK-PROOFS /tmp/p1q-weakq-def 1Q-NEG-WEAK-UNIV-Q 300
  run_claim phase1q/proofs/n_q_neg_weak_q.k Q-NEG-WEAK-PROOFS /tmp/p1q-weakq-def 1Q-WEAK-BREAKING-RUN-Q 150
  run_claim phase1q/proofs/n_q_neg_weak_q.k Q-NEG-WEAK-PROOFS /tmp/p1q-weakq-def 1Q-NEG-WEAK-INV-Q 150
  run_claim phase1q/proofs/n_q_neg_weak_q.k Q-NEG-WEAK-PROOFS /tmp/p1q-weakq-def 1Q-NEG-C3-WEAK-Q 150
  run_claim phase1q/proofs/n_q_neg_weak_q.k Q-NEG-WEAK-PROOFS /tmp/p1q-weakq-def 1Q-WEAK-W2-STEP-EVAL-Q 150
  run_claim phase1q/proofs/n_q_univ_q.k Q-UNIV-PROOFS /tmp/p1q-q-def 1Q-NEG-PREFIX-CEX-Q 150
  run_claim phase1q/proofs/n_q_univ_q.k Q-UNIV-PROOFS /tmp/p1q-q-def 1Q-NEG-DEST-Q 150
  run_claim phase1q/proofs/n_q_diag_eqform.k Q-DIAG-EQFORM-PROOFS /tmp/p1q-q-def 1Q-DIAG-EQFORM-TRUE 100
  run_claim phase1q/proofs/n_q_diag_eqform.k Q-DIAG-EQFORM-PROOFS /tmp/p1q-q-def 1Q-DIAG-EQFORM-FALSE 100
  run_claim phase1q/proofs/n_q_diag_eqform.k Q-DIAG-EQFORM-PROOFS /tmp/p1q-q-def 1Q-DIAG-FALSE-HYP 100
  run_claim phase1q/proofs/n_q_univ_prefix_unpatched.k Q-UNIV-PREFIX-UNPATCHED-PROOFS /tmp/p1q-q-def 1Q-UNIV-PREFIX-UNPATCHED-Q 300
  kompile_def phase1q/tests/abs-machine-mut-omit-q.k SRW3N-ABS-MUT-OMIT-Q /tmp/p1q-mutomit-def mutomit || exit 1
  run_claim phase1q/proofs/n_q_neg_mut_omit_q.k Q-NEG-MUT-OMIT-PROOFS /tmp/p1q-mutomit-def 1Q-NEG-MUT-OMIT-GATEMINT 110
  run_claim phase1q/proofs/n_q_neg_mut_omit_q.k Q-NEG-MUT-OMIT-PROOFS /tmp/p1q-mutomit-def 1Q-NEG-MUT-OMIT-C2 110
  ;;
S)
  python3 phase1r/scripts/summarize_1r.py
  ;;
*) note "unknown stage $ST"; exit 1;;
esac
done
note "stages done: $STAGES"
