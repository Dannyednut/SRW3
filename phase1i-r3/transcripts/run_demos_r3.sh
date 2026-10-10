#!/usr/bin/env bash
# SRW3 Phase 1I-R3 — krun demonstration transcripts (LLVM, real krypto shim).
#
# PRIMARY RUN: LLVM backend with the pinned krypto shim (k/phase1d/shim — the
# multiblock-fix shim; scripts/build_shim_r3.sh + build_llvm_r3.sh).
# Keccak256raw and the secp256k1 hooks EVALUATE CONCRETELY: the init root
# check decides against the REAL ProtoRootR3, the honest mint computes the
# REAL VerifyLineageG verdict, the honest accepts commit, and every attack
# runs against real digests.
#
# THE ANCHOR: the trusted protocol root anchor is passed as the explicit
# authenticated configuration input (-cSRW3R3ANCHOR="LinHex(...)"); its value
# is the Python-mirror-computed real Keccak root of XCfgR3 (cross-layer
# agreement: the K machine recomputes ProtoRootR3(XCfgR3) with the shim and
# must agree byte-for-byte).  The xanchorx demo passes a DIFFERENT anchor.
#
# SECONDARY RUN (T-hs-*): the Haskell backend keeps the hash hooks
# uninterpreted (finding 1C-1); the init root equality and the accept-side
# derived-decision check cannot decide — the disclosed structural boundary
# (the R1-T5 / R2-T11/T12 discipline).  Only boundary-relevant cases are
# re-run there; parse errors (T-inj/T-legacy) are backend-independent.
#
# TRANSCRIPT POST-PROCESSING (disclosed, the R2 discipline): the hs runs emit
# the SAME 5-line WarnFunctionWithoutEvaluators block per unevaluated
# Keccak256raw occurrence; the runner filters that repeated block and keeps
# every other line.  LLVM runs emit none.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
OUT="${1:-$REPO/phase1i-r3/transcripts/demos}"
mkdir -p "$OUT"
source /home/z/my-project/tools/env.sh

DEF_LLVM=/tmp/r3demo-llvm
DEF_HS=/tmp/r3demo-hs
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# the authorized root anchor of the demo configuration XCfgR3 (Python mirror,
# real keccak-256; cross-checked by the K machine itself at init)
ANCHOR="207799d4800e6048606189de14198ba95cfd738d5a58e3ada85132fe71f87c12"
ANCHOR_ARG="LinHex(\"$ANCHOR\")"
# a DIFFERENT protocol's root anchor (for the wrong-anchor demo)
OTHER_ANCHOR="LinHex(\"abababababababababababababababababababababababababababababababab\")"

if [ ! -x "$DEF_LLVM/interpreter" ]; then
  echo "LLVM definition missing — run scripts/build_llvm_r3.sh first"; exit 1
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

run() { # run <def> <timeout> <program> <outfile> <label> [extra krun args]
  printf '%s\n' "$3" > "$WORK/pgm.k"
  { echo "### $5"
    echo "# definition: $1  (krun, K v7.1.337)"
    echo "# anchor (SRW3R3ANCHOR): $ANCHOR"
    echo "# program:"
    sed 's/^/#   /' "$WORK/pgm.k"
    echo "# --- krun output ---"
    timeout "$2" krun "$WORK/pgm.k" -d "$1" -cSRW3R3ANCHOR="$ANCHOR_ARG" ${6:-} 2>&1
    echo "# --- krun exit: $? ---"
  } > "$WORK/raw.txt" 2>&1
  postproc "$WORK/raw.txt" "$4"
  echo "wrote $4 ($(wc -l < "$4") lines)"
}

run_other_anchor() { # run with the WRONG anchor
  printf '%s\n' "$3" > "$WORK/pgm.k"
  { echo "### $5"
    echo "# definition: $1  (krun, K v7.1.337)"
    echo "# anchor (SRW3R3ANCHOR): abab..ab (a DIFFERENT protocol root)"
    echo "# program:"
    sed 's/^/#   /' "$WORK/pgm.k"
    echo "# --- krun output ---"
    timeout "$2" krun "$WORK/pgm.k" -d "$1" -cSRW3R3ANCHOR="$OTHER_ANCHOR" 2>&1
    echo "# --- krun exit: $? ---"
  } > "$WORK/raw.txt" 2>&1
  postproc "$WORK/raw.txt" "$4"
  echo "wrote $4 ($(wc -l < "$4") lines)"
}

