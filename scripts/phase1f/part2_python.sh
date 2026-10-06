#!/bin/bash
# SRW3 Phase 1F — Part 2: Python permanent suites (adversarial + mutations).
# The Python mirror (exec_model.py) reproduces the K decision table exactly
# and the cross-layer byte certificate pins Python == K (llvm, real krypto).
set -u
SRC=/home/z/my-project/srw3-kevm
OUT=$SRC/phase1f/transcripts/part2_python_suites.txt
: > "$OUT"
log() { echo "$@" | tee -a "$OUT"; }

log "=== SRW3 Phase 1F — Part 2: PYTHON PERMANENT SUITES ==="
log "=== generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC') ==="
log "sha256(exec_model.py)      = $(sha256sum $SRC/phase1f/python/exec_model.py | cut -d' ' -f1)"
log "sha256(test_exec_verify.py)= $(sha256sum $SRC/phase1f/python/test_exec_verify.py | cut -d' ' -f1)"
log "sha256(exec_mutations.py)  = $(sha256sum $SRC/phase1f/python/exec_mutations.py | cut -d' ' -f1)"
log ""
log "--- [1] test_exec_verify.py (16 verdict cases + cross-layer bytes) ---"
python3 "$SRC/phase1f/python/test_exec_verify.py" 2>&1 | tee -a "$OUT"
log ""
log "--- [2] exec_mutations.py (15 hostile mutations + 2 boundaries) ---"
python3 "$SRC/phase1f/python/exec_mutations.py" 2>&1 | tee -a "$OUT"
log ""
log "PART2_PYTHON_DONE"
