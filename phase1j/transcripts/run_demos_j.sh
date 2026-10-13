#!/usr/bin/env bash
# SRW3 Phase 1J — LLVM demonstration + attack suite (real Keccak-256 via the
# Phase-1C krypto shim).  Produces the T-series transcripts (the concrete
# pipeline evidence the documented Haskell boundary cannot evaluate) and the
# kparse ill-formedness series.  Usage: bash phase1j/transcripts/run_demos_j.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
OUT="$HERE/llvm"
WORK=$(mktemp -d)
mkdir -p "$OUT"
DEF_LLVM=/tmp/j-llvm
[ -x "$DEF_LLVM/interpreter" ] || { echo "J LLVM interpreter missing — run phase1j/proofs/j_build_llvm.sh"; exit 9; }
source /home/z/my-project/tools/env.sh

# the trusted anchor: the REAL Keccak root of XCfgJ (computed by the machine
# itself in T0 — the cross-layer agreement with the Python anchor is the
# conformance check; here we take it from the certificate run)
ANCHOR=$(timeout 300 krun "$WORK/pgm.k" -d "$DEF_LLVM" -cSRW3JANCHOR='LinHex("00")' 2>/dev/null true; printf 'pConsJ(xCertJ, runNilJ)' > "$WORK/pgm.k"; timeout 300 krun "$WORK/pgm.k" -d "$DEF_LLVM" -cSRW3JANCHOR='LinHex("00")' 2>/dev/null | grep -oE "cfgjroot=[a-f0-9]{64}" | head -1 | cut -d= -f2)
[ -n "$ANCHOR" ] || { echo "ANCHOR computation failed"; exit 9; }
ANCHOR_ARG="LinHex(\"$ANCHOR\")"
OTHER_ANCHOR="LinHex(\"abababababababababababababababababababababababababababababababab\")"
echo "ANCHOR=$ANCHOR" > "$OUT/anchor.txt"

postproc() { # postproc <raw> <out>  (keep the k cell + the final config WITH values)
  grep -A3 -E "^###|^# |<srw3closureJ>|<jnext>|<jhead>|<jlinhead>|<jstate>|<jrefuse>|<jvalid>|\[Error\]|kparse|krun exit" "$1" | grep -v "^--$" > "$2" 2>/dev/null
  echo "# --- end of transcript ---" >> "$2"
}

run() { # run <timeout> <program> <outfile> <label>
  printf '%s\n' "$2" > "$WORK/pgm.k"
  { echo "### $4"
    echo "# definition: srw3closure-j-demo.k (krun, K v7.1.337, LLVM + krypto shim)"
    echo "# anchor (SRW3JANCHOR): $ANCHOR"
    echo "# program:"
    sed 's/^/#   /' "$WORK/pgm.k"
    echo "# --- krun output ---"
    timeout "$1" krun "$WORK/pgm.k" -d "$DEF_LLVM" -cSRW3JANCHOR="$ANCHOR_ARG" 2>&1
    echo "# --- krun exit: $? ---"
  } > "$WORK/raw.txt" 2>&1
  postproc "$WORK/raw.txt" "$3"
  echo "wrote $3 ($(wc -l < "$3") lines)"
}

run_other_anchor() {
  printf '%s\n' "$2" > "$WORK/pgm.k"
  { echo "### $4"
    echo "# definition: srw3closure-j-demo.k (krun, K v7.1.337, LLVM + krypto shim)"
    echo "# anchor (SRW3JANCHOR): abab..ab (a DIFFERENT protocol root)"
    echo "# program:"
    sed 's/^/#   /' "$WORK/pgm.k"
    echo "# --- krun output ---"
    timeout "$1" krun "$WORK/pgm.k" -d "$DEF_LLVM" -cSRW3JANCHOR="$OTHER_ANCHOR" 2>&1
    echo "# --- krun exit: $? ---"
  } > "$WORK/raw.txt" 2>&1
  postproc "$WORK/raw.txt" "$3"
  echo "wrote $3 ($(wc -l < "$3") lines)"
}

