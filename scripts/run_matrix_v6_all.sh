#!/bin/bash
# Phase 1D Part I — run all remaining matrix v6 stages sequentially (background).
# Idempotent-ish: stages append to full_matrix_v6.txt; ghostgen resumes itself.
M=/home/z/my-project/srw3-work/scripts/audit_matrix_v6.sh
for st in claims r2 defect ghost tier3 kevm llvm gendemos genbind ckcrypto verdict; do
  echo "[$(date -u +%H:%M:%S)] stage $st START" >> /tmp/matrix_v6_progress.log
  bash "$M" "$st" >> /tmp/matrix_v6_progress.log 2>&1
  echo "[$(date -u +%H:%M:%S)] stage $st EXIT=$?" >> /tmp/matrix_v6_progress.log
done
echo "[$(date -u +%H:%M:%S)] ghostgen (long, resumable) START" >> /tmp/matrix_v6_progress.log
bash "$M" ghostgen >> /tmp/matrix_v6_progress.log 2>&1
echo "[$(date -u +%H:%M:%S)] ghostgen EXIT=$?" >> /tmp/matrix_v6_progress.log
echo "MATRIX_V6_ALL_DONE" >> /tmp/matrix_v6_progress.log
