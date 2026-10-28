#!/bin/bash
# =============================================================================
# SRW3 Phase 1V — the configuration-ownership + reproducibility regression
# runner. (phase1v/tests/run_1v_model_tests.sh)
#
# Workstream B discipline (fail-closed, clean-checkout reproducible):
#   * EVERY input comes from the repository (committed programs, committed
#     harness sources, git-object-pinned historical models) or from the
#     pinned external toolchain (K v7.1.337 + z3 4.13.3). NO /tmp
#     prerequisites, NO leftover state: the workspace is a UNIQUE mktemp
#     directory with a cleanup trap.
#   * Old-versus-fixed matrix over three model generations:
#       OLD-1T = git show 2247e68:k/srw3.k (1T tip: bareEdge bug; unguarded
#                mid-transition mutation)            [pinned git objects]
#       OLD-1U = git show 8697bd7:k/srw3.k (1U tip: setup-phase discipline
#                only — pre-begin/between windows open; useResMap and grant
#                unguarded entirely)                  [pinned git objects]
#       NEW-1V = working tree k/srw3.k + k/srw3gen.k (trusted configuration
#                boundary: policy/registry/authorities/resmap/caps enter ONLY
#                via the trusted harness's initial configuration)
#   * Compile failures are FATAL. Every expected outcome is ASSERTED (result
#     cell, committed state, head, lineageNext, gateopen, protected cells).
#     Parse rejections assert the nonzero rc AND the offending token.
#     Tool-error classes (WarnFunctionWithoutEvaluators = stuck function) and
#     nondeterministic multi-branch outputs (<srw3> block count != 1) are
#     ALWAYS failures.
#   * Every raw log + exit code is preserved under phase1v/transcripts/model/
#     and a machine-readable verdict ledger is written to
#     phase1v/claims/model-verdicts-1v.csv (one row per control).
#   * The runner exits NONZERO if any control deviates from its expectation.
#
# Stages: KOM CFG OWN T1 T2 GEN CLM
#   KOM  six fresh kompiles (3 generations x 2 layers) + the two T1 harness
#        layouts (old-model harness = the committed harness file copied
#        byte-identically beside the git-pinned old model; NO transformation)
#   CFG  WS-A1 before-evidence: the recorded exploits on OLD-1U
#   OWN  WS-A4 after-evidence: unrepresentability (parse rejection) + the
#        init/as runtime blocks + the alternative-route immutability control
#   T1   the bareEdge order-independence matrix (NEW harness probes + the
#        OLD-1T recorded-defect reproductions, outcomes recorded per shape)
#   T2   gate re-entrancy regression (NEW + the OLD-1T recorded defects)
#   GEN  the generalized-model battery on NEW-1V
#   CLM  kprove: SRW3-CLAIMS battery + negative control on NEW-1V
#
# Level III only; no consensus-integration claim.
# =============================================================================
set -u
cd "$(dirname "$0")/../.." || exit 1
REPO=$PWD

# --- toolchain (external, pinned: K v7.1.337 + z3 4.13.3) --------------------
if [ -n "${KTOOLS:-}" ] && [ -f "$KTOOLS/env.sh" ]; then source "$KTOOLS/env.sh"
elif [ -f /home/z/my-project/tools1v/env.sh ]; then source /home/z/my-project/tools1v/env.sh
elif [ -f /home/z/my-project/tools/env.sh ]; then source /home/z/my-project/tools/env.sh
else echo "[1V-MODEL] FATAL: pinned toolchain env.sh not found (set KTOOLS=)"; exit 2; fi

OUTD=$REPO/phase1v/transcripts/model
CLMS=$REPO/phase1v/claims
mkdir -p "$OUTD" "$CLMS"
VCSV=$CLMS/model-verdicts-1v.csv
FAILURES=0
# staged runs (RUN_WS_DIR set, several invocations over one workspace)
# append to ONE ledger; a normal run starts a fresh ledger.
if [ -n "${RUN_APPEND:-}" ]; then
  [ -s "$VCSV" ] || echo "tag,class,rc,expected,observed,verdict,note" >> "$VCSV"
else
  echo "tag,class,rc,expected,observed,verdict,note" > "$VCSV"
fi

