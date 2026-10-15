#!/usr/bin/env python3
# =============================================================================
# SRW3 Phase 1I-R2 — Python executable reference of the ISOLATED R2 machine
# (r2_model.py)
#
# ROLE (handoff section 8): executable CROSS-LAYER correspondence evidence —
# NOT a formal proof.  This module mirrors the K definitions in
# phase1i-r2/semantics/srw3proto-r2.k (the isolated R2 machine) and drives the
# REAL frozen gate: `verify_lineage_g` is imported UNCHANGED from the Phase 1G
# model (phase1g/python/authz_model.py, itself importing the frozen 1D/1E/1F
# layers) — the same function the K machine evaluates.  All digests are real
# keccak-256 (original Keccak padding, byte-identical to K's LinH =
# Keccak256raw over the same preimages).
#
# The R1 transition (phase1i-r1/python/pi_r1_model.py, UNMODIFIED) is imported
# for the BEFORE side of the decisive comparison: the same attack that R1
# accepts (caller injects "valid-g") is ILL-FORMED in R2 and the evidence-
# based variant computes a rejection.
#
# Canonical byte encodings (byte-identical to the K model; cross-checked in
# run_r2_attacks.py against the K krun transcripts):
#   ProtoCfgCanonR2 = 0x9C || chainId || I2B4(policyV) || policyD || appSetD
#                     || graphD || clientCfgD || execClientD || fork
#                     (fields 9..13 are pin-internal, NOT in the root preimage)
#   PolicyAuthIdR2  = K(0xA5 || chainId || fork)
#   PolicyCommitR2  = K(0x9D || I2B4(policyV) || policyD || appSetD || graphD
#                     || PolicyAuthIdR2)
#   CtxCanonR2      = 0xA6 || I2B4(policyV) || chainId || appSetD || graphD
#                     || lineageHead
#   BlockCommitR2   = K(0x9E || parentCommit || payloadD || parentRoot
#                     || childRoot || effectD || evidenceD || ctxD
#                     || polCommit || I2B4(decision) || I2B4(slot))
#   SRW3RootR2      = K(0x9F || parentCommit || PolicyCommitR2 || ctxD
#                     || evidenceD || I2B4(decision))
# =============================================================================
import sys
from dataclasses import dataclass

HERE = __file__
REPO = "/".join(HERE.split("/")[:-3])

for p in (f"{REPO}/python-gen", f"{REPO}/phase1e/python", f"{REPO}/phase1f/python",
          f"{REPO}/phase1g/python", f"{REPO}/phase1i-r1/python"):
    if p not in sys.path:
        sys.path.insert(0, p)

from lin_verify import H  # noqa: E402  (keccak256, byte-identical to K LinH)
from exec_model import (ExecCtx, LinRecF, config_digest,  # noqa: E402
                        payload_digest, SCHED_CANCUN, SPEC_V1)
from exec_model import child_f as _child_f  # noqa: E402
from authz_model import (AuthzCert, AzCtx, LinRecG, SecCtx, cert_id,  # noqa: E402
                         exec_client_id, verify_lineage_g)
from pi_r1_model import ProtoCfg, ProtoBlock, keccak256, I2B4  # noqa: E402 (before side)

PDEC_VALID_R2, PDEC_REJECT_R2, PDEC_UNKNOWN_R2 = 1, 0, 2


def ProtoDecisionOfGateR2(verdict: str) -> int:
    """Frozen total mapping: ONLY 'valid-g' is protocol-valid (fail-closed)."""
    return PDEC_VALID_R2 if verdict == "valid-g" else PDEC_REJECT_R2


def verdict_k(v: str) -> str:
    """VERDICT-SURFACE NORMALIZATION (disclosed mirror artifact).

    The frozen K gate emits the surface verdicts  valid-g / invalid-<x>
    (srw3authz.k L23..L30, srw3exec.k, srw3lin-verify.k).  The frozen PYTHON
    mirror of the SAME gate emits layer-coded verdicts for the SAME rejection
    conditions: L<NN>-<X>  (e.g. L29-POLICY for the K invalid-policy), plus
    VALID-G.  The correspondence is systematic over the whole code set:
    the <NN> is the K rule's layer number and <X> the K suffix.  The R2
    machine surface is the K surface, so the mirror normalizes the frozen
    result to the K form.  Total on the verdict code set; changes no decision
    (only 'valid-g' maps to pdecValidR2 on both sides)."""
    if v == "VALID-G":
        return "valid-g"
    if v.startswith("L") and "-" in v:
        return "invalid-" + v.split("-", 1)[1].lower()
    return v.lower()


