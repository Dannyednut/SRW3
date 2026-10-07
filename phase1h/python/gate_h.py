"""SRW3 Phase 1H — Gate_H: the SRW3 security gate at the client boundary.

Layered verdict (Phase 1D-R1/1E/1F/1G discipline carried to a real client):

  L1  evidence binding        payload/parent/child/execution-id cross-checked
                              against client records (state-root binding, §9)
  L2  effect completeness     presented-vs-executed effect comparison (1F LEVEL-3
                              CORE: declared == execution-derived), H3/H-A4
  L3  authority               AuthorityCertificate chain (1G NoCircularAuthority),
                              H5/H8/H10 + adversarial A2/A8/A10
  L4  policy context binding  SecurityContext_H fields (policy version, chain,
                              application set, interaction graph, lineage head,
                              execution config), H6/H7 + A7/A9
  L5  security invariants     policy invariants evaluated on the DERIVED
                              effect trace (H2)
  L6  interaction obligations policy interaction graph on the ordered trace
                              (H9)

Verdicts: SRW3_VALID | SRW3_REJECT(layer, reason).  This gate NEVER changes
the Ethereum validity result (shadow mode, §3/§6).
"""
from __future__ import annotations

from dataclasses import dataclass, field

from authority import (AuthorityCertificate, make_protocol_root,
                       make_client_cert, make_evidence_cert,
                       verify_certificate_chain, cert_id_for)
from evidence import ClientExecutionEvidence
from policy import Policy


@dataclass
class SecurityContext_H:
    """Section 11 candidate — every field records source + authority."""
    policy_version: str
    chain_id: int
    application_set_digest: str
    interaction_graph_digest: str
    lineage_head: str
    client_execution_config: str
    field_provenance: dict = field(default_factory=dict)


@dataclass
class GateVerdict:
    verdict: str                # SRW3_VALID | SRW3_REJECT | SRW3_ERROR
    layer: str | None = None
    reason: str | None = None
    checks: dict = field(default_factory=dict)


def _digest_fields(ctx_fields: dict) -> str:
    from eth_utils import keccak
    can = "|".join(f"{k}={ctx_fields[k]}" for k in sorted(ctx_fields))
    return "0x" + keccak(can.encode()).hex()


def build_security_context(policy: Policy, policy_digest: str, chain_id: int,
                           lineage_head: str, client_config_digest: str,
                           client_identity: str) -> SecurityContext_H:
    app_can = "|".join(sorted(policy.application_set))
    from eth_utils import keccak
    app_digest = "0x" + keccak(app_can.encode()).hex()
    ig_can = "|".join(
        o["id"] for o in policy.interaction_graph.get("obligations", []))
    ig_digest = "0x" + keccak(ig_can.encode()).hex()
    return SecurityContext_H(
        policy_version=policy.policy_version,
        chain_id=chain_id,
        application_set_digest=app_digest,
        interaction_graph_digest=ig_digest,
        lineage_head=lineage_head,
        client_execution_config=client_config_digest,
        field_provenance={
            "policyVersion": {"source": "srw3_policy.json",
                              "authority": "deployment-pinned policy digest "
                                           "(governance input, A-G7 preserved)",
                              "verification": "digest recompute vs deployment pin"},
            "chainId": {"source": "eth_chainId (client)",
                        "authority": "protocol chain identity",
                        "verification": "equality with deployment chainId"},
            "applicationSetDigest": {"source": "policy applicationSet",
                                     "authority": "policy (authorized above)",
                                     "verification": "digest over sorted set"},
            "interactionGraphDigest": {"source": "policy interactionGraph",
                                       "authority": "policy (authorized above)",
                                       "verification": "digest over obligation ids"},
            "lineageHead": {"source": "SRW3 lineage sidecar",
                            "authority": "SRW3 records only; never client state",
                            "verification": "sidecar persistence + reorg rules"},
            "clientExecutionConfig": {"source": "debug_chainConfig + clientVersion",
                                      "authority": "execution client (L1 cert)",
                                      "verification": "digest vs authority certificate"},
            "policyDigest": {"source": "policy file", "authority": "deployment pin",
                             "verification": "digest recompute"},
            "_policyDigest": policy_digest,
            "_clientIdentity": client_identity,
        },
    )


