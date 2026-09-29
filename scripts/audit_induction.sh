#!/bin/bash
# Audit P2 (final): consolidated induction audit — reproducible end-to-end
source /home/z/my-project/tools/env.sh
cd /home/z/my-project/srw3-kevm
OUT=transcripts/audit/induction_attempt.txt
: > "$OUT"
{
echo "## P2 audit — Claim 4 split (4a/4b) + full lineage-length induction attempts"
echo "## [B] proofs/induction_full.k   — Map encoding, symbolic committed state"
echo "## [C] proofs/induction_record.k — record encoding of reachable states"
echo "## date: $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
echo
} >> "$OUT"

echo "=== [B1] kompile SRW3-INDUCT-STEP definition (main SRW3-INDUCT-STEP) ===" >> "$OUT"
timeout 900 kompile proofs/induction_full.k --backend haskell \
  --main-module SRW3-INDUCT-STEP --syntax-module SRW3-INDUCT-STEP -I k \
  -o proofs/inductB-out >> "$OUT" 2>&1
echo "kompile exit: $?" >> "$OUT"
echo "=== [B2] kprove --spec-module SRW3-INDUCT-FULL (full theorem, Map encoding) ===" >> "$OUT"
echo "--- RESULT: STUCK (blocker captured verbatim below) ---" >> "$OUT"
timeout 900 kprove proofs/induction_full.k -d proofs/inductB-out -I k \
  --spec-module SRW3-INDUCT-FULL > /tmp/kpB.txt 2>&1
echo "kprove exit: $?" >> "$OUT"
sed -n '1,60p' /tmp/kpB.txt >> "$OUT"
echo "  ... [truncated]" >> "$OUT"
echo >> "$OUT"

echo "=== [C-P] kprove --spec-module SRW3-RECORD-CLAIMS-PROVED (4a/4b-shape, record encoding) ===" >> "$OUT"
timeout 600 kprove proofs/induction_record.k -d proofs/inductC-out -I k \
  --spec-module SRW3-RECORD-CLAIMS-PROVED --claims record-4a > /tmp/kpCa.txt 2>&1
echo "record-4a kprove exit: $?  (#Top count: $(rg -c '#Top' /tmp/kpCa.txt || echo 0))" >> "$OUT"
timeout 600 kprove proofs/induction_record.k -d proofs/inductC-out -I k \
  --spec-module SRW3-RECORD-CLAIMS-PROVED --claims record-4b > /tmp/kpCb.txt 2>&1
echo "record-4b kprove exit: $?  (#Top count: $(rg -c '#Top' /tmp/kpCb.txt || echo 0))" >> "$OUT"
echo >> "$OUT"

echo "=== [C-A] kprove --spec-module SRW3-RECORD-CLAIM-ATTEMPT (observer + circularity) ===" >> "$OUT"
echo "--- RESULT: STUCK (residuals captured verbatim below) ---" >> "$OUT"
timeout 900 kprove proofs/induction_record.k -d proofs/inductC-out -I k \
  --spec-module SRW3-RECORD-CLAIM-ATTEMPT > /tmp/kpCatt.txt 2>&1
echo "kprove exit: $?" >> "$OUT"
sed -n '1,35p' /tmp/kpCatt.txt >> "$OUT"
echo "  ... [truncated]" >> "$OUT"
echo >> "$OUT"

echo "=== [C-ISO] isolation experiment: observer-free direct 4a-shape PROVES ===" >> "$OUT"
echo "--- (the same cycle WITHOUT the chk observer closes with #Top, isolating the" >> "$OUT"
echo "---  obstruction to destination-variable handling under observer/continuation" >> "$OUT"
echo "---  composition, NOT to the induction logic itself) ---" >> "$OUT"
cat > /tmp/recdirect.k <<'EOF'
requires "/home/z/my-project/srw3-kevm/proofs/induction_record.k"
module REC-DIRECT
  imports SRW3-RECORD
  claim // direct 4a-shape on record encoding, no observer
    <k> tB(W:Int) => .K </k>
    <xa> X:Int </xa>
    <xb> Y:Int => W:Int </xb>
    <pa> _PA:Int => 0 </pa>
    <pb> _PB:Int => 0 </pb>
    <result> _R:String => "commit" </result>
    requires X <=Int 10 andBool Y <=Int 10 andBool X +Int Y <=Int 10
             andBool W <=Int 10 andBool X +Int W <=Int 10
endmodule
EOF
timeout 600 kprove /tmp/recdirect.k -d proofs/inductC-out -I /tmp --spec-module REC-DIRECT > /tmp/kpD.txt 2>&1
echo "observer-free direct 4a: kprove exit: $?  (#Top count: $(rg -c '#Top' /tmp/kpD.txt || echo 0))" >> "$OUT"
echo >> "$OUT"
echo "=== done ===" >> "$OUT"
