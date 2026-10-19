#!/usr/bin/env bash
# SRW3 Phase 1M — re-certify the PROVED-class KB claims with captured exit
# codes for the canonical claims-status-kb.csv (the logs are retained fresh).
set -u
source /home/z/my-project/tools/env.sh
export LIBRARY_PATH="$TOOLS/extract/syslibs:$LIBRARY_PATH"
REPO=/home/z/my-project/srw3-1m
INC="-I $REPO/phase1g/semantics -I $REPO/phase1f/semantics -I $REPO/phase1e/semantics -I $REPO/k/phase1d -I $REPO/k/kevm/kproj-e1e/plugin"
OUT=$REPO/phase1m/transcripts/k
for C in KB-VEC-ABC KB-VEC-TWOBLOCK KB-INIT-BASE-HEAD; do
  echo "=== $C ==="
  timeout 1200 kprove $REPO/phase1m/proofs/kb_proofs.k $INC \
    -d /tmp/kb-m2-hs --spec-module KB-PROOFS --claims "$C" > "$OUT/kprove_$C.log" 2>&1
  echo "$C rc=$?"
done
echo "=== KB-OLD-INIT-BASE-HEAD ==="
timeout 1200 kprove $REPO/phase1m/proofs/kb_old_proofs.k $INC \
  -d /tmp/kb-old-m1-hs --spec-module KB-OLD-PROOFS --claims KB-OLD-INIT-BASE-HEAD > "$OUT/kprove_KB-OLD-INIT-BASE-HEAD.log" 2>&1
echo "KB-OLD-INIT-BASE-HEAD rc=$?"
echo "RECERT-DONE"
