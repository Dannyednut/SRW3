#!/usr/bin/env python3
"""SRW3 Phase 1F — permanent Python adversarial suite.

Mirrors the K demo suite (phase1f/semantics/srw3exec-demo.k) case-for-case,
plus the cross-layer byte certificate against the K (llvm, real krypto)
values recorded in transcripts/part4_xbytes_raw.txt.

Cases:
  pos0/pos1/pos2  honest Oracle->Lending->Liquidator LinRecF chain -> VALID-F
  f8a/f8b/f8diff  equal final state, divergent traces: both VALID-F, digests differ
  neg1  (F1) hidden write in trace, declared unchanged ....... L20-EFFDECL
  neg2  (F2) read suppressed, digest covers full trace ....... L19-EFFTRACE
  neg3  (F4) same-slot reorder, value changed, coherently re-forged -> L14-ANCHOR
  neg3x (F4) cross-slot reorder, same map .................... VALID-F (boundary)
  neg3xdiff  cross-slot trace digest differs from the honest record's
  neg4  (F5) stale parent root replay ........................ L18-EXECID
  neg5  (F6) fork-spec replaced .............................. L17-EXECCONFIG
  neg6  (F7) witness bound to foreign trace digest ........... L21-WITNESS
  neg7  fragment bounds refuse (app = 2^32) .................. L16-EXECBOUNDS
  neg8  (F2 residual) false read observation ................. L22-EFFBIND
"""
from __future__ import annotations

import sys

sys.path.insert(0, "/home/z/my-project/srw3-kevm/python-gen")
sys.path.insert(0, "/home/z/my-project/srw3-kevm/phase1e/python")
sys.path.insert(0, "/home/z/my-project/srw3-kevm/phase1f/python")

from lin_verify import LinCtx, addr_of, canon_kv  # noqa: E402
from auth_verify import AuthCtxA  # noqa: E402
from auth_model import auth_root, canon_union  # noqa: E402
from exec_model import (ExEvt, ExecCtx, ExecWit, OP_READ, OP_WRITE,
                        SCHED_CANCUN, SPEC_V1, build_rec_e_wrap, build_rec_f,
                        canon_trace, child_f, config_digest, env_digest,
                        exec_id, payload_digest, trace_digest, trace_writes,
                        verify_lineage_f, wit_digest)  # noqa: E402

SK1 = (77).to_bytes(32, "big")
ROOT = b"\x00" * 32
CALLER = addr_of(SK1)

ORACLE, LENDING, LIQ = 4097, 4098, 4099

# ---- shared context ----------------------------------------------------------
REG = (5, 6)
AUTH = (addr_of(SK1),)


def ctx_of(pre, eff, post, anchor) -> AuthCtxA:
    return AuthCtxA(LinCtx(pre, eff, post, REG, AUTH), anchor)


# ---- R0: oracle update --------------------------------------------------------
Q0 = {ORACLE: {0: 0}}
E0 = {ORACLE: {0: 100}}
P0 = {ORACLE: {0: 100}}                       # independent post
T0 = [ExEvt(OP_WRITE, ORACLE, 0, 100)]
PLD0 = bytes.fromhex("4f5241434c4531")        # "ORACLE1"

SR0 = auth_root(canon_union(Q0, E0, P0), P0)


def _recf0():
    return build_rec_f(0, ROOT, Q0, E0, P0, SK1, 5, T0, PLD0,
                       SCHED_CANCUN, SPEC_V1, CALLER, 0, ROOT)


R0F = _recf0()
CF0 = child_f(R0F)


def wctx0() -> ExecCtx:
    return ExecCtx(ctx_of(Q0, E0, P0, SR0), ROOT, PLD0, SCHED_CANCUN,
                   SPEC_V1, CALLER, 0, T0, _wit(ROOT, PLD0, E0, T0, SR0))


def _wit(parent_root, pld, declared, trace, post_root, spec=SPEC_V1):
    """Witness computed exactly as the honest construction does."""
    eid = exec_id(parent_root, payload_digest(pld),
                  config_digest(SCHED_CANCUN, spec), env_digest(CALLER, 0))
    return ExecWit(1, parent_root, eid, payload_digest(pld),
                   H_kv(declared), trace_digest(trace), post_root,
                   config_digest(SCHED_CANCUN, spec))


def H_kv(m):
    from lin_verify import H
    return H(canon_kv(m))


