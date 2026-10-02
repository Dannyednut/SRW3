#!/usr/bin/env bash
# Package the SRW3 Phase 1D-R1 artifact set (cumulative: 0-D + 1A + 1B + 1C + 1D + 1D-R1).
# MANIFEST references all paths RELATIVELY (no agent-local absolute paths).
set -euo pipefail

ROOT=/home/z/my-project
SRC=$ROOT/srw3-work
DL=$ROOT/download
STG=$DL/srw3-artifacts
ZIP=$DL/SRW3-Phase1D-R1-Artifact-Bundle.zip

rm -rf "$ZIP"
mkdir -p "$STG"/{semantics,proofs,transcripts/audit,scripts,git}
mkdir -p "$STG"/semantics/phase1d "$STG"/semantics/kevm/demos \
         "$STG"/proofs/phase1d "$STG"/transcripts/audit/phase1d_r1 \
         "$STG"/python-gen

# ---- 1. Reports ----
cp "$SRC"/SRW3-Phase*.md "$SRC"/SRW3-Phase*.pdf "$STG/" 2>/dev/null || true

# ---- 2. Semantics sources ----
cp "$SRC/k/srw3.k" "$SRC/k/srw3gen.k" "$SRC/k/run_demos.sh" "$STG/semantics/" 2>/dev/null || true
mkdir -p "$STG/semantics/phase1c/shim"
cp "$SRC/k/phase1c/"*.k "$SRC/k/phase1c/"*.ck "$STG/semantics/phase1c/" 2>/dev/null || true
cp "$SRC/k/phase1c/shim/"* "$STG/semantics/phase1c/shim/" 2>/dev/null || true
cp "$SRC/k/kevm/srw3-kevm.k" "$SRC/k/kevm/srw3-gen-binding.k" "$SRC/k/kevm/srw3-lin-evm.k" "$STG/semantics/kevm/" 2>/dev/null || true
cp "$SRC/k/kevm/demos/"*.srw3evm "$STG/semantics/kevm/demos/" 2>/dev/null || true
cp "$SRC/k/phase1d/"*.k "$SRC/k/phase1d/"*.lin "$STG/semantics/phase1d/"

# ---- 3. Proofs ----
cp "$SRC/proofs/"*.k "$STG/proofs/" 2>/dev/null || true
cp -r "$SRC/proofs/gen" "$STG/proofs/" 2>/dev/null || true
rm -rf "$STG/proofs/gen"/out-* 2>/dev/null || true
cp "$SRC/proofs/phase1d/"*.k "$STG/proofs/phase1d/" 2>/dev/null || true
cp "$SRC/proofs/ghost_manifest.json" "$STG/proofs/" 2>/dev/null || true

# ---- 4. Python oracle + R1 verifier ----
cp "$SRC/python-gen/"*.py "$STG/python-gen/"
cp "$SRC/scripts/keccak_ref.py" "$STG/scripts/" 2>/dev/null || true

# ---- 5. Scripts ----
cp "$SRC/scripts/"*.sh "$SRC/scripts/"*.py "$STG/scripts/" 2>/dev/null || true

# ---- 6. Transcripts (audit; R1 subdir in full) ----
cp "$SRC/transcripts/audit/"*.txt "$STG/transcripts/audit/" 2>/dev/null || true
cp -r "$SRC/transcripts/audit/phase1d_r1" "$STG/transcripts/audit/"
cp -r "$SRC/transcripts/provenance" "$STG/transcripts/" 2>/dev/null || true

# ---- 7. Worklog ----
cp "$SRC/worklog.md" "$STG/worklog.md"

# ---- 8. MANIFEST (relative paths only) ----
cd "$STG"
find . -type f | sed 's|^\./||' | sort > MANIFEST.txt
sha256sum $(find . -type f -name "*.md" -o -type f -name "*.pdf" -o -type f -name "*.k" \
    -o -type f -name "*.py" -o -type f -name "*.sh" -o -type f -name "*.txt" \
    -o -type f -name "*.lin" -o -type f -name "*.ck" -o -type f -name "*.cpp" \
    -o -type f -name "*.h" | sort) >> MANIFEST.txt 2>/dev/null || true
echo "MANIFEST: $(wc -l < MANIFEST.txt) lines"

# ---- 9. zip + sidecar ----
cd "$DL"
rm -f "$ZIP.sha256"
zip -qr "$ZIP" srw3-artifacts
sha256sum "$ZIP" > "$ZIP.sha256"
sha256sum -c "$ZIP.sha256" > /dev/null && echo "BUNDLE OK: $ZIP ($(du -h "$ZIP" | cut -f1))"

# ---- 10. portability check: no agent-local absolute paths ----
if grep -rn "/home/z" "$STG/MANIFEST.txt" >/dev/null 2>&1; then
  echo "PORTABILITY DEFECT: absolute paths in MANIFEST"; exit 1
fi
echo "portability check: no /home/z paths in MANIFEST"
