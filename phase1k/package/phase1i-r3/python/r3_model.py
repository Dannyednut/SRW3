#!/usr/bin/env python3
# =============================================================================
# SRW3 Phase 1I-R3 — Python executable reference of the ISOLATED R3 machine
# (r3_model.py)
#
# ROLE (handoff section 8): executable CROSS-LAYER correspondence evidence —
# NOT a formal proof.  This module mirrors the K definitions in
# phase1i-r3/semantics/srw3proto-r3.k (the isolated R3 machine) and drives the
# REAL frozen gate: `verify_lineage_g` is imported UNCHANGED from the Phase 1G
# model (phase1g/python/authz_model.py, itself importing the frozen 1D/1E/1F
# layers) — the same function the K machine evaluates.  All digests are real
# keccak-256 (original Keccak padding, byte-identical to K's LinH =
# Keccak256raw over the same preimages).  SHA3-256 is NEVER substituted
# (handoff §3: they are not interchangeable).
#
# THE R3 DELTA OVER R2 (handoff §1/§3/§4):
#   1. COMPLETE COMMITMENT.  The configuration root is the NEW R3 canonical
#      encoding (srw3_r3_config_commitment.py — the handoff's reference
#      encoder, integrated verbatim): domain-separated ("SRW3/ProtoCfg/R3" ||
#      0x00), versioned (U32BE(1)), length-delimited (LP32), covering ALL 13
#      configuration fields including the five authority fields (schedule,
#      spec version, authority proof type, authority guest digest, authority
#      proof-config digest) that the frozen R2 root (0x9C tag, fields 1..8
#      only) omitted.
#   2. AUTHENTICATED ROOT ANCHOR.  A locally computed root is not
#      automatically an authenticated protocol root.  R3State carries an
#      IMMUTABLE anchor (set ONCE at machine construction from OUTSIDE the
#      command API — the model of the protocol's trusted genesis/config-root
#      channel) and initialization REFUSES any configuration whose computed
#      root differs from that anchor.  There is no API through which a caller
#      could supply an "expectedRoot" or mutate the anchor: the K machine
#      models the same discipline with the <r3anchor> cell filled by
#      $SRW3R3ANCHOR and written by no rule.
#
# Canonical byte encodings (byte-identical to the K model; cross-checked in
# run_r3_attacks.py against the K krun transcripts and the golden vector):
#   ProtoCfgCanonR3 = "SRW3/ProtoCfg/R3"||0x00 || U32BE(1)
#                     || LP32(chainId) || U32BE(policyV) || LP32(policyD)
#                     || LP32(appSetD) || LP32(graphD) || LP32(clientCfgD)
#                     || LP32(execClientD) || LP32(fork) || LP32(sched)
#                     || U32BE(spec) || U32BE(authPT) || LP32(authGuestD)
#                     || LP32(authCfgD)                       [ALL 13 fields]
#   ProtoRootR3     = Keccak256(ProtoCfgCanonR3)
#   PolicyAuthIdR3  = K(0xA5 || chainId || fork)        [frozen 1I, unchanged]
#   PolicyCommitR3  = K(0x9D || I2B4(policyV) || policyD || appSetD || graphD
#                     || PolicyAuthIdR3)                [frozen 1I, unchanged]
#   CtxCanonR3      = 0xA6 || I2B4(policyV) || chainId || appSetD || graphD
#                     || lineageHead                    [frozen 1I, unchanged]
#   BlockCommitR3   = K(0x9E || parentCommit || payloadD || parentRoot
#                     || childRoot || effectD || evidenceD || ctxD
#                     || polCommit || I2B4(decision) || I2B4(slot))
#                                                       [frozen 1I, unchanged]
#   SRW3RootR3      = K(0x9F || parentCommit || PolicyCommitR3 || ctxD
#                     || evidenceD || I2B4(decision))   [frozen 1I, unchanged]
#   LegacyR2Projection = 0x9C || chainId || I2B4(policyV) || policyD
#                     || appSetD || graphD || clientCfgD || execClientD
#                     || fork                           [frozen R2 alias
#                     witness — fields 9..13 ABSENT; regression oracle only]
# =============================================================================
import sys
from dataclasses import dataclass

