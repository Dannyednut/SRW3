#!/bin/bash
# Audit P1: reconciliation bridge — kprove the agreement/disagreement ground claims
source /home/z/my-project/tools/env.sh
cd /home/z/my-project/srw3-kevm
OUT=transcripts/audit/bridge_reconciliation.txt
: > "$OUT"
{
echo "## SRW3 reconciliation bridge — gateOk/rootOk vs evaluated-obligation gate"
echo "## step 1: kompile k/compat/srw3-bridge.k --main-module SRW3-BRIDGE --syntax-module SRW3-BRIDGE -o k/compat/bridge-out"
echo "## step 2: kprove k/compat/srw3-bridge.k -d k/compat/bridge-out --spec-module SRW3-BRIDGE-CLAIMS"
echo "## date: $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
echo
} >> "$OUT"
echo "--- kompile (bridge definition) ---" >> "$OUT"
timeout 900 kompile k/compat/srw3-bridge.k --backend haskell --main-module SRW3-BRIDGE --syntax-module SRW3-BRIDGE -I k -o k/compat/bridge-out >> "$OUT" 2>&1
echo "kompile exit: $?" >> "$OUT"
echo "--- kprove (ground agreement/disagreement claims) ---" >> "$OUT"
timeout 900 kprove k/compat/srw3-bridge.k -d k/compat/bridge-out -I k --spec-module SRW3-BRIDGE-CLAIMS >> "$OUT" 2>&1
echo "kprove exit: $?" >> "$OUT"
echo "=== done; transcript at $OUT ==="
tail -5 "$OUT"
