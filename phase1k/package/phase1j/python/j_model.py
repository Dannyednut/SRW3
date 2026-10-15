#!/usr/bin/env python3
# =============================================================================
# SRW3 Phase 1J — Python executable reference of the ISOLATED J machine
# (j_model.py)
#
# ROLE: executable CROSS-LAYER correspondence evidence — NOT a formal proof.
# This module mirrors the K definitions in phase1j/semantics/srw3closure-j.k
# and drives the REAL frozen gate: `verify_lineage_g` is imported UNCHANGED
# from the Phase 1G model (phase1g/python/authz_model.py).  All digests are
# real keccak-256 (original Keccak padding, byte-identical to K's LinH =
# Keccak256raw over the same preimages).  SHA3-256 is NEVER substituted.
#
# MIRRORED SEMANTICS (K <-> Python, cross-checked by run_j_attacks.py against
# the K krun transcripts and the golden vectors):
#   JCatalogCanonJ  = "SRW3/PolicyCat/J"||0x00 || U32BE(1) || U32BE(policyV)
#                     || U32BE(#apps)  || (U32BE(id) || LP32(name))*
#                     || U32BE(#res)   || (KEY8 || U32BE(owner))*
#                     || U32BE(#hyper) || (U32BE(heId) || U32BE(n) || KEY8^n)*
#                     || U32BE(#loc) || JCanonInv* || U32BE(#hyp) || JCanonInv*
#                     || U32BE(#glob) || JCanonInv*
#   JCanonInv       = U32BE(id) || U32BE(kind: 1=local,2=sum,3=eq)
#                     || U32BE(heId) || U32BE(lo/cap) || U32BE(hi)
#                     || U32BE(nKeys) || KEY8^n
#   KEY8            = 8-byte big-endian flat key (app*2^32 + slot — 64-bit)
#   JAppSetRootJ    = K(0xB1 || appsCanon || resourcesCanon)
#   JGraphRootJ     = K(0xB2 || hyperCanon)
#   JPolicyRootJ    = K(0xB3 || localsCanon || hypInvCanon || globalsCanon)
#   JCatalogRootJ   = K(JCatalogCanonJ)
#   StateRootJ      = K(0xB4 || LinCanonKV(state))       [frozen canon, new tag]
#   JProgBytesJ     = U32BE(#ops) || (op1 || app4 || a1-8 || a2-8)*
#   JPayloadDigestJ = ExecPayloadDigest(JProgBytesJ)     [FROZEN 1F formula:
#                     K(0x11 || bytes) — the certificate's digest family]
#   JFootprintCanonJ= 0xB7 || U32BE(#keys) || KEY8^n  (first-occurrence order)
#   JBlockCommitJ   = K(0xB6 || parentCommit || payloadD || parentRoot
#                     || postRoot || traceD || footD || evidenceId
#                     || catalogRoot || configRoot || execSrc
#                     || I2B4(decision) || I2B4(slot) || PolicyCommitmentR3)
#   EvidenceCanonJ  = "SRW3/Evidence/J"||0x00 || U32BE(1) || LP32(configRoot)
#                     || LP32(catalogRoot) || LP32(chainId) || LP32(fork)
#                     || LP32(parentStateRootJ) || LP32(payloadDigestJ)
#                     || LP32(execSourceId) || LP32(postStateRootJ)
#                     || LP32(traceDigest) || LP32(footprintDigest)
#                     || LP32(policyCtxDigest)
#   JPolicyCtxDigest= K(0xB5 || LP32(configRoot) || LP32(catalogRoot)
#                     || U32BE(policyV))
#   ProtoCfgCanonR3 / PolicyCommitmentR3 / CtxDigestR3 — the FROZEN R3/1I
#   formulas, reproduced byte-identically (tags 0x9D/0xA5/0xA6/0x9E;
#   "SRW3/ProtoCfg/R3") — the same bytes the R3 machine computes.
#
# THE EXECUTION FRAGMENT (EVM_F, Option A): the four-op vocabulary
# (Read/Write/Call/Return) interpreted over the nested state; jUnsupported(n)
# and out-of-range operands are EXPLICIT refusals (no post-state, no receipt).
# =============================================================================
import sys
from dataclasses import dataclass, field

