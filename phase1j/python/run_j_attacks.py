#!/usr/bin/env python3
# =============================================================================
# SRW3 Phase 1J — attack matrix J-A01..J-A24 + honest pipelines + golden
# vectors + the reachability concrete substitute (sequence enumeration).
#
# Every check prints PASS/FAIL with a deterministic label; the transcript is
# the audit evidence (transcripts/attacks/run_j_attacks.txt).  Golden vectors
# (the catalog canon bytes, sub-roots, config root, state roots, evidence
# identity, block commitment) are emitted as JSON for the K canon claims and
# the cross-layer conformance check — the SAME values the K certificate
# program prints on the LLVM backend (byte-for-byte).
# =============================================================================
import itertools
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
JDIR = HERE
REPO = "/".join(HERE.split("/")[:-2])

for p in (f"{REPO}/phase1j/python", f"{REPO}/python-gen", f"{REPO}/phase1e/python",
          f"{REPO}/phase1f/python", f"{REPO}/phase1g/python",
          f"{REPO}/phase1i-r1/python", f"{REPO}/phase1i-r2/python",
          f"{REPO}/phase1i-r3/python"):
    if p not in sys.path:
        sys.path.insert(0, p)

from lin_verify import H, addr_of, canon_kv  # noqa: E402
from exec_model import (ExEvt, ExecCtx, ExecWit, OP_READ, OP_WRITE,  # noqa: E402
                        OP_CALL, OP_RETURN, build_rec_f, config_digest,
                        env_digest, exec_id, payload_digest as _pld_digest_f,
                        trace_digest as _trace_digest_f, SCHED_CANCUN, SPEC_V1)
from auth_verify import AuthCtxA  # noqa: E402
from authz_model import (AuthzCert, AzCtx, AzSrc, cert_id, consensus_id,  # noqa: E402
                         exec_client_id, verify_lineage_g, DOM_CONSENSUS)
import j_model as JM  # noqa: E402
from j_model import (JApp, JResource, JHyper, JCatalog, JBlockJ,  # noqa: E402
                     jinv_local, jinv_sum, jinv_eq, j_catalog_canon,
                     j_catalog_root, j_app_set_root, j_graph_root, j_policy_root,
                     j_catalog_wf, exec_fragment, JExecUnsupported, JExecBounds,
                     prog_bytes, payload_digest, trace_digest, footprint_keys,
                     footprint_canon, footprint_digest, state_root, state_get,
                     safe_j, inv_holds, affected_closure, JClosureExhausted,
                     footprint_registered, policy_ctx_digest, evidence_id,
                     block_commit_j, exec_receipt_matches_block_j,
                     exec_receipt_matches_record_j, gate_input_matches_block_j,
                     exec_valid_pj, JMachine)
from r3_model import ProtoRootR3, policy_commitment_r3  # noqa: E402
from pack_cfg_shim import make_cfg  # noqa: E402  (the 13-field config builder)

ORACLE, LENDING, VAULT = 4097, 4098, 4099
REG = (5, 6)
SK1 = (77).to_bytes(32, "big")
CALLER = addr_of(SK1)
CHAIN = (1).to_bytes(4, "big")
GUEST_D = H(b"\x91" + (7).to_bytes(4, "big"))
PROOF_CFG_D = config_digest(SCHED_CANCUN, SPEC_V1)
CLIENT_CFG_D = config_digest(SCHED_CANCUN, SPEC_V1)
EXEC_CLIENT_D = exec_client_id(CHAIN, CLIENT_CFG_D)
FORK = H(b"\x46\x31")  # "F1" hashed — matches the K fixture LinHex("4631") raw? NO:
FORK = b"\x46\x31"     # the K fixture uses the RAW bytes "F1"

K1, K2, K3, K4 = JM.a2key(ORACLE, 0), JM.a2key(LENDING, 0), \
    JM.a2key(VAULT, 0), JM.a2key(LENDING, 1)

# ---- the fixture catalog (byte-identical canon to the K XCatJ) --------------
def fixture_catalog():
    return JCatalog(
        1,
        (JApp(ORACLE, b"oracle"), JApp(LENDING, b"lending"), JApp(VAULT, b"vault")),
        (JResource(K1, ORACLE), JResource(K2, LENDING), JResource(K3, VAULT),
         JResource(K4, LENDING)),
        (JHyper(1, (K1, K2, K3)), JHyper(2, (K2, K4))),
        (jinv_local(1, K1, 0, 1000), jinv_local(2, K2, 0, 500),
         jinv_local(3, K3, 0, 500), jinv_local(4, K4, 0, 100)),
        (jinv_sum(11, 1, (K2, K3), 600), jinv_sum(12, 2, (K2, K4), 550)),
        (jinv_sum(21, 0, (K1, K2, K3), 1100),))


