#!/bin/bash
# =============================================================================
# SRW3 Phase 1Q — the fail-closed runner (stages K/B/A/L/U/N/M/D/S).
# (phase1q/proofs/run_q_univ.sh)
#
# Every listed claim is attempted in a fixed order with its own budget; the
# raw log lands under phase1q/transcripts/k/kprove_<CLAIM>.log; the exit
# code is appended to phase1q/claims/exit-codes.csv (last-wins).  The
# summarizer (scripts/summarize_1q.py) fails closed on missing logs,
# unrecognized terminals, and inconsistent classifications.  The sandbox
# reaps detached processes (the 1P lesson): run this script in FOREGROUND
# batches, or per-stage:
#   bash phase1q/proofs/run_q_univ.sh K B A L U N M D && \
#     python3 phase1q/scripts/summarize_1q.py
#
# Stages:
#   K  kompile the seven definitions (5 machine variants + 2 toys)
#   B  the 1P residual reproduction (the baseline anchor)
#   A  the toy ladder (the direct diagnostic + the forked architecture)
#   L  the lemma families (P1/C1/PRESV/COH/C2/C3/C4/C5/self)
#   U  the universal attempts (MACHINE-Q long form; PREFIX of record)
#   N  the weak-machine battery + the strong-side commit controls
#   M  the mutant battery (one mutant per kompile target)
#   D  the diagnostics (the ==K-form vacuity pair + the false-hypothesis
#      probe + the circularity-hole exhibit)
#   S  the summarizer gate
# Whatever the raw results, they are recorded and never relabeled.
# Level III only; no consensus-integration claim.
# =============================================================================
set -u
cd "$(dirname "$0")/../.." || exit 1
REPO=$PWD
source /home/z/my-project/tools/env.sh
export LIBRARY_PATH="$TOOLS/extract/syslibs:$LIBRARY_PATH"
INC="-I $REPO/phase1n/semantics -I $REPO/phase1m/semantics -I $REPO/phase1g/semantics -I $REPO/phase1f/semantics -I $REPO/phase1e/semantics -I $REPO/k/phase1d -I $REPO/k/kevm/kproj-e1e/plugin"
LOGS=$REPO/phase1q/transcripts/k
mkdir -p "$LOGS" "$REPO/phase1q/claims"
EC=$REPO/phase1q/claims/exit-codes.csv
[ -f "$EC" ] || echo "claim_id,exit_code,budget_s" > "$EC"

note() { echo "[1Q] $*"; }
run_claim() { # run_claim <spec-file> <spec-module> <def> <claim> <budget>
  local F=$1 M=$2 D=$3 C=$4 T=$5
  note "kprove $C (budget ${T}s)"
  local RC
  timeout "$T" kprove "$F" $INC -d "$D" --spec-module "$M" --claims "$C" \
    > "$LOGS/kprove_$C.log" 2>&1
  RC=$?
  echo "$C,$RC,$T" >> "$EC"
  note "  -> rc=$RC"
}
kompile_def() { # kompile_def <src> <mainmod> <outdir>
  local SRC=$1 MM=$2 O=$3
  note "kompile $SRC -> $O"
  kompile "$SRC" --backend haskell --main-module "$MM" $INC -o "$O" \
    > "/tmp/kompile-1q-$(basename "$O").log" 2>&1
  local RC=$?
  note "  -> rc=$RC"
  return $RC
}

STAGES=${@:-K B A L U N M D S}
for ST in $STAGES; do
case $ST in
K)
  kompile_def phase1q/semantics/abs-machine-q.k SRW3N-ABS-Q /tmp/p1q-q-def || exit 1
  kompile_def phase1q/semantics/abs-machine-weak-q.k SRW3N-ABS-WEAK-Q /tmp/p1q-weakq-def || exit 1
  kompile_def phase1q/tests/abs-machine-mut-stale-q.k SRW3N-ABS-MUT-STALE-Q /tmp/p1q-mutstale-def || exit 1
  kompile_def phase1q/tests/abs-machine-mut-flip-q.k SRW3N-ABS-MUT-FLIP-Q /tmp/p1q-mutflip-def || exit 1
  kompile_def phase1q/tests/abs-machine-mut-omit-q.k SRW3N-ABS-MUT-OMIT-Q /tmp/p1q-mutomit-def || exit 1
  kompile_def phase1q/proofs/repro/univ-repro-q.k TOY-Q /tmp/p1q-toy-def || exit 1
  kompile_def phase1q/proofs/repro/univ-repro-qf.k TOY-QF /tmp/p1q-toyf-def || exit 1
  kompile_def phase1p/semantics/abs-machine-tdrr.k SRW3N-ABS-TDRR /tmp/p1p-tdrr-def || exit 1
  ;;
