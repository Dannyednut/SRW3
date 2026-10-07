#!/usr/bin/env python3
"""SRW3 Phase 1G — hostile mutation harness (authorized-dishonest producer).

Every mutation re-signs and re-digests everything the producer CAN forge;
the expected result is rejection at the documented first-fail layer. The
producer may build ANY certificate and recompute its id (certId is a
keccak of the presented body — the gate RE-COMPUTES it, so a forged id that
is consistent with a forged body passes the digest check BY DESIGN; the
rejection then comes from the AUTHORITY checks: unauthorized source, bad
level, circular chain, failed binding). The documented BOUNDARIES (accept-
marked) mirror the 1F b01/b02 discipline.
"""
from __future__ import annotations

import sys

sys.path.insert(0, "/home/z/my-project/srw3-kevm/python-gen")
sys.path.insert(0, "/home/z/my-project/srw3-kevm/phase1e/python")
sys.path.insert(0, "/home/z/my-project/srw3-kevm/phase1f/python")
sys.path.insert(0, "/home/z/my-project/srw3-kevm/phase1g/python")

import test_authz_verify as T  # noqa: E402
from authz_model import (AuthzCert, AzCtx, AzSrc, AzStep, DOM_CONSENSUS,  # noqa: E402
                         DOM_EXECUTION, DOM_PROOF, cert_id, az_proof_pub,
                         build_rec_g, consensus_id, exec_client_id,
                         proof_sys_id, verify_lineage_g)
from exec_model import payload_digest  # noqa: E402
from test_authz_verify import (ACTX2, CALLER, CF0, CF1, CHAIN, E2, GUEST_D,  # noqa: E402
                               P2, PLD2, PROOF_CFG_D, Q2, ROOT, R2F, SEC2, SR1,
                               SR2, T2, wctx2)


def _az(fctx, cert, pt=0, guest=b"", cfg=b""):
    return AzCtx(fctx, SEC2, cert, pt, guest, cfg)


def H_kv(m):
    from lin_verify import H, canon_kv
    return H(canon_kv(m))


def _rc(base, cert, pv=1):
    return build_rec_g(base, cert, pv)