# unique per-run workspace; cleaned on exit (durable evidence copied out).
# RUN_WS_DIR=<dir> reuses (and keeps) a caller-provided workspace — used by
# the Phase 1V session to split long runs across foreground invocations;
# normal callers get the default mktemp behavior.
if [ -n "${RUN_WS_DIR:-}" ]; then WS=$RUN_WS_DIR; mkdir -p "$WS"; else
  WS=$(mktemp -d /tmp/srw3-1v-runner-XXXXXX)
  cleanup() { rm -rf "$WS"; }
  trap cleanup EXIT
fi

note() { echo "[1V-MODEL] $*"; }
die() { echo "[1V-MODEL] FATAL: $*" >&2; exit 3; }

# the protected-cell authority strings (trusted harness configuration)
AUTH6="SetItem(appA) |Set SetItem(appB) |Set SetItem(appC) |Set SetItem(oracle) |Set SetItem(lending) |Set SetItem(liq)"
AUTH4="SetItem(appA) |Set SetItem(appB) |Set SetItem(appC) |Set SetItem(appD)"
CAPS="appB |-> 10 appC |-> 6 appD |-> 6"
PARENTS="appB |-> appB appC |-> appB appD |-> appB"

# record <tag> <class> <rc> <expected> <observed> <OK|FAIL> <note>
record() {
  echo "$1,$2,$3,$4,$5,$6,$7" >> "$VCSV"
  if [ "$6" = "FAIL" ]; then FAILURES=$((FAILURES+1)); note "ASSERTION FAILED: $1 (expected [$4], observed [$5])"; fi
}

# krun1 <tag> <program> <defdir> [extra krun args...] -> prints rc
krun1() {
  local TAG=$1 PGM=$2 DEF=$3; shift 3
  timeout 120 krun "$PGM" -d "$DEF" "$@" > "$OUTD/krun_$TAG.txt" 2>&1
  echo $?
}

# verify <tag> <rc> <expected_rc> <expected_result> <note> [cell=NAME:substr]...
#   expected_rc = 0  : asserts rc=0, exactly ONE final config block, no stuck-
#                      function warning, result cell == expected_result (quote-
#                      canonicalized), and every cell=NAME:substr assertion.
#   expected_rc != 0 : asserts rc == expected_rc and records the raw outcome
#                      (for designed-nonzero controls; use check_reject_token
#                      for the parse-rejection token evidence).
verify() { # verify <tag> <rc> <expected_rc> <expected_result> <note> [cell=...]...
  local TAG=$1 RC=$2 ERC=$3 ERES=$4 NOTE=$5; shift 5
  local RAW="$OUTD/krun_$TAG.txt"
  if [ "$ERC" != "0" ]; then
    if [ "$RC" = "$ERC" ]; then record "$TAG" krun "$RC" "rc=$ERC" "rc=$RC" OK "$NOTE"
    else record "$TAG" krun "$RC" "rc=$ERC" "rc=$RC" FAIL "$NOTE (unexpected exit on designed-nonzero control)"; fi
    return
  fi
  [ "$RC" = "0" ] || { record "$TAG" krun "$RC" "rc=0" "rc=$RC" FAIL "$NOTE (krun failed on a positive control)"; return; }
  local V
  V=$(python3 "$REPO/phase1v/tests/verify_1v_out.py" "$TAG" "$RAW" "$ERES" "$@")
  local VRC=$?
  if [ $VRC = 0 ]; then record "$TAG" krun 0 "$ERES${*:+ +cells}" "$V" OK "$NOTE"
  else record "$TAG" krun 0 "$ERES${*:+ +cells}" "$V" FAIL "$NOTE"; fi
}

# check_reject_token <tag> <rc> <token> — parse rejection must mention token
check_reject_token() {
  local TAG=$1 RC=$2 TOK=$3
  if [ "$RC" != "0" ] && grep -q "$TOK" "$OUTD/krun_$TAG.txt" 2>/dev/null; then
    record "$TAG" parse-reject "$RC" "rc!=0 + '$TOK'" "rc=$RC + '$TOK'" OK "unrepresentable at parse time"
  else
    record "$TAG" parse-reject "$RC" "rc!=0 + '$TOK'" "rc=$RC" FAIL "expected parse-time rejection mentioning $TOK"
  fi
}

