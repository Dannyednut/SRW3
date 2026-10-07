#!/usr/bin/env python3
"""SRW3 Phase 1G — permanent Python adversarial suite (authority layer).

Mirrors the K demo suite (phase1g/semantics/srw3authz-demo.k) case-for-case,
plus the cross-layer byte certificate against the K (llvm, real krypto)
values recorded in transcripts/part4_xbytes_raw.txt.

Cases:
  pos0..pos3      honest Oracle->Lending->Liquidator LinRecG chain + Mode B
                  over R0: rel=1,1,2,3 ............................ VALID-G
  g1  (CM-G1) self-authorizing anchor (unauthorized id as chain root) L26-AUTHCIRCLE
  g2  (CM-G2) evidence certifies itself (source id = a certificate id) L27-AUTHSRC
  g3a (CM-G3) client claims level 0 ........................... L25-AUTHLEVEL
  g3b (CM-G3) client output without a consensus chain ......... L26-AUTHCIRCLE
  g4  (CM-G4) payload substitution ........................... L28-AUTHBIND
  g5  (CM-G5) parent-root substitution ....................... L28-AUTHBIND
  g6  (CM-G6) fork/config substitution (client of fork A under B) L27-AUTHSRC
  g7  (CM-G7) child-root substitution ........................ L28-AUTHBIND
  g8  (CM-G8) policy substitution ............................. L29-POLICY
  g9  (CM-G10) unauthorized proof type ........................ L27-AUTHSRC
  g9b (CM-G10) proofPub does not recompute ................... L28-AUTHBIND
  g10        unknown authority relation (rel=4) ............... L23-AUTHTYPE
  g11        rel/domain mismatch .............................. L24-AUTHREL
  bal1..bal4  access-list analysis (footprint/omission/stale-read/order)
"""
from __future__ import annotations

import sys

sys.path.insert(0, "/home/z/my-project/srw3-kevm/python-gen")
sys.path.insert(0, "/home/z/my-project/srw3-kevm/phase1e/python")
sys.path.insert(0, "/home/z/my-project/srw3-kevm/phase1f/python")
sys.path.insert(0, "/home/z/my-project/srw3-kevm/phase1g/python")

from lin_verify import H, LinCtx, addr_of, canon_kv  # noqa: E402
from auth_verify import AuthCtxA  # noqa: E402
from auth_model import auth_root, canon_union  # noqa: E402
from exec_model import (ExEvt, ExecCtx, ExecWit, OP_READ, OP_WRITE,  # noqa: E402
                        SCHED_CANCUN, SPEC_V1, build_rec_f, canon_trace,
                        child_f, config_digest, env_digest, exec_id, i2b4,
                        payload_digest, trace_digest, verify_lineage_f)
from authz_model import (AuthzCert, AzCtx, AzSrc, AzStep, DOM_CONSENSUS,  # noqa: E402
                         DOM_EXECUTION, DOM_PROOF, SecCtx, az_proof_pub,
                         bal_canon, bal_footprint_ok, bal_writes_ok,
                         build_rec_g, cert_body, cert_id, child_g,
                         consensus_id, exec_client_id, policy_auth_id,
                         proof_sys_id, verify_lineage_g)

SK1 = (77).to_bytes(32, "big")
ROOT = b"\x00" * 32
CALLER = addr_of(SK1)

ORACLE, LENDING, LIQ = 4097, 4098, 4099


def i2b1(n):
    return (int(n) % (1 << 8)).to_bytes(1, "big")

# ---- shared context ----------------------------------------------------------
REG = (5, 6)
AUTH = (addr_of(SK1),)


def ctx_of(pre, eff, post, anchor) -> AuthCtxA:
    return AuthCtxA(LinCtx(pre, eff, post, REG, AUTH), anchor)


def H_kv(m):
    return H(canon_kv(m))


def _wit(parent_root, pld, declared, trace, post_root, spec=SPEC_V1):
    eid = exec_id(parent_root, payload_digest(pld),
                  config_digest(SCHED_CANCUN, spec), env_digest(CALLER, 0))
    return ExecWit(1, parent_root, eid, payload_digest(pld),
                   H_kv(declared), trace_digest(trace), post_root,
                   config_digest(SCHED_CANCUN, spec))


