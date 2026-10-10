#!/usr/bin/env bash
# SRW3 Phase 1I-R3 — frozen regression re-run (handoff §7 "backwards isolation"
# + the R2 §9 baseline list).  All suites run from the R3 branch checkout with
# the FROZEN trees untouched; transcripts are saved under phase1i-r3/
# transcripts/regression/.  Baseline expectations (from the R2 handoff):
#   test_lineage_r1.py            11/11
#   test_security_context_r1.py   26/26
#   run_attack_matrix.py          30/30
#   run_determinism_i.py          15/15
#   run_reorg_replay.py           17/17
#   run_forkchoice_compare.py     16/16
#   run_r1_attacks.py             48/48
#   run_r2_attacks.py             87/87   (the R2 suite, frozen tree)
# plus the NEW R3 suites:
#   unittest tests/              21/21
#   run_r3_attacks.py           181/181
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
OUT="$HERE/regression"
mkdir -p "$OUT"
cd "$REPO"

run_py() { # run_py <label> <path> <args...>
  local label="$1"; shift
  { echo "### regression: $label"
    echo "# command: python3 $*"
    echo "# host: $(uname -m), python $(python3 --version 2>&1)"
    echo "# --- output ---"
    python3 "$@" 2>&1
    echo "# --- exit: $? ---"
  } > "$OUT/$label.txt" 2>&1
  local rc=$?
  echo "$label: $(tail -3 "$OUT/$label.txt" | head -1) (exit $rc)"
}

run_py test_lineage_r1          phase1h/python/test_lineage_r1.py
run_py test_security_context_r1 phase1h/python/test_security_context_r1.py
run_py run_attack_matrix        phase1i/python/run_attack_matrix.py
run_py run_determinism_i        phase1i/python/run_determinism_i.py
run_py run_reorg_replay         phase1i/python/run_reorg_replay.py
run_py run_forkchoice_compare   phase1i/python/run_forkchoice_compare.py
# run_r1_attacks reads its own demo transcripts via RELATIVE paths — run it
# from phase1i-r1/python (as the R1/R2 sessions did).
{ echo "### regression: run_r1_attacks (cwd=phase1i-r1/python)"
  echo "# command: (cd phase1i-r1/python && python3 run_r1_attacks.py)"
  echo "# --- output ---"
  ( cd phase1i-r1/python && python3 run_r1_attacks.py 2>&1 )
  echo "# --- exit: $? ---"
} > "$OUT/run_r1_attacks.txt" 2>&1
echo "run_r1_attacks: $(rg -o 'TOTAL: [0-9/]+ PASS' "$OUT/run_r1_attacks.txt" | tail -1)"
# run_r2_attacks hardcodes /home/z/my-project/srw3b-work path inserts (stale in
# this sandbox — disclosed); PYTHONPATH supplies the live frozen-module dirs.
{ echo "### regression: run_r2_attacks (PYTHONPATH pre-seeded)"
  echo "# command: PYTHONPATH=<repo python dirs> python3 phase1i-r2/python/run_r2_attacks.py"
  echo "# --- output ---"
  PYTHONPATH="$REPO/python-gen:$REPO/phase1e/python:$REPO/phase1f/python:$REPO/phase1g/python:$REPO/phase1i-r1/python" \
    python3 phase1i-r2/python/run_r2_attacks.py 2>&1
  echo "# --- exit: $? ---"
} > "$OUT/run_r2_attacks.txt" 2>&1
echo "run_r2_attacks: $(rg -o 'R2 adversarial suite: [0-9]+ PASS / [0-9]+ FAIL' "$OUT/run_r2_attacks.txt" | tail -1)"
run_py r3_unittest_tests        -m unittest discover -s phase1i-r3/tests
run_py run_r3_attacks           phase1i-r3/python/run_r3_attacks.py
echo "regression re-run complete -> $OUT"
