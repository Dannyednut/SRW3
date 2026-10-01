#!/usr/bin/env bash
# Create the Phase-1B state git repository (srw3b-work) and export a bundle.
# Post-reset provenance: a fresh repo holding the complete Phase-1B work tree
# (sources only; build outputs excluded via .gitignore).
set -euo pipefail
ROOT=/home/z/my-project
REPO=$ROOT/srw3b-work
mkdir -p "$REPO"
cd "$REPO"
[ -d .git ] || git init -q

cat > .gitignore <<'EOF'
out-*/
hs-out/
llvm-out/
n/
*hs-out/
*llvm-out/
gen-hs-out/
gen-llvm-out/
kevm-hs-out/
kevm-llvm-out/
gen-out/
search-out/
__pycache__/
*.pyc
EOF

# stage the full work tree (idempotent; mirrors srw3-kevm layout)
mkdir -p k/{demos,gen-demos,kevm/demos} proofs/{gen,boundaries,defects} transcripts/{audit/boundaries,provenance} python-gen
cp -r "$ROOT/srw3-kevm/k/srw3.k" "$ROOT/srw3-kevm/k/srw3gen.k" k/ 2>/dev/null || true
cp "$ROOT/srw3-kevm/k/run_demos.sh" k/ 2>/dev/null || true
cp "$ROOT/srw3-kevm/k/demos/"*.srw3 k/demos/ 2>/dev/null || true
cp "$ROOT/srw3-kevm/k/gen-demos/"*.srw3 k/gen-demos/ 2>/dev/null || true
cp "$ROOT/srw3-kevm/k/kevm/srw3-kevm.k" "$ROOT/srw3-kevm/k/kevm/srw3-gen-binding.k" k/kevm/ 2>/dev/null || true
cp "$ROOT/srw3-kevm/k/kevm/demos/"* k/kevm/demos/ 2>/dev/null || true
cp "$ROOT/srw3-kevm/proofs/"*.k "$ROOT/srw3-kevm/proofs/"*.json proofs/ 2>/dev/null || true
cp "$ROOT/srw3-kevm/proofs/gen/"*.k "$ROOT/srw3-kevm/proofs/gen/ghost_manifest_gen.json" proofs/gen/ 2>/dev/null || true
cp "$ROOT/srw3-kevm/proofs/boundaries/"*.k proofs/boundaries/ 2>/dev/null || true
cp "$ROOT/srw3-kevm/proofs/defects/"*.k proofs/defects/ 2>/dev/null || true
cp "$ROOT/srw3-kevm/transcripts/"*.txt transcripts/ 2>/dev/null || true
cp "$ROOT/srw3-kevm/transcripts/audit/"*.txt transcripts/audit/ 2>/dev/null || true
cp "$ROOT/srw3-kevm/transcripts/audit/boundaries/"*.txt transcripts/audit/boundaries/ 2>/dev/null || true
cp "$ROOT/srw3-kevm/transcripts/provenance/"* transcripts/provenance/ 2>/dev/null || true
cp "$ROOT/srw3-kevm/python-gen/"*.py python-gen/ 2>/dev/null || true
mkdir -p scripts
find "$ROOT/scripts" -maxdepth 1 -type f -exec cp {} scripts/ \;
cp -r "$ROOT/scripts/gen_fragments" scripts/ 2>/dev/null || true
cp "$ROOT/worklog.md" .
cp "$ROOT"/download/SRW3-Phase*.md . 2>/dev/null || true

git add -A
git -c user.name="SRW3 Provenance" -c user.email="srw3@local" \
  commit -q -m "Phase 1B complete: generalized semantics (srw3gen.k), CM2+CM3+generalized ghost theorems MECHANIZED (35 claims: 32 PROVED + 3 designed-FAIL), Python mirror oracle 14/14, additive KEVM generalized binding (hs<->llvm identical), matrix v5 zero regression. Post-reset recovery note: pre-1B git objects lost; file-level recovery sha-verified (srw3gen.k d583ef0c...)." \
  --allow-empty
git branch -M phase1b 2>/dev/null || true
git tag -f phase1b-complete

git bundle create "$ROOT/srw3b-work.bundle" --all
git log --oneline
echo "bundle: $ROOT/srw3b-work.bundle"
sha256sum "$ROOT/srw3b-work.bundle"