B)
  run_claim phase1p/proofs/n_p_univ_tdrr.k P-UNIV-TDRR-PROOFS /tmp/p1p-tdrr-def 1P-UNIV-MACHINE-TDRR-repro 300
  # NOTE: the 1P claim's label is 1P-UNIV-MACHINE-TDRR; the repro log is
  # written under the -repro name by re-running with --claims and renaming.
  if [ -f "$LOGS/kprove_1P-UNIV-MACHINE-TDRR.log" ] && [ ! -f "$LOGS/kprove_1P-UNIV-MACHINE-TDRR-repro.log" ]; then
    mv "$LOGS/kprove_1P-UNIV-MACHINE-TDRR.log" "$LOGS/kprove_1P-UNIV-MACHINE-TDRR-repro.log"
  fi
  ;;
A)
  run_claim phase1q/proofs/repro/univ-repro-q.k  TOY-Q-PROOFS  /tmp/p1q-toy-def  Q1-TOY-UNIV-DIRECT 240
  run_claim phase1q/proofs/repro/univ-repro-q.k  TOY-Q-PROOFS  /tmp/p1q-toy-def  Q2-TOY-CONS 240
  run_claim phase1q/proofs/repro/univ-repro-q.k  TOY-Q-PROOFS  /tmp/p1q-toy-def  Q3-TOY-DOMAIN 240
  run_claim phase1q/proofs/repro/univ-repro-q.k  TOY-Q-PROOFS  /tmp/p1q-toy-def  Q4-TOY-MUST-FAIL 240
  run_claim phase1q/proofs/repro/univ-repro-q.k  TOY-Q-PROOFS  /tmp/p1q-toy-def  Q4B-TOY-BREAKING-RUN 240
  run_claim phase1q/proofs/repro/univ-repro-q.k  TOY-Q-PROOFS  /tmp/p1q-toy-def  Q5-TOY-C1-NONNEG 240
  run_claim phase1q/proofs/repro/univ-repro-qf.k TOY-QF-PROOFS /tmp/p1q-toyf-def Q1F-TOY-UNIV-FORKED 240
  run_claim phase1q/proofs/repro/univ-repro-qf.k TOY-QF-PROOFS /tmp/p1q-toyf-def Q2F-TOY-CONS 240
  run_claim phase1q/proofs/repro/univ-repro-qf.k TOY-QF-PROOFS /tmp/p1q-toyf-def Q3F-TOY-DOMAIN 240
  run_claim phase1q/proofs/repro/univ-repro-qf.k TOY-QF-PROOFS /tmp/p1q-toyf-def Q4F-TOY-MUST-FAIL 240
  run_claim phase1q/proofs/repro/univ-repro-qf.k TOY-QF-PROOFS /tmp/p1q-toyf-def Q4FB-TOY-BREAKING-RUN 240
  run_claim phase1q/proofs/repro/univ-repro-qf.k TOY-QF-PROOFS /tmp/p1q-toyf-def Q5F-TOY-C1-NONNEG 240
  ;;
