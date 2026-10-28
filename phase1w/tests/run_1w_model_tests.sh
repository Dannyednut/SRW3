#!/bin/bash
# =============================================================================
# SRW3 Phase 1W — the initialization-boundary + reproduction regression
# runner. (phase1w/tests/run_1w_model_tests.sh)
#
# Workstream A discipline (fail-closed, clean-checkout reproducible — same
# shape as the 1V runner, which is the audited precedent):
#   * EVERY input comes from the repository (committed programs, committed
#     harness sources, git-object-pinned historical models) or from the
#     pinned external toolchain (K v7.1.337 + z3 4.13.3). NO /tmp
#     prerequisites, NO leftover state: the workspace is a UNIQUE mktemp
#     directory with a cleanup trap.
#   * Old-versus-fixed matrix over the initialization boundary:
#       OLD-1T = git show 2247e68:k/srw3.k (1T tip)          [pinned git objects]
#       OLD-1V = git show 430f468:k/srw3.k (+srw3gen.k) — the Phase 1V tip:
#                the between-transition `init` affordance of record (R9)
#                                                            [pinned git objects]
#       NEW-1W = working tree k/srw3.k + k/srw3gen.k — the structurally
#                closed boundary: `init` removed from the grammar; the initial
#                committed state is trusted configuration $INITSTATE
#   * Compile failures are FATAL. Every expected outcome is ASSERTED (result
#     cell, committed state, head, lineageNext, gateopen, protected cells)
#     via tests/verify_1w_out.py (byte-identical copy of the 1V verifier).
#     Parse rejections assert the nonzero rc AND the offending token.
#     WarnFunctionWithoutEvaluators (stuck function) and nondeterministic
#     multi-branch outputs are ALWAYS failures.
#   * Every raw log + verdict row is preserved under phase1w/transcripts/
#     and phase1w/claims/model-verdicts-1w.csv.
#   * The runner exits NONZERO on any deviation.
#
# Stages: KOM AFF OWN T1 T2 GEN CLM
#   KOM  six fresh kompiles (3 model generations x 2 layers) + the two T1
#        harness layouts (OLD-1T layout beside the git-pinned 1T model;
#        NEW-1W layout beside the working-tree model; the committed 1V
#        harness file copied byte-identically into both — NO transformation)
#   AFF  WS-A before-evidence: the between-transition initialization
#        affordance DEMONSTRATED on the pinned OLD-1V model (direct
#        corruption, corruption surviving a reject, after-reject,
#        after-authfail, gen-model variant, pre-begin characterization,
#        mid-transition block reproduction)
#   OWN1 WS-A after-evidence (1/2): `init` unrepresentable on NEW-1W (parse
#        rejection at every lifecycle position); the carried 1V
#        configuration-ownership parse rejections
#   OWN2 WS-A after-evidence (2/2): trusted-seeding positive controls; the
#        bad-baseline TCB boundary control; the carried runtime blocks
#        (as-mid, config-immutable)
#   T1   the bareEdge order-independence matrix (translated NEW-1W probes +
#        the OLD-1T recorded-defect reproductions, outcomes per 1U/1V record)
#   T2   gate re-entrancy regression (translated NEW-1W + OLD-1T defects)
#   GEN1 the generalized-model battery on NEW-1W (translated; part 1)
#   GEN2 the generalized-model battery on NEW-1W (translated; part 2)
#   CLM  kprove: SRW3-CLAIMS battery + negative control on NEW-1W
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
else echo "[1W-MODEL] FATAL: pinned toolchain env.sh not found (set KTOOLS=)"; exit 2; fi

OUTD=$REPO/phase1w/transcripts/model
CLMS=$REPO/phase1w/claims
mkdir -p "$OUTD" "$CLMS"
VCSV=$CLMS/model-verdicts-1w.csv
FAILURES=0
if [ -n "${RUN_APPEND:-}" ]; then
  [ -s "$VCSV" ] || echo "tag,class,rc,expected,observed,verdict,note" >> "$VCSV"
else
  echo "tag,class,rc,expected,observed,verdict,note" > "$VCSV"
fi
if [ -n "${RUN_WS_DIR:-}" ]; then WS=$RUN_WS_DIR; mkdir -p "$WS"; else
  WS=$(mktemp -d /tmp/srw3-1w-runner-XXXXXX)
  cleanup() { rm -rf "$WS"; }
  trap cleanup EXIT
fi

note() { echo "[1W-MODEL] $*"; }
die() { echo "[1W-MODEL] FATAL: $*" >&2; exit 3; }

