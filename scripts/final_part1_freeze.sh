#!/bin/bash
# SRW3 Phase 1D-R1-FINAL — Part 1: freeze the current (preclosure) R1 state.
# Records: source-tree hash, git status, ZIP SHA-256, toolchain versions.
# Preserves the current artifact bundle unchanged as SRW3-Phase1D-R1-preclosure.
set -u
source /home/z/my-project/tools/env.sh
ROOT=/home/z/my-project
SRC=$ROOT/srw3-work
DL=$ROOT/download
OUT=$SRC/transcripts/audit/phase1d_r1/part0_final_freeze.txt

: > "$OUT"
log() { echo "$@" | tee -a "$OUT"; }

log "=== SRW3 Phase 1D-R1-FINAL — Part 1: PRECLOSURE STATE FREEZE ==="
log "=== generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC') ==="
log ""
log "--- git state ---"
log "branch: $(cd $SRC && git branch --show-current)"
log "head:   $(cd $SRC && git rev-parse HEAD)"
log "parent: $(cd $SRC && git log --format=%H -n1 HEAD^ 2>/dev/null)"
log "remote: $(cd $SRC && git config --get remote.origin.url)"
log ""
log "--- git status ---"
cd "$SRC"
git status --porcelain=v1 >> /tmp/final_freeze_status.txt 2>&1
if [ -s /tmp/final_freeze_status.txt ]; then
  while IFS= read -r l; do log "$l"; done < /tmp/final_freeze_status.txt
else
  log "(clean working tree)"
fi
rm -f /tmp/final_freeze_status.txt
log ""
log "--- source-tree hash (committed tree object) ---"
log "git worktree hash: $(git rev-parse HEAD^{tree})"
log "git archive sha256: $(git archive HEAD | sha256sum | cut -d' ' -f1)"
log ""
log "--- toolchain versions (pinned recipe rebuild, reset #6) ---"
log "K:        $(kompile --version 2>&1 | head -1)"
log "z3:       $(z3 --version 2>&1)"
log "clang:    $T/extract/llvm/usr/bin/clang++-15 --version | head -1"
log "clang:    $($T/extract/llvm/usr/bin/clang++-15 --version 2>/dev/null | head -1)"
log "kevm src: v1.0.921 ($KEVMSRC)"
log "plugin:   blockchain-k-plugin @ 207ae512 ($PLUGIN)"
log "shim:     $(ls -la $SRC/k/phase1c/shim/krypto_shim.cpp 2>/dev/null | awk '{print $5" bytes (source)"}')"
log ""
log "--- current artifact bundle (preclosure) ---"
ZIP=$DL/SRW3-Phase1D-R1-Artifact-Bundle.zip
log "bundle: SRW3-Phase1D-R1-Artifact-Bundle.zip"
log "size:   $(stat -c %s "$ZIP" 2>/dev/null) bytes"
log "sha256: $(sha256sum "$ZIP" | cut -d' ' -f1)"
log ""
log "--- preserve unchanged as preclosure bundle ---"
cp -f "$ZIP" "$DL/SRW3-Phase1D-R1-preclosure.zip"
cp -f "$ZIP.sha256" "$DL/SRW3-Phase1D-R1-preclosure.zip.sha256" 2>/dev/null || \
  sha256sum "$ZIP" > "$DL/SRW3-Phase1D-R1-preclosure.zip.sha256"
log "preserved: SRW3-Phase1D-R1-preclosure.zip"
log "sha256:    $(sha256sum "$DL/SRW3-Phase1D-R1-preclosure.zip" | cut -d' ' -f1)"
log ""
log "--- transcript preservation note ---"
log "ALL prior transcripts are preserved, including the stale failed K"
log "composition transcript part7_k_composition_suite.txt (krun loader"
log "failure, missing libLLVM-15.so.1 on LD_LIBRARY_PATH) and the note"
log "part7_k_composition_note.txt whose claimed success it did not evidence."
log "Neither file will be modified or deleted; the FINAL successful run is"
log "captured separately in part7_k_composition_suite_final.txt."
log ""
log "PART1_FINAL_FREEZE_DONE"
