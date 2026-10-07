"""SRW3 Phase 1H — Gate_H: the SRW3 security gate at the client boundary.

Layered verdict (Phase 1D-R1/1E/1F/1G discipline carried to a real client):

  SC  security-context binding  SecurityContext_H is a FIRST-CLASS gate
                              input (Phase 1H-R1): the supplied context is
                              validated (SC-1..SC-9) against gate-local
                              authoritative state BEFORE any substantive
                              layer runs.  A mutated, substituted, stale or
                              internally inconsistent context yields
                              SRW3_REJECT at the security-context layer.
                              SC-10 is architectural: the gate NEVER
                              rebuilds/replaces an invalid context.
  L1  evidence binding        payload/parent/child/execution-id cross-checked
                              against client records (state-root binding, §9)
  L2  effect completeness     presented-vs-executed effect comparison (1F LEVEL-3
                              CORE: declared == execution-derived), H3/H-A4
  L3  authority               AuthorityCertificate chain (1G NoCircularAuthority),
                              H5/H8/H10 + adversarial A2/A8/A10
  L4  policy context binding  presented (attacker-supplied) bindings vs
                              authoritative state, H6/H7 + A7/A9
  L5  security invariants     policy invariants evaluated on the DERIVED
                              effect trace (H2)
  L6  interaction obligations policy interaction graph on the ordered trace
                              (H9)

Verdicts: SRW3_VALID | SRW3_REJECT(layer, reason).  This gate NEVER changes
the Ethereum validity result (shadow mode, §3/§6).

AUTHORITY NOTE (Phase 1H-R1, section 8): the security context does NOT
become an authority source.  The context digest is an integrity/binding
mechanism only — an attacker who recomputes a valid digest over mutated
fields still fails the field bindings (SC-1..SC-8 compare the context
against gate-local authoritative state: the deployment-pinned policy, the
client-derived evidence, the lineage sidecar).  Authority remains exactly

    protocol root -> authorized execution client -> execution evidence
"""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Callable

from authority import (AuthorityCertificate, make_protocol_root,
                       make_client_cert, make_evidence_cert,
                       verify_certificate_chain, cert_id_for)
from evidence import ClientExecutionEvidence
from policy import Policy


# ---------------------------------------------------------------------------
# SecurityContext_H — first-class gate input (Phase 1H-R1)
# ---------------------------------------------------------------------------

# Fixed security-relevant fields; the canonical context digest is computed
# over exactly this field set (see canonical_context_fields /
# compute_context_digest).  Order here is documentation; the digest uses
# lexicographic key order for determinism.
SECURITY_CONTEXT_FIELDS = (
    "policyVersion",
    "policyDigest",
    "chainId",
    "applicationSetDigest",
    "interactionGraphDigest",
    "lineageHead",
    "clientExecutionConfig",
    "clientIdentity",
)

# Domain tag for the canonical context serialization (R1): separates context
# digests from every other SRW3 digest domain.
CONTEXT_DIGEST_DOM = "SRW3-CONTEXT-H-V1"


@dataclass
class SecurityContext_H:
    """Section 11 candidate, first-class as of Phase 1H-R1.

    Every field records source + authority in field_provenance.  The
    context_digest is computed over the canonical serialization of the
    security-relevant fields only (no timestamps, no pids, no paths, no
    dict-order dependence) and is re-verified by the gate (SC-9).

    The context is an INPUT to the gate, never an authority root: the gate
    validates each field against its own authoritative state and never
    reconstructs or substitutes the context (SC-10).
    """
    policy_version: str
    policy_digest: str
    chain_id: int
    application_set_digest: str
    interaction_graph_digest: str
    lineage_head: str
    client_execution_config: str
    client_identity: str
    context_digest: str = ""
    field_provenance: dict = field(default_factory=dict)

    def canonical_fields(self) -> dict:
        """Canonical (deterministic) security-relevant field map."""
        return canonical_context_fields(self)

    def to_json(self) -> dict:
        return {
            **self.canonical_fields(),
            "contextDigest": self.context_digest,
            "fieldProvenance": self.field_provenance,
        }