AUTH6="SetItem(appA) |Set SetItem(appB) |Set SetItem(appC) |Set SetItem(oracle) |Set SetItem(lending) |Set SetItem(liq)"
AUTH4="SetItem(appA) |Set SetItem(appB) |Set SetItem(appC) |Set SetItem(appD)"
AUTHA="SetItem(appA)"
CAPS="appB |-> 10 appC |-> 6 appD |-> 6"
PARENTS="appB |-> appB appC |-> appB appD |-> appB"
# trusted-harness seed maps ($INITSTATE; the 1W replacement of pre-begin init)
SEED_AB="stK(appA,0) |-> 7 stK(appB,0) |-> 3"          # the minimal-model standard seed
SEED_AB5="stK(appA,0) |-> 5 stK(appB,0) |-> 3"         # 5/3 variant (attack baselines)
SEED_ABC="stK(appA,0) |-> 7 stK(appB,0) |-> 3 stK(appC,0) |-> 3"
SEED_CHAIN="stK(oracle,0) |-> 100 stK(oracle,1) |-> 1 stK(lending,0) |-> 100 stK(lending,1) |-> 5"
SEED_GEN="stK(appA,7) |-> 5 stK(appB,3) |-> 0"
SEED_B1="stK(appB,0) |-> 1"
SEED_B3="stK(appB,0) |-> 3"
SEED_A999="stK(appA,0) |-> 999"

record() {
  echo "$1,$2,$3,$4,$5,$6,$7" >> "$VCSV"
  if [ "$6" = "FAIL" ]; then FAILURES=$((FAILURES+1)); note "ASSERTION FAILED: $1 (expected [$4], observed [$5])"; fi
}

krun1() {
  local TAG=$1 PGM=$2 DEF=$3; shift 3
  timeout 120 krun "$PGM" -d "$DEF" "$@" > "$OUTD/krun_$TAG.txt" 2>&1
  echo $?
}

verify() {
  local TAG=$1 RC=$2 ERC=$3 ERES=$4 NOTE=$5; shift 5
  local RAW="$OUTD/krun_$TAG.txt"
  if [ "$ERC" != "0" ]; then
    if [ "$RC" = "$ERC" ]; then record "$TAG" krun "$RC" "rc=$ERC" "rc=$RC" OK "$NOTE"
    else record "$TAG" krun "$RC" "rc=$ERC" "rc=$RC" FAIL "$NOTE (unexpected exit on designed-nonzero control)"; fi
    return
  fi
  [ "$RC" = "0" ] || { record "$TAG" krun "$RC" "rc=0" "rc=$RC" FAIL "$NOTE (krun failed on a positive control)"; return; }
  local V
  V=$(python3 "$REPO/phase1w/tests/verify_1w_out.py" "$TAG" "$RAW" "$ERES" "$@")
  local VRC=$?
  if [ $VRC = 0 ]; then record "$TAG" krun 0 "$ERES${*:+ +cells}" "$V" OK "$NOTE"
  else record "$TAG" krun 0 "$ERES${*:+ +cells}" "$V" FAIL "$NOTE"; fi
}

check_reject_token() {
  local TAG=$1 RC=$2 TOK=$3
  if [ "$RC" != "0" ] && grep -q "$TOK" "$OUTD/krun_$TAG.txt" 2>/dev/null; then
    record "$TAG" parse-reject "$RC" "rc!=0 + '$TOK'" "rc=$RC + '$TOK'" OK "unrepresentable at parse time"
  else
    record "$TAG" parse-reject "$RC" "rc!=0 + '$TOK'" "rc=$RC" FAIL "expected parse-time rejection mentioning $TOK"
  fi
}

STAGES=${@:-KOM AFF OWN1 OWN2 T1 T2 GEN1 GEN2 CLM}
for ST in $STAGES; do
case $ST in

