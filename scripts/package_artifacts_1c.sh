#!/usr/bin/env bash
# Package the SRW3 Phase 1C final artifact set (cumulative: 0-D + 1A + 1B + 1C).
# Renders: browsable tree at download/srw3-artifacts/ + single zip bundle.
# Adapted from package_artifacts_1b.sh with the Phase-1C additions.
set -euo pipefail

ROOT=/home/z/my-project
SRC=$ROOT/srw3-kevm
DL=$ROOT/download
STG=$DL/srw3-artifacts
ZIP=$DL/SRW3-Phase1C-Artifact-Bundle.zip

rm -rf "$STG" "$ZIP"
mkdir -p "$STG"/{semantics,proofs,proof-build-outputs,transcripts/audit,prior-art-freeze,scripts,baseline/reference-implementation,git,patches}
mkdir -p "$STG"/semantics/abstract-demos "$STG"/semantics/gen-demos "$STG"/semantics/kevm/demos \
         "$STG"/semantics/phase1c/shim \
         "$STG"/proofs/gen "$STG"/proofs/boundaries \
         "$STG"/python-gen "$STG"/transcripts/audit/boundaries \
         "$STG"/transcripts/provenance

# ---- 1. Reports (0-D + 1A + 1B) ----
cp "$DL"/SRW3-*.md "$STG/"
cp "$DL"/SRW3-*.pdf "$STG/"

# ---- 2. Semantics sources ----
cp "$SRC/k/srw3.k" "$STG/semantics/srw3.k"
cp "$SRC/k/srw3gen.k" "$STG/semantics/srw3gen.k"
cp "$SRC/k/run_demos.sh" "$STG/semantics/run_demos.sh"
cp /home/z/my-project/scripts/run_gen_demos.sh "$STG/semantics/run_gen_demos.sh"
cp "$SRC/k/demos/"*.srw3 "$STG/semantics/abstract-demos/"
cp "$SRC/k/gen-demos/"*.srw3 "$STG/semantics/gen-demos/"
cp "$SRC/k/kevm/srw3-kevm.k" "$STG/semantics/kevm/srw3-kevm.k"
cp "$SRC/k/kevm/srw3-gen-binding.k" "$STG/semantics/kevm/srw3-gen-binding.k"
cp "$SRC/k/kevm/demos/"* "$STG/semantics/kevm/demos/"

# ---- 2b. Phase-1C cryptographic layer ----
cp "$SRC/k/phase1c/srw3ck.k" "$STG/semantics/phase1c/srw3ck.k"
cp "$SRC/k/phase1c/krypto-probe.k" "$STG/semantics/phase1c/krypto-probe.k"
cp "$SRC/k/phase1c/"ck_*.ck "$STG/semantics/phase1c/"
cp "$SRC/k/phase1c/shim/krypto_shim.cpp" "$STG/semantics/phase1c/shim/"
cp "$SRC/k/phase1c/shim/plugin_util.h" "$SRC/k/phase1c/shim/plugin_util.cpp" "$STG/semantics/phase1c/shim/"
cp /home/z/my-project/scripts/keccak_ref.py "$STG/semantics/phase1c/keccak_ref.py"

# ---- 3. Proof sources (.k) + manifests ----
cp "$SRC/proofs/"*.k "$STG/proofs/"
cp "$SRC/proofs/"*.json "$STG/proofs/" 2>/dev/null || true
cp "$SRC/proofs/boundaries/"*.k "$STG/proofs/boundaries/"
cp "$SRC/proofs/gen/"*.k "$STG/proofs/gen/"
cp "$SRC/proofs/gen/ghost_manifest_gen.json" "$STG/proofs/gen/"
for d in ghost-out tier3-out safeform-out bridgegen-out; do
  [ -f "$SRC/proofs/$d/README.md" ] && cp "$SRC/proofs/$d/README.md" "$STG/proof-build-outputs/$d.README.md" || true
done
cp "$SRC/proofs/gen/out-cm2/README.md" "$STG/proof-build-outputs/gen-out-cm2.README.md" 2>/dev/null || true

# ---- 4. Python generalized model ----
cp "$SRC/python-gen/"*.py "$STG/python-gen/"

# ---- 5. Transcripts ----
cp "$SRC/transcripts/"*.txt "$STG/transcripts/" 2>/dev/null || true
cp "$SRC/transcripts/"*.log "$STG/transcripts/" 2>/dev/null || true
cp "$SRC/transcripts/audit/"*.txt "$STG/transcripts/audit/"
cp "$SRC/transcripts/audit/boundaries/"*.txt "$STG/transcripts/audit/boundaries/"
cp "$SRC/transcripts/audit/"*.time "$STG/transcripts/audit/" 2>/dev/null || true
cp "$SRC/transcripts/provenance/"* "$STG/transcripts/provenance/" 2>/dev/null || true

# ---- 6. Scripts + fragments ----
find "$ROOT/scripts" -maxdepth 1 -type f -exec cp {} "$STG/scripts/" \;
mkdir -p "$STG/scripts/gen_fragments"
cp "$ROOT/scripts/gen_fragments/"* "$STG/scripts/gen_fragments/"

# ---- 7. Prior-art freeze evidence ----
cp "$ROOT/tool-results/prior-art/freeze/"* "$STG/prior-art-freeze/" 2>/dev/null || true

