#!/usr/bin/env bash
# Package the SRW3 Phase 1D final artifact set (cumulative: 0-D + 1A + 1B + 1C + 1D).
# Renders: browsable tree at download/srw3-artifacts/ + single zip bundle + .sha256.
# Adapted from package_artifacts_1c.sh with the Phase-1D additions.
# MANIFEST defect fix (carried from the Phase-1C review): the MANIFEST references
# all paths RELATIVELY (no agent-local absolute paths).
set -euo pipefail

ROOT=/home/z/my-project
SRC=$ROOT/srw3-work
DL=$ROOT/download
STG=$DL/srw3-artifacts
ZIP=$DL/SRW3-Phase1D-Artifact-Bundle.zip

rm -rf "$ZIP"
mkdir -p "$STG"/{semantics,proofs,transcripts/audit,scripts,git}
mkdir -p "$STG"/semantics/phase1d "$STG"/semantics/kevm/demos \
         "$STG"/proofs/phase1d "$STG"/transcripts/audit

# ---- 1. Reports (0-D + 1A + 1B + 1C + 1D) ----
cp "$SRC"/SRW3-Phase*.md "$SRC"/SRW3-Phase*.pdf "$STG/" 2>/dev/null || true

# ---- 2. Semantics sources ----
cp "$SRC/k/srw3.k" "$STG/semantics/" 2>/dev/null || true
cp "$SRC/k/srw3gen.k" "$STG/semantics/" 2>/dev/null || true
cp "$SRC/k/run_demos.sh" "$STG/semantics/" 2>/dev/null || true
cp "$SRC/k/phase1c/srw3ck.k" "$SRC/k/phase1c/krypto-probe.k" "$STG/semantics/phase1c/" 2>/dev/null || true
cp "$SRC/k/phase1c/"*.ck "$STG/semantics/phase1c/" 2>/dev/null || true
cp "$SRC/k/phase1c/shim/krypto_shim.cpp" "$SRC/k/phase1c/shim/plugin_util."* "$STG/semantics/phase1c/shim/" 2>/dev/null || true
cp "$SRC/k/kevm/srw3-kevm.k" "$SRC/k/kevm/srw3-gen-binding.k" "$SRC/k/kevm/srw3-lin-evm.k" "$STG/semantics/kevm/" 2>/dev/null || true
cp "$SRC/k/kevm/demos/"*.srw3evm "$STG/semantics/kevm/demos/" 2>/dev/null || true
# Phase 1D
cp "$SRC/k/phase1d/"*.k "$STG/semantics/phase1d/"
cp "$SRC/k/phase1d/"*.lin "$STG/semantics/phase1d/"

# ---- 3. Proofs ----
cp -r "$SRC/proofs/gen" "$STG/proofs/" 2>/dev/null || true
rm -rf "$STG/proofs/gen"/out-* 2>/dev/null || true
cp "$SRC/proofs/"*.k "$STG/proofs/" 2>/dev/null || true
cp "$SRC/proofs/ghost_manifest.json" "$STG/proofs/" 2>/dev/null || true
# Phase 1D
cp "$SRC/proofs/phase1d/"*.k "$STG/proofs/phase1d/"

# ---- 4. Python oracle ----
mkdir -p "$STG/python-gen"
cp "$SRC/python-gen/"*.py "$STG/python-gen/" 2>/dev/null || true
cp "$SRC/scripts/keccak_ref.py" "$STG/scripts/" 2>/dev/null || true

# ---- 5. Scripts (complete audit + generation pipeline) ----
cp "$SRC/scripts/"*.sh "$STG/scripts/" 2>/dev/null || true
cp "$SRC/scripts/"*.py "$STG/scripts/" 2>/dev/null || true

# ---- 6. Transcripts (audit) ----
cp "$SRC/transcripts/audit/"*.txt "$STG/transcripts/audit/" 2>/dev/null || true
cp -r "$SRC/transcripts/provenance" "$STG/transcripts/" 2>/dev/null || true

# ---- 7. Worklog ----
cp "$SRC/worklog.md" "$STG/worklog.md" 2>/dev/null || true

# ---- 8. Git bundles ----
cp "$DL"/srw3*.bundle "$STG/git/" 2>/dev/null || true