class GateH:
    """The SRW3 gate (shadow mode by default)."""

    def __init__(self, policy: Policy, policy_digest: str, genesis_hash: str,
                 state_reader=None):
        self.policy = policy
        self.policy_digest = policy_digest
        self.genesis_hash = genesis_hash
        # state_reader(addr, slot, block_hash) -> 32-byte hex value.
        # Invariant bounds that are NOT written in the evaluated block are
        # read from the client's authoritative post-state via
        # eth_getStorageAt (recorded: the tx-diff alone does not expose
        # untouched invariant bounds - a Phase 1H boundary finding).
        self.state_reader = state_reader
        self.root_cert = make_protocol_root(genesis_hash, policy.authority_config
                                            ["protocolRoot"]["chainId"])

    def client_cert(self, ev: ClientExecutionEvidence) -> AuthorityCertificate:
        return make_client_cert(
            self.root_cert,
            ev.execution_identity["client"],
            ev.execution_identity["chainId"],
            ev.execution_configuration["configDigest"],
        )

    def evidence_cert(self, ev: ClientExecutionEvidence) -> AuthorityCertificate:
        cc = self.client_cert(ev)
        return make_evidence_cert(cc, ev.execution_id, ev.effect_digest,
                                  ev.parent_root, ev.child_state_root)

    # ----------------------------------------------------------

    def evaluate(self, ev: ClientExecutionEvidence,
                 presented_effects=None,
                 context_override: dict | None = None,
                 skip_invariants: bool = False) -> tuple[GateVerdict, dict]:
        checks: dict = {}
        if callable(presented_effects):
            presented_effects = presented_effects(ev)

        # ---- L1: evidence binding / state-root binding ----
        sco = context_override or {}
        if "expectedParentRoot" in sco and \
                ev.parent_root.lower() != sco["expectedParentRoot"].lower():
            return GateVerdict("SRW3_REJECT", "evidence-binding",
                               "stale or mismatched parent root (H4/H-A5)"), checks
        if "expectedChildRoot" in sco and \
                ev.child_state_root.lower() != sco["expectedChildRoot"].lower():
            return GateVerdict("SRW3_REJECT", "evidence-binding",
                               "tampered child state root (H-A12)"), checks
        if ev.parent_root == ev.child_state_root:
            return GateVerdict("SRW3_REJECT", "evidence-binding",
                               "parent root equals child root"), checks
        if not ev.execution_id or not ev.effect_digest:
            return GateVerdict("SRW3_REJECT", "evidence-binding",
                               "missing execution/effect digest"), checks
        checks["L1_evidence_binding"] = "ok"

        # ---- L2: effect completeness (presented vs execution-derived) ----
        if presented_effects is not None:
            declared_writes = {
                (w["address"].lower(), w["slot"].lower()): w["value"].lower()
                for w in presented_effects.get("writes", [])
            }
            derived_writes = {k: v.lower() for k, v in ev.storage_writes.items()}
            if declared_writes != derived_writes:
                hidden = sorted(set(derived_writes) - set(declared_writes))
                phantom = sorted(set(declared_writes) - set(derived_writes))
                changed = sorted(
                    k for k in set(declared_writes) & set(derived_writes)
                    if declared_writes[k] != derived_writes[k])
                checks["L2_hidden_writes"] = hidden
                checks["L2_phantom_writes"] = phantom
                checks["L2_changed_values"] = changed
                return GateVerdict(
                    "SRW3_REJECT", "effect-completeness",
                    f"declared != executed: hidden={len(hidden)} "
                    f"phantom={len(phantom)} changed={len(changed)}"), checks
        checks["L2_effect_completeness"] = \
            "executed-derived (presented==executed by Mode A construction)"

        # ---- L3: authority certificate chain ----
        cc = self.client_cert(ev)
        ec = make_evidence_cert(cc, ev.execution_id, ev.effect_digest,
                                ev.parent_root, ev.child_state_root)
        certs_by_id = {
            self.root_cert.cert_id: self.root_cert,
            cc.cert_id: cc,
            ec.cert_id: ec,
        }
        ctx = {
            "protocolRootSubject": self.root_cert.subject,
            "protocolRootGenesis": self.genesis_hash.lower(),
            "chainId": ev.execution_identity["chainId"],
            "authorizedClientSubject": cc.subject,
            "clientConfigDigest": ev.execution_configuration["configDigest"],
            "policyVersion": self.policy.policy_version,
            "certsById": certs_by_id,
        }
        if context_override:
            ctx.update(context_override)
        av = verify_certificate_chain(ec, ctx)
        if not av.ok:
            checks["L3_authority_layer"] = av.layer
            return GateVerdict("SRW3_REJECT", f"authority:{av.layer}", av.reason), checks
        checks["L3_authority"] = ec.cert_id

        # ---- L4: policy context binding (SecurityContext_H) ----
        if sco.get("presentedPolicyVersion") not in (None, self.policy.policy_version):
            return GateVerdict("SRW3_REJECT", "policy-context",
                               "presented policy version differs from authorized "
                               "policy (H6/H-A7)"), checks
        if sco.get("presentedConfigDigest") not in (None, ev.execution_configuration["configDigest"]):
            return GateVerdict("SRW3_REJECT", "policy-context",
                               "execution configuration substitution (H7/H-A9)"), checks
        if sco.get("presentedChainId") not in (None, ev.execution_identity["chainId"]):
            return GateVerdict("SRW3_REJECT", "policy-context",
                               "chain identity substitution"), checks
        if "expectedLineageHead" in sco and \
                sco.get("presentedLineageHead") not in (None, sco["expectedLineageHead"]):
            return GateVerdict("SRW3_REJECT", "policy-context",
                               "stale lineage head presented (H-A5)"), checks
        checks["L4_policy_context"] = self.policy.policy_version

        # ---- L5/L6: invariants + interaction obligations on DERIVED effects ----
        if not skip_invariants:
            inv_fail = self._check_invariants(ev)
            if inv_fail:
                checks["L5_invariant"] = inv_fail
                return GateVerdict("SRW3_REJECT", "invariant", inv_fail), checks
            checks["L5_invariants"] = "ok"
            io_fail = self._check_interactions(ev)
            if io_fail:
                checks["L6_interaction"] = io_fail
                return GateVerdict("SRW3_REJECT", "interaction", io_fail), checks
            checks["L6_interaction"] = "ok"

        return GateVerdict("SRW3_VALID"), checks

    # ----------------------------------------------------------

    def _slot_final(self, ev: ClientExecutionEvidence, addr: str,
                    slot: str) -> str | None:
        want = int(slot, 16)
        for (a, s), v in ev.storage_writes.items():
            if a == addr.lower() and int(s, 16) == want:
                return v
        return None

    def _check_invariants(self, ev: ClientExecutionEvidence) -> str | None:
        for inv in self.policy.invariants:
            kind = inv["type"]
            if kind == "slot_le":
                addr = inv["contract"].lower()
                val = self._slot_final(ev, addr, inv["slot"])
                cap = self._slot_final(ev, addr, inv["boundSlot"])
                if val is not None and cap is None and self.state_reader is not None:
                    cap = self.state_reader(addr, inv["boundSlot"], ev.payload_digest)
                if val is not None and cap is not None:
                    if int(val, 16) > int(cap, 16):
                        return (f"{inv['id']}: totalBorrowed(0x{int(val,16):x}) > "
                                f"borrowCap(0x{int(cap,16):x})")
            elif kind == "slot_unchanged":
                addr = inv["contract"].lower()
                want = int(inv["slot"], 16)
                for (a, s) in ev.storage_writes:
                    if a == addr and int(s, 16) == want:
                        if ev.storage_writes[(a, s)].lower() != inv["expected"].lower():
                            return f"{inv['id']}: protected slot written"
        return None

    def _check_interactions(self, ev: ClientExecutionEvidence) -> str | None:
        for ob in self.policy.interaction_graph.get("obligations", []):
            if ob["type"] == "write_before_read_same_block":
                wfn = ob["writer"]["fnSel"].lower()
                rfn = ob["reader"]["fnSel"].lower()
                wi = ri = None
                for entry in ev.effect_trace:
                    if entry[0] == "CALL":
                        c = entry[1]
                        if c["fn"].lower() == wfn and c["type"] in ("CALL", "CALLCODE"):
                            wi = wi if wi is not None else entry[1].get("_i")
                # re-scan with tx indices: effect_trace entries carry TX markers
                w_idx = r_idx = None
                cur_tx = None
                for entry in ev.effect_trace:
                    if entry[0] == "TX":
                        cur_tx = entry[1]
                    elif entry[0] == "CALL":
                        c = entry[1]
                        if c["fn"].lower() == wfn:
                            w_idx = cur_tx if w_idx is None else w_idx
                        if c["fn"].lower() == rfn:
                            r_idx = cur_tx if r_idx is None else r_idx
                if w_idx is not None and r_idx is not None and w_idx > r_idx:
                    return (f"{ob['id']}: oracle write (tx {w_idx}) ordered AFTER "
                            f"borrow (tx {r_idx}) in the same block")
        return None