# ===========================================================================
KOM)
note "stage KOM: fresh kompiles from committed inputs"
git show 2247e68872d7a5f8bd8920db96db3ace290535b2:k/srw3.k > "$WS/old1t-srw3.k" || die "git show 1T tip"
git show 430f46858168f0477c1296ba9cc895b3f44e89be:k/srw3.k > "$WS/old1v-srw3.k" || die "git show 1V head"
git show 430f46858168f0477c1296ba9cc895b3f44e89be:k/srw3gen.k > "$WS/old1v-gen.k" || die "git show 1V head gen"
mkdir -p "$WS/h1t/k" "$WS/h1t/phase1w/tests" "$WS/h1w/k" "$WS/h1w/phase1w/tests"
cp "$WS/old1t-srw3.k"                  "$WS/h1t/k/srw3.k"
cp "$REPO/phase1v/tests/t1_harness.k"  "$WS/h1t/phase1w/tests/t1_harness.k"
cp "$REPO/k/srw3.k"                    "$WS/h1w/k/srw3.k"
cp "$REPO/phase1v/tests/t1_harness.k"  "$WS/h1w/phase1w/tests/t1_harness.k"
cmp -s "$WS/h1t/phase1w/tests/t1_harness.k" "$REPO/phase1v/tests/t1_harness.k" || die "old harness copy drifted"
cmp -s "$WS/h1w/k/srw3.k"                   "$REPO/k/srw3.k"                   || die "new model copy drifted"
cmp -s "$WS/h1w/phase1w/tests/t1_harness.k" "$REPO/phase1v/tests/t1_harness.k" || die "new harness copy drifted"
sha_old=$(sha256sum "$WS/h1t/k/srw3.k" | cut -d' ' -f1)
[ "$sha_old" = "da4a895b21d7989de48480e735fc19d9c8387b352a6f10c55f121da35bb9380d" ] || die "OLD-1T model sha mismatch ($sha_old)"
note "  OLD-1T model sha256 pinned: $sha_old"
sha_1v=$(sha256sum "$WS/old1v-srw3.k" | cut -d' ' -f1)
[ "$sha_1v" = "069afc5b92afb8d0215e2b48ac9c9a9f9d13885eedea877071629743b7a9fb65" ] || die "OLD-1V model sha mismatch ($sha_1v)"
note "  OLD-1V model sha256 pinned: $sha_1v"
sha_1vg=$(sha256sum "$WS/old1v-gen.k" | cut -d' ' -f1)
[ "$sha_1vg" = "3fdb6387846bff6a07a211bfc1369443b26651bda9e6e68a5b45eaec3b98f65d" ] || die "OLD-1V gen sha mismatch ($sha_1vg)"
note "  OLD-1V gen model sha256 pinned: $sha_1vg"
kompile_or_die() {
  timeout 600 kompile "$1" --backend haskell --main-module "$2" -o "$3" > "$4" 2>&1
  local RC=$?
  [ $RC = 0 ] || die "kompile $1 rc=$RC (see $4)"
  [ -d "$3" ] || die "kompile output missing: $3"
  note "  kompile OK: $(basename "$1") -> $(basename "$3")"
}
kompile_or_die "$WS/h1t/phase1w/tests/t1_harness.k" T1-HARNESS "$WS/d-old1t-harness" "$OUTD/kompile_old1t_harness.log"
kompile_or_die "$WS/h1w/phase1w/tests/t1_harness.k" T1-HARNESS "$WS/d-new1w-harness" "$OUTD/kompile_new1w_harness.log"
kompile_or_die "$WS/old1v-srw3.k"  SRW3-GATE  "$WS/d-old1v"     "$OUTD/kompile_old1v.log"
kompile_or_die "$WS/old1v-gen.k"   SRW3G-GATE "$WS/d-old1v-gen" "$OUTD/kompile_old1v_gen.log"
kompile_or_die "$REPO/k/srw3.k"    SRW3-GATE  "$WS/d-new1w"     "$OUTD/kompile_new1w.log"
kompile_or_die "$REPO/k/srw3gen.k" SRW3G-GATE "$WS/d-new1w-gen" "$OUTD/kompile_new1w_gen.log"
for t in kompile krun kprove; do command -v $t >/dev/null || die "toolchain tool missing: $t"; done
note "  all definitions compiled; unique workspace $WS"
;;

