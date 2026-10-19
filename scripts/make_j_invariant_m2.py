#!/usr/bin/env python3
"""
SRW3 Phase 1M — Workstream B: build the M2 port of the 1L proof-facing
invariant module (j_invariant.k).

j_invariant_m2.k = phase1l/semantics/j_invariant.k with EXACTLY THREE
disclosed edits and NOTHING else:
  1. the M2-port header (documentation; records the 1L sha256);
  2. requires "../../phase1j/semantics/srw3closure-j.k" ->
     requires "../semantics/srw3closure-j-m2.k"  (the M2 hash-redirect
     machine replaces the frozen machine; the JInv definitions are
     UNCHANGED — every hash application inside them now flows through the
     total evaluator Keccak256T via the M2 redirect);
  3. module rename SRW3L-INVARIANT -> SRW3L-INVARIANT-M2.

Roundtrip discipline (make_m1.py/make_m2.py precedent): the emitted file is
verified to reduce to the 1L original modulo exactly the disclosed edits.
"""
import hashlib
from pathlib import Path

REPO = Path("/home/z/my-project/srw3-1m")
SRC = REPO / "phase1l/semantics/j_invariant.k"
OUT = REPO / "phase1m/semantics/j_invariant_m2.k"

src = SRC.read_text()
src_sha = hashlib.sha256(src.encode()).hexdigest()

HEADER = f"""\
// =============================================================================
// SRW3 PHASE 1M — THE 1L SAFETY INVARIANT, M2 PORT (PROOF-FACING)
//                    (phase1m/semantics/j_invariant_m2.k)
//
// This module is phase1l/semantics/j_invariant.k (sha256
// {src_sha}) with EXACTLY THREE disclosed edits and NOTHING else:
//   1. this header;
//   2. the machine import is the M2 hash-redirect machine
//      (../semantics/srw3closure-j-m2.k — make_m2.py) replacing the frozen
//      Phase 1J machine; the JInv/JInvPreinitJ/JChainCoherentJ definitions
//      and every hash-using builder body are UNCHANGED — with the M2
//      redirect every hash application they materialize flows through the
//      TOTAL evaluator Keccak256T (the B1 definedness boundary removed);
//   3. the module rename SRW3L-INVARIANT -> SRW3L-INVARIANT-M2.
// The reachable rule set is the M2 machine's = the frozen 1J machine's
// rules + the ONE L-FINDING-1 repair (the map tail; make_m1.py) + the ONE
// hash-redirect equation (make_m2.py; no transition rule — the redirect is
// a function EQUATION on the hash primitive).
// =============================================================================

"""

OLD_REQ = 'requires "../../phase1j/semantics/srw3closure-j.k"'
NEW_REQ = 'requires "../semantics/srw3closure-j-m2.k"'
OLD_MOD = "module SRW3L-INVARIANT\n"
NEW_MOD = "module SRW3L-INVARIANT-M2\n"
OLD_IMP = "  imports SRW3CLOSURE-J\n"
NEW_IMP = "  imports SRW3CLOSURE-J-M2\n"

body = src
assert body.count(OLD_REQ) == 1
body = body.replace(OLD_REQ, NEW_REQ)
assert body.count(OLD_MOD) == 1
body = body.replace(OLD_MOD, NEW_MOD)
assert body.count(OLD_IMP) == 1
body = body.replace(OLD_IMP, NEW_IMP)

out_text = HEADER + body
OUT.write_text(out_text)

# roundtrip
chk = out_text.replace(HEADER, "", 1)
chk = chk.replace(NEW_REQ, OLD_REQ, 1)
chk = chk.replace(NEW_MOD, OLD_MOD, 1)
chk = chk.replace(NEW_IMP, OLD_IMP, 1)
assert chk == src, "ROUNDTRIP FAILED"
print(f"j_invariant_m2.k written; 1L sha256: {src_sha}; roundtrip OK")