HERE = __file__
REPO = "/".join(HERE.split("/")[:-3])
JDIR = "/".join(HERE.split("/")[:-1])

for p in (f"{REPO}/python-gen", f"{REPO}/phase1e/python", f"{REPO}/phase1f/python",
          f"{REPO}/phase1g/python", f"{REPO}/phase1i-r1/python",
          f"{REPO}/phase1i-r2/python", f"{REPO}/phase1i-r3/python", JDIR):
    if p not in sys.path:
        sys.path.insert(0, p)

from lin_verify import H, LinCtx, addr_of, canon_kv  # noqa: E402  (H = keccak256)
from auth_model import auth_root, canon_union  # noqa: E402
from auth_verify import AuthCtxA  # noqa: E402
from exec_model import (ExEvt, ExecCtx, ExecWit, OP_READ, OP_WRITE,  # noqa: E402
                        OP_CALL, OP_RETURN)
from authz_model import (AuthzCert, AzCtx, AzSrc, AzStep, SecCtx,  # noqa: E402
                         verify_lineage_g)
from exec_model import child_f as _child_f  # noqa: E402
from pi_r1_model import keccak256, I2B4  # noqa: E402
from r3_model import (ProtoCfgR3 as _PackCfg, ProtoRootR3,  # noqa: E402
                      policy_commitment_r3, CtxDigestR3, authorized_sec_ctx_r3,
                      ProtoDecisionOfGateR3, GateInputMatchesBlockR3,
                      GateAuthorityMatchesCfgR3, GateCtxAuthorizedR3, R3RecChildF)

PDEC_VALID_J, PDEC_REJECT_J, PDEC_UNKNOWN_J = 1, 0, 2
BOUND_APP = 1 << 32
BOUND_VAL = 1 << 64


def u32(x: int) -> bytes:
    if not isinstance(x, int) or isinstance(x, bool):
        raise TypeError("u32 expects int")
    if x < 0 or x > 0xFFFFFFFF:
        raise ValueError("u32 out of range")
    return x.to_bytes(4, "big")


def u64(x: int) -> bytes:
    if not isinstance(x, int) or isinstance(x, bool):
        raise TypeError("u64 expects int")
    if x < 0 or x > (1 << 64) - 1:
        raise ValueError("u64 out of range")
    return x.to_bytes(8, "big")


def key8(k: int) -> bytes:
    """the 64-bit flat resource key encoding"""
    return u64(k)


def a2key(app: int, slot: int) -> int:
    return app * BOUND_APP + slot


def lp32(b: bytes) -> bytes:
    return u32(len(b)) + b


# ---------------------------------------------------------------------------
# the catalog
# ---------------------------------------------------------------------------
@dataclass(frozen=True)
class JApp:
    app_id: int
    name: bytes


@dataclass(frozen=True)
class JResource:
    key: int
    owner: int


@dataclass(frozen=True)
class JHyper:
    he_id: int
    nodes: tuple


@dataclass(frozen=True)
class JInv:
    inv_id: int
    kind: int          # 1 local, 2 sum, 3 eq
    he_id: int         # 0 for locals/globals
    key: int           # local
    keys: tuple        # sum/eq
    lo: int            # local lo / sum cap
    hi: int            # local hi


def jinv_local(i, key, lo, hi):
    return JInv(i, 1, 0, key, (), lo, hi)


def jinv_sum(i, he, keys, cap):
    return JInv(i, 2, he, 0, tuple(keys), cap, 0)


def jinv_eq(i, he, keys):
    return JInv(i, 3, he, 0, tuple(keys), 0, 0)


@dataclass(frozen=True)
class JCatalog:
    policy_v: int
    apps: tuple
    resources: tuple
    hypers: tuple
    locals: tuple
    hyper_invs: tuple
    globals: tuple


def j_canon_apps(apps) -> bytes:
    out = b""
    for a in apps:
        out += u32(a.app_id) + lp32(a.name)
    return out


def j_canon_resources(res) -> bytes:
    out = b""
    for r in res:
        out += key8(r.key) + u32(r.owner)
    return out


def j_canon_hypers(hyp) -> bytes:
    out = b""
    for h in hyp:
        out += u32(h.he_id) + u32(len(h.nodes)) + b"".join(key8(k) for k in h.nodes)
    return out


