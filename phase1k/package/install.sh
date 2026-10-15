#!/bin/bash
# SRW3 Implementation Package — install.sh
# Three steps, nothing else: interpreter check; the DISCLOSED path-compat
# layer for the three frozen hardcoded-path files (zero frozen-byte edits);
# self-integrity over MANIFEST.sha256.
#
# Usage:
#   ./install.sh                  default mode (refuse to clobber)
#   ./install.sh --adopt-quarantine  move pre-existing targets aside, then link
#   ./install.sh --no-compat      skip the compat layer entirely
set -u
PKG="$(cd "$(dirname "$0")" && pwd)"
MODE="${1:---compat}"

echo "=== SRW3 Implementation Package install (v1.0.0, Phase 1K) ==="
echo "package root: $PKG"

# ---- 1. interpreter ---------------------------------------------------------
command -v python3 >/dev/null 2>&1 || { echo "FATAL: python3 not found"; exit 1; }
PV=$(python3 -c 'import sys; print("%d.%d" % sys.version_info[:2])')
case "$PV" in 3.1[0-9]|3.[2-9][0-9]) ;; *) echo "FATAL: python3 >= 3.10 required, got $PV"; exit 1;; esac
echo "python3 $PV OK"
python3 -c 'import hashlib' || { echo "FATAL: hashlib unavailable"; exit 1; }
# lin_verify.py (the 1D-R1 verifier core every tier imports) needs coincurve
# (secp256k1).  Probe and give the precise remediation — never install
# silently: the environment stays the operator's.
python3 -c 'import coincurve' 2>/dev/null || {
  echo "FATAL: the 'coincurve' package is required (pip install coincurve)"; exit 1;
}
echo "coincurve OK"

# ---- 2. path-compat layer (disclosed) ---------------------------------------
# The frozen 1E/1F/1G test files and the R2 runner hardcode their historical
# checkout prefixes.  The package resolves them by symlink, never by editing
# a frozen byte.  Targets: exactly the two hardcoded prefixes.
COMPAT_TARGETS="/home/z/my-project/srw3-kevm /home/z/my-project/srw3b-work"
FAIL=0
if [ "$MODE" = "--no-compat" ]; then
  echo "compat layer: SKIPPED (--no-compat); hardcoded-path suites will not import"
else
  for T in $COMPAT_TARGETS; do
    if [ -L "$T" ] && [ "$(readlink "$T")" = "$PKG" ]; then
      echo "compat ok:   $T -> $PKG"; continue
    fi
    if [ -e "$T" ]; then
      if [ "$MODE" = "--adopt-quarantine" ]; then
        Q="$T.phase1k-quarantined.$(date +%s)"
        mv "$T" "$Q" || { echo "FATAL: cannot quarantine $T"; exit 1; }
        ln -s "$PKG" "$T" || { echo "FATAL: cannot link $T"; exit 1; }
        echo "compat:      $T adopted (pre-existing tree moved to $Q)"
      else
        echo "REFUSE:      $T already exists (re-run with --adopt-quarantine to move it aside)"
        FAIL=1
      fi
    else
      ln -s "$PKG" "$T" || { echo "FATAL: cannot create $T"; exit 1; }
      echo "compat:      $T -> $PKG"
    fi
  done
  [ "$FAIL" = "1" ] && exit 2
fi

# ---- 3. self-integrity ------------------------------------------------------
cd "$PKG" || exit 1
if sha256sum -c MANIFEST.sha256 --quiet; then
  echo "self-integrity OK: $(wc -l < MANIFEST.sha256) files match MANIFEST.sha256"
else
  echo "FATAL: package integrity check FAILED — do not run this copy"; exit 1
fi
echo "install complete"