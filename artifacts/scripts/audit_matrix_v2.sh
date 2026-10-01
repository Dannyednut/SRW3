#!/bin/bash
# Round-2 audit item 8: FULL regression matrix v2 — staged runner (foreground-safe).
# Usage: bash audit_matrix_v2.sh <stage>
#   setup | py | demos | claims | r2 | defect | kevm | verdict
# Appends to transcripts/audit/full_matrix_v2.txt; "setup" truncates it.
source /home/z/my-project/tools/env.sh
cd /home/z/my-project/srw3-kevm
OUT=transcripts/audit/full_matrix_v2.txt
STAGE="${1:-setup}"

case "$STAGE" in
setup)
  : > "$OUT"
  {
  echo "## Round-2 audit — full verification matrix v2 (post theorem-boundary audit)"
  echo "## Components: [1] Python 15/15  [2] abstract demos 13/13  [3] Claims 1,2,3,4a,4b"
  echo "## [4] negative control  [5] bridge (9 ground claims)  [6] phantom-reject audit"
  echo "## [7] round-2 artifacts (safe-form SF0-SF3; generalized bridge G8-G11+X3; necessity probe)"
  echo "## [8] KEVM positive / stale rejection+restore / min2"
  echo "## date: $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  echo
  } >> "$OUT"
  echo "setup done"
  ;;
py)
  echo "=== [1] Baseline Python suite (canonical make test) — expect 15/15 ===" >> "$OUT"
  ( cd /home/z/my-project/srw3-work && timeout 300 make test ) >> "$OUT" 2>&1
  echo "[1] exit: $?" >> "$OUT"; echo >> "$OUT"
  echo "py done"
  ;;
demos)
  echo "=== [2] Abstract demo suite (13 demos) ===" >> "$OUT"
  timeout 2400 bash k/run_demos.sh > /tmp/demos_m2.txt 2>&1
  echo "[2] exit: $?" >> "$OUT"
  echo "--- demo verdict lines ---" >> "$OUT"
  rg -n "DEMO:|result\s+:|committed\s+:|head\s+:|lineageNext\s+:" /tmp/demos_m2.txt >> "$OUT" 2>&1
  echo >> "$OUT"
  echo "demos done (exit $?)"
  ;;
claims)
  echo "=== [3] Claims 1,2,3,4a,4b (kprove, SRW3-CLAIMS) — expect #Top, no vacuity ===" >> "$OUT"
  timeout 1800 kprove k/srw3.k -d k/hs-out --spec-module SRW3-CLAIMS > /tmp/kp_m2.txt 2>&1
  echo "[3] exit: $?  (#Top count: $(rg -c '#Top' /tmp/kp_m2.txt || echo 0))" >> "$OUT"
  rg -n "WarnTrivial|WarnStuck|#Top" /tmp/kp_m2.txt | head -8 >> "$OUT" 2>&1
  echo >> "$OUT"

  echo "=== [4] Negative control — expect FAILURE (non-zero exit) ===" >> "$OUT"
  timeout 900 kprove proofs/negative_control.k -d k/hs-out -I .. -I . --spec-module SRW3-NEGCONTROL > /tmp/nc_m2.txt 2>&1
  echo "[4] exit: $? (non-zero = correctly fails)" >> "$OUT"
  rg -n "WarnStuck" /tmp/nc_m2.txt | head -2 >> "$OUT" 2>&1
  echo >> "$OUT"

  echo "=== [5] Reconciliation bridge (9 ground claims G1-G7,X1,X2) — fresh kompile ===" >> "$OUT"
  timeout 900 kompile k/compat/srw3-bridge.k --backend haskell --main-module SRW3-BRIDGE --syntax-module SRW3-BRIDGE -I k -o k/compat/bridge-out >> /tmp/kom_br_m2.txt 2>&1
  echo "[5-pre] bridge kompile exit: $?" >> "$OUT"
  timeout 900 kprove k/compat/srw3-bridge.k -d k/compat/bridge-out -I k --spec-module SRW3-BRIDGE-CLAIMS > /tmp/br_m2.txt 2>&1
  echo "[5] exit: $?  (#Top count: $(rg -c '#Top' /tmp/br_m2.txt || echo 0); WarnTrivial count: $(rg -c 'WarnTrivialClaim' /tmp/br_m2.txt || echo 0) = checked-by-evaluation)" >> "$OUT"
  rg -n "WarnStuck" /tmp/br_m2.txt | head -2 >> "$OUT" 2>&1
  echo >> "$OUT"
  echo "claims done"
  ;;