def j_canon_inv(v: JInv) -> bytes:
    # kind 1 (local): nKeys=1 and the single bound key (mirrors the K
    # JCanonInv jInvLocal rule); kinds 2/3: the key list
    if v.kind == 1:
        return (u32(v.inv_id) + u32(v.kind) + u32(v.he_id) + u32(v.lo)
                + u32(v.hi) + u32(1) + key8(v.key))
    return (u32(v.inv_id) + u32(v.kind) + u32(v.he_id) + u32(v.lo) + u32(v.hi)
            + u32(len(v.keys)) + b"".join(key8(k) for k in v.keys))


def j_canon_invs(invs) -> bytes:
    return b"".join(j_canon_inv(v) for v in invs)


def j_catalog_canon(p: JCatalog) -> bytes:
    return (b"SRW3/PolicyCat/J\x00" + u32(1) + u32(p.policy_v)
            + u32(len(p.apps)) + j_canon_apps(p.apps)
            + u32(len(p.resources)) + j_canon_resources(p.resources)
            + u32(len(p.hypers)) + j_canon_hypers(p.hypers)
            + u32(len(p.locals)) + j_canon_invs(p.locals)
            + u32(len(p.hyper_invs)) + j_canon_invs(p.hyper_invs)
            + u32(len(p.globals)) + j_canon_invs(p.globals))


def j_app_set_root(p: JCatalog) -> bytes:
    return H(b"\xb1" + j_canon_apps(p.apps) + j_canon_resources(p.resources))


def j_graph_root(p: JCatalog) -> bytes:
    return H(b"\xb2" + j_canon_hypers(p.hypers))


def j_policy_root(p: JCatalog) -> bytes:
    return H(b"\xb3" + j_canon_invs(p.locals)
             + j_canon_invs(p.hyper_invs) + j_canon_invs(p.globals))


def j_catalog_root(p: JCatalog) -> bytes:
    return H(j_catalog_canon(p))


# well-formedness (fail-closed; mirrors JCatalogWF)
def j_catalog_wf(p: JCatalog) -> bool:
    app_ids = [a.app_id for a in p.apps]
    res_keys = [r.key for r in p.resources]
    he_ids = [h.he_id for h in p.hypers]
    if len(p.apps) < 1:
        return False
    if len(app_ids) != len(set(app_ids)):
        return False
    if len(res_keys) != len(set(res_keys)):
        return False
    if len(he_ids) != len(set(he_ids)):
        return False
    inv_ids = ([v.inv_id for v in p.locals] + [v.inv_id for v in p.hyper_invs]
               + [v.inv_id for v in p.globals])
    if len(inv_ids) != len(set(inv_ids)):
        return False
    if any(r.owner not in app_ids for r in p.resources):
        return False
    if any(not set(h.nodes) <= set(res_keys) for h in p.hypers):
        return False
    for lst in (p.locals, p.hyper_invs, p.globals):
        for v in lst:
            ks = (v.key,) if v.kind == 1 else v.keys
            if any(k not in res_keys for k in ks):
                return False
    for v in p.hyper_invs:
        if v.kind in (2, 3) and v.he_id not in he_ids:
            return False
    return True


# ---------------------------------------------------------------------------
# the state (nested app -> slot -> value) + the flat-key reader
# ---------------------------------------------------------------------------
def state_get(st: dict, key: int) -> int:
    app, slot = key // BOUND_APP, key % BOUND_APP
    return st.get(app, {}).get(slot, 0)


def state_write(st: dict, app: int, slot: int, val: int) -> dict:
    out = {a: dict(s) for a, s in st.items()}
    out.setdefault(app, {})[slot] = val
    return out


def state_root(st: dict) -> bytes:
    """StateRootJ = K(0xB4 || LinCanonKV) — the frozen ascending nested canon"""
    return H(b"\xb4" + canon_kv(st))


# ---------------------------------------------------------------------------
# the closed fragment EVM_F
# ---------------------------------------------------------------------------
class JExecUnsupported(Exception):
    def __init__(self, op):
        self.op = op


class JExecBounds(Exception):
    def __init__(self, op):
        self.op = op


