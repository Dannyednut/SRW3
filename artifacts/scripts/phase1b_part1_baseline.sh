#!/bin/bash
# =============================================================================
# SRW3 Phase 1B — Part I: freeze Phase-1A as regression baseline.
#   1. record provenance (Phase-1A commit, bundle SHA, toolchain, tree status)
#   2. sync the (hitherto uncommitted) Phase-1A LLVM work-products into the
#      git repo and commit them as branch `phase1a-final`
#   3. create the clean Phase-1B starting branch `phase1b-start`
#   4. archive the Phase-1A matrix-v4 transcript (the re-run appends to it)
# No Phase-1A source file is modified.
# =============================================================================
set -u
export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-}"
export PYTHONPATH="${PYTHONPATH:-}"
source /home/z/my-project/tools/env.sh
REPO=/home/z/my-project/srw3-work
WORK=/home/z/my-project/srw3-kevm
SUB=$REPO/srw3-kevm
OUTDIR=$WORK/transcripts/provenance
mkdir -p "$OUTDIR"

echo "=== [1] provenance record ==="
{
  echo "# SRW3 Phase 1B — Part I baseline record ($(date -u +'%Y-%m-%dT%H:%M:%SZ'))"
  echo
  echo "## Phase-1A anchors (frozen, from Phase-1A report/bundle)"
  echo "* Phase-1A recorded commit : $(cd $REPO && git rev-parse phase1-start)  (branch phase1-start, label 'Phase-1 starting state')"
  echo "* Phase-1A artifact bundle : download/SRW3-Phase1A-Artifact-Bundle.zip"
  echo "* bundle sha256            : $(sha256sum /home/z/my-project/download/SRW3-Phase1A-Artifact-Bundle.zip | cut -d' ' -f1)"
  echo "* K                        : $(kompile --version 2>/dev/null | sed -n 's/K version:[[:space:]]*//p') (llvm-backend $(krun --version 2>/dev/null | sed -n 's/.*llvm-backend[[:space:]]*\([0-9.]*\).*/\1/p' | head -1))"
  echo "* KEVM                     : v1.0.921 (source; \$KEVMSRC=$KEVMSRC)"
  echo "* blockchain-k-plugin      : 207ae5121e5178a09742ed746f2d15e34b1750cc (K files; C libkrypto not built)"
  echo "* Z3                       : $(z3 --version 2>/dev/null)"
  echo "* clang (LLVM backend)     : 15.0.6-4+b1 via LLVM_KOMPILE_CXX"
  echo
  echo "## Working-tree status at Phase-1B start"
  echo "* git repo HEAD before sync: $(cd $REPO && git rev-parse HEAD) ($(cd $REPO && git branch --show-current))"
  echo "* git repo status          : $(cd $REPO && git status --porcelain | wc -l) dirty entries"
  echo "* NOTE: the Phase-1A LLVM work-products (proofs/boundaries/, llvm transcripts,"
  echo "*       matrix v4) existed only in the working area ($WORK) and were NOT"
  echo "*       part of commit 80448f2 (which records the theorem-closure tree that"
  echo "*       Phase 1A started from). They are committed below as 'phase1a-final'"
  echo "*       so that Phase 1B starts from the complete Phase-1A final tree."
} > "$OUTDIR/phase1b_baseline.md"
cat "$OUTDIR/phase1b_baseline.md"

echo "=== [2] sync working area -> git repo (tracked content only) ==="
# tracked-content sync; excludes = .gitignore build dirs + repo-owned .gitignore
rsync -rc --delete \
  --exclude .gitignore \
  --exclude 'hs-out/' --exclude 'hs-search-out/' --exclude 'llvm-out/' --exclude 'llvm-search-out/' \
  --exclude 'bridge-out/' --exclude 'kevm-hs-out/' --exclude 'kevm-llvm-out/' \
  --exclude 'ghost-out/' --exclude 'tier3-out/' --exclude 'safeform-out/' --exclude 'bridgegen-out/' \
  --exclude 'defects-out/' --exclude 'defects-search-out/' \
  --exclude '*-kompiled/' \
  "$WORK/" "$SUB/"
cd "$REPO"
git add -A srw3-kevm
git status --porcelain | head -40

echo "=== [3] commit phase1a-final ==="
git branch -f phase1a-final phase1-start   # reset any stale pointer to the starting commit
git checkout -q phase1a-final
if git diff --cached --quiet; then
  echo "nothing to commit (unexpected)"
else
  git -c user.name="SRW3" -c user.email="srw3@local" commit -q \
    -m "Phase-1A final tree: LLVM retarget + artifact-integrity work-products

Working-area state at Phase-1A completion (report: SRW3-Phase1A-LLVM-Report,
bundle sha256 1fc51f29...): proofs/boundaries B1-B3, llvm/evm-llvm transcripts,
matrix v4 record, updated audit transcripts. No Phase-1B changes included."
fi
P1A=$(git rev-parse HEAD)
P1AP=$(git rev-parse HEAD~1)
echo "phase1a-final = $P1A (parent $P1AP)"

echo "=== [4] clean Phase-1B starting branch ==="
git branch -f phase1b-start "$P1A"
git checkout -q phase1b-start
P1B=$(git rev-parse HEAD)
echo "phase1b-start = $P1B"
{
  echo
  echo "## Phase-1B starting point"
  echo "* phase1a-final : $P1A (parent $P1AP = 80448f2-lineage; full Phase-1A tree)"
  echo "* phase1b-start : $P1B (identical tree, clean branch for Phase-1B work)"
  echo "* status        : $(git status --porcelain | wc -l) dirty entries (expect 0)"
} >> "$OUTDIR/phase1b_baseline.md"

echo "=== [5] archive Phase-1A matrix-v4 transcript before re-run ==="
cd "$WORK/transcripts/audit"
if [ -f full_matrix_v4.txt ] && [ ! -f full_matrix_v4.phase1a.txt ]; then
  cp full_matrix_v4.txt full_matrix_v4.phase1a.txt
  echo "archived -> transcripts/audit/full_matrix_v4.phase1a.txt ($(wc -l < full_matrix_v4.phase1a.txt) lines)"
fi

echo "PART1-BASELINE-DONE"
