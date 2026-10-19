#!/usr/bin/env python3
"""
SRW3 Phase 1M — Workstream C: build the M3 machine (the explicit,
non-committing gate-refusal transition) from the M2 machine.

M3 = M2 (the hash-redirect machine) with EXACTLY FOUR disclosed edits and
NOTHING else:
  1. the M3 header block (documentation; records the M2 sha256);
  2. module rename SRW3CLOSURE-J-M2 -> SRW3CLOSURE-J-M3;
  3. the JRefuse syntax gains `jrefusedGate()` (the explicit gate-refusal
     diagnostic, in the domain of the existing refusal diagnostics);
  4. ONE [owise] rule — THE GATE-FAILURE TRANSITION:
         rule <k> pGateEvalJ(...) => .K ... </k>
              <jrefuse> _:JRefuse => jrefusedGate() </jrefuse>
              [owise]
     placed immediately after the two gate-mint rules.  By K's [owise]
     semantics the rule fires IFF neither mint rule matches — the
     success/failure partition is EXHAUSTIVE BY CONSTRUCTION (two mint
     rules + one [owise] = the complete match space of well-formed gate
     commands) and NON-OVERLAPPING ([owise] cannot fire when a mint rule
     matches).  The refusal writes ONLY the diagnostic and consumes the
     command; every other cell is absent from the rule and therefore
     unchanged (the non-committing property, mechanized by MC-GATE-REFUSE-
     NOCOMMIT and the concrete per-class witnesses).

WHY (the handoff §4 Workstream C): the 1L blocker census B4 — a
pGateEvalJ whose mint preconditions are unmet matched NO rule: the
configuration was STUCK (no receipt, no diagnostic, no movement), which
preserves safety but is not the explicit refusal the model and the Python
mirror promise (the mirror's gate_eval returns None — no receipt, no
movement — on every unmet-precondition class).  M3 makes the failure
transition EXPLICIT: the machine now agrees with the mirror on every
well-formed gate command (the domain-coverage claim MC-GATE-COVERAGE,
measured against its M2 OLD witness MC-OLD-GATE-COVERAGE).

Roundtrip discipline (make_m1/m2 precedent): the emitted file is verified
to reduce to M2 modulo exactly the disclosed edits.
"""
import hashlib
from pathlib import Path

REPO = Path("/home/z/my-project/srw3-1m")
M2 = REPO / "phase1m/semantics/srw3closure-j-m2.k"
OUT = REPO / "phase1m/semantics/srw3closure-j-m3.k"
DEMO_IN = REPO / "phase1m/semantics/srw3closure-j-m2-demo.k"
DEMO_OUT = REPO / "phase1m/semantics/srw3closure-j-m3-demo.k"

src = M2.read_text()
m2_sha = hashlib.sha256(src.encode()).hexdigest()

HEADER = f"""\
// =============================================================================
// SRW3 PHASE 1M — M3: THE EXPLICIT GATE-FAILURE TRANSITION (Workstream C)
//                    (phase1m/semantics/srw3closure-j-m3.k)
//
// M3 = M2 (the hash-redirect machine; scripts/make_m2.py; sha256
// {m2_sha}) with EXACTLY FOUR disclosed edits and NOTHING else:
//   1. this header;
//   2. the module rename SRW3CLOSURE-J-M2 -> SRW3CLOSURE-J-M3;
//   3. `jrefusedGate()` — the explicit gate-refusal diagnostic (JRefuse
//      domain, alongside jrefusedUnsupported/jrefusedBounds/jrefusedSource);
//   4. ONE [owise] rule after the two gate-mint rules — the gate-FAILURE
//      transition: it fires IFF neither mint rule matches (K's [owise]
//      semantics), consumes the command, and writes ONLY <jrefuse> :=
//      jrefusedGate().  THE SUCCESS/FAILURE PARTITION OF WELL-FORMED GATE
//      COMMANDS IS EXHAUSTIVE BY CONSTRUCTION (mint ∧ pool-exists-mint ∪
//      [owise]) AND NON-OVERLAPPING ([owise] cannot fire when a mint
//      matches); the refusal is NON-COMMITTING (no receipt, no committed
//      state, no head, no lineage movement — mechanized by MC-GATE-REFUSE-
//      NOCOMMIT + the concrete per-class witnesses in the MC ladder).
//
// WHY (the handoff §4): the 1L blocker B4 — a gate command with unmet mint
// preconditions matched NO rule and the configuration was STUCK (safe, but
// not the explicit refusal the model and the Python mirror promise — the
// mirror's gate_eval returns None with NO state change on every unmet
// class).  M3 makes the failure explicit; the machine now agrees with the
// mirror on EVERY well-formed gate command (MC-GATE-COVERAGE vs its M2 OLD
// witness MC-OLD-GATE-COVERAGE — the B4 removal, measured).  Level III
// only; no consensus-integration claim.
// =============================================================================
"""

body = src

# (2) module rename
assert body.count("module SRW3CLOSURE-J-M2") == 1
body = body.replace("module SRW3CLOSURE-J-M2", "module SRW3CLOSURE-J-M3")

