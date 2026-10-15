#!/usr/bin/env python3
"""SRW3 Phase 1F — hostile mutation harness (authorized-dishonest producer).

Every mutation re-signs and re-digests everything the producer CAN forge;
the expected result is rejection at the documented first-fail layer. The
two ACCEPT-marked cases are documented boundaries (not defects): the
cross-slot order swap (fragment: order-insensitive obligations, order still
digest-bound) and the fully-consistent forgery reaching the anchor layer
(the Level-2 catch — the A-F3 boundary at the abstract layer).
"""
from __future__ import annotations

import copy
import sys

sys.path.insert(0, "/home/z/my-project/srw3-kevm/python-gen")
sys.path.insert(0, "/home/z/my-project/srw3-kevm/phase1e/python")
sys.path.insert(0, "/home/z/my-project/srw3-kevm/phase1f/python")

import test_exec_verify as T  # noqa: E402
from exec_model import (ExEvt, ExecCtx, ExecWit, OP_READ, OP_WRITE,
                        SCHED_CANCUN, SPEC_V1, build_rec_f, trace_digest,
                        verify_lineage_f, wit_digest)  # noqa: E402
from test_exec_verify import (CF0, CF1, E2, P2, PLD2, Q2, ROOT, SR0, SR1, SR2,
                              T1, T2, _wit, wctx2)  # noqa: E402


def _ctx(pre, eff, post, anchor, parent_root, trace, wit):
    from test_exec_verify import CALLER
    from auth_verify import AuthCtxA
    from lin_verify import LinCtx
    from test_exec_verify import AUTH, REG
    return ExecCtx(AuthCtxA(LinCtx(pre, eff, post, REG, AUTH), anchor),
                   parent_root, PLD2, SCHED_CANCUN, SPEC_V1, CALLER, 0,
                   trace, wit)


