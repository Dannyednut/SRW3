#!/usr/bin/env python3
"""SRW3 Phase 1G — authority-rooted evidence model (Python mirror).

Faithful mirror of phase1g/semantics/srw3authz.k (module SRW3AUTHZ) and the
normative spec phase1g/semantics/MODEL.md. The frozen layers are imported
unchanged: lin_verify (Phase 1D-R1), auth_verify (Phase 1E), exec_model
(Phase 1F). This module adds ONLY the authority extension:

  * authority domains + levels                   (MODEL.md §3)
  * authorized identities (context-derived)      (MODEL.md §5)
  * SecurityContext                              (MODEL.md §7)
  * AuthorityCertificate + canonical encoding    (MODEL.md §3/§6)
  * NoCircularAuthority (own-id, chain checks)   (MODEL.md §4)
  * source authorization + rel/domain mapping    (MODEL.md §5/§9)
  * LinRecG + CanonCoreG + childG                (MODEL.md §8)
  * VerifyLineageG first-fail gate (21 conjuncts)(MODEL.md §9)
  * access-list (BAL) analysis object            (MODEL.md §12)

All digests are keccak256 (pycryptodome), byte-identical to the K layer's
LinH over the same preimages.
"""
from __future__ import annotations

import sys
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Tuple

sys.path.insert(0, "/home/z/my-project/srw3-kevm/python-gen")
sys.path.insert(0, "/home/z/my-project/srw3-kevm/phase1e/python")
sys.path.insert(0, "/home/z/my-project/srw3-kevm/phase1f/python")

from lin_verify import H  # noqa: E402  (keccak256, byte-identical to K LinH)
from exec_model import (ExecCtx, ExEvt, ExecWit, LinRecF, canon_core_f,  # noqa: E402
                        canon_kv, config_digest, exec_id, i2b4, payload_digest,
                        trace_digest, trace_writes, verify_lineage_f,
                        canon_trace)


def i2b1(n: int) -> bytes:
    return (int(n) % (1 << 8)).to_bytes(1, "big")


# =============================================================================
# §0 Authority domains and levels (MODEL.md §3)
# =============================================================================

DOM_CONSENSUS = "consensus"
DOM_EXECUTION = "execution"
DOM_PROOF = "proof"
DOM_POLICY = "policy"


def dom_byte(d: str) -> int:
    return {DOM_CONSENSUS: 1, DOM_EXECUTION: 2, DOM_PROOF: 3, DOM_POLICY: 4}[d]


def dom_level(d: str) -> int:
    return {DOM_CONSENSUS: 0, DOM_POLICY: 0, DOM_EXECUTION: 1, DOM_PROOF: 1}[d]


@dataclass(frozen=True)
class AzSrc:
    dom: str
    sid: bytes
    level: int


@dataclass(frozen=True)
class AzStep:
    dom: str
    sid: bytes
    level: int


# =============================================================================
# §2 Authorized identities — CONTEXT-derived, never certificate-derived
# =============================================================================

def consensus_id(chain_id: bytes) -> bytes:
    return H(i2b1(0xA1) + chain_id)


def exec_client_id(chain_id: bytes, cfg_d: bytes) -> bytes:
    return H(i2b1(0xA2) + chain_id + cfg_d)


def proof_sys_id(pt: int, guest_d: bytes, proof_cfg_d: bytes) -> bytes:
    return H(i2b1(0xA3) + i2b4(pt) + guest_d + proof_cfg_d)


def policy_auth_id(policy_v: int) -> bytes:
    return H(i2b1(0xA4) + i2b4(policy_v))


# =============================================================================
# §3 SecurityContext (MODEL.md §7)
# =============================================================================

@dataclass(frozen=True)
class SecCtx:
    policy_v: int
    chain_id: bytes
    app_set_d: bytes
    graph_d: bytes
    lineage_head: bytes


# =============================================================================
# §4 AuthorityCertificate (MODEL.md §3/§6)
# =============================================================================

@dataclass(frozen=True)
class AuthzCert:
    payload_d: bytes
    parent_root: bytes
    exec_id: bytes
    child_root: bytes
    effect_d: bytes
    rel: int                       # 1 consensus-authorized / 2 re-execution / 3 proof-checked
    src: AzSrc
    chain: Tuple[AzStep, ...] = field(default=())
    policy_v: int = 1
    proof_pub: bytes = b""


def step_canon(s: AzStep) -> bytes:
    return i2b1(dom_byte(s.dom)) + s.sid + i2b4(s.level)


def chain_bytes(chain: Tuple[AzStep, ...]) -> bytes:
    return b"".join(step_canon(s) for s in chain)