# ---- R1: lending borrow --------------------------------------------------------
Q1 = {ORACLE: {0: 100}, LENDING: {0: 0, 1: 0}}
E1 = {LENDING: {0: 100, 1: 100}}
P1 = {ORACLE: {0: 100}, LENDING: {0: 100, 1: 100}}
T1 = [ExEvt(OP_READ, ORACLE, 0, 100),
      ExEvt(OP_WRITE, LENDING, 0, 100),
      ExEvt(OP_WRITE, LENDING, 1, 100)]
PLD1 = bytes.fromhex("424f52524f5731")        # "BORROW1"

SR1 = auth_root(canon_union(Q1, E1, P1), P1)
R1F = build_rec_f(1, CF0, Q1, E1, P1, SK1, 5, T1, PLD1,
                  SCHED_CANCUN, SPEC_V1, CALLER, 0, SR0)
CF1 = child_f(R1F)


def wctx1() -> ExecCtx:
    return ExecCtx(ctx_of(Q1, E1, P1, SR1), SR0, PLD1, SCHED_CANCUN,
                   SPEC_V1, CALLER, 0, T1, _wit(SR0, PLD1, E1, T1, SR1))


# ---- R2: liquidation ------------------------------------------------------------
Q2 = {ORACLE: {0: 100}, LENDING: {0: 100, 1: 100}, LIQ: {0: 0}}  # = P1 + fresh liquidator
E2 = {LIQ: {0: 100}, LENDING: {1: 0}}
P2 = {ORACLE: {0: 100}, LENDING: {0: 100, 1: 0}, LIQ: {0: 100}}
T2 = [ExEvt(OP_READ, LENDING, 0, 100),
      ExEvt(OP_READ, LENDING, 1, 100),
      ExEvt(OP_READ, ORACLE, 0, 100),
      ExEvt(OP_WRITE, LIQ, 0, 100),
      ExEvt(OP_WRITE, LENDING, 1, 50),
      ExEvt(OP_WRITE, LENDING, 1, 0)]
PLD2 = bytes.fromhex("4c495155494441544531")  # "LIQUIDATE1"

SR2 = auth_root(canon_union(Q2, E2, P2), P2)
R2F = build_rec_f(2, CF1, Q2, E2, P2, SK1, 5, T2, PLD2,
                  SCHED_CANCUN, SPEC_V1, CALLER, 0, SR1)


def wctx2() -> ExecCtx:
    return ExecCtx(ctx_of(Q2, E2, P2, SR2), SR1, PLD2, SCHED_CANCUN,
                   SPEC_V1, CALLER, 0, T2, _wit(SR1, PLD2, E2, T2, SR2))


# ---- f8: equal final state, divergent trace --------------------------------------
T2alt = T2 + [ExEvt(OP_READ, ORACLE, 0, 100)]
R2altF = build_rec_f(2, CF1, Q2, E2, P2, SK1, 5, T2alt, PLD2,
                     SCHED_CANCUN, SPEC_V1, CALLER, 0, SR1)


def wctx2alt() -> ExecCtx:
    return ExecCtx(ctx_of(Q2, E2, P2, SR2), SR1, PLD2, SCHED_CANCUN,
                   SPEC_V1, CALLER, 0, T2alt, _wit(SR1, PLD2, E2, T2alt, SR2))


# ---- negatives ---------------------------------------------------------------------
# neg1 (F1): hidden write in the trace, declared effects unchanged
T1hidden = T1 + [ExEvt(OP_WRITE, LENDING, 9, 999)]
R1hF = build_rec_f(1, CF0, Q1, E1, P1, SK1, 5, T1hidden, PLD1,
                   SCHED_CANCUN, SPEC_V1, CALLER, 0, SR0)


def nctx1() -> ExecCtx:
    return ExecCtx(ctx_of(Q1, E1, P1, SR1), SR0, PLD1, SCHED_CANCUN,
                   SPEC_V1, CALLER, 0, T1hidden,
                   _wit(SR0, PLD1, E1, T1hidden, SR1))


# neg2 (F2): read suppressed from the presented trace; record keeps the full digest
T1minus = T1[1:]


def nctx2() -> ExecCtx:
    return ExecCtx(ctx_of(Q1, E1, P1, SR1), SR0, PLD1, SCHED_CANCUN,
                   SPEC_V1, CALLER, 0, T1minus, _wit(SR0, PLD1, E1, T1, SR1))