# ---- authority-side protocol constants (honest fragment values) --------------
CHAIN = (1).to_bytes(4, "big")
APP_SET_D = H(i2b1(143) + i2b4(ORACLE) + i2b4(LENDING) + i2b4(LIQ))
GRAPH_D = H(i2b1(144) + i2b4(3))
GUEST_D = H(i2b1(145) + i2b4(7))
PROOF_CFG_D = config_digest(SCHED_CANCUN, SPEC_V1)

# ---- R0/R1/R2 (identical to the 1F suite; imported discipline) ----------------
Q0 = {ORACLE: {0: 0}}
E0 = {ORACLE: {0: 100}}
P0 = {ORACLE: {0: 100}}
T0 = [ExEvt(OP_WRITE, ORACLE, 0, 100)]
PLD0 = bytes.fromhex("4f5241434c4531")
SR0 = auth_root(canon_union(Q0, E0, P0), P0)
R0F = build_rec_f(0, ROOT, Q0, E0, P0, SK1, 5, T0, PLD0,
                  SCHED_CANCUN, SPEC_V1, CALLER, 0, ROOT)
CF0 = child_f(R0F)


def wctx0() -> ExecCtx:
    return ExecCtx(ctx_of(Q0, E0, P0, SR0), ROOT, PLD0, SCHED_CANCUN,
                   SPEC_V1, CALLER, 0, T0, _wit(ROOT, PLD0, E0, T0, SR0))


Q1 = {ORACLE: {0: 100}, LENDING: {0: 0, 1: 0}}
E1 = {LENDING: {0: 100, 1: 100}}
P1 = {ORACLE: {0: 100}, LENDING: {0: 100, 1: 100}}
T1 = [ExEvt(OP_READ, ORACLE, 0, 100),
      ExEvt(OP_WRITE, LENDING, 0, 100),
      ExEvt(OP_WRITE, LENDING, 1, 100)]
PLD1 = bytes.fromhex("424f52524f5731")
SR1 = auth_root(canon_union(Q1, E1, P1), P1)
R1F = build_rec_f(1, CF0, Q1, E1, P1, SK1, 5, T1, PLD1,
                  SCHED_CANCUN, SPEC_V1, CALLER, 0, SR0)
CF1 = child_f(R1F)


def wctx1() -> ExecCtx:
    return ExecCtx(ctx_of(Q1, E1, P1, SR1), SR0, PLD1, SCHED_CANCUN,
                   SPEC_V1, CALLER, 0, T1, _wit(SR0, PLD1, E1, T1, SR1))


Q2 = {ORACLE: {0: 100}, LENDING: {0: 100, 1: 100}, LIQ: {0: 0}}
E2 = {LIQ: {0: 100}, LENDING: {1: 0}}
P2 = {ORACLE: {0: 100}, LENDING: {0: 100, 1: 0}, LIQ: {0: 100}}
T2 = [ExEvt(OP_READ, LENDING, 0, 100),
      ExEvt(OP_READ, LENDING, 1, 100),
      ExEvt(OP_READ, ORACLE, 0, 100),
      ExEvt(OP_WRITE, LIQ, 0, 100),
      ExEvt(OP_WRITE, LENDING, 1, 50),
      ExEvt(OP_WRITE, LENDING, 1, 0)]
PLD2 = bytes.fromhex("4c495155494441544531")
SR2 = auth_root(canon_union(Q2, E2, P2), P2)
R2F = build_rec_f(2, CF1, Q2, E2, P2, SK1, 5, T2, PLD2,
                  SCHED_CANCUN, SPEC_V1, CALLER, 0, SR1)


def wctx2() -> ExecCtx:
    return ExecCtx(ctx_of(Q2, E2, P2, SR2), SR1, PLD2, SCHED_CANCUN,
                   SPEC_V1, CALLER, 0, T2, _wit(SR1, PLD2, E2, T2, SR2))


# the stale-read case (1F neg8)
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
                   SPEC_V1, CALLER, 0, T2false,
                   _wit(SR1, PLD2, E2, T2false, SR2))


# the cross-slot reorder (1F neg3x)
T2x = [ExEvt(OP_READ, LENDING, 0, 100),
       ExEvt(OP_READ, LENDING, 1, 100),
       ExEvt(OP_READ, ORACLE, 0, 100),
       ExEvt(OP_WRITE, LENDING, 1, 50),
       ExEvt(OP_WRITE, LIQ, 0, 100),
       ExEvt(OP_WRITE, LENDING, 1, 0)]

# =============================================================================
# authority objects
# =============================================================================