def exec_fragment(st: dict, prog):
    """returns (post, eff, trace); raises JExecUnsupported/JExecBounds"""
    post = {a: dict(s) for a, s in st.items()}
    eff: dict = {}
    trace = []
    for op in prog:
        kind = op[0]
        if kind == "unsupported":
            raise JExecUnsupported(op[1])
        if kind == "read":
            a, s = op[1], op[2]
            _bounds_op(OP_READ, a, s, 0)
            trace.append(ExEvt(OP_READ, a, s, state_get(post, a2key(a, s))))
        elif kind == "write":
            a, s, v = op[1], op[2], op[3]
            _bounds_op(OP_WRITE, a, s, v)
            post = state_write(post, a, s, v)
            eff = state_write(eff, a, s, v)
            trace.append(ExEvt(OP_WRITE, a, s, v))
        elif kind == "call":
            a, t, v = op[1], op[2], op[3]
            _bounds_op(OP_CALL, a, t, v)
            trace.append(ExEvt(OP_CALL, a, t, v))
        elif kind == "return":
            a, o, z = op[1], op[2], op[3]
            _bounds_op(OP_RETURN, a, o, z)
            trace.append(ExEvt(OP_RETURN, a, o, z))
        else:
            raise JExecUnsupported(-1)
    return post, eff, trace


def _bounds_op(code, a, b, c):
    if not (0 <= a < BOUND_APP and 0 <= b < BOUND_APP and 0 <= c < BOUND_VAL):
        raise JExecBounds(code)


def prog_bytes(prog) -> bytes:
    out = b""
    for op in prog:
        kind = op[0]
        if kind == "read":
            out += bytes([1]) + u32(op[1]) + u64(op[2])
        elif kind == "write":
            out += bytes([2]) + u32(op[1]) + u64(op[2]) + u64(op[3])
        elif kind == "call":
            out += bytes([3]) + u32(op[1]) + u64(op[2]) + u64(op[3])
        elif kind == "return":
            out += bytes([4]) + u32(op[1]) + u64(op[2]) + u64(op[3])
        elif kind == "unsupported":
            out += bytes([255]) + u64(op[1])
    return u32(len(prog)) + out


def payload_digest(prog) -> bytes:
    """the FROZEN 1F payload-digest formula over the canonical program bytes"""
    return H(b"\x11" + prog_bytes(prog))


def trace_digest(trace) -> bytes:
    return H(b"\x03" + u32(len(trace))
             + b"".join(bytes([e.op]) + u32(e.app) + u64(e.a1) + u64(e.a2)
                        for e in trace))


def footprint_keys(trace):
    out = []
    for e in trace:
        k = a2key(e.app, e.a1)
        if k not in out:
            out.append(k)
    return out


FOOT_TAG = 0xB7


def footprint_canon(trace) -> bytes:
    ks = footprint_keys(trace)
    return bytes([FOOT_TAG]) + u32(len(ks)) + b"".join(key8(k) for k in ks)


def footprint_digest(trace) -> bytes:
    return H(footprint_canon(trace))


# ---------------------------------------------------------------------------
# the typed invariant fragment + Safe_P (independent of the gate)
# ---------------------------------------------------------------------------
def inv_holds(v: JInv, st: dict) -> bool:
    if v.kind == 1:
        return v.lo <= state_get(st, v.key) <= v.hi
    if v.kind == 2:
        return sum(state_get(st, k) for k in v.keys) <= v.lo  # lo == cap
    if v.kind == 3:
        vals = [state_get(st, k) for k in v.keys]
        return all(x == vals[0] for x in vals)
    raise ValueError(v.kind)


def safe_j(p: JCatalog, st: dict) -> bool:
    return (all(inv_holds(v, st) for v in p.locals)
            and all(inv_holds(v, st) for v in p.hyper_invs)
            and all(inv_holds(v, st) for v in p.globals))


# ---------------------------------------------------------------------------
# the bounded hypergraph closure
# ---------------------------------------------------------------------------
def he_touches(h: JHyper, aff) -> bool:
    return any(k in h.nodes for k in aff)


def list_union(add, acc):
    out = list(acc)
    for k in add:
        if k not in out:
            out.append(k)
    return out