# ---------------------------------------------------------------------------
# R2 protocol objects (mirrors srw3proto-r2.k sections 1/4)
# ---------------------------------------------------------------------------
@dataclass(frozen=True)
class ProtoCfgR2:
    chain_id: bytes
    policy_v: int
    policy_d: bytes
    app_set_d: bytes
    graph_d: bytes
    client_cfg_d: bytes
    exec_client_d: bytes
    fork: bytes
    # ---- R2 additions: the pinned gate-authority parameters (handoff 5.3) ----
    sched: bytes
    spec: int
    auth_pt: int
    auth_guest_d: bytes
    auth_cfg_d: bytes

    def canon(self) -> bytes:
        # frozen 1I ProtoCfgCanon formula (tag 0x9C) over fields 1..8
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

    def authorized_sec_ctx(self, lineage_head: bytes) -> SecCtx:
        return SecCtx(self.policy_v, self.chain_id, self.app_set_d,
                      self.graph_d, lineage_head)

    def fields13(self):
        return (self.chain_id, self.policy_v, self.policy_d, self.app_set_d,
                self.graph_d, self.client_cfg_d, self.exec_client_d, self.fork,
                self.sched, self.spec, self.auth_pt, self.auth_guest_d,
                self.auth_cfg_d)


def CfgEqR2(a: ProtoCfgR2, b: ProtoCfgR2) -> bool:
    return a.fields13() == b.fields13()


def CtxCanonR2(s: SecCtx) -> bytes:
    return (b"\xa6" + I2B4(s.policy_v) + s.chain_id + s.app_set_d
            + s.graph_d + s.lineage_head)


def CtxDigestR2(s: SecCtx) -> bytes:
    return keccak256(CtxCanonR2(s))


@dataclass(frozen=True)
class ProtoBlockR2:
    parent_commit: bytes
    payload_d: bytes
    parent_root: bytes
    child_root: bytes
    effect_d: bytes
    evidence_d: bytes
    ctx_d: bytes
    pol_commit: bytes
    decision: int
    slot: int

    def fields(self):
        return (self.parent_commit, self.payload_d, self.parent_root,
                self.child_root, self.effect_d, self.evidence_d, self.ctx_d,
                self.pol_commit, self.decision, self.slot)

    def block_commit_canon(self, pol_commit: bytes) -> bytes:
        return (b"\x9e" + self.parent_commit + self.payload_d
                + self.parent_root + self.child_root + self.effect_d
                + self.evidence_d + self.ctx_d + pol_commit
                + I2B4(self.decision) + I2B4(self.slot))

    def block_commitment(self, cfg: ProtoCfgR2) -> bytes:
        return keccak256(self.block_commit_canon(cfg.policy_commitment()))

    def srw3_root(self, cfg: ProtoCfgR2) -> bytes:
        return keccak256(b"\x9f" + self.parent_commit + cfg.policy_commitment()
                         + self.ctx_d + self.evidence_d
                         + I2B4(self.decision))


# ---------------------------------------------------------------------------
# The gate-input binding (mirrors srw3proto-r2.k section 6)
# ---------------------------------------------------------------------------
def GateInputMatchesBlockR2(fc: ExecCtx, rg: LinRecG, cert: AuthzCert,
                            b: ProtoBlockR2) -> bool:
    """Named, explicit binding of every presented evidence object to the EXACT
    candidate block.  Structural equalities here; the cryptographic closures
    (ExecPayloadDigest(payload) == cert payload digest, AzCertId(cert) ==
    record certificate digest) are conjuncts INSIDE the frozen gate (L28) and
    are discharged by the gate evaluation itself."""
    return (cert.payload_d == b.payload_d
            and fc.parent_root == b.parent_root
            and rg.base.base.state_root == b.child_root
            and rg.base.eff_trace_d == b.effect_d
            and rg.az_cert_d == b.evidence_d)


def GateAuthorityMatchesCfgR2(fc: ExecCtx, c: ProtoCfgR2) -> bool:
    return fc.schedule == c.sched and fc.spec == c.spec


def GateCtxAuthorizedR2(ac: AzCtx, c: ProtoCfgR2, lh: bytes) -> bool:
    sec = ac.sec
    auth = c.authorized_sec_ctx(lh)
    return (sec.policy_v == auth.policy_v and sec.chain_id == auth.chain_id
            and sec.app_set_d == auth.app_set_d
            and sec.graph_d == auth.graph_d
            and sec.lineage_head == auth.lineage_head
            and ac.auth_pt == c.auth_pt
            and ac.auth_guest_d == c.auth_guest_d
            and ac.auth_cfg_d == c.auth_cfg_d)


