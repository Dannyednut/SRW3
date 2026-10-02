#!/usr/bin/env bash
# =============================================================================
# SRW3 Phase 1D-R1-FINAL — final artifact packaging (mandate Parts 6 + 11).
#
# MANIFEST REPAIR: the manifest is generated from all artifact files EXCEPT
# the manifest itself — no self-checksum. The ZIP integrity is recorded in a
# SEPARATE sidecar SRW3-Phase1D-R1-FINAL-Artifact-Bundle.zip.sha256.
# Portability: no agent-local absolute paths anywhere in the manifest.
# =============================================================================
set -euo pipefail

ROOT=/home/z/my-project
SRC=$ROOT/srw3-work
DL=$ROOT/download
STG=$DL/srw3-artifacts
ZIP=$DL/SRW3-Phase1D-R1-FINAL-Artifact-Bundle.zip

# ---- 1. refresh the staging tree from the final repository ----
cp "$SRC"/SRW3-Phase*.md "$SRC"/SRW3-Phase*.pdf "$STG/" 2>/dev/null || true

mkdir -p "$STG"/semantics/phase1c/shim "$STG"/semantics/kevm/demos \
         "$STG"/semantics/phase1d "$STG"/proofs/phase1d \
         "$STG"/transcripts/audit/phase1d_r1 "$STG"/transcripts/provenance \
         "$STG"/python-gen "$STG"/scripts "$STG"/git

cp "$SRC/k/srw3.k" "$SRC/k/srw3gen.k" "$SRC/k/run_demos.sh" "$STG/semantics/" 2>/dev/null || true
cp "$SRC/k/phase1c/"*.k "$SRC/k/phase1c/"*.ck "$STG/semantics/phase1c/" 2>/dev/null || true
cp "$SRC/k/phase1c/probe.pgm" "$STG/semantics/phase1c/" 2>/dev/null || true
cp "$SRC/k/phase1c/shim/"*.cpp "$SRC/k/phase1c/shim/"*.h "$STG/semantics/phase1c/shim/" 2>/dev/null || true
cp "$SRC/k/kevm/srw3-kevm.k" "$SRC/k/kevm/srw3-gen-binding.k" "$SRC/k/kevm/srw3-lin-evm.k" "$STG/semantics/kevm/" 2>/dev/null || true
cp "$SRC/k/kevm/demos/"*.srw3evm "$STG/semantics/kevm/demos/" 2>/dev/null || true
cp "$SRC/k/phase1d/"*.k "$SRC/k/phase1d/"*.lin "$STG/semantics/phase1d/"

cp "$SRC/proofs/"*.k "$STG/proofs/" 2>/dev/null || true
cp -r "$SRC/proofs/gen" "$STG/proofs/" 2>/dev/null || true
rm -rf "$STG/proofs/gen"/out-* 2>/dev/null || true
cp "$SRC/proofs/phase1d/"*.k "$STG/proofs/phase1d/" 2>/dev/null || true
cp "$SRC/proofs/ghost_manifest.json" "$STG/proofs/" 2>/dev/null || true

cp "$SRC/python-gen/"*.py "$STG/python-gen/"
cp "$SRC/scripts/"*.sh "$SRC/scripts/"*.py "$STG/scripts/" 2>/dev/null || true

cp "$SRC/transcripts/audit/"*.txt "$STG/transcripts/audit/" 2>/dev/null || true
cp -r "$SRC/transcripts/audit/phase1d_r1/." "$STG/transcripts/audit/phase1d_r1/"
cp "$SRC/transcripts/provenance/"*.txt "$STG/transcripts/provenance/" 2>/dev/null || true

cp "$SRC/worklog.md" "$STG/worklog.md"

# ---- 2. closure provenance metadata ----
COMMIT=$(cd "$SRC" && git rev-parse refs/tags/phase1d-r1-complete^{commit})
PARENT=$(cd "$SRC" && git rev-parse refs/tags/phase1d-r1-complete^{commit}^)
TREE=$(cd "$SRC" && git rev-parse refs/tags/phase1d-r1-complete^{tree})
cat > "$STG/PROVENANCE.txt" <<EOF
SRW3 Phase 1D-R1-FINAL — closure provenance
===========================================
final commit (tag/branch phase1d-r1-complete): $COMMIT
parent:                                        $PARENT
tree object:                                   $TREE
tree git-archive sha256: e1a8b4d518e298e25dbbd7949e397d5aea87a92b4d13c19291a563785a2904e7
branch: phase1d-r1-complete   tag: phase1d-r1-complete   lineage: phase1c
git bundle: git/srw3-work-r1-final.bundle (verified in a fresh empty
repository; see transcripts/provenance/git_bundle_r1_final_verify.txt)
preclosure bundle preserved as: SRW3-Phase1D-R1-preclosure.zip
toolchain: K v7.1.337 | z3 4.13.3 | clang/LLVM-15 15.0.6-4+b1 | KEVM v1.0.921
           | blockchain-k-plugin @ 207ae512 | libsecp256k1 0.5.0
scientific result frozen (scope: modeled verifier domain):
  a validly authorized but dishonest producer cannot make an internally
  inconsistent presented post-state pass the verifier's state-composition
  layer after the L7 repair (presented-effect consistency ONLY; historically
  true effects remain open — NOT YET MECHANIZED / REQUIRES CLIENT SUPPORT).
EOF

# ---- 3. MANIFEST: all files EXCEPT the manifest itself (self-checksum repaired) ----
cd "$STG"
find . -type f ! -name MANIFEST.txt | sed 's|^\./||' | sort | xargs sha256sum > MANIFEST.txt
echo "MANIFEST: $(wc -l < MANIFEST.txt) entries (self-excluding)"

# ---- 4. zip + SEPARATE sidecar (no self-reference) ----
cd "$DL"
rm -f "$ZIP" "$ZIP.sha256"
zip -qr "$ZIP" srw3-artifacts
sha256sum "$ZIP" > "$ZIP.sha256"
sha256sum -c "$ZIP.sha256" > /dev/null && echo "BUNDLE OK: $ZIP ($(du -h "$ZIP" | cut -f1))"

# ---- 5. portability check: no agent-local absolute paths in the manifest ----
if grep -n "/home/z" "$STG/MANIFEST.txt" >/dev/null 2>&1; then
  echo "PORTABILITY DEFECT: absolute paths in MANIFEST"; exit 1
fi
echo "portability check: no /home/z paths in MANIFEST"

# ---- 6. manifest self-verification round-trip ----
cd "$STG"
if sha256sum -c MANIFEST.txt > /tmp/manifest_check.txt 2>&1; then
  echo "MANIFEST round-trip: ALL $(wc -l < MANIFEST.txt) checksums OK"
else
  echo "MANIFEST round-trip FAILURES:"; grep -v ": OK$" /tmp/manifest_check.txt | head; exit 1
fi
