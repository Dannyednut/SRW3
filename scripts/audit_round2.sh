#!/bin/bash
# Round-2 theorem-boundary audit: premise-form equivalences (item 1) +
# generalized bridge / coverage predicate (item 2)
source /home/z/my-project/tools/env.sh
cd /home/z/my-project/srw3-kevm

# ---------------------------------------------------------------- item 1 ----
OUT=transcripts/audit/safe_form_audit.txt
: > "$OUT"
{
echo "## Round-2 audit item 1 — 4a/4b premise-form equivalences"
echo "## SF0 IC vacuous on two-key shape; SF1 inlined premise == named Safe predicate;"
echo "## SF2 accept conjuncts == gate applicable-obligation conjunction; SF3 reject disjunction == negation"
echo "## date: $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
echo
} >> "$OUT"
echo "--- kompile (SRW3-SAFE-FORM) ---" >> "$OUT"
timeout 900 kompile proofs/safe_form_audit.k --backend haskell \
  --main-module SRW3-SAFE-FORM --syntax-module SRW3-SAFE-FORM -I k \
  -o proofs/safeform-out >> "$OUT" 2>&1
echo "kompile exit: $?" >> "$OUT"
echo "--- kprove (SF0-SF3, symbolic X Y V) ---" >> "$OUT"
timeout 900 kprove proofs/safe_form_audit.k -d proofs/safeform-out -I k \
  --spec-module SRW3-SAFE-FORM-CLAIMS > /tmp/kpsf.txt 2>&1
echo "kprove exit: $?  (#Top count: $(rg -c '#Top' /tmp/kpsf.txt || echo 0))" >> "$OUT"
rg -n "WarnTrivial|WarnStuck|#Top|Error" /tmp/kpsf.txt >> "$OUT" 2>&1
echo >> "$OUT"

# ---------------------------------------------------------------- item 2 ----
OUT=transcripts/audit/generalized_bridge.txt
: > "$OUT"
{
echo "## Round-2 audit item 2 — generalized bridge: wfCoverage + state-generalized agreement"
echo "## G8-G11: symbolic-state agreement claims, requires = wfCoverage (verbatim predicate)"
echo "## X3: ground necessity witness (coverage premise cannot be dropped)"
echo "## GEN theorem: stated in-source; NOT mechanized (symbolic-set induction boundary)"
echo "## date: $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
echo
} >> "$OUT"
echo "--- kompile (SRW3-BRIDGE-GEN) ---" >> "$OUT"
timeout 900 kompile proofs/generalized_bridge.k --backend haskell \
  --main-module SRW3-BRIDGE-GEN --syntax-module SRW3-BRIDGE-GEN -I k \
  -o proofs/bridgegen-out >> "$OUT" 2>&1
echo "kompile exit: $?" >> "$OUT"
echo "--- kprove (G8-G11 + X3) ---" >> "$OUT"
timeout 900 kprove proofs/generalized_bridge.k -d proofs/bridgegen-out -I k \
  --spec-module SRW3-BRIDGE-GEN-CLAIMS > /tmp/kpbg.txt 2>&1
echo "kprove exit: $?  (#Top count: $(rg -c '#Top' /tmp/kpbg.txt || echo 0))" >> "$OUT"
rg -n "WarnTrivial|WarnStuck|#Top|Error" /tmp/kpbg.txt >> "$OUT" 2>&1
echo >> "$OUT"
echo "=== done ===" >> "$OUT"
echo "tail of last transcript:"; tail -12 "$OUT"
