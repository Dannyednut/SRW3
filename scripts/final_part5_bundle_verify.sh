#!/bin/bash
# SRW3 Phase 1D-R1-FINAL — Part 5: git bundle verification in a fresh empty repo.
set -u
source /home/z/my-project/tools/env.sh
SRC=/home/z/my-project/srw3-work
BUNDLE=/home/z/my-project/download/srw3-artifacts/git/srw3-work-r1-final.bundle
OUT=$SRC/transcripts/provenance/git_bundle_r1_final_verify.txt
mkdir -p "$SRC/transcripts/provenance"
: > "$OUT"
log() { echo "$@" | tee -a "$OUT"; }

log "=== SRW3 Phase 1D-R1-FINAL — Part 5: FINAL GIT BUNDLE VERIFICATION ==="
log "=== generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC') ==="
log ""
log "bundle: git/srw3-work-r1-final.bundle"
log "bundle size: $(stat -c %s "$BUNDLE") bytes"
log "bundle sha256: $(sha256sum "$BUNDLE" | cut -d' ' -f1)"
log ""
log "--- 1. git bundle verify (in the source repository) ---"
cd "$SRC"
git bundle verify "$BUNDLE" 2>&1 | tee -a "$OUT"
log ""
log "--- 2. bundle ref inventory ---"
git bundle list-heads "$BUNDLE" >> "$OUT"
log "refs recorded above: main, kevm-changes, phase1-start, phase1b, phase1c,"
log "phase1d-r1-complete (branch @ b52427a...), refs/tags/phase1d-r1-complete."
log ""
log "--- 3. fresh empty repository reconstruction ---"
rm -rf /tmp/srw3-fresh-$$
mkdir -p /tmp/srw3-fresh-$$
cd /tmp/srw3-fresh-$$
git init -q fresh
cd fresh
git config user.email "verify@local"; git config user.name "verify"
git fetch -q "$BUNDLE" 'refs/heads/*:refs/heads/*' 'refs/tags/*:refs/tags/*'
log "fetched refs: $(git for-each-ref --format='%(refname:short)' | sort | tr '\n' ' ')"
git checkout -q phase1d-r1-complete
log "checked out: phase1d-r1-complete @ $(git rev-parse HEAD)"
log "commit parent: $(git rev-parse HEAD^)"
log "commit subject: $(git log --format=%s -n1)"
log ""
log "--- 4. exact source-tree reconstruction check ---"
FRESH_ARCHIVE=$(git archive HEAD | sha256sum | cut -d' ' -f1)
SRC_ARCHIVE=$(cd "$SRC" && git archive refs/tags/phase1d-r1-complete | sha256sum | cut -d' ' -f1)
log "fresh repo  git archive sha256: $FRESH_ARCHIVE"
log "source repo git archive sha256: $SRC_ARCHIVE"
if [ "$FRESH_ARCHIVE" = "$SRC_ARCHIVE" ]; then
  log "TREE RECONSTRUCTION: EXACT MATCH — the fresh repository reconstructs"
  log "the final R1 source tree byte-for-byte."
else
  log "TREE RECONSTRUCTION: MISMATCH — investigate before closure."
fi
log ""
log "--- 5. working-tree spot checks (final artifacts present) ---"
for f in SRW3-Phase1D-R1-FINAL-Report.md k/phase1d/srw3lin-r1.k \
         transcripts/audit/phase1d_r1/part7_k_composition_suite_final.txt \
         transcripts/audit/phase1d_r1/final_crosslayer_bytes.txt \
         python-gen/lin_verify.py k/phase1c/shim/krypto_shim.cpp; do
  [ -f "$f" ] && log "  present: $f" || log "  MISSING: $f"
done
log ""
rm -rf /tmp/srw3-fresh-$$
log "PART5_BUNDLE_VERIFY_DONE"
