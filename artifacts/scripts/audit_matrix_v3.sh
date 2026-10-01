#!/bin/bash
# Theorem-closure pass: FULL regression matrix v3.
# Usage: bash audit_matrix_v3.sh <stage>
#   setup | py | demos | claims | r2 | defect | ghost | tier3 | kevm | verdict
# Appends to transcripts/audit/full_matrix_v3.txt; "setup" truncates it.
source /home/z/my-project/tools/env.sh
cd /home/z/my-project/srw3-kevm
OUT=transcripts/audit/full_matrix_v3.txt
STAGE="${1:-setup}"

case "$STAGE" in
setup)
  : > "$OUT"
  {
  echo "## Theorem-closure pass — full verification matrix v3"
  echo "## [1] Python 15/15  [2] abstract demos 13/13  [3] Claims 1,2,3,4a,4b"
  echo "## [4] negative control  [5] bridge (9 ground claims)  [6] phantom-reject audit"
  echo "## [7] round-2 artifacts (SF0-SF3; G8-G11+X3; necessity probe)"
  echo "## [8] KEVM positive / stale reject+restore / minimal reject+restore"
  echo "## [9] theorem-closure ghost encoding (12 claims + faithfulness certificate + faith-run probe)"
  echo "## [10] tier-3 universal attempts (T3-U/T3-FD/T3-A)  [11] prior-art freeze evidence"
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
  timeout 2400 bash k/run_demos.sh > /tmp/demos_m3.txt 2>&1
  echo "[2] exit: $?" >> "$OUT"
  rg -n "DEMO:|result\s+:|committed\s+:|head\s+:|lineageNext\s+:" /tmp/demos_m3.txt >> "$OUT" 2>&1
  echo >> "$OUT"
  echo "demos done"
  ;;
claims)
  echo "=== [3] Claims 1,2,3,4a,4b (kprove, SRW3-CLAIMS) — expect #Top, no vacuity ===" >> "$OUT"
  timeout 1800 kprove k/srw3.k -d k/hs-out --spec-module SRW3-CLAIMS > /tmp/kp_m3.txt 2>&1
  echo "[3] exit: $?  (#Top count: $(rg -c '#Top' /tmp/kp_m3.txt || echo 0))" >> "$OUT"
  rg -n "WarnTrivial|WarnStuck|#Top" /tmp/kp_m3.txt | head -8 >> "$OUT" 2>&1
  echo >> "$OUT"

  echo "=== [4] Negative control — expect FAILURE (non-zero exit) ===" >> "$OUT"
  timeout 900 kprove proofs/negative_control.k -d k/hs-out -I .. -I . --spec-module SRW3-NEGCONTROL > /tmp/nc_m3.txt 2>&1
  echo "[4] exit: $? (non-zero = correctly fails)" >> "$OUT"
  rg -n "WarnStuck" /tmp/nc_m3.txt | head -2 >> "$OUT" 2>&1
  echo >> "$OUT"

  echo "=== [5] Reconciliation bridge (9 ground claims G1-G7,X1,X2) — fresh kompile ===" >> "$OUT"
  timeout 900 kompile k/compat/srw3-bridge.k --backend haskell --main-module SRW3-BRIDGE --syntax-module SRW3-BRIDGE -I k -o k/compat/bridge-out >> /tmp/kom_br_m3.txt 2>&1
  echo "[5-pre] bridge kompile exit: $?" >> "$OUT"
  timeout 900 kprove k/compat/srw3-bridge.k -d k/compat/bridge-out -I k --spec-module SRW3-BRIDGE-CLAIMS > /tmp/br_m3.txt 2>&1
  echo "[5] exit: $?  (#Top count: $(rg -c '#Top' /tmp/br_m3.txt || echo 0); WarnTrivial: $(rg -c 'WarnTrivialClaim' /tmp/br_m3.txt || echo 0))" >> "$OUT"
  rg -n "WarnStuck" /tmp/br_m3.txt | head -2 >> "$OUT" 2>&1
  echo >> "$OUT"
  echo "claims done"
  ;;
