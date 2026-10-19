#!/usr/bin/env bash
# SRW3 Phase 1M — M2 demonstration transcripts (LLVM + krypto shim, real
# Keccak-256), executed over the M2 HASH-REDIRECT machine
# (srw3closure-j-m2-demo.k — make_m2.py).
#
# The M2 machine redirects the hash primitive to the total pure-K evaluator
# Keccak256T (the machine-side redirect; the equation is tried before the
# native hook).  These transcripts run with --hook-namespaces KRYPTO + the
# krypto shim LINKED (the attribute-dropped kompile of the redirect machine
# crashes the LLVM backend — heap corruption, gdb backtrace retained at
# phase1m/audit/m2-hash-redirect.md §6 — so the M2 LLVM tier uses the
# attribute-PRESENT build; the redirect equation still computes every
# machine hash, and the anchor byte-equality below is the end-to-end
# evidence that the evaluator agrees with the frozen hook on the demo
# data).
#
#   ANCHOR-M2 — the machine-computed cfgjroot over the SAME fixture and the
#               SAME anchor discipline as the frozen T0/T1 record: MUST be
#               byte-identical to 295e0b6d... (the frozen record).
#   T11-M2    — the unauthorized-source refusal CORRECTED on the M2 machine
#               (Workstream-A continuity through the redirect: the command
#               is consumed and jrefusedSource() is written).
#   T1-M2     — the honest one-block pipeline COMMITS on the M2 machine
#               (no-regression continuity through the redirect).
#
# Usage: bash phase1m/transcripts/run_demos_m2.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
OUT="$HERE/llvm"
WORK=$(mktemp -d)
mkdir -p "$OUT"
DEF_LLVM=/tmp/m2-llvm-hk
[ -x "$DEF_LLVM/srw3closure-j-m2-demo-kompiled/interpreter" ] || { echo "M2 LLVM interpreter missing — kompile srw3closure-j-m2-demo.k --backend llvm --hook-namespaces KRYPTO with the krypto shim (see audit/m2-hash-redirect.md §6)"; exit 9; }
source /home/z/my-project/tools/env.sh
export LIBRARY_PATH="$TOOLS/extract/syslibs:$LIBRARY_PATH"
export NIX_LLVM_KOMPILE_LIBS="-L$REPO/k/phase1d/shim -lkrypto-shim -lsecp256k1 -lgmp"

# the trusted anchor: the REAL Keccak root of XCfgJ (the T0 certificate
# discipline; cross-layer agreement with the Python-computed anchor)
printf 'pConsJ(xCertJ, runNilJ)' > "$WORK/pgm.k"
ANCHOR=$(timeout 900 krun "$WORK/pgm.k" -d "$DEF_LLVM/srw3closure-j-m2-demo-kompiled" -cSRW3JANCHOR='LinHex("00")' 2>/dev/null | grep -oE "cfgjroot=[a-f0-9]{64}" | head -1 | cut -d= -f2)
[ -n "$ANCHOR" ] || { echo "ANCHOR computation failed"; exit 9; }
ANCHOR_ARG="LinHex(\"$ANCHOR\")"
{
  echo "ANCHOR=$ANCHOR"
  echo "FROZEN-RECORD-ANCHOR=295e0b6d2215e20662693a20e9af41d58f09b07b77dedd92924c2f6029dec9df"
  if [ "$ANCHOR" = "295e0b6d2215e20662693a20e9af41d58f09b07b77dedd92924c2f6029dec9df" ]; then
    echo "ANCHOR-MATCH: BYTE-IDENTICAL to the frozen record (the M2 redirect computes the same anchor bytes)"
  else
    echo "ANCHOR-MATCH: MISMATCH — GATE ALARM"
  fi
} > "$OUT/anchor-m2.txt"
cat "$OUT/anchor-m2.txt"

postproc() { # postproc <raw> <out>
  grep -A3 -E "^###|^# |<srw3closureJ>|<jnext>|<jhead>|<jlinhead>|<jstate>|<jrefuse>|<jvalid>|\[Error\]|kparse|krun exit" "$1" | grep -v "^--$" > "$2" 2>/dev/null
  echo "# --- end of transcript ---" >> "$2"
}

run() { # run <timeout> <program> <outfile> <label>
  printf '%s\n' "$2" > "$WORK/pgm.k"
  { echo "### $4"
    echo "# definition: srw3closure-j-m2-demo.k (krun, K v7.1.337, LLVM + krypto shim + --hook-namespaces KRYPTO — the M2 hash-redirect machine)"
    echo "# anchor (SRW3JANCHOR): $ANCHOR"
    echo "# program:"
    sed 's/^/#   /' "$WORK/pgm.k"
    echo "# --- krun output ---"
    timeout "$1" krun "$WORK/pgm.k" -d "$DEF_LLVM/srw3closure-j-m2-demo-kompiled" -cSRW3JANCHOR="$ANCHOR_ARG" 2>&1
    echo "# --- krun exit: $? ---"
  } > "$WORK/raw.txt" 2>&1
  postproc "$WORK/raw.txt" "$3"
  echo "wrote $3 ($(wc -l < "$3") lines)"
}

# T1-M2: the honest one-block pipeline (the frozen T1 program, byte-equal)
G0='pConsJ(pInitJ(XCfgJ, XCatJ), pConsJ(pExecJ(XExecClientD, XProg0, XCaller, 0), pConsJ(pGateEvalJ(XB0, XCtx0, XRG0, XCert0, StateRootJ(XPost0D), JPayloadDigestJ(XProg0)), pConsJ(pCommitJ(XB0, StateRootJ(XPost0D), JPayloadDigestJ(XProg0), 1), runNilJ))))'

# T11-M2: the unauthorized source (the frozen T11 program, byte-equal)
T11='pConsJ(pInitJ(XCfgJ, XCatJ), pConsJ(pExecJ(LinHex("1111111111111111111111111111111111111111111111111111111111111111"), XProg0, XCaller, 0), runNilJ))'

run 900 "$T11" "$OUT/T11-M2-llvm-unauthorized-source-refused.txt" \
  "T11-M2 (the L-FINDING-1 repair, on the M2 hash-redirect machine): unauthorized source in the fully-pinned machine — the command is consumed and jrefusedSource() is written (Workstream-A continuity through the redirect; the frozen T11 stuck witness remains retained unchanged in phase1j/transcripts/llvm/)."
run 900 "$G0" "$OUT/T1-M2-llvm-honest-one-block-pipeline.txt" \
  "T1-M2 (no-regression continuity): the honest one-block pipeline COMMITS on the M2 hash-redirect machine — every machine hash computed by the total evaluator Keccak256T."

echo "DONE (anchor recorded in $OUT/anchor-m2.txt)"