HERE = __file__
REPO = "/".join(HERE.split("/")[:-3])
R3DIR = "/".join(HERE.split("/")[:-1])

for p in (f"{REPO}/python-gen", f"{REPO}/phase1e/python", f"{REPO}/phase1f/python",
          f"{REPO}/phase1g/python", f"{REPO}/phase1i-r1/python",
          f"{REPO}/phase1i-r2/python", R3DIR):
    if p not in sys.path:
        sys.path.insert(0, p)

from lin_verify import H  # noqa: E402  (keccak256, byte-identical to K LinH)
from exec_model import ExecCtx, LinRecF  # noqa: E402
from exec_model import child_f as _child_f  # noqa: E402
from authz_model import (AuthzCert, AzCtx, LinRecG, SecCtx,  # noqa: E402
                         verify_lineage_g)
from pi_r1_model import keccak256, I2B4  # noqa: E402
# the handoff's reference encoder, integrated verbatim:
from srw3_r3_config_commitment import (ProtoCfgR3 as _PackCfg,  # noqa: E402
                                       legacy_r2_config_preimage,
                                       proto_cfg_canon_r3, proto_root_r3)

PDEC_VALID_R3, PDEC_REJECT_R3, PDEC_UNKNOWN_R3 = 1, 0, 2

# re-export the frozen 1I formula family + the R2 alias witness oracle
LegacyR2Projection = legacy_r2_config_preimage
ProtoCfgCanonR3 = proto_cfg_canon_r3


def ProtoRootR3(cfg: _PackCfg) -> bytes:
    """The R3 protocol root: real Keccak-256 over the complete 13-field
    canonical preimage (the handoff's proto_root_r3 with the project's
    tested LinH injected)."""
    return proto_root_r3(cfg, H)


def ProtoDecisionOfGateR3(verdict: str) -> int:
    """Frozen total mapping: ONLY 'valid-g' is protocol-valid (fail-closed)."""
    return PDEC_VALID_R3 if verdict == "valid-g" else PDEC_REJECT_R3


def verdict_k(v: str) -> str:
    """VERDICT-SURFACE NORMALIZATION (disclosed mirror artifact, carried from
    R2 verbatim).  The frozen K gate emits the surface verdicts
    valid-g / invalid-<x>; the frozen PYTHON mirror of the SAME gate emits
    layer-coded verdicts L<NN>-<X> for the SAME rejection conditions.  Total
    on the verdict code set; changes no decision (only 'valid-g' maps to
    pdecValidR3 on both sides)."""
    if v == "VALID-G":
        return "valid-g"
    if v.startswith("L") and "-" in v:
        return "invalid-" + v.split("-", 1)[1].lower()
    return v.lower()


# ---------------------------------------------------------------------------
# R3 protocol objects (mirrors srw3proto-r3.k sections 1/4)
# ---------------------------------------------------------------------------
# ProtoCfgR3 IS the handoff pack's validated 13-field configuration (the
# canonical-encoder domain type); the protocol-level formulas live here.
ProtoCfgR3 = _PackCfg


def CfgEqR3(a: ProtoCfgR3, b: ProtoCfgR3) -> bool:
    return a.fields13() == b.fields13() if hasattr(a, "fields13") else a == b


def _fields13(c: ProtoCfgR3):
    return (c.chain_id, c.policy_version, c.policy_digest, c.app_set_digest,
            c.graph_digest, c.client_config_digest, c.execution_client_digest,
            c.fork, c.schedule, c.spec_version, c.authority_proof_type,
            c.authority_guest_digest, c.authority_config_digest)


ProtoCfgR3.fields13 = _fields13  # structural-identity helper (K CfgEqR3)


def policy_auth_id_r3(c: ProtoCfgR3) -> bytes:
    return keccak256(b"\xa5" + c.chain_id + c.fork)


def policy_commitment_r3(c: ProtoCfgR3) -> bytes:
    return keccak256(b"\x9d" + I2B4(c.policy_version) + c.policy_digest
                     + c.app_set_digest + c.graph_digest + policy_auth_id_r3(c))


def authorized_sec_ctx_r3(c: ProtoCfgR3, lineage_head: bytes) -> SecCtx:
    return SecCtx(c.policy_version, c.chain_id, c.app_set_digest, c.graph_digest,
                  lineage_head)


