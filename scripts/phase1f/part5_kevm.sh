#!/bin/bash
# SRW3 Phase 1F — Part 5: KEVM instrumented-execution binding (LLVM, real
# keccak + secp256k1). The Level-3 demonstration over REAL EVM execution:
# the effect trace is EXECUTION-DERIVED (built by additive #next-interception
# rules from the actual opcode stream); the record binds the PRESENTED
# artifacts; the LEVEL-3 EXECUTION CHECK confronts the declared effects with
# the write projection of the execution-derived trace.
#   evm_exec_commit : honest  -> valid-f   -> COMMIT (lineage appended)
#   evm_exec_hidden : state-invisible hidden SSTORE (slot already holds its
#                     value; every state layer blind) -> invalid-declared-exec
#                     -> REJECT + RESTORE (no lineage record)
#   evm_exec_tamper : tampered presented trace -> invalid-effdecl
#                     -> REJECT + RESTORE
set -u
source /home/z/my-project/tools/env.sh
SRC=/home/z/my-project/srw3-kevm
OUT=$SRC/phase1f/transcripts/part5_kevm_binding.txt
: > "$OUT"
log() { echo "$@" | tee -a "$OUT"; }

log "=== SRW3 Phase 1F — Part 5: KEVM INSTRUMENTED-EXECUTION BINDING ==="
log "=== generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC') ==="
log "definition : k/kevm/srw3-exec-evm-demos.k (module SRW3-EXEC-EVM-DEMOS;"
log "             additive over the frozen srw3-auth-evm.k / srw3-lin-evm.k /"
log "             srw3-gen-binding.k / srw3-kevm.k chain)"
log "sha256(srw3-exec-evm.k)      = $(sha256sum $SRC/k/kevm/srw3-exec-evm.k | cut -d' ' -f1)"
log "sha256(srw3-exec-evm-demos.k)= $(sha256sum $SRC/k/kevm/srw3-exec-evm-demos.k | cut -d' ' -f1)"
log "krun flags : -cCHAINID=1 -cMODE=NORMAL -cSCHEDULE=CANCUN -cUSEGAS=false"
log "             (krun exit=1 = designed carrier terminal, the 1E precedent)"
log ""

PASS=0; FAIL=0
run() { # run <demo> <expected-verdict>
  local D="$1" EXPECT="$2"
  local T0=$(date +%s)
  timeout 500 krun "$SRC/k/kevm/demos/$D.srw3evm" -d "$SRC/k/kevm/exec-evm-demos-out" \
    -cCHAINID=1 -cMODE=NORMAL -cSCHEDULE=CANCUN -cUSEGAS=false > "/tmp/kevm_$D.txt" 2>&1
  local EX=$?
  local T1=$(date +%s)
  local V=$(python3 -c "
import re
t=open('/tmp/kevm_$D.txt').read()
vs=sorted(set(re.findall(r'\"(valid-f|invalid-[a-z-]*)\"', t)))
print(';'.join(vs))")
  local NC=$(python3 -c "print(open('/tmp/kevm_$D.txt').read().count('#w3ExecState'))")
  log "--- $D (krun exit=$EX, $((T1-T0))s, carriers=$NC)"
  log "    verdict(s): $V"
  if [ "$V" = "$EXPECT" ]; then
    log "    EXPECTED MATCH: $EXPECT"; PASS=$((PASS+1))
  else
    log "    EXPECTED: $EXPECT"; log "    *** MISMATCH ***"; FAIL=$((FAIL+1))
  fi
  log ""
}

run evm_exec_commit "valid-f"
run evm_exec_hidden "invalid-declared-exec"
run evm_exec_tamper "invalid-effdecl"

log "SUMMARY: PASS=$PASS FAIL=$FAIL"
log "carrier note: each #w3ExecState carries the record bound to the PRESENTED"
log "artifacts, the anchored state root over REAL storage, the EXECUTION-DERIVED"
log "trace, and the verdict; rejects show the same carrier shape with the"
log "failing verdict + full storage restore (commit/lineage atomicity)."
log ""
log "PART5_KEVM_DONE"