run_parse_reject() {
  printf '%s\n' "$2" > "$WORK/pgm.k"
  { echo "### $4"
    echo "# definition: srw3closure-j-demo.k (krun, K v7.1.337)"
    echo "# program (EXPECTED: kparse rejection — the command is ILL-FORMED):"
    sed 's/^/#   /' "$WORK/pgm.k"
    echo "# --- krun output ---"
    timeout "$1" krun "$WORK/pgm.k" -d "$DEF_LLVM" -cSRW3JANCHOR="$ANCHOR_ARG" 2>&1
    echo "# --- krun exit: $? ---"
  } > "$WORK/raw.txt" 2>&1
  postproc "$WORK/raw.txt" "$3"
  echo "wrote $3 ($(wc -l < "$3") lines)"
}

G0='pConsJ(pInitJ(XCfgJ, XCatJ), pConsJ(pExecJ(XExecClientD, XProg0, XCaller, 0), pConsJ(pGateEvalJ(XB0, XCtx0, XRG0, XCert0, StateRootJ(XPost0D), JPayloadDigestJ(XProg0)), pConsJ(pCommitJ(XB0, StateRootJ(XPost0D), JPayloadDigestJ(XProg0), 1), runNilJ))))'
G1='pConsJ(pInitJ(XCfgJ, XCatJ), pConsJ(pExecJ(XExecClientD, XProg0, XCaller, 0), pConsJ(pGateEvalJ(XB0, XCtx0, XRG0, XCert0, StateRootJ(XPost0D), JPayloadDigestJ(XProg0)), pConsJ(pCommitJ(XB0, StateRootJ(XPost0D), JPayloadDigestJ(XProg0), 1), pConsJ(pExecJ(XExecClientD, XProg1, XCaller, 0), pConsJ(pGateEvalJ(XB1, XCtx1, XRG1, XCert1, StateRootJ(XPost1D), JPayloadDigestJ(XProg1)), pConsJ(pCommitJ(XB1, StateRootJ(XPost1D), JPayloadDigestJ(XProg1), 1), runNilJ)))))))'

run 300 'pConsJ(xCertJ, runNilJ)' "$OUT/T0-llvm-cross-layer-certificate.txt" \
  "T0: cross-layer byte certificate (catalog canon + sub-roots + config root + state roots + trace/footprint digests + evidence identity + block commitment + the COMPUTED verdicts verdict0/verdict1/verdictu + the SafeJ evaluations safe0/safeunsafe — real Keccak-256)"

run 300 "$G0" "$OUT/T1-llvm-honest-one-block-pipeline.txt" \
  "T1: honest one-block pipeline (init authorized -> derived exec -> COMPUTED verdict -> commit; the state moves to the DERIVED post-state)"

run 420 "$G1" "$OUT/T2-llvm-honest-two-block-pipeline.txt" \
  "T2: honest two-block continuation under the SAME full config root (the J-A24 reorg-stale class's positive control)"

run 240 'pConsJ(pInitJ(XCfgJ, XCatJ), pConsJ(pExecJ(XExecClientD, XProg0, XCaller, 0), pConsJ(pGateEvalJ(XB0, XCtx0, XRG0, XCert0, StateRootJ(XPost0D), JPayloadDigestJ(XProg0)), runNilJ)))' \
  "$OUT/T3-llvm-gate-only-no-chain-move.txt" \
  "T3: gate evaluation mints the receipt (computed verdict + computed roots); NO chain state moves"

run 240 'pConsJ(pInitJ(XCfgJ, XCatJ), pConsJ(pCommitJ(XB0, StateRootJ(XPost0D), JPayloadDigestJ(XProg0), 1), runNilJ))' \
  "$OUT/T4-llvm-commit-no-receipt-REJECTS.txt" \
  "T4: commit with NO receipts -> fail-closed reject, state unchanged (J-A17/J-A19 class)"

run 240 'pConsJ(pInitJ(XCfgJ, XCatJ), pConsJ(pInitJ(XCfgJ, XCatJ), runNilJ))' \
  "$OUT/T5-llvm-reinit-refused.txt" \
  "T5: re-initialization refused (the pin is immutable)"