r2)
  echo "=== [7] Round-2 artifacts — fresh kompile + kprove (self-contained) ===" >> "$OUT"
  timeout 900 kompile proofs/safe_form_audit.k --backend haskell \
    --main-module SRW3-SAFE-FORM --syntax-module SRW3-SAFE-FORM -I k \
    -o proofs/safeform-out >> /tmp/kom_sf_m2.txt 2>&1
  echo "[7-pre] safe-form kompile exit: $?" >> "$OUT"
  timeout 900 kompile proofs/generalized_bridge.k --backend haskell \
    --main-module SRW3-BRIDGE-GEN --syntax-module SRW3-BRIDGE-GEN -I k \
    -o proofs/bridgegen-out >> /tmp/kom_gb_m2.txt 2>&1
  echo "[7-pre] generalized-bridge kompile exit: $?" >> "$OUT"
  timeout 900 kprove proofs/safe_form_audit.k -d proofs/safeform-out -I k --spec-module SRW3-SAFE-FORM-CLAIMS > /tmp/sf_m2.txt 2>&1
  echo "[7a] safe-form (SF0-SF3) exit: $?  (#Top: $(rg -c '#Top' /tmp/sf_m2.txt || echo 0))" >> "$OUT"
  timeout 900 kprove proofs/generalized_bridge.k -d proofs/bridgegen-out -I k --spec-module SRW3-BRIDGE-GEN-CLAIMS > /tmp/gb_m2.txt 2>&1
  echo "[7b] generalized bridge (G8-G11+X3) exit: $?  (#Top: $(rg -c '#Top' /tmp/gb_m2.txt || echo 0))" >> "$OUT"
  timeout 900 kprove /tmp/genbridge_neg.k -d proofs/bridgegen-out -I /tmp -I k --spec-module SRW3-BRIDGE-GEN-NEG > /tmp/gbn_m2.txt 2>&1
  echo "[7c] necessity probe (no coverage premise) exit: $?  (non-zero = correctly fails)" >> "$OUT"
  echo >> "$OUT"
  echo "r2 done"
  ;;
defect)
  echo "=== [6] Phantom-reject defect audit (reconstruction + search demonstration) ===" >> "$OUT"
  bash /home/z/my-project/scripts/audit_defect.sh > /tmp/def_m2.log 2>&1
  echo "[6a] audit_defect.sh exit: $?" >> "$OUT"
  bash /home/z/my-project/scripts/audit_defect_search.sh > /tmp/defs_m2.log 2>&1
  echo "[6b] audit_defect_search.sh exit: $?" >> "$OUT"
  rg -n "result\s+:|krun exit|Solution [0-9]|#Solution|outcome" transcripts/audit/phantom_defect.txt transcripts/audit/phantom_defect_search.txt 2>/dev/null | head -24 >> "$OUT"
  echo >> "$OUT"
  echo "defect done"
  ;;
kevm)
  echo "=== [8] KEVM demos (real EVM execution) ===" >> "$OUT"
  for d in evm_positive evm_negative_stale evm_minimal; do
    timeout 1800 krun k/kevm/demos/$d.srw3evm -d k/kevm/kevm-hs-out -cMODE=NORMAL -cSCHEDULE=CANCUN -cUSEGAS=false -cCHAINID=1 > /tmp/evm2_$d.txt 2>&1
    echo "--- $d: krun exit: $?" >> "$OUT"
    python3 - /tmp/evm2_$d.txt <<'PYEOF' >> "$OUT"
import re, sys
txt=open(sys.argv[1]).read()
blocks=re.findall(r'<kevm>.*?</kevm>', txt, re.S)
f=blocks[-1] if blocks else ''
k=re.search(r'<k>\s*(.*?)\s*</k>', f, re.S)
kc=' '.join(k.group(1).split()) if k else '?'
m=re.search(r'#w3State\s*\(\s*\.\.\.\s*s:\s*(.*?)\s*,\s*ln:\s*(.*?)\s*,\s*n:\s*(\S+)\s*,\s*h:\s*(\S+)\s*\)', kc, re.S)
if m:
    print('    carrier: s=%s ln=%s n=%s h=%s' % (' '.join(m.group(1).split())[:120], ' '.join(m.group(2).split())[:120], m.group(3), m.group(4)))
else:
    print('    carrier: (none)')
for addr,name in ((4097,'oracle'),(4098,'lending'),(4099,'liq')):
    m=re.search(r'<acctID>\s*%d\s*</acctID>.*?<storage>\s*(.*?)\s*</storage>'%addr, f, re.S)
    print('    %-8s: %s' % (name, ' '.join(m.group(1).split()) if m else '?'))
PYEOF
  done
  echo >> "$OUT"
  echo "kevm done"
  ;;
verdict)
  echo "=== verdict summary ===" >> "$OUT"
  echo "[1] expect 'OK (15 tests)'  [2] expect 13 DEMO lines as-expected  [3] expect exit 0 + #Top" >> "$OUT"
  echo "[4] expect exit 113  [5] expect exit 0 + 9 WarnTrivial  [6] expect corrected=1 outcome, defective=2" >> "$OUT"
  echo "[7a/7b] expect exit 0 + #Top  [7c] expect non-zero  [8] positive=COMMIT, stale=restore+no lineage, min2=reject" >> "$OUT"
  echo "=== done ===" >> "$OUT"
  echo "verdict done"
  ;;
*)
  echo "unknown stage: $STAGE"; exit 1
  ;;
esac