def CtxCanonR3(s: SecCtx) -> bytes:
    return (b"\xa6" + I2B4(s.policy_v) + s.chain_id + s.app_set_d
            + s.graph_d + s.lineage_head)


def CtxDigestR3(s: SecCtx) -> bytes:
    return keccak256(CtxCanonR3(s))


@dataclass(frozen=True)
class ProtoBlockR3:
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

    def block_commitment(self, cfg: ProtoCfgR3) -> bytes:
        return keccak256(self.block_commit_canon(policy_commitment_r3(cfg)))

    def srw3_root(self, cfg: ProtoCfgR3) -> bytes:
        return keccak256(b"\x9f" + self.parent_commit
                         + policy_commitment_r3(cfg) + self.ctx_d
                         + self.evidence_d + I2B4(self.decision))


# ---------------------------------------------------------------------------
# The gate-input binding (mirrors srw3proto-r3.k section 6)
# ---------------------------------------------------------------------------
def GateInputMatchesBlockR3(fc: ExecCtx, rg: LinRecG, cert: AuthzCert,
                            b: ProtoBlockR3) -> bool:
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


def GateAuthorityMatchesCfgR3(fc: ExecCtx, c: ProtoCfgR3) -> bool:
    return fc.schedule == c.schedule and fc.spec == c.spec_version


def GateCtxAuthorizedR3(ac: AzCtx, c: ProtoCfgR3, lh: bytes) -> bool:
    sec = ac.sec
    auth = authorized_sec_ctx_r3(c, lh)
    return (sec.policy_v == auth.policy_v and sec.chain_id == auth.chain_id
            and sec.app_set_d == auth.app_set_d
            and sec.graph_d == auth.graph_d
            and sec.lineage_head == auth.lineage_head
            and ac.auth_pt == c.authority_proof_type
            and ac.auth_guest_d == c.authority_guest_digest
            and ac.auth_cfg_d == c.authority_config_digest)


def R3RecChildF(rg: LinRecG) -> bytes:
    """The lineage-head advance: the accepted record's F-child commitment."""
    return _child_f(rg.base)


# ---------------------------------------------------------------------------
# Receipts (mirrors srw3proto-r3.k section 7) — the verdict is COMPUTED; the
# R3 receipt additionally binds the computed ROOT and the trusted ANCHOR.
# ---------------------------------------------------------------------------
@dataclass(frozen=True)
class R3GateReceipt:
    block: ProtoBlockR3
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
    cfg: ProtoCfgR3
    root: bytes           # gr3Root:  ProtoRootR3(cfg) at mint time
    anchor: bytes         # gr3Anchor: the machine's trusted anchor at mint

    def derived_decision(self) -> int:
        return ProtoDecisionOfGateR3(self.verdict)

    def fields(self):
        return (self.block.fields(), self.erc, self.erp, self.verdict,
                self.head, self.slot, self.lin_head, _fields13(self.cfg),
                self.root, self.anchor)


# ---------------------------------------------------------------------------
# Validity predicates and Commit_P (mirrors srw3proto-r3.k section 5)
# ---------------------------------------------------------------------------
def ExecValidPR3(b: ProtoBlockR3, erc: bytes, erp: bytes) -> bool:
    return b.child_root == erc and b.payload_d == erp


def SRW3ValidPR3(b: ProtoBlockR3, c: ProtoCfgR3, lh: bytes) -> bool:
    return (b.decision == PDEC_VALID_R3
            and b.pol_commit == policy_commitment_r3(c)
            and b.ctx_d == CtxDigestR3(authorized_sec_ctx_r3(c, lh)))


def CommitPR3(b: ProtoBlockR3, erc: bytes, erp: bytes, c: ProtoCfgR3,
              lh: bytes) -> bool:
    return ExecValidPR3(b, erc, erp) and SRW3ValidPR3(b, c, lh)


# ---------------------------------------------------------------------------
# The R3 machine (mirrors srw3proto-r3.k sections 8/9 — the transition rules)
# ---------------------------------------------------------------------------
R3_LIN_ROOT = b"\x00" * 32     # R3LinRoot: the 1D record-chain anchor
R3_GENESIS_HEAD = b"\x00"      # R3GenesisHead: the frozen 1I form


