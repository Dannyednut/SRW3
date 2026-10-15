#!/usr/bin/env python3
# =============================================================================
# SRW3 Phase 1I-R1 — Python executable reference of the REPAIRED protocol
# model (pi_r1_model.py)
#
# ROLE (handoff): "Keep the Python protocol model as an executable reference,
# not as a substitute for K proofs."  This module mirrors the K definitions
# in phase1i/semantics/srw3proto.k (frozen predicates, UNCHANGED byte
# encodings) and the repaired transition in
# phase1i-r1/semantics/srw3proto-r1.k (gate receipts, pinned configuration,
# full operational guard).  All digests are REAL keccak-256 (original Keccak
# padding, matching K's Keccak256raw).
#
# Two transition logics live here:
#   * FrozenLogic  — the frozen Phase 1I pAccept (caller-supplied Bool, no
#                    stored configuration).  Used ONLY to witness the
#                    before-side of the counterexamples.
#   * RepairedLogic — the R1 transition (pInitR1 / pGateEval / pAcceptR1).
#
# Canonical byte encodings (byte-identical to the K model):
#   ProtoCfgCanon   = 0x9C || chainId || I2B4(policyV) || policyD || appSetD
#                     || graphD || clientCfgD || execClientD || fork
#   PolicyAuthId    = K(0xA5 || chainId || fork)
#   PolicyCommitI   = K(0x9D || I2B4(policyV) || policyD || appSetD || graphD
#                     || PolicyAuthId)
#   CtxCanonI       = 0xA6 || I2B4(policyV) || chainId || appSetD || graphD
#                     || lineageHead
#   CtxDigestI      = K(CtxCanonI)
#   BlockCommitCanon= 0x9E || parentCommit || payloadD || parentRoot
#                     || childRoot || effectD || evidenceD || ctxD
#                     || polCommit || I2B4(decision) || I2B4(slot)
#   BlockCommitI    = K(BlockCommitCanon(B, PolicyCommitI(C)))
#   SRW3RootI       = K(0x9F || parentCommit || PolicyCommitI || ctxD
#                     || evidenceD || I2B4(decision))
# =============================================================================
import hashlib

try:
    from Crypto.Hash import keccak as _kc

    def keccak256(b: bytes) -> bytes:
        h = _kc.new(digest_bits=256)
        h.update(b)
        return h.digest()
except ImportError:  # pragma: no cover - fallback to the repo reference
    import sys, os
    sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..", "scripts"))
    from keccak_ref import keccak256  # type: ignore


def I2B4(n: int) -> bytes:
    return int(n).to_bytes(4, "big")


PDEC_VALID, PDEC_REJECT, PDEC_UNKNOWN = 1, 0, 2


def ProtoDecisionOfGate(verdict: str) -> int:
    """Frozen total mapping: ONLY 'valid-g' is protocol-valid (fail-closed)."""
    return PDEC_VALID if verdict == "valid-g" else PDEC_REJECT


# ---------------------------------------------------------------------------
# Frozen predicate layer (mirrors srw3proto.k sections 1-5, unchanged)
# ---------------------------------------------------------------------------
class ProtoCfg:
    __slots__ = ("chain_id", "policy_v", "policy_d", "app_set_d", "graph_d",
                 "client_cfg_d", "exec_client_d", "fork")

    def __init__(self, chain_id, policy_v, policy_d, app_set_d, graph_d,
                 client_cfg_d, exec_client_d, fork):
        self.chain_id = chain_id
        self.policy_v = policy_v
        self.policy_d = policy_d
        self.app_set_d = app_set_d
        self.graph_d = graph_d
        self.client_cfg_d = client_cfg_d
        self.exec_client_d = exec_client_d
        self.fork = fork

    def canon(self) -> bytes:
        return (b"\x9c" + self.chain_id + I2B4(self.policy_v) + self.policy_d
                + self.app_set_d + self.graph_d + self.client_cfg_d
                + self.exec_client_d + self.fork)

    def proto_root(self) -> bytes:
        return keccak256(self.canon())

    def policy_auth_id(self) -> bytes:
        return keccak256(b"\xa5" + self.chain_id + self.fork)

    def policy_commitment(self) -> bytes:
        return keccak256(b"\x9d" + I2B4(self.policy_v) + self.policy_d
                         + self.app_set_d + self.graph_d
                         + self.policy_auth_id())

    def authorized_sec_ctx(self, lineage_head: bytes) -> "SecCtx":
        return SecCtx(self.policy_v, self.chain_id, self.app_set_d,
                      self.graph_d, lineage_head)

    def __eq__(self, other):
        return isinstance(other, ProtoCfg) and self.canon() == other.canon()

    def __hash__(self):
        return hash(self.canon())


