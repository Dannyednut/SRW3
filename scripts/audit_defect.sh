#!/bin/bash
# Audit P3: phantom-reject defect — reconstruction, demonstrations, controls
source /home/z/my-project/tools/env.sh
cd /home/z/my-project/srw3-kevm
OUT=transcripts/audit/phantom_defect.txt
: > "$OUT"
{
echo "## P3 audit — the phantom-reject defect: reconstruction + demonstrations"
echo "## date: $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
echo
} >> "$OUT"

echo "=== [0] kompile the DEFECTIVE definition (SRW3-PHANTOM) ===" >> "$OUT"
timeout 900 kompile proofs/defects/phantom_reject.k --backend haskell \
  --main-module SRW3-PHANTOM --syntax-module SRW3-PHANTOM -I k -I proofs/defects \
  -o proofs/defects/defects-out >> "$OUT" 2>&1
echo "kompile exit: $?   (note: the unbound P in the defective rule yields a WARNING, not an error)" >> "$OUT"
echo >> "$OUT"

cat > /tmp/honest.srw3 <<'EOF'
useRegistry(complete) , init(appA,0,7) , init(appB,0,3) , as(appB) , begin , w(appB,0,2) , wfCheck , gate
EOF

echo "=== [1] krun HONEST transition (7,3)->(7,2) under CORRECTED gate (hs-out) ===" >> "$OUT"
echo "    expected: result = commit (deterministic)" >> "$OUT"
krun /tmp/honest.srw3 -d k/hs-out > /tmp/kr_corr.txt 2>&1; echo "krun exit: $?" >> "$OUT"
python3 - <<'PYEOF' >> "$OUT"
import re
txt=open('/tmp/kr_corr.txt').read()
b=re.findall(r'<srw3>.*?</srw3>',txt,re.S)
f=b[-1] if b else ''
for c in ('result','committed','prospective'):
    m=re.search(r'<%s>\s*(.*?)\s*</%s>'%(c,c),f,re.S)
    print('  %-12s: %s'%(c,' '.join(m.group(1).split()) if m else '?'))
PYEOF
echo >> "$OUT"

echo "=== [2] krun SAME honest transition under DEFECTIVE gate (defects-out) ===" >> "$OUT"
echo "    phantom reject rule fires with a phantom state -> spurious reject path" >> "$OUT"
krun /tmp/honest.srw3 -d proofs/defects/defects-out > /tmp/kr_def.txt 2>&1; echo "krun exit: $?" >> "$OUT"
python3 - <<'PYEOF' >> "$OUT"
import re
txt=open('/tmp/kr_def.txt').read()
b=re.findall(r'<srw3>.*?</srw3>',txt,re.S)
f=b[-1] if b else ''
for c in ('result','committed','prospective'):
    m=re.search(r'<%s>\s*(.*?)\s*</%s>'%(c,c),f,re.S)
    print('  %-12s: %s'%(c,' '.join(m.group(1).split()) if m else '?'))
PYEOF
echo >> "$OUT"

echo "=== [3] kprove D-FALSE-REJECT under DEFECTIVE gate ===" >> "$OUT"
echo "    ('honest transition rejects' — FALSE of the intended model)" >> "$OUT"
timeout 600 kprove proofs/defects/phantom_reject.k -d proofs/defects/defects-out -I k -I proofs/defects \
  --spec-module SRW3-PHANTOM-CLAIMS > /tmp/kp1.txt 2>&1
echo "kprove exit: $?  (0 = the false claim is PROVED / stuck = phantom path visible)" >> "$OUT"
head -3 /tmp/kp1.txt >> "$OUT"
echo >> "$OUT"

echo "=== [4] kprove verbatim Claim 4a (accept-side) under DEFECTIVE gate ===" >> "$OUT"
echo "    PROVED under corrected gate; expected to FAIL here (accept-side collapse)" >> "$OUT"
timeout 600 kprove proofs/defects/phantom_reject.k -d proofs/defects/defects-out -I k -I proofs/defects \
  --spec-module SRW3-PHANTOM-ACCEPT-CLAIM > /tmp/kp2.txt 2>&1
echo "kprove exit: $?" >> "$OUT"
head -3 /tmp/kp2.txt >> "$OUT"
echo >> "$OUT"

echo "=== [5] kprove same false claim under CORRECTED gate (control) ===" >> "$OUT"
timeout 600 kprove proofs/defects/phantom_reject.k -d k/hs-out -I k -I proofs/defects \
  --spec-module SRW3-CORR-FALSE-REJECT > /tmp/kp3.txt 2>&1
echo "kprove exit: $?  (expected non-zero: correctly fails)" >> "$OUT"
head -3 /tmp/kp3.txt >> "$OUT"
echo >> "$OUT"

echo "=== done; transcript at $OUT ==="
cat "$OUT"