class R3State:
    """The machine state.  `anchor` — the protocol-authorized configuration-
    root anchor — is an EXPLICIT AUTHENTICATED INPUT: it is set ONCE here,
    from OUTSIDE the command API, and no machine method ever writes it
    (mirrors the K <r3anchor> cell filled by $SRW3R3ANCHOR and written by no
    rule).  Callers can inspect it; they cannot substitute it on a live
    machine any more than a consensus client can rewrite its genesis spec."""

    def __init__(self, anchor: bytes):
        if not isinstance(anchor, bytes):
            raise TypeError("anchor must be bytes (the authenticated root)")
        self.anchor = anchor
        self.lineage = {}      # slot -> ProtoBlockR3
        self.pnext = 0
        self.head = R3_GENESIS_HEAD
        self.linhead = R3_LIN_ROOT
        self.valid = True
        self.pinned_cfg = None     # reserved key -1 (None = noCfgR3)
        self.receipts = []         # reserved key -2 (the receipt pool)

    def snapshot(self):
        return (tuple(sorted((s, b.fields()) for s, b in self.lineage.items())),
                self.pnext, self.head, self.linhead, self.valid,
                _fields13(self.pinned_cfg) if self.pinned_cfg else None,
                tuple(sorted(r.fields() for r in self.receipts)),
                self.anchor)


