#!/usr/bin/env bash
# SRW3 Phase 1I-R2 — krun demonstration transcripts (LLVM, real krypto shim).
#
# PRIMARY RUN: LLVM backend with the pinned krypto shim (k/phase1d/shim — the
# multiblock-fix shim; scripts/r2_build_llvm.sh).  Keccak256raw and the
# secp256k1 hooks EVALUATE CONCRETELY: the honest mint computes the REAL
# VerifyLineageG verdict, the honest accepts commit, and every attack runs
# against real digests.  (The frozen 1G demo suite used the same executable
# path — phase1g/transcripts/part4_k_demo_suite.txt.)
#
# SECONDARY RUN (T11/T12): the Haskell backend keeps the hash hooks
# uninterpreted (finding 1C-1); the honest mint's computed verdict is the
# stuck VerifyLineageG(...) term and the accept-side derived-decision check
# cannot decide — the disclosed structural boundary (the R1-T5 discipline).
# Only the boundary-relevant cases are re-run there; the parse errors
# (T9/T10) are backend-independent.
#
# TRANSCRIPT POST-PROCESSING (disclosed): the hs runs emit the SAME 5-line
# WarnFunctionWithoutEvaluators block per unevaluated Keccak256raw occurrence
# (the raw stream of one hs mint reached 61 MB); the runner filters that
# repeated block and keeps every other line.  LLVM runs emit none.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
OUT="${1:-$REPO/phase1i-r2/transcripts/demos}"
mkdir -p "$OUT"
source /home/z/my-project/tools/env.sh

DEF_LLVM=/tmp/r2demo-llvm
DEF_HS=/tmp/r2demo-hs
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

if [ ! -x "$DEF_LLVM/interpreter" ]; then
  echo "LLVM definition missing — run scripts/r2_build_llvm.sh first"; exit 1
fi

postproc() { # postproc <rawfile> <outfile>
  rg -v \
    -e '^kore-exec: \[[0-9]+\] Warning \(WarnFunctionWithoutEvaluators\):' \
    -e '^    No evaluators for function symbol:' \
    -e "^        Lbl" \
    -e '^    defined at: .*krypto\.md:50:' \
    -e '^\s+\^\s*$' \
    -e '^kore-exec: \[[0-9]+\] Warning \(WarnTriviallyTrue\):' \
    "$1" > "$2" || true
}

run() { # run <def> <timeout> <program> <outfile> <label>
  printf '%s\n' "$3" > "$WORK/pgm.k"
  { echo "### $5"
    echo "# definition: $1  (krun, K v7.1.337)"
    echo "# program:"
    sed 's/^/#   /' "$WORK/pgm.k"
    echo "# --- krun output ---"
    timeout "$2" krun "$WORK/pgm.k" -d "$1" 2>&1
    echo "# --- krun exit: $? ---"
  } > "$WORK/raw.txt" 2>&1
  postproc "$WORK/raw.txt" "$4"
  echo "wrote $4 ($(wc -l < "$4") lines)"
}

MINT0="pGateEvalR2(XB0, XCtx0, XRG0, XCert0, XSR0, ExecPayloadDigest(XPld0))"
MINT1="pGateEvalR2(XB1, XCtx1, XRG1, XCert1, XSR1, ExecPayloadDigest(XPld1))"
ACC0='pAcceptR2(XB0, XSR0, ExecPayloadDigest(XPld0), 1)'
ACC1='pAcceptR2(XB1, XSR1, ExecPayloadDigest(XPld1), 1)'

run "$DEF_LLVM" 300 "pConsR2(pInitR2(XCfgR2), pConsR2(${MINT0}, runNilR2))" \
  "$OUT/T1-llvm-gate-eval-computes-verdict.txt" \
  "T1 [LLVM] gate evaluation: the machine constructs the authorized context from the PINNED configuration, evaluates the frozen VerifyLineageG over the bound evidence, and mints the receipt carrying the COMPUTED verdict (no chain state moves)"

run "$DEF_LLVM" 300 "pConsR2(pInitR2(XCfgR2), pConsR2(${MINT0}, pConsR2(${ACC0}, runNilR2)))" \
  "$OUT/T2-llvm-honest-accept-COMMITS.txt" \
  "T2 [LLVM] the honest pipeline: computed verdict 'valid-g' -> the accept consumes the receipt, commits slot 0, advances both heads"

run "$DEF_LLVM" 300 "pConsR2(pInitR2(XCfgR2), pConsR2(${MINT0}, pConsR2(${ACC0}, pConsR2(${MINT1}, pConsR2(${ACC1}, runNilR2)))))" \
  "$OUT/T3-llvm-honest-two-block-continuation.txt" \
  "T3 [LLVM] the honest two-block continuation: slot 0 and slot 1 both commit; the lineage head threads the accepted record's F-child into the slot-1 gate position"

run "$DEF_LLVM" 300 'pConsR2(pInitR2(XCfgR2), pConsR2(pAcceptR2(XB0, XSR0, ExecPayloadDigest(XPld0), 1), runNilR2))' \
  "$OUT/T4-llvm-accept-no-receipt-REJECTS.txt" \
  "T4 [LLVM] accept with NO gate evaluation at all — fail-closed (state unchanged)"

run "$DEF_LLVM" 300 'pConsR2(pInitR2(XCfgR2), pConsR2(pInitR2(protoCfgR2(b"\xd1", 2, b"\xd2", b"\xa2", b"\x92", b"\xcc", b"\xee", b"\xf2", b"CANCUN\x00\x00", 1, 1, b"\x91", b"\x91")), runNilR2))' \
  "$OUT/T5-llvm-reinit-refused.txt" \
  "T5 [LLVM] re-initialization with a DIFFERENT configuration — refused, state unchanged (the pin is immutable)"