# ===========================================================================
# WS-A BEFORE evidence — the between-transition initialization affordance on
# the pinned OLD-1V model (R9 of the 1V register, demonstrated, not assumed).
# ===========================================================================
AFF)
note "stage AFF: OLD-1V initialization-affordance demonstrations (before-evidence)"
RC=$(krun1 OLD1V-w1_aff_between_direct "$REPO/phase1w/tests/demos-aff/w1_aff_between_direct.srw3" "$WS/d-old1v" -cPOLICY=enforce -cREGISTRY=complete -cAUTHORITIES="$AUTH6")
verify OLD1V-w1_aff_between_direct "$RC" 0 commit "BETWEEN transitions init re-seeds committed appA 5->999; the value NEVER passed any gate and IS the final committed state" "cell=committed:appA , slot: 0 ) |-> 999" "cell=committed:appB , slot: 0 ) |-> 2" "cell=head:commit ( 0 )"
RC=$(krun1 OLD1V-w1_aff_between_survives_reject "$REPO/phase1w/tests/demos-aff/w1_aff_between_survives_reject.srw3" "$WS/d-old1v" -cPOLICY=enforce -cREGISTRY=complete -cAUTHORITIES="$AUTH6")
verify OLD1V-w1_aff_between_survives_reject "$RC" 0 reject "BETWEEN-transitions corruption SURVIVES the subsequent gate REJECT (IAB violated on the seeded value; the reject restores nothing)" "cell=committed:appA , slot: 0 ) |-> 999" "cell=committed:appB , slot: 0 ) |-> 2" "cell=lineageNext:1"
RC=$(krun1 OLD1V-w1_aff_after_reject "$REPO/phase1w/tests/demos-aff/w1_aff_after_reject.srw3" "$WS/d-old1v" -cPOLICY=enforce -cREGISTRY=complete -cAUTHORITIES="$AUTH6")
verify OLD1V-w1_aff_after_reject "$RC" 0 reject "AFTER a rejected transition init mutates committed appA 5->999 ungated" "cell=committed:appA , slot: 0 ) |-> 999" "cell=head:rootC"
RC=$(krun1 OLD1V-w1_aff_after_authfail "$REPO/phase1w/tests/demos-aff/w1_aff_after_authfail.srw3" "$WS/d-old1v" -cPOLICY=enforce -cREGISTRY=complete -cAUTHORITIES="$AUTHA")
verify OLD1V-w1_aff_after_authfail "$RC" 0 reject-auth "AFTER an authorization failure init mutates committed appA 5->999 ungated" "cell=committed:appA , slot: 0 ) |-> 999" "cell=head:commit ( 0 )"
RC=$(krun1 OLD1V-w1_aff_prebegin_by_design "$REPO/phase1w/tests/demos-aff/w1_aff_prebegin_by_design.srw3" "$WS/d-old1v" -cPOLICY=enforce -cREGISTRY=complete -cAUTHORITIES="$AUTH6")
verify OLD1V-w1_aff_prebegin_by_design "$RC" 0 commit "CHARACTERIZATION: pre-begin seeding is the disclosed 1V scenario-authoring affordance (accepted by design; Phase 1W removes it)" "cell=committed:appA , slot: 0 ) |-> 5" "cell=committed:appB , slot: 0 ) |-> 2"
RC=$(krun1 OLD1V-w1_aff_gen_between "$REPO/phase1w/tests/demos-aff/w1_aff_gen_between.srw3" "$WS/d-old1v-gen" -cPOLICY=enforce -cREGISTRYG=aliasOnly -cRESMAP=rmPQ -cCAP="$CAPS" -cPARENT="$PARENTS" -cAUTHORITIES="$AUTH4")
verify OLD1V-w1_aff_gen_between "$RC" 0 commit "GEN model: the same between-transition init re-seeds committed appA@7 5->999 ungated" "cell=committed:appA , slot: 7 ) |-> 999" "cell=committed:appB , slot: 3 ) |-> 4"
RC=$(krun1 OLD1V-w1_aff_mid_repro "$REPO/phase1v/tests/demos/v1_atk_init_mid.srw3" "$WS/d-old1v" -cPOLICY=enforce -cREGISTRY=complete -cAUTHORITIES="$AUTH6")
verify OLD1V-w1_aff_mid_repro "$RC" 0 blocked-init-open "1V control reproduced on the pinned 1V model: MID-transition init BLOCKED (blocked-init-open; committed intact)" "cell=committed:appA , slot: 0 ) |-> 7" "cell=head:rootC"
;;

# ===========================================================================
# WS-A AFTER evidence (1/2) — the attack shapes are UNREPRESENTABLE on NEW-1W.
# ===========================================================================
OWN1)
note "stage OWN1: NEW-1W unrepresentability (parse rejections)"
# the between/reject/authfail attack programs VERBATIM (copied to the OWN set)
for t in init_between init_afterauthfail init_mid; do
  RC=$(krun1 NEW1W-w1_atk_$t "$REPO/phase1w/tests/demos/w1_atk_${t}_verbatim.srw3" "$WS/d-new1w" -cPOLICY=enforce -cREGISTRY=complete -cINITSTATE="$SEED_AB5" -cAUTHORITIES="$AUTH6")
  check_reject_token "NEW1W-w1_atk_$t" "$RC" "init"
done
# carried 1V configuration-ownership parse rejections, by reference to the
# committed 1V programs (setPolicy/useRegistry/useResMap/grant stay removed)
RC=$(krun1 NEW1W-v1_atk_policy_prebegin "$REPO/phase1v/tests/demos/v1_atk_policy_prebegin.srw3" "$WS/d-new1w" -cPOLICY=enforce -cREGISTRY=complete -cINITSTATE=".Map" -cAUTHORITIES="$AUTH6")
check_reject_token "NEW1W-v1_atk_policy_prebegin" "$RC" "setPolicy"
RC=$(krun1 NEW1W-v1_atk_registry_between "$REPO/phase1v/tests/demos/v1_atk_registry_between.srw3" "$WS/d-new1w" -cPOLICY=enforce -cREGISTRY=complete -cINITSTATE=".Map" -cAUTHORITIES="$AUTH6")
check_reject_token "NEW1W-v1_atk_registry_between" "$RC" "useRegistry"
RC=$(krun1 NEW1W-v1_atk_gen_useResMap_mid "$REPO/phase1v/tests/demos/v1_atk_gen_useResMap_mid.srw3" "$WS/d-new1w-gen" -cPOLICY=enforce -cREGISTRYG=aliasOnly -cRESMAP=rmPQ -cINITSTATE=".Map" -cCAP="$CAPS" -cPARENT="$PARENTS" -cAUTHORITIES="$AUTH4")
check_reject_token "NEW1W-v1_atk_gen_useResMap_mid" "$RC" "useResMap"
RC=$(krun1 NEW1W-v1_atk_gen_grant_mid "$REPO/phase1v/tests/demos/v1_atk_gen_grant_mid.srw3" "$WS/d-new1w-gen" -cPOLICY=enforce -cREGISTRYG=aliasOnly -cRESMAP=rmPQ -cINITSTATE=".Map" -cCAP="$CAPS" -cPARENT="$PARENTS" -cAUTHORITIES="$AUTH4")
check_reject_token "NEW1W-v1_atk_gen_grant_mid" "$RC" "grant"
;;

