#!/bin/bash
# SRW3 Phase 1D-R1-FINAL — Part 7 (K demo stages A): abstract demos 13/13 +
# Phase-1B generalized demos 10/10 hs + 10/10 llvm, against the SURVIVING
# frozen compiled definitions (sources sha-verified identical: srw3.k
# da4a895b..., srw3gen.k d583ef0c...). Verdict sequence is diffed against the
# frozen full_matrix_v5 [2] record.
set -u
source /home/z/my-project/tools/env.sh
SRC=/home/z/my-project/srw3-work
KDIR=/home/z/my-project/srw3-kevm
OUT=$SRC/transcripts/audit/phase1d_r1/final_regression_kdemos.txt
: > "$OUT"
log() { echo "$@" | tee -a "$OUT"; }

log "=== SRW3 Phase 1D-R1-FINAL — Part 7: REGRESSION, K demo stages ==="
log "=== generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC') ==="
log "source identity: sha256(srw3.k)  = $(sha256sum $SRC/k/srw3.k | cut -d' ' -f1)"
log "                 sha256(srw3gen.k)= $(sha256sum $SRC/k/srw3gen.k | cut -d' ' -f1)"
log "compiled definitions reused from the surviving pre-reset tree (sources"
log "byte-identical): $KDIR/k/{hs-out,gen-hs-out,gen-llvm-out}"
log ""

# ---------- [K1] abstract demos 13/13 (hs backend) ----------
log "--- [K1] Phase-0 abstract demo suite (13 demos, haskell backend) ---"
ln -sfn "$KDIR/k/hs-out" "$SRC/k/hs-out"
cd "$SRC/k" || exit 1
bash "$SRC/k/run_demos.sh" > /tmp/abstract_demos.txt 2>&1
E=$?
log "[K1] run_demos.sh exit=$E"
# frozen reference: [2] section of full_matrix_v5
awk '/^=== \[2\] Abstract demo suite/{f=1} f&&/^=== \[3\]/{exit} f' \
  "$SRC/transcripts/audit/full_matrix_v5.txt" | \
  rg "^(DEMO:|[0-9]+:(DEMO:|  result))|  result " > /tmp/frozen2.txt || true
rg "^(DEMO:|  result )" /tmp/abstract_demos.txt > /tmp/new2.txt
# normalize (strip line numbers + leading whitespace from both sides)
sed 's/^[0-9]*://; s/^[[:space:]]*//' /tmp/frozen2.txt > /tmp/frozen2n.txt
sed 's/^[[:space:]]*//' /tmp/new2.txt > /tmp/new2n.txt
log "--- verdict-sequence diff (new vs frozen v5 [2]) ---"
if diff /tmp/frozen2n.txt /tmp/new2n.txt > /tmp/diff2.txt 2>&1; then
  log "IDENTICAL — verdict sequence byte-identical to the frozen v5 record:"
  paste -d'|' <(rg -c "DEMO:" /tmp/new2.txt) <(echo) >/dev/null 2>&1
  log "  $(rg -c 'DEMO:' /tmp/new2.txt) demos, $(rg -c '  result ' /tmp/new2.txt) result lines"
else
  log "DIFF DETECTED:"; cat /tmp/diff2.txt | head -20
fi
rg "  result " /tmp/abstract_demos.txt | head -14 >> "$OUT" 2>/dev/null
log ""

# ---------- [K2] generalized demos 10/10 hs ----------
log "--- [K2] Phase-1B generalized demos, haskell backend ---"
cd "$KDIR" || exit 1
bash "$SRC/scripts/run_gen_demos.sh" k/gen-hs-out hs > /tmp/gen_hs.txt 2>&1
E=$?
tail -6 /tmp/gen_hs.txt >> "$OUT"
log "[K2] exit=$E; $(rg -o 'PASS: [0-9]+/10|pass=[0-9]+|passed [0-9]+' /tmp/gen_hs.txt | tail -1)"
rg "GEN demo|PASS|FAIL" /tmp/gen_hs.txt | tail -3 >> "$OUT" 2>/dev/null
log ""

# ---------- [K3] generalized demos 10/10 llvm ----------
log "--- [K3] Phase-1B generalized demos, llvm backend ---"
bash "$SRC/scripts/run_gen_demos.sh" k/gen-llvm-out llvm > /tmp/gen_llvm.txt 2>&1
E=$?
tail -6 /tmp/gen_llvm.txt >> "$OUT"
log "[K3] exit=$E; $(rg -o 'PASS: [0-9]+/10|pass=[0-9]+|passed [0-9]+' /tmp/gen_llvm.txt | tail -1)"
log ""

log "PART7_KDEMOS_DONE"