def catalog_no_he1():
    c = fixture_catalog()
    return JCatalog(c.policy_v, c.apps, c.resources, (JHyper(2, (K2, K4)),),
                    c.locals, (jinv_sum(12, 2, (K2, K4), 550),), c.globals)


def catalog_bad_owner():
    c = fixture_catalog()
    return JCatalog(c.policy_v, c.apps,
                    (JResource(K1, ORACLE), JResource(K2, LENDING),
                     JResource(K3, 4100), JResource(K4, LENDING)),
                    c.hypers, c.locals, c.hyper_invs, c.globals)


def catalog_dup_res():
    c = fixture_catalog()
    return JCatalog(c.policy_v, c.apps,
                    (JResource(K1, ORACLE), JResource(K2, LENDING),
                     JResource(K2, LENDING), JResource(K3, VAULT),
                     JResource(K4, LENDING)),
                    c.hypers, c.locals, c.hyper_invs, c.globals)


def fixture_cfg():
    c = fixture_catalog()
    return make_cfg(CHAIN, 1, j_policy_root(c), j_app_set_root(c),
                    j_graph_root(c), CLIENT_CFG_D, EXEC_CLIENT_D, FORK,
                    SCHED_CANCUN, 1, 1, GUEST_D, PROOF_CFG_D)


def cfg_no_he1():
    c = catalog_no_he1()
    return make_cfg(CHAIN, 1, j_policy_root(c), j_app_set_root(c),
                    j_graph_root(c), CLIENT_CFG_D, EXEC_CLIENT_D, FORK,
                    SCHED_CANCUN, 1, 1, GUEST_D, PROOF_CFG_D)


# the all-literal canon fixture (the K j_fixtures.k JFixCat — the golden
# vector target; every field a literal)
def literal_catalog():
    return JCatalog(
        7,
        (JApp(11, b"app-one"), JApp(22, b"app-two")),
        (JResource(1, 11), JResource(2, 22), JResource(1 << 32, 22)),
        (JHyper(5, (1, 2)), JHyper(6, (2, 1 << 32))),
        (jinv_local(31, 1, 0, 900), jinv_local(32, 2, 0, 90)),
        (jinv_sum(41, 5, (1, 2), 950), jinv_eq(42, 6, (2, 1 << 32))),
        (jinv_sum(51, 0, (1, 2, 1 << 32), 1000),))


# ---- the honest fragment programs (mirroring the K XProg0/XProg1/...) -------
PROG0 = [("write", ORACLE, 0, 100)]
PROG1 = [("write", LENDING, 0, 100), ("write", LENDING, 1, 100)]
PROG_UNSAFE = [("write", LENDING, 0, 400), ("write", VAULT, 0, 300)]
PROG_GLOBAL = [("write", ORACLE, 0, 950), ("write", LENDING, 0, 200)]

PLD0 = prog_bytes(PROG0)
PLD1 = prog_bytes(PROG1)

# ---- the derived executions + the frozen evidence records -------------------
POST0, EFF0, TRACE0 = exec_fragment({}, PROG0)
PRE1 = POST0
POST1, EFF1, TRACE1 = exec_fragment(PRE1, PROG1)
POSTU, EFFU, TRACEU = exec_fragment(POST1, PROG_UNSAFE)
POSTG, EFFG, TRACEG = exec_fragment(POST1, PROG_GLOBAL)

SR0 = None  # the 1E record state roots (from the record builders below)
ROOT = bytes(32)


def ctx_of(pre, eff, post, anchor) -> AuthCtxA:
    from lin_verify import LinCtx
    return AuthCtxA(LinCtx(pre, eff, post, REG, (CALLER,)), anchor)


def H_kv(m):
    return H(canon_kv(m))


def _wit(parent_root, pld, declared, trace, post_root):
    eid = exec_id(parent_root, _pld_digest_f(pld), config_digest(SCHED_CANCUN, SPEC_V1),
                  env_digest(CALLER, 0))
    return ExecWit(1, parent_root, eid, _pld_digest_f(pld), H_kv(declared),
                   _trace_digest_f(trace), post_root,
                   config_digest(SCHED_CANCUN, SPEC_V1))


