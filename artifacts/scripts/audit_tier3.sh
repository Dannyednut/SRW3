#!/bin/bash
# Theorem-closure pass, item 3: tier-3 universal reconciliation attempts.
# Expected (per the audit prediction): all three claims STUCK at the
# symbolic-set induction boundary; residuals recorded verbatim; classification
# STATEMENT FORMALIZED; NOT YET MECHANIZED. Tier-1/2 results are untouched.
source /home/z/my-project/tools/env.sh
cd /home/z/my-project/srw3-kevm
OUT=transcripts/audit/tier3_universal.txt
: > "$OUT"
{
echo "## Theorem-closure pass item 3 — tier-3 UNIVERSAL reconciliation theorem"
echo "## Target: wfCoverage(H,FD,S) -> gateOk_faithful(H,S) = implementedGate(H,FD,S),"
echo "## universal over H, FD, S (T3-U); incremental T3-FD (symbolic FD); authorization"
echo "## lemma T3-A. Statement NOT weakened; tier-1/2 preserved."
echo "## date: $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
echo
} >> "$OUT"
echo "--- kompile (SRW3-TIER3-UNIV) ---" >> "$OUT"
timeout 900 kompile proofs/tier3_universal.k --backend haskell \
  --main-module SRW3-TIER3-UNIV --syntax-module SRW3-TIER3-UNIV -I k \
  -o proofs/tier3-out -I proofs >> "$OUT" 2>&1
echo "kompile exit: $?" >> "$OUT"
LABELS="T3-U T3-FD T3-A"
for L in $LABELS; do
  cat > /tmp/t3_$L.k <<EOF
requires "/home/z/my-project/srw3-kevm/proofs/tier3_universal.k"
module SRW3-T3-$L
  imports SRW3-TIER3-UNIV
endmodule
EOF
  # extract the single claim into the per-claim module
  python3 - "$L" <<'PYEOF'
import re, sys
lab = sys.argv[1]
text = open('/home/z/my-project/srw3-kevm/proofs/tier3_universal.k').read()
m = re.search(r"module SRW3-TIER3-UNIV-CLAIMS\n(.*?)\nendmodule", text, re.S)
claims = re.findall(r"  claim .*?\n    \[label\(([A-Za-z0-9-]+)\)\]", m.group(1), re.S)
bodies = re.split(r"(?=  claim )", m.group(1))
for b in bodies:
    if f"label({lab})" in b:
        fn = f"/tmp/t3_{lab}.k"
        src = open(fn).read()
        src = src.replace("endmodule", b.rstrip() + "\nendmodule")
        open(fn, 'w').write(src)
        break
PYEOF
  echo "--- kprove ($L) ---" >> "$OUT"
  timeout 900 kprove /tmp/t3_$L.k -d proofs/tier3-out -I /tmp -I k -I proofs \
    --spec-module SRW3-T3-$L > /tmp/kpt3_$L.txt 2>&1
  E=$?
  T=$(rg -c '#Top' /tmp/kpt3_$L.txt || echo 0)
  S=$(rg -c 'WarnStuckClaimState' /tmp/kpt3_$L.txt || echo 0)
  if [ "$E" = "0" ]; then V="PROVED"; else V="STUCK-OR-FAILED"; fi
  echo "[$L] kprove exit=$E verdict=$V  #Top=$T WarnStuck=$S" >> "$OUT"
  echo "--- verbatim residual head ($L) ---" >> "$OUT"
  rg -n -A22 "WarnStuckClaimState" /tmp/kpt3_$L.txt | head -26 >> "$OUT" 2>&1
  echo >> "$OUT"
done
{
echo "## CLASSIFICATION (mandated by the audit instruction):"
echo "##   tier-3 universal reconciliation: STATEMENT FORMALIZED; NOT YET MECHANIZED"
echo "##   (symbolic-set induction boundary; tier-1/2 results preserved unchanged)"
} >> "$OUT"
echo "=== done ===" >> "$OUT"
tail -8 "$OUT"
