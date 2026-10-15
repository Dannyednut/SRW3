#!/bin/bash
# SRW3 Implementation Package — run_all.sh
# Runs the FULL Python verification tier from THIS package tree.
# One transcript per tier, written to OUT-DIR (default: ../executions).
# Every runner exits with its failure count; the summary table is printed.
#
# Notes:
# - attacks_1j REGENERATES phase1j/vectors/j_golden.json in place; verify_all.sh
#   re-checks the MANIFEST afterwards, which is the byte-stability oracle for
#   the regenerated vectors.
# - Tiers 1e/1f/1g (and r2) require the install.sh compat layer (the frozen
#   files hardcode their historical checkout prefixes; the package never
#   edits frozen bytes).
set -u
PKG="$(cd "$(dirname "$0")" && pwd)"
OUT="${1:-$(dirname "$PKG")/executions}"
mkdir -p "$OUT"

run() { # run <name> <cmd...>
  local name="$1"; shift
  echo "--- $name: $*"
  ( "$@" ) > "$OUT/$name.txt" 2>&1
  local rc=$?
  echo "    exit=$rc  transcript: $OUT/$name.txt"
  return $rc
}

runcd() { # runcd <name> <dir> <cmd...> — run with CWD=<dir> (a frozen runner
          # may resolve its KX transcripts relative to the CWD, as the
          # historical regression driver did)
  local name="$1" dir="$2"; shift 2
  echo "--- $name: (cd $dir) $*"
  ( cd "$dir" && "$@" ) > "$OUT/$name.txt" 2>&1
  local rc=$?
  echo "    exit=$rc  transcript: $OUT/$name.txt"
  return $rc
}

echo "=== SRW3 Implementation Package — Python verification tier ==="
echo "output: $OUT"
# The frozen suites locate their sibling modules via PYTHONPATH (the historical
# regression driver supplied it the same way); the package exports its own
# module dirs — an additive entry-point concern, no frozen byte is edited.
export PYTHONPATH="$PKG/python-gen:$PKG/phase1e/python:$PKG/phase1f/python:$PKG/phase1g/python:$PKG/phase1i-r1/python:$PKG/phase1i-r2/python:$PKG/phase1i-r3/python:$PKG/phase1j/python${PYTHONPATH:+:$PYTHONPATH}"
FAILS=0
run unittests_1j  python3 "$PKG/phase1j/tests/test_security_closure.py" -v || FAILS=$((FAILS+1))
run attacks_1j    python3 "$PKG/phase1j/python/run_j_attacks.py"        || FAILS=$((FAILS+1))
runcd regression_r1 "$PKG/phase1i-r1/python" python3 run_r1_attacks.py    || FAILS=$((FAILS+1))
run regression_r2 python3 "$PKG/phase1i-r2/python/run_r2_attacks.py"    || FAILS=$((FAILS+1))
run regression_r3 python3 "$PKG/phase1i-r3/python/run_r3_attacks.py"    || FAILS=$((FAILS+1))
run suite_1e      python3 "$PKG/phase1e/python/test_auth_verify.py" -v  || FAILS=$((FAILS+1))
run suite_1f      python3 "$PKG/phase1f/python/test_exec_verify.py" -v  || FAILS=$((FAILS+1))
run suite_1g      python3 "$PKG/phase1g/python/test_authz_verify.py" -v || FAILS=$((FAILS+1))

echo
echo "=== summary ==="
grep -h -E "PASS / |OK|byte checks|verdict cases" "$OUT"/*.txt 2>/dev/null | sed 's/^/  /' | head -20
echo "tiers with nonzero exit: $FAILS (expected 0)"
exit "$FAILS"