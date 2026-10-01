#!/bin/bash
# Theorem-closure pass, item 1: ghost-state (invariant-as-data) encoding runs.
# Stages: kompile | claims | faith | theorem
source /home/z/my-project/tools/env.sh
cd /home/z/my-project/srw3-kevm
OUT=transcripts/audit/ghost_theorem.txt
STAGE="${1:-kompile}"

case "$STAGE" in
kompile)
  : > "$OUT"
  {
  echo "## Theorem-closure pass item 1 — ghost-state (invariant-as-data) encoding"
  echo "## Artifact: proofs/induction_ghost.k (byte-faithful copy of k/srw3.k:24-530"
  echo "## + 12 //GHOST:-marked lines; certificate scripts/audit_ghost_faithful.py)"
  echo "## Claims: GH-BASE/GH-A/GH-R (GhostMatches obligations), GH-SOUND-I/F"
  echo "## (certificate->real-state bridge), GATE-AGREE, GH-ISO/GH-T1 (non-circular"
  echo "## diagnostics), GH-T/GH-T2 (the forall-n theorem, circularity)."
  echo "## date: $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  echo
  } >> "$OUT"
  echo "--- kompile (SRW3-GHOST-OBS, haskell backend; claim modules stay out of the definition) ---" >> "$OUT"
  timeout 1200 kompile proofs/induction_ghost.k --backend haskell \
    --main-module SRW3-GHOST-OBS --syntax-module SRW3-GHOST-OBS \
    -o proofs/ghost-out >> "$OUT" 2>&1
  echo "kompile exit: $?" >> "$OUT"
  rg -n "Error|error" "$OUT" | grep -v "error-free" | head -5 >> "$OUT" 2>&1
  echo "kompile done"
  ;;
claims)
  echo "--- kprove (GH-BASE..GH-T1: obligations + diagnostics) ---" >> "$OUT"
  timeout 1800 kprove proofs/induction_ghost.k -d proofs/ghost-out \
    --spec-module SRW3-GHOST-CLAIMS > /tmp/kpghost_all.txt 2>&1
  E=$?
  echo "kprove exit: $E  (#Top count: $(rg -c '#Top' /tmp/kpghost_all.txt || echo 0))" >> "$OUT"
  rg -n "label\(GH|label\(GATE|WarnTrivial|WarnStuck|#Top|Error" /tmp/kpghost_all.txt | head -40 >> "$OUT" 2>&1
  echo >> "$OUT"
  echo "claims done (exit $E)"
  ;;
faith)
  echo "--- kprove (copied SRW3-CLAIMS against the instrumented definition —" >> "$OUT"
  echo "    the original Claims 1,2,3,4a,4b must prove unchanged on the copy) ---" >> "$OUT"
  timeout 1800 kprove proofs/induction_ghost.k -d proofs/ghost-out \
    --spec-module SRW3-CLAIMS > /tmp/kpghost_faith.txt 2>&1
  E=$?
  echo "kprove exit: $E  (#Top count: $(rg -c '#Top' /tmp/kpghost_faith.txt || echo 0))" >> "$OUT"
  rg -n "WarnTrivial|WarnStuck|#Top|Error" /tmp/kpghost_faith.txt | head -12 >> "$OUT" 2>&1
  echo >> "$OUT"
  echo "faith done (exit $E)"
  ;;
theorem)
  echo "--- kprove (GH-T + GH-T2 only: the forall-n theorem, circularity) ---" >> "$OUT"
  timeout 1800 kprove proofs/induction_ghost.k -d proofs/ghost-out \
    --spec-module SRW3-GHOST-CLAIMS \
    --claims "GH-T,GH-T2" > /tmp/kpghost_T.txt 2>&1 \
    || timeout 1800 kprove proofs/induction_ghost.k -d proofs/ghost-out \
    --spec-module SRW3-GHOST-CLAIMS > /tmp/kpghost_T.txt 2>&1
  E=$?
  echo "kprove exit: $E  (#Top count: $(rg -c '#Top' /tmp/kpghost_T.txt || echo 0))" >> "$OUT"
  rg -n "WarnTrivial|WarnStuck|#Top|Error|residual|#Not|#Equals" /tmp/kpghost_T.txt | head -30 >> "$OUT" 2>&1
  echo "--- verbatim residual (if any) ---" >> "$OUT"
  rg -n -A 25 "WarnStuckClaimState" /tmp/kpghost_T.txt | head -60 >> "$OUT" 2>&1
  echo >> "$OUT"
  echo "=== done ===" >> "$OUT"
  echo "theorem done (exit $E)"
  ;;
*)
  echo "unknown stage: $STAGE"; exit 1
  ;;
esac
tail -6 "$OUT"
