#!/bin/bash
# SRW3 Phase 1D-R1-FINAL — Part 7 (python stages): L7 suite, comparison audit,
# mutation harness, Phase-0 baseline unittests. Historical evidence files are
# only CHECKED, never modified.
set -u
source /home/z/my-project/tools/env.sh
SRC=/home/z/my-project/srw3-work
OUT=$SRC/transcripts/audit/phase1d_r1/final_regression_python.txt
: > "$OUT"
log() { echo "$@" | tee -a "$OUT"; }

log "=== SRW3 Phase 1D-R1-FINAL — Part 7: REGRESSION, python stages ==="
log "=== generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC') ==="
log ""

# ---------- [P1] Phase-0 baseline: 15/15 ----------
log "--- [P1] Phase-0 Python baseline (unittest discover) ---"
cd /home/z/my-project/download/srw3-artifacts/baseline/reference-implementation || exit 1
PYTHONPATH=. python3 -m unittest discover -s tests -v > /tmp/p0py.txt 2>&1
E=$?
tail -4 /tmp/p0py.txt >> "$OUT" 2>/dev/null
R=$(rg -o "Ran [0-9]+ tests" /tmp/p0py.txt | head -1)
OKC=$(rg -c "OK" /tmp/p0py.txt || echo 0)
log "[P1] exit=$E; $R; result-lines: $(rg -c '^OK' /tmp/p0py.txt || echo 0)"
log ""

# ---------- [P2] L7 permanent suite: 10/10 ----------
log "--- [P2] L7 permanent adversarial suite (post-fix, 10 classes) ---"
cd "$SRC/python-gen" || exit 1
python3 test_lin_verify_L7.py > /tmp/l7suite.txt 2>&1
E=$?
cat /tmp/l7suite.txt >> "$OUT"
log "[P2] exit=$E (0 = 10/10 PASS)"
log ""

# ---------- [P3] historical L7 attack reproduction file preserved ----------
log "--- [P3] historical evidence preserved (not re-run: pre-fix expectations) ---"
log "python-gen/test_lin_attack_L7.py: $(ls -la $SRC/python-gen/test_lin_attack_L7.py | awk '{print $5}') bytes, header declares PRE-FIX expectations"
log "transcripts/audit/phase1d_r1/l7_attack_prefix.txt: $(ls -la $SRC/transcripts/audit/phase1d_r1/l7_attack_prefix.txt | awk '{print $5}') bytes (frozen pre-fix transcript)"
log ""

# ---------- [P4] comparison audit: 33 probes ----------
log "--- [P4] full comparison audit (Part IV, 33 probes) ---"
cd "$SRC/python-gen" || exit 1
python3 audit_comparisons.py > /tmp/cmpaudit.txt 2>&1
E=$?
tail -25 /tmp/cmpaudit.txt >> "$OUT"
log "[P4] exit=$E"
NPASS=$(rg -c "ok=True|OK|PASS" /tmp/cmpaudit.txt || echo 0)
log "[P4] pass-marker lines: $NPASS"
log ""

# ---------- [P5] hostile mutation harness: 21 classes ----------
log "--- [P5] hostile-input mutation harness (Part VI, 21 classes) ---"
cd "$SRC/python-gen" || exit 1
python3 audit_mutations_21.py > /tmp/mut21.txt 2>&1
E=$?
tail -30 /tmp/mut21.txt >> "$OUT"
log "[P5] exit=$E"
NREJ=$(rg -c "rejected|REJECTED" /tmp/mut21.txt || echo 0)
log "[P5] rejection-marker lines: $NREJ"
log "UNRESOLVED marker present: $(rg -c 'UNRESOLVED VERIFIER SOUNDNESS ISSUE' /tmp/mut21.txt || echo 0) (0 = clean)"
log ""

log "PART7_PYTHON_DONE"