r2)
  echo "=== [7] Round-2 artifacts — fresh kompile + kprove ===" >> "$OUT"
  timeout 900 kompile proofs/safe_form_audit.k --backend haskell \
    --main-module SRW3-SAFE-FORM --syntax-module SRW3-SAFE-FORM -I k \
    -o proofs/safeform-out >> /tmp/kom_sf_m3.txt 2>&1
  echo "[7-pre] safe-form kompile exit: $?" >> "$OUT"
  timeout 900 kompile proofs/generalized_bridge.k --backend haskell \
    --main-module SRW3-BRIDGE-GEN --syntax-module SRW3-BRIDGE-GEN -I k \
    -o proofs/bridgegen-out >> /tmp/kom_gb_m3.txt 2>&1
  echo "[7-pre] generalized-bridge kompile exit: $?" >> "$OUT"
  timeout 900 kprove proofs/safe_form_audit.k -d proofs/safeform-out -I k --spec-module SRW3-SAFE-FORM-CLAIMS > /tmp/sf_m3.txt 2>&1
  echo "[7a] safe-form (SF0-SF3) exit: $?  (#Top: $(rg -c '#Top' /tmp/sf_m3.txt || echo 0))" >> "$OUT"
  timeout 900 kprove proofs/generalized_bridge.k -d proofs/bridgegen-out -I k --spec-module SRW3-BRIDGE-GEN-CLAIMS > /tmp/gb_m3.txt 2>&1
  echo "[7b] generalized bridge (G8-G11+X3) exit: $?  (#Top: $(rg -c '#Top' /tmp/gb_m3.txt || echo 0))" >> "$OUT"
  bash /home/z/my-project/scripts/audit_round2_neg.sh > /tmp/neg_m3.log 2>&1
  echo "[7c] necessity probe exit recorded in generalized_bridge_negative.txt: $(rg -n 'kprove exit' transcripts/audit/generalized_bridge_negative.txt | tail -1)" >> "$OUT"
  echo >> "$OUT"
  echo "r2 done"
  ;;
defect)
  echo "=== [6] Phantom-reject defect audit (reconstruction + search demonstration) ===" >> "$OUT"
  bash /home/z/my-project/scripts/audit_defect.sh > /tmp/def_m3.log 2>&1
  echo "[6a] audit_defect.sh exit: $?" >> "$OUT"
  bash /home/z/my-project/scripts/audit_defect_search.sh > /tmp/defs_m3.log 2>&1
  echo "[6b] audit_defect_search.sh exit: $?" >> "$OUT"
  rg -n "result\s+:|krun exit|Solution [0-9]|#Solution|outcome" transcripts/audit/phantom_defect.txt transcripts/audit/phantom_defect_search.txt 2>/dev/null | head -24 >> "$OUT"
  echo >> "$OUT"
  echo "defect done"
  ;;
ghost)
  echo "=== [9] Theorem-closure ghost encoding (fresh kompile + all claims) ===" >> "$OUT"
  bash /home/z/my-project/scripts/audit_ghost.sh kompile > /tmp/gh_m3.log 2>&1
  echo "[9-pre] ghost kompile exit: $(rg -o 'kompile exit: [0-9]+' transcripts/audit/ghost_theorem.txt | tail -1)" >> "$OUT"
  python3 /home/z/my-project/scripts/audit_ghost_faithful.py > /tmp/faith_m3.txt 2>&1
  echo "[9a] faithfulness certificate: $(head -1 /tmp/faith_m3.txt)" >> "$OUT"
  bash /home/z/my-project/scripts/audit_ghost_persample.sh > /tmp/ghp_m3.log 2>&1
  rg -n "^\[GH-|^\[GATE" transcripts/audit/ghost_theorem.txt | tail -12 >> "$OUT"
  echo >> "$OUT"
  echo "ghost done"
  ;;