class SecCtx:
    __slots__ = ("policy_v", "chain_id", "app_set_d", "graph_d", "lineage_head")

    def __init__(self, policy_v, chain_id, app_set_d, graph_d, lineage_head):
        self.policy_v = policy_v
        self.chain_id = chain_id
        self.app_set_d = app_set_d
        self.graph_d = graph_d
        self.lineage_head = lineage_head

    def canon(self) -> bytes:
        return (b"\xa6" + I2B4(self.policy_v) + self.chain_id + self.app_set_d
                + self.graph_d + self.lineage_head)

    def digest(self) -> bytes:
        return keccak256(self.canon())


class ProtoBlock:
    __slots__ = ("parent_commit", "payload_d", "parent_root", "child_root",
                 "effect_d", "evidence_d", "ctx_d", "pol_commit", "decision",
                 "slot")

    def __init__(self, parent_commit, payload_d, parent_root, child_root,
                 effect_d, evidence_d, ctx_d, pol_commit, decision, slot):
        self.parent_commit = parent_commit
        self.payload_d = payload_d
        self.parent_root = parent_root
        self.child_root = child_root
        self.effect_d = effect_d
        self.evidence_d = evidence_d
        self.ctx_d = ctx_d
        self.pol_commit = pol_commit
        self.decision = decision
        self.slot = slot

    def fields(self):
        return (self.parent_commit, self.payload_d, self.parent_root,
                self.child_root, self.effect_d, self.evidence_d, self.ctx_d,
                self.pol_commit, self.decision, self.slot)

    def __eq__(self, other):
        return isinstance(other, ProtoBlock) and self.fields() == other.fields()

    def __hash__(self):
        return hash(self.fields())

    def block_commit_canon(self, pol_commit: bytes) -> bytes:
        return (b"\x9e" + self.parent_commit + self.payload_d
                + self.parent_root + self.child_root + self.effect_d
                + self.evidence_d + self.ctx_d + pol_commit
                + I2B4(self.decision) + I2B4(self.slot))

    def block_commitment(self, cfg: ProtoCfg) -> bytes:
        return keccak256(self.block_commit_canon(cfg.policy_commitment()))

    def srw3_root(self, cfg: ProtoCfg) -> bytes:
        return keccak256(b"\x9f" + self.parent_commit + cfg.policy_commitment()
                         + self.ctx_d + self.evidence_d
                         + I2B4(self.decision))


def ExecValidP(B: ProtoBlock, erc: bytes, erp: bytes) -> bool:
    return B.child_root == erc and B.payload_d == erp


def SRW3ValidP(B: ProtoBlock, cfg: ProtoCfg, lh: bytes) -> bool:
    return (B.decision == PDEC_VALID
            and B.pol_commit == cfg.policy_commitment()
            and B.ctx_d == cfg.authorized_sec_ctx(lh).digest())


def ValidP(B: ProtoBlock, erc: bytes, erp: bytes, cfg: ProtoCfg,
           lh: bytes) -> bool:
    return ExecValidP(B, erc, erp) and SRW3ValidP(B, cfg, lh)


def CommitP(B: ProtoBlock, erc: bytes, erp: bytes, cfg: ProtoCfg,
            lh: bytes) -> bool:
    return ValidP(B, erc, erp, cfg, lh)


# ---------------------------------------------------------------------------
# FrozenLogic — the frozen Phase 1I transition (for the BEFORE side only)
# ---------------------------------------------------------------------------
class FrozenState:
    def __init__(self):
        self.lineage = {}      # slot -> ProtoBlock
        self.pnext = 0
        self.head = b"\x00"    # PGenesisHead
        self.pvalid = True

    def snapshot(self):
        return (tuple(sorted((s, b.fields()) for s, b in self.lineage.items())),
                self.pnext, self.head, self.pvalid)


class FrozenLogic:
    """phase1i/semantics/srw3proto.k — pAccept with caller-supplied verdict."""

    NAME = "frozen(pAccept/SRW3OK)"

    @staticmethod
    def init(state: FrozenState, cfg: ProtoCfg) -> FrozenState:
        state.head = cfg.proto_root()
        return state

    @staticmethod
    def accept(state: FrozenState, B: ProtoBlock, erc: bytes, erp: bytes,
               cfg: ProtoCfg, srw3ok: bool) -> tuple[bool, str]:
        if B.parent_commit == state.head and B.slot == state.pnext and srw3ok:
            state.lineage[B.slot] = B
            state.pnext += 1
            state.head = B.block_commitment(cfg)
            state.pvalid = True
            return True, "accepted"
        return False, "rejected(owise)"


