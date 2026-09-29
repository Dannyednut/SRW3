#!/bin/bash
# Audit P7: full verification matrix re-run after reconciliation artifacts
source /home/z/my-project/tools/env.sh
cd /home/z/my-project/srw3-kevm
OUT=transcripts/audit/full_matrix.txt
: > "$OUT"
{
echo "## P7 — full verification matrix re-run (post-reconciliation)"
echo "## Confirms the reconciliation/audit artifacts changed no previous result."
echo "## date: $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
echo
} >> "$OUT"

echo "=== [1] Baseline Python suite (canonical make test) — expect 15/15 ===" >> "$OUT"
( cd /home/z/my-project/srw3-work && timeout 300 make test ) >> "$OUT" 2>&1
echo "[1] exit: $?" >> "$OUT"
echo >> "$OUT"

echo "=== [2] Abstract demo suite (13 demos) ===" >> "$OUT"
timeout 2400 bash k/run_demos.sh > /tmp/demos_matrix.txt 2>&1
echo "[2] exit: $?" >> "$OUT"
echo "--- demo verdict lines ---" >> "$OUT"
rg -n "DEMO:|result\s+:|committed\s+:|head\s+:|lineageNext\s+:" /tmp/demos_matrix.txt >> "$OUT" 2>&1
echo >> "$OUT"

echo "=== [3] Claims 1,2,3,4a,4b (kprove, SRW3-CLAIMS) — expect #Top, no vacuity ===" >> "$OUT"
timeout 1800 kprove k/srw3.k -d k/hs-out --spec-module SRW3-CLAIMS > /tmp/kp_matrix.txt 2>&1
echo "[3] exit: $?  (#Top count: $(rg -c '#Top' /tmp/kp_matrix.txt || echo 0))" >> "$OUT"
rg -n "WarnTrivial|WarnStuck|#Top" /tmp/kp_matrix.txt | head -8 >> "$OUT"
echo >> "$OUT"

echo "=== [4] Negative control — expect FAILURE (non-zero exit) ===" >> "$OUT"
timeout 900 kprove proofs/negative_control.k -d k/hs-out -I .. -I . --spec-module SRW3-NEGCONTROL > /tmp/nc_matrix.txt 2>&1
echo "[4] exit: $? (non-zero = correctly fails)" >> "$OUT"
rg -n "WarnStuck" /tmp/nc_matrix.txt | head -2 >> "$OUT"
echo >> "$OUT"

echo "=== [5] KEVM demos (real EVM execution) ===" >> "$OUT"
for d in evm_positive evm_negative_stale evm_minimal; do
  timeout 1800 krun k/kevm/demos/$d.srw3evm -d k/kevm/kevm-hs-out -cMODE=NORMAL -cSCHEDULE=CANCUN -cUSEGAS=false -cCHAINID=1 > /tmp/evm_$d.txt 2>&1
  echo "--- $d: krun exit: $?" >> "$OUT"
  python3 - /tmp/evm_$d.txt <<'PYEOF' >> "$OUT"
import re, sys
txt=open(sys.argv[1]).read()
blocks=re.findall(r'<kevm>.*?</kevm>', txt, re.S)
f=blocks[-1] if blocks else ''
k=re.search(r'<k>\s*(.*?)\s*</k>', f, re.S)
kc=' '.join(k.group(1).split()) if k else '?'
m=re.search(r'#w3State\s*\(\s*\.\.\.\s*s:\s*(.*?)\s*,\s*ln:\s*(.*?)\s*,\s*n:\s*(\S+)\s*,\s*h:\s*(\S+)\s*\)', kc, re.S)
if m:
    print('    carrier: s=%s ln=%s n=%s h=%s' % (' '.join(m.group(1).split()), ' '.join(m.group(2).split()), m.group(3), m.group(4)))
else:
    print('    carrier: (none)')
for addr,name in ((4097,'oracle'),(4098,'lending'),(4099,'liq')):
    m=re.search(r'<acctID>\s*%d\s*</acctID>.*?<storage>\s*(.*?)\s*</storage>'%addr, f, re.S)
    print('    %-8s: %s' % (name, ' '.join(m.group(1).split()) if m else '?'))
PYEOF
done
echo >> "$OUT"

echo "=== [6] New audit artifacts (already run; verdict summary) ===" >> "$OUT"
echo "  bridge reconciliation (9 ground claims): kprove exit 0, #Top — see audit/bridge_reconciliation.txt" >> "$OUT"
echo "  phantom defect demonstrations: see audit/phantom_defect.txt + phantom_defect_search.txt" >> "$OUT"
echo "  induction attempts: record-4a/4b PROVED; full-theorem attempts stuck — see audit/induction_attempt.txt" >> "$OUT"
echo >> "$OUT"
echo "=== done ===" >> "$OUT"
