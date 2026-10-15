#!/bin/bash
# SRW3 Implementation Package — run_all.sh
# Runs the FULL Python verification tier from THIS package tree.
# One transcript per tier, written to OUT-DIR (default: ../executions).
# Every runner exits with its failure count; the summary table is printed.
#
# Phase 1K CORRECTIVE protocol (verification repair, K1) — the golden-vector
# regeneration is now SEMANTIC-EQUIVALENCE-CHECKED and the committed bytes are
# RESTORED before any manifest check:
#   1. the committed j_golden.json bytes are saved before the 1J attack tier;
#   2. the frozen J attack script runs and regenerates the vector in place
#      (frozen bytes are never edited — the regeneration is the script's own
#      documented write-back, and the package wrapper owns the copy lifecycle);
#   3. the regenerated object is parsed and compared key/value-for-key with
#      the saved original — ANY semantic difference fails the tier;
#   4. the original frozen bytes are restored by a trap-guarded cleanup,
#      whether the runner succeeds or fails;
#   5. verify_all.sh (the MANIFEST byte-stability oracle) runs ONLY after
#      restoration — so byte-stability is asserted over the package tree as
#      committed, never over an environment-mutated copy;
#   6. the semantic-equivalence result is recorded separately
#      (vector_semantics.txt) while the package retains the frozen vector's
#      exact committed bytes.
# Rationale: byte-level stability of a regenerated JSON is environment-
# dependent (float repr / library builds); SEMANTIC equivalence is the
# reproducible property, byte stability of the RESTORED tree is the package
# property.  The saved d32ad13 verifier conflated the two and failed on a
# fresh run (see executions/archive/verify_all_d32ad13_FAILED.txt).
#
# Notes:
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

# ---- golden-vector protection (corrective K1 protocol, steps 1-2) -----------
VEC="$PKG/phase1j/vectors/j_golden.json"
VEC_SAVE="$(mktemp /tmp/j_golden_committed.XXXXXX.json)"
cp "$VEC" "$VEC_SAVE"
echo "vector protection: committed bytes saved ($(wc -c < "$VEC_SAVE") bytes)"

restore_vec() { cp "$VEC_SAVE" "$VEC"; }
trap restore_vec EXIT

# step 2: the frozen runner regenerates the vector in place
run unittests_1j  python3 "$PKG/phase1j/tests/test_security_closure.py" -v || FAILS=$((FAILS+1))
run attacks_1j    python3 "$PKG/phase1j/python/run_j_attacks.py"        || FAILS=$((FAILS+1))

# ---- steps 3-4: semantic equivalence check, then restore --------------------
echo "--- vector semantic equivalence (regenerated vs committed) ---"
python3 - "$VEC_SAVE" "$VEC" > "$OUT/vector_semantics.txt" 2>&1 <<'EOF'
import json, sys
old_p, new_p = sys.argv[1], sys.argv[2]
print("=== golden-vector semantic equivalence (corrective K1 protocol) ===")
print(f"committed object : {old_p}")
print(f"regenerated object: {new_p}")
try:
    old = json.load(open(old_p))
except Exception as e:
    print(f"FAIL: committed vector unreadable: {e}"); sys.exit(2)
try:
    new = json.load(open(new_p))
except Exception as e:
    print(f"FAIL: regenerated vector unreadable: {e}"); sys.exit(2)
ok = True
for k in sorted(set(old) | set(new)):
    if k not in new:
        print(f"FAIL: key missing in regenerated object: {k}"); ok = False
    elif k not in old:
        print(f"FAIL: key absent from committed object: {k}"); ok = False
    elif old[k] != new[k]:
        print(f"FAIL: value differs for {k}:\n  committed  = {old[k]!r}\n  regenerated= {new[k]!r}"); ok = False
if ok:
    print(f"SEMANTICALLY IDENTICAL: all {len(old)} fields equal key/value-for-key")
    print("committed bytes restored by the wrapper (trap-guarded); "
          "byte stability is asserted by verify_all.sh over the committed tree")
sys.exit(0 if ok else 1)
EOF
SEMRC=$?
cat "$OUT/vector_semantics.txt"
echo "    semantic-compare exit=$SEMRC  transcript: $OUT/vector_semantics.txt"
restore_vec
trap - EXIT
rm -f "$VEC_SAVE"
if [ "$SEMRC" -ne 0 ]; then
  echo "FAIL: regenerated golden vector is semantically DIFFERENT from the committed one"
  FAILS=$((FAILS+1))
fi

# ---- remaining tiers --------------------------------------------------------
runcd regression_r1 "$PKG/phase1i-r1/python" python3 run_r1_attacks.py    || FAILS=$((FAILS+1))
run regression_r2 python3 "$PKG/phase1i-r2/python/run_r2_attacks.py"    || FAILS=$((FAILS+1))
run regression_r3 python3 "$PKG/phase1i-r3/python/run_r3_attacks.py"    || FAILS=$((FAILS+1))
run suite_1e      python3 "$PKG/phase1e/python/test_auth_verify.py" -v  || FAILS=$((FAILS+1))
run suite_1f      python3 "$PKG/phase1f/python/test_exec_verify.py" -v  || FAILS=$((FAILS+1))
run suite_1g      python3 "$PKG/phase1g/python/test_authz_verify.py" -v || FAILS=$((FAILS+1))

echo
echo "=== summary ==="
grep -h -E "PASS / |OK|byte checks|verdict cases" "$OUT"/*.txt 2>/dev/null | sed 's/^/  /' | head -20

# ---- step 5: manifest oracle AFTER restoration ------------------------------
echo "--- verify_all (manifest byte-stability, post-restoration) ---"
if bash "$PKG/verify_all.sh" > "$OUT/verify_all.txt" 2>&1; then
  echo "    verify_all: PASS  transcript: $OUT/verify_all.txt"
else
  echo "    verify_all: FAIL  transcript: $OUT/verify_all.txt (failing paths listed there)"
  FAILS=$((FAILS+1))
fi

echo "tiers with nonzero exit: $FAILS (expected 0)"
exit "$FAILS"
