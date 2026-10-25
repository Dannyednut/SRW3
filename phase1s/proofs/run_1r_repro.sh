#!/bin/bash
# SRW3 Phase 1S — the §1 baseline reproduction sequence of record
# (audit/baseline-1s.md §5, packaged as one script).
# Level III only; no consensus-integration claim.
set -u
cd "$(dirname "$0")/../.." || exit 1
REPO=$PWD
source /home/z/my-project/tools/env.sh
INC="-I $REPO/phase1n/semantics -I $REPO/phase1m/semantics -I $REPO/phase1g/semantics -I $REPO/phase1f/semantics -I $REPO/phase1e/semantics -I $REPO/k/phase1d -I $REPO/k/kevm/kproj-e1e/plugin"
LOGS=$REPO/phase1s/transcripts/1r-repro
mkdir -p "$LOGS"

echo "== kompile the QS definition of record =="
[ -d /tmp/p1r-qs-def ] || kompile phase1r/semantics/abs-machine-qs.k --backend haskell \
  --main-module SRW3N-ABS-QS $INC -o /tmp/p1r-qs-def
echo "kompile rc=$?"

echo "== the central theorem (standalone; the claim of record) =="
T0=$(date +%s)
timeout 560 kprove phase1r/proofs/n_r_univ_qs.k $INC -d /tmp/p1r-qs-def \
  --spec-module R-UNIV-QS-PROOFS --claims 1R-UNIV-COMPOSED-QS \
  > "$LOGS/kprove_1R-UNIV-COMPOSED-QS.log" 2>&1
echo "1R-UNIV-COMPOSED-QS rc=$? wall=$(($(date +%s)-T0))s"

echo "== the depth-1/2/3 genuineness probes =="
for D in 1 2 3; do
  T0=$(date +%s)
  timeout 560 kprove phase1r/proofs/n_r_univ_qs.k $INC -d /tmp/p1r-qs-def \
    --spec-module R-UNIV-QS-PROOFS --claims 1R-UNIV-COMPOSED-QS --depth $D \
    > "$LOGS/kprove_1R-UNIV-COMPOSED-QS-depth$D.log" 2>&1
  echo "depth$D rc=$? wall=$(($(date +%s)-T0))s"
done

echo "== the structural witness and the generators (fail-closed) =="
python3 phase1r/scripts/verify_grid_1r.py
python3 phase1r/scripts/make_abs_qs.py > /dev/null && echo "make_abs_qs roundtrip OK"
python3 phase1r/scripts/make_tag0_family_1r.py > /dev/null && echo "make_tag0_family roundtrip OK"

echo "== the gate of record =="
python3 phase1r/scripts/summarize_1r.py | tail -2
