#!/usr/bin/env python3
# =============================================================================
# SRW3 Phase 1M — Workstream A: the M1 cross-layer Python mirror check.
#
# The M1 repair makes the K machine agree with the Python mirror on the
# unauthorized-source refusal: the mirror (j_model.py, UNCHANGED frozen
# code) emits (False, REFUSE_SOURCE) with NO receipt and NO committed
# movement on EVERY initialized shape; the repaired K machine now does the
# same (claims M1-EXEC-DISPATCH-SOURCE / -SINGLE-ENTRY / -SOURCE-NOCOMMIT).
#
# 8 checks over BOTH fully-pinned shapes:
#   A: initialized, empty lineage (the pins only);
#   B: fully-pinned with a committed block + a non-empty exec pool
#      (the frozen L-FINDING-1 stuck shape).
#   1-3: A unauthorized source -> (False, ('source',)), no receipt, no
#        movement (state/head/lin_head/next_slot/anchor byte-equal);
#   4-6: B unauthorized source -> same three properties;
#   7-8: the authorized source still mints on A and on B (no over-tightening).
#
# The transcript is the audit evidence.  CROSS-LAYER AGREEMENT: the mirror
# results correspond 1:1 to the M1 K claims (the dispatch partition is the
# mirror's if/if/if structure).
# =============================================================================
import json
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

from run_j_attacks import (EXEC_CLIENT_D, CALLER, PROG0, PROG1,  # noqa: E402
                           fixture_cfg, fixture_catalog, fresh_machine,
                           build_chain, jblocks, state_root, payload_digest)
from j_model import safe_j  # noqa: E402

RESULTS = []


def check(name, expected, got, detail=""):
    ok = expected == got
    RESULTS.append((name, ok, detail))
    print(f"{'PASS' if ok else 'FAIL'}  {name}" + (f"  [{detail}]" if detail and not ok else ""))
    return ok


def snapshot(m):
    return (dict(m.state), m.head, m.lin_head, m.next_slot, m.anchor,
            len(m.exec_receipts), len(m.gate_receipts))


BAD_SRC = b"\x11" * 32  # NOT the pinned execution-client identity


def main() -> int:
    cfg = fixture_cfg()
    cat = fixture_catalog()
    anchor = cfg and __import__("j_model").ProtoRootR3(cfg)

    # ---- shape A: initialized, empty lineage --------------------------------
    mA = fresh_machine(anchor)
    assert mA.init(cfg, cat), "fixture init must succeed"

    snapA = snapshot(mA)
    rA = mA.exec(BAD_SRC, PROG0, CALLER, 0)
    check("A1 unauthorized source -> (False, ('source',))",
          (False, ("source",)), rA)
    check("A2 no receipt minted", 0, len(mA.exec_receipts))
    check("A3 no movement (state/head/linhead/slot/anchor/pools)",
          snapA, snapshot(mA))

    # authorized source still mints on A (no over-tightening)
    rAok = mA.exec(EXEC_CLIENT_D, PROG0, CALLER, 0)
    check("A4 authorized source still mints", True, rAok[0])
    assert len(mA.exec_receipts) == 1

    # ---- shape B: fully-pinned + committed block (the stuck shape) ----------
    mB = fresh_machine(anchor)
    assert mB.init(cfg, cat)
    chain = build_chain()
    blocks = jblocks(chain, cfg, cat)
    b0 = blocks[0]
    ok_e = mB.exec(EXEC_CLIENT_D, PROG0, CALLER, 0)
    assert ok_e[0], "authorized exec must mint on B's path"
    e0 = mB.exec_receipts[-1]
    g = mB.gate_eval(b0, chain["ctx0"], chain["rg0"], chain["c0"],
                     state_root(e0.post), payload_digest(PROG0))
    assert g is not None, "gate eval must accept the honest record"
    okc = mB.commit(b0, state_root(e0.post), payload_digest(PROG0), 1)
    assert okc, "honest commit must succeed"
    # the honest pipeline CONSUMES both receipts (single-use); the committed
    # block is in the lineage — the fully-pinned shape
    assert len(mB.lineage) == 1 and len(mB.exec_receipts) == 0

    snapB = snapshot(mB)
    rB = mB.exec(BAD_SRC, PROG1, CALLER, 0)
    check("B1 unauthorized source -> (False, ('source',))",
          (False, ("source",)), rB)
    check("B2 no receipt minted", 0, len(mB.exec_receipts))
    check("B3 no movement (state/head/linhead/slot/anchor/pools)",
          snapB, snapshot(mB))

    # authorized source still mints on B (no over-tightening)
    rBok = mB.exec(EXEC_CLIENT_D, PROG1, CALLER, 0)
    check("B4 authorized source still mints", True, rBok[0])

    npass = sum(1 for _, ok, _ in RESULTS if ok)
    nfail = len(RESULTS) - npass
    print(f"\nM1 mirror crosscheck: {npass} PASS / {nfail} FAIL (of {len(RESULTS)})")
    print("CROSS-LAYER AGREEMENT: "
          + ("YES — the mirror's refusal on both fully-pinned shapes, no "
             "receipt, no movement; authorized sources still mint (the M1 "
             "K claims agree 1:1)" if nfail == 0 else "NO"))
    return 0 if nfail == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