def incident_union(aff, hypers):
    out = []
    for h in hypers:
        if he_touches(h, aff):
            out = list_union(h.nodes, out)
    return out


def affected_closure(aff, hypers, fuel):
    """mirrors AffectedClosureJ: least closure under fuel; exhaustion =>
    jClosureExhausted (raised as JClosureExhausted); never 'no more
    interactions'"""
    cur = list(aff)
    for _ in range(fuel):
        inc = incident_union(cur, hypers)
        new = [k for k in inc if k not in cur]
        if not new:
            return cur
        cur = list_union(inc, cur)
    inc = incident_union(cur, hypers)
    if all(k in cur for k in inc):
        return cur
    raise JClosureExhausted()


class JClosureExhausted(Exception):
    pass


def footprint_registered(trace, p: JCatalog) -> bool:
    res_keys = {r.key for r in p.resources}
    return all(k in res_keys for k in footprint_keys(trace))


# ---------------------------------------------------------------------------
# the R3 configuration formulas (frozen, byte-identical) — re-exported from
# the R3 mirror; the J machine pins the SAME ProtoCfgR3 and root
# ---------------------------------------------------------------------------
ProtoCfgCanonR3_bytes = None  # set below via the pack encoder


def policy_ctx_digest(cfg_root: bytes, cat_root: bytes, policy_v: int) -> bytes:
    """JPolicyCtxDigestJ — NEW tag 0xB5"""
    return H(b"\xb5" + lp32(cfg_root) + lp32(cat_root) + u32(policy_v))


def evidence_canon(cfg_root, cat_root, chain_id, fork, parent_root_j,
                   pld_digest, exec_src, post_root_j, tr_digest, foot_digest,
                   pol_ctx) -> bytes:
    return (b"SRW3/Evidence/J\x00" + u32(1)
            + lp32(cfg_root) + lp32(cat_root) + lp32(chain_id) + lp32(fork)
            + lp32(parent_root_j) + lp32(pld_digest) + lp32(exec_src)
            + lp32(post_root_j) + lp32(tr_digest) + lp32(foot_digest)
            + lp32(pol_ctx))


def evidence_id(cfg_root, cat_root, chain_id, fork, parent_root_j,
                pld_digest, exec_src, post_root_j, tr_digest, foot_digest,
                pol_ctx) -> bytes:
    return H(evidence_canon(cfg_root, cat_root, chain_id, fork, parent_root_j,
                            pld_digest, exec_src, post_root_j, tr_digest,
                            foot_digest, pol_ctx))


BLOCK_TAG_J = 0xB6


def block_commit_j(b: "JBlockJ", cfg: _PackCfg) -> bytes:
    return H(bytes([BLOCK_TAG_J]) + b.parent_commit + b.payload_d
             + b.parent_root + b.post_root + b.trace_d + b.foot_d
             + b.evidence_id + b.catalog_root + b.config_root + b.exec_src
             + I2B4(b.decision) + I2B4(b.slot)
             + policy_commitment_r3(cfg))


@dataclass(frozen=True)
class JBlockJ:
    parent_commit: bytes
    payload_d: bytes
    parent_root: bytes
    post_root: bytes
    trace_d: bytes
    foot_d: bytes
    evidence_id: bytes
    catalog_root: bytes
    config_root: bytes
    exec_src: bytes
    decision: int
    slot: int


@dataclass(frozen=True)
class JExecReceipt:
    payload: bytes
    caller: bytes
    value: int
    pre: dict
    eff: dict
    post: dict
    trace: tuple
    pre_root: bytes
    post_root: bytes
    trace_d: bytes
    foot_d: bytes
    payload_d: bytes
    exec_src: bytes
    cfg_root: bytes
    cat_root: bytes
    anchor: bytes
    head: bytes
    slot: int
    lin_head: bytes
    evidence_id: bytes


def exec_valid_pj(b: JBlockJ, erc: bytes, erp: bytes) -> bool:
    return b.post_root == erc and b.payload_d == erp


def gate_input_matches_block_j(fc: ExecCtx, rg, cert: AuthzCert,
                               b: JBlockJ) -> bool:
    return (cert.payload_d == b.payload_d
            and fc.parent_root == b.parent_root
            and rg.base.eff_trace_d == b.trace_d
            and rg.az_cert_d == b.evidence_id)