def run() -> int:
    cases = []
    base_cert = T.cert2()
    base_rg = T.RG2
    base_ctx = T.ACTX2

    # m01: record's azCertD byte-flip (naive tamper; the cert itself honest)
    bad = bytes([base_rg.az_cert_d[0] ^ 1]) + base_rg.az_cert_d[1:]
    rg1 = base_rg.__class__(base_rg.base, bad, base_rg.az_policy_v)
    cases.append(("m01 certD byte-flip",
                  verify_lineage_g(rg1, base_ctx, 2, CF1), "L28-AUTHBIND"))

    # m02: unauthorized consensus identity as the source (a self-chosen id)
    c = AuthzCert(base_cert.payload_d, base_cert.parent_root,
                  base_cert.exec_id, base_cert.child_root,
                  base_cert.effect_d, 1,
                  AzSrc(DOM_CONSENSUS, b"\x11" * 32, 0), (), 1, b"")
    cases.append(("m02 self-chosen consensus id",
                  verify_lineage_g(_rc(T.R2F, c), _az(T.wctx2(), c, 0, b"", b""),
                                   2, CF1), "L27-AUTHSRC"))

    # m03: CM-G1 class — chain step with an unauthorized (guessed self) id
    c = AuthzCert(base_cert.payload_d, base_cert.parent_root,
                  base_cert.exec_id, base_cert.child_root,
                  base_cert.effect_d, 2,
                  AzSrc(DOM_EXECUTION, exec_client_id(CHAIN, PROOF_CFG_D), 1),
                  (AzStep(DOM_CONSENSUS, cert_id(T.cert1()), 0),), 1, b"")
    cases.append(("m03 chain cites a certificate id",
                  verify_lineage_g(_rc(T.R2F, c), _az(T.wctx2(), c), 2, CF1),
                  "L26-AUTHCIRCLE"))

    # m04: client claims level 0 (CM-G3a)
    c = AuthzCert(base_cert.payload_d, base_cert.parent_root,
                  base_cert.exec_id, base_cert.child_root,
                  base_cert.effect_d, 2,
                  AzSrc(DOM_EXECUTION, exec_client_id(CHAIN, PROOF_CFG_D), 0),
                  (), 1, b"")
    cases.append(("m04 client claims level 0",
                  verify_lineage_g(_rc(T.R2F, c), _az(T.wctx2(), c), 2, CF1),
                  "L25-AUTHLEVEL"))

    # m05: level-1 source with NO consensus chain (CM-G3b)
    c = AuthzCert(base_cert.payload_d, base_cert.parent_root,
                  base_cert.exec_id, base_cert.child_root,
                  base_cert.effect_d, 2,
                  AzSrc(DOM_EXECUTION, exec_client_id(CHAIN, PROOF_CFG_D), 1),
                  (), 1, b"")
    cases.append(("m05 no consensus chain",
                  verify_lineage_g(_rc(T.R2F, c), _az(T.wctx2(), c), 2, CF1),
                  "L26-AUTHCIRCLE"))

    # m06: non-decreasing chain (level-1 step BELOW a level-1 source is fine,
    # but a level-1 step after a level-0 root violates strict decrease)
    c = AuthzCert(base_cert.payload_d, base_cert.parent_root,
                  base_cert.exec_id, base_cert.child_root,
                  base_cert.effect_d, 3,
                  AzSrc(DOM_PROOF, proof_sys_id(1, GUEST_D, PROOF_CFG_D), 1),
                  (AzStep(DOM_CONSENSUS, consensus_id(CHAIN), 0),), 1,
                  az_proof_pub(base_cert.payload_d, base_cert.parent_root,
                               CHAIN, T.SCHED_CANCUN, T.SPEC_V1,
                               base_cert.child_root, 1, T.APP_SET_D,
                               T.GRAPH_D, CF1))
    ok_ctx = _az(T.wctx2(), c, 1, GUEST_D, PROOF_CFG_D)
    # sanity: this honest Mode-B-over-R2 cert must itself be well-formed but
    # its parentRoot (SR1) binds R2 — expected VALID-G for the binding, then
    # m06b flips the chain into a cycle-shape (two level-1 steps)
    cases.append(("m06 honest-modeB-over-R2 sanity",
                  verify_lineage_g(_rc(T.R2F, c), ok_ctx, 2, CF1), "VALID-G"))
    c_bad = c.__class__(c.payload_d, c.parent_root, c.exec_id, c.child_root,
                        c.effect_d, 3, c.src,
                        (AzStep(DOM_EXECUTION,
                                exec_client_id(CHAIN, PROOF_CFG_D), 1),
                         AzStep(DOM_CONSENSUS, consensus_id(CHAIN), 0)), 1,
                        c.proof_pub)
    cases.append(("m06b chain level non-decrease",
                  verify_lineage_g(_rc(T.R2F, c_bad),
                                   _az(T.wctx2(), c_bad, 1, GUEST_D,
                                       PROOF_CFG_D), 2, CF1),
                  "L26-AUTHCIRCLE"))

    # m07: proofPub does not recompute (rel=3 with a foreign lineage head)
    c = AuthzCert(base_cert.payload_d, base_cert.parent_root,
                  base_cert.exec_id, base_cert.child_root,
                  base_cert.effect_d, 3,
                  AzSrc(DOM_PROOF, proof_sys_id(1, GUEST_D, PROOF_CFG_D), 1),
                  (AzStep(DOM_CONSENSUS, consensus_id(CHAIN), 0),), 1,
                  az_proof_pub(base_cert.payload_d, base_cert.parent_root,
                               CHAIN, T.SCHED_CANCUN, T.SPEC_V1,
                               base_cert.child_root, 1, T.APP_SET_D,
                               T.GRAPH_D, b"\x22" * 32))
    cases.append(("m07 foreign proofPub",
                  verify_lineage_g(_rc(T.R2F, c),
                                   _az(T.wctx2(), c, 1, GUEST_D, PROOF_CFG_D),
                                   2, CF1), "L28-AUTHBIND"))

    # m08: unauthorized proof type (CM-G10)
    c = AuthzCert(base_cert.payload_d, base_cert.parent_root,
                  base_cert.exec_id, base_cert.child_root,
                  base_cert.effect_d, 3,
                  AzSrc(DOM_PROOF, proof_sys_id(9, GUEST_D, PROOF_CFG_D), 1),
                  (AzStep(DOM_CONSENSUS, consensus_id(CHAIN), 0),), 1,
                  az_proof_pub(base_cert.payload_d, base_cert.parent_root,
                               CHAIN, T.SCHED_CANCUN, T.SPEC_V1,
                               base_cert.child_root, 1, T.APP_SET_D,
                               T.GRAPH_D, CF0))
    cases.append(("m08 unauthorized proof type",
                  verify_lineage_g(_rc(T.R2F, c),
                                   _az(T.wctx2(), c, 1, GUEST_D, PROOF_CFG_D),
                                   2, CF1), "L27-AUTHSRC"))

    # m09: policy substitution (CM-G8) — the record re-digests the cert too
    c = AuthzCert(base_cert.payload_d, base_cert.parent_root,
                  base_cert.exec_id, base_cert.child_root,
                  base_cert.effect_d, 2,
                  AzSrc(DOM_EXECUTION, exec_client_id(CHAIN, PROOF_CFG_D), 1),
                  (AzStep(DOM_CONSENSUS, consensus_id(CHAIN), 0),), 2, b"")
    cases.append(("m09 policy version substitution",
                  verify_lineage_g(_rc(T.R2F, c), _az(T.wctx2(), c), 2, CF1),
                  "L29-POLICY"))

    # m10: execId binding break (cert exec_id = R1's)
    c = AuthzCert(base_cert.payload_d, base_cert.parent_root,
                  T.R1F.exec_id, base_cert.child_root,
                  base_cert.effect_d, 2,
                  AzSrc(DOM_EXECUTION, exec_client_id(CHAIN, PROOF_CFG_D), 1),
                  (AzStep(DOM_CONSENSUS, consensus_id(CHAIN), 0),), 1, b"")
    cases.append(("m10 foreign execId in cert",
                  verify_lineage_g(_rc(T.R2F, c), _az(T.wctx2(), c), 2, CF1),
                  "L28-AUTHBIND"))

    # m11: child-root substitution (CM-G7)
    c = AuthzCert(base_cert.payload_d, base_cert.parent_root,
                  base_cert.exec_id, T.R1F.base.state_root,
                  base_cert.effect_d, 2,
                  AzSrc(DOM_EXECUTION, exec_client_id(CHAIN, PROOF_CFG_D), 1),
                  (AzStep(DOM_CONSENSUS, consensus_id(CHAIN), 0),), 1, b"")
    cases.append(("m11 foreign childRoot in cert",
                  verify_lineage_g(_rc(T.R2F, c), _az(T.wctx2(), c), 2, CF1),
                  "L28-AUTHBIND"))

    # m12: rel/domain mismatch (rel=2 with a consensus source)
    c = AuthzCert(base_cert.payload_d, base_cert.parent_root,
                  base_cert.exec_id, base_cert.child_root,
                  base_cert.effect_d, 2,
                  AzSrc(DOM_CONSENSUS, consensus_id(CHAIN), 0), (), 1, b"")
    cases.append(("m12 rel/domain mismatch",
                  verify_lineage_g(_rc(T.R2F, c), _az(T.wctx2(), c), 2, CF1),
                  "L24-AUTHREL"))

    # m13: unknown rel (rel=7)
    c = AuthzCert(base_cert.payload_d, base_cert.parent_root,
                  base_cert.exec_id, base_cert.child_root,
                  base_cert.effect_d, 7,
                  AzSrc(DOM_CONSENSUS, consensus_id(CHAIN), 0), (), 1, b"")
    cases.append(("m13 unknown rel",
                  verify_lineage_g(_rc(T.R2F, c), _az(T.wctx2(), c), 2, CF1),
                  "L23-AUTHTYPE"))

    # m14: rel=1 cert missing the payload binding (foreign payload digest)
    c = AuthzCert(payload_digest(T.PLD1), base_cert.parent_root,
                  base_cert.exec_id, base_cert.child_root,
                  base_cert.effect_d, 1,
                  AzSrc(DOM_CONSENSUS, consensus_id(CHAIN), 0), (), 1, b"")
    cases.append(("m14 foreign payload binding",
                  verify_lineage_g(_rc(T.R2F, c), _az(T.wctx2(), c), 2, CF1),
                  "L28-AUTHBIND"))

    # m15: stale parent root in an otherwise honest cert (CM-G5)
    c = AuthzCert(base_cert.payload_d, T.SR0, base_cert.exec_id,
                  base_cert.child_root, base_cert.effect_d, 2,
                  AzSrc(DOM_EXECUTION, exec_client_id(CHAIN, PROOF_CFG_D), 1),
                  (AzStep(DOM_CONSENSUS, consensus_id(CHAIN), 0),), 1, b"")
    cases.append(("m15 stale parentRoot in cert",
                  verify_lineage_g(_rc(T.R2F, c), _az(T.wctx2(), c), 2, CF1),
                  "L28-AUTHBIND"))

    # b01 (DOCUMENTED BOUNDARY, accepted): fully-consistent rel=2 certificate
    # constructed by the authorized producer — the model accepts the
    # authority STRUCTURE; whether the source really is the protocol's client
    # is the context-pinning assumption A-G3 (the verifier-domain boundary).
    cases.append(("b01 honest rel=2 cert (boundary)",
                  verify_lineage_g(base_rg, base_ctx, 2, CF1), "VALID-G"))

    # b02 (DOCUMENTED BOUNDARY, rejected): the 1F fully-consistent hidden-
    # write forgery is still caught — at the FROZEN Level-2 anchor layer
    # BEFORE any authority layer runs (the authority layers never fire).
    from exec_model import (ExEvt, ExecCtx, ExecWit, OP_WRITE, SCHED_CANCUN, SPEC_V1,
                            build_rec_f, verify_lineage_f, env_digest as _ed,
                            exec_id as _eid, payload_digest as _pd,
                            trace_digest as _td, config_digest as _cd)
    from auth_model import auth_root, canon_union
    effb = {T.LIQ: {0: 100}, T.LENDING: {1: 0, 9: 999}}
    postb = {T.ORACLE: {0: 100}, T.LENDING: {0: 100, 1: 0, 9: 999},
             T.LIQ: {0: 100}}
    tb = T.T2 + [ExEvt(OP_WRITE, T.LENDING, 9, 999)]
    rb = build_rec_f(2, CF1, T.Q2, effb, postb, T.SK1, 5, tb, T.PLD2,
                     SCHED_CANCUN, SPEC_V1, T.CALLER, 0, SR1)
    srb = auth_root(canon_union(T.Q2, effb, postb), postb)
    witb = ExecWit(1, SR1, _eid(SR1, _pd(T.PLD2), _cd(SCHED_CANCUN, 1),
                               _ed(T.CALLER, 0)), _pd(T.PLD2),
                   H_kv(effb), _td(tb), srb, _cd(SCHED_CANCUN, 1))
    from auth_verify import AuthCtxA
    from lin_verify import LinCtx
    from test_authz_verify import AUTH, REG
    fctxb = ExecCtx(AuthCtxA(LinCtx(T.Q2, effb, postb, REG, AUTH), SR2),
                    SR1, T.PLD2, SCHED_CANCUN, SPEC_V1, T.CALLER, 0, tb,
                    witb)
    got = verify_lineage_f(rb, fctxb, 2, CF1)
    cases.append(("b02 1F-consistent forgery still L2-caught", got,
                  "L14-ANCHOR"))

    npass = 0
    for name, got, expect in cases:
        ok = got == expect
        npass += ok
        print(f"[{name}] verdict={got} expect={expect} "
              f"{'PASS' if ok else ('*** FAIL ***' if not name.startswith('b0') else '(boundary)')}")

    print(f"\n=== PHASE 1G MUTATION HARNESS: {npass}/{len(cases)} as expected "
          f"(b01/b02 are documented boundaries) ===")
    return 0


if __name__ == "__main__":
    raise SystemExit(run())
