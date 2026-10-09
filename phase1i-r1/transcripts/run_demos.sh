#!/usr/bin/env bash
# SRW3 Phase 1I-R1 — krun demonstration transcripts (Haskell backend).
#
# T1  BEFORE: the FROZEN Phase 1I model accepts a caller-forged verdict for a
#     gate-rejected block (pbDecision = 0 = pdecReject) — chain extends.  This
#     is the operational vulnerability (audit finding F2), witnessed live.
# T2  AFTER: the REPAIRED model, same attack shape — the block even claims
#     pbDecision = 1, but the machine-created receipt records the true gate
#     verdict "invalid-policy"; the chain does NOT extend, the counter does
#     NOT advance, and the receipt remains (unconsumed).
# T3  AFTER: accept attempt with NO gate evaluation at all — fail-closed.
# T4  AFTER: config-version substitution (pinned policyV=7, declared CV=8) —
#     fail-closed (R1-CM4, decidable witness).
# T5  AFTER: the honest path under krun on the Haskell backend — the
#     policy/context digest equalities cannot be decided (no Keccak256raw
#     evaluators on this backend, finding 1C-1); the honest path is
#     demonstrated concretely by the Python mirror with real keccak
#     (transcripts/attacks/).  Retained as the disclosed boundary.
#
# Note on presentation: the Haskell backend emits symbolic #Ceil(Keccak256raw)
# definedness disjuncts for unevaluatable hook terms; the STATE content shown
# (cells) is concrete.  Digest-valued cells appear as unevaluated
# Keccak256raw(...) applications — the documented crypto abstraction.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
OUT="${1:-$REPO/phase1i-r1/transcripts/demos}"
mkdir -p "$OUT"
source /home/z/my-project/tools/env.sh

DEF_OLD=/tmp/proto-hs
DEF_R1=/tmp/r1-hs
INC="-I $REPO/phase1g/semantics -I $REPO/phase1f/semantics -I $REPO/phase1e/semantics -I $REPO/k/phase1d -I $REPO/k/kevm/kproj-e1e/plugin"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# C1: the pinned configuration (policy version 7)
CFG='protoCfg(b"\xc1", 7, b"\xd1", b"\xa1", b"\x91", b"\xcc", b"\xee", b"\xf1")'
# B_forged: parent-commit 0x11, payload 0x22, parent-root 0x33, child 0x44,
# effect 0x55, evidence 0x66, ctx 0x77, policy-commit 0x88, DECISION=0 (the
# gate said REJECT), slot 0
BF='protoBlock(b"\x11", b"\x22", b"\x33", b"\x44", b"\x55", b"\x66", b"\x77", b"\x88", 0, 0)'
# B_lie: the same block but DECISION=1 (the block LIES that the gate said valid)
BL='protoBlock(b"\x11", b"\x22", b"\x33", b"\x44", b"\x55", b"\x66", b"\x77", b"\x88", 1, 0)'

run() { # run <defdir> <pgm-text> <outfile> <label>
  printf '%s\n' "$2" > "$WORK/pgm.k"
  { echo "### $4"
    echo "# definition: $1  (krun, Haskell backend, K v7.1.337)"
    echo "# program:"
    sed 's/^/#   /' "$WORK/pgm.k"
    echo "# --- krun output ---"
    timeout 180 krun "$WORK/pgm.k" -d "$1" 2>&1
    echo "# --- krun exit: $? ---"
  } > "$3" 2>&1
  echo "wrote $3 ($(wc -l < "$3") lines)"
}

# T1 — BEFORE: frozen model accepts the forged verdict
run "$DEF_OLD" "pCons(pInit($CFG), pCons(pAccept($BF, b\"\\x44\", b\"\\x22\", $CFG, true), runNil))" \
  "$OUT/T1-BEFORE-frozen-forged-verdict-ACCEPTS.txt" \
  "T1 BEFORE (frozen phase1i model): caller supplies SRW3OK=true for a block whose decision field is pdecReject (0). The frozen pAccept checks only parent-link, slot, and the caller Boolean: the chain EXTENDS (slot 0 committed, counter 1)."

# T2 — AFTER: repaired model rejects the same attack (block even claims valid)
run "$DEF_R1" "pCons(pInitR1($CFG), pCons(pGateEval($BL, b\"\\x44\", b\"\\x22\", \"invalid-policy\"), pCons(pAcceptR1($BL, b\"\\x44\", b\"\\x22\", 7), runNil)))" \
  "$OUT/T2-AFTER-repaired-forged-verdict-REJECTS.txt" \
  "T2 AFTER (repaired model): the gate receipt for the SAME candidate records 'invalid-policy' (derived decision pdecReject). The accept attempt fails: counter stays 0, no committed block, the receipt remains unconsumed."

# T3 — AFTER: no gate evaluation at all
run "$DEF_R1" "pCons(pInitR1($CFG), pCons(pAcceptR1($BL, b\"\\x44\", b\"\\x22\", 7), runNil))" \
  "$OUT/T3-AFTER-no-receipt-REJECTS.txt" \
  "T3 AFTER: accept attempt with NO gate evaluation (empty receipt pool). Fail-closed: state unchanged (R1-CM7)."

# T4 — AFTER: config-version substitution
run "$DEF_R1" "pCons(pInitR1($CFG), pCons(pGateEval($BL, b\"\\x44\", b\"\\x22\", \"valid-g\"), pCons(pAcceptR1($BL, b\"\\x44\", b\"\\x22\", 8), runNil)))" \
  "$OUT/T4-AFTER-config-substitution-REJECTS.txt" \
  "T4 AFTER: the candidate declares config version 8 while the pinned configuration has policy version 7 — a policy upgrade that was never activated. Fail-closed (R1-CM4, decidable witness); the receipt also remains."

# T5 — AFTER: honest path under the hs backend (disclosed boundary)
run "$DEF_R1" "pCons(pInitR1($CFG), pCons(pGateEval($BL, b\"\\x44\", b\"\\x22\", \"valid-g\"), pCons(pAcceptR1($BL, b\"\\x44\", b\"\\x22\", 7), runNil)))" \
  "$OUT/T5-AFTER-honest-path-hs-boundary.txt" \
  "T5 AFTER: the HONEST path (verdict 'valid-g', matching decision/execution fields) under krun on the Haskell backend. The policy/context digest equalities in the accept guard cannot be decided (no Keccak256raw evaluators on this backend — finding 1C-1): the accept cannot CONFIRM, so the machine fail-closes or stalls on the symbolic condition. The honest path is demonstrated concretely by the Python mirror with real keccak digests (phase1i-r1/transcripts/attacks/ and phase1i-r1/python/)."
echo "demos complete"