# ===========================================================================
# WS-A AFTER evidence (2/2) — trusted seeding works; the boundary fails closed.
# ===========================================================================
OWN2)
note "stage OWN2: NEW-1W trusted-seeding positive controls + carried blocks"
# positive controls: trusted seeding (the boundary replacement works)
RC=$(krun1 NEW1W-w1_pos_initstate_seed "$REPO/phase1w/tests/demos/w1_pos_initstate_seed.srw3" "$WS/d-new1w" -cPOLICY=enforce -cREGISTRY=complete -cINITSTATE="$SEED_AB5" -cAUTHORITIES="$AUTH6")
verify NEW1W-w1_pos_initstate_seed "$RC" 0 commit "trusted INITSTATE seeding accepted; seeded appA=5 preserved as legitimate committed state" "cell=committed:appA , slot: 0 ) |-> 5" "cell=committed:appB , slot: 0 ) |-> 2" "cell=head:commit ( 0 )" "cell=lineageNext:1"
RC=$(krun1 NEW1W-w1_pos_empty_seed "$REPO/phase1w/tests/demos/w1_pos_empty_seed.srw3" "$WS/d-new1w" -cPOLICY=enforce -cREGISTRY=complete -cINITSTATE=".Map" -cAUTHORITIES="$AUTH6")
verify NEW1W-w1_pos_empty_seed "$RC" 0 commit "empty seed map (EVM-analogue zeroed storage) works" "cell=committed:appA , slot: 0 ) |-> 1" "cell=head:commit ( 0 )"
RC=$(krun1 NEW1W-w1_pos_two_transitions "$REPO/phase1w/tests/demos/w1_pos_two_transitions.srw3" "$WS/d-new1w" -cPOLICY=enforce -cREGISTRY=complete -cINITSTATE="$SEED_B1" -cAUTHORITIES="$AUTH6")
verify NEW1W-w1_pos_two_transitions "$RC" 0 commit "legitimate between-transition flow WITHOUT any seeding command: two accepted transitions, lineage advances twice" "cell=committed:appB , slot: 0 ) |-> 3" "cell=head:commit ( 1 )" "cell=lineageNext:2"
RC=$(krun1 NEW1W-w1_pos_reject_then_recover "$REPO/phase1w/tests/demos/w1_pos_reject_then_recover.srw3" "$WS/d-new1w" -cPOLICY=enforce -cREGISTRY=complete -cINITSTATE="$SEED_AB5" -cAUTHORITIES="$AUTH6")
verify NEW1W-w1_pos_reject_then_recover "$RC" 0 commit "post-reject lifecycle intact: committed state unchanged by the reject, honest transition commits" "cell=committed:appA , slot: 0 ) |-> 5" "cell=committed:appB , slot: 0 ) |-> 2" "cell=head:commit ( 0 )" "cell=lineageNext:1"
RC=$(krun1 NEW1W-w1_pos_bad_baseline_rejected "$REPO/phase1w/tests/demos/w1_pos_bad_baseline_rejected.srw3" "$WS/d-new1w" -cPOLICY=enforce -cREGISTRY=complete -cINITSTATE="$SEED_A999" -cAUTHORITIES="$AUTH6")
verify NEW1W-w1_pos_bad_baseline_rejected "$RC" 0 reject "TCB boundary control: a VIOLATING harness-supplied baseline is VISIBLE and FAILS CLOSED (gate evaluates obligations over the seed; nothing commits)" "cell=committed:appA , slot: 0 ) |-> 999" "cell=head:rootC" "cell=lineageNext:0"
# carried runtime blocks (F3 hardening) on NEW-1W
RC=$(krun1 NEW1W-w1_atk_as_mid "$REPO/phase1w/tests/demos/w1_atk_as_mid.srw3" "$WS/d-new1w" -cPOLICY=enforce -cREGISTRY=complete -cINITSTATE="$SEED_AB" -cAUTHORITIES="$AUTHA")
verify NEW1W-w1_atk_as_mid "$RC" 0 blocked-actor-switch-open "carried 1V F3 block: mid-transition as() refused (would-be identity swap to the only authority)" "cell=committed:appA , slot: 0 ) |-> 7" "cell=head:rootC"
RC=$(krun1 NEW1W-w1_atk_config_immutable "$REPO/phase1w/tests/demos/w1_atk_config_immutable.srw3" "$WS/d-new1w" -cPOLICY=enforce -cREGISTRY=complete -cINITSTATE="$SEED_ABC" -cAUTHORITIES="$AUTH6")
verify NEW1W-w1_atk_config_immutable "$RC" 0 blocked-effect-incomplete "carried 1V alternative-route control: maximal in-grammar attack blocked; policy/registry/authorities/committed unchanged" "cell=committed:appA , slot: 0 ) |-> 7" "cell=committed:appC , slot: 0 ) |-> 3" "cell=policy:enforce" "cell=lineageNext:0" "cell=head:rootC"
;;

