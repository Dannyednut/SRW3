#!/bin/bash
# Phase 1B: per-claim kprove runs for the three generalized ghost proof files.
# One verdict line per claim; transcripts/audit/ghost_gen_theorem.txt.
# Stages: kompile | claims | all
export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-}"
source /home/z/my-project/tools/env.sh
cd /home/z/my-project/srw3-kevm
OUT="${GEN_OUT:-transcripts/audit/ghost_gen_theorem.txt}"
STAGE="${1:-all}"

if [ "$STAGE" = "kompile" ] || [ "$STAGE" = "all" ]; then
{
echo "## SRW3 Phase 1B — generalized ghost theorem runs (CM2 / CM3 / generalized)"
echo "## date: $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
echo
echo "--- kompile (GHOST-OBS main modules; claim modules stay out of the definition) ---"
timeout 900 kompile proofs/gen/cm2_alias.k --backend haskell --main-module SRW3G2-GHOST-OBS --syntax-module SRW3G2-GHOST-OBS -I k -o proofs/gen/out-cm2 > /tmp/kpg2.log 2>&1
echo "cm2 kompile exit: $?"
timeout 900 kompile proofs/gen/cm3_auth.k --backend haskell --main-module SRW3G3-GHOST-OBS --syntax-module SRW3G3-GHOST-OBS -I k -o proofs/gen/out-cm3 > /tmp/kpg3.log 2>&1
echo "cm3 kompile exit: $?"
timeout 900 kompile proofs/gen/gen_full.k --backend haskell --main-module SRW3G4-GHOST-OBS --syntax-module SRW3G4-GHOST-OBS -I k -o proofs/gen/out-gen > /tmp/kpg4.log 2>&1
echo "gen kompile exit: $?"
echo
} >> "$OUT"
fi

if [ "$STAGE" = "claims" ] || [ "$STAGE" = "all" ]; then
for SET in "proofs/gen/cm2_alias.k SRW3G2 out-cm2" "proofs/gen/cm3_auth.k SRW3G3 out-cm3" "proofs/gen/gen_full.k SRW3G4 out-gen"; do
  ART=$(echo "$SET" | cut -d' ' -f1); PRE=$(echo "$SET" | cut -d' ' -f2); OD=$(echo "$SET" | cut -d' ' -f3)
  LABELS=$(python3 /home/z/my-project/scripts/split_gen_claims.py "$ART" "$PRE" "$PRE")
  echo
  echo "## ---- per-claim verdicts: $ART ----" >> "$OUT"
  for L in $LABELS; do
    if grep -q "^\[${PRE}-${L}\] kprove" "$OUT" 2>/dev/null; then
      echo "[${PRE}-${L}] already recorded, skipping" >> "$OUT"
      continue
    fi
    timeout 3600 kprove "/tmp/gen_claims/${PRE}_${L}.k" -d "proofs/gen/${OD}" -I /tmp -I k \
      --spec-module "${PRE}-GC-${L}" > /tmp/kpg_${PRE}_${L}.txt 2>&1
    E=$?
    T=$(grep -c '#Top' /tmp/kpg_${PRE}_${L}.txt || echo 0)
    W=$(grep -c 'WarnTrivialClaim' /tmp/kpg_${PRE}_${L}.txt || echo 0)
    S=$(grep -c 'WarnStuckClaimState' /tmp/kpg_${PRE}_${L}.txt || echo 0)
    if [ "$E" = "0" ]; then V="PROVED"; else V="FAILED"; fi
    echo "[${PRE}-${L}] kprove exit=$E verdict=$V  #Top=$T WarnTrivial=$W WarnStuck=$S" | tee -a "$OUT"
  done
done
echo
echo "per-claim done ($(date -u +'%Y-%m-%dT%H:%M:%SZ'))" >> "$OUT"
fi