def cert_body(c: AuthzCert) -> bytes:
    return (i2b1(0x8C) + c.payload_d + c.parent_root + c.exec_id
            + c.child_root + c.effect_d + i2b1(c.rel)
            + i2b1(dom_byte(c.src.dom)) + c.src.sid + i2b4(c.src.level)
            + chain_bytes(c.chain) + i2b4(c.policy_v) + c.proof_pub)


def cert_id(c: AuthzCert) -> bytes:
    return H(cert_body(c))


def az_proof_pub(payload_d: bytes, parent_root: bytes, chain_id: bytes,
                 schedule: bytes, spec: int, child_root: bytes,
                 policy_v: int, app_set_d: bytes, graph_d: bytes,
                 lineage_head: bytes) -> bytes:
    """proofPub (rel=3 only): the FULL public-input binding — the EIP-8025-
    style payload/chain/fork/child bindings PLUS the SRW3 additions (policy
    version, application set, interaction graph, lineage head)."""
    return H(i2b1(0x8D) + payload_d + parent_root + chain_id + schedule
             + i2b4(spec) + child_root + i2b4(policy_v) + app_set_d + graph_d
             + lineage_head)


# =============================================================================
# §5 NoCircularAuthority (MODEL.md §4)
# =============================================================================

def az_own_in_chain(chain: Tuple[AzStep, ...], cid: bytes) -> bool:
    return any(s.sid == cid for s in chain)


def az_chain_ok(chain: Tuple[AzStep, ...], cur: int, chain_id: bytes,
                cfg_d: bytes, policy_v: int, auth_pt: int,
                auth_guest_d: bytes, auth_cfg_d: bytes) -> bool:
    """Strict level decrease; EVERY step's identity authorized for its
    domain (context-derived); termination at a level-0 protocol root;
    empty chain valid iff cur == 0."""
    if not chain:
        return cur == 0
    s, rest = chain[0], chain[1:]
    if s.level < 0 or s.level >= cur:
        return False
    if not az_src_authorized(AzSrc(s.dom, s.sid, s.level), chain_id, cfg_d,
                             policy_v, auth_pt, auth_guest_d, auth_cfg_d):
        return False
    if s.level == 0 and s.dom in (DOM_CONSENSUS, DOM_POLICY):
        return len(rest) == 0
    return az_chain_ok(rest, s.level, chain_id, cfg_d, policy_v, auth_pt,
                       auth_guest_d, auth_cfg_d)


def az_non_circular(c: AuthzCert, chain_id: bytes, cfg_d: bytes,
                    policy_v: int, auth_pt: int, auth_guest_d: bytes,
                    auth_cfg_d: bytes) -> bool:
    cid = cert_id(c)
    return (c.src.sid != cid
            and not az_own_in_chain(c.chain, cid)
            and az_chain_ok(c.chain, c.src.level, chain_id, cfg_d, policy_v,
                            auth_pt, auth_guest_d, auth_cfg_d))


# =============================================================================
# §6 Source authorization (context-derived; MODEL.md §5)
# =============================================================================

def az_src_authorized(s: AzSrc, chain_id: bytes, cfg_d: bytes,
                      policy_v: int, auth_pt: int, auth_guest_d: bytes,
                      auth_cfg_d: bytes) -> bool:
    if s.dom == DOM_CONSENSUS:
        return s.sid == consensus_id(chain_id)
    if s.dom == DOM_EXECUTION:
        return s.sid == exec_client_id(chain_id, cfg_d)
    if s.dom == DOM_PROOF:
        return s.sid == proof_sys_id(auth_pt, auth_guest_d, auth_cfg_d)
    if s.dom == DOM_POLICY:
        return s.sid == policy_auth_id(policy_v)
    return False


def az_rel_domain(rel: int) -> str:
    return {1: DOM_CONSENSUS, 2: DOM_EXECUTION, 3: DOM_PROOF}[rel]


# =============================================================================
# §7 LinRecG additive record (MODEL.md §8)
# =============================================================================

@dataclass(frozen=True)
class LinRecG:
    base: LinRecF
    az_cert_d: bytes
    az_policy_v: int


def canon_core_g(base: LinRecF, cert_d: bytes, policy_v: int) -> bytes:
    """CanonCoreG = CanonCoreF || azCertD || policyV_4 (CanonCoreF a strict
    PREFIX)."""
    return canon_core_f(base) + cert_d + i2b4(policy_v)


def child_g(base: LinRecF, cert_d: bytes, policy_v: int) -> bytes:
    return H(canon_core_g(base, cert_d, policy_v))


def build_rec_g(base: LinRecF, cert: AuthzCert, policy_v: int) -> LinRecG:
    return LinRecG(base, cert_id(cert), policy_v)


# =============================================================================
# §8 Certificate binding (MODEL.md §9 L28)
# =============================================================================