def canonical_context_fields(sc_or_fields) -> dict:
    """Canonical representation of the security-relevant context fields.

    Normalizations (deterministic by construction):
      * chainId -> decimal string of the integer value;
      * all other fields -> verbatim strings;
    Excluded by construction: timestamps, process ids, object addresses,
    filesystem paths, dict-ordering (keys are fixed by
    SECURITY_CONTEXT_FIELDS; the digest sorts them again).
    """
    get = (lambda k: getattr(sc_or_fields, k)) \
        if hasattr(sc_or_fields, "policy_version") else (lambda k: sc_or_fields[k])
    return {
        "policyVersion": str(get("policy_version")),
        "policyDigest": str(get("policy_digest")),
        "chainId": str(int(get("chain_id"))),
        "applicationSetDigest": str(get("application_set_digest")),
        "interactionGraphDigest": str(get("interaction_graph_digest")),
        "lineageHead": str(get("lineage_head")),
        "clientExecutionConfig": str(get("client_execution_config")),
        "clientIdentity": str(get("client_identity")),
    }


def compute_context_digest(fields: dict) -> str:
    """keccak256 over the canonical context serialization (documented R1).

    Canonical form: CONTEXT_DIGEST_DOM + "\\n" + "\\n".join("k=v" for the
    fields in lexicographic key order).  Every value is a string produced
    by canonical_context_fields; no floats, no wall-clock values, no
    unordered serialization.
    """
    from eth_utils import keccak
    can = CONTEXT_DIGEST_DOM + "\n" + "\n".join(
        f"{k}={fields[k]}" for k in sorted(fields))
    return "0x" + keccak(can.encode()).hex()


def context_digest_of(sc: SecurityContext_H) -> str:
    return compute_context_digest(canonical_context_fields(sc))


def _application_set_digest(policy: Policy) -> str:
    from eth_utils import keccak
    app_can = "|".join(sorted(policy.application_set))
    return "0x" + keccak(app_can.encode()).hex()


def _interaction_graph_digest(policy: Policy) -> str:
    from eth_utils import keccak
    ig_can = "|".join(
        o["id"] for o in policy.interaction_graph.get("obligations", []))
    return "0x" + keccak(ig_can.encode()).hex()


def build_security_context(policy: Policy, policy_digest: str, chain_id: int,
                           lineage_head: str, client_config_digest: str,
                           client_identity: str) -> SecurityContext_H:
    """Construct the SecurityContext_H for one evaluation (caller-side).

    The HARNESS (or test runner) constructs the context; the gate only
    consumes and validates it.  All inputs are deterministic:
    policy fields and the deployment-pinned digest, the client-derived
    chain id and execution configuration/identity, and the applicable
    lineage head from the SRW3 sidecar.  No wall-clock value enters the
    context or its digest.
    """
    app_digest = _application_set_digest(policy)
    ig_digest = _interaction_graph_digest(policy)
    sc = SecurityContext_H(
        policy_version=policy.policy_version,
        policy_digest=policy_digest,
        chain_id=chain_id,
        application_set_digest=app_digest,
        interaction_graph_digest=ig_digest,
        lineage_head=lineage_head,
        client_execution_config=client_config_digest,
        client_identity=client_identity,
        field_provenance={
            "policyVersion": {"source": "srw3_policy.json",
                              "authority": "deployment-pinned policy digest "
                                           "(governance input, A-G7 preserved)",
                              "verification": "SC-1 vs gate-local authorized policy"},
            "policyDigest": {"source": "policy file",
                             "authority": "deployment pin (outside the policy)",
                             "verification": "SC-2 vs deployment-pinned digest"},
            "chainId": {"source": "eth_chainId (client)",
                        "authority": "protocol chain identity",
                        "verification": "SC-3 vs client-derived evidence chainId"},
            "applicationSetDigest": {"source": "policy applicationSet",
                                     "authority": "policy (authorized above)",
                                     "verification": "SC-4 digest recompute over sorted set"},
            "interactionGraphDigest": {"source": "policy interactionGraph",
                                       "authority": "policy (authorized above)",
                                       "verification": "SC-5 digest recompute over obligation ids"},
            "lineageHead": {"source": "SRW3 lineage sidecar",
                            "authority": "SRW3 records only; never client state",
                            "verification": "SC-8 vs gate lineage-head source"},
            "clientExecutionConfig": {"source": "admin_nodeInfo chainConfig + clientVersion",
                                      "authority": "execution client (L1 cert)",
                                      "verification": "SC-6 vs evidence configuration digest"},
            "clientIdentity": {"source": "web3_clientVersion (client)",
                               "authority": "execution client (L1 cert subject)",
                               "verification": "SC-7 vs evidence execution identity"},
            "contextDigest": {"source": "canonical serialization of the fields above",
                              "authority": "none (integrity/binding mechanism only; "
                                           "the digest does not authorize anything)",
                              "verification": "SC-9 recompute over canonical fields"},
        },
    )
    sc.context_digest = context_digest_of(sc)
    return sc