# ===========================================================================
T1)
note "stage T1: bareEdge order-independence matrix (translated to NEW-1W + OLD-1T defects)"
RC=$(krun1 NEW1W-t1_probe_only_violation "$REPO/phase1w/tests/demos/w1_t1_probe_only_violation.srw3" "$WS/d-new1w-harness" -cPOLICY=enforce -cREGISTRY=t1Mixed -cINITSTATE="$SEED_CHAIN" -cAUTHORITIES="$AUTH6")
verify NEW1W-t1_probe_only_violation "$RC" 0 '"false"' "mixed-registry probe: IOL obligation IS applicable on the violating state (1V-record parity)"
RC=$(krun1 NEW1W-t1_probe_only_ok "$REPO/phase1w/tests/demos/w1_t1_probe_only_ok.srw3" "$WS/d-new1w-harness" -cPOLICY=enforce -cREGISTRY=t1Mixed -cINITSTATE="$SEED_CHAIN" -cAUTHORITIES="$AUTH6")
verify NEW1W-t1_probe_only_ok "$RC" 0 '"true"' "mixed-registry probe: honest state satisfies all applicable obligations (parity)"
RC=$(krun1 NEW1W-t1_mixed_probe_violation "$REPO/phase1w/tests/demos/w1_t1_mixed_probe_violation.srw3" "$WS/d-new1w-harness" -cPOLICY=enforce -cREGISTRY=t1Mixed -cINITSTATE="$SEED_CHAIN" -cAUTHORITIES="$AUTH6")
verify NEW1W-t1_mixed_probe_violation "$RC" 0 reject "mixed registry + IOL violation -> reject (parity: bareEdge cannot drop the obligation)"
RC=$(krun1 NEW1W-t1_mixed_probe_ok "$REPO/phase1w/tests/demos/w1_t1_mixed_probe_ok.srw3" "$WS/d-new1w-harness" -cPOLICY=enforce -cREGISTRY=t1Mixed -cINITSTATE="$SEED_CHAIN" -cAUTHORITIES="$AUTH6")
verify NEW1W-t1_mixed_probe_ok "$RC" 0 commit "mixed registry + honest transition -> commit preserved (parity)"
RC=$(krun1 NEW1W-t1_pairwise_violation "$REPO/phase1w/tests/demos/w1_t1_pairwise_violation.srw3" "$WS/d-new1w" -cPOLICY=enforce -cREGISTRY=pairwiseOnly -cINITSTATE="$SEED_CHAIN" -cAUTHORITIES="$AUTH6")
verify NEW1W-t1_pairwise_violation "$RC" 0 reject "pairwise registry + IOL violation -> reject (parity)"
RC=$(krun1 NEW1W-t1_pairwise_ok "$REPO/phase1w/tests/demos/w1_t1_pairwise_ok.srw3" "$WS/d-new1w" -cPOLICY=enforce -cREGISTRY=pairwiseOnly -cINITSTATE="$SEED_CHAIN" -cAUTHORITIES="$AUTH6")
verify NEW1W-t1_pairwise_ok "$RC" 0 commit "pairwise registry + honest transition -> commit preserved (parity)"
RC=$(krun1 OLD1T-t1_mixed_probe_violation "$REPO/phase1u/tests/demos/u1_t1_mixed_probe_violation.srw3" "$WS/d-old1t-harness")
verify OLD1T-t1_mixed_probe_violation "$RC" 0 reject "RECORDED 1U outcome (unchanged): the 2-element mixed probe is decomposition-masked on the OLD model"
RC=$(krun1 OLD1T-t1_probe_only_violation "$REPO/phase1u/tests/demos/u1_t1_probe_only_violation.srw3" "$WS/d-old1t-harness")
verify OLD1T-t1_probe_only_violation "$RC" 0 false "RECORDED 1U outcome (unchanged): OLD probe=false on THIS 2-element decomposition"
RC=$(krun1 OLD1T-t1_pairwise_violation "$REPO/phase1u/tests/demos/u1_t1_pairwise_violation.srw3" "$WS/d-old1t-harness")
verify OLD1T-t1_pairwise_violation "$RC" 0 commit "RECORDED 1U outcome (unchanged): OLD pairwise registry IMPROPERLY COMMITS the IOL violation" "cell=committed:lending , slot: 0 ) |-> 90"
;;