# neg3 (F4): same-slot reorder with value change, fully re-forged presentation
T2swap = [ExEvt(OP_READ, LENDING, 0, 100),
          ExEvt(OP_READ, LENDING, 1, 100),
          ExEvt(OP_READ, ORACLE, 0, 100),
          ExEvt(OP_WRITE, LIQ, 0, 100),
          ExEvt(OP_WRITE, LENDING, 1, 0),
          ExEvt(OP_WRITE, LENDING, 1, 50)]
E2s = {LIQ: {0: 100}, LENDING: {1: 50}}
P2s = {ORACLE: {0: 100}, LENDING: {0: 100, 1: 50}, LIQ: {0: 100}}
R3F = build_rec_f(2, CF1, Q2, E2s, P2s, SK1, 5, T2swap, PLD2,
                  SCHED_CANCUN, SPEC_V1, CALLER, 0, SR1)


def nctx3() -> ExecCtx:
    sr3 = auth_root(canon_union(Q2, E2s, P2s), P2s)
    return ExecCtx(ctx_of(Q2, E2s, P2s, SR2), SR1, PLD2, SCHED_CANCUN,
                   SPEC_V1, CALLER, 0, T2swap, _wit(SR1, PLD2, E2s, T2swap, sr3))


# neg3x (F4 cross-slot): order swapped, same final map, same declared effects
T2x = [ExEvt(OP_READ, LENDING, 0, 100),
       ExEvt(OP_READ, LENDING, 1, 100),
       ExEvt(OP_READ, ORACLE, 0, 100),
       ExEvt(OP_WRITE, LENDING, 1, 50),
       ExEvt(OP_WRITE, LIQ, 0, 100),
       ExEvt(OP_WRITE, LENDING, 1, 0)]
R3xF = build_rec_f(2, CF1, Q2, E2, P2, SK1, 5, T2x, PLD2,
                   SCHED_CANCUN, SPEC_V1, CALLER, 0, SR1)


def nctx3x() -> ExecCtx:
    return ExecCtx(ctx_of(Q2, E2, P2, SR2), SR1, PLD2, SCHED_CANCUN,
                   SPEC_V1, CALLER, 0, T2x, _wit(SR1, PLD2, E2, T2x, SR2))


# neg4 (F5): stale parent root replay (record + witness built on SR0)
R4F = build_rec_f(2, CF1, Q2, E2, P2, SK1, 5, T2, PLD2,
                  SCHED_CANCUN, SPEC_V1, CALLER, 0, SR0)


def nctx4() -> ExecCtx:
    return ExecCtx(ctx_of(Q2, E2, P2, SR2), SR1, PLD2, SCHED_CANCUN,
                   SPEC_V1, CALLER, 0, T2, _wit(SR0, PLD2, E2, T2, SR2))


# neg5 (F6): fork-spec replacement (spec 2 in record/witness, 1 in context)
R5F = build_rec_f(2, CF1, Q2, E2, P2, SK1, 5, T2, PLD2,
                  SCHED_CANCUN, 2, CALLER, 0, SR1)


def nctx5() -> ExecCtx:
    return ExecCtx(ctx_of(Q2, E2, P2, SR2), SR1, PLD2, SCHED_CANCUN,
                   SPEC_V1, CALLER, 0, T2, _wit(SR1, PLD2, E2, T2, SR2, spec=2))


# neg6 (F7): witness bound to a foreign trace digest (R1's trace)
def nctx6() -> ExecCtx:
    return ExecCtx(ctx_of(Q2, E2, P2, SR2), SR1, PLD2, SCHED_CANCUN,
                   SPEC_V1, CALLER, 0, T2, _wit(SR1, PLD2, E2, T1, SR2))


# neg7: fragment bounds refuse
Tb = [ExEvt(OP_WRITE, 2 ** 32, 0, 1)]
Qb, Eb, Pb = {ORACLE: {0: 0}}, {ORACLE: {0: 1}}, {ORACLE: {0: 1}}
R7F = build_rec_f(0, ROOT, Qb, Eb, Pb, SK1, 5, Tb, PLD0,
                  SCHED_CANCUN, SPEC_V1, CALLER, 0, ROOT)


def nctx7() -> ExecCtx:
    srb = auth_root(canon_union(Qb, Eb, Pb), Pb)
    return ExecCtx(ctx_of(Qb, Eb, Pb, srb), ROOT, PLD0, SCHED_CANCUN,
                   SPEC_V1, CALLER, 0, Tb, _wit(ROOT, PLD0, Eb, Tb, srb))