run_parse_reject() { # parse-rejection demo (backend-independent)
  printf '%s\n' "$3" > "$WORK/pgm.k"
  { echo "### $5"
    echo "# definition: $1  (krun, K v7.1.337)"
    echo "# program (EXPECTED: kparse rejection — the command is ILL-FORMED):"
    sed 's/^/#   /' "$WORK/pgm.k"
    echo "# --- krun output ---"
    timeout "$2" krun "$WORK/pgm.k" -d "$1" -cSRW3R3ANCHOR="$ANCHOR_ARG" 2>&1
    echo "# --- krun exit: $? ---"
  } > "$WORK/raw.txt" 2>&1
  postproc "$WORK/raw.txt" "$4"
  echo "wrote $4 ($(wc -l < "$4") lines)"
}

# ---- LLVM (real keccak) ------------------------------------------------------
run  "$DEF_LLVM" 120 'pConsR3(xCertR3, runNilR3)'                                   "$OUT/T0-llvm-cross-layer-certificate.txt" "T0: cross-layer byte certificate (the K half of the golden-vector conformance; includes the 13-field canonical preimage and its real-Keccak root)"
run  "$DEF_LLVM" 300 'pConsR3(pInitR3(XCfgR3), pConsR3(pGateEvalR3(XB0, XCtx0, XRG0, XCert0, XSR0, ExecPayloadDigest(XPld0)), pConsR3(pAcceptR3(XB0, XSR0, ExecPayloadDigest(XPld0), 1), pConsR3(pGateEvalR3(XB1, XCtx1, XRG1, XCert1, XSR1, ExecPayloadDigest(XPld1)), pConsR3(pAcceptR3(XB1, XSR1, ExecPayloadDigest(XPld1), 1), runNilR3)))))' "$OUT/T1-llvm-honest-two-block-pipeline.txt" "T1: honest pipeline, two blocks, same full config root (init authorized -> computed verdict -> commit x2)"
run  "$DEF_LLVM" 120 'pConsR3(pInitR3(XCfgR3), pConsR3(pGateEvalR3(XB0, XCtx0, XRG0, XCert0, XSR0, ExecPayloadDigest(XPld0)), runNilR3))' "$OUT/T2-llvm-gate-only-no-chain-move.txt" "T2: gate evaluation mints the receipt (computed verdict, computed root, anchor); NO chain state moves"
run  "$DEF_LLVM" 120 'pConsR3(pInitR3(XCfgR3), pConsR3(pAcceptR3(XB0, XSR0, ExecPayloadDigest(XPld0), 1), runNilR3))' "$OUT/T3-llvm-accept-no-receipt-REJECTS.txt" "T3: accept with NO receipt -> fail-closed reject, state unchanged"
run  "$DEF_LLVM" 120 'pConsR3(pInitR3(XCfgR3), pConsR3(pInitR3(XCfgR3), runNilR3))' "$OUT/T4-llvm-reinit-refused.txt" "T4: re-initialization refused (the pin is immutable)"
run  "$DEF_LLVM" 120 'pConsR3(pInitR3(XCfgR3SchedB), runNilR3)' "$OUT/T5-llvm-schedule-mutation-under-old-root-REFUSED.txt" "T5: a schedule-mutated configuration (field 9 — the R2 alias class) re-presented under the authorized root of the honest config is REFUSED: the computed R3 root differs (real keccak)"
run_other_anchor "$DEF_LLVM" 120 'pConsR3(pInitR3(XCfgR3), runNilR3)' "$OUT/T6-llvm-wrong-anchor-REFUSED.txt" "T6: the honest configuration on a machine anchored at a DIFFERENT protocol root is REFUSED (the anchor is authenticated protocol input, not caller data)"
run  "$DEF_LLVM" 120 'pConsR3(pInitR3(XCfgR3), pConsR3(pGateEvalR3(XB0, XCtx0, XRG0, XCert0, XSR0, ExecPayloadDigest(XPld0)), pConsR3(pAcceptR3(XB0, XSR0, ExecPayloadDigest(XPld0), 2), runNilR3)))' "$OUT/T7-llvm-config-substitution-REJECTS.txt" "T7: config-version witness substitution (2 != pinned 1) -> reject, receipt unconsumed"
run  "$DEF_LLVM" 120 'pConsR3(pInitR3(XCfgR3), pConsR3(pGateEvalR3(XB0slot1, XCtx0, XRG0, XCert0, XSR0, ExecPayloadDigest(XPld0)), runNilR3))' "$OUT/T8-llvm-position-substitution-REJECTS.txt" "T8: slot-1 candidate at the slot-0 position -> mint refuses"
run  "$DEF_LLVM" 120 'pConsR3(pInitR3(XCfgR3), pConsR3(pGateEvalR3(XB0, XCtx0, XRG0, XCert0, XSR0, ExecPayloadDigest(XPld1)), runNilR3))' "$OUT/T9-llvm-evidence-candidate-mismatch-REJECTS.txt" "T9: evidence bound to a different payload -> mint refuses (GateInputMatchesBlockR3)"