STAGES=${@:-KOM CFG OWN T1 T2 GEN CLM}
for ST in $STAGES; do
case $ST in

# ===========================================================================
KOM)
note "stage KOM: fresh kompiles from committed inputs"
git show 2247e68872d7a5f8bd8920db96db3ace290535b2:k/srw3.k   > "$WS/old1t-srw3.k"  || die "git show 1T tip"
git show 8697bd744faee0b17156393fd8f57dd87e51598e:k/srw3.k   > "$WS/old1u-srw3.k"  || die "git show 1U tip"
git show 8697bd744faee0b17156393fd8f57dd87e51598e:k/srw3gen.k > "$WS/old1u-gen.k"   || die "git show 1U tip gen"
# OLD-1T T1 harness layout: the COMMITTED 1V harness file copied
# byte-identically into a MINIATURE OF THE REPO LAYOUT (phase1v/tests/ two
# levels below the layout root, k/ one level) so the relative require
# "../../k/srw3.k" resolves to the git-pinned OLD model inside the layout.
# NO source transformation; layout + sha256 asserted before any compile.
mkdir -p "$WS/h1t/k" "$WS/h1t/phase1v/tests" "$WS/h1v/k" "$WS/h1v/phase1v/tests"
cp "$WS/old1t-srw3.k"                  "$WS/h1t/k/srw3.k"
cp "$REPO/phase1v/tests/t1_harness.k"  "$WS/h1t/phase1v/tests/t1_harness.k"
cp "$REPO/k/srw3.k"                    "$WS/h1v/k/srw3.k"
cp "$REPO/phase1v/tests/t1_harness.k"  "$WS/h1v/phase1v/tests/t1_harness.k"
cmp -s "$WS/h1t/phase1v/tests/t1_harness.k" "$REPO/phase1v/tests/t1_harness.k" || die "old harness copy drifted"
cmp -s "$WS/h1v/k/srw3.k"                   "$REPO/k/srw3.k"                   || die "new model copy drifted"
sha_old=$(sha256sum "$WS/h1t/k/srw3.k" | cut -d' ' -f1)
sha_ref=$(git show 2247e68872d7a5f8bd8920db96db3ace290535b2:k/srw3.k | sha256sum | cut -d' ' -f1)
[ "$sha_old" = "$sha_ref" ] || die "old model sha mismatch ($sha_old vs $sha_ref)"
note "  OLD-1T model sha256 pinned: $sha_old"
kompile_or_die() { # <src> <module> <out> <log>
  timeout 600 kompile "$1" --backend haskell --main-module "$2" -o "$3" > "$4" 2>&1
  local RC=$?
  [ $RC = 0 ] || die "kompile $1 rc=$RC (see $4)"
  [ -d "$3" ] || die "kompile output missing: $3"
  note "  kompile OK: $(basename "$1") -> $(basename "$3")"
}
kompile_or_die "$WS/h1t/phase1v/tests/t1_harness.k" T1-HARNESS "$WS/d-old1t-harness" "$OUTD/kompile_old1t_harness.log"
kompile_or_die "$WS/h1v/phase1v/tests/t1_harness.k" T1-HARNESS "$WS/d-new1v-harness" "$OUTD/kompile_new1v_harness.log"
kompile_or_die "$WS/old1u-srw3.k"     SRW3-GATE  "$WS/d-old1u"        "$OUTD/kompile_old1u.log"
kompile_or_die "$WS/old1u-gen.k"      SRW3G-GATE "$WS/d-old1u-gen"    "$OUTD/kompile_old1u_gen.log"
kompile_or_die "$REPO/k/srw3.k"       SRW3-GATE  "$WS/d-new1v"        "$OUTD/kompile_new1v.log"
kompile_or_die "$REPO/k/srw3gen.k"    SRW3G-GATE "$WS/d-new1v-gen"    "$OUTD/kompile_new1v_gen.log"
for t in kompile krun kprove; do command -v $t >/dev/null || die "toolchain tool missing: $t"; done
note "  all definitions compiled; unique workspace $WS"
;;

