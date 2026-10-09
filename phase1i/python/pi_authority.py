"""SRW3 Phase 1I — authority model and the protocol-authoritative policy
commitment.

Authority hierarchy (Phase 1I spec section 6; extends the frozen Phase 1G
levels — domConsensus/domPolicy at 0, domExecution/domProof at 1, certified
object at 2):

    Protocol / Consensus Authority        (level 0 — the protocol config root)
        -> Policy Authority               (authorized BY the protocol config)
            -> Execution Authority        (authorized client identities)
                -> SRW3 Security Evaluation   (the gate; consumes, never creates)
                    -> Application            (governed object)

Two non-negotiable properties:

  * AUTHORITY DESCENT: every authorization edge points strictly DOWN the
    hierarchy.  An object at level n can be authorized only by an object at a
    strictly lower level; nothing authorizes itself; nothing at level >= 1
    creates protocol authority.

  * CONTEXT-DERIVED AUTHORIZED IDENTITIES (the Phase 1G discipline, carried
    to the protocol layer): every authorized identity is a deterministic
    function of the PROTOCOL CONFIGURATION — never of the object being
    checked.  A policy cannot authorize itself; evidence cannot authorize
    itself; a security context cannot mint authority.

The PolicyCommitment construction (spec section 5):

    PolicyCommitment = H("SRW3-POLICYCOMMIT-V1" | policyVersion | policyDigest
                         | appSetDigest | graphDigest | policyAuthorityId)

  * policyVersion/policyDigest  — WHAT governs (identity + content)
  * appSetDigest/graphDigest    — WHAT it governs (the application surface)
  * policyAuthorityId           — WHO is authorized to govern, derived from
                                  the protocol configuration:
        policyAuthorityId = H("SRW3-AUTH-I-V1" | "policyAuthority" | chainId
                              | forkVersion)

The SecurityContext is deliberately NOT a PolicyCommitment input.  The
context (Phase 1H-R1) contains the per-evaluation lineage head, client
config digest and client identity — per-block, client-derived, mutable
state.  Folding it into the policy commitment would (a) make the POLICY
IDENTITY change on every block, conflating governance with progress,
(b) let a substituted context masquerade as a policy change, and (c) invert
authority (a client-derived object inside the protocol's policy root).  The
context is instead bound at COMMITMENT-VALIDATION time: ContextValid(B)
requires the evaluation's contextDigest to be recomputed over the canonical
context fields (SC-9) and the context to validate against the gate
(SC-1..SC-8).  The spec's literal form H(..., SecurityContext) is compared
as option B of the commitment-root design (section 16); the selected
construction above is option A refined with the explicit authority id.
"""
from __future__ import annotations

from dataclasses import dataclass, field

from pi_canonical import (DOM_POLICYCOMMIT, DOM_PROTOCFG, canonical_digest)


# ---------------------------------------------------------------------------
# Authority levels (strict descent)
# ---------------------------------------------------------------------------

AUTH_LEVELS = {
    "protocol": 0,
    "policy": 1,
    "execution": 2,
    "srw3-evaluation": 3,
    "application": 4,
}


def authority_descends(src_level: int, dst_level: int) -> bool:
    """True iff src strictly outranks dst (authorization may flow down)."""
    return src_level < dst_level


# ---------------------------------------------------------------------------
# Protocol configuration — the LEVEL-0 protocol authority object.
# Pinned at genesis / protocol activation; carries every authorized identity.
# ---------------------------------------------------------------------------