SEC0 = SecCtx(1, CHAIN, APP_SET_D, GRAPH_D, ROOT)
SEC1 = SecCtx(1, CHAIN, APP_SET_D, GRAPH_D, CF0)
SEC2 = SecCtx(1, CHAIN, APP_SET_D, GRAPH_D, CF1)

CONS_ID = consensus_id(CHAIN)
EXEC_ID_AUTH = exec_client_id(CHAIN, PROOF_CFG_D)
PROOF_ID_AUTH = proof_sys_id(1, GUEST_D, PROOF_CFG_D)


def cert0():
    return AuthzCert(payload_digest(PLD0), ROOT, R0F.exec_id, R0F.base.state_root,
                     R0F.eff_trace_d, 1, AzSrc(DOM_CONSENSUS, CONS_ID, 0),
                     (), 1, b"")


def cert1():
    return AuthzCert(payload_digest(PLD1), SR0, R1F.exec_id, R1F.base.state_root,
                     R1F.eff_trace_d, 1, AzSrc(DOM_CONSENSUS, CONS_ID, 0),
                     (), 1, b"")


def cert2():
    return AuthzCert(payload_digest(PLD2), SR1, R2F.exec_id, R2F.base.state_root,
                     R2F.eff_trace_d, 2,
                     AzSrc(DOM_EXECUTION, EXEC_ID_AUTH, 1),
                     (AzStep(DOM_CONSENSUS, CONS_ID, 0),), 1, b"")


def cert3():
    return AuthzCert(payload_digest(PLD0), ROOT, R0F.exec_id, R0F.base.state_root,
                     R0F.eff_trace_d, 3, AzSrc(DOM_PROOF, PROOF_ID_AUTH, 1),
                     (AzStep(DOM_CONSENSUS, CONS_ID, 0),), 1,
                     az_proof_pub(payload_digest(PLD0), ROOT, CHAIN,
                                  SCHED_CANCUN, SPEC_V1, R0F.base.state_root, 1,
                                  APP_SET_D, GRAPH_D, ROOT))


RG0 = build_rec_g(R0F, cert0(), 1)
RG1 = build_rec_g(R1F, cert1(), 1)
RG2 = build_rec_g(R2F, cert2(), 1)
RG3 = build_rec_g(R0F, cert3(), 1)

ACTX0 = AzCtx(wctx0(), SEC0, cert0())
ACTX1 = AzCtx(wctx1(), SEC1, cert1())
ACTX2 = AzCtx(wctx2(), SEC2, cert2())
ACTX3 = AzCtx(wctx0(), SEC0, cert3(), 1, GUEST_D, PROOF_CFG_D)

# ---- countermodels -------------------------------------------------------------
g1c = AuthzCert(payload_digest(PLD0), ROOT, R0F.exec_id, R0F.base.state_root,
                R0F.eff_trace_d, 1, AzSrc(DOM_CONSENSUS, CONS_ID, 0),
                (AzStep(DOM_CONSENSUS, cert_id(cert1()), 0),), 1, b"")
g1r = build_rec_g(R0F, g1c, 1)
g1x = AzCtx(wctx0(), SEC0, g1c)

g2c = AuthzCert(payload_digest(PLD0), ROOT, R0F.exec_id, R0F.base.state_root,
                R0F.eff_trace_d, 1, AzSrc(DOM_CONSENSUS, cert_id(cert1()), 0),
                (), 1, b"")
g2r = build_rec_g(R0F, g2c, 1)
g2x = AzCtx(wctx0(), SEC0, g2c)

g3ac = AuthzCert(payload_digest(PLD2), SR1, R2F.exec_id, R2F.base.state_root,
                 R2F.eff_trace_d, 2, AzSrc(DOM_EXECUTION, EXEC_ID_AUTH, 0),
                 (), 1, b"")
g3ar = build_rec_g(R2F, g3ac, 1)
g3ax = AzCtx(wctx2(), SEC2, g3ac)

g3bc = AuthzCert(payload_digest(PLD2), SR1, R2F.exec_id, R2F.base.state_root,
                 R2F.eff_trace_d, 2, AzSrc(DOM_EXECUTION, EXEC_ID_AUTH, 1),
                 (), 1, b"")
g3br = build_rec_g(R2F, g3bc, 1)
g3bx = AzCtx(wctx2(), SEC2, g3bc)

g4c = AuthzCert(payload_digest(PLD1), ROOT, R0F.exec_id, R0F.base.state_root,
                R0F.eff_trace_d, 1, AzSrc(DOM_CONSENSUS, CONS_ID, 0),
                (), 1, b"")
