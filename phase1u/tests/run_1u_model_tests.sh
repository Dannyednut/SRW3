#!/bin/bash
# =============================================================================
# SRW3 Phase 1U — the model-hygiene regression runner (Workstreams B/C/E).
# (phase1u/tests/run_1u_model_tests.sh)
#
# Old-vs-fixed discipline:
#   OLD  = the Phase 1T tip model  (git show 2247e688:k/srw3.k)   — buggy
#   NEW  = the 1U working tree     (k/srw3.k, k/srw3gen.k)        — fixed
# Both are kompiled FRESH into separate directories; every control program is
# run against BOTH where the control is meaningful (the blocked-* and
# gate-closed paths only exist in NEW), and the raw outcomes are retained.
#
# Stages:
#   KOM   fresh kompiles (old srw3, new srw3, new srw3gen, T1 harness)
#   T1    bareEdge obligation-drop controls (mixed registry probe + pairwise)
#   T2    gate re-entrancy controls (double gate / gate-no-begin /
#         reject-then-gate / double begin / valid begin-gate)
#   T3    mid-transition mutation controls (setPolicy / useRegistry)
#   GEN   the generalized-model T2 controls
#   CLM   the kprove claims battery on the fixed model (Claims 1-4 +
#         negative control must still FAIL)
# Every run's raw output is retained under phase1u/transcripts/model/.
# Level III only; no consensus-integration claim.
# =============================================================================
set -u
cd "$(dirname "$0")/../.." || exit 1
REPO=$PWD
source /home/z/my-project/tools/env.sh
OUTD=$REPO/phase1u/transcripts/model
mkdir -p "$OUTD" "$REPO/phase1u/claims"
EC=$REPO/phase1u/claims/exit-codes-1u.csv
OLDK=/tmp/p1u-old-srw3.k
NEWOUT=/tmp/p1u-model-new
GENOUT=/tmp/p1u-model-gen
OLDOUT=/tmp/p1u-model-old
HARNOUT=/tmp/p1u-model-harness
OLDOUTH=/tmp/p1u-model-harness-old

note() { echo "[1U-MODEL] $*"; }
record() { # record <label> <rc> <wall>
  echo "$1,$2,300,$3" >> "$EC"
}
run_prog() { # run_prog <tag> <program> <defdir> <expect-note>
  local TAG=$1 PGM=$2 DEF=$3 NOTE=$4
  local T0=$(date +%s)
  timeout 120 krun "$PGM" -d "$DEF" > "$OUTD/krun_$TAG.txt" 2>&1
  local RC=$?
  local T1=$(date +%s)
  python3 - "$TAG" "$OUTD/krun_$TAG.txt" "$NOTE" <<'PYEOF' > "$OUTD/verdict_$TAG.txt" 2>&1
import re, sys
tag, path, note = sys.argv[1], sys.argv[2], sys.argv[3]
txt = open(path).read()
blocks = re.findall(r'<srw3[a-z]?>.*?</srw3[a-z]?>', txt, re.S)
final = blocks[-1] if blocks else ''
def cell(c):
    m = re.search(r'<%s>\s*(.*?)\s*</%s>' % (c, c), final, re.S)
    return ' '.join(m.group(1).split()) if m else '?'
print(f'{tag} | result={cell("result")} | committed={cell("committed")} | head={cell("head")} | lineageNext={cell("lineageNext")} | gateopen={cell("gateopen")} | {note}')
PYEOF
  cat "$OUTD/verdict_$TAG.txt"
  record "$TAG" "$RC" "$((T1-T0))"
}

STAGES=${@:-KOM T1 T2 T3 GEN CLM}
for ST in $STAGES; do
case $ST in
KOM)
  git show 2247e68872d7a5f8bd8920db96db3ace290535b2:k/srw3.k > "$OLDK"
  cp "$OLDK" /tmp/p1u-old-harness/srw3.k
  note "kompile OLD (1T tip) srw3.k"
  kompile "$OLDK" --backend haskell --main-module SRW3-GATE -o "$OLDOUT" > /tmp/kompile-1u-old.log 2>&1
  note "  old rc=$?"
  note "kompile NEW srw3.k"
  kompile k/srw3.k --backend haskell --main-module SRW3-GATE -o "$NEWOUT" > /tmp/kompile-1u-new.log 2>&1
  note "  new rc=$?"
  note "kompile NEW srw3gen.k"
  kompile k/srw3gen.k --backend haskell --main-module SRW3G-GATE -o "$GENOUT" > /tmp/kompile-1u-gen.log 2>&1
  note "  gen rc=$?"
  note "kompile NEW T1 harness (requires the NEW srw3.k)"
  kompile phase1u/tests/t1_harness.k --backend haskell --main-module T1-HARNESS -o "$HARNOUT" > /tmp/kompile-1u-harness.log 2>&1
  note "  harness-new rc=$?"
  note "kompile OLD T1 harness (requires the OLD srw3.k copy)"
  kompile /tmp/p1u-old-harness/t1_harness_old.k --backend haskell --main-module T1-HARNESS -o "$OLDOUTH" > /tmp/kompile-1u-harness-old.log 2>&1
  note "  harness-old rc=$?"
  ;;