# ---- 9. MANIFEST (relative paths; sha256 chain) ----
MANIFEST=$STG/MANIFEST.txt
{
  echo "SRW3 Artifact Bundle — Phase 0-D + 1A + 1B + 1C + Phase 1D (Verifiable Lineage)"
  echo "Generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
  echo
  echo "THEOREM / EVIDENCE STATUS"
  echo "-------------------------"
  echo "  Full lineage-length safety theorem (1B surface)               : MECHANIZED (v5 record)"
  echo "  Tier-3 universal reconciliation                               : STATEMENT FORMALIZED; NOT YET MECHANIZED"
  echo "  Self-contained lineage record Lambda (12 fields)              : MECHANIZED (k/phase1d/)"
  echo "  Independent VerifyLineage + 12-field tamper matrix            : DEMONSTRATED (12/12 distinct verdicts)"
  echo "  Replay protection (R1-R4)                                     : DEMONSTRATED (reject/no-corruption)"
  echo "  CM-L3/L4/L5/L6/L8/L9/L11/L12 countermodels                    : DEMONSTRATED (execution layer)"
  echo "  CM-L1/L2/L10                                                  : EXCLUDED BY CONSTRUCTION"
  echo "  Chain continuity: LIN-CHAIN-BASE + LIN-CHAIN-STEP             : PROVED BY K (hs, symbolic)"
  echo "  LIN-CHAIN-ALL (forall-n circularity)                          : STATEMENT FORMALIZED; NOT YET MECHANIZED"
  echo "    (prover boundary documented; base+step = induction pieces)"
  echo "  KEVM + cryptographic lineage composition (Part XIII)          : OPERATIONAL (real multi-contract"
  echo "    storage -> real keccak256 Lambda records; atomicity demo: rejected transition appends NO record)"
  echo "  Merkle/authenticated state-proof interface                    : NOT YET MECHANIZED (declared, no rules)"
  echo "  ValidSignature / hash resistance                              : ASSUMED (impl vector-validated)"
  echo "  Calldata-level declared-input binding                         : REQUIRES CLIENT/PROTOCOL SUPPORT"
  echo
  echo "CONTENTS (paths relative to this MANIFEST)"
  echo "------------------------------------------"
  echo "  SRW3-Phase{0D,1A,1B}-*.md/pdf        Prior research reports"
  echo "  SRW3-Phase1C-Crypto-Report.md/pdf    Phase-1C report"
  echo "  SRW3-Phase1D-Verifiable-Lineage-Report.md/pdf  Phase-1D report (MD = source of truth)"
  echo "  semantics/phase1d/                   Lambda schema + verifier + gate + symb layer + 6 demos"
  echo "  semantics/kevm/                      Frozen 1A binding + 1B gen binding + 1D composition (srw3-lin-evm.k)"
  echo "  semantics/phase1c/                   Crypto lineage (srw3ck.k), probe, shim sources"
  echo "  proofs/phase1d/                      Chain-continuity claims (lin_chain.k)"
  echo "  scripts/                             Complete audit + rebuild + generation pipeline"
  echo "    rebuild_env_1d.sh                  Full toolchain recipe (fourth-reset recovery)"
  echo "    rebuild_1c_llvm_1d.sh              1C crypto-layer rebuild + re-verification"
  echo "    audit_matrix_v6.sh                 Part I freeze matrix"
  echo "    run_lin_demos_1d.sh                Phase-1D demonstration matrix runner"
  echo "  transcripts/audit/phase1d_*.txt      1D evidence (lin demos / kevm composition / chain proof / 1C rebuild)"
  echo "  git/                                 Repository bundles (off-site: github.com/Dannyednut/SRW3 branch phase1c)"
  echo "  worklog.md                           Full multi-agent work log"
  echo
  echo "NOTE ON GIT PROVENANCE"
  echo "----------------------"
  echo "  Fourth sandbox reset: the working repository was restored by cloning the"
  echo  "  off-site remote (push-every-step discipline) — zero work lost. All Phase-1D"
  echo "  sources are tracked in git branch phase1c (commits 3ef0d08..)."
  echo
  echo "BASELINE PROVENANCE"
  echo "-------------------"
  echo "  SRW3_Phase_0D_Implementation_v1.0.zip sha256:"
  echo "  $(cat "$ROOT/srw3-baseline.sha256")"
} > "$MANIFEST"

# ---- 10. sha256 chain ----
cd "$STG" && find . -type f ! -name MANIFEST.txt -exec sha256sum {} \; | sort -k2 >> "$MANIFEST.tmp"
{ echo; echo "SHA256 CHAIN (files as listed above)"; echo "-------------------------------------"; cat "$MANIFEST.tmp"; } >> "$MANIFEST"
rm -f "$MANIFEST.tmp"

# ---- 11. zip + sidecar ----
cd "$DL" && rm -f "$ZIP" && zip -qr "$ZIP" srw3-artifacts -x "srw3-artifacts/MANIFEST.tmp" && sha256sum "$ZIP" > "$ZIP.sha256" && sha256sum -c "$ZIP.sha256" && echo "BUNDLE_OK: $ZIP ($(du -h "$ZIP" | cut -f1))"
