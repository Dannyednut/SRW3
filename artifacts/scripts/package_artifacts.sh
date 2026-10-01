#!/usr/bin/env bash
# Package the SRW3 Phase 0-D final artifact set for download.
# Renders: browsable tree at download/srw3-artifacts/ + single zip bundle.
set -euo pipefail

ROOT=/home/z/my-project
SRC=$ROOT/srw3-kevm
DL=$ROOT/download
STG=$DL/srw3-artifacts
ZIP=$DL/SRW3-Phase1A-Artifact-Bundle.zip

rm -rf "$STG" "$ZIP"
mkdir -p "$STG"/{semantics,proofs,proof-build-outputs,transcripts/audit,prior-art-freeze,scripts,baseline/reference-implementation,git,patches}

# ---- 1. Reports (Phase 0-D Theorem-Closure + Phase 1A LLVM) ----
cp "$DL/SRW3-Phase0D-KEVM-Report.md" "$STG/"
cp "$DL/SRW3-Phase0D-KEVM-Report.pdf" "$STG/"
cp "$DL/SRW3-Phase1A-LLVM-Report.md" "$STG/"
cp "$DL/SRW3-Phase1A-LLVM-Report.pdf" "$STG/"

# ---- 2. Semantics sources (ghost-instrumented srw3.k + KEVM binding + demos) ----
cp "$SRC/k/srw3.k" "$STG/semantics/srw3.k"
cp "$SRC/k/run_demos.sh" "$STG/semantics/run_demos.sh"
mkdir -p "$STG/semantics/abstract-demos" "$STG/semantics/kevm/demos"
cp "$SRC/k/demos/"*.srw3 "$STG/semantics/abstract-demos/"
cp "$SRC/k/kevm/srw3-kevm.k" "$STG/semantics/kevm/srw3-kevm.k"
cp "$SRC/k/kevm/demos/"* "$STG/semantics/kevm/demos/"

# ---- 3. Proof sources (.k) ----
cp "$SRC/proofs/"*.k "$STG/proofs/"
mkdir -p "$STG/proofs/boundaries"
cp "$SRC/proofs/boundaries/"*.k "$STG/proofs/boundaries/"
cp "$SRC/proofs/ghost_manifest.json" "$STG/proofs/"
mkdir -p "$STG/transcripts/provenance"
cp "$SRC/transcripts/provenance/"* "$STG/transcripts/provenance/" 2>/dev/null || true
# kompile build records (README only; binaries excluded)
for d in ghost-out tier3-out safeform-out bridgegen-out; do
  [ -f "$SRC/proofs/$d/README.md" ] && cp "$SRC/proofs/$d/README.md" "$STG/proof-build-outputs/$d.README.md"
done

# ---- 4. Transcripts (all human-readable evidence) ----
cp "$SRC/transcripts/"*.txt "$STG/transcripts/"
cp "$SRC/transcripts/"*.log "$STG/transcripts/" 2>/dev/null || true
mkdir -p "$STG/transcripts/audit/boundaries"
cp "$SRC/transcripts/audit/"*.txt "$STG/transcripts/audit/"
cp "$SRC/transcripts/audit/boundaries/"*.txt "$STG/transcripts/audit/boundaries/"
cp "$SRC/transcripts/audit/"*.time "$STG/transcripts/audit/" 2>/dev/null || true

# ---- 5. Scripts (all audit/generation pipeline code) ----
cp "$ROOT/scripts/"* "$STG/scripts/"

# ---- 6. Prior-art freeze evidence ----
cp "$ROOT/tool-results/prior-art/freeze/"* "$STG/prior-art-freeze/"

# ---- 7. Baseline provenance ----
cp "$ROOT/srw3-baseline.sha256" "$STG/baseline/SRW3-Phase0D-baseline.sha256"
# unpacked authoritative baseline (byte-identical zip lives in git bundle, commit a857618)
tar -C "$ROOT/srw3-baseline" -cf - . | tar -C "$STG/baseline/reference-implementation" -xf -

# ---- 8. Patches + worklog ----
cp "$SRC/patches/"* "$STG/patches/"
cp "$ROOT/worklog.md" "$STG/worklog.md"

# ---- 9. Git bundle (canonical provenance artifact; created once at Phase-1A close, copied verbatim)
cp "$ROOT/srw3-work.bundle" "$STG/git/srw3-work.bundle"

# ---- 10. MANIFEST.txt with SHA-256 of every staged file ----
{
  echo "SRW3 Artifact Bundle — Phase 0-D (Theorem-Closure) + Phase 1A (LLVM Retarget)"
  echo "Generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
  echo
  echo "THEOREM STATUS"
  echo "--------------"
  echo "  Full lineage-length safety theorem  : MECHANIZED (#Top)"
  echo "    InitialSafe(P,sigma0) ^ SecurityClosed(P) -> forall n. Safe(P,sigma_n)"
  echo "    Encoding: ghost-instrumented semantics (induction_ghost.k); GH-T2/GH-M #Top,"
  echo "    GhostMatches soundness structure machine-checked (GH-BASE/GH-A/GH-R/GH-SOUND-I/F/GATE-AGREE)."
  echo "  Tier-3 universal reconciliation     : STATEMENT FORMALIZED; NOT YET MECHANIZED"
  echo "    wfCoverage(H,FD,S) -> gateOk_faithful(H,S) = implementedGate(H,FD,S) (tier3_universal.k, unweakened)"
  echo "  LLVM backend                        : UNBLOCKED per mandate decision rule"
  echo
  echo "CONTENTS"
  echo "--------"
  echo "  SRW3-Phase0D-KEVM-Report.{md,pdf}   Research report (Theorem-Closure Pass edition, Rev 4)"
  echo "  semantics/srw3.k                    Ghost-instrumented abstract SRW3 semantics"
  echo "  semantics/kevm/srw3-kevm.k          KEVM binding definition"
  echo "  semantics/abstract-demos/           13 abstract demo cases (.srw3)"
  echo "  semantics/kevm/demos/               KEVM positive / stale-price / minimal demos"
  echo "  proofs/                             K proof sources (induction_ghost.k = full theorem)"
  echo "  proof-build-outputs/                Kompile build records for ghost/tier3/safeform/bridgegen"
  echo "  transcripts/                        Human-readable evidence: demos, EVM runs, kprove verdicts"
  echo "  transcripts/audit/                  14 audit transcripts incl. full_matrix_v3.txt (regression matrix)"
  echo "  scripts/                            Complete audit + generation pipeline"
  echo "  prior-art-freeze/                   Freeze-check evidence (SUMMARY.md + 3 search JSONs)"
  echo "  baseline/                           Authoritative Phase 0-D baseline (sha256 + unpacked reference)"
  echo "  patches/baseline-k-compat.patch     Recorded K v7.1.337 compatibility patch (pristine untouched)"
  echo "  git/srw3-work.bundle                Self-contained repo: main (pristine baseline) + kevm-changes"
  echo "  worklog.md                          Full multi-agent work log"
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

# ---- 11. Zip ----
( cd "$DL" && zip -qr "$ZIP" srw3-artifacts )

echo "=== staged tree ==="
du -sh "$STG"
echo "=== zip ==="
ls -la "$ZIP"

# ---- 12. standalone sha256 sidecar for the zip ----
sha256sum "$ZIP" > "$ZIP.sha256"
