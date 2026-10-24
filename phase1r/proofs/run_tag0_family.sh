#!/bin/bash
# SRW3 Phase 1R — the tag-0 family runner (12 members, sequential).
# Usage: bash phase1r/proofs/run_tag0_family.sh <idx...>   (default: all)
# The init-accept member (idx 1) runs with --trusted 1R-UNIV-TAG1-Q.
set -u
cd "$(dirname "$0")/../.." || exit 1
REPO=$PWD
source /home/z/my-project/tools/env.sh
export LIBRARY_PATH="$TOOLS/extract/syslibs:$LIBRARY_PATH"
INC="-I $REPO/phase1n/semantics -I $REPO/phase1m/semantics -I $REPO/phase1g/semantics -I $REPO/phase1f/semantics -I $REPO/phase1e/semantics -I $REPO/k/phase1d -I $REPO/k/kevm/kproj-e1e/plugin"
LOGS=$REPO/phase1r/transcripts/k
EC=$REPO/phase1r/claims/exit-codes-1r.csv
MEMBERS=${@:-1 2 3 4 5 6 7 8 9 10 11 12}
for I in $MEMBERS; do
  C=1R-T0F-$I-Q
  T=300
  TR=""
  [ "$I" = "1" ] && TR="--trusted 1R-UNIV-TAG1-Q"
  T0=$(date +%s)
  timeout $T kprove phase1r/proofs/n_r_tag0_family.k $INC -d /tmp/p1q-q-def \
    --spec-module R-TAG0-FAM-PROOFS --claims "$C" $TR \
    > "$LOGS/kprove_$C.log" 2>&1
  RC=$?; T1=$(date +%s)
  echo "$C,$RC,$T,$((T1-T0))" >> "$EC"
  echo "[T0F] $C rc=$RC wall=$((T1-T0))s"
done
echo "T0F_DONE"
