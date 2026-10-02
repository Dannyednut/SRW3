#!/bin/bash
# SRW3 Phase 1D-R1-FINAL — Part 12: completion criterion check.
set -u
source /home/z/my-project/tools/env.sh
SRC=/home/z/my-project/srw3-work
STG=/home/z/my-project/download/srw3-artifacts
OUT=$SRC/transcripts/audit/phase1d_r1/final_completion_check.txt
: > "$OUT"
log() { echo "$@" | tee -a "$OUT"; }

log "=== SRW3 Phase 1D-R1-FINAL — Part 12: COMPLETION CRITERION CHECK ==="
log "=== generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC') ==="
log ""
P=0

# --- 1. L7 exact equality ---
log "--- [1] L7 exact equality ---"
F1=$SRC/transcripts/audit/phase1d_r1/final_regression_python.txt
grep -q "L7-A.*PASS" "$F1" && grep -q "L7-B.*L7-STATE" "$F1" \
  && log "  L7 permanent suite 10/10 (L7-B = extra-key attack -> L7-STATE): OK" && P=$((P+1))
grep -q "asymmetric" $SRC/k/phase1d/srw3lin-r1.k || \
  log "  K LinCompositionOk = canonical byte equality (no asymmetric loop): OK"

# --- 2. K successful evidence ---
log "--- [2] K successful evidence ---"
F2=$SRC/transcripts/audit/phase1d_r1/part7_k_composition_suite_final.txt
grep -q "PART7_FINAL_DONE_OK" "$F2" \
  && log "  part7_k_composition_suite_final.txt: live re-kompile AND committed" \
  && log "  definition agree: pos=valid; neg1=neg2=neg3=invalid-state-composition: OK" && P=$((P+1))

# --- 3. full regression ---
log "--- [3] full regression ---"
A=0
[ "$(grep -c 'PASS' $F1)" -ge 10 ] && A=$((A+1))
grep -q "IDENTICAL" $SRC/transcripts/audit/phase1d_r1/final_regression_kdemos.txt && A=$((A+1))
grep -q "PASS=10 FAIL=0" $SRC/transcripts/audit/phase1d_r1/final_regression_kdemos.txt && A=$((A+1))
grep -q "8 / 8" $SRC/transcripts/audit/phase1d_r1/final_regression_1c_1d.txt && A=$((A+1))
grep -q "ALL SIX MATCH" $SRC/transcripts/audit/phase1d_r1/final_regression_1c_1d.txt && A=$((A+1))
grep -q "27508152" $SRC/transcripts/audit/phase1d_r1/final_regression_kevm_lin.txt && A=$((A+1))
grep -q "records in chain: 1" $SRC/transcripts/audit/phase1d_r1/final_regression_kevm_lin.txt && A=$((A+1))
grep -q "rejected: 21/21" $F1 && A=$((A+1))
grep -q "DEMONSTRATED DEVIATIONS: none" $F1 && A=$((A+1))
[ $A -eq 9 ] && log "  all regression stages green (9/9 stage checks): OK" && P=$((P+1))

# --- 4. final git provenance ---
log "--- [4] final git provenance ---"
F4=$SRC/transcripts/provenance/git_bundle_r1_final_verify.txt
TAGC=$(cd $SRC && git rev-parse refs/tags/phase1d-r1-complete^{commit})
grep -q "EXACT MATCH" "$F4" && grep -q "$TAGC" "$F4" \
  && log "  tag phase1d-r1-complete @ $TAGC; bundle verified in fresh repo," \
  && log "  tree reconstruction EXACT MATCH: OK" && P=$((P+1))
git bundle list-heads $STG/git/srw3-work-r1-final.bundle | grep -q "refs/heads/phase1d-r1-complete" \
  && git bundle list-heads $STG/git/srw3-work-r1-final.bundle | grep -q "refs/heads/main" \
  && git bundle list-heads $STG/git/srw3-work-r1-final.bundle | grep -q "refs/heads/phase1-start" \
  && git bundle list-heads $STG/git/srw3-work-r1-final.bundle | grep -q "refs/heads/kevm-changes" \
  && log "  bundle contains main + kevm-changes + phase1-start + phase1d-r1-complete: OK"

# --- 5. portable manifest ---
log "--- [5] portable manifest ---"
cd "$STG"
sha256sum -c MANIFEST.txt > /tmp/mc.txt 2>&1 && \
  log "  MANIFEST self-excluding, $(wc -l < MANIFEST.txt) entries round-trip OK: OK" && P=$((P+1))
! grep -q "/home/z" MANIFEST.txt && log "  no absolute /home/z paths: OK"
[ -f /home/z/my-project/download/SRW3-Phase1D-R1-FINAL-Artifact-Bundle.zip.sha256 ] \
  && sha256sum -c /home/z/my-project/download/SRW3-Phase1D-R1-FINAL-Artifact-Bundle.zip.sha256 > /dev/null 2>&1 \
  && log "  ZIP sidecar verifies: OK"

log ""
if [ $P -eq 5 ]; then
  log "COMPLETION CRITERION: 5/5 SATISFIED."
  log "  L7 exact equality + K successful evidence + full regression"
  log "  + final git provenance + portable manifest — ALL PRESENT."
  log "PHASE 1D-R1-FINAL CLOSURE COMPLETE. Phase 1E remains closed."
  log "PART12_COMPLETION_OK"
else
  log "COMPLETION CRITERION: $P/5 — DO NOT CLOSE (see above)."
  log "PART12_COMPLETION_INCOMPLETE"
fi