U='pConsJ(pInitJ(XCfgJ, XCatJ), pConsJ(pExecJ(XExecClientD, XProg0, XCaller, 0), pConsJ(pGateEvalJ(XB0, XCtx0, XRG0, XCert0, StateRootJ(XPost0D), JPayloadDigestJ(XProg0)), pConsJ(pCommitJ(XB0, StateRootJ(XPost0D), JPayloadDigestJ(XProg0), 1), pConsJ(pExecJ(XExecClientD, XProg1, XCaller, 0), pConsJ(pGateEvalJ(XB1, XCtx1, XRG1, XCert1, StateRootJ(XPost1D), JPayloadDigestJ(XProg1)), pConsJ(pCommitJ(XB1, StateRootJ(XPost1D), JPayloadDigestJ(XProg1), 1), pConsJ(pExecJ(XExecClientD, XProgUnsafe, XCaller, 0), pConsJ(pGateEvalJ(XBUnsafe, XCtxU, XRGU, XCertU, StateRootJ(XPostUD), JPayloadDigestJ(XProgUnsafe)), pConsJ(pCommitJ(XBUnsafe, StateRootJ(XPostUD), JPayloadDigestJ(XProgUnsafe), 1), runNilJ))))))))))'

run 420 "$U" "$OUT/T6-llvm-unsafe-3app-composition-REJECTS.txt" \
  "T6: THE 3-APP COUNTERMODEL AT THE COMMIT BOUNDARY (J-A13): every local check passes, the pairwise invariant passes, the gate ACCEPTS the record (valid-g) — and the COMPUTED SafeJ conjunct REFUSES the commit; state/head/counter unchanged"

run 240 'pConsJ(pInitJ(XCfgJ, XCatJ), pConsJ(pInitJ(XCfgJ, XCatJNoHe1), runNilJ))' \
  "$OUT/T7-llvm-missing-hyperedge-catalog-REFUSED.txt" \
  "T7: the missing-hyperedge catalog under the honest config is REFUSED at the pin (the graph digest differs — J-A10/J-A12; real keccak)"

run_other_anchor 240 'pConsJ(pInitJ(XCfgJ, XCatJ), runNilJ)' \
  "$OUT/T8-llvm-wrong-anchor-REFUSED.txt" \
  "T8: the honest configuration on a machine anchored at a DIFFERENT protocol root is REFUSED (the anchor is authenticated protocol input, not caller data — J-A21)"

run 240 'pConsJ(pInitJ(XCfgJ, XCatJ), pConsJ(pExecJ(XExecClientD, ListItem(jWrite(4098, 0, 100)) ListItem(jUnsupported(96)) ListItem(jWrite(4098, 1, 1)) .List, XCaller, 0), runNilJ))' \
  "$OUT/T9-llvm-unsupported-effect-refused.txt" \
  "T9: an excluded effect class (LOGn-family marker 96) mid-program -> EXPLICIT refusal, NO receipt, NO state change (J-A06; the closed-fragment boundary)"

run 240 'pConsJ(pInitJ(XCfgJ, XCatJ), pConsJ(pExecJ(XExecClientD, ListItem(jWrite(4097, 0, 18446744073709551616)) .List, XCaller, 0), runNilJ))' \
  "$OUT/T10-llvm-bounds-refused.txt" \
  "T10: an out-of-bounds operand -> the explicit bounds refusal, no receipt (J-A06 bounds class)"

run 240 'pConsJ(pInitJ(XCfgJ, XCatJ), pConsJ(pExecJ(LinHex("1111111111111111111111111111111111111111111111111111111111111111"), XProg0, XCaller, 0), runNilJ))' \
  "$OUT/T11-llvm-unauthorized-source-refused.txt" \
  "T11: an unauthorized execution source is REFUSED (J-A08; the declared source is not the pinned execution-client identity)"

