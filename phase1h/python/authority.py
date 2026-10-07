"""SRW3 Phase 1H — AuthorityCertificate machinery (Phase 1G rules carried to
the client boundary).

Structure (mirrors 1G rel/level discipline):
  level 0: protocol root          (devnet genesis + Engine API boundary)
  level 1: execution client       (geth identity, authorized by level 0)
  level 2: execution evidence     (ClientExecutionEvidence, authorized by L1)

Non-circularity checks (1G NoCircularAuthority, ported):
  NC1  a certificate never cites itself (as parent or source)
  NC2  levels strictly decrease along the parent chain
  NC3  the chain terminates at an authorized level-0 protocol root
  NC4  each step's issuer identity is authorized in the context
       (context-derived: chainId, genesis, client config, policy version —
       never taken from the certificate being verified)
"""
from __future__ import annotations

from dataclasses import dataclass, field, asdict

from eth_utils import keccak


@dataclass
class AuthorityCertificate:
    cert_id: str
    subject: str            # what this certificate authorizes
    level: int              # 0 = protocol, 1 = client, 2 = evidence
    issuer_domain: str      # WHO established the authority
    parent_cert_id: str | None
    rel: int                # 1 = record-binding cert, 2 = derivation cert
    bindings: dict = field(default_factory=dict)

    def to_json(self) -> dict:
        return asdict(self)


def cert_id_for(cert: AuthorityCertificate) -> str:
    can = "|".join([
        "SRW3-AZCERT-V1",
        cert.subject, str(cert.level), cert.issuer_domain,
        cert.parent_cert_id or "-", str(cert.rel),
        "|".join(f"{k}={v}" for k, v in sorted(cert.bindings.items())),
    ])
    return "0x" + keccak(can.encode()).hex()


def make_protocol_root(genesis_hash: str, chain_id: int) -> AuthorityCertificate:
    """LEVEL 0 — protocol-given (A-G2 boundary, carried from Phase 1G)."""
    c = AuthorityCertificate(
        cert_id="", subject=f"protocol:{chain_id}", level=0,
        issuer_domain="protocol-given", parent_cert_id=None, rel=0,
        bindings={"genesisHash": genesis_hash.lower(), "chainId": str(chain_id)},
    )
    c.cert_id = cert_id_for(c)
    return c


def make_client_cert(root: AuthorityCertificate, client_version: str,
                     chain_id: int, config_digest: str) -> AuthorityCertificate:
    """LEVEL 1 — authorizes the execution client's outputs."""
    c = AuthorityCertificate(
        cert_id="", subject=f"execution-client:{client_version}", level=1,
        issuer_domain=root.subject, parent_cert_id=root.cert_id, rel=1,
        bindings={
            "chainId": str(chain_id),
            "clientVersion": client_version,
            "configDigest": config_digest,
        },
    )
    c.cert_id = cert_id_for(c)
    return c


def make_evidence_cert(client: AuthorityCertificate, execution_id: str,
                       effect_digest: str, parent_root: str,
                       child_root: str) -> AuthorityCertificate:
    """LEVEL 2 — binds the execution-derived evidence fields (rel=1)."""
    c = AuthorityCertificate(
        cert_id="", subject=f"execution-evidence:{execution_id}", level=2,
        issuer_domain=client.subject, parent_cert_id=client.cert_id, rel=1,
        bindings={
            "executionId": execution_id,
            "effectDigest": effect_digest,
            "parentRoot": parent_root.lower(),
            "childRoot": child_root.lower(),
        },
    )
    c.cert_id = cert_id_for(c)
    return c


class AuthorityVerdict:
    def __init__(self):
        self.ok = True
        self.layer = None
        self.reason = ""

    def fail(self, layer: str, reason: str) -> "AuthorityVerdict":
        self.ok = False
        self.layer = layer
        self.reason = reason
        return self


def verify_certificate_chain(cert: AuthorityCertificate, context: dict) -> AuthorityVerdict:
    """1G non-circularity + authorization, ported to the client boundary.

    context must contain (context-derived, NOT taken from `cert`):
      protocolRootSubject, protocolRootGenesis, chainId,
      authorizedClientSubject, clientConfigDigest, policyVersion
    """
    seen = set()
    cur = cert
    depth = 0
    while True:
        # NC1: no self-citation
        if cur.cert_id == (cur.parent_cert_id or ""):
            return AuthorityVerdict().fail("authcircle", "certificate cites itself as parent")
        if cur.issuer_domain == cur.subject:
            return AuthorityVerdict().fail("authsrc", "certificate is its own authority source")
        if cur.cert_id in seen:
            return AuthorityVerdict().fail("authcircle", f"cycle at {cur.cert_id[:18]}")
        seen.add(cur.cert_id)
        # termination at an authorized level-0 protocol root
        if cur.level == 0:
            if cur.subject != context["protocolRootSubject"]:
                return AuthorityVerdict().fail(
                    "authroot", f"unknown protocol root {cur.subject}")
            if cur.bindings.get("genesisHash") != context["protocolRootGenesis"]:
                return AuthorityVerdict().fail(
                    "authroot", "protocol root genesis mismatch (H-A2/H5)")
            if cur.bindings.get("chainId") != str(context["chainId"]):
                return AuthorityVerdict().fail("authroot", "protocol root chainId mismatch")
            return AuthorityVerdict()
        # NC4: issuer identity must be the CONTEXT-authorized issuer for this level
        if cur.level == 1:
            if cur.issuer_domain != context["protocolRootSubject"]:
                return AuthorityVerdict().fail("authsrc", "L1 issuer is not the protocol root")
            if cur.subject != context["authorizedClientSubject"]:
                return AuthorityVerdict().fail(
                    "authclient", "execution client not authorized in context (H5/H-A8)")
            if cur.bindings.get("configDigest") != context["clientConfigDigest"]:
                return AuthorityVerdict().fail(
                    "authconfig", "client config digest mismatch (H7/H-A9)")
            if cur.bindings.get("chainId") != str(context["chainId"]):
                return AuthorityVerdict().fail("authconfig", "chainId mismatch")
        if cur.level == 2:
            if cur.issuer_domain != context["authorizedClientSubject"]:
                return AuthorityVerdict().fail(
                    "authsrc", "evidence issuer is not the authorized client")
        if cur.level != 2 and depth == 0 and cur.subject.startswith("execution-evidence:"):
            # the certificate under evaluation must bind the policy version
            if cur.bindings.get("policyVersion") not in (None, context["policyVersion"]):
                return AuthorityVerdict().fail("authpolicy", "policy version binding mismatch")
        # NC2: strict level decrease toward the root
        parent_id = cur.parent_cert_id
        if parent_id is None:
            return AuthorityVerdict().fail("authroot", "chain does not terminate at level 0")
        if parent_id not in context.get("certsById", {}):
            return AuthorityVerdict().fail("authroot", f"parent {parent_id[:18]} unavailable")
        parent = context["certsById"][parent_id]
        if parent.level >= cur.level:
            return AuthorityVerdict().fail("authlevel", "level does not strictly decrease")
        cur = parent
        depth += 1