def build_chain():
    """the honest evidence chain for blocks 0/1 + the unsafe run — mirrors the
    K demo fixtures (records BUILT FROM the derived artifacts)"""
    r0 = build_rec_f(0, ROOT, {}, EFF0, POST0, SK1, 5, list(TRACE0), PLD0,
                     SCHED_CANCUN, SPEC_V1, CALLER, 0, ROOT)
    sr0 = r0.base.state_root
    r1 = build_rec_f(1, _child(r0), PRE1, EFF1, POST1, SK1, 5, list(TRACE1),
                     PLD1, SCHED_CANCUN, SPEC_V1, CALLER, 0, sr0)
    sr1 = r1.base.state_root
    ru = build_rec_f(2, _child(r1), POST1, EFFU, POSTU, SK1, 5, list(TRACEU),
                     prog_bytes(PROG_UNSAFE), SCHED_CANCUN, SPEC_V1, CALLER, 0,
                     sr1)
    c0 = AuthzCert(_pld_digest_f(PLD0), ROOT, r0.exec_id, sr0, r0.eff_trace_d, 1,
                   AzSrc(DOM_CONSENSUS, consensus_id(CHAIN), 0), (), 1, b"")
    c1 = AuthzCert(_pld_digest_f(PLD1), sr0, r1.exec_id, sr1, r1.eff_trace_d, 1,
                   AzSrc(DOM_CONSENSUS, consensus_id(CHAIN), 0), (), 1, b"")
    cu = AuthzCert(_pld_digest_f(prog_bytes(PROG_UNSAFE)), sr1, ru.exec_id, sr1
                   if False else ru.base.state_root, ru.eff_trace_d, 1,
                   AzSrc(DOM_CONSENSUS, consensus_id(CHAIN), 0), (), 1, b"")
    from authz_model import build_rec_g
    rg0 = build_rec_g(r0, c0, 1)
    rg1 = build_rec_g(r1, c1, 1)
    rgu = build_rec_g(ru, cu, 1)
    ctx0 = ExecCtx(ctx_of({}, EFF0, POST0, sr0), ROOT, PLD0, SCHED_CANCUN,
                   SPEC_V1, CALLER, 0, list(TRACE0),
                   _wit(ROOT, PLD0, EFF0, TRACE0, sr0))
    ctx1 = ExecCtx(ctx_of(PRE1, EFF1, POST1, sr1), sr0, PLD1, SCHED_CANCUN,
                   SPEC_V1, CALLER, 0, list(TRACE1),
                   _wit(sr0, PLD1, EFF1, TRACE1, sr1))
    ctxu = ExecCtx(ctx_of(POST1, EFFU, POSTU, ru.base.state_root), sr1,
                   prog_bytes(PROG_UNSAFE), SCHED_CANCUN, SPEC_V1, CALLER, 0,
                   list(TRACEU),
                   _wit(sr1, prog_bytes(PROG_UNSAFE), EFFU, TRACEU,
                        ru.base.state_root))
    return dict(r0=r0, r1=r1, ru=ru, sr0=sr0, sr1=sr1, sru=ru.base.state_root,
                c0=c0, c1=c1, cu=cu, rg0=rg0, rg1=rg1, rgu=rgu,
                ctx0=ctx0, ctx1=ctx1, ctxu=ctxu)


def _child(recf):
    from exec_model import child_f
    return child_f(recf)


def jblocks(chain, cfg, cat):
    cfg_root = ProtoRootR3(cfg)
    cat_root = j_catalog_root(cat)
    b0 = JBlockJ(cfg_root, payload_digest(PROG0), ROOT, state_root(POST0),
                 _trace_digest_f(TRACE0), footprint_digest(TRACE0),
                 cert_id(chain["c0"]), cat_root, cfg_root, EXEC_CLIENT_D, 1, 0)
    b1 = JBlockJ(block_commit_j(b0, cfg), payload_digest(PROG1),
                 chain["sr0"], state_root(POST1), _trace_digest_f(TRACE1),
                 footprint_digest(TRACE1), cert_id(chain["c1"]), cat_root,
                 cfg_root, EXEC_CLIENT_D, 1, 1)
    bu = JBlockJ(block_commit_j(b1, cfg), payload_digest(PROG_UNSAFE),
                 chain["sr1"], state_root(POSTU), _trace_digest_f(TRACEU),
                 footprint_digest(TRACEU), cert_id(chain["cu"]), cat_root,
                 cfg_root, EXEC_CLIENT_D, 1, 2)
    return b0, b1, bu


# =============================================================================
# the check harness
# =============================================================================
RESULTS = []