L)
  for C in 1Q-P1-TAG-RANGE 1Q-P1-GENESIS-COH 1Q-P1-ERASE-GENESIS 1Q-C1-CONCRETE; do
    run_claim phase1q/proofs/n_q_lemmas_q.k Q-LEMMAS-PROOFS /tmp/p1q-q-def "$C" 150
  done
  run_claim phase1q/proofs/n_q_lemmas_q.k Q-LEMMAS-PROOFS /tmp/p1q-q-def 1Q-C1-NONNEG 200
  for C in 1Q-PRESV-I-COMMIT-ACCEPT 1Q-PRESV-I-COMMIT-REJECT-ZG 1Q-PRESV-I-COMMIT-REJECT-ZGS \
           1Q-PRESV-I-COMMIT-REJECT-HI 1Q-PRESV-I-COMMIT-REJECT-BITF 1Q-PRESV-I-EXEC-MINT \
           1Q-PRESV-I-EXEC-REFUSE 1Q-PRESV-I-EXEC-SOURCE 1Q-PRESV-I-GATE-MINT \
           1Q-PRESV-I-GATE-MINT-EMPTY 1Q-PRESV-I-GATE-REFUSE-S 1Q-PRESV-I-INIT-ACCEPT \
           1Q-PRESV-I-INIT-REFUSE 1Q-PRESV-I-EXEC-STALL; do
    run_claim phase1q/proofs/n_q_lemmas_q.k Q-LEMMAS-PROOFS /tmp/p1q-q-def "$C" 150
  done
  for C in 1Q-COH-P-INIT-ACCEPT 1Q-COH-P-INIT-REFUSE 1Q-COH-P-EXEC-STALL \
           1Q-COH-I-GATE-MINT 1Q-COH-I-COMMIT-ACCEPT 1Q-COH-I-COMMIT-REJECT-ZG; do
    run_claim phase1q/proofs/n_q_lemmas_q.k Q-LEMMAS-PROOFS /tmp/p1q-q-def "$C" 150
  done
  for C in 1Q-C2-ERASE-INIT-ACCEPT 1Q-C2-ERASE-INIT-REFUSE 1Q-C2-ERASE-EXEC-MINT \
           1Q-C2-ERASE-EXEC-REFUSE 1Q-C2-ERASE-EXEC-SOURCE 1Q-C2-ERASE-EXEC-STALL \
           1Q-C2-ERASE-GATE-MINT 1Q-C2-ERASE-GATE-MINT-NODEP 1Q-C2-ERASE-GATE-REFUSE-Z \
           1Q-C2-ERASE-GATE-REFUSE-S 1Q-C2-ERASE-COMMIT-ACCEPT 1Q-C2-ERASE-COMMIT-REJECT-ZG \
           1Q-C2-ERASE-COMMIT-REJECT-ZGS 1Q-C2-ERASE-COMMIT-REJECT-HI; do
    run_claim phase1q/proofs/n_q_lemmas_q.k Q-LEMMAS-PROOFS /tmp/p1q-q-def "$C" 150
  done
  for C in 1Q-C3-SUCC-IMPLIES-NONZERO 1Q-C3-ZERO-NOT-NONZERO 1Q-C4-TAGSOUND-B0 \
           1Q-C4-TAGSOUND-B1-SUCC 1Q-C4-TAGSOUND-B1-ZERO 1Q-NEG-SELF-ASSUME; do
    run_claim phase1q/proofs/n_q_lemmas_q.k Q-LEMMAS-PROOFS /tmp/p1q-q-def "$C" 150
  done
  for C in 1Q-C3-GENERAL-FORM 1Q-C5-EXHAUSTIVENESS-ATTEMPT; do
    run_claim phase1q/proofs/n_q_lemmas_q.k Q-LEMMAS-PROOFS /tmp/p1q-q-def "$C" 240
  done
  ;;
U)
  run_claim phase1q/proofs/n_q_univ_q.k Q-UNIV-PROOFS /tmp/p1q-q-def 1Q-UNIV-PREFIX-Q 560
  # 1Q-UNIV-MACHINE-Q: the sandbox's single-call ceiling is ~560s; the full
  # attempt of record ran detached with a 3600s budget (see the report and
  # claims.csv).  Re-run here with the foreground ceiling:
  run_claim phase1q/proofs/n_q_univ_q.k Q-UNIV-PROOFS /tmp/p1q-q-def 1Q-UNIV-MACHINE-Q 560
  ;;