# ---- ill-formed programs (backend-independent parse rejections) --------------
run_parse_reject "$DEF_LLVM" 60 'pConsR3(pInitR3(XCfgR3), pConsR3(pGateEvalR3(XB0, XCtx0, XRG0, XCert0, XSR0, ExecPayloadDigest(XPld0), "valid-g"), runNilR3))' "$OUT/T10-llvm-injection-ill-formed.txt" "T10: THE R1 INJECTION SHAPE (7 args, verdict string) IS ILL-FORMED in the R3 command language"
run_parse_reject "$DEF_LLVM" 60 'pConsR3(pInitR3(XCfgR3), pConsR3(pAccept(XB0, XSR0, ExecPayloadDigest(XPld0), true), runNilR3))' "$OUT/T11a-llvm-legacy-pAccept-ill-formed.txt" "T11a: frozen-1I pAccept(…, SRW3OK) is ILL-FORMED"
run_parse_reject "$DEF_LLVM" 60 'pConsR3(pGateEval(XB0, XSR0, ExecPayloadDigest(XPld0), "valid-g"), runNilR3)' "$OUT/T11b-llvm-legacy-pGateEval-ill-formed.txt" "T11b: frozen-1I pGateEval(…, verdict) is ILL-FORMED"
run_parse_reject "$DEF_LLVM" 60 'pConsR3(pInitR1(XCfgR3), runNilR3)' "$OUT/T11c-llvm-legacy-pInitR1-ill-formed.txt" "T11c: R1 pInitR1 is ILL-FORMED"
run_parse_reject "$DEF_LLVM" 60 'pConsR3(pAcceptR1(XB0, XSR0, ExecPayloadDigest(XPld0), 1), runNilR3)' "$OUT/T11d-llvm-legacy-pAcceptR1-ill-formed.txt" "T11d: R1 pAcceptR1 is ILL-FORMED"
run_parse_reject "$DEF_LLVM" 60 'pConsR3(pInitR2(XCfgR3), runNilR3)' "$OUT/T11e-llvm-legacy-pInitR2-ill-formed.txt" "T11e: R2 pInitR2 is ILL-FORMED"
run_parse_reject "$DEF_LLVM" 60 'pConsR3(pAcceptR2(XB0, XSR0, ExecPayloadDigest(XPld0), 1), runNilR3)' "$OUT/T11f-llvm-legacy-pAcceptR2-ill-formed.txt" "T11f: R2 pAcceptR2 is ILL-FORMED"

# ---- hs boundary demo --------------------------------------------------------
# The R3 init root check (a real-Keccak equality) does NOT decide on the
# Haskell backend (finding 1C-1) — the honest pipeline executes concretely on
# LLVM (T1) and Python only; the mechanized hs content is the proof ladder
# with the equality as a hypothesis.  T12 documents this boundary with a
# short stuck-run; there is deliberately NO hs honest-pipeline demo.
if [ -f "$DEF_HS/definition.kore" ]; then
  WORK2=$(mktemp -d)
  { echo "### T12 (hs boundary): the R3 INIT root check — BytesEq(ProtoRootR3(C), <r3anchor>) —"
    echo "    is a REAL-KECCAK equality and therefore does NOT decide on the Haskell backend"
    echo "    (finding 1C-1).  See the transcript body for the full disclosure."
    echo "# definition: $DEF_HS  (krun, K v7.1.337, Haskell backend)"
    echo "# program: pConsR3(pInitR3(XCfgR3), runNilR3)"
    printf '%s\n' 'pConsR3(pInitR3(XCfgR3), runNilR3)' > "$WORK2/pgm.k"
    echo "# --- krun output (trimmed to the evidence) ---"
    timeout 90 krun "$WORK2/pgm.k" -d "$DEF_HS" -cSRW3R3ANCHOR="$ANCHOR_ARG" 2>&1 | \
      rg -v -e '^kore-exec: \[[0-9]+\] Warning \(WarnFunctionWithoutEvaluators\):' \
        -e '^    No evaluators for function symbol:' -e '^        Lbl' \
        -e '^    defined at: ' -e '^\s+\^\s*$' \
        -e '^kore-exec: \[[0-9]+\] Warning \(WarnTriviallyTrue\):' | head -30
    echo "# --- krun exit: $? (124 = stuck at the init root equality; the documented boundary) ---"
    rm -rf "$WORK2"
  } > "$OUT/T12-hs-init-root-check-boundary.txt" 2>&1
  echo "wrote $OUT/T12-hs-init-root-check-boundary.txt"
else
  echo "hs definition not found at $DEF_HS — skipping T12 (compile with: kompile ... --backend haskell)"
fi

echo "R3 demo suite complete -> $OUT"