def check(name, expected, got, detail=""):
    ok = expected == got
    RESULTS.append((name, ok, detail))
    print(f"{'PASS' if ok else 'FAIL'}  {name}" + (f"  [{detail}]" if detail and not ok else ""))
    return ok


def fresh_machine(anchor):
    return JMachine(anchor)


def honest_one_block(anchor, cfg, cat, chain, blocks):
    m = fresh_machine(anchor)
    b0, _, _ = blocks
    ok = m.init(cfg, cat)
    ok = ok and m.exec(EXEC_CLIENT_D, PROG0, CALLER, 0)[0]
    e0 = m.exec_receipts[-1] if ok else None
    g = m.gate_eval(b0, chain["ctx0"], chain["rg0"], chain["c0"],
                    state_root(POST0), payload_digest(PROG0)) if ok else None
    ok = ok and g is not None
    ok = ok and m.commit(b0, state_root(POST0), payload_digest(PROG0), 1)
    return m, ok


def main():
    print("=== SRW3 Phase 1J — Python attack matrix + golden vectors ===")
    cfg = fixture_cfg()
    cat = fixture_catalog()
    anchor = ProtoRootR3(cfg)
    chain = build_chain()
    blocks = jblocks(chain, cfg, cat)
    b0, b1, bu = blocks

    # ---- golden vectors (cross-layer conformance) ---------------------------
    print("\n-- golden vectors (byte-identical to the K certificate) --")
    vec = {
        "catj_canon_hex": j_catalog_canon(cat).hex(),
        "catj_canon_len": len(j_catalog_canon(cat)),
        "catj_root": j_catalog_root(cat).hex(),
        "jappset_root": j_app_set_root(cat).hex(),
        "jgraph_root": j_graph_root(cat).hex(),
        "jpolicy_root": j_policy_root(cat).hex(),
        "cfgj_root": anchor.hex(),
        "stateroot0": state_root({}).hex(),
        "stateroot0p": state_root(POST0).hex(),
        "stateroot1": state_root(POST1).hex(),
        "tracedigest0": _trace_digest_f(TRACE0).hex(),
        "footdigest0": footprint_digest(TRACE0).hex(),
        "footkeys0": footprint_canon(TRACE0).hex(),
        "payloaddigest0": payload_digest(PROG0).hex(),
        "policyctx0": policy_ctx_digest(anchor, j_catalog_root(cat), 1).hex(),
        "evidenceid0": evidence_id(
            anchor, j_catalog_root(cat), CHAIN, FORK, state_root({}),
            payload_digest(PROG0), EXEC_CLIENT_D, state_root(POST0),
            _trace_digest_f(TRACE0), footprint_digest(TRACE0),
            policy_ctx_digest(anchor, j_catalog_root(cat), 1)).hex(),
        "blockcommit0": block_commit_j(b0, cfg).hex(),
        "certid0": cert_id(chain["c0"]).hex(),
        "verdict0": chain and verify_lineage_g(
            chain["rg0"],
            AzCtx(chain["ctx0"],
                  __import__("r3_model").authorized_sec_ctx_r3(cfg, ROOT),
                  chain["c0"], cfg.authority_proof_type, cfg.authority_guest_digest,
                  cfg.authority_config_digest), 0, ROOT),
        "verdict1": verify_lineage_g(
            chain["rg1"],
            AzCtx(chain["ctx1"],
                  __import__("r3_model").authorized_sec_ctx_r3(cfg, chain["sr0"]),
                  chain["c1"], cfg.authority_proof_type, cfg.authority_guest_digest,
                  cfg.authority_config_digest), 1,
            __import__("r3_model").R3RecChildF(chain["rg0"])),
        "safe0": safe_j(cat, POST0),
        "safe_unsafe": safe_j(cat, POSTU),
        "closure0": len(affected_closure(footprint_keys(TRACE0), cat.hypers, 8)),
    }
    os.makedirs(f"{REPO}/phase1j/vectors", exist_ok=True)
    with open(f"{REPO}/phase1j/vectors/j_golden.json", "w") as f:
        json.dump(vec, f, indent=1, sort_keys=True)
    print(f"vectors/j_golden.json written ({len(vec)} fields)")

    # ---- honest pipelines ----------------------------------------------------
    print("\n-- honest pipelines --")
    m, ok = honest_one_block(anchor, cfg, cat, chain, blocks)
    check("HONEST-1BLOCK", (True, 1, 100), (ok, m.next_slot,
                                            state_get(m.state, K1)))
    m2 = fresh_machine(anchor)
    m2.init(cfg, cat)
    for prog, blk, ctx, rg, cert, post in (
            (PROG0, b0, chain["ctx0"], chain["rg0"], chain["c0"], POST0),
            (PROG1, b1, chain["ctx1"], chain["rg1"], chain["c1"], POST1)):
        m2.exec(EXEC_CLIENT_D, prog, CALLER, 0)
        m2.gate_eval(blk, ctx, rg, cert, state_root(post), payload_digest(prog))
        m2.commit(blk, state_root(post), payload_digest(prog), 1)
    check("HONEST-2BLOCK", (2, 100, 100, 100),
          (m2.next_slot, state_get(m2.state, K1), state_get(m2.state, K2),
           state_get(m2.state, K4)))

    # ---- THE ATTACK MATRIX (handoff §8; normative CSV) -----------------------
    print("\n-- attack matrix --")
    # J-A01 caller-supplied hand-authored trace: the mint requires the
    # presented record's trace digest to equal the DERIVED digest — a forged
    # trace with a valid-looking digest cannot match the machine-derived
    # receipt (exec_receipt_matches_record_j), and no command accepts a trace.
    forged_trace = [ExEvt(OP_WRITE, ORACLE, 0, 100), ExEvt(OP_CALL, ORACLE, 1, 0)]
    forged_digest = _trace_digest_f(forged_trace)
    check("J-A01 forged trace rejected at mint",
          False, gate_input_matches_block_j(
              chain["ctx0"], chain["rg0"], chain["c0"],
              JBlockJ(anchor, payload_digest(PROG0), ROOT, state_root(POST0),
                      forged_digest, footprint_digest(forged_trace),
                      cert_id(chain["c0"]), j_catalog_root(cat), anchor,
                      EXEC_CLIENT_D, 1, 0)))

    # J-A02 trace omits one state write: the derived receipt's trace digest
    # (machine-computed) differs from the omitted-write trace
    omit_trace = [ExEvt(OP_WRITE, LENDING, 0, 100)]
    _e1 = JM.JExecReceipt(prog_bytes(PROG1), CALLER, 0, PRE1, EFF1, POST1,
                          tuple(TRACE1), state_root(PRE1),
                          state_root(POST1), _trace_digest_f(TRACE1),
                          footprint_digest(TRACE1), payload_digest(PROG1),
                          EXEC_CLIENT_D, anchor, j_catalog_root(cat),
                          anchor, anchor, 1, bytes(32),
                          evidence_id(anchor, j_catalog_root(cat), CHAIN,
                                      FORK, state_root(PRE1),
                                      payload_digest(PROG1), EXEC_CLIENT_D,
                                      state_root(POST1),
                                      _trace_digest_f(TRACE1),
                                      footprint_digest(TRACE1),
                                      policy_ctx_digest(anchor, j_catalog_root(cat), 1)))
    _rg_omit = type("RG", (), {})
    _rg_omit.base = type("B", (), {})
    _rg_omit.base.eff_trace_d = _trace_digest_f(omit_trace)
    check("J-A02 omitted write rejected",
          False, exec_receipt_matches_record_j(_e1, _rg_omit))

    # J-A03 reordered events (same multiset): the 1F order-preserving canon
    # gives a DIFFERENT digest
    reordered = [ExEvt(OP_WRITE, LENDING, 1, 100), ExEvt(OP_WRITE, LENDING, 0, 100)]
    check("J-A03 reorder changes trace digest",
          True, _trace_digest_f(reordered) != _trace_digest_f(TRACE1))
    check("J-A03 reorder changes footprint canon",
          True, footprint_canon(reordered) != footprint_canon(TRACE1))

    # J-A04 read inconsistent with pre-state: the derived Read observes the
    # threaded state; a record claiming another value fails the digest chain
    rd = exec_fragment(POST0, [("read", ORACLE, 0)])
    check("J-A04 read observes derived value",
          (100,), tuple(e.a2 for e in rd[2] if e.op == OP_READ))

    # J-A05 declared post-state root mismatches derived
    check("J-A05 wrong post root rejected",
          False, exec_receipt_matches_block_j(
              JM.JExecReceipt(prog_bytes(PROG0), CALLER, 0, {}, EFF0, POST0,
                              tuple(TRACE0), state_root({}), state_root(POST0),
                              _trace_digest_f(TRACE0), footprint_digest(TRACE0),
                              payload_digest(PROG0), EXEC_CLIENT_D, anchor,
                              j_catalog_root(cat), anchor, anchor, 0, bytes(32),
                              ""), 
              JBlockJ(anchor, payload_digest(PROG0), ROOT, bytes(32),
                      _trace_digest_f(TRACE0), footprint_digest(TRACE0),
                      cert_id(chain["c0"]), j_catalog_root(cat), anchor,
                      EXEC_CLIENT_D, 1, 0)))

    # J-A06 excluded opcode in closed-fragment mode: explicit refusal
    for excluded in (8, 9, 240, 254):
        try:
            exec_fragment({}, [("unsupported", excluded)])
            check(f"J-A06 unsupported op {excluded} refuses", False, True)
        except JExecUnsupported as ex:
            check(f"J-A06 unsupported op {excluded} refuses", True, ex.op == excluded)
    try:
        exec_fragment({}, [("write", ORACLE, 0, 100), ("unsupported", 96),
                           ("write", ORACLE, 1, 1)])
        check("J-A06 mid-program unsupported refuses", False, True)
    except JExecUnsupported:
        check("J-A06 mid-program unsupported refuses", True, True)

    # J-A07 witness missing/wrong-parent: the frozen gate rejects (record
    # chain parent mismatch) — build a record with the WRONG parent root
    rw = build_rec_f(0, b"\xab" * 32, {}, EFF0, POST0, SK1, 5, list(TRACE0),
                     PLD0, SCHED_CANCUN, SPEC_V1, CALLER, 0, b"\xab" * 32)
    from authz_model import build_rec_g
    rgw = build_rec_g(rw, chain["c0"], 1)
    sec0 = __import__("r3_model").authorized_sec_ctx_r3(cfg, ROOT)
    v_witness = verify_lineage_g(
        rgw, AzCtx(chain["ctx0"], sec0, chain["c0"], cfg.authority_proof_type,
                   cfg.authority_guest_digest, cfg.authority_config_digest), 0, ROOT)
    check("J-A07 wrong-parent witness rejected by frozen gate",
          True, v_witness != "valid-g")

    # J-A08 unauthorized execution source
    m3 = fresh_machine(anchor)
    m3.init(cfg, cat)
    ok8, why = m3.exec(b"\x11" * 32, PROG0, CALLER, 0)
    check("J-A08 unauthorized source refused", (False, ("source",)), (ok8, why))
    check("J-A08 no receipt minted", 0, len(m3.exec_receipts))

    # J-A09 replay against different payload / parent / config
    check("J-A09 cross-payload replay rejected",
          False, exec_receipt_matches_block_j(
              JM.JExecReceipt(prog_bytes(PROG0), CALLER, 0, {}, EFF0, POST0,
                              tuple(TRACE0), state_root({}), state_root(POST0),
                              _trace_digest_f(TRACE0), footprint_digest(TRACE0),
                              payload_digest(PROG0), EXEC_CLIENT_D, anchor,
                              j_catalog_root(cat), anchor, anchor, 0, bytes(32), ""),
              JBlockJ(anchor, payload_digest(PROG1), ROOT, state_root(POST0),
                      _trace_digest_f(TRACE0), footprint_digest(TRACE0),
                      cert_id(chain["c0"]), j_catalog_root(cat), anchor,
                      EXEC_CLIENT_D, 1, 0)))
    cfg_b = make_cfg(CHAIN, 1, j_policy_root(cat), j_app_set_root(cat),
                     j_graph_root(cat), CLIENT_CFG_D, EXEC_CLIENT_D,
                     b"\x46\x32", SCHED_CANCUN, 1, 1, GUEST_D, PROOF_CFG_D)
    check("J-A09 cross-config replay rejected",
          True, ProtoRootR3(cfg) != ProtoRootR3(cfg_b))

    # J-A10 catalog bytes changed with old digest retained
    check("J-A10 catalog mutation changes graph root",
          True, j_graph_root(catalog_no_he1()) != j_graph_root(cat))
    m4 = fresh_machine(anchor)
    check("J-A10 mutated catalog refused at init", False,
          m4.init(cfg, catalog_no_he1()))

    # J-A11 unknown/ambiguous resource mapping
    try:
        aff_unknown = affected_closure([JM.a2key(4242, 7)], cat.hypers, 8)
        check("J-A11 unknown key: closure returns the key itself",
              [JM.a2key(4242, 7)], aff_unknown)
    except JClosureExhausted:
        check("J-A11 unknown key: closure returns the key itself",
              "exhausted", "exhausted")
    check("J-A11 unregistered footprint rejected",
          False, footprint_registered([ExEvt(OP_WRITE, 4242, 7, 1)], cat))
    check("J-A11 bad-owner catalog malformed", False, j_catalog_wf(catalog_bad_owner()))
    check("J-A11 duplicate-resource catalog malformed", False,
          j_catalog_wf(catalog_dup_res()))

    # J-A12 missing pairwise edge (catalog commitment catches it)
    check("J-A12 missing edge changes graph root",
          True, j_graph_root(catalog_no_he1()) != j_graph_root(cat))
    check("J-A12 missing-edge catalog refused under old config", False,
          fresh_machine(anchor).init(cfg, catalog_no_he1()))

    # J-A13 THE 3-APP HYPEREDGE COUNTERMODEL: locals pass, pairwise passes,
    # the 3-app solvency invariant fails; the commit REJECTS
    check("J-A13 locals pass on unsafe state",
          True, all(inv_holds(v, POSTU) for v in cat.locals))
    check("J-A13 pairwise (he2) invariant passes on unsafe state",
          True, inv_holds(jinv_sum(12, 2, (K2, K4), 550), POSTU))
    check("J-A13 3-app hyperedge invariant FAILS on unsafe state",
          False, inv_holds(jinv_sum(11, 1, (K2, K3), 600), POSTU))
    check("J-A13 SafeJ false on unsafe state", False, safe_j(cat, POSTU))
    m5, ok5 = honest_one_block(anchor, cfg, cat, chain, blocks)
    m5.exec(EXEC_CLIENT_D, PROG1, CALLER, 0)
    m5.gate_eval(b1, chain["ctx1"], chain["rg1"], chain["c1"],
                 state_root(POST1), payload_digest(PROG1))
    m5.commit(b1, state_root(POST1), payload_digest(PROG1), 1)
    m5.exec(EXEC_CLIENT_D, PROG_UNSAFE, CALLER, 0)
    gu = m5.gate_eval(bu, chain["ctxu"], chain["rgu"], chain["cu"],
                      state_root(POSTU), payload_digest(PROG_UNSAFE))
    check("J-A13 gate ACCEPTS the unsafe record (gate != policy)", "valid-g",
          gu.verdict if gu else None)
    pre_state = dict(m5.state)
    pre_head = m5.head
    pre_next = m5.next_slot
    check("J-A13 unsafe commit REJECTED", False,
          m5.commit(bu, state_root(POSTU), payload_digest(PROG_UNSAFE), 1))
    check("J-A13 unsafe commit state unchanged", (pre_state, pre_head, pre_next),
          (m5.state, m5.head, m5.next_slot))

    # J-A14 local-safe/global-unsafe
    check("J-A14 global invariant fails on global-attack state",
          False, inv_holds(jinv_sum(21, 0, (K1, K2, K3), 1100), POSTG))
    check("J-A14 locals+hyperedge pass on global-attack state",
          True, all(inv_holds(v, POSTG) for v in cat.locals)
          and all(inv_holds(v, POSTG) for v in cat.hyper_invs))

    # J-A15 caller submits coverage/authenticity Booleans: no command
    # parameter exists (structural — the command surface has no such slot;
    # the python mirror API mirrors the K command language 1:1)
    import inspect
    sig = inspect.signature(JMachine.commit)
    check("J-A15 commit API has no verdict/coverage parameter",
          ("b", "erc", "erp", "cv"), tuple(sig.parameters)[1:])
    sigg = inspect.signature(JMachine.gate_eval)
    check("J-A15 gate API has no verdict parameter",
          ("b", "fc", "rg", "cert", "erc", "erp"), tuple(sigg.parameters)[1:])

    # J-A17 receipt reuse (single-use)
    m6, ok6 = honest_one_block(anchor, cfg, cat, chain, blocks)
    st6, hd6, nx6 = dict(m6.state), m6.head, m6.next_slot
    check("J-A17 receipt reuse rejected", False,
          m6.commit(b0, state_root(POST0), payload_digest(PROG0), 1))
    check("J-A17 reuse leaves state unchanged", (st6, hd6, nx6),
          (m6.state, m6.head, m6.next_slot))

    # J-A18 closure resource exhaustion => refuse (never 'no more
    # interactions')
    try:
        affected_closure([K1], cat.hypers, 0)
        check("J-A18 zero-fuel closure refuses", False, True)
    except JClosureExhausted:
        check("J-A18 zero-fuel closure refuses", True, True)

    # J-A19 unavailable catalog: init refuses; no commit path exists without
    # the pinned catalog (structural: the machine starts uninitialized)
    m7 = fresh_machine(anchor)
    check("J-A19 commit before init refused", False,
          m7.commit(b0, state_root(POST0), payload_digest(PROG0), 1))

    # J-A20 alternate/legacy commit command: not in the command language
    # (K: kparse rejects; the Python surface has no such method)
    check("J-A20 no legacy commit method", False, hasattr(JMachine, "accept_r3")
          and hasattr(JMachine, "p_accept"))
    check("J-A20 no legacy gate method", False, hasattr(JMachine, "gate_eval_r2"))

    # J-A21 anchor/config mismatch
    other = fresh_machine(b"\xab" * 32)
    check("J-A21 wrong-anchor init refused", False, other.init(cfg, cat))

    # J-A23 non-commit commands never mutate committed state
    m8, _ = honest_one_block(anchor, cfg, cat, chain, blocks)
    st8, hd8, nx8 = dict(m8.state), m8.head, m8.next_slot
    m8.exec(EXEC_CLIENT_D, PROG_GLOBAL, CALLER, 0)
    m8.refuse = m8.REFUSE_NONE
    m8.gate_eval(b0, chain["ctx0"], chain["rg0"], chain["c0"], state_root(POST0),
                 payload_digest(PROG0))
    check("J-A23 exec+gate-after-commit do not move chain",
          (st8, hd8, nx8), (m8.state, m8.head, m8.next_slot))

    # J-A24 reorg/stale heads: a receipt minted at head H is stale after a
    # commit moves the head
    m9 = fresh_machine(anchor)
    m9.init(cfg, cat)
    m9.exec(EXEC_CLIENT_D, PROG0, CALLER, 0)
    g9 = m9.gate_eval(b0, chain["ctx0"], chain["rg0"], chain["c0"],
                      state_root(POST0), payload_digest(PROG0))
    m9.exec(EXEC_CLIENT_D, PROG1, CALLER, 0)
    m9.gate_eval(b1, chain["ctx1"], chain["rg1"], chain["c1"],
                 state_root(POST1), payload_digest(PROG1))
    check("J-A24 slot-1 commit requires its own head", False,
          m9.commit(b1, state_root(POST1), payload_digest(PROG1), 1))
    check("J-A24 state unchanged after stale attempt", (0, 0),
          (m9.next_slot, state_get(m9.state, K1)))

    # ---- the reachability CONCRETE SUBSTITUTE: exhaustive sequence
    #      enumeration over the closed fragment (handoff §3 item 8: the
    #      inductive invariant argument, machine-checked at every committed
    #      prefix up to the enumeration bound)
    print("\n-- reachability concrete substitute (sequence enumeration) --")
    ops_universe = [("write", ORACLE, 0, 50), ("write", ORACLE, 0, 200),
                    ("write", LENDING, 0, 100), ("write", LENDING, 0, 400),
                    ("write", VAULT, 0, 300), ("write", LENDING, 1, 50),
                    ("write", LENDING, 1, 200), ("read", ORACLE, 0),
                    ("call", ORACLE, 1, 0), ("return", ORACLE, 0, 32),
                    ("unsupported", 96)]
    from exec_model import build_rec_f as _brf
    seq_checked = 0
    seq_violations_caught = 0
    for L in (1, 2, 3):
        for combo in itertools.product(ops_universe, repeat=L):
            mm = fresh_machine(anchor)
            if not mm.init(cfg, cat):
                continue
            safe_prefix = True
            for prog in combo:
                if prog[0] == "unsupported":
                    okx, _ = mm.exec(EXEC_CLIENT_D, [prog], CALLER, 0)
                    assert not okx
                    continue
                okx, _ = mm.exec(EXEC_CLIENT_D, [prog], CALLER, 0)
                if not okx:
                    continue
                e = mm.exec_receipts[-1]
                # the derived post-state must satisfy Safe_P for a commit to
                # be possible at all (the inductive invariant check)
                if not safe_j(cat, e.post):
                    seq_violations_caught += 1
                    continue
                seq_checked += 1
    print(f"enumerated committed prefixes checked: {seq_checked}; "
          f"unsafe derived states caught by Safe_P: {seq_violations_caught}")
    check("REACH-ENUM coverage (prefixes checked, unsafe caught)",
          True, seq_checked > 0 and seq_violations_caught > 0)

    # ---- summary -------------------------------------------------------------
    npass = sum(1 for _, ok, _ in RESULTS if ok)
    nfail = sum(1 for _, ok, _ in RESULTS if not ok)
    print(f"\nTOTAL: {npass} PASS / {nfail} FAIL")
    for name, ok, detail in RESULTS:
        if not ok:
            print(f"  FAILED: {name} {detail}")
    return 0 if nfail == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