# ===========================================================================
T2)
note "stage T2: gate re-entrancy regression (translated to NEW-1W + OLD-1T defects)"
RC=$(krun1 NEW1W-t2_valid_begin_gate "$REPO/phase1w/tests/demos/w1_t2_valid_begin_gate.srw3" "$WS/d-new1w" -cPOLICY=enforce -cREGISTRY=complete -cINITSTATE="$SEED_AB" -cAUTHORITIES="$AUTH6")
verify NEW1W-t2_valid_begin_gate "$RC" 0 commit "valid transition unchanged under the initialization boundary (parity)" "cell=committed:appB , slot: 0 ) |-> 2" "cell=head:commit ( 0 )" "cell=lineageNext:1" "cell=gateopen:false" "cell=policy:enforce"
RC=$(krun1 NEW1W-t2_double_gate "$REPO/phase1w/tests/demos/w1_t2_double_gate.srw3" "$WS/d-new1w" -cPOLICY=enforce -cREGISTRY=complete -cINITSTATE="$SEED_AB" -cAUTHORITIES="$AUTH6")
verify NEW1W-t2_double_gate "$RC" 0 gate-closed "second gate fails closed (parity)" "cell=committed:appB , slot: 0 ) |-> 2" "cell=head:commit ( 0 )" "cell=lineageNext:1"
RC=$(krun1 NEW1W-t2_gate_no_begin "$REPO/phase1w/tests/demos/w1_t2_gate_no_begin.srw3" "$WS/d-new1w" -cPOLICY=enforce -cREGISTRY=complete -cINITSTATE="$SEED_AB" -cAUTHORITIES="$AUTH6")
verify NEW1W-t2_gate_no_begin "$RC" 0 gate-closed "gate without begin fails closed (parity)" "cell=committed:appA , slot: 0 ) |-> 7" "cell=head:rootC" "cell=lineageNext:0"
RC=$(krun1 NEW1W-t2_reject_then_gate "$REPO/phase1w/tests/demos/w1_t2_reject_then_gate.srw3" "$WS/d-new1w" -cPOLICY=enforce -cREGISTRY=complete -cINITSTATE="$SEED_AB" -cAUTHORITIES="$AUTH6")
verify NEW1W-t2_reject_then_gate "$RC" 0 gate-closed "reject then second gate: closed; committed intact (parity)" "cell=committed:appB , slot: 0 ) |-> 3" "cell=head:rootC"
RC=$(krun1 NEW1W-t2_double_begin "$REPO/phase1w/tests/demos/w1_t2_double_begin.srw3" "$WS/d-new1w" -cPOLICY=enforce -cREGISTRY=complete -cINITSTATE="$SEED_AB" -cAUTHORITIES="$AUTH6")
verify NEW1W-t2_double_begin "$RC" 0 blocked-begin-open "nested begin blocked (parity)" "cell=head:rootC" "cell=lineageNext:0"
RC=$(krun1 OLD1T-t2_double_gate "$REPO/phase1u/tests/demos/u1_t2_double_gate.srw3" "$WS/d-old1t-harness")
verify OLD1T-t2_double_gate "$RC" 0 commit "RECORDED 1U outcome (unchanged): OLD double-gate commits the EMPTY map"
RC=$(krun1 OLD1T-t2_gate_no_begin "$REPO/phase1u/tests/demos/u1_t2_gate_no_begin.srw3" "$WS/d-old1t-harness")
verify OLD1T-t2_gate_no_begin "$RC" 0 commit "RECORDED 1U outcome (unchanged): OLD gate-without-begin commits the EMPTY map"
;;