T1)
  # NEW model — the decisive fixed-model outcomes
  run_prog NEW-t1-mixed-probe-violation phase1u/tests/demos/u1_t1_mixed_probe_violation.srw3 "$HARNOUT" "expect probe=false gate=reject (fixed: IOL enforced)" ;
  run_prog NEW-t1-mixed-probe-ok       phase1u/tests/demos/u1_t1_mixed_probe_ok.srw3       "$HARNOUT" "expect probe=true gate=commit (honest accept preserved)"
  run_prog NEW-t1-pairwise-violation   phase1u/tests/demos/u1_t1_pairwise_violation.srw3   "$NEWOUT"  "expect reject (IOL edge enforced regardless of bareEdge)"
  run_prog NEW-t1-pairwise-ok          phase1u/tests/demos/u1_t1_pairwise_ok.srw3          "$NEWOUT"  "expect commit (honest accept preserved)"
  # OLD model — the reproduced defect (order-dependent; recorded verbatim)
  run_prog OLD-t1-mixed-probe-violation phase1u/tests/demos/u1_t1_mixed_probe_violation.srw3 "$OLDOUTH" "record actual (buggy: probe may be true = obligation dropped)"
  run_prog OLD-t1-pairwise-violation    phase1u/tests/demos/u1_t1_pairwise_violation.srw3    "$OLDOUT"  "record actual (buggy: may improperly commit)"
  ;;
T2)
  run_prog NEW-t2-double-gate    phase1u/tests/demos/u1_t2_double_gate.srw3    "$NEWOUT" "expect commit then gate-closed; committed=(7,2) intact; lineageNext=1"
  run_prog NEW-t2-gate-no-begin  phase1u/tests/demos/u1_t2_gate_no_begin.srw3  "$NEWOUT" "expect gate-closed; committed={appA->7} intact; lineageNext=0"
  run_prog NEW-t2-reject-then-gate phase1u/tests/demos/u1_t2_reject_then_gate.srw3 "$NEWOUT" "expect reject then gate-closed; committed unchanged"
  run_prog NEW-t2-double-begin   phase1u/tests/demos/u1_t2_double_begin.srw3   "$NEWOUT" "expect blocked-begin-open; no commit"
  run_prog NEW-t2-valid-begin-gate phase1u/tests/demos/u1_t2_valid_begin_gate.srw3 "$NEWOUT" "expect commit (normal transition unchanged)"
  run_prog OLD-t2-double-gate    phase1u/tests/demos/u1_t2_double_gate.srw3    "$OLDOUT" "record actual (buggy: second gate commits EMPTY map)"
  run_prog OLD-t2-gate-no-begin  phase1u/tests/demos/u1_t2_gate_no_begin.srw3  "$OLDOUT" "record actual (buggy: gate without begin commits EMPTY map)"
  ;;
T3)
  run_prog NEW-t3-policy-mid   phase1u/tests/demos/u1_t3_policy_mid.srw3   "$NEWOUT" "expect blocked-policy-mutable (mid-transition policy switch refused)"
  run_prog NEW-t3-registry-mid phase1u/tests/demos/u1_t3_registry_mid.srw3 "$NEWOUT" "expect blocked-registry-mutable (mid-transition registry switch refused)"
  run_prog OLD-t3-policy-mid   phase1u/tests/demos/u1_t3_policy_mid.srw3   "$OLDOUT" "record actual (buggy: trust switch mid-transition admits hidden write)"
  run_prog OLD-t3-registry-mid phase1u/tests/demos/u1_t3_registry_mid.srw3 "$OLDOUT" "record actual (buggy: negative registry switch admits IAB violation)"
  ;;
GEN)
  run_prog NEW-gen-double-gate   phase1u/tests/demos/u1_gen_double_gate.srw3   "$GENOUT" "expect commit then gate-closed (gen model fixed)"
  run_prog NEW-gen-gate-no-begin phase1u/tests/demos/u1_gen_gate_no_begin.srw3 "$GENOUT" "expect gate-closed (gen model fixed)"
  run_prog NEW-gen-double-begin  phase1u/tests/demos/u1_gen_double_begin.srw3  "$GENOUT" "expect blocked-begin-open (gen model fixed)"
  ;;
CLM)
  note "kprove Claims 1-4 + negative control on the FIXED model"
  T0=$(date +%s)
  timeout 1800 kprove k/srw3.k -d "$NEWOUT" -I "$REPO/k" --spec-module SRW3-CLAIMS > "$OUTD/kprove_claims_new.txt" 2>&1
  RC=$?
  T1=$(date +%s)
  note "  claims rc=$RC (#Top: $(grep -c '#Top' "$OUTD/kprove_claims_new.txt" || true)) wall=$((T1-T0))s"
  record "NEW-claims-1-4" "$RC" "$((T1-T0))"
  timeout 900 kprove proofs/negative_control.k -d "$NEWOUT" -I "$REPO/k" -I "$REPO/proofs" --spec-module SRW3-NEGCONTROL > "$OUTD/kprove_negcontrol_new.txt" 2>&1
  RC=$?
  note "  negative control rc=$RC (non-zero = correctly fails)"
  record "NEW-negative-control" "$RC" "0"
  ;;
*) note "unknown stage $ST"; exit 1;;
esac
done
note "stages done: $STAGES"