def exec_receipt_matches_block_j(e: JExecReceipt, b: JBlockJ) -> bool:
    return (e.payload_d == b.payload_d
            and e.post_root == b.post_root
            and e.trace_d == b.trace_d
            and e.foot_d == b.foot_d
            and e.exec_src == b.exec_src
            and e.cfg_root == b.config_root
            and e.cat_root == b.catalog_root)


def exec_receipt_matches_record_j(e: JExecReceipt, rg) -> bool:
    return e.trace_d == rg.base.eff_trace_d


# ---------------------------------------------------------------------------
# THE ISOLATED J MACHINE (executable reference)
# ---------------------------------------------------------------------------
class JMachine:
    """The J machine: init/exec/gate/commit with fail-closed rejects.  The
    anchor is set ONCE at construction from OUTSIDE the command API (the
    trusted protocol channel model); no API can rewrite it."""

    REFUSE_NONE = ("none",)
    REFUSE_UNSUPPORTED = ("unsupported",)
    REFUSE_BOUNDS = ("bounds",)
    REFUSE_SOURCE = ("source",)

    def __init__(self, anchor: bytes, closure_fuel: int = 8):
        self.anchor = anchor
        self.fuel = closure_fuel
        self.cfg: _PackCfg = None
        self.cat: JCatalog = None
        self.lineage: dict = {}       # slot -> JBlockJ
        self.gate_receipts: list = []
        self.exec_receipts: list = []
        self.next_slot = 0
        self.head = (0).to_bytes(1, "big")
        self.lin_head = bytes(32)
        self.state: dict = {}
        self.refuse = self.REFUSE_NONE
        self.initialized = False

    # -- pInitJ ------------------------------------------------------------
    def init(self, cfg: _PackCfg, cat: JCatalog) -> bool:
        if self.initialized:
            return False
        if ProtoRootR3(cfg) != self.anchor:
            return False
        if not j_catalog_wf(cat):
            return False
        if j_app_set_root(cat) != cfg.app_set_digest:
            return False
        if j_graph_root(cat) != cfg.graph_digest:
            return False
        if j_policy_root(cat) != cfg.policy_digest:
            return False
        if cat.policy_v != cfg.policy_version:
            return False
        if not safe_j(cat, {}):
            return False
        self.cfg, self.cat = cfg, cat
        self.head = ProtoRootR3(cfg)
        self.lin_head = bytes(32)
        self.initialized = True
        return True

    # -- pExecJ ------------------------------------------------------------
    def exec(self, src: bytes, prog, caller: bytes, value: int):
        """mints a JExecReceipt on success; returns (True, receipt) or
        (False, refusal) — a refusal leaves NO receipt and NO state change"""
        if not self.initialized:
            return False, self.REFUSE_NONE
        if src != self.cfg.execution_client_digest:
            self.refuse = self.REFUSE_SOURCE
            return False, self.REFUSE_SOURCE
        try:
            post, eff, trace = exec_fragment(self.state, prog)
        except JExecUnsupported as ex:
            self.refuse = (self.REFUSE_UNSUPPORTED[0], ex.op)
            return False, self.refuse
        except JExecBounds as ex:
            self.refuse = (self.REFUSE_BOUNDS[0], ex.op)
            return False, self.refuse
        cat_root = j_catalog_root(self.cat)
        cfg_root = ProtoRootR3(self.cfg)
        pre_root = state_root(self.state)
        post_root = state_root(post)
        tr_d = trace_digest(trace)
        foot_d = footprint_digest(trace)
        pld_d = payload_digest(prog)
        pol_ctx = policy_ctx_digest(cfg_root, cat_root, self.cfg.policy_version)
        eid = evidence_id(cfg_root, cat_root, self.cfg.chain_id, self.cfg.fork,
                          pre_root, pld_d, src, post_root, tr_d, foot_d,
                          pol_ctx)
        rec = JExecReceipt(prog_bytes(prog), caller, value, self.state, eff,
                           post, tuple(trace), pre_root, post_root, tr_d,
                           foot_d, pld_d, src, cfg_root, cat_root, self.anchor,
                           self.head, self.next_slot, self.lin_head, eid)
        self.exec_receipts.append(rec)
        return True, rec

    # -- pGateEvalJ --------------------------------------------------------
    def gate_eval(self, b: JBlockJ, fc: ExecCtx, rg, cert: AuthzCert,
                  erc: bytes, erp: bytes):
        """mints a JGateReceipt (verdict COMPUTED by the frozen gate); the
        derived-execution correspondence is enforced here"""
        if not self.initialized:
            return None
        if not gate_input_matches_block_j(fc, rg, cert, b):
            return None
        if not (fc.schedule == self.cfg.schedule and fc.spec == self.cfg.spec_version):
            return None
        if b.parent_commit != self.head or b.slot != self.next_slot:
            return None
        match = [e for e in self.exec_receipts
                 if exec_receipt_matches_block_j(e, b)
                 and exec_receipt_matches_record_j(e, rg)
                 and e.head == self.head and e.slot == self.next_slot
                 and e.lin_head == self.lin_head and e.anchor == self.anchor]
        if not match:
            return None
        e = match[0]
        sec = authorized_sec_ctx_r3(self.cfg, b.parent_root)
        ac = AzCtx(fc, sec, cert, self.cfg.authority_proof_type,
                   self.cfg.authority_guest_digest, self.cfg.authority_config_digest)
        from r3_model import verdict_k
        verdict = verdict_k(verify_lineage_g(rg, ac, self.next_slot,
                                             self.lin_head))
        rec = JGateReceipt(b, erc, erp, fc, rg, cert, ac, e, verdict, self.head,
                           self.next_slot, self.lin_head, self.cfg,
                           ProtoRootR3(self.cfg), self.anchor,
                           j_catalog_root(self.cat))
        self.gate_receipts.append(rec)
        return rec

    # -- pCommitJ — the ONE chain-extending rule ---------------------------
    def commit(self, b: JBlockJ, erc: bytes, erp: bytes, cv: int):
        if not self.initialized:
            return False
        match = [r for r in self.gate_receipts
                 if r.block == b and r.erc == erc and r.erp == erp
                 and r.head == self.head and r.slot == self.next_slot
                 and r.lin_head == self.lin_head
                 and cfg_eq(r.cfg, self.cfg) and r.anchor == self.anchor]
        if not match:
            return False
        r = match[0]
        if ProtoDecisionOfGateR3(r.verdict) != PDEC_VALID_J:
            return False
        if b.decision != PDEC_VALID_J:
            return False
        if not exec_valid_pj(b, erc, erp):
            return False
        if r.exec.cfg_root != ProtoRootR3(self.cfg):
            return False
        if r.exec.cat_root != j_catalog_root(self.cat):
            return False
        if b.parent_commit != self.head or b.slot != self.next_slot:
            return False
        if cv != self.cfg.policy_version:
            return False
        # THE COMPUTED J POLICY RESULT (never caller-supplied)
        try:
            aff = affected_closure(footprint_keys(r.exec.trace),
                                   self.cat.hypers, self.fuel)
        except JClosureExhausted:
            return False
        if not footprint_registered(r.exec.trace, self.cat):
            return False
        if not safe_j(self.cat, r.exec.post):
            return False
        # ACCEPT: consume BOTH receipts exactly once; move the state
        self.gate_receipts.remove(r)
        self.exec_receipts.remove(r.exec)
        self.lineage[b.slot] = b
        self.head = block_commit_j(b, self.cfg)
        self.lin_head = rec_child(r.rg)
        self.state = r.exec.post
        self.next_slot += 1
        return True


class JGateReceipt:
    def __init__(self, block, erc, erp, fc, rg, cert, ac, exec_rec, verdict,
                 head, slot, lin_head, cfg, root, anchor, cat_root):
        self.block = block
        self.erc = erc
        self.erp = erp
        self.fc = fc
        self.rg = rg
        self.cert = cert
        self.ac = ac
        self.exec = exec_rec
        self.verdict = verdict
        self.head = head
        self.slot = slot
        self.lin_head = lin_head
        self.cfg = cfg
        self.root = root
        self.anchor = anchor
        self.cat_root = cat_root


def cfg_eq(a: _PackCfg, b: _PackCfg) -> bool:
    return a == b


def rec_child(rg) -> bytes:
    return _child_f(rg.base)
