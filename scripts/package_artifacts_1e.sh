#!/usr/bin/env bash
# Package the SRW3 Phase 1E artifact set (cumulative: 0-D .. 1D-R1 + 1E).
# MANIFEST references all paths RELATIVELY (no agent-local absolute paths).
# Self-excluding MANIFEST: the MANIFEST does not checksum itself; separate
# ZIP sidecar; round-trip verified.
set -euo pipefail

ROOT=/home/z/my-project
SRC=$ROOT/srw3-phase1e
DL=$ROOT/download
STG=$DL/srw3-artifacts
ZIP=$DL/SRW3-Phase1E-Artifact-Bundle.zip

rm -rf "$ZIP" "$ZIP.sha256"
mkdir -p "$STG"/{semantics,proofs,transcripts/audit,scripts,git,python,provenance} \
         "$STG"/semantics/phase1d "$STG"/semantics/kevm/demos \
         "$STG"/proofs/phase1d "$STG"/proofs/phase1e/negative_controls \
         "$STG"/transcripts/audit/phase1e \
         "$STG"/python-gen "$STG"/python \
         "$STG"/phase1e/report "$STG"/phase1e/semantics "$STG"/phase1e/proofs/negative_controls \
         "$STG"/phase1e/python "$STG"/phase1e/transcripts "$STG"/phase1e/provenance

# ---- 1. Reports ----
cp "$SRC"/SRW3-Phase*.md "$SRC"/SRW3-Phase*.pdf "$STG/" 2>/dev/null || true

# ---- 2. Phase 1E sources (the new artifact tree, §22 layout) ----
cp "$SRC/phase1e/report/"* "$STG/phase1e/report/"
cp "$SRC/phase1e/semantics/"*.md "$SRC/phase1e/semantics/"*.k "$STG/phase1e/semantics/"
cp "$SRC/phase1e/proofs/"*.k "$STG/phase1e/proofs/"
cp "$SRC/phase1e/proofs/negative_controls/"*.k "$STG/phase1e/proofs/negative_controls/"
cp "$SRC/phase1e/python/"*.py "$STG/phase1e/python/"
cp "$SRC/phase1e/transcripts/"*.txt "$STG/phase1e/transcripts/"
cp "$SRC/phase1e/provenance/"* "$STG/phase1e/provenance/"

# ---- 3. Shared sources (mirrors) ----
cp "$SRC/k/srw3.k" "$SRC/k/srw3gen.k" "$SRC/k/run_demos.sh" "$STG/semantics/" 2>/dev/null || true
cp "$SRC/k/phase1d/"*.k "$SRC/k/phase1d/"*.lin "$STG/semantics/phase1d/" 2>/dev/null || true
mkdir -p "$STG/semantics/phase1d/shim"
cp "$SRC/k/phase1d/shim/"* "$STG/semantics/phase1d/shim/" 2>/dev/null || true
cp "$SRC/k/kevm/srw3-kevm.k" "$SRC/k/kevm/srw3-gen-binding.k" "$SRC/k/kevm/srw3-lin-evm.k" \
   "$SRC/k/kevm/srw3-auth-evm.k" "$STG/semantics/kevm/" 2>/dev/null || true
cp "$SRC/k/kevm/demos/"*.srw3evm "$STG/semantics/kevm/demos/" 2>/dev/null || true
cp "$SRC/proofs/"*.k "$STG/proofs/" 2>/dev/null || true
cp "$SRC/proofs/phase1d/"*.k "$STG/proofs/phase1d/" 2>/dev/null || true
cp "$SRC/python-gen/"*.py "$STG/python-gen/"
cp "$SRC/scripts/split_auth_claims.py" "$SRC/scripts/phase1e_crosslayer.py" "$SRC/scripts/rebuild_env_1d.sh" \
   "$SRC/scripts/final_part8_crosslayer.py" "$SRC/scripts/final_part9_threat.py" "$STG/scripts/" 2>/dev/null || true

# ---- 4. Phase 1E transcripts (audit path) ----
cp "$SRC/transcripts/audit/phase1e/"*.txt "$STG/transcripts/audit/phase1e/" 2>/dev/null || true

# ---- 5. MANIFEST (relative paths; self-excluding) ----
cd "$STG"
find . -type f ! -name MANIFEST.txt | sort | sed 's|^\./||' | xargs sha256sum > MANIFEST.txt
ENTRIES=$(wc -l < MANIFEST.txt)

# ---- 6. ZIP + sidecar ----
cd "$DL"
rm -f "$ZIP"
zip -q -r "$ZIP" "$(basename "$STG")"
sha256sum "$ZIP" > "$ZIP.sha256"

# ---- 7. Round-trip verification ----
TMP=$(mktemp -d)
unzip -q "$ZIP" -d "$TMP"
cd "$TMP/$(basename "$STG")"
sha256sum -c MANIFEST.txt --quiet > /dev/null 2>&1 && RT="ALL OK" || RT="FAIL"
cd /; rm -rf "$TMP"

echo "MANIFEST entries: $ENTRIES"
echo "round-trip sha256sum -c: $RT"
echo "zip: $ZIP ($(stat -c %s "$ZIP") bytes)"
echo "sha256: $(cat "$ZIP.sha256" | cut -d' ' -f1)"