tier3)
  echo "=== [10] Tier-3 universal attempts (statement preserved; expected STUCK) ===" >> "$OUT"
  bash /home/z/my-project/scripts/audit_tier3.sh > /tmp/t3_m3.log 2>&1
  rg -n "^\[T3-|CLASSIFICATION|STATEMENT FORMALIZED" transcripts/audit/tier3_universal.txt >> "$OUT"
  echo >> "$OUT"
  echo "tier3 done"
  ;;
kevm)
  echo "=== [8] KEVM demos (real EVM execution) ===" >> "$OUT"
  for d in evm_positive evm_negative_stale evm_minimal evm_min2; do
    timeout 1800 krun k/kevm/demos/$d.srw3evm -d k/kevm/kevm-hs-out -cMODE=NORMAL -cSCHEDULE=CANCUN -cUSEGAS=false -cCHAINID=1 > /tmp/evm3_$d.txt 2>&1
    echo "--- $d: krun exit: $? (1 = demo terminal exit-code cell; see state below) ---" >> "$OUT"
    python3 - /tmp/evm3_$d.txt <<'PYEOF' >> "$OUT"
import re, sys
txt=open(sys.argv[1]).read()
m=re.search(r'#w3State\s*\(\.\.\.\s*s:\s*(.*?)\s*,\s*ln:\s*(.*?)\s*,\s*n:\s*(\S+)\s*,\s*h:\s*(\S+)\s*\)', txt, re.S)
if m:
    print('    carrier: s=%s ln=%s n=%s h=%s' % (' '.join(m.group(1).split()), ' '.join(m.group(2).split()), m.group(3), m.group(4)))
else:
    print('    carrier: (none)')
k=re.search(r'<k>\s*(.*?)\s*</k>', txt, re.S)
if k and 'SSTORE' in k.group(1):
    print('    WARNING: EVM stuck mid-program (SSTORE unexecuted)')
PYEOF
  done
  echo >> "$OUT"
  {
  echo "    expected: positive = s:{4097:{0:100,1:1},4098:{0:100,1:5},4099:{0:4,1:100}} ln:{0:w3lin(...price:100)} n=1 h=0  (COMMIT)"
  echo "    expected: stale/min2 = s:{4097:.Map,4098:.Map,4099:.Map} ln:.Map n=0 h=-1  (REJECT + restore)"
  echo "    expected: minimal = carrier (none) — setup-only smoke demo"
  } >> "$OUT"
  echo >> "$OUT"
  echo "kevm done"
  ;;
verdict)
  echo "=== verdict summary (expectations) ===" >> "$OUT"
  echo "[1] OK (15 tests)   [2] 13 DEMO lines as-expected   [3] exit 0 + #Top" >> "$OUT"
  echo "[4] non-zero (113)  [5] exit 0 + 9 WarnTrivial     [6] corrected=1, defective=2 outcomes" >> "$OUT"
  echo "[7a/7b] exit 0 + #Top  [7c] non-zero  [8] positive COMMIT; stale+min2 restore; minimal smoke" >> "$OUT"
  echo "[9] kompile 0; certificate PASS 507/507; GH-BASE/A/R/SOUND-I/SOUND-F/GATE-AGREE/ISO/T1/T2/M PROVED;" >> "$OUT"
  echo "    GH-T stuck (documented kore destination probe); GH-T2-NEG fails (non-vacuity control)" >> "$OUT"
  echo "[10] T3-U/T3-FD/T3-A stuck (symbolic-set induction) => STATEMENT FORMALIZED; NOT YET MECHANIZED" >> "$OUT"
  echo "[11] freeze evidence present" >> "$OUT"
  echo "=== done ===" >> "$OUT"
  echo "verdict done"
  ;;
*)
  echo "unknown stage: $STAGE"; exit 1
  ;;
esac