run 240 'pConsJ(pInitJ(XCfgJ, XCatJ), pConsJ(pExecJ(XExecClientD, XProg0, XCaller, 0), pConsJ(pGateEvalJ(XB1, XCtx0, XRG0, XCert0, StateRootJ(XPost0D), JPayloadDigestJ(XProg0)), runNilJ)))' \
  "$OUT/T12-llvm-position-substitution-REJECTS.txt" \
  "T12: the slot-0 evidence presented for the slot-1 candidate -> the mint refuses (position binding; J-A17/J-A24 class)"

run 420 'pConsJ(pInitJ(XCfgJ, XCatJ), pConsJ(pExecJ(XExecClientD, XProg0, XCaller, 0), pConsJ(pGateEvalJ(XB0, XCtx0, XRG0, XCert0, StateRootJ(XPost0D), JPayloadDigestJ(XProg0)), pConsJ(pCommitJ(XB0, StateRootJ(XPost0D), JPayloadDigestJ(XProg0), 1), pConsJ(pExecJ(XExecClientD, XProgGlobal, XCaller, 0), pConsJ(pGateEvalJ(XBG, XCtxG, XRG0, XCert0, StateRootJ(XPostG), JPayloadDigestJ(XProgGlobal)), pConsJ(pCommitJ(XBG, StateRootJ(XPostG), JPayloadDigestJ(XProgGlobal), 1), runNilJ)))))))' \
  "$OUT/T13-llvm-global-invariant-REJECTS.txt" \
  "T13: the global-invariant class (J-A15): locals + hyperedge invariants pass, the GLOBAL invariant fails -> commit refused"

# ---- ill-formed programs (backend-independent parse rejections) --------------
run_parse_reject 120 'pConsJ(pInitJ(XCfgJ, XCatJ), pConsJ(pExecJ(XExecClientD, XProg0, XCaller, 0), pConsJ(pGateEvalJ(XB0, XCtx0, XRG0, XCert0, StateRootJ(XPost0D), JPayloadDigestJ(XProg0), "valid-g"), runNilJ)))' \
  "$OUT/T14a-llvm-injection-ill-formed.txt" \
  "T14a: THE INJECTION SHAPE (a verdict string on pGateEvalJ) IS ILL-FORMED in the J command language"

run_parse_reject 120 'pConsJ(pInitJ(XCfgJ, XCatJ), pConsJ(pCommitJ(XB0, StateRootJ(XPost0D), JPayloadDigestJ(XProg0), 1, true), runNilJ))' \
  "$OUT/T14b-llvm-caller-boolean-ill-formed.txt" \
  "T14b: a caller-supplied coverage Boolean on pCommitJ IS ILL-FORMED (J-A16/J-A01 — no command accepts a policy/coverage/authenticity Boolean)"

run_parse_reject 120 'pConsJ(pInitJ(XCfgJ, XCatJ), pConsJ(pAcceptR3(XB0, StateRootJ(XPost0D), JPayloadDigestJ(XProg0), 1), runNilJ))' \
  "$OUT/T15a-llvm-legacy-pAcceptR3-ill-formed.txt" \
  "T15a: the frozen R3 command pAcceptR3 IS ILL-FORMED in the J command language (J-LEGACY-SURFACE-EXCLUDED)"

run_parse_reject 120 'pConsJ(pGateEvalR3(XB0, XCtx0, XRG0, XCert0, StateRootJ(XPost0D), JPayloadDigestJ(XProg0)), runNilJ)' \
  "$OUT/T15b-llvm-legacy-pGateEvalR3-ill-formed.txt" \
  "T15b: the frozen R3 command pGateEvalR3 IS ILL-FORMED"

run_parse_reject 120 'pConsJ(pInitJ(XCfgJ, XCatJ, 1), runNilJ)' \
  "$OUT/T15c-llvm-anchor-argument-ill-formed.txt" \
  "T15c: an anchor/root ARGUMENT on pInitJ IS ILL-FORMED (the anchor is protocol input, never caller data)"

echo "=== J LLVM demo suite complete ==="
rm -rf "$WORK"
