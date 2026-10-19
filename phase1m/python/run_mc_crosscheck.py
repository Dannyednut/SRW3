#!/usr/bin/env python3
"""SRW3 Phase 1M — Workstream C: the Python-mirror gate-refusal crosscheck.

The mirror's gate_eval returns None (NO receipt, NO state movement) on every
unmet-precondition class (j_model.py gate_eval: the early `return None`
branches); the M3 machine writes jrefusedGate() and changes nothing (the
MC-GATE-REFUSE-* claims).  This crosscheck drives the REAL frozen mirror
through every unmet class + the honest accept control and asserts:
  refusal classes  -> gate_eval returns None, no gate receipt minted,
                      no committed movement (state/head/lin_head/slot);
  the accept class -> the mirror mints (the gate's accept path agrees with
                      the frozen 1J mirror behavior, 48/48 suite).
CROSS-LAYER AGREEMENT: the M3 machine and the mirror agree on every
well-formed gate command class (explicit refusal <-> None+no-movement).
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = "/".join(HERE.split("/")[:-2])
for p in (f"{REPO}/phase1j/python", f"{REPO}/python-gen", f"{REPO}/phase1e/python",
          f"{REPO}/phase1f/python", f"{REPO}/phase1g/python",
          f"{REPO}/phase1i-r1/python", f"{REPO}/phase1i-r2/python",
          f"{REPO}/phase1i-r3/python"):
    if p not in sys.path:
        sys.path.insert(0, p)

from run_j_attacks import (EXEC_CLIENT_D, PROG0,  # noqa: E402
                           fixture_cfg, fixture_catalog, fresh_machine,
                           build_chain, jblocks, state_root, payload_digest)

RESULTS = []


def check(name, expected, got, detail=""):
    ok = expected == got
    RESULTS.append((name, ok, detail))
    print(f"{'PASS' if ok else 'FAIL'}  {name}" + (f"  [{detail}]" if detail and not ok else ""))
    return ok


def snapshot(m):
    return (dict(m.state), m.head, m.lin_head, m.next_slot, m.anchor,
            len(m.exec_receipts), len(m.gate_receipts))


def main() -> int:
    import copy
    cfg = fixture_cfg()
    cat = fixture_catalog()
    anchor = cfg and __import__("j_model").ProtoRootR3(cfg)

    # the initialized machine with a live exec receipt (the mint-ready shape)
    m = fresh_machine(anchor)
    assert m.init(cfg, cat), "fixture init must succeed"
    chain = build_chain()
    blocks = jblocks(chain, cfg, cat)
    b0 = blocks[0]
    ok_e = m.exec(EXEC_CLIENT_D, PROG0, None, 0)
    assert ok_e[0], "authorized exec must mint"
    e0 = m.exec_receipts[-1]
    snap = snapshot(m)

    # ---- the unmet-precondition classes (the M3 jrefusedGate() classes) ----
    import dataclasses
    # 1. the wrong-slot block (the CONCRETE K witness class: slot 7 vs 5)
    b_slot = dataclasses.replace(b0, slot=7) if dataclasses.is_dataclass(b0) else b0
    r1 = m.gate_eval(b_slot, chain["ctx0"], chain["rg0"], chain["c0"],
                     state_root(e0.post), payload_digest(PROG0))
    check("C1 wrong-slot block -> None (the explicit-refusal class)",
          None, r1)
    check("C2 wrong-slot: no movement", snap, snapshot(m))

    # 2. the wrong-parent block
    b_par = dataclasses.replace(b0, parent_commit=b"\x99" * 32)
    r2 = m.gate_eval(b_par, chain["ctx0"], chain["rg0"], chain["c0"],
                     state_root(e0.post), payload_digest(PROG0))
    check("C3 wrong-parent block -> None", None, r2)
    check("C4 wrong-parent: no movement", snap, snapshot(m))

    # 3. the no-matching-exec-receipt class: the record's trace digest is
    #    the receipt-matching key (exec_receipt_matches_record_j:
    #    e.trace_d == rg.base.eff_trace_d) — mutate THAT field
    rg_bad = copy.deepcopy(chain["rg0"])
    bad_trace = bytes([rg_bad.base.eff_trace_d[0] ^ 0xFF]) \
        + rg_bad.base.eff_trace_d[1:]
    object.__setattr__(rg_bad.base, "eff_trace_d", bad_trace)
    assert m.exec_receipts[-1].trace_d != rg_bad.base.eff_trace_d
    r3 = m.gate_eval(b0, chain["ctx0"], rg_bad, chain["c0"],
                     state_root(e0.post), payload_digest(PROG0))
    check("C5 non-matching record -> None", None, r3)
    check("C6 non-matching record: no movement", snap, snapshot(m))

    # 4. the uninitialized machine
    m0 = fresh_machine(anchor)
    snap0 = snapshot(m0)
    r4 = m0.gate_eval(b0, chain["ctx0"], chain["rg0"], chain["c0"],
                      state_root(e0.post), payload_digest(PROG0))
    check("C7 uninitialized -> None", None, r4)
    check("C8 uninitialized: no movement", snap0, snapshot(m0))

    # ---- the accept control (the mint path agrees) --------------------------
    g = m.gate_eval(b0, chain["ctx0"], chain["rg0"], chain["c0"],
                    state_root(e0.post), payload_digest(PROG0))
    check("C9 the honest record still MINTS", True, g is not None)
    check("C10 the mint is the only pool movement",
          1, len(m.gate_receipts))

    npass = sum(1 for _, ok, _ in RESULTS if ok)
    nfail = len(RESULTS) - npass
    print(f"\nMC mirror crosscheck: {npass} PASS / {nfail} FAIL (of {len(RESULTS)})")
    print("CROSS-LAYER AGREEMENT: "
          + ("YES — the mirror returns None with NO movement on every "
             "unmet-precondition class (the M3 jrefusedGate() classes) and "
             "mints on the honest class (the M3 mint branch agrees)"
             if nfail == 0 else "NO"))
    return 0 if nfail == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
