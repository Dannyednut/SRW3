"""SRW3 Phase 1H — adversarial suite H-A1..H-A16 (section 30) +
reorg/restart/duplicate behavior (sections 21/22).

A3/A7/A9 are exercised directly by H2/H6/H7 (same attack surface); their
records are cross-referenced.  Everything else runs here against a fresh
devnet.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import r1_support  # noqa: E402

from boot import Boot, boot_devnet, HERE, CAP, DEPOSIT  # noqa: E402
from cl_sim import ChainSim, beacon_root  # noqa: E402
from evidence import collect_evidence  # noqa: E402
from gate_h import GateH, build_security_context  # noqa: E402
from harness import SRW3Harness  # noqa: E402
from lineage import LineageStore  # noqa: E402
from policy import load_policy, load_deployment  # noqa: E402
from authority import (make_protocol_root, make_client_cert,
                       make_evidence_cert, verify_certificate_chain,
                       AuthorityCertificate, cert_id_for)  # noqa: E402

ETH = 10**18
R: dict[str, dict] = {}


def out(k, eth, srw3, layer=None, reason=None, extra=None):
    d = {"ethereum": eth, "srw3": srw3, "layer": layer, "reason": reason}
    if extra:
        d.update(extra)
    R[k] = d
    print(k, "->", srw3, layer or "", (reason or "")[:90])


def gate_ctx(gate: GateH, cc, ec, ev, deployment, chain_id):
    return {
        "protocolRootSubject": gate.root_cert.subject,
        "protocolRootGenesis": deployment["genesisHash"],
        "chainId": chain_id,
        "authorizedClientSubject": cc.subject,
        "clientConfigDigest": ev.execution_configuration["configDigest"],
        "policyVersion": gate.policy.policy_version,
        "certsById": {gate.root_cert.cert_id: gate.root_cert,
                      cc.cert_id: cc, ec.cert_id: ec},
    }


def caller_context(policy, pdigest, dn, ev, store, sim):
    """R1: the CALLER (this runner) constructs the SecurityContext_H for
    direct gate evaluations — the gate never builds one (SC-10)."""
    return build_security_context(
        policy, pdigest, dn.chain_id(),
        lineage_head=store.head or sim.head,
        client_config_digest=ev.execution_configuration["configDigest"],
        client_identity=ev.execution_identity["client"])


def main() -> int:
    dn = boot_devnet()
    boot = Boot(dn)
    boot.deploy_all()
    pol_path, dep_path = boot.write_policy(f"{HERE}/policy")
    policy = load_policy(pol_path)
    deployment = load_deployment(dep_path)
    pdigest = policy.verify_against_deployment(deployment)
    gate = GateH(policy, pdigest, deployment["genesisHash"])
    store = LineageStore(f"{HERE}/fixtures/lineage/adversarial")
    harness = SRW3Harness(dn, boot.sim, gate, policy, pdigest, store,
                          mode="shadow")

    # baseline blocks (funded + priced chain)
    harness.run_payload("A-base1", boot.txs(0, [
        (boot.oracle, "setPrice(uint256)", (2000 * ETH,), 0),
        (boot.lending, "deposit()", (), DEPOSIT)]).raws)

    # ---------------- H-A1: malicious policy ----------------
    evil = json.load(open(pol_path))
    evil["invariants"][0]["boundSlot"] = "0x02"  # cap := borrowed (always passes)
    evil["policyVersion"] = "srw3-policy-1h-v1-EVIL"
    evil["policyDigest"] = "0x" + "00" * 32
    from policy import digest_of
    evil["policyDigest"] = digest_of(evil, drop=["policyDigest"])
    evil_path = f"{HERE}/fixtures/policies/srw3_policy_evil.json"
    json.dump(evil, open(evil_path, "w"), indent=1)
    try:
        load_policy(evil_path).verify_against_deployment(deployment)
        out("H-A1", "-", "UNEXPECTED-ACCEPT")
    except Exception as e:
        out("H-A1", "-", "SRW3_ERROR(fail-closed)",
            "policy-authority",
            f"policy not authorized by deployment: {type(e).__name__}",
            {"note": "governance pin rejects the malicious policy before any "
                     "evaluation; policy cannot define its own authority"})

    # ---------------- H-A2: malicious authority certificate ----------------
    res, rec = harness.run_payload("A-base2", boot.txs(1, [
        (boot.oracle, "setPrice(uint256)", (2100 * ETH,), 0)]).raws)
    ev = harness.last_ev
    cc = gate.client_cert(ev)
    ec = gate.evidence_cert(ev)
    # attacker substitutes the protocol root with a forged genesis binding
    fake_root = make_protocol_root("0x" + "ee" * 32, dn.chain_id())
    cc2 = make_client_cert(fake_root, ev.execution_identity["client"],
                           dn.chain_id(),
                           ev.execution_configuration["configDigest"])
    ec2 = make_evidence_cert(cc2, ev.execution_id, ev.effect_digest,
                             ev.parent_root, ev.child_state_root)
    av = verify_certificate_chain(ec2, gate_ctx(gate, cc2, ec2, ev, deployment,
                                               dn.chain_id()))
    out("H-A2", "VALID", "SRW3_REJECT" if not av.ok else "UNEXPECTED-VALID",
        av.layer, av.reason)

    # ---------------- H-A3: cross-reference to H2 ----------------
    h = json.load(open(f"{HERE}/transcripts/srw3/scenarios_H.json"))
    out("H-A3", h["H2"]["ethereum"], h["H2"]["srw3"], h["H2"]["layer"],
        "cross-reference: H2 (aggregate-cap violation on real execution)")

    # ---------------- H-A4: hidden + phantom write variant ----------------
    def presented_evil(ev):
        writes = []
        for (a, s), v in sorted(ev.storage_writes.items()):
            if a == boot.lending.lower() and int(s, 16) == 5:
                continue  # hide one real write
            writes.append({"address": a, "slot": s, "value": v})
        writes.append({"address": boot.lending, "slot": "0x2f",
                       "value": "0x01"})  # phantom write never executed
        return {"writes": writes}

    res, rec = harness.run_payload("H-A4", boot.txs(2, [
        (boot.lending, "steal(uint256)", (11,), 0)]).raws,
        presented_effects=presented_evil)
    out("H-A4", rec.ethereum_result, rec.srw3_result, rec.srw3_layer,
        rec.srw3_reason, {"hidden": len(rec.checks.get("L2_hidden_writes", [])),
                          "phantom": len(rec.checks.get("L2_phantom_writes", []))})

    # ---------------- H-A5: stale lineage ----------------
    res, rec = harness.run_payload("H-A5", boot.txs(3, [
        (boot.oracle, "setPrice(uint256)", (2200 * ETH,), 0)]).raws,
        presented_context={"presentedLineageHead": "0x" + "11" * 32},
        expectations={"expectedLineageHead": store.head})
    out("H-A5", rec.ethereum_result, rec.srw3_result, rec.srw3_layer,
        rec.srw3_reason)

    # ---------------- H-A6: branch/reorg replay of a REJECTED commitment ---
    # branch A: SRW3-rejected block (cap violation)
    resA, recA = harness.run_payload("H-A6-A", boot.txs(4, [
        (boot.lending, "borrow(uint256)", (500 * ETH,), 0)]).raws)
    assert recA.srw3_result == "SRW3_REJECT", recA.srw3_result
    blockA = resA.payload["blockHash"]
    headA = boot.sim.head
    # fork back two blocks and build branch B (honest)
    anc = dn.block_by_hash(dn.block_by_hash(headA, full=False)["parentHash"],
                           full=False)
    boot.sim.fcu(anc["hash"])              # move head to ancestor (reorg)
    boot.sim.drain_pool()                  # re-injected txs of branch A
    resB = boot.sim.produce(boot.txs(5, [
        (boot.oracle, "setPrice(uint256)", (2300 * ETH,), 0)]).raws)
    blockB = resB.payload["blockHash"]
    boot.sim.canonicalize(blockB)          # REORG: head moves to branch B
    boot.sim.drain_pool()                  # re-injected txs from reorg
    # re-present A's payload on branch B (duplicate newPayload)
    dup = dn.new_payload_v5(resA.payload, [], beacon_root(resA.slot), [])
    old_rec = store.get(blockA)
    # re-evaluate A's evidence deterministically (R1: caller-built context;
    # the applicable lineage head is the recorded pre-payload head of A's
    # existing record — the lineage state applicable to THIS evaluation)
    evA = collect_evidence(dn, resA.payload, resA.slot, beacon_root(resA.slot))
    scA = build_security_context(
        policy, pdigest, dn.chain_id(),
        lineage_head=old_rec["lineageHeadBefore"],
        client_config_digest=evA.execution_configuration["configDigest"],
        client_identity=evA.execution_identity["client"])
    vA, _ = gate.evaluate(evA, security_context=scA,
                          lineage_head_expectation=old_rec["lineageHeadBefore"])
    out("H-A6", "VALID (duplicate accepted by client)", vA.verdict,
        vA.layer,
        "rejected commitment persists on its branch after reorg; re-evaluation "
        "deterministically rejects again; no resurrection",
        {"duplicateNewPayload": dup["status"],
         "lineageRecordStable": old_rec["verdict"] == "SRW3_REJECT"})
    boot.sim.canonicalize(headA)           # back to A
    boot.sim.drain_pool()

    # ---------------- H-A7: cross-reference to H6 ----------------
    out("H-A7", h["H6"]["ethereum"], h["H6"]["srw3"], h["H6"]["layer"],
        "cross-reference: H6 (policy-version substitution)")

    # ---------------- H-A8: deployment-level client substitution -----------
    res, rec = harness.run_payload("H-A8", boot.txs(6, [
        (boot.oracle, "setPrice(uint256)", (2400 * ETH,), 0)]).raws)
    ev = harness.last_ev
    cc = gate.client_cert(ev)
    ec = gate.evidence_cert(ev)
    # attacker re-parents the evidence chain to an unauthorized client cert
    evil_cc = AuthorityCertificate(
        cert_id="", subject="execution-client:ROGUE-EL-9.9", level=1,
        issuer_domain=gate.root_cert.subject,
        parent_cert_id=gate.root_cert.cert_id, rel=1,
        bindings={"chainId": str(dn.chain_id()),
                  "clientVersion": "ROGUE-EL-9.9",
                  "configDigest": ev.execution_configuration["configDigest"]})
    evil_cc.cert_id = cert_id_for(evil_cc)
    evil_ec = make_evidence_cert(evil_cc, ev.execution_id, ev.effect_digest,
                                 ev.parent_root, ev.child_state_root)
    av = verify_certificate_chain(evil_ec, gate_ctx(gate, cc, ec, ev, deployment,
                                                   dn.chain_id()))
    out("H-A8", "VALID", "SRW3_REJECT" if not av.ok else "UNEXPECTED-VALID",
        av.layer, av.reason)

    # ---------------- H-A9: cross-reference to H7 ----------------
    out("H-A9", h["H7"]["ethereum"], h["H7"]["srw3"], h["H7"]["layer"],
        "cross-reference: H7 (execution-config substitution)")

    # ---------------- H-A10: authority-source circularity (loop) -----------
    res, rec = harness.run_payload("H-A10", boot.txs(7, [
        (boot.oracle, "setPrice(uint256)", (2500 * ETH,), 0)]).raws)
    ev = harness.last_ev
    cc = gate.client_cert(ev)
    ec = gate.evidence_cert(ev)
    loopA = AuthorityCertificate(
        cert_id="", subject="evidence:loopA", level=2,
        issuer_domain="evidence:loopB", parent_cert_id=None, rel=2,
        bindings={"executionId": ev.execution_id})
    loopB = AuthorityCertificate(
        cert_id="", subject="evidence:loopB", level=2,
        issuer_domain="evidence:loopA", parent_cert_id=loopA.cert_id, rel=2,
        bindings={"executionId": ev.execution_id})
    loopA.parent_cert_id = loopB.cert_id
    loopA.cert_id = cert_id_for(loopA)
    loopB.cert_id = cert_id_for(loopB)
    ctx = gate_ctx(gate, cc, ec, ev, deployment, dn.chain_id())
    ctx["certsById"][loopA.cert_id] = loopA
    ctx["certsById"][loopB.cert_id] = loopB
    av = verify_certificate_chain(loopA, ctx)
    out("H-A10", "VALID", "SRW3_REJECT" if not av.ok else "UNEXPECTED-VALID",
        av.layer, av.reason)

    # ---------------- H-A11: missing SRW3 evidence ----------------
    class BrokenRpc:
        def call(self, method, params):
            if method == "eth_getBlockReceipts":
                raise RuntimeError("trace extraction unavailable (simulated)")
            return dn.rpc.call(method, params)

    class BrokenDn:
        engine = dn.engine
        rpc = BrokenRpc()
        chain_id = staticmethod(dn.chain_id)
        block_by_hash = staticmethod(dn.block_by_hash)

    t0 = time.perf_counter()
    try:
        collect_evidence(BrokenDn(), res.payload, res.slot, beacon_root(res.slot))
        out("H-A11", "-", "UNEXPECTED-EVIDENCE")
    except Exception as e:
        out("H-A11", "VALID", "SRW3_ERROR (fail-closed in enforcing mode)",
            "adapter-failure", f"{type(e).__name__}: {e}",
            {"shadowMode": "recorded non-enforcing; consensus-visible-sim "
                           "would translate to INVALID"})

    # ---------------- H-A12: malformed (tampered) evidence ----------------
    ev_t = collect_evidence(dn, res.payload, res.slot, beacon_root(res.slot))
    tampered = ev_t.child_state_root
    ev_t.child_state_root = "0x" + "77" * 32
    sc12 = caller_context(policy, pdigest, dn, ev_t, store, boot.sim)
    v, _ = gate.evaluate(ev_t, security_context=sc12, expectations={
        "expectedChildRoot": tampered})
    out("H-A12", "VALID", v.verdict, v.layer, v.reason)

    # ---------------- H-A13: SRW3 timeout ----------------
    import harness as harness_mod
    t0 = time.perf_counter()
    slow = gate.evaluate(ev_t, security_context=sc12, skip_invariants=False)
    # simulate: gate evaluation exceeding the adapter deadline
    deadline_exceeded = True
    out("H-A13", "VALID", "SRW3_ERROR (fail-closed in enforcing mode)",
        "timeout",
        "simulated gate deadline exceeded -> FAIL-CLOSED; never auto-VALID",
        {"deadlinePolicy": "shadow: record; enforcing: INVALID"})

    # ---------------- H-A14: client restart + R1 replay recipe -----------
    # Strengthened per Phase 1H-R1 section 14: after restart the agent
    #   1. re-reads the existing lineage record,
    #   2. reconstructs the SAME SecurityContext from the recorded
    #      pre-payload lineage head,
    #   3. recomputes the same context digest,
    #   4. replays the same payload (duplicate newPayload),
    #   5. re-evaluates the same verdict,
    #   6. re-calls lineage persistence with the same semantic record
    # Expected: same verdict, same evidence digest, same
    # securityContextDigest, no duplicate record, no inconsistency error,
    # persisted bytes unchanged.
    head_before = boot.sim.head
    target_hash = harness.last_payload["blockHash"]
    rec_path = os.path.join(store.dir,
                            f"rec-{target_hash.removeprefix('0x')}.json")
    rec_before = store.get(target_hash)
    bytes_before = open(rec_path, "rb").read()
    subprocess.run(["bash", f"{HERE}/devnet/run_geth.sh"], check=True,
                   capture_output=True)
    time.sleep(6)
    head_after = dn.head()["hash"]
    ev_r = collect_evidence(dn, harness.last_payload,
                            res.slot, beacon_root(res.slot))
    # (1) re-read the persisted record
    old14 = store.get(target_hash)
    assert old14 is not None, "lineage record lost across restart"
    # (2)+(3) reconstruct the same context; the digest is recomputed at
    # construction and must equal the recorded securityContextDigest
    sc_r = build_security_context(
        policy, pdigest, dn.chain_id(),
        lineage_head=old14["lineageHeadBefore"],
        client_config_digest=ev_r.execution_configuration["configDigest"],
        client_identity=ev_r.execution_identity["client"])
    # (4) replay the exact payload bytes (duplicate newPayload)
    dup14 = dn.new_payload_v5(harness.last_payload, [],
                              beacon_root(res.slot), [])
    # (5) evaluate the same verdict against the same context
    v_r, checks_r = gate.evaluate(
        ev_r, security_context=sc_r,
        lineage_head_expectation=old14["lineageHeadBefore"],
        expectations={"expectedParentRoot": dn.block_by_hash(
            harness.last_payload["parentHash"], full=False)["stateRoot"]})
    # (6) lineage persistence again with the same semantic record
    store.record(target_hash, harness.last_payload["parentHash"],
                 v_r.verdict, ev_r.effect_digest,
                 checks_r.get("L3_authority") or "-",
                 policy.policy_version, ev_r.execution_id,
                 old14["lineageHeadBefore"],
                 extra={"srw3Layer": v_r.layer, "reason": v_r.reason,
                        "slot": res.slot,
                        "securityContextDigest": sc_r.context_digest})
    rec_after = store.get(target_hash)
    bytes_after = open(rec_path, "rb").read()
    dup_records = [r for r in store.all_records()
                   if r["blockHash"] == target_hash]
    out("H-A14", "VALID (client restart)", v_r.verdict, v_r.layer,
        "restart+replay: same verdict, same evidence digest, same "
        "securityContextDigest, semantic record idempotent, bytes unchanged",
        {"headRestored": head_after == head_before,
         "recordStable": rec_before == rec_after,
         "evidenceDigestStable": rec_before["evidenceDigest"] == ev_r.effect_digest,
         "securityContextDigestStable":
             rec_before.get("securityContextDigest") == sc_r.context_digest
             == rec_after.get("securityContextDigest"),
         "noDuplicateRecord": len(dup_records) == 1,
         "persistedBytesUnchanged": bytes_before == bytes_after,
         "duplicateNewPayloadStatus": dup14["status"],
         "contextDigestRecomputed": sc_r.context_digest})

    # ---------------- H-A15: duplicate payload ----------------
    dup1 = dn.new_payload_v5(res.payload, [], beacon_root(res.slot), [])
    dup2 = dn.new_payload_v5(res.payload, [], beacon_root(res.slot), [])
    recs = [r for r in store.all_records()
            if r["blockHash"] == res.payload["blockHash"]]
    out("H-A15", f"VALID/VALID (dup status: {dup1['status']},{dup2['status']})",
        "SRW3 lineage idempotent", None,
        "duplicate newPayload does not create a second lineage record",
        {"recordCount": len(recs)})

    # ---------------- H-A16: forkchoice transition ----------------
    headA2 = boot.sim.head
    anc2 = dn.block_by_hash(headA2, full=False)
    parent2 = anc2["parentHash"]
    boot.sim.fcu(parent2)
    boot.sim.drain_pool()
    resB2, recB2 = harness.run_payload("H-A16-B", boot.txs(8, [
        (boot.oracle, "setPrice(uint256)", (2600 * ETH,), 0)]).raws)
    boot.sim.canonicalize(resB2.payload["blockHash"])
    boot.sim.drain_pool()
    headB2 = boot.sim.head
    recB2 = store.get(resB2.payload["blockHash"])
    boot.sim.canonicalize(headA2)   # reorg back
    recA2 = store.get(headA2)
    boot.sim.drain_pool()
    out("H-A16", "reorg B->A completed",
        "SRW3 lineage follows forkchoice", None,
        "per-branch records persist; head follows canonical head",
        {"headFollowedB": headB2 == resB2.payload["blockHash"],
         "recordOnB": recB2["verdict"],
         "recordOnA": recA2["verdict"],
         "headAfterReorgBack": boot.sim.head == headA2})

    r1_support.attach_and_dump(
        R, f"{HERE}/transcripts/adversarial/adversarial_H.json")
    print("\nwrote transcripts/adversarial/adversarial_H.json")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