# (3) the JRefuse syntax extension
OLD_SYN = '''  syntax JRefuse ::= "jrefuseNoneJ"'''
NEW_SYN = '''  syntax JRefuse ::= "jrefuseNoneJ"'''
assert body.count(OLD_SYN) == 1
# append the new constructor to the END of the JRefuse declaration block
# (the block ends with jrefusedSource() at the line `| "jrefusedSource" "(" ")"`)
OLD_SRC_CONS = '''                   | "jrefusedSource" "(" ")"'''
NEW_SRC_CONS = '''                   | "jrefusedSource" "(" ")"
                   | "jrefusedGate" "(" ")"'''
assert body.count(OLD_SRC_CONS) == 1
body = body.replace(OLD_SRC_CONS, NEW_SRC_CONS)

# (4) the [owise] refusal rule — inserted after the SECOND mint rule's
# requires block (the fresh-pool mint; the second occurrence of the anchor
# equality conjunct), before the next section comment.
ANCHOR_LINE = "         andBool BytesEq(jerAnchorOf(E:JExecReceipt), A:Bytes)\n"
assert body.count(ANCHOR_LINE) == 2
idx = body.index(ANCHOR_LINE)                     # first mint rule
idx = body.index(ANCHOR_LINE, idx + 1)            # second mint rule
insert_at = idx + len(ANCHOR_LINE)
RULE = """
  // ---------------------------------------------------------------------------
  // THE M3 GATE-FAILURE TRANSITION (Workstream C; the ONLY rule added to the
  // machine).  [owise]: fires IFF neither gate-mint rule matches — the
  // explicit, fail-closed refusal of EVERY well-formed gate command whose
  // mint preconditions are unmet (the 1L B4 stuck path is GONE).  The rule
  // consumes the command and writes ONLY the diagnostic; every other cell
  // is absent from the rule and therefore unchanged.  Non-overlap with the
  // mint rules is K's [owise] semantics; the partition of well-formed gate
  // commands into (mint) and (explicit refusal) is exhaustive by
  // construction and mechanized as MC-GATE-COVERAGE (vs its M2 OLD witness
  // MC-OLD-GATE-COVERAGE, the retained B4 stuck-path witness).
  // ---------------------------------------------------------------------------
  rule <k> pGateEvalJ(_:JBlockJ, _:ExecCtx, _:LinRecG, _:AuthzCert,
                      _:Bytes, _:Bytes) => .K ... </k>
       <jrefuse> _:JRefuse => jrefusedGate() </jrefuse>
    [owise]

"""
body = body[:insert_at] + RULE + body[insert_at:]

out_text = HEADER + "\n" + body
OUT.write_text(out_text)

# --- roundtrip verification -------------------------------------------------
chk = out_text
chk = chk.replace(HEADER + "\n", "", 1)
chk = chk.replace("module SRW3CLOSURE-J-M3", "module SRW3CLOSURE-J-M2", 1)
chk = chk.replace(NEW_SRC_CONS, OLD_SRC_CONS, 1)
i = chk.index(RULE)
chk = chk[:i] + chk[i + len(RULE):]
assert chk == src, "ROUNDTRIP FAILED: emitted file does not reduce to M2"
print(f"M3 written: {OUT}")
print(f"M2 sha256: {m2_sha}")
print("roundtrip: OK (M3 = M2 + exactly the 4 disclosed edits)")

# --- demo module ------------------------------------------------------------
demo = DEMO_IN.read_text()
d3 = demo.replace('\nrequires "srw3closure-j-m2.k"', '\nrequires "srw3closure-j-m3.k"', 1)
d3 = d3.replace("\nmodule SRW3CLOSURE-J-M2-DEMO", "\nmodule SRW3CLOSURE-J-M3-DEMO", 1)
d3 = d3.replace("\n  imports SRW3CLOSURE-J-M2", "\n  imports SRW3CLOSURE-J-M3", 1)
assert '\nrequires "srw3closure-j-m3.k"' in d3
assert '\nmodule SRW3CLOSURE-J-M3-DEMO' in d3
assert '\n  imports SRW3CLOSURE-J-M3' in d3
d3 = d3.replace(
    "// SRW3 PHASE 1M — M2 DEMONSTRATION MODULE (VERSIONED COPY; make_m2.py)",
    "// SRW3 PHASE 1M — M3 DEMONSTRATION MODULE (VERSIONED COPY; make_m3.py)", 1)
d3 = d3.replace("srw3closure-j-m2.k — the M2 hash-redirect machine; make_m2.py)",
                "srw3closure-j-m3.k — the M3 gate-refusal machine; make_m3.py)", 1)
d3 = d3.replace("T11-M2", "T11-M3").replace("T1-M2", "T1-M3")
d3 = d3.replace("M2 hash-redirect machine", "M3 gate-refusal machine")
DEMO_OUT.write_text(d3)
print(f"M3 demo written: {DEMO_OUT}")