# ===========================================================================
GEN1)
note "stage GEN1: generalized-model battery on NEW-1W (translated; part 1)"
RC=$(krun1 NEW1W-gen_valid "$REPO/phase1w/tests/demos/w1_gen_valid.srw3" "$WS/d-new1w-gen" -cPOLICY=enforce -cREGISTRYG=aliasOnly -cRESMAP=rmPQ -cINITSTATE="$SEED_GEN" -cCAP="$CAPS" -cPARENT="$PARENTS" -cAUTHORITIES="$AUTH4")
verify NEW1W-gen_valid "$RC" 0 commit "gen honest transition via the trusted boundary (parity)" "cell=committed:appB , slot: 3 ) |-> 4" "cell=head:commit ( 0 )" "cell=lineageNext:1"
RC=$(krun1 NEW1W-gen_alias_violation "$REPO/phase1w/tests/demos/w1_gen_alias_violation.srw3" "$WS/d-new1w-gen" -cPOLICY=enforce -cREGISTRYG=aliasOnly -cRESMAP=rmPQ -cINITSTATE="$SEED_GEN" -cCAP="$CAPS" -cPARENT="$PARENTS" -cAUTHORITIES="$AUTH4")
verify NEW1W-gen_alias_violation "$RC" 0 reject "gen alias-resource violation REJECTED (parity)" "cell=committed:appA , slot: 7 ) |-> 5" "cell=head:rootC"
RC=$(krun1 NEW1W-gen_cap_valid "$REPO/phase1v/tests/demos/v1_gen_cap_valid.srw3" "$WS/d-new1w-gen" -cPOLICY=enforce -cREGISTRYG=authOnly -cRESMAP=rmNone -cINITSTATE=".Map" -cCAP="$CAPS" -cPARENT="$PARENTS" -cAUTHORITIES="$AUTH4")
verify NEW1W-gen_cap_valid "$RC" 0 commit "gen authority consumption within caps commits (parity)" "cell=usage-c:appC |-> 6"
RC=$(krun1 NEW1W-gen_cap_violation "$REPO/phase1v/tests/demos/v1_gen_cap_violation.srw3" "$WS/d-new1w-gen" -cPOLICY=enforce -cREGISTRYG=authOnly -cRESMAP=rmNone -cINITSTATE=".Map" -cCAP="$CAPS" -cPARENT="$PARENTS" -cAUTHORITIES="$AUTH4")
verify NEW1W-gen_cap_violation "$RC" 0 reject "gen authority consumption beyond cap rejected (parity)" "cell=usage-c:.Map"
;;
GEN2)
note "stage GEN2: generalized-model battery on NEW-1W (translated; part 2)"
RC=$(krun1 NEW1W-gen_double_gate "$REPO/phase1w/tests/demos/w1_gen_double_gate.srw3" "$WS/d-new1w-gen" -cPOLICY=enforce -cREGISTRYG=aliasOnly -cRESMAP=rmPQ -cINITSTATE="$SEED_GEN" -cCAP="$CAPS" -cPARENT="$PARENTS" -cAUTHORITIES="$AUTH4")
verify NEW1W-gen_double_gate "$RC" 0 gate-closed "gen second gate fails closed (parity)" "cell=head:commit ( 0 )" "cell=lineageNext:1"
RC=$(krun1 NEW1W-gen_gate_no_begin "$REPO/phase1w/tests/demos/w1_gen_gate_no_begin.srw3" "$WS/d-new1w-gen" -cPOLICY=enforce -cREGISTRYG=aliasOnly -cRESMAP=rmPQ -cINITSTATE="$SEED_GEN" -cCAP="$CAPS" -cPARENT="$PARENTS" -cAUTHORITIES="$AUTH4")
verify NEW1W-gen_gate_no_begin "$RC" 0 gate-closed "gen gate without begin fails closed (parity)" "cell=head:rootC"
RC=$(krun1 NEW1W-gen_double_begin "$REPO/phase1w/tests/demos/w1_gen_double_begin.srw3" "$WS/d-new1w-gen" -cPOLICY=enforce -cREGISTRYG=aliasOnly -cRESMAP=rmPQ -cINITSTATE="$SEED_GEN" -cCAP="$CAPS" -cPARENT="$PARENTS" -cAUTHORITIES="$AUTH4")
verify NEW1W-gen_double_begin "$RC" 0 blocked-begin-open "gen nested begin blocked (parity)" "cell=head:rootC"
;;

# ===========================================================================
CLM)
note "stage CLM: kprove claims battery on NEW-1W"
T0=$(date +%s)
timeout 1800 kprove "$REPO/k/srw3.k" -d "$WS/d-new1w" -I "$REPO/k" --spec-module SRW3-CLAIMS > "$OUTD/kprove_claims_1w.txt" 2>&1
RC=$?; T1S=$(date +%s)
if [ $RC = 0 ] && grep -q "#Top" "$OUTD/kprove_claims_1w.txt"; then
  record NEW1W-claims-1-4 kprove "$RC" "rc=0 + #Top" "rc=$RC + #Top" OK "wall=$((T1S-T0))s"
else
  record NEW1W-claims-1-4 kprove "$RC" "rc=0 + #Top" "rc=$RC" FAIL "the claims battery must close on the 1W model"
fi
T0=$(date +%s)
timeout 900 kprove "$REPO/proofs/negative_control.k" -d "$WS/d-new1w" -I "$REPO/k" -I "$REPO/proofs" --spec-module SRW3-NEGCONTROL > "$OUTD/kprove_negcontrol_1w.txt" 2>&1
RC=$?; T1S=$(date +%s)
if [ $RC = 1 ]; then
  record NEW1W-negative-control kprove "$RC" "rc=1 (refuted)" "rc=$RC" OK "wall=$((T1S-T0))s"
else
  record NEW1W-negative-control kprove "$RC" "rc=1 (refuted)" "rc=$RC" FAIL "the negative control must FAIL to prove (rc=1), not time out or pass"
fi
;;

*) note "unknown stage $ST"; exit 1;;
esac
done
note "stages done: $STAGES"
if [ "$FAILURES" != "0" ]; then note "TOTAL FAILURES: $FAILURES (verdict ledger: $VCSV)"; exit 1; fi
note "ALL CONTROLS ASSERTED OK (verdict ledger: $VCSV)"
exit 0