def az_cert_bind_ok(c: AuthzCert, rg: LinRecG, ctx: ExecCtx,
                    sec: SecCtx) -> bool:
    pub_ok = True
    if c.rel == 3:
        pub_ok = (c.proof_pub == az_proof_pub(
            c.payload_d, c.parent_root, sec.chain_id, ctx.schedule, ctx.spec,
            c.child_root, c.policy_v, sec.app_set_d, sec.graph_d,
            sec.lineage_head))
    else:
        pub_ok = (c.proof_pub == b"")
    return (cert_id(c) == rg.az_cert_d
            and c.payload_d == payload_digest(ctx.payload)
            and c.parent_root == ctx.parent_root
            and c.exec_id == rg.base.exec_id
            and c.child_root == rg.base.base.state_root
            and c.effect_d == rg.base.eff_trace_d
            and pub_ok)


# =============================================================================
# §9 AzCtx and VerifyLineageG (MODEL.md §9)
# =============================================================================

@dataclass(frozen=True)
class AzCtx:
    fctx: ExecCtx
    sec: SecCtx
    cert: AuthzCert
    auth_pt: int = 0                 # the PINNED authorized proof descriptor
    auth_guest_d: bytes = b""
    auth_cfg_d: bytes = b""


def verify_lineage_g(rg: LinRecG, ctx: AzCtx, tid: int, head: bytes) -> str:
    """VerifyLineageG — first-fail; every frozen layer fires first.
    Verdict codes continue the numbering after 1F's L22."""
    base = verify_lineage_f(rg.base, ctx.fctx, tid, head)
    if base != "VALID-F":
        return base

    c = ctx.cert
    sec = ctx.sec
    cfg_d = config_digest(ctx.fctx.schedule, ctx.fctx.spec)

    # L23 — AUTHTYPE
    if c.rel not in (1, 2, 3):
        return "L23-AUTHTYPE"

    # L24 — AUTHREL
    if c.src.dom != az_rel_domain(c.rel):
        return "L24-AUTHREL"

    # L25 — AUTHLEVEL
    if c.src.level != dom_level(c.src.dom):
        return "L25-AUTHLEVEL"

    # L26 — AUTHCIRCLE (NoCircularAuthority; before AUTHSRC by design)
    if not az_non_circular(c, sec.chain_id, cfg_d, sec.policy_v,
                           ctx.auth_pt, ctx.auth_guest_d, ctx.auth_cfg_d):
        return "L26-AUTHCIRCLE"

    # L27 — AUTHSRC
    if not az_src_authorized(c.src, sec.chain_id, cfg_d, sec.policy_v,
                             ctx.auth_pt, ctx.auth_guest_d, ctx.auth_cfg_d):
        return "L27-AUTHSRC"

    # L28 — AUTHBIND
    if not az_cert_bind_ok(c, rg, ctx.fctx, sec):
        return "L28-AUTHBIND"

    # L29 — POLICY
    if c.policy_v != sec.policy_v:
        return "L29-POLICY"

    return "VALID-G"


# =============================================================================
# §10 Access-list (BAL) analysis object (MODEL.md §12) — ANALYSIS ONLY
# =============================================================================

@dataclass(frozen=True)
class BalEntry:
    app: int
    slot: int
    has_post: bool
    post: int


def bal_canon(bal: List[BalEntry]) -> bytes:
    out = i2b1(0x8E) + i2b4(len(bal))
    for e in bal:
        out += (i2b4(e.app) + i2b4(e.slot) + i2b1(1 if e.has_post else 0)
                + i2b4(e.post))
    return out


def _flat(app: int, slot: int) -> int:
    return app * (1 << 32) + slot


def bal_touched(trace: List[ExEvt]) -> Dict[int, int]:
    touched: Dict[int, int] = {}
    for e in trace:
        if e.op in (1, 2):   # Read or Write
            touched[_flat(e.app, e.a1)] = 1
    return touched


def bal_footprint_ok(bal: List[BalEntry], trace: List[ExEvt]) -> bool:
    keys = {_flat(e.app, e.slot) for e in bal}
    return keys == set(bal_touched(trace).keys())


def bal_writes_ok(bal: List[BalEntry], trace: List[ExEvt],
                  pre: Dict[int, Dict[int, int]]) -> bool:
    """Post-value binding: written locations bind the LAST write; read-only
    locations bind the CURRENT (pre-state) value — what a read would
    observe. The BAL records what IS, never what was OBSERVED."""
    writes = trace_writes(trace)

    def last_write(app: int, slot: int) -> Optional[int]:
        return writes.get(app, {}).get(slot)

    for e in bal:
        if not e.has_post:
            continue
        lw = last_write(e.app, e.slot)
        if lw is not None:
            if e.post != lw:
                return False
        else:
            if e.post != pre.get(e.app, {}).get(e.slot, 0):
                return False
    return True