# ---- 8. Baseline provenance (unpacked authoritative baseline) ----
cp "$ROOT/srw3-baseline.sha256" "$STG/baseline/SRW3-Phase0D-baseline.sha256"
tar -C "$ROOT/srw3-baseline" -cf - . | tar -C "$STG/baseline/reference-implementation" -xf -

# ---- 9. Patches + worklog ----
cp "$SRC/patches/"* "$STG/patches/" 2>/dev/null || true
cp "$ROOT/worklog.md" "$STG/worklog.md"

# ---- 10. Git bundles ----
# (a) the historical bundle (main pristine a857618 / kevm-changes / phase1-start)
cp "$ROOT/srw3-work.bundle" "$STG/git/srw3-work.bundle"
# (b) the Phase-1B state repo (created by package_git_1b.sh; branch phase1b)
if [ -f "$ROOT/srw3b-work.bundle" ]; then
  cp "$ROOT/srw3b-work.bundle" "$STG/git/srw3b-work.bundle"
fi
if [ -f "$ROOT/srw3c-work.bundle" ]; then
  cp "$ROOT/srw3c-work.bundle" "$STG/git/srw3c-work.bundle"
fi

# ---- 11. MANIFEST.txt with SHA-256 of every staged file ----
{
  echo "SRW3 Artifact Bundle — Phase 0-D + 1A + 1B + Phase 1C (Cryptographic Grounding)"
  echo "Generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
  echo
  echo "THEOREM STATUS"
  echo "--------------"
  echo "  Full lineage-length safety theorem (single-write ghost model) : MECHANIZED (#Top)"
  echo "  Alias-aware forall-n safety (CM2)                             : MECHANIZED (GH2-T2/GH2-M #Top)"
  echo "  Aggregate-authority forall-n safety (CM3)                     : MECHANIZED (GH3-T2/GH3-M #Top)"
  echo "  Generalized forall-n safety (multi-write+alias+authority)     : MECHANIZED (GH4-T2/GH4-M #Top)"
  echo "    All three non-vacuity negative controls FAIL as designed."
  echo "    Encoding: proofs/gen/{cm2_alias,cm3_auth,gen_full}.k + ghost_manifest_gen.json."
  echo "  Tier-3 universal reconciliation                               : STATEMENT FORMALIZED; NOT YET MECHANIZED"
  echo "  Cryptographic lineage                                         : DEMONSTRATED (execution layer)
                                                                  real keccak256 commitments in the gate;
                                                                  probe 8/8 + tamper/recover demos (LLVM+shim)
  KRYPTO hooks availability                                     : LLVM-only (hs has no evaluators); requires
                                                                  --hook-namespaces KRYPTO + krypto shim"
  echo "  LLVM backend                                                  : execution portability only (proof layer haskell)"
  echo
  echo "CONTENTS"
  echo "--------"
  echo "  SRW3-Phase{0D,1A,1B}-*.md/pdf      Research reports (MD = source of truth)"
  echo "  semantics/srw3.k                   Phase-0 abstract semantics (ghost-instrumented)"
  echo "  semantics/srw3gen.k                Phase-1B generalized semantics"
  echo "  semantics/abstract-demos/          13 abstract demos"
  echo "  semantics/gen-demos/               10 generalized demos (CM2/CM3/generalized)"
  echo "  semantics/kevm/                    Frozen binding + additive generalized binding + demos"
  echo "  semantics/phase1c/                 Crypto lineage (srw3ck.k), probe, shim, keccak_ref oracle"
  echo "  proofs/                            K proof sources incl. proofs/gen/ (35 ghost claims)"
  echo "  python-gen/                        Python mirror oracle (14/14)"
  echo "  scripts/                           Complete audit + generation pipeline + gen_fragments"
  echo "  transcripts/audit/                 Audit transcripts incl. full_matrix_v5.txt"
  echo "  git/                               srw3-work.bundle (pre-1B) + srw3b-work.bundle (1B state)"
  echo "  worklog.md                         Full multi-agent work log"
  echo
  echo "NOTE ON GIT PROVENANCE"
  echo "----------------------"
  echo "  A sandbox reset destroyed the pre-1B git objects (phase1a-final 88e4209)."
  echo "  Recovery was sha-verified at file level (k/srw3gen.k d583ef0c... vs"
  echo "  ghost_manifest_gen.json). srw3b-work.bundle is a fresh repository holding"
  echo "  the complete Phase-1B state; history before it is manifest-based."
  echo
  echo "BASELINE PROVENANCE"
  echo "-------------------"
  echo "  SRW3_Phase_0D_Implementation_v1.0.zip sha256 (byte-identical copy in git bundle, commit a857618):"
  echo "  $(cat "$ROOT/srw3-baseline.sha256")"
  echo
  echo "SHA-256 MANIFEST"
  echo "----------------"
  ( cd "$STG" && find . -type f ! -name MANIFEST.txt -print0 | sort -z | xargs -0 sha256sum )
} > "$STG/MANIFEST.txt"

# ---- 12. Zip ----
( cd "$DL" && zip -qr "$ZIP" srw3-artifacts )

echo "=== staged tree ==="
du -sh "$STG"
echo "=== zip ==="
ls -la "$ZIP"

# ---- 13. standalone sha256 sidecar for the zip ----
sha256sum "$ZIP" > "$ZIP.sha256"
