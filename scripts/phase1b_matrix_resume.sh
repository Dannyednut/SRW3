#!/bin/bash
export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-}"
source /home/z/my-project/tools/env.sh
M=/home/z/my-project/scripts/audit_matrix_v4.sh
for st in demos claims r2 defect ghost tier3 kevm llvm verdict; do
  echo ">>> stage $st start: $(date -u +%H:%M:%S)"
  bash "$M" "$st" || echo ">>> stage $st returned $?"
  echo ">>> stage $st end  : $(date -u +%H:%M:%S)"
done
echo "MATRIX-V4-RESUME-DONE"
