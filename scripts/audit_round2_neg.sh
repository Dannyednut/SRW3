#!/bin/bash
# Round-2 falsification probe: G8/G9 WITHOUT the wfCoverage premise must FAIL
# (this validates that the requires is load-bearing, not decorative).
source /home/z/my-project/tools/env.sh
cd /home/z/my-project/srw3-kevm
OUT=transcripts/audit/generalized_bridge_negative.txt
: > "$OUT"
{
echo "## Round-2 audit item 2 — necessity probe: agreement claims WITHOUT wfCoverage"
echo "## A modified G8/G9 with the coverage premise dropped must FAIL (exit non-zero):"
echo "##   - G8 over Z: counterexample X=15, V=-5 (IAB no longer entails IA)"
echo "##   - G9 over Z: counterexample AU=0 (unauthenticated oracle)"
echo "## date: $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
echo
} >> "$OUT"

cat > /tmp/genbridge_neg.k <<'EOF'
requires "/home/z/my-project/srw3-kevm/proofs/generalized_bridge.k"
module SRW3-BRIDGE-GEN-NEG
  imports SRW3-BRIDGE-GEN

  claim // N1 = G8 minus the coverage premise (must FAIL: X=15, V=-5)
    <k> ( rootOk(gAuth6(), "appB", "t0")
          andBool gateOk(.Map, stK(appA, 0) |-> X:Int stK(appB, 0) |-> V:Int,
                         .List, gAuth6(), completeRegistry(), .Map) )
        ==Bool
        gateAccept(completeRegistry(), SetItem(appB), appB, gAuth6(),
                   stK(appA, 0) |-> X stK(appB, 0) |-> V)
        => true
    </k>

  claim // N2 = G9 minus the coverage premise (must FAIL: AU=0)
    <k> ( rootOk(gAuth6(), "lending", "t0")
          andBool gateOk(.Map, gSgen(PR:Int, AU:Int, LP:Int, LD:Int, LT:Int, LL:Int),
                         .List, gAuth6(), chainCompleteRegistry(), .Map) )
        ==Bool
        gateAccept(chainCompleteRegistry(), SetItem(lending), lending, gAuth6(),
                   gSgen(PR, AU, LP, LD, LT, LL))
        => true
    </k>
endmodule
EOF
echo "--- kprove (N1, N2 — expected FAILURE) ---" >> "$OUT"
timeout 900 kprove /tmp/genbridge_neg.k -d proofs/bridgegen-out -I /tmp -I k \
  --spec-module SRW3-BRIDGE-GEN-NEG > /tmp/kpneg.txt 2>&1
echo "kprove exit: $?  (non-zero = coverage premise is load-bearing; prover rejects the under-premised generalization)" >> "$OUT"
rg -n "WarnStuck|WarnTrivial|#Top|not entail|Failed|residual" /tmp/kpneg.txt | head -6 >> "$OUT" 2>&1
sed -n '1,25p' /tmp/kpneg.txt >> "$OUT"
echo >> "$OUT"
echo "=== done ===" >> "$OUT"
echo "probe result:"; rg "kprove exit|WarnStuck" "$OUT" | head -4