# ===========================================================================
# WS-A1 BEFORE evidence — the exploits on OLD-1U (no -c args: the 1U model
# has no configuration variables; its setup commands are in-program).
# ===========================================================================
CFG)
note "stage CFG: OLD-1U exploits (before-evidence)"
RC=$(krun1 OLD1U-p1u_policy_prebegin  "$REPO/phase1v/tests/demos-old/p1u_policy_prebegin.srw3"  "$WS/d-old1u")
verify OLD1U-p1u_policy_prebegin "$RC" 0 commit "policy=trust BEFORE the first begin admits the hidden write (appC->11 COMMITTED)" "cell=committed:appC , slot: 0 ) |-> 11"
RC=$(krun1 OLD1U-p1u_policy_between   "$REPO/phase1v/tests/demos-old/p1u_policy_between.srw3"   "$WS/d-old1u")
verify OLD1U-p1u_policy_between "$RC" 0 commit "policy downgrade BETWEEN transitions admits the hidden write (appC->11 COMMITTED)" "cell=committed:appC , slot: 0 ) |-> 11"
RC=$(krun1 OLD1U-p1u_registry_prebegin "$REPO/phase1v/tests/demos-old/p1u_registry_prebegin.srw3" "$WS/d-old1u")
verify OLD1U-p1u_registry_prebegin "$RC" 0 commit "incomplete registry BEFORE begin commits the IAB violation (10+10=20)" "cell=committed:appA , slot: 0 ) |-> 10" "cell=committed:appB , slot: 0 ) |-> 10"
RC=$(krun1 OLD1U-p1u_registry_between "$REPO/phase1v/tests/demos-old/p1u_registry_between.srw3" "$WS/d-old1u")
verify OLD1U-p1u_registry_between "$RC" 0 commit "incomplete registry BETWEEN transitions commits the IAB violation" "cell=committed:appA , slot: 0 ) |-> 10" "cell=committed:appB , slot: 0 ) |-> 10"
RC=$(krun1 OLD1U-p1u_init_mid         "$REPO/phase1v/tests/demos-old/p1u_init_mid.srw3"         "$WS/d-old1u")
verify OLD1U-p1u_init_mid "$RC" 0 reject "mid-transition init CORRUPTS committed state on the reject path (appA->999, never gated)" "cell=committed:appA , slot: 0 ) |-> 999"
RC=$(krun1 OLD1U-p1u_resmap_mid       "$REPO/phase1v/tests/demos-old/p1u_resmap_mid.srw3"       "$WS/d-old1u-gen")
verify OLD1U-p1u_resmap_mid "$RC" 0 commit "MID-TRANSITION useResMap(rmNone) wipes the alias table; IRP 6+9=15>10 COMMITS" "cell=committed:appA , slot: 7 ) |-> 6" "cell=committed:appB , slot: 3 ) |-> 9"
RC=$(krun1 OLD1U-p1u_resmap_prebegin  "$REPO/phase1v/tests/demos-old/p1u_resmap_prebegin.srw3"  "$WS/d-old1u-gen")
verify OLD1U-p1u_resmap_prebegin "$RC" 0 commit "empty alias table selected BEFORE begin; IRP 6+9=15>10 COMMITS" "cell=committed:appA , slot: 7 ) |-> 6" "cell=committed:appB , slot: 3 ) |-> 9"
RC=$(krun1 OLD1U-p1u_grant_mid        "$REPO/phase1v/tests/demos-old/p1u_grant_mid.srw3"        "$WS/d-old1u-gen")
verify OLD1U-p1u_grant_mid "$RC" 0 commit "MID-TRANSITION grant raises own delegation bounds; usage 1000 COMMITS (budget 6/10)" "cell=usage-c:appC |-> 1000"
RC=$(krun1 OLD1U-p1u_grant_between    "$REPO/phase1v/tests/demos-old/p1u_grant_between.srw3"    "$WS/d-old1u-gen")
verify OLD1U-p1u_grant_between "$RC" 0 commit "grant BETWEEN transitions raises bounds; usage 1001 COMMITS (budget 6/10)" "cell=usage-c:appC |-> 1001"
;;