run "$DEF_LLVM" 300 "pConsR2(pInitR2(XCfgR2), pConsR2(${MINT0}, pConsR2(pAcceptR2(XB0, XSR0, ExecPayloadDigest(XPld0), 2), runNilR2)))" \
  "$OUT/T6-llvm-config-substitution-REJECTS.txt" \
  "T6 [LLVM] config-version substitution (pinned policyV=1, declared CV=2) — reject (R2-CM4 decidable witness)"

run "$DEF_LLVM" 300 "pConsR2(pInitR2(XCfgR2), pConsR2(pGateEvalR2(XB0slot1, XCtx0, XRG0, XCert0, XSR0, ExecPayloadDigest(XPld0)), pConsR2(pAcceptR2(XB0slot1, XSR0, ExecPayloadDigest(XPld0), 1), runNilR2)))" \
  "$OUT/T7-llvm-position-substitution-REJECTS.txt" \
  "T7 [LLVM] a slot-1 candidate presented at slot 0 — the mint refuses (position binding), the accept finds no receipt — reject"

run "$DEF_LLVM" 300 "pConsR2(pInitR2(XCfgR2), pConsR2(pGateEvalR2(XB0altPld, XCtx0, XRG0, XCert0, XSR0, ExecPayloadDigest(XPld1)), pConsR2(pAcceptR2(XB0altPld, XSR0, ExecPayloadDigest(XPld1), 1), runNilR2)))" \
  "$OUT/T8-llvm-evidence-candidate-mismatch-REJECTS.txt" \
  "T8 [LLVM] the candidate's payload digest does not match the presented certificate/evidence (XB0altPld) — the mint refuses (GateInputMatchesBlockR2), the accept finds no receipt — reject"

# ---- the injection + legacy surface (parse level; backend-independent) ------
run "$DEF_LLVM" 300 "pConsR2(pInitR2(XCfgR2), pConsR2(${MINT0}, \"valid-g\"), runNilR2))" \
  "$OUT/T9-llvm-injection-ill-formed.txt" \
  "T9 [LLVM] THE R1 INJECTION: pGateEvalR2 with a trailing verdict string — ILL-FORMED (no such production; the R2 command language has no verdict parameter)"

run "$DEF_LLVM" 300 'pConsR2(pInitR2(XCfgR2), pConsR2(pAccept(protoBlock(b"\x11", b"\x22", b"\x33", b"\x44", b"\x55", b"\x66", b"\x77", b"\x88", 1, 0), b"\x44", b"\x22", protoCfg(b"\xc1", 7, b"\xd1", b"\xa1", b"\x91", b"\xcc", b"\xee", b"\xf1"), true), runNil))' \
  "$OUT/T10a-llvm-legacy-pAccept-ill-formed.txt" \
  "T10a [LLVM] the frozen 1I pAccept command — ILL-FORMED in the R2 machine"

run "$DEF_LLVM" 300 'pConsR2(pInitR2(XCfgR2), pConsR2(pGateEval(protoBlock(b"\x11", b"\x22", b"\x33", b"\x44", b"\x55", b"\x66", b"\x77", b"\x88", 1, 0), b"\x44", b"\x22", "valid-g"), runNil))' \
  "$OUT/T10b-llvm-legacy-pGateEval-ill-formed.txt" \
  "T10b [LLVM] the R1 pGateEval injection command — ILL-FORMED in the R2 machine"

run "$DEF_LLVM" 300 'pConsR2(pInitR2(XCfgR2), pConsR2(pAcceptR1(protoBlock(b"\x11", b"\x22", b"\x33", b"\x44", b"\x55", b"\x66", b"\x77", b"\x88", 1, 0), b"\x44", b"\x22", 7), runNil))' \
  "$OUT/T10c-llvm-legacy-pAcceptR1-ill-formed.txt" \
  "T10c [LLVM] the R1 pAcceptR1 command — ILL-FORMED in the R2 machine"

run "$DEF_LLVM" 300 'pConsR2(pInitR1(protoCfg(b"\xc1", 7, b"\xd1", b"\xa1", b"\x91", b"\xcc", b"\xee", b"\xf1")), runNilR2)' \
  "$OUT/T10d-llvm-legacy-pInitR1-ill-formed.txt" \
  "T10d [LLVM] the R1 pInitR1 command — ILL-FORMED in the R2 machine"

# ---- hs boundary subset (the disclosed structural boundary) ------------------
run "$DEF_HS" 150 "pConsR2(pInitR2(XCfgR2), pConsR2(${MINT0}, runNilR2))" \
  "$OUT/T11-hs-mint-computed-verdict-boundary.txt" \
  "T11 [HS boundary] the same mint on the Haskell backend: the computed verdict is retained as the unevaluated VerifyLineageG(...) application (no Keccak evaluators — finding 1C-1); the receipt STRUCTURE is concrete.  The concrete decision is T1 (LLVM) and the Python mirror."

run "$DEF_HS" 150 'pConsR2(pInitR2(XCfgR2), pConsR2(pAcceptR2(XB0, XSR0, ExecPayloadDigest(XPld0), 1), runNilR2))' \
  "$OUT/T12-hs-accept-no-receipt-REJECTS.txt" \
  "T12 [HS] accept with no receipt — clean reject on the structural backend as well"

echo "DEMOS DONE"