@dataclass
class GateVerdict:
    verdict: str                # SRW3_VALID | SRW3_REJECT | SRW3_ERROR
    layer: str | None = None
    reason: str | None = None
    checks: dict = field(default_factory=dict)


class GateH:
    """The SRW3 gate (shadow mode by default)."""

    def __init__(self, policy: Policy, policy_digest: str, genesis_hash: str,
                 state_reader=None, lineage_head_provider: Callable[[], str | None] | None = None):
        self.policy = policy
        self.policy_digest = policy_digest
        self.genesis_hash = genesis_hash
        # state_reader(addr, slot, block_hash) -> 32-byte hex value.
        # Invariant bounds that are NOT written in the evaluated block are
        # read from the client's authoritative post-state via
        # eth_getStorageAt (recorded: the tx-diff alone does not expose
        # untouched invariant bounds - a Phase 1H boundary finding).
        self.state_reader = state_reader
        # lineage_head_source() -> the applicable SRW3 lineage head (R1, SC-8).
        # Wired by the harness to the sidecar head; if absent (and no
        # explicit per-evaluation expectation is supplied) the gate FAILS
        # CLOSED on SC-8 rather than evaluating with an unbound lineage head.
        self.lineage_head_provider = lineage_head_provider
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
    # SC layer (R1): validate the SUPPLIED SecurityContext_H against
    # gate-local authoritative state.  No field of the context is taken
    # as authority; every binding is an equality against an independent
    # source.  SC-10 (no silent substitution) is architectural: there is
    # no code path that rebuilds a context after a failed check.
    # ----------------------------------------------------------

    def _sc_reject(self, checks: dict, n: str, name: str, detail: str):
        return GateVerdict(
            "SRW3_REJECT", "security-context",
            f"SC-{n} {name} binding violated: {detail}"), checks

    def _validate_security_context(
            self, sc: SecurityContext_H, ev: ClientExecutionEvidence,
            lineage_head_expectation: str | None) -> GateVerdict | None:
        """SC-1..SC-9.  Returns a reject verdict or None if all hold."""
        if sc.policy_version != self.policy.policy_version:
            return GateVerdict("SRW3_REJECT", "security-context",
                               f"SC-1 policy version binding violated: context "
                               f"{sc.policy_version!r} != authorized policy "
                               f"{self.policy.policy_version!r}")
        if sc.policy_digest != self.policy_digest:
            return GateVerdict("SRW3_REJECT", "security-context",
                               f"SC-2 policy digest binding violated: context "
                               f"{sc.policy_digest[:18]}... != deployment-pinned "
                               f"{self.policy_digest[:18]}...")
        if int(sc.chain_id) != int(ev.execution_identity["chainId"]):
            return GateVerdict("SRW3_REJECT", "security-context",
                               f"SC-3 chain identity binding violated: context "
                               f"chainId {sc.chain_id} != client-derived "
                               f"{ev.execution_identity['chainId']}")
        if sc.application_set_digest != _application_set_digest(self.policy):
            return GateVerdict("SRW3_REJECT", "security-context",
                               "SC-4 application-set binding violated: context "
                               "applicationSetDigest != digest(authorized "
                               "application set)")
        if sc.interaction_graph_digest != _interaction_graph_digest(self.policy):
            return GateVerdict("SRW3_REJECT", "security-context",
                               "SC-5 interaction-graph binding violated: context "
                               "interactionGraphDigest != digest(authorized "
                               "interaction graph)")
        if sc.client_execution_config != ev.execution_configuration["configDigest"]:
            return GateVerdict("SRW3_REJECT", "security-context",
                               "SC-6 client configuration binding violated: "
                               "context clientExecutionConfig != execution "
                               "evidence configuration digest")
        if sc.client_identity != ev.execution_identity["client"]:
            return GateVerdict("SRW3_REJECT", "security-context",
                               f"SC-7 client identity binding violated: context "
                               f"{sc.client_identity!r} != execution evidence "
                               f"authorized client identity "
                               f"{ev.execution_identity['client']!r}")
        # SC-8: the supplied context's lineage head must be the lineage
        # state applicable to THIS evaluation.  The expectation comes from
        # the gate's lineage-head source (sidecar) or, for authorized
        # replay evaluation, from the persisted record being replayed —
        # never from a reconstructed context.
        if lineage_head_expectation is not None:
            expected_head = lineage_head_expectation
        elif self.lineage_head_provider is not None:
            expected_head = self.lineage_head_provider()
        else:
            return GateVerdict("SRW3_REJECT", "security-context",
                               "SC-8 lineage-head binding violated: no "
                               "lineage-head source configured (fail-closed; "
                               "wire GateH.lineage_head_provider or pass an "
                               "explicit lineage_head_expectation)")
        if sc.lineage_head != expected_head:
            return GateVerdict("SRW3_REJECT", "security-context",
                               f"SC-8 lineage-head binding violated: context "
                               f"{str(sc.lineage_head)[:18]}... != applicable "
                               f"lineage head {str(expected_head)[:18]}...")
        # SC-9: integrity of the supplied object itself.
        recomputed = context_digest_of(sc)
        if sc.context_digest != recomputed:
            return GateVerdict("SRW3_REJECT", "security-context",
                               f"SC-9 context digest integrity violated: "
                               f"recorded {sc.context_digest[:18]}... != "
                               f"recomputed {recomputed[:18]}...")
        return None

    # ----------------------------------------------------------

    def evaluate(self, ev: ClientExecutionEvidence, *,
                 security_context: SecurityContext_H,
                 presented_effects=None,
                 presented_context: dict | None = None,
                 expectations: dict | None = None,
                 skip_invariants: bool = False,
                 lineage_head_expectation: str | None = None
                 ) -> tuple[GateVerdict, dict]:
        """Evaluate one payload against the SRW3 layers.

        security_context  — REQUIRED first-class input: the SecurityContext_H
                            constructed for THIS evaluation by the caller
                            (harness).  Validated (SC-1..SC-9) before any
                            substantive layer; never rebuilt or substituted
                            by the gate (SC-10).
        presented_effects — attacker/producer-presented effect record
                            (Mode H-B surface; compared vs execution-derived).
        presented_context — attacker-PRESENTED bindings (substituted policy
                            version / config digest / chain id / lineage
                            head / authorized client subject); checked
                            against authoritative state at L3/L4.
        expectations      — evaluation-time expectation pins used by the
                            stale-evidence tests (expectedParentRoot,
                            expectedChildRoot, expectedLineageHead).
        lineage_head_expectation — explicit applicable lineage head for
                            authorized replay evaluation (from the
                            persisted record); overrides the provider for
                            this single evaluation (SC-8).
        """
        checks: dict = {}
        if callable(presented_effects):
            presented_effects = presented_effects(ev)
        pc = presented_context or {}
        ex = expectations or {}

        # ---- SC: SecurityContext_H validation (first-class, R1) ----
        sc_fail = self._validate_security_context(security_context, ev,
                                                  lineage_head_expectation)
        if sc_fail is not None:
            checks["SC_security_context"] = {
                "status": "REJECTED",
                "contextDigest": security_context.context_digest,
            }
            return sc_fail, checks
        checks["SC_security_context"] = {
            "status": "ok",
            "contextDigest": security_context.context_digest,
            "bindings": "SC-1..SC-9 ok (SC-10: no substitution path exists)",
        }

        # ---- L1: evidence binding / state-root binding ----
        if "expectedParentRoot" in ex and \
                ev.parent_root.lower() != ex["expectedParentRoot"].lower():
            return GateVerdict("SRW3_REJECT", "evidence-binding",
                               "stale or mismatched parent root (H4/H-A5)"), checks
        if "expectedChildRoot" in ex and \
                ev.child_state_root.lower() != ex["expectedChildRoot"].lower():
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
        if pc:
            ctx.update(pc)
        av = verify_certificate_chain(ec, ctx)
        if not av.ok:
            checks["L3_authority_layer"] = av.layer
            return GateVerdict("SRW3_REJECT", f"authority:{av.layer}", av.reason), checks
        checks["L3_authority"] = ec.cert_id

        # ---- L4: policy context binding (presented vs authoritative) ----
        if pc.get("presentedPolicyVersion") not in (None, self.policy.policy_version):
            return GateVerdict("SRW3_REJECT", "policy-context",
                               "presented policy version differs from authorized "
                               "policy (H6/H-A7)"), checks
        if pc.get("presentedConfigDigest") not in (None, ev.execution_configuration["configDigest"]):
            return GateVerdict("SRW3_REJECT", "policy-context",
                               "execution configuration substitution (H7/H-A9)"), checks
        if pc.get("presentedChainId") not in (None, ev.execution_identity["chainId"]):
            return GateVerdict("SRW3_REJECT", "policy-context",
                               "chain identity substitution"), checks
        if ex.get("expectedLineageHead") is not None and \
                pc.get("presentedLineageHead") not in (None, ex["expectedLineageHead"]):
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
