#!/bin/bash
# Audit P3 (part 2): --search demonstration of phantom nondeterminism
source /home/z/my-project/tools/env.sh
cd /home/z/my-project/srw3-kevm
OUT=transcripts/audit/phantom_defect_search.txt
: > "$OUT"
{
echo "## P3 audit (part 2) — krun --search: honest transition outcome sets"
echo "## A gate decision must be deterministic; the phantom rule adds a
## spurious 'reject' outcome to an HONEST transition."
echo "## date: $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
echo
} >> "$OUT"

echo "=== [0] search-enabled definitions ===" >> "$OUT"
timeout 900 kompile proofs/defects/phantom_reject.k --backend haskell --enable-search \
  --main-module SRW3-PHANTOM --syntax-module SRW3-PHANTOM -I k -I proofs/defects \
  -o proofs/defects/defects-search-out >> "$OUT" 2>&1
echo "defective kompile exit: $?" >> "$OUT"
timeout 900 kompile k/srw3.k --backend haskell --enable-search \
  --main-module SRW3-GATE --syntax-module SRW3-GATE -I k \
  -o k/hs-search-out >> "$OUT" 2>&1
echo "corrected kompile exit: $?" >> "$OUT"
echo >> "$OUT"

cat > /tmp/honest.srw3 <<'EOF'
useRegistry(complete) , init(appA,0,7) , init(appB,0,3) , as(appB) , begin , w(appB,0,2) , wfCheck , gate
EOF

extract_results() {
python3 - "$1" <<'PYEOF'
import re, sys
txt=open(sys.argv[1]).read()
blocks=re.findall(r'<srw3>.*?</srw3>', txt, re.S)
print('  final states found:', len(blocks))
seen=set()
for b in blocks:
    m=re.search(r'<result>\s*(.*?)\s*</result>', b, re.S)
    r=' '.join(m.group(1).split()) if m else '?'
    m2=re.search(r'<committed>\s*(.*?)\s*</committed>', b, re.S)
    c=' '.join(m2.group(1).split()) if m2 else '?'
    key=(r,c)
    if key not in seen:
        seen.add(key)
        print('   outcome: result=%s  committed=%s' % (r,c))
PYEOF
}

echo "=== [1] krun --search HONEST transition under CORRECTED gate ===" >> "$OUT"
echo "    expected: exactly ONE outcome: commit" >> "$OUT"
krun /tmp/honest.srw3 -d k/hs-search-out --search > /tmp/ks_corr.txt 2>&1; echo "krun exit: $?" >> "$OUT"
extract_results /tmp/ks_corr.txt >> "$OUT"
echo >> "$OUT"

echo "=== [2] krun --search SAME honest transition under DEFECTIVE gate ===" >> "$OUT"
echo "    expected: TWO outcomes -- commit AND spurious reject (phantom state)" >> "$OUT"
krun /tmp/honest.srw3 -d proofs/defects/defects-search-out --search > /tmp/ks_def.txt 2>&1; echo "krun exit: $?" >> "$OUT"
extract_results /tmp/ks_def.txt >> "$OUT"
echo >> "$OUT"

echo "=== done; transcript at $OUT ==="
cat "$OUT"