class R3Logic:
    """The isolated R3 machine surface.  The command language is EXACTLY the
    three methods below.  There is no method (and no parameter of any method)
    through which a caller could supply a verdict, a decision, a receipt, a
    configuration (other than init's C, which must hash to the anchor), a
    root, or an anchor.  The legacy commands (pInit/pAccept, pInitR1/
    pGateEval/pAcceptR1, pInitR2/pGateEvalR2/pAcceptR2) are not part of this
    surface — attempting them is an AttributeError, the Python mirror of the
    K parse error."""

    NAME = "R3(pInitR3/pGateEvalR3/pAcceptR3)"

    @staticmethod
    def init(state: R3State, cfg: ProtoCfgR3):
        """pInitR3: pin ONCE — and ONLY if the COMPUTED root of the complete
        configuration equals the trusted anchor (handoff §4 B: initialization
        checks the computed root against an explicitly authenticated protocol
        root; a caller-supplied expectedRoot is not expressible here)."""
        if state.pinned_cfg is not None:
            return False, "rejected(owise): configuration already pinned"
        computed = ProtoRootR3(cfg)
        if computed != state.anchor:
            return False, ("rejected(owise): computed root does not match the"
                           " authorized protocol root anchor")
        state.pinned_cfg = cfg
        state.head = computed          # == state.anchor (checked above)
        state.linhead = R3_LIN_ROOT
        return True, "initialized(root authorized)"

    @staticmethod
    def gate_eval(state: R3State, b: ProtoBlockR3, fc: ExecCtx, rg: LinRecG,
                  cert: AuthzCert, erc: bytes, erp: bytes):
        """pGateEvalR3 — the ONLY receipt-minting transition.  NOTE THE
        SIGNATURE: candidate, execution context, lineage record, certificate,
        client-derived child root, client-derived payload identity.  There is
        NO verdict/decision parameter (the R1 injection is ill-formed), NO
        config/root/anchor parameter."""
        c = state.pinned_cfg
        if c is None:
            return False, "rejected: no pinned configuration"
        # the mint guard (srw3proto-r3.k pGateEvalR3 requires, in order)
        if not GateInputMatchesBlockR3(fc, rg, cert, b):
            return False, "rejected: GateInputMatchesBlockR3 fails"
        if not GateAuthorityMatchesCfgR3(fc, c):
            return False, "rejected: GateAuthorityMatchesCfgR3 fails"
        if b.parent_commit != state.head:
            return False, "rejected: candidate not at the current position"
        if b.slot != state.pnext:
            return False, "rejected: candidate not at the current slot"
        # (a) the machine constructs the authority context FROM THE PIN
        ac = AzCtx(fc, authorized_sec_ctx_r3(c, b.parent_root), cert,
                   c.authority_proof_type, c.authority_guest_digest,
                   c.authority_config_digest)
        # (b) the machine supplies the position: T = pnext, HEAD = linhead
        # (c) the machine COMPUTES the verdict with the FROZEN gate (verdict_k
        #     is the disclosed mirror normalization — see above)
        verdict = verdict_k(verify_lineage_g(rg, ac, state.pnext,
                                             state.linhead))
        # (d) the receipt binds the computed 13-field root and the anchor
        state.receipts.append(R3GateReceipt(
            b, erc, erp, fc, rg, cert, ac, verdict,
            state.head, state.pnext, state.linhead, c,
            ProtoRootR3(c), state.anchor))
        return True, f"receipt recorded (computed verdict: {verdict})"

    @staticmethod
    def accept(state: R3State, b: ProtoBlockR3, erc: bytes, erp: bytes,
               cv: int):
        """pAcceptR3 — the ONLY chain-extending transition.  The guard is the
        commitment discipline (decidable conjuncts first, hash conjuncts
        last: anchor re-check, root re-check, policy, context); the receipt
        is consumed exactly once."""
        c = state.pinned_cfg
        if c is None:
            return False, "rejected(owise)", "no pinned configuration"
        # the matching receipt (structural binding to THIS candidate; the R3
        # root/anchor fields are part of the receipt identity)
        r = None
        for x in state.receipts:
            if (x.block == b and x.erc == erc and x.erp == erp
                    and x.head == state.head and x.slot == state.pnext
                    and x.lin_head == state.linhead
                    and CfgEqR3(x.cfg, c)
                    and x.anchor == state.anchor          # ANCHOR re-check
                    and x.derived_decision() == PDEC_VALID_R3):
                r = x
                break
        if r is None:
            return False, "rejected(owise)", "no matching valid receipt"
        # decision binding (block field vs the gate-derived decision)
        if b.decision != PDEC_VALID_R3:
            return False, "rejected(owise)", "block decision field invalid"
        # execution binding
        if not ExecValidPR3(b, erc, erp):
            return False, "rejected(owise)", "execution binding fails"
        # evidence identity + input binding + authority re-checks (defense in
        # depth on the receipt-stored inputs)
        if r.rg.az_cert_d != b.evidence_d:
            return False, "rejected(owise)", "evidence identity mismatch"
        if not GateInputMatchesBlockR3(r.fc, r.rg, r.cert, b):
            return False, "rejected(owise)", "gate-input binding fails"
        if not GateCtxAuthorizedR3(r.ac, c, b.parent_root):
            return False, "rejected(owise)", "unauthorized context"
        if not GateAuthorityMatchesCfgR3(r.fc, c):
            return False, "rejected(owise)", "pinned-authority mismatch"
        # structural links
        if b.parent_commit != state.head:
            return False, "rejected(owise)", "parent commitment mismatch"
        if b.slot != state.pnext:
            return False, "rejected(owise)", "slot mismatch"
        # config witness
        if cv != c.policy_version:
            return False, "rejected(owise)", "config version mismatch"
        # ROOT re-check: the receipt's computed root must equal the root of
        # the currently pinned FULL configuration (defense in depth; also
        # excludes cross-root receipt replay)                      [keccak]
        if r.root != ProtoRootR3(c):
            return False, "rejected(owise)", "receipt root mismatch"
        # policy binding (against the PINNED configuration)        [keccak]
        if b.pol_commit != policy_commitment_r3(c):
            return False, "rejected(owise)", "policy commitment mismatch"
        # context binding (authorized projection for the applicable head)
        if b.ctx_d != CtxDigestR3(authorized_sec_ctx_r3(c, b.parent_root)):
            return False, "rejected(owise)", "context digest mismatch"
        # ACCEPT: consume the receipt exactly once, extend the chain,
        # advance the lineage head to the accepted record's F-child
        state.receipts.remove(r)
        state.lineage[b.slot] = b
        state.pnext += 1
        state.head = b.block_commitment(c)
        state.linhead = R3RecChildF(r.rg)
        state.valid = True
        return True, "accepted", f"committed at slot {b.slot}"

    # ---- the legacy surface is ABSENT (R3-LEGACY-SURFACE-EXCLUDED) --------
    # There is deliberately NO gate_eval_with_verdict / accept_with_bool /
    # set_config / set_anchor / accept_raw / reinit method.  In K this absence
    # is the absence of the productions and rules; here it is the absence of
    # the API.  Both are checked by run_r3_attacks.py (LEG group).
