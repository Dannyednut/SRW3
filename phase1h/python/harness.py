"""SRW3 Phase 1H — shadow-gate harness.

Wires: ChainSim (CL role) + GateH (SRW3 gate) + LineageStore (sidecar).

Modes (section 3 / section 15):
  shadow                  — gate observes, records, NEVER changes Ethereum behavior
  consensus-visible-sim   — SRW3_REJECT (or SRW3_ERROR, fail-closed) is
                            TRANSLATED to Engine-API-INVALID by the CL
                            simulator: the payload is NOT canonicalized;
                            head remains at parent.  This is a SIMULATION of
                            a protocol rule change, not an Ethereum change.

Failure policy (section 24/25):
  adapter/evidence failures produce verdict SRW3_ERROR(reason).  In shadow
  mode SRW3_ERROR is recorded and non-enforcing (explicit non-enforcing
  operation); in consensus-visible-sim mode SRW3_ERROR is FAIL-CLOSED.
  SRW3 unavailable is therefore never an automatic security-valid
  commitment.

Phase 1H-R1 execution path (section 10) — the SecurityContext_H is a
FIRST-CLASS gate input:

    real payload (Engine API)
        -> client-derived evidence
        -> SecurityContext_H construction (deterministic inputs only)
        -> SecurityContext_H validation (gate SC-1..SC-9; SC-10: no substitution)
        -> GateH.evaluate(ev, security_context=sc, ...)
        -> verdict
        -> lineage persistence INCLUDING securityContextDigest

The harness never generates a context and then ignores it, and never lets
the gate run without one (security_context is a required keyword).  For an
AUTHORIZED replay (a lineage record already exists for the payload) the
applicable lineage head is re-read from the persisted record (section 14
restart/replay recipe): the context is reconstructed from exactly the
recorded pre-payload lineage head, the same digest is recomputed, and the
re-recorded semantic record is idempotent.  For a FRESH payload the gate
derives the applicable lineage head through its own lineage-head source
(SC-8 has teeth: a substituted or stale context cannot pass).
"""
from __future__ import annotations

import time
from dataclasses import dataclass, field

from cl_sim import BuildResult, ChainSim
from evidence import collect_evidence
from gate_h import GateH, GateVerdict, build_security_context
from lineage import LineageStore
from policy import Policy


@dataclass
class ProcessingRecord:
    label: str
    block_hash: str | None
    parent_hash: str | None
    ethereum_result: str          # VALID / INVALID / NOT-PROCESSED
    srw3_result: str              # SRW3_VALID / SRW3_REJECT / SRW3_ERROR / DISABLED
    srw3_layer: str | None = None
    srw3_reason: str | None = None
    evidence: dict | None = None
    timings_ms: dict = field(default_factory=dict)
    checks: dict = field(default_factory=dict)
    canonicalized: bool = False
    security_context_digest: str | None = None   # R1: context digest of this evaluation


