#!/bin/bash
# SRW3 Phase 1R — definition kompiles (the 1Q definitions of record; NO new
# machine is generated unless a later experiment needs one — the bounded
# diagnostics use the ORIGINAL Q runner with symbolic command spines).
# Idempotent; per-target logs under /tmp/kompile-1r-*.log.
set -u
cd /home/z/my-project/SRW3 || exit 1
source /home/z/my-project/tools/env.sh
export LIBRARY_PATH="$TOOLS/extract/syslibs:$LIBRARY_PATH"
INC="-I $PWD/phase1n/semantics -I $PWD/phase1m/semantics -I $PWD/phase1g/semantics -I $PWD/phase1f/semantics -I $PWD/phase1e/semantics -I $PWD/k/phase1d -I $PWD/k/kevm/kproj-e1e/plugin"

kd() { # kd <src> <mainmod> <outdir> <tag>
  local SRC=$1 MM=$2 O=$3 TAG=$4
  if [ -d "$O" ]; then echo "[1R-kompile] HAVE $O ($TAG)"; return 0; fi
  echo "[1R-kompile] $SRC -> $O ($TAG)"
  kompile "$SRC" --backend haskell --main-module "$MM" $INC -o "$O" \
    > "/tmp/kompile-1r-$TAG.log" 2>&1
  local RC=$?
  echo "[1R-kompile]   -> rc=$RC ($TAG)"
  return $RC
}

kd phase1q/semantics/abs-machine-weak-q.k SRW3N-ABS-WEAK-Q /tmp/p1q-weakq-def weakq  || exit 1
kd phase1q/proofs/repro/univ-repro-qf.k TOY-QF /tmp/p1q-toyf-def toyf               || exit 1
kd phase1q/tests/abs-machine-mut-stale-q.k SRW3N-ABS-MUT-STALE-Q /tmp/p1q-mutstale-def mutstale || exit 1
kd phase1q/tests/abs-machine-mut-flip-q.k  SRW3N-ABS-MUT-FLIP-Q  /tmp/p1q-mutflip-def  mutflip  || exit 1
kd phase1q/tests/abs-machine-mut-omit-q.k  SRW3N-ABS-MUT-OMIT-Q  /tmp/p1q-mutomit-def  mutomit  || exit 1
echo "1R_KOMPILES_DONE"