def R2RecChildF(rg: LinRecG) -> bytes:
    """The lineage-head advance: the accepted record's F-child commitment."""
    return _child_f(rg.base)


# ---------------------------------------------------------------------------
# Receipts (mirrors srw3proto-r2.k section 7) — the verdict is COMPUTED
# ---------------------------------------------------------------------------
@dataclass(frozen=True)
class R2GateReceipt:
    block: ProtoBlockR2
    erc: bytes
    erp: bytes
    fc: ExecCtx
    rg: LinRecG
    cert: AuthzCert
    ac: AzCtx
    verdict: str          # WRITTEN ONLY by gate_eval: verify_lineage_g(...)
    head: bytes
    slot: int
    lin_head: bytes
    cfg: ProtoCfgR2

    def derived_decision(self) -> int:
        return ProtoDecisionOfGateR2(self.verdict)

    def fields(self):
        return (self.block.fields(), self.erc, self.erp, self.verdict,
                self.head, self.slot, self.lin_head, self.cfg.fields13())


# ---------------------------------------------------------------------------
# Validity predicates and Commit_P (mirrors srw3proto-r2.k section 5)
# ---------------------------------------------------------------------------
def ExecValidPR2(b: ProtoBlockR2, erc: bytes, erp: bytes) -> bool:
    return b.child_root == erc and b.payload_d == erp


def SRW3ValidPR2(b: ProtoBlockR2, c: ProtoCfgR2, lh: bytes) -> bool:
    return (b.decision == PDEC_VALID_R2
            and b.pol_commit == c.policy_commitment()
            and b.ctx_d == CtxDigestR2(c.authorized_sec_ctx(lh)))


def CommitPR2(b: ProtoBlockR2, erc: bytes, erp: bytes, c: ProtoCfgR2,
              lh: bytes) -> bool:
    return ExecValidPR2(b, erc, erp) and SRW3ValidPR2(b, c, lh)


# ---------------------------------------------------------------------------
# The R2 machine (mirrors srw3proto-r2.k sections 8/9 — the transition rules)
# ---------------------------------------------------------------------------
R2_LIN_ROOT = b"\x00" * 32     # R2LinRoot: the 1D record-chain anchor
R2_GENESIS_HEAD = b"\x00"      # R2GenesisHead: the frozen 1I form


class R2State:
    def __init__(self):
        self.lineage = {}      # slot -> ProtoBlockR2
        self.pnext = 0
        self.head = R2_GENESIS_HEAD
        self.linhead = R2_LIN_ROOT
        self.valid = True
        self.pinned_cfg = None     # reserved key -1 (None = noCfgR2)
        self.receipts = []         # reserved key -2 (the receipt pool)

    def snapshot(self):
        return (tuple(sorted((s, b.fields()) for s, b in self.lineage.items())),
                self.pnext, self.head, self.linhead, self.valid,
                self.pinned_cfg.fields13() if self.pinned_cfg else None,
                tuple(sorted(r.fields() for r in self.receipts)))