class SRW3Harness:
    def __init__(self, dn, sim: ChainSim, gate: GateH, policy: Policy,
                 policy_digest: str, store: LineageStore,
                 mode: str = "shadow", fail_policy: str = "record-error",
                 collect_traces: bool = True):
        gate.state_reader = self._state_reader
        # R1 (SC-8): the gate derives the applicable lineage head from the
        # SRW3 sidecar (falling back to the client head before any record
        # exists).  This is the gate's OWN source — independent of whatever
        # context a caller supplies.
        gate.lineage_head_provider = lambda: self.store.head or self.sim.head
        self.dn = dn
        self.sim = sim
        self.gate = gate
        self.policy = policy
        self.policy_digest = policy_digest
        self.store = store
        self.mode = mode
        self.fail_policy = fail_policy
        self.collect_traces = collect_traces
        self.records: list[ProcessingRecord] = []
        self.disabled = (policy is None)

    # ------------------------------------------------------------------

    def _security_context(self, lineage_head: str | None = None):
        """Construct the SecurityContext_H for one evaluation.

        Deterministic inputs only: policy + deployment-pinned digest,
        client-derived chain id, the applicable lineage head, the
        client-derived execution configuration digest and identity.  No
        wall-clock value enters the context or its digest.
        """
        return build_security_context(
            self.policy, self.policy_digest, self.dn.chain_id(),
            lineage_head=lineage_head if lineage_head is not None
            else (self.store.head or self.sim.head),
            client_config_digest=self._last_config_digest or "",
            client_identity=self._last_identity or "")

    _last_config_digest: str = ""
    _last_identity: str = ""
    last_ev = None
    last_payload = None
    last_security_context = None   # R1: the context actually supplied to the gate

    def _state_reader(self, addr: str, slot: str, block_hash: str) -> str | None:
        """Authoritative post-state read through the client."""
        from eth_utils import to_checksum_address
        try:
            return self.dn.rpc.call("eth_getStorageAt",
                                    [to_checksum_address(addr), slot, block_hash])
        except Exception:
            return None

    def process(self, label: str, res: BuildResult,
                presented_effects: dict | None = None,
                presented_context: dict | None = None,
                expectations: dict | None = None,
                skip_invariants: bool = False) -> ProcessingRecord:
        """Collect evidence + run the gate on a produced payload (post
        newPayload, pre/post canonicalization — shadow mode records regardless).

        R1: if a lineage record already exists for this payload (authorized
        replay), the context is reconstructed from the record's
        lineageHeadBefore so the replayed evaluation is semantically
        identical to the original (same context digest, same semantic
        record, idempotent persistence).
        """
        rec = ProcessingRecord(label=label,
                               block_hash=res.payload["blockHash"] if res.payload else None,
                               parent_hash=res.payload["parentHash"] if res.payload else None,
                               ethereum_result="NOT-PROCESSED",
                               srw3_result="DISABLED")
        if self.disabled:
            rec.ethereum_result = "VALID"  # client behaved normally
            return rec
        t0 = time.perf_counter()
        try:
            from cl_sim import beacon_root
            ev = collect_evidence(self.dn, res.payload, res.slot,
                                  beacon_root(res.slot))
            self.last_ev = ev
            self.last_payload = res.payload
            self._last_config_digest = ev.execution_configuration["configDigest"]
            self._last_identity = ev.execution_identity["client"]
            t_collect = (time.perf_counter() - t0) * 1000

            # security context (uses client-derived config digest).
            # Authorized replay: applicable lineage head = the recorded
            # pre-payload head of the EXISTING record (section 14 recipe);
            # the gate's SC-8 then evaluates against that same recorded
            # head via the explicit expectation (never against a rebuilt
            # context).
            old_rec = (self.store.get(rec.block_hash)
                       if rec.block_hash else None)
            lineage_head_for_eval = (old_rec["lineageHeadBefore"]
                                     if old_rec is not None
                                     else (self.store.head or self.sim.head))
            sc = self._security_context(lineage_head_for_eval)
            self.last_security_context = sc

            t1 = time.perf_counter()
            verdict, checks = self.gate.evaluate(
                ev,
                security_context=sc,
                presented_effects=presented_effects,
                presented_context=presented_context,
                expectations=expectations,
                skip_invariants=skip_invariants,
                lineage_head_expectation=lineage_head_for_eval
                if old_rec is not None else None)
            t_gate = (time.perf_counter() - t1) * 1000

            rec.srw3_result = verdict.verdict
            rec.srw3_layer = verdict.layer
            rec.srw3_reason = verdict.reason
            rec.checks = checks
            rec.security_context_digest = sc.context_digest
            rec.evidence = {
                "executionId": ev.execution_id,
                "effectDigest": ev.effect_digest,
                "parentRoot": ev.parent_root,
                "childRoot": ev.child_state_root,
                "authorityCertificate": checks.get("L3_authority"),
                "policyVersion": self.policy.policy_version,
                "securityContextDigest": sc.context_digest,
                "balSummary": ev.bal_summary,
            }
            rec.timings_ms = {"evidence": round(t_collect, 3),
                              "gate": round(t_gate, 3),
                              **ev.timings_ms}
            # persist lineage (sidecar, crash-atomic; R1: semantic replay
            # idempotence + securityContextDigest as a semantic field)
            if rec.block_hash:
                head_before = (old_rec["lineageHeadBefore"]
                               if old_rec is not None else self.store.head)
                self.store.record(
                    rec.block_hash, rec.parent_hash, verdict.verdict,
                    ev.effect_digest, checks.get("L3_authority") or "-",
                    self.policy.policy_version, ev.execution_id, head_before,
                    extra={"srw3Layer": verdict.layer,
                           "reason": verdict.reason,
                           "slot": res.slot,
                           "securityContextDigest": sc.context_digest})
                self.store.set_head(rec.block_hash)
        except Exception as e:  # section 24: adapter failure
            rec.srw3_result = "SRW3_ERROR"
            rec.srw3_reason = f"adapter-failure: {type(e).__name__}: {e}"
            rec.timings_ms = {"total": round((time.perf_counter() - t0) * 1000, 3)}
        rec.ethereum_result = "VALID"
        self.records.append(rec)
        return rec

    # ------------------------------------------------------------------

    def run_payload(self, label: str, raw_txs: list[str],
                    presented_effects: dict | None = None,
                    presented_context: dict | None = None,
                    expectations: dict | None = None,
                    parent: str | None = None,
                    skip_invariants: bool = False) -> tuple[BuildResult, ProcessingRecord]:
        """Produce a payload through the real CL flow, then gate it.

        shadow mode:             build -> submit(executed) -> canonicalize -> gate records
        consensus-visible-sim:   build -> submit(executed) -> GATE -> canonicalize
                                 only on SRW3_VALID (the gate sits between
                                 execution and fork choice)"""
        res = self.sim.produce(raw_txs, parent=parent,
                               defer_canonicalize=(self.mode == "consensus-visible-sim"))
        if res.payload is None:
            rec = ProcessingRecord(label=label, block_hash=None,
                                   parent_hash=None, ethereum_result="NOT-PROCESSED",
                                   srw3_result="DISABLED")
            self.records.append(rec)
            return res, rec
        rec = self.process(label, res, presented_effects, presented_context,
                           expectations, skip_invariants)
        if self.mode == "shadow" or self.disabled:
            # Ethereum canonical behavior unchanged: head advanced already.
            rec.canonicalized = (self.sim.head == rec.block_hash)
        elif self.mode == "consensus-visible-sim":
            if rec.srw3_result in ("SRW3_REJECT", "SRW3_ERROR"):
                # translated to INVALID: refuse canonicalization; the client's
                # canonical head remains at the parent (fail-closed on ERROR)
                rec.ethereum_result = "INVALID(SRW3-sim)"
                rec.canonicalized = False
                self.sim.fcu(self.sim.head)
                self.sim.drain_pool()   # sweep txs re-injected by the refusal
            else:
                st = self.sim.canonicalize(rec.block_hash)
                rec.canonicalized = (self.sim.head == rec.block_hash)
        return res, rec
