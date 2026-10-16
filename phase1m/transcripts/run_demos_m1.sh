#!/usr/bin/env bash
# SRW3 Phase 1M — M1 demonstration transcripts (LLVM + krypto shim, real
# Keccak-256), executed over the REPAIRED machine (srw3closure-j-m1-demo.k).
#
#   T11-M1  — the unauthorized-source refusal CORRECTED: the same program as
#             the frozen T11 (init ~> exec with a source that is NOT the
#             pinned execution-client identity ~> runNil) now CONSUMES the
#             command and writes the jrefusedSource() diagnostic (the frozen
#             T11 shows the stuck configuration — the pre-repair witness).
#             The frozen T11 is RETAINED UNCHANGED as historical evidence;
#             this transcript carries the explicit OLD/NEW labels.
#   T1-M1   — the honest one-block pipeline COMMITS on the repaired machine
#             (no-regression continuity: the repair does not disturb the
#             authorized branches).
#
# Usage: bash phase1m/transcripts/run_demos_m1.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
OUT="$HERE/llvm"
WORK=$(mktemp -d)
mkdir -p "$OUT"
DEF_LLVM=/tmp/m1-llvm
[ -x "$DEF_LLVM/interpreter" ] || { echo "M1 LLVM interpreter missing — kompile srw3closure-j-m1-demo.k --backend llvm -o /tmp/m1-llvm (with the krypto shim)"; exit 9; }
source /home/z/my-project/tools/env.sh

# the trusted anchor: the REAL Keccak root of XCfgJ (the T0 certificate
# discipline; cross-layer agreement with the Python-computed anchor)
printf 'pConsJ(xCertJ, runNilJ)' > "$WORK/pgm.k"
ANCHOR=$(timeout 300 krun "$WORK/pgm.k" -d "$DEF_LLVM" -cSRW3JANCHOR='LinHex("00")' 2>/dev/null | grep -oE "cfgjroot=[a-f0-9]{64}" | head -1 | cut -d= -f2)
[ -n "$ANCHOR" ] || { echo "ANCHOR computation failed"; exit 9; }
ANCHOR_ARG="LinHex(\"$ANCHOR\")"
echo "ANCHOR=$ANCHOR" > "$OUT/anchor-m1.txt"

postproc() { # postproc <raw> <out>
  grep -A3 -E "^###|^# |<srw3closureJ>|<jnext>|<jhead>|<jlinhead>|<jstate>|<jrefuse>|<jvalid>|\[Error\]|kparse|krun exit" "$1" | grep -v "^--$" > "$2" 2>/dev/null
  echo "# --- end of transcript ---" >> "$2"
}

run() { # run <timeout> <program> <outfile> <label>
  printf '%s\n' "$2" > "$WORK/pgm.k"
  { echo "### $4"
    echo "# definition: srw3closure-j-m1-demo.k (krun, K v7.1.337, LLVM + krypto shim — the M1 REPAIRED machine)"
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

# T1-M1: the honest one-block pipeline (the frozen T1 program, byte-equal)
G0='pConsJ(pInitJ(XCfgJ, XCatJ), pConsJ(pExecJ(XExecClientD, XProg0, XCaller, 0), pConsJ(pGateEvalJ(XB0, XCtx0, XRG0, XCert0, StateRootJ(XPost0D), JPayloadDigestJ(XProg0)), pConsJ(pCommitJ(XB0, StateRootJ(XPost0D), JPayloadDigestJ(XProg0), 1), runNilJ))))'

# T11-M1: the unauthorized source (the frozen T11 program, byte-equal — the
# declared source LinHex("11..11") is NOT the pinned execution-client identity)
T11='pConsJ(pInitJ(XCfgJ, XCatJ), pConsJ(pExecJ(LinHex("1111111111111111111111111111111111111111111111111111111111111111"), XProg0, XCaller, 0), runNilJ))'

run 600 "$T11" "$OUT/T11-M1-llvm-unauthorized-source-refused-CORRECTED.txt" \
  "T11-M1 (CORRECTED — the L-FINDING-1 repair): unauthorized source in the fully-pinned machine — NEW behavior: the command is consumed and jrefusedSource() is written.  OLD (frozen T11, retained unchanged in phase1j/transcripts/llvm/): the configuration was STUCK (no diagnostic)."
run 600 "$G0" "$OUT/T1-M1-llvm-honest-one-block-pipeline.txt" \
  "T1-M1 (no-regression continuity): the honest one-block pipeline COMMITS on the repaired machine."

echo "DONE (anchor recorded in $OUT/anchor-m1.txt)"