@dataclass(frozen=True)
class ProtocolConfig:
    chain_id: int
    fork_version: str
    policy: PolicyCommitment        # the AUTHORIZED policy OBJECT (level-0)
    exec_client_identity: str       # the authorized execution client (1G id)
    client_config_digest: str       # authorized execution configuration

    @property
    def policy_commitment(self) -> str:
        """The protocol-authorized PolicyCommitment (derived, never set
        independently — config self-consistency by construction)."""
        return self.policy.commitment(self.chain_id, self.fork_version)

    @property
    def policy_version(self) -> str:
        return self.policy.policy_version

    def canonical_fields(self) -> dict:
        return {
            "chainId": self.chain_id,
            "forkVersion": self.fork_version,
            "authorizedPolicyCommitment": self.policy_commitment,
            "authorizedExecClientIdentity": self.exec_client_identity,
            "authorizedClientConfigDigest": self.client_config_digest,
        }

    @property
    def proto_root(self) -> str:
        """The level-0 protocol root: H over the canonical config fields.

        This digest is the PROTOCOL AUTHORITY anchor.  It is an INPUT to the
        model (the honest way to say: the protocol itself), matching the
        Phase 1G disclosure A-G2 — now carried as an explicit object with a
        digest instead of a prose assumption."""
        return canonical_digest(DOM_PROTOCFG, self.canonical_fields())


def policy_authority_id(chain_id: int, fork_version: str) -> str:
    """Context-derived (config-derived) policy authority identity."""
    return canonical_digest("SRW3-AUTH-I-V1", {
        "role": "policyAuthority", "chainId": chain_id,
        "forkVersion": fork_version})


# ---------------------------------------------------------------------------
# PolicyCommitment
# ---------------------------------------------------------------------------

@dataclass(frozen=True)
class PolicyCommitment:
    policy_version: str
    policy_digest: str
    app_set_digest: str
    graph_digest: str

    def canonical_fields(self, chain_id: int, fork_version: str) -> dict:
        return {
            "policyVersion": self.policy_version,
            "policyDigest": self.policy_digest,
            "appSetDigest": self.app_set_digest,
            "graphDigest": self.graph_digest,
            "policyAuthorityId":
                policy_authority_id(chain_id, fork_version),
        }

    def commitment(self, chain_id: int, fork_version: str) -> str:
        return canonical_digest(DOM_POLICYCOMMIT,
                                self.canonical_fields(chain_id, fork_version))


# ---------------------------------------------------------------------------
# Authority checks (the negative-control surface; spec sections 5/6)
# ---------------------------------------------------------------------------

def policy_valid(pc: PolicyCommitment, cfg: ProtocolConfig,
                 presented: str | None = None) -> tuple[bool, str]:
    """PolicyValid(B): the policy commitment applicable to B equals the
    protocol-authorized commitment.  Authority is checked ONLY against the
    protocol config — never against the policy object's own content, so a
    self-authorizing policy (a policy that carries its own authority
    statement) has no path to acceptance."""
    authorized = cfg.policy_commitment
    claimed = presented if presented is not None else \
        pc.commitment(cfg.chain_id, cfg.fork_version)
    if claimed != authorized:
        return False, (f"policy commitment mismatch: presented {claimed[:18]}..."
                       f" != protocol-authorized {authorized[:18]}...")
    return True, "protocol-authorized policy commitment"


def self_authorizing_policy_accepted(pc: PolicyCommitment, cfg: ProtocolConfig,
                                     self_claim: str) -> tuple[bool, str]:
    """Negative control: a policy that declares ITSELF authorized (its own
    commitment, or an authority statement inside the policy object).  The
    protocol check consumes only cfg — the self-claim is inert — so the
    answer is False unless the self-claim coincidentally equals the
    protocol-authorized commitment (which an attacker cannot mint without
    controlling the protocol config)."""
    ok, why = policy_valid(pc, cfg, presented=self_claim)
    return ok, why


def evidence_self_authorization_blocked(issuer_identity: str,
                                        cfg: ProtocolConfig) -> tuple[bool, str]:
    """Negative control: evidence issued by an identity that is NOT the
    protocol-authorized execution client (including evidence that carries a
    self-declared authorization) is rejected at the authority layer."""
    if issuer_identity != cfg.exec_client_identity:
        return False, ("evidence issuer is not the protocol-authorized "
                       f"execution client ({issuer_identity[:24]}... )")
    return True, "authorized execution client"