g4r = build_rec_g(R0F, g4c, 1)
g4x = AzCtx(wctx0(), SEC0, g4c)

g5c = AuthzCert(payload_digest(PLD0), SR1, R0F.exec_id, R0F.base.state_root,
                R0F.eff_trace_d, 1, AzSrc(DOM_CONSENSUS, CONS_ID, 0),
                (), 1, b"")
g5r = build_rec_g(R0F, g5c, 1)
g5x = AzCtx(wctx0(), SEC0, g5c)

g6c = AuthzCert(payload_digest(PLD2), SR1, R2F.exec_id, R2F.base.state_root,
                R2F.eff_trace_d, 2,
                AzSrc(DOM_EXECUTION, exec_client_id(CHAIN, config_digest(SCHED_CANCUN, 2)), 1),
                (AzStep(DOM_CONSENSUS, CONS_ID, 0),), 1, b"")
g6r = build_rec_g(R2F, g6c, 1)
g6x = AzCtx(wctx2(), SEC2, g6c)

g7c = AuthzCert(payload_digest(PLD0), ROOT, R0F.exec_id, R1F.base.state_root,
                R0F.eff_trace_d, 1, AzSrc(DOM_CONSENSUS, CONS_ID, 0),
                (), 1, b"")
g7r = build_rec_g(R0F, g7c, 1)
g7x = AzCtx(wctx0(), SEC0, g7c)

g8c = AuthzCert(payload_digest(PLD0), ROOT, R0F.exec_id, R0F.base.state_root,
                R0F.eff_trace_d, 1, AzSrc(DOM_CONSENSUS, CONS_ID, 0),
                (), 2, b"")
g8r = build_rec_g(R0F, g8c, 1)
g8x = AzCtx(wctx0(), SEC0, g8c)

g9c = AuthzCert(payload_digest(PLD0), ROOT, R0F.exec_id, R0F.base.state_root,
                R0F.eff_trace_d, 3, AzSrc(DOM_PROOF, proof_sys_id(2, GUEST_D, PROOF_CFG_D), 1),
                (AzStep(DOM_CONSENSUS, CONS_ID, 0),), 1,
                az_proof_pub(payload_digest(PLD0), ROOT, CHAIN, SCHED_CANCUN,
                             SPEC_V1, R0F.base.state_root, 1, APP_SET_D, GRAPH_D, ROOT))
g9r = build_rec_g(R0F, g9c, 1)
g9x = AzCtx(wctx0(), SEC0, g9c, 1, GUEST_D, PROOF_CFG_D)

g9bc = AuthzCert(payload_digest(PLD0), ROOT, R0F.exec_id, R0F.base.state_root,
                 R0F.eff_trace_d, 3, AzSrc(DOM_PROOF, PROOF_ID_AUTH, 1),
                 (AzStep(DOM_CONSENSUS, CONS_ID, 0),), 1, b"")
g9br = build_rec_g(R0F, g9bc, 1)
g9bx = AzCtx(wctx0(), SEC0, g9bc, 1, GUEST_D, PROOF_CFG_D)

g10c = AuthzCert(payload_digest(PLD0), ROOT, R0F.exec_id, R0F.base.state_root,
                 R0F.eff_trace_d, 4, AzSrc(DOM_CONSENSUS, CONS_ID, 0),
                 (), 1, b"")
g10r = build_rec_g(R0F, g10c, 1)
g10x = AzCtx(wctx0(), SEC0, g10c)

g11c = AuthzCert(payload_digest(PLD2), SR1, R2F.exec_id, R2F.base.state_root,
                 R2F.eff_trace_d, 2, AzSrc(DOM_CONSENSUS, CONS_ID, 0),
                 (), 1, b"")
g11r = build_rec_g(R2F, g11c, 1)
g11x = AzCtx(wctx2(), SEC2, g11c)

# ---- BAL cases -------------------------------------------------------------------
from authz_model import BalEntry  # noqa: E402

BAL1 = [BalEntry(ORACLE, 0, True, 100)]
BAL2 = []
BAL3 = [BalEntry(ORACLE, 0, True, 100),
        BalEntry(LENDING, 0, True, 100),
        BalEntry(LENDING, 1, True, 0),
        BalEntry(LIQ, 0, True, 100)]

# =============================================================================
# suite
# =============================================================================