# ===========================================================================
# WS-A4 AFTER evidence — the same attack shapes on NEW-1V.
# ===========================================================================
OWN)
note "stage OWN: NEW-1V unrepresentability + hardening blocks"
for t in policy_prebegin policy_between registry_prebegin registry_between; do
  RC=$(krun1 NEW1V-v1_atk_$t "$REPO/phase1v/tests/demos/v1_atk_$t.srw3" "$WS/d-new1v" -cPOLICY=enforce -cREGISTRY=complete -cAUTHORITIES="$AUTH6")
  case $t in policy_*) TOK=setPolicy;; *) TOK=useRegistry;; esac
  check_reject_token "NEW1V-v1_atk_$t" "$RC" "$TOK"
done
for t in gen_useResMap_mid gen_grant_mid gen_setPolicy_mid; do
  RC=$(krun1 NEW1V-v1_atk_$t "$REPO/phase1v/tests/demos/v1_atk_$t.srw3" "$WS/d-new1v-gen" -cPOLICY=enforce -cREGISTRYG=aliasOnly -cRESMAP=rmPQ -cCAP="$CAPS" -cPARENT="$PARENTS" -cAUTHORITIES="$AUTH4")
  case $t in gen_useResMap*) TOK=useResMap;; gen_grant*) TOK=grant;; *) TOK=setPolicy;; esac
  check_reject_token "NEW1V-v1_atk_$t" "$RC" "$TOK"
done
# runtime hardening blocks (F2/F3): init / as are PRE-BEGIN-ONLY
RC=$(krun1 NEW1V-v1_atk_init_mid "$REPO/phase1v/tests/demos/v1_atk_init_mid.srw3" "$WS/d-new1v" -cPOLICY=enforce -cREGISTRY=complete -cAUTHORITIES="$AUTH6")
verify NEW1V-v1_atk_init_mid "$RC" 0 blocked-init-open "mid-transition init BLOCKED; committed state intact (no 999 corruption)" "cell=committed:appA , slot: 0 ) |-> 7" "cell=head:rootC" "cell=lineageNext:0"
RC=$(krun1 NEW1V-v1_atk_as_mid "$REPO/phase1v/tests/demos/v1_atk_as_mid.srw3" "$WS/d-new1v" -cPOLICY=enforce -cREGISTRY=complete -cAUTHORITIES="SetItem(appA)")
verify NEW1V-v1_atk_as_mid "$RC" 0 blocked-actor-switch-open "mid-transition as() BLOCKED (would-be identity swap to the only authority is refused)" "cell=committed:appA , slot: 0 ) |-> 7" "cell=head:rootC"
# alternative-route immutability: a maximal in-grammar attack cannot change
# the protected configuration nor commit the violation
RC=$(krun1 NEW1V-v1_atk_config_immutable "$REPO/phase1v/tests/demos/v1_atk_config_immutable.srw3" "$WS/d-new1v" -cPOLICY=enforce -cREGISTRY=complete -cAUTHORITIES="$AUTH6")
verify NEW1V-v1_atk_config_immutable "$RC" 0 blocked-effect-incomplete "maximal in-grammar attack: hidden write BLOCKED by enforce; policy/registry/authorities unchanged" "cell=committed:appA , slot: 0 ) |-> 7" "cell=committed:appC , slot: 0 ) |-> 3" "cell=policy:enforce" "cell=lineageNext:0" "cell=head:rootC"
;;

