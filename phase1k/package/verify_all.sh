#!/bin/bash
# SRW3 Implementation Package — verify_all.sh
# Package byte-stability oracle: every packaged file must match
# MANIFEST.sha256.  The tree checked is the COMMITTED package tree — the
# run_all.sh wrapper restores the committed j_golden.json bytes after its
# semantic-equivalence check (corrective K1 protocol), so byte stability is
# asserted over the package as committed, not over an environment-mutated
# copy.  A mismatch means a packaged byte was altered; that is a package
# failure, and the failing paths are printed (K2 disclosure requirement).
#
# Phase 1K CORRECTIVE (K2): the golden-vector spot check is now part of the
# exit status — a vector that is malformed or missing a required field makes
# verify_all.sh FAIL (exit nonzero), even when the manifest itself matches.
set -u
PKG="$(cd "$(dirname "$0")" && pwd)"
cd "$PKG" || exit 1

echo "=== SRW3 Implementation Package — verify_all ==="
echo "--- manifest self-check (sha256 -c MANIFEST.sha256) ---"
if sha256sum -c MANIFEST.sha256 --quiet; then
  echo "OK: $(wc -l < MANIFEST.sha256) files byte-stable (tree as committed; regenerated vectors are restored before this check)"
  RC=0
else
  echo "FAIL: manifest mismatch — failing entries:"
  sha256sum -c MANIFEST.sha256 2>&1 | grep -vE ": OK$" | sed 's/^/  /'
  RC=1
fi
echo "--- manifest fingerprint ---"
sha256sum MANIFEST.sha256
echo "--- golden vector spot check (exit-relevant: K2) ---"
python3 - <<'EOF'
import json, sys
try:
    g = json.load(open("phase1j/vectors/j_golden.json"))
except Exception as e:
    print(f"j_golden.json: MALFORMED ({e})")
    sys.exit(1)
required = {"catj_canon_hex", "catj_canon_len", "catj_root", "jappset_root",
            "jgraph_root", "jpolicy_root", "cfgj_root", "stateroot0",
            "stateroot0p", "stateroot1", "tracedigest0", "footdigest0",
            "footkeys0", "payloaddigest0", "policyctx0", "evidenceid0",
            "blockcommit0", "certid0", "verdict0", "verdict1", "safe0",
            "safe_unsafe", "closure0"}
missing = sorted(k for k in required if k not in g)
print(f"j_golden.json: {len(g)} fields present, parse OK"
      + ("" if not missing else f"; MISSING: {missing}"))
sys.exit(1 if missing else 0)
EOF
VRC=$?
if [ "$VRC" -ne 0 ]; then
  echo "FAIL: golden-vector spot check (see above)"
  RC=1
fi
exit "$RC"
