#!/usr/bin/env bash
# Package the SRW3 Phase 1F artifact set (cumulative: 0-D .. 1E + 1F).
# MANIFEST references all paths RELATIVELY (no agent-local absolute paths).
# Self-excluding MANIFEST: the MANIFEST does not checksum itself; separate
# ZIP sidecar; round-trip verified.
set -euo pipefail

ROOT=/home/z/my-project
SRC=$ROOT/srw3-kevm
DL=$ROOT/download
STG=$DL/srw3-artifacts
ZIP=$DL/SRW3-Phase1F-Artifact-Bundle.zip

rm -rf "$ZIP" "$ZIP.sha256"
mkdir -p "$STG"/{semantics,proofs,transcripts/audit,scripts,git,python,provenance} \
         "$STG"/semantics/phase1d "$STG"/semantics/kevm/demos \
         "$STG"/proofs/phase1d "$STG"/proofs/phase1e/negative_controls \
         "$STG"/proofs/phase1f/not_mechanized \
         "$STG"/transcripts/audit/phase1e "$STG"/transcripts/audit/phase1f \
         "$STG"/transcripts/part3_per_claim \
         "$STG"/python-gen "$STG"/python \
         "$STG"/phase1e/report "$STG"/phase1e/semantics "$STG"/phase1e/proofs/negative_controls \
         "$STG"/phase1e/python "$STG"/phase1e/transcripts "$STG"/phase1e/provenance \
         "$STG"/phase1f/report "$STG"/phase1f/semantics "$STG"/phase1f/proofs/not_mechanized \
         "$STG"/phase1f/python "$STG"/phase1f/transcripts/part3_per_claim \
         "$STG"/phase1f/provenance "$STG"/scripts/phase1f

# ---- 1. Reports ----
cp "$SRC"/SRW3-Phase*.md "$SRC"/SRW3-Phase*.pdf "$STG/" 2>/dev/null || true

# ---- 2. Phase 1F sources ----
cp "$SRC/phase1f/report/"* "$STG/phase1f/report/"
cp "$SRC/phase1f/semantics/"*.md "$SRC/phase1f/semantics/"*.k "$STG/phase1f/semantics/"
cp "$SRC/phase1f/proofs/"*.k "$STG/phase1f/proofs/"
cp "$SRC/phase1f/proofs/not_mechanized/"* "$STG/phase1f/proofs/not_mechanized/"
cp "$SRC/phase1f/python/"*.py "$STG/phase1f/python/"
cp "$SRC/phase1f/transcripts/"*.txt "$STG/phase1f/transcripts/"
cp "$SRC/phase1f/transcripts/part3_per_claim/"*.out "$STG/phase1f/transcripts/part3_per_claim/" 2>/dev/null || true
cp "$SRC/phase1f/provenance/"* "$STG/phase1f/provenance/"

# ---- 3. Shared sources (mirrors; frozen layers) ----
cp "$SRC/k/srw3.k" "$SRC/k/srw3gen.k" "$SRC/k/run_demos.sh" "$STG/semantics/" 2>/dev/null || true
cp "$SRC/k/phase1d/"*.k "$SRC/k/phase1d/"*.lin "$STG/semantics/phase1d/" 2>/dev/null || true
mkdir -p "$STG/semantics/phase1d/shim"
cp "$SRC/k/phase1d/shim/"* "$STG/semantics/phase1d/shim/" 2>/dev/null || true
cp "$SRC/k/kevm/srw3-kevm.k" "$SRC/k/kevm/srw3-gen-binding.k" "$SRC/k/kevm/srw3-lin-evm.k" \
   "$SRC/k/kevm/srw3-auth-evm.k" "$SRC/k/kevm/srw3-exec-evm.k" \
   "$SRC/k/kevm/srw3-exec-evm-demos.k" "$STG/semantics/kevm/" 2>/dev/null || true
cp "$SRC/k/kevm/demos/"*.srw3evm "$STG/semantics/kevm/demos/" 2>/dev/null || true
cp "$SRC/proofs/"*.k "$STG/proofs/" 2>/dev/null || true
cp "$SRC/proofs/phase1d/"*.k "$STG/proofs/phase1d/" 2>/dev/null || true
cp "$SRC/python-gen/"*.py "$STG/python-gen/"
cp "$SRC/scripts/split_auth_claims.py" "$SRC/scripts/phase1e_crosslayer.py" \
   "$SRC/scripts/rebuild_env_1d.sh" "$SRC/scripts/reinstall_toolchain_1b.sh" \
   "$SRC/scripts/final_part8_crosslayer.py" "$SRC/scripts/final_part9_threat.py" \
   "$SRC/scripts/gen_phase1f_pdf.py" "$STG/scripts/" 2>/dev/null || true
cp "$SRC/scripts/phase1f/"* "$STG/scripts/phase1f/" 2>/dev/null || true

# ---- 4. 1E tree refresh (unchanged, kept cumulative) ----
cp "$SRC/phase1e/report/"* "$STG/phase1e/report/" 2>/dev/null || true
cp "$SRC/phase1e/semantics/"*.md "$SRC/phase1e/semantics/"*.k "$STG/phase1e/semantics/" 2>/dev/null || true
cp "$SRC/phase1e/proofs/"*.k "$STG/phase1e/proofs/" 2>/dev/null || true
cp "$SRC/phase1e/proofs/negative_controls/"*.k "$STG/phase1e/proofs/negative_controls/" 2>/dev/null || true
cp "$SRC/phase1e/python/"*.py "$STG/phase1e/python/" 2>/dev/null || true
cp "$SRC/phase1e/transcripts/"*.txt "$STG/phase1e/transcripts/" 2>/dev/null || true
cp "$SRC/phase1e/provenance/"* "$STG/phase1e/provenance/" 2>/dev/null || true
cp "$SRC/transcripts/audit/phase1e/"*.txt "$STG/transcripts/audit/phase1e/" 2>/dev/null || true

# ---- 5. 1F transcripts (audit path) ----
cp "$SRC/phase1f/transcripts/"*.txt "$STG/transcripts/audit/phase1f/" 2>/dev/null || true
mkdir -p "$STG/transcripts/audit/phase1f/part3_per_claim"
cp "$SRC/phase1f/transcripts/part3_per_claim/"*.out "$STG/transcripts/audit/phase1f/part3_per_claim/" 2>/dev/null || true

# ---- 6. git bundle (offline ref carrier) ----
cd "$SRC" && git bundle create "$STG/git/srw3f-phase1f.bundle" phase1f 2>/dev/null || true

# ---- 7. MANIFEST (relative paths; self-excluding) ----
cd "$STG"
find . -type f ! -name MANIFEST.txt | sort | sed 's|^\./||' | xargs sha256sum > MANIFEST.txt
ENTRIES=$(wc -l < MANIFEST.txt)

# ---- 8. ZIP + sidecar + round-trip ----
cd "$DL"
rm -f "$ZIP"
zip -q -r "$ZIP" "$(basename "$STG")"
sha256sum "$(basename "$ZIP")" > "$ZIP.sha256"
echo "MANIFEST entries: $ENTRIES"
echo "bundle: $ZIP"
sha256sum "$(basename "$ZIP")"
# round-trip
RT=$(mktemp -d)
unzip -q "$ZIP" -d "$RT"
cd "$RT/$(basename "$STG")" && sha256sum -c MANIFEST.txt > /tmp/rt1f.log 2>&1 || true
OK=$(grep -c ': OK' /tmp/rt1f.log || true)
echo "round-trip: $OK / $ENTRIES OK"
rm -rf "$RT"