# ===========================================================================
T1)
note "stage T1: bareEdge order-independence matrix"
# NEW-1V harness probes (fixed model: every decomposition agrees)
RC=$(krun1 NEW1V-t1_probe_only_violation "$REPO/phase1v/tests/demos/v1_t1_probe_only_violation.srw3" "$WS/d-new1v-harness" -cPOLICY=enforce -cREGISTRY=t1Mixed -cAUTHORITIES="$AUTH6")
verify NEW1V-t1_probe_only_violation "$RC" 0 '"false"' "mixed-registry probe: IOL obligation IS applicable on the violating state (allHold=false)"
RC=$(krun1 NEW1V-t1_probe_only_ok "$REPO/phase1v/tests/demos/v1_t1_probe_only_ok.srw3" "$WS/d-new1v-harness" -cPOLICY=enforce -cREGISTRY=t1Mixed -cAUTHORITIES="$AUTH6")
verify NEW1V-t1_probe_only_ok "$RC" 0 '"true"' "mixed-registry probe: honest state satisfies all applicable obligations"
RC=$(krun1 NEW1V-t1_mixed_probe_violation "$REPO/phase1v/tests/demos/v1_t1_mixed_probe_violation.srw3" "$WS/d-new1v-harness" -cPOLICY=enforce -cREGISTRY=t1Mixed -cAUTHORITIES="$AUTH6")
verify NEW1V-t1_mixed_probe_violation "$RC" 0 reject "mixed registry + IOL violation -> reject (bareEdge cannot drop the obligation)"
RC=$(krun1 NEW1V-t1_mixed_probe_ok "$REPO/phase1v/tests/demos/v1_t1_mixed_probe_ok.srw3" "$WS/d-new1v-harness" -cPOLICY=enforce -cREGISTRY=t1Mixed -cAUTHORITIES="$AUTH6")
verify NEW1V-t1_mixed_probe_ok "$RC" 0 commit "mixed registry + honest transition -> commit preserved"
RC=$(krun1 NEW1V-t1_pairwise_violation "$REPO/phase1v/tests/demos/v1_t1_pairwise_violation.srw3" "$WS/d-new1v" -cPOLICY=enforce -cREGISTRY=pairwiseOnly -cAUTHORITIES="$AUTH6")
verify NEW1V-t1_pairwise_violation "$RC" 0 reject "pairwise registry (bareEdge present) + IOL violation -> reject"
RC=$(krun1 NEW1V-t1_pairwise_ok "$REPO/phase1v/tests/demos/v1_t1_pairwise_ok.srw3" "$WS/d-new1v" -cPOLICY=enforce -cREGISTRY=pairwiseOnly -cAUTHORITIES="$AUTH6")
verify NEW1V-t1_pairwise_ok "$RC" 0 commit "pairwise registry + honest transition -> commit preserved"
# OLD-1T recorded-defect reproductions (outcomes RECORDED per registry shape;
# the mixed probe was decomposition-masked on the pinned toolchain — the
# pairwise shape exposes the defect; both facts are the record)
RC=$(krun1 OLD1T-t1_mixed_probe_violation "$REPO/phase1u/tests/demos/u1_t1_mixed_probe_violation.srw3" "$WS/d-old1t-harness")
verify OLD1T-t1_mixed_probe_violation "$RC" 0 reject "RECORDED 1U outcome: the 2-element mixed probe is decomposition-masked on the OLD model (rejects anyway)"
RC=$(krun1 OLD1T-t1_probe_only_violation "$REPO/phase1u/tests/demos/u1_t1_probe_only_violation.srw3" "$WS/d-old1t-harness")
verify OLD1T-t1_probe_only_violation "$RC" 0 false "RECORDED 1U outcome: OLD probe=false = the obligation IS still applicable on THIS 2-element decomposition (masked at gate level -> reject); the pairwise shape below exposes the actual drop"
RC=$(krun1 OLD1T-t1_pairwise_violation "$REPO/phase1u/tests/demos/u1_t1_pairwise_violation.srw3" "$WS/d-old1t-harness")
verify OLD1T-t1_pairwise_violation "$RC" 0 commit "RECORDED 1U outcome: OLD pairwise registry IMPROPERLY COMMITS the IOL violation" "cell=committed:lending , slot: 0 ) |-> 90"
;;

