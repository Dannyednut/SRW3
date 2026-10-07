#!/bin/bash
# SRW3 Phase 1G — Part 5: KEVM AUTHORITY ADAPTER (Tier G2; LLVM, real
# keccak + secp256k1). The authority demonstration over REAL EVM execution:
# the certificate is constructed FROM THE RUN (Mode A rel=2; source = the
# authorized execution client; chain = [consensus root]; effect digest =
# the EXECUTION-DERIVED trace digest, so authbind forces presented ==
# executed).
#   evm_authz_commit   : honest  -> valid-g   -> COMMIT (lineage appended)
#   evm_authz_selfauth : the self-authorizing certificate (client claims
#                        LEVEL 0, CM-G3a) -> invalid-authlevel -> REJECT+RESTORE
#   evm_authz_tamper   : tampered presented trace -> caught by the FROZEN 1F
#                        chain first (invalid-effdecl) -> REJECT+RESTORE
set -u
source /home/z/my-project/tools/env.sh
SRC=/home/z/my-project/srw3-kevm
OUT=$SRC/phase1g/transcripts/part5_kevm_authz.txt
: > "$OUT"
log() { echo "$@" | tee -a "$OUT"; }

log "=== SRW3 Phase 1G — Part 5: KEVM AUTHORITY ADAPTER (TIER G2) ==="
log "=== generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC') ==="
log "definition : k/kevm/srw3-authz-evm-demos.k (module SRW3-AUTHZ-EVM-DEMOS;"
log "             additive over the frozen srw3-exec-evm.k / srw3-auth-evm.k /"
log "             srw3-lin-evm.k / srw3-gen-binding.k / srw3-kevm.k chain)"
log "sha256(srw3-authz-evm.k)      = $(sha256sum $SRC/k/kevm/srw3-authz-evm.k | cut -d' ' -f1)"
log "sha256(srw3-authz-evm-demos.k)= $(sha256sum $SRC/k/kevm/srw3-authz-evm-demos.k | cut -d' ' -f1)"
log "krun flags : -cCHAINID=1 -cMODE=NORMAL -cSCHEDULE=CANCUN -cUSEGAS=false"
log "             (krun exit=1 = designed carrier terminal, the 1E/1F precedent)"
log ""

PASS=0; FAIL=0
run() { # run <demo> <expected-verdict>
  local D="$1" EXPECT="$2"
  local T0=$(date +%s)
  timeout 600 krun "$SRC/k/kevm/demos/$D.srw3evm" -d "$SRC/k/kevm/authz-evm-out" \
    -cCHAINID=1 -cMODE=NORMAL -cSCHEDULE=CANCUN -cUSEGAS=false > "/tmp/kevm1g_$D.txt" 2>&1
  local EX=$?
  local T1=$(date +%s)
  local V=$(python3 -c "
import re
t=open('/tmp/kevm1g_$D.txt').read()
vs=sorted(set(re.findall(r'\"(valid-g|valid-f|invalid-[a-z-]*)\"', t)))
print(';'.join(vs))")
  local NC=$(python3 -c "print(open('/tmp/kevm1g_$D.txt').read().count('#w3GState'))")
  log "--- $D (krun exit=$EX, $((T1-T0))s, carriers=$NC)"
  log "    verdict(s): $V"
  if [ "$V" = "$EXPECT" ]; then
    log "    EXPECTED MATCH: $EXPECT"; PASS=$((PASS+1))
  else
    log "    EXPECTED: $EXPECT"; log "    *** MISMATCH ***"; FAIL=$((FAIL+1))
  fi
  log ""
}

run evm_authz_commit "valid-g"
run evm_authz_selfauth "invalid-authlevel"
run evm_authz_tamper "invalid-effdecl"

log "SUMMARY: PASS=$PASS FAIL=$FAIL"
log "PART5_KEVM_AUTHZ_DONE"