def main() -> int:
    cases = [
        ("pos0", verify_lineage_g(RG0, ACTX0, 0, ROOT), "VALID-G"),
        ("pos1", verify_lineage_g(RG1, ACTX1, 1, CF0), "VALID-G"),
        ("pos2", verify_lineage_g(RG2, ACTX2, 2, CF1), "VALID-G"),
        ("pos3", verify_lineage_g(RG3, ACTX3, 0, ROOT), "VALID-G"),
        ("g1", verify_lineage_g(g1r, g1x, 0, ROOT), "L26-AUTHCIRCLE"),
        ("g2", verify_lineage_g(g2r, g2x, 0, ROOT), "L27-AUTHSRC"),
        ("g3a", verify_lineage_g(g3ar, g3ax, 2, CF1), "L25-AUTHLEVEL"),
        ("g3b", verify_lineage_g(g3br, g3bx, 2, CF1), "L26-AUTHCIRCLE"),
        ("g4", verify_lineage_g(g4r, g4x, 0, ROOT), "L28-AUTHBIND"),
        ("g5", verify_lineage_g(g5r, g5x, 0, ROOT), "L28-AUTHBIND"),
        ("g6", verify_lineage_g(g6r, g6x, 2, CF1), "L27-AUTHSRC"),
        ("g7", verify_lineage_g(g7r, g7x, 0, ROOT), "L28-AUTHBIND"),
        ("g8", verify_lineage_g(g8r, g8x, 0, ROOT), "L29-POLICY"),
        ("g9", verify_lineage_g(g9r, g9x, 0, ROOT), "L27-AUTHSRC"),
        ("g9b", verify_lineage_g(g9br, g9bx, 0, ROOT), "L28-AUTHBIND"),
        ("g10", verify_lineage_g(g10r, g10x, 0, ROOT), "L23-AUTHTYPE"),
        ("g11", verify_lineage_g(g11r, g11x, 2, CF1), "L24-AUTHREL"),
        ("bal1", str(bal_footprint_ok(BAL1, T0)
                     and bal_writes_ok(BAL1, T0, Q0)), "True"),
        ("bal2", str(bal_footprint_ok(BAL2, T0)), "False"),
        ("bal3fp", str(bal_footprint_ok(BAL3, T2false)), "True"),
        ("bal3wr", str(bal_writes_ok(BAL3, T2false, Q2)), "True"),
        ("bal3effbind", verify_lineage_f(R8F, nctx8(), 2, CF1), "L22-EFFBIND"),
        ("bal4a", str(bal_footprint_ok(BAL3, T2)), "True"),
        ("bal4b", str(bal_footprint_ok(BAL3, T2x)), "True"),
        ("bal4diff", str(trace_digest(T2) != trace_digest(T2x)), "True"),
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
        "certbody0": "", "certid0": "", "consensusid": "",
        "execclientid": "", "proofsysid": "", "policyauthid": "",
        "proofpub3": "", "childg0": "", "canoncoreg0": "", "bal3canon": "",
    }
    pvals = {
        "certbody0": cert_body(cert0()).hex(),
        "certid0": cert_id(cert0()).hex(),
        "consensusid": CONS_ID.hex(),
        "execclientid": EXEC_ID_AUTH.hex(),
        "proofsysid": PROOF_ID_AUTH.hex(),
        "policyauthid": policy_auth_id(1).hex(),
        "proofpub3": cert3().proof_pub.hex(),
        "childg0": child_g(R0F, cert_id(cert0()), 1).hex(),
        "canoncoreg0": (None,),  # filled below via canon_core_g
        "bal3canon": bal_canon(BAL3).hex(),
    }
    from authz_model import canon_core_g
    pvals["canoncoreg0"] = canon_core_g(R0F, cert_id(cert0()), 1).hex()
    nbyte = 0
    nhave = 0
    for k, kv in kvals.items():
        pv = pvals[k]
        if not kv:
            print(f"[bytes:{k}] python={pv} k=<pending K run>")
            continue
        nhave += 1
        ok = pv == kv
        nbyte += ok
        print(f"[bytes:{k}] python={pv} k={kv} "
              f"{'MATCH' if ok else '*** MISMATCH ***'}")

    total = len(cases) + nhave
    print(f"\n=== PHASE 1G PYTHON SUITE: {npass}/{len(cases)} verdict cases PASS;"
          f" {nbyte}/{nhave} byte checks MATCH ===")
    return 0 if (npass == len(cases) and nbyte == nhave) else 1


if __name__ == "__main__":
    raise SystemExit(main())