# ===========================================================================
T2)
note "stage T2: gate re-entrancy regression"
RC=$(krun1 NEW1V-t2_valid_begin_gate "$REPO/phase1v/tests/demos/v1_t2_valid_begin_gate.srw3" "$WS/d-new1v" -cPOLICY=enforce -cREGISTRY=complete -cAUTHORITIES="$AUTH6")
verify NEW1V-t2_valid_begin_gate "$RC" 0 commit "valid transition unchanged under the trusted configuration boundary" "cell=committed:appB , slot: 0 ) |-> 2" "cell=head:commit ( 0 )" "cell=lineageNext:1" "cell=gateopen:false" "cell=policy:enforce"
RC=$(krun1 NEW1V-t2_double_gate "$REPO/phase1v/tests/demos/v1_t2_double_gate.srw3" "$WS/d-new1v" -cPOLICY=enforce -cREGISTRY=complete -cAUTHORITIES="$AUTH6")
verify NEW1V-t2_double_gate "$RC" 0 gate-closed "second gate fails closed; committed state intact" "cell=committed:appB , slot: 0 ) |-> 2" "cell=head:commit ( 0 )" "cell=lineageNext:1"
RC=$(krun1 NEW1V-t2_gate_no_begin "$REPO/phase1v/tests/demos/v1_t2_gate_no_begin.srw3" "$WS/d-new1v" -cPOLICY=enforce -cREGISTRY=complete -cAUTHORITIES="$AUTH6")
verify NEW1V-t2_gate_no_begin "$RC" 0 gate-closed "gate without begin fails closed; nothing committed" "cell=committed:appA , slot: 0 ) |-> 7" "cell=head:rootC" "cell=lineageNext:0"
RC=$(krun1 NEW1V-t2_reject_then_gate "$REPO/phase1v/tests/demos/v1_t2_reject_then_gate.srw3" "$WS/d-new1v" -cPOLICY=enforce -cREGISTRY=complete -cAUTHORITIES="$AUTH6")
verify NEW1V-t2_reject_then_gate "$RC" 0 gate-closed "reject then second gate: closed; committed state intact" "cell=committed:appB , slot: 0 ) |-> 3" "cell=head:rootC"
RC=$(krun1 NEW1V-t2_double_begin "$REPO/phase1v/tests/demos/v1_t2_double_begin.srw3" "$WS/d-new1v" -cPOLICY=enforce -cREGISTRY=complete -cAUTHORITIES="$AUTH6")
verify NEW1V-t2_double_begin "$RC" 0 blocked-begin-open "nested begin blocked" "cell=head:rootC" "cell=lineageNext:0"
RC=$(krun1 OLD1T-t2_double_gate "$REPO/phase1u/tests/demos/u1_t2_double_gate.srw3" "$WS/d-old1t-harness")
verify OLD1T-t2_double_gate "$RC" 0 commit "RECORDED 1U outcome: OLD double-gate commits the EMPTY map (re-entrancy erasure)"
RC=$(krun1 OLD1T-t2_gate_no_begin "$REPO/phase1u/tests/demos/u1_t2_gate_no_begin.srw3" "$WS/d-old1t-harness")
verify OLD1T-t2_gate_no_begin "$RC" 0 commit "RECORDED 1U outcome: OLD gate-without-begin commits the EMPTY map"
;;

