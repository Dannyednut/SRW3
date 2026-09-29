#!/bin/bash
# Phase 1B Part I: full re-run of the Phase-1A regression matrix v4 (all stages).
# Appends to transcripts/audit/full_matrix_v4.txt (the Phase-1A original is
# archived at full_matrix_v4.phase1a.txt). The setup stage adds a re-run header.
export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-}"
source /home/z/my-project/tools/env.sh
M=/home/z/my-project/scripts/audit_matrix_v4.sh
OUT=/home/z/my-project/srw3-kevm/transcripts/audit/full_matrix_v4.txt

# re-run header (setup truncates; re-add context lines afterwards)
bash "$M" setup
{
  echo "## NOTE: Phase-1A original record preserved at full_matrix_v4.phase1a.txt;"
  echo "## this section is the Phase-1B Part-I re-verification run (same stages)."
  echo
} >> "$OUT"

for st in py demos claims r2 defect ghost tier3 kevm llvm verdict; do
  echo ">>> stage $st start: $(date -u +%H:%M:%S)"
  bash "$M" "$st" || echo ">>> stage $st returned $?"
  echo ">>> stage $st end  : $(date -u +%H:%M:%S)"
done
echo "MATRIX-V4-RERUN-DONE"