# ---------------------------------------------------------------------------
# RepairedLogic — the R1 transition (receipts + pinned configuration)
# ---------------------------------------------------------------------------
class GateReceipt:
    __slots__ = ("block", "erc", "erp", "verdict", "head", "slot")

    def __init__(self, block: ProtoBlock, erc: bytes, erp: bytes,
                 verdict: str, head: bytes, slot: int):
        self.block = block
        self.erc = erc
        self.erp = erp
        self.verdict = verdict
        self.head = head
        self.slot = slot

    def derived_decision(self) -> int:
        return ProtoDecisionOfGate(self.verdict)

    def fields(self):
        return (self.block.fields(), self.erc, self.erp, self.verdict,
                self.head, self.slot)

    def __eq__(self, other):
        return isinstance(other, GateReceipt) and self.fields() == other.fields()

    def __hash__(self):
        return hash(self.fields())


class RepairedState:
    """Mirrors the frozen <srw3proto> cells plus the reserved metadata region:

        lineage: dict — non-negative keys are committed slots (slot -> block);
                 the K model stores the pinned configuration at reserved key
                 -1 and the receipt pool at -2 (pinned_cfg / receipts here).
    """

    def __init__(self):
        self.lineage = {}
        self.pnext = 0
        self.head = b"\x00"
        self.pvalid = True
        self.pinned_cfg = None     # reserved key -1 (None = noCfg)
        self.receipts = []         # reserved key -2 (the gate-receipt pool)

    def snapshot(self):
        return (tuple(sorted((s, b.fields()) for s, b in self.lineage.items())),
                self.pnext, self.head, self.pvalid,
                self.pinned_cfg.canon() if self.pinned_cfg else None,
                tuple(sorted(r.fields() for r in self.receipts)))


class RepairedLogic:
    """phase1i-r1/semantics/srw3proto-r1.k — the repaired transition."""

    NAME = "repaired(pInitR1/pGateEval/pAcceptR1)"

    @staticmethod
    def init(state: RepairedState, cfg: ProtoCfg) -> tuple[bool, str]:
        if state.pinned_cfg is not None:
            return False, "rejected(owise): configuration already pinned"
        state.pinned_cfg = cfg
        state.head = cfg.proto_root()
        return True, "initialized"

    @staticmethod
    def gate_eval(state: RepairedState, B: ProtoBlock, erc: bytes,
                  erp: bytes, verdict: str) -> tuple[bool, str]:
        if state.pinned_cfg is None:
            return False, "rejected: no pinned configuration"
        state.receipts.append(GateReceipt(B, erc, erp, verdict, state.head,
                                          state.pnext))
        return True, "receipt recorded"

    @staticmethod
    def accept(state: RepairedState, B: ProtoBlock, erc: bytes, erp: bytes,
               cv: int) -> tuple[bool, str, str]:
        C = state.pinned_cfg
        if C is None:
            return False, "rejected(owise)", "no pinned configuration"
        # the matching receipt (structural binding to THIS candidate)
        R = None
        for r in state.receipts:
            if (r.block == B and r.erc == erc and r.erp == erp
                    and r.head == state.head and r.slot == state.pnext
                    and r.derived_decision() == PDEC_VALID):
                R = r
                break
        if R is None:
            return False, "rejected(owise)", "no matching valid receipt"
        # decision binding (block field vs the gate-derived decision)
        if B.decision != PDEC_VALID:
            return False, "rejected(owise)", "block decision field invalid"
        # execution binding
        if not ExecValidP(B, erc, erp):
            return False, "rejected(owise)", "execution binding fails"
        # policy binding (against the PINNED configuration)
        if B.pol_commit != C.policy_commitment():
            return False, "rejected(owise)", "policy commitment mismatch"
        # context binding (authorized projection for the applicable head)
        if B.ctx_d != C.authorized_sec_ctx(B.parent_root).digest():
            return False, "rejected(owise)", "context digest mismatch"
        # structural links
        if B.parent_commit != state.head:
            return False, "rejected(owise)", "parent commitment mismatch"
        if B.slot != state.pnext:
            return False, "rejected(owise)", "slot mismatch"
        # config witness
        if cv != C.policy_v:
            return False, "rejected(owise)", "config version mismatch"
        # ACCEPT: consume the receipt exactly once, extend the chain
        state.receipts.remove(R)
        state.lineage[B.slot] = B
        state.pnext += 1
        state.head = B.block_commitment(C)
        state.pvalid = True
        return True, "accepted", "committed at slot %d" % B.slot
