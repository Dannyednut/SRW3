#!/bin/bash
# Per-claim kprove runs for the ghost artifact — one verdict line per claim.
source /home/z/my-project/tools/env.sh
cd /home/z/my-project/srw3-kevm
OUT=transcripts/audit/ghost_theorem.txt
LABELS=$(python3 /home/z/my-project/scripts/split_ghost_claims.py)
{
echo
echo "## ---- per-claim verdicts (isolated kprove runs) ----"
echo "## date: $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
} >> "$OUT"
for L in $LABELS; do
  timeout 1200 kprove /tmp/ghost_claims/c_$L.k -d proofs/ghost-out -I /tmp \
    --spec-module SRW3-GC-$L > /tmp/kpg_$L.txt 2>&1
  E=$?
  T=$(rg -c '#Top' /tmp/kpg_$L.txt || echo 0)
  W=$(rg -c 'WarnTrivialClaim' /tmp/kpg_$L.txt || echo 0)
  S=$(rg -c 'WarnStuckClaimState' /tmp/kpg_$L.txt || echo 0)
  if [ "$E" = "0" ]; then V="PROVED"; else V="FAILED"; fi
  echo "[$L] kprove exit=$E verdict=$V  #Top=$T WarnTrivial=$W WarnStuck=$S" >> "$OUT"
done
echo "per-claim done"
tail -12 "$OUT"