# ===========================================================================
GEN)
note "stage GEN: generalized-model battery on NEW-1V"
RC=$(krun1 NEW1V-gen_valid "$REPO/phase1v/tests/demos/v1_gen_valid.srw3" "$WS/d-new1v-gen" -cPOLICY=enforce -cREGISTRYG=aliasOnly -cRESMAP=rmPQ -cCAP="$CAPS" -cPARENT="$PARENTS" -cAUTHORITIES="$AUTH4")
verify NEW1V-gen_valid "$RC" 0 commit "gen honest transition via the trusted configuration boundary" "cell=committed:appB , slot: 3 ) |-> 4" "cell=head:commit ( 0 )" "cell=lineageNext:1"
RC=$(krun1 NEW1V-gen_alias_violation "$REPO/phase1v/tests/demos/v1_gen_alias_violation.srw3" "$WS/d-new1v-gen" -cPOLICY=enforce -cREGISTRYG=aliasOnly -cRESMAP=rmPQ -cCAP="$CAPS" -cPARENT="$PARENTS" -cAUTHORITIES="$AUTH4")
verify NEW1V-gen_alias_violation "$RC" 0 reject "gen alias-resource violation (IRP 6+9=15>10) REJECTED under the protocol-owned resmap" "cell=committed:appA , slot: 7 ) |-> 5" "cell=head:rootC"
RC=$(krun1 NEW1V-gen_cap_valid "$REPO/phase1v/tests/demos/v1_gen_cap_valid.srw3" "$WS/d-new1v-gen" -cPOLICY=enforce -cREGISTRYG=authOnly -cRESMAP=rmNone -cCAP="$CAPS" -cPARENT="$PARENTS" -cAUTHORITIES="$AUTH4")
verify NEW1V-gen_cap_valid "$RC" 0 commit "gen authority consumption within the protocol-owned caps commits (6<=6, 6<=10)" "cell=usage-c:appC |-> 6"
RC=$(krun1 NEW1V-gen_cap_violation "$REPO/phase1v/tests/demos/v1_gen_cap_violation.srw3" "$WS/d-new1v-gen" -cPOLICY=enforce -cREGISTRYG=authOnly -cRESMAP=rmNone -cCAP="$CAPS" -cPARENT="$PARENTS" -cAUTHORITIES="$AUTH4")
verify NEW1V-gen_cap_violation "$RC" 0 reject "gen authority consumption beyond the protocol-owned cap rejected (7>6)" "cell=usage-c:.Map"
RC=$(krun1 NEW1V-gen_double_gate "$REPO/phase1v/tests/demos/v1_gen_double_gate.srw3" "$WS/d-new1v-gen" -cPOLICY=enforce -cREGISTRYG=aliasOnly -cRESMAP=rmPQ -cCAP="$CAPS" -cPARENT="$PARENTS" -cAUTHORITIES="$AUTH4")
verify NEW1V-gen_double_gate "$RC" 0 gate-closed "gen second gate fails closed" "cell=head:commit ( 0 )" "cell=lineageNext:1"
RC=$(krun1 NEW1V-gen_gate_no_begin "$REPO/phase1v/tests/demos/v1_gen_gate_no_begin.srw3" "$WS/d-new1v-gen" -cPOLICY=enforce -cREGISTRYG=aliasOnly -cRESMAP=rmPQ -cCAP="$CAPS" -cPARENT="$PARENTS" -cAUTHORITIES="$AUTH4")
verify NEW1V-gen_gate_no_begin "$RC" 0 gate-closed "gen gate without begin fails closed" "cell=head:rootC"
RC=$(krun1 NEW1V-gen_double_begin "$REPO/phase1v/tests/demos/v1_gen_double_begin.srw3" "$WS/d-new1v-gen" -cPOLICY=enforce -cREGISTRYG=aliasOnly -cRESMAP=rmPQ -cCAP="$CAPS" -cPARENT="$PARENTS" -cAUTHORITIES="$AUTH4")
verify NEW1V-gen_double_begin "$RC" 0 blocked-begin-open "gen nested begin blocked" "cell=head:rootC"
;;

# ===========================================================================
CLM)
note "stage CLM: kprove claims battery on NEW-1V"
T0=$(date +%s)
timeout 1800 kprove "$REPO/k/srw3.k" -d "$WS/d-new1v" -I "$REPO/k" --spec-module SRW3-CLAIMS > "$OUTD/kprove_claims_new.txt" 2>&1
RC=$?; T1S=$(date +%s)
# expected: rc=0 with #Top (all five claims close) — 1U historical parity
if [ $RC = 0 ] && grep -q "#Top" "$OUTD/kprove_claims_new.txt"; then
  record NEW1V-claims-1-4 kprove "$RC" "rc=0 + #Top" "rc=$RC + #Top" OK "wall=$((T1S-T0))s"
else
  record NEW1V-claims-1-4 kprove "$RC" "rc=0 + #Top" "rc=$RC" FAIL "the claims battery must close on the fixed model"
fi
T0=$(date +%s)
timeout 900 kprove "$REPO/proofs/negative_control.k" -d "$WS/d-new1v" -I "$REPO/k" -I "$REPO/proofs" --spec-module SRW3-NEGCONTROL > "$OUTD/kprove_negcontrol_new.txt" 2>&1
RC=$?; T1S=$(date +%s)
# expected: rc=1 (the deliberately false claim is REFUTED; a timeout rc=124
# would be recorded as a deviation, never relabeled)
if [ $RC = 1 ]; then
  record NEW1V-negative-control kprove "$RC" "rc=1 (refuted)" "rc=$RC" OK "wall=$((T1S-T0))s"
else
  record NEW1V-negative-control kprove "$RC" "rc=1 (refuted)" "rc=$RC" FAIL "the negative control must FAIL to prove (rc=1), not time out or pass"
fi
;;

*) note "unknown stage $ST"; exit 1;;
esac
done
note "stages done: $STAGES"
if [ "$FAILURES" != "0" ]; then note "TOTAL FAILURES: $FAILURES (verdict ledger: $VCSV)"; exit 1; fi
note "ALL CONTROLS ASSERTED OK (verdict ledger: $VCSV)"
exit 0