class R2Logic:
    """The isolated R2 machine surface.  The command language is EXACTLY the
    three methods below; there is no method (and no parameter of any method)
    through which a caller could supply a verdict, a decision, a receipt, or a
    configuration.  The legacy commands (pInit/pAccept/pGateEval/pAcceptR1)
    are not part of this surface — attempting them is an AttributeError, the
    Python mirror of the K parse error."""

    NAME = "R2(pInitR2/pGateEvalR2/pAcceptR2)"

    @staticmethod
    def init(state: R2State, cfg: ProtoCfgR2):
        """pInitR2: pin ONCE, anchor both heads; refuse re-initialization."""
        if state.pinned_cfg is not None:
            return False, "rejected(owise): configuration already pinned"
        state.pinned_cfg = cfg
        state.head = cfg.proto_root()
        state.linhead = R2_LIN_ROOT
        return True, "initialized"

    @staticmethod
    def gate_eval(state: R2State, b: ProtoBlockR2, fc: ExecCtx, rg: LinRecG,
                  cert: AuthzCert, erc: bytes, erp: bytes):
        """pGateEvalR2 — the ONLY receipt-minting transition.  NOTE THE
        SIGNATURE: candidate, execution context, lineage record, certificate,
        client-derived child root, client-derived payload identity.  There is
        NO verdict/decision parameter (the R1 injection is ill-formed)."""
        c = state.pinned_cfg
        if c is None:
            return False, "rejected: no pinned configuration"
        # the mint guard (srw3proto-r2.k pGateEvalR2 requires, in order)
        if not GateInputMatchesBlockR2(fc, rg, cert, b):
            return False, "rejected: GateInputMatchesBlockR2 fails"
        if not GateAuthorityMatchesCfgR2(fc, c):
            return False, "rejected: GateAuthorityMatchesCfgR2 fails"
        if b.parent_commit != state.head:
            return False, "rejected: candidate not at the current position"
        if b.slot != state.pnext:
            return False, "rejected: candidate not at the current slot"
        # (a) the machine constructs the authority context FROM THE PIN
        ac = AzCtx(fc, c.authorized_sec_ctx(b.parent_root), cert,
                   c.auth_pt, c.auth_guest_d, c.auth_cfg_d)
        # (b) the machine supplies the position: T = pnext, HEAD = linhead
        # (c) the machine COMPUTES the verdict with the FROZEN gate and
        # normalizes it to the K surface form (verdict_k — the disclosed
        # mirror artifact above).
        verdict = verdict_k(verify_lineage_g(rg, ac, state.pnext,
                                             state.linhead))
        state.receipts.append(R2GateReceipt(
            b, erc, erp, fc, rg, cert, ac, verdict,
            state.head, state.pnext, state.linhead, c))
        return True, f"receipt recorded (computed verdict: {verdict})"

    @staticmethod
    def accept(state: R2State, b: ProtoBlockR2, erc: bytes, erp: bytes,
               cv: int):
        """pAcceptR2 — the ONLY chain-extending transition.  The guard is the
        commitment discipline (decidable conjuncts first, hash conjuncts
        last); the receipt is consumed exactly once."""
        c = state.pinned_cfg
        if c is None:
            return False, "rejected(owise)", "no pinned configuration"
        # the matching receipt (structural binding to THIS candidate)
        r = None
        for x in state.receipts:
            if (x.block == b and x.erc == erc and x.erp == erp
                    and x.head == state.head and x.slot == state.pnext
                    and x.lin_head == state.linhead
                    and CfgEqR2(x.cfg, c)
                    and x.derived_decision() == PDEC_VALID_R2):
                r = x
                break
        if r is None:
            return False, "rejected(owise)", "no matching valid receipt"
        # decision binding (block field vs the gate-derived decision)
        if b.decision != PDEC_VALID_R2:
            return False, "rejected(owise)", "block decision field invalid"
        # execution binding
        if not ExecValidPR2(b, erc, erp):
            return False, "rejected(owise)", "execution binding fails"
        # evidence identity + input binding + authority re-checks (defense in
        # depth on the receipt-stored inputs)
        if r.rg.az_cert_d != b.evidence_d:
            return False, "rejected(owise)", "evidence identity mismatch"
        if not GateInputMatchesBlockR2(r.fc, r.rg, r.cert, b):
            return False, "rejected(owise)", "gate-input binding fails"
        if not GateCtxAuthorizedR2(r.ac, c, b.parent_root):
            return False, "rejected(owise)", "unauthorized context"
        if not GateAuthorityMatchesCfgR2(r.fc, c):
            return False, "rejected(owise)", "pinned-authority mismatch"
        # structural links
        if b.parent_commit != state.head:
            return False, "rejected(owise)", "parent commitment mismatch"
        if b.slot != state.pnext:
            return False, "rejected(owise)", "slot mismatch"
        # config witness
        if cv != c.policy_v:
            return False, "rejected(owise)", "config version mismatch"
        # policy binding (against the PINNED configuration)  [keccak closure]
        if b.pol_commit != c.policy_commitment():
            return False, "rejected(owise)", "policy commitment mismatch"
        # context binding (authorized projection for the applicable head)
        if b.ctx_d != CtxDigestR2(c.authorized_sec_ctx(b.parent_root)):
            return False, "rejected(owise)", "context digest mismatch"
        # ACCEPT: consume the receipt exactly once, extend the chain,
        # advance the lineage head to the accepted record's F-child
        state.receipts.remove(r)
        state.lineage[b.slot] = b
        state.pnext += 1
        state.head = b.block_commitment(c)
        state.linhead = R2RecChildF(r.rg)
        state.valid = True
        return True, "accepted", f"committed at slot {b.slot}"

    # ---- the legacy surface is ABSENT (R2-LEGACY-SURFACE-EXCLUDED) --------
    # There is deliberately NO gate_eval_with_verdict / accept_with_bool /
    # set_config / accept_raw method.  In K this absence is the absence of
    # the productions and rules; here it is the absence of the API.  Both are
    # checked by run_r2_attacks.py (LEG group).