# neg8 (F2 residual): false read observation, everything else coherent
T2false = [ExEvt(OP_READ, LENDING, 0, 100),
           ExEvt(OP_READ, LENDING, 1, 100),
           ExEvt(OP_READ, ORACLE, 0, 7),
           ExEvt(OP_WRITE, LIQ, 0, 100),
           ExEvt(OP_WRITE, LENDING, 1, 50),
           ExEvt(OP_WRITE, LENDING, 1, 0)]
R8F = build_rec_f(2, CF1, Q2, E2, P2, SK1, 5, T2false, PLD2,
                  SCHED_CANCUN, SPEC_V1, CALLER, 0, SR1)


def nctx8() -> ExecCtx:
    return ExecCtx(ctx_of(Q2, E2, P2, SR2), SR1, PLD2, SCHED_CANCUN,
                   SPEC_V1, CALLER, 0, T2false, _wit(SR1, PLD2, E2, T2false, SR2))


# =============================================================================
# suite
# =============================================================================

def main() -> int:
    cases = [
        ("pos0", verify_lineage_f(R0F, wctx0(), 0, ROOT), "VALID-F"),
        ("pos1", verify_lineage_f(R1F, wctx1(), 1, CF0), "VALID-F"),
        ("pos2", verify_lineage_f(R2F, wctx2(), 2, CF1), "VALID-F"),
        ("f8a", verify_lineage_f(R2F, wctx2(), 2, CF1), "VALID-F"),
        ("f8b", verify_lineage_f(R2altF, wctx2alt(), 2, CF1), "VALID-F"),
        ("f8diff", str(R2F.eff_trace_d != R2altF.eff_trace_d), "True"),
        ("neg1", verify_lineage_f(R1hF, nctx1(), 1, CF0), "L20-EFFDECL"),
        ("neg2", verify_lineage_f(R1F, nctx2(), 1, CF0), "L19-EFFTRACE"),
        ("neg3", verify_lineage_f(R3F, nctx3(), 2, CF1), "L14-ANCHOR"),
        ("neg3x", verify_lineage_f(R3xF, nctx3x(), 2, CF1), "VALID-F"),
        ("neg3xdiff", str(R2F.eff_trace_d != R3xF.eff_trace_d), "True"),
        ("neg4", verify_lineage_f(R4F, nctx4(), 2, CF1), "L18-EXECID"),
        ("neg5", verify_lineage_f(R5F, nctx5(), 2, CF1), "L17-EXECCONFIG"),
        ("neg6", verify_lineage_f(R2F, nctx6(), 2, CF1), "L21-WITNESS"),
        ("neg7", verify_lineage_f(R7F, nctx7(), 0, ROOT), "L16-EXECBOUNDS"),
        ("neg8", verify_lineage_f(R8F, nctx8(), 2, CF1), "L22-EFFBIND"),
    ]
    npass = 0
    for name, got, expect in cases:
        ok = got == expect
        npass += ok
        print(f"[{name}] verdict={got} expect={expect} "
              f"{'PASS' if ok else '*** FAIL ***'}")

    # cross-layer byte certificate vs the K (llvm, real krypto) values
    print("\n--- cross-layer bytes (Python == K/llvm values from Part 4) ---")
    kvals = {
        "trace0": "0300000001020000100100000000000000000000000000000064",
        "execid0": "c16e1bb5a8b54d3eb04482863d04498a2b17fef9f888009655ba586efea85366",
        "childf0": "cc07b327ee7c659a7fd2f4bb12fcef206cd92397e36a50894091504171dfc6be",
    }
    pvals = {
        "trace0": canon_trace(T0).hex(),
        "execid0": R0F.exec_id.hex(),
        "childf0": child_f(R0F).hex(),
    }
    nbyte = 0
    for k, kv in kvals.items():
        pv = pvals[k]
        ok = pv == kv
        nbyte += ok
        print(f"[bytes:{k}] python={pv} k={kv} "
              f"{'MATCH' if ok else '*** MISMATCH ***'}")

    total = len(cases) + len(kvals)
    print(f"\n=== PHASE 1F PYTHON SUITE: {npass}/{len(cases)} verdict cases PASS;"
          f" {nbyte}/{len(kvals)} byte checks MATCH ===")
    return 0 if (npass == len(cases) and nbyte == len(kvals)) else 1


if __name__ == "__main__":
    raise SystemExit(main())