N)
  run_claim phase1q/proofs/n_q_neg_weak_q.k Q-NEG-WEAK-PROOFS /tmp/p1q-weakq-def 1Q-NEG-WEAK-UNIV-Q 300
  run_claim phase1q/proofs/n_q_neg_weak_q.k Q-NEG-WEAK-PROOFS /tmp/p1q-weakq-def 1Q-WEAK-BREAKING-RUN-Q 150
  run_claim phase1q/proofs/n_q_neg_weak_q.k Q-NEG-WEAK-PROOFS /tmp/p1q-weakq-def 1Q-NEG-WEAK-INV-Q 150
  run_claim phase1q/proofs/n_q_neg_weak_q.k Q-NEG-WEAK-PROOFS /tmp/p1q-weakq-def 1Q-NEG-C3-WEAK-Q 150
  run_claim phase1q/proofs/n_q_neg_weak_q.k Q-NEG-WEAK-PROOFS /tmp/p1q-weakq-def 1Q-WEAK-EMPTY-ACCEPT-RUN-Q 150
  run_claim phase1q/proofs/n_q_univ_q.k Q-UNIV-PROOFS /tmp/p1q-q-def 1Q-NEG-DEST-Q 150
  run_claim phase1q/proofs/n_q_univ_q.k Q-UNIV-PROOFS /tmp/p1q-q-def 1Q-NEG-UNSAFE-COMMIT-Q 150
  run_claim phase1q/proofs/n_q_univ_q.k Q-UNIV-PROOFS /tmp/p1q-q-def 1Q-NEG-COMMIT-EMPTY-Q 150
  run_claim phase1q/proofs/n_q_univ_q.k Q-UNIV-PROOFS /tmp/p1q-q-def 1Q-NEG-PREFIX-CEX-Q 150
  ;;
M)
  run_claim phase1q/proofs/n_q_neg_mut_stale_q.k Q-NEG-MUT-STALE-PROOFS /tmp/p1q-mutstale-def 1Q-NEG-MUT-STALE-COH 110
  run_claim phase1q/proofs/n_q_neg_mut_stale_q.k Q-NEG-MUT-STALE-PROOFS /tmp/p1q-mutstale-def 1Q-NEG-MUT-STALE-INV 110
  run_claim phase1q/proofs/n_q_neg_mut_flip_q.k Q-NEG-MUT-FLIP-PROOFS /tmp/p1q-mutflip-def 1Q-NEG-MUT-FLIP-INIT 110
  run_claim phase1q/proofs/n_q_neg_mut_flip_q.k Q-NEG-MUT-FLIP-PROOFS /tmp/p1q-mutflip-def 1Q-NEG-MUT-FLIP-RUN 110
  run_claim phase1q/proofs/n_q_neg_mut_omit_q.k Q-NEG-MUT-OMIT-PROOFS /tmp/p1q-mutomit-def 1Q-NEG-MUT-OMIT-GATEMINT 110
  run_claim phase1q/proofs/n_q_neg_mut_omit_q.k Q-NEG-MUT-OMIT-PROOFS /tmp/p1q-mutomit-def 1Q-NEG-MUT-OMIT-C2 110
  ;;
D)
  run_claim phase1q/proofs/n_q_diag_eqform.k Q-DIAG-EQFORM-PROOFS /tmp/p1q-q-def 1Q-DIAG-EQFORM-TRUE 100
  run_claim phase1q/proofs/n_q_diag_eqform.k Q-DIAG-EQFORM-PROOFS /tmp/p1q-q-def 1Q-DIAG-EQFORM-FALSE 100
  run_claim phase1q/proofs/n_q_diag_eqform.k Q-DIAG-EQFORM-PROOFS /tmp/p1q-q-def 1Q-DIAG-FALSE-HYP 100
  run_claim phase1q/proofs/n_q_univ_prefix_unpatched.k Q-UNIV-PREFIX-UNPATCHED-PROOFS /tmp/p1q-q-def 1Q-UNIV-PREFIX-UNPATCHED-Q 300
  ;;
S)
  python3 phase1q/scripts/summarize_1q.py
  ;;
*) note "unknown stage $ST"; exit 1;;
esac
done
note "stages done: $STAGES"