def run() -> int:
    cases = []

    # m01: trace digest byte-flip in the record (naive tamper)
    rf = T.R2F
    bad = bytes([rf.eff_trace_d[0] ^ 1]) + rf.eff_trace_d[1:]
    rf1 = rf.__class__(rf.base, rf.exec_id, bad, rf.exec_wd, rf.exec_cfg_d)
    cases.append(("m01 traced byte-flip", verify_lineage_f(
        rf1, _ctx(T.Q2, E2, P2, SR2, SR1, T2, T._wit(SR1, PLD2, E2, T2, SR2)),
        2, CF1), "L19-EFFTRACE"))

    # m02: execution id byte-flip (naive tamper)
    bad = bytes([rf.exec_id[0] ^ 1]) + rf.exec_id[1:]
    rf2 = rf.__class__(rf.base, bad, rf.eff_trace_d, rf.exec_wd, rf.exec_cfg_d)
    cases.append(("m02 execid byte-flip", verify_lineage_f(
        rf2, _ctx(T.Q2, E2, P2, SR2, SR1, T2, T._wit(SR1, PLD2, E2, T2, SR2)),
        2, CF1), "L18-EXECID"))

    # m03: witness version bumped
    w = T._wit(SR1, PLD2, E2, T2, SR2)
    w3 = ExecWit(2, w.parent_root, w.exec_id, w.payload_d, w.declared_d,
                 w.trace_d, w.post_root, w.config_d)
    cases.append(("m03 witness version", verify_lineage_f(
        T.R2F, _ctx(T.Q2, E2, P2, SR2, SR1, T2, w3), 2, CF1), "L21-WITNESS"))

    # m04: witness parent root stale
    w4 = ExecWit(1, SR0, w.exec_id, w.payload_d, w.declared_d,
                 w.trace_d, w.post_root, w.config_d)
    cases.append(("m04 witness parent stale", verify_lineage_f(
        T.R2F, _ctx(T.Q2, E2, P2, SR2, SR1, T2, w4), 2, CF1), "L21-WITNESS"))

    # m05: witness post root foreign
    w5 = ExecWit(1, w.parent_root, w.exec_id, w.payload_d, w.declared_d,
                 w.trace_d, SR1, w.config_d)
    cases.append(("m05 witness post root", verify_lineage_f(
        T.R2F, _ctx(T.Q2, E2, P2, SR2, SR1, T2, w5), 2, CF1), "L21-WITNESS"))

    # m06: witness declared digest foreign (E1's)
    w6 = ExecWit(1, w.parent_root, w.exec_id, w.payload_d,
                 T.H_kv(T.E1), w.trace_d, w.post_root, w.config_d)
    cases.append(("m06 witness declared foreign", verify_lineage_f(
        T.R2F, _ctx(T.Q2, E2, P2, SR2, SR1, T2, w6), 2, CF1), "L21-WITNESS"))

    # m07: declared effects enriched (extra (LIQ,9):=999 in ctx only)
    eff7 = {k: dict(v) for k, v in E2.items()}
    eff7[4099] = dict(eff7[4099]); eff7[4099][9] = 999
    cases.append(("m07 declared enriched", verify_lineage_f(
        T.R2F, _ctx(T.Q2, eff7, P2, SR2, SR1, T2, T._wit(SR1, PLD2, E2, T2, SR2)),
        2, CF1), "L6-EFFECTDIGEST"))

    # m08: trace drops the LAST write, record RE-BOUND to the truncated
    # trace (the producer forges everything rebindable) — the declared
    # check fires: E2 != Writes(T2[:-1])
    r8 = build_rec_f(2, CF1, T.Q2, E2, P2, T.SK1, 5, T2[:-1], T.PLD2,
                     SCHED_CANCUN, SPEC_V1, T.CALLER, 0, SR1)
    cases.append(("m08 trace drop last write", verify_lineage_f(
        r8, _ctx(T.Q2, E2, P2, SR2, SR1, T2[:-1],
                 T._wit(SR1, PLD2, E2, T2[:-1], SR2)), 2, CF1),
        "L20-EFFDECL"))

    # m09: trace write value tampered, record re-bound — declared check
    t9 = T2.copy(); t9[5] = ExEvt(OP_WRITE, T.LENDING, 1, 7)
    r9 = build_rec_f(2, CF1, T.Q2, E2, P2, T.SK1, 5, t9, T.PLD2,
                     SCHED_CANCUN, SPEC_V1, T.CALLER, 0, SR1)
    cases.append(("m09 write value tampered", verify_lineage_f(
        r9, _ctx(T.Q2, E2, P2, SR2, SR1, t9,
                 T._wit(SR1, PLD2, E2, t9, SR2)), 2, CF1),
        "L20-EFFDECL"))

    # m10: payload replaced (record honest, context payload swapped)
    ctx10 = T.wctx2()
    from dataclasses import replace
    cases.append(("m10 context payload swapped", verify_lineage_f(
        T.R2F, replace(ctx10, payload=T.PLD1), 2, CF1), "L18-EXECID"))

    # m11: caller replaced (env substitution -> different execution id)
    cases.append(("m11 caller replaced", verify_lineage_f(
        T.R2F, replace(ctx10, caller=T.addr_of((78).to_bytes(32, "big"))),
        2, CF1), "L18-EXECID"))

    # m12: spec replaced in the context only
    cases.append(("m12 context spec replaced", verify_lineage_f(
        T.R2F, replace(ctx10, spec=2), 2, CF1), "L17-EXECCONFIG"))

    # m13: anchor replaced with the parent's (stale anchor; L2 first)
    cases.append(("m13 stale anchor", verify_lineage_f(
        T.R2F, replace(ctx10, ctxa=replace(ctx10.ctxa, anchor=SR1)),
        2, CF1), "L14-ANCHOR"))

    # BOUNDARY b01 (documented, NOT a defect): cross-slot order swap accepted
    cases.append(("b01 cross-slot order (BOUNDARY)", verify_lineage_f(
        T.R3xF, T.nctx3x(), 2, CF1), "VALID-F"))

    # BOUNDARY b02 (documented): fully-consistent hidden-write forgery is
    # caught by the ANCHOR (Level 2), not by Level-3 — the abstract layer's
    # A-F3 boundary (KEVM closes it by execution-derived traces)
    effb = {T.LIQ: {0: 100}, T.LENDING: {1: 0, 9: 999}}
    postb = {T.ORACLE: {0: 100}, T.LENDING: {0: 100, 1: 0, 9: 999},
             T.LIQ: {0: 100}}
    tb = T2 + [ExEvt(OP_WRITE, T.LENDING, 9, 999)]
    rb = build_rec_f(2, CF1, T.Q2, effb, postb, T.SK1, 5, tb, T.PLD2,
                     SCHED_CANCUN, SPEC_V1, T.CALLER, 0, SR1)
    from auth_model import auth_root, canon_union
    srb = auth_root(canon_union(T.Q2, effb, postb), postb)
    cases.append(("b02 hidden write fully re-forged (L2 catch)", verify_lineage_f(
        rb, _ctx(T.Q2, effb, postb, SR2, SR1, tb,
                 T._wit(SR1, PLD2, effb, tb, srb)), 2, CF1), "L14-ANCHOR"))

    npass = 0
    for name, got, expect in cases:
        ok = got == expect
        npass += ok
        print(f"[{name}] first-fail={got} expect={expect} "
              f"{'OK' if ok else '*** FAIL ***'}")
    print(f"\n=== PHASE 1F MUTATIONS: {npass}/{len(cases)} as expected "
          f"(b01/b02 are documented boundaries) ===")
    return 0 if npass == len(cases) else 1


if __name__ == "__main__":
    raise SystemExit(run())
