"""SRW3 Phase 1I — abstract multi-client protocol interface (spec section 14).

NOT a modification of several real clients: an ABSTRACT client interface with
two deterministic implementations, used to state and TEST the multi-client
semantic requirement BEFORE any real-client work:

    Client_A.execute(B) == Client_B.execute(B)          (post-state)
    Evidence_A(B)  ==  Evidence_B(B)                    under EquivalentEvidence
    =>   SRW3_A(B)  ==  SRW3_B(B)

EquivalentEvidence(E_A, E_B): equality of the SEMANTIC evidence projection —
payload identity, parent/post state roots, effect digest, execution
configuration — modulo client-LOCAL, security-irrelevant presentation
(internal key order, integer encodings).  Non-semantic differences do not
change the SRW3 decision; semantic differences do (and a client divergence
at the state-root level is Ethereum-invalid before SRW3 even runs).
"""
from __future__ import annotations

from dataclasses import dataclass, field

from pi_protocol import (Evidence, ExecutionResult, SecurityContext)


class ClientProtocol:
    """Abstract client interface (spec section 14)."""
    name = "abstract"

    def execute(self, payload: dict, pre_state_root: str) -> ExecutionResult:
        raise NotImplementedError

    def evidence_equivalence_fields(self, er: ExecutionResult) -> dict:
        """The semantic projection used by EquivalentEvidence."""
        return er.canonical_fields()


@dataclass
class DeterministicVM:
    """The shared deterministic execution machine: same (payload, pre-state)
    -> same post-state.  Clients differ only in PRESENTATION."""
    state: dict = field(default_factory=dict)

    def run(self, payload: dict) -> tuple[str, str, str]:
        """Returns (payload_digest, parent_root, post_root); applies writes."""
        import json
        from eth_utils import keccak
        writes = payload.get("writes", {})
        pd = "0x" + keccak(json.dumps(payload, sort_keys=True).encode()).hex()
        parent = payload.get("parentStateRoot", "0x" + "00" * 32)
        new_state = dict(self.state)
        for k, v in sorted(writes.items()):
            new_state[k] = v
        post = "0x" + keccak(
            json.dumps(new_state, sort_keys=True).encode()).hex()
        effects = "|".join(f"{k}={writes[k]}" for k in sorted(writes))
        eff = "0x" + keccak(effects.encode()).hex()
        self.state = new_state
        return pd, parent, post, eff


class ClientA(ClientProtocol):
    """Client A: canonical presentation (sorted keys, decimal ints)."""
    name = "client-A"

    def __init__(self, vm: DeterministicVM):
        self.vm = vm

    def execute(self, payload: dict, pre_state_root: str) -> ExecutionResult:
        pd, parent, post, eff = self.vm.run(payload)
        return ExecutionResult(payload_digest=pd, parent_state_root=parent,
                               post_state_root=post, exec_valid=True,
                               effect_digest=eff)


class ClientB(ClientProtocol):
    """Client B: identical SEMANTICS, different local presentation (JSON key
    order reversed, integers hex-encoded).  Evidence equivalence must
    normalize this away."""
    name = "client-B"

    def __init__(self, vm: DeterministicVM):
        self.vm = vm

    def execute(self, payload: dict, pre_state_root: str) -> ExecutionResult:
        res = ClientA(self.vm).execute(payload, pre_state_root)
        # presentation difference lives in a local, non-semantic field:
        object.__setattr__(res, "bal_summary",
                           "presentation=reversed-keys,hex-ints")
        return res


def equivalent_evidence(ea: dict, eb: dict,
                        semantic_keys=("payloadDigest", "parentStateRoot",
                                       "postStateRoot", "effectDigest")
                        ) -> tuple[bool, list]:
    """EquivalentEvidence(E_A, E_B): equality on the semantic projection."""
    diffs = [k for k in semantic_keys if ea.get(k) != eb.get(k)]
    return (len(diffs) == 0), diffs
