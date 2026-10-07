"""SRW3 Phase 1H — required scenarios H1..H10 (section 14).

Runs against a FRESH Geth devnet (Amsterdam fork) driven through the real
Engine API.  Writes results JSON to transcripts/srw3/scenarios_H.json.
"""
from __future__ import annotations

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import r1_support  # noqa: E402

from boot import Boot, boot_devnet, CAP, DEPOSIT, HERE  # noqa: E402
from gate_h import GateH, build_security_context  # noqa: E402
from harness import SRW3Harness  # noqa: E402
from lineage import LineageStore  # noqa: E402
from policy import load_policy, load_deployment  # noqa: E402
from evidence import collect_evidence  # noqa: E402
from cl_sim import beacon_root  # noqa: E402

ETH = 10**18


def summarize(rec) -> dict:
    return {
        "ethereum": rec.ethereum_result,
        "srw3": rec.srw3_result,
        "layer": rec.srw3_layer,
        "reason": rec.srw3_reason,
        "canonicalized": rec.canonicalized,
        "evidence": rec.evidence,
    }


def main() -> int:
    dn = boot_devnet()
    boot = Boot(dn)
    print("== deploying through real payloads ==")
    boot.deploy_all()
    print(f"oracle={boot.oracle} lending={boot.lending} liquidator={boot.liquidator}")

    pol_path, dep_path = boot.write_policy(f"{HERE}/policy")
    policy = load_policy(pol_path)
    deployment = load_deployment(dep_path)
    pdigest = policy.verify_against_deployment(deployment)
    gate = GateH(policy, pdigest, deployment["genesisHash"])
    store = LineageStore(f"{HERE}/fixtures/lineage/scenarios")
    harness = SRW3Harness(dn, boot.sim, gate, policy, pdigest, store,
                          mode="shadow")
    print(f"policy={policy.policy_version} digest={pdigest[:20]}...")

    R: dict[str, dict] = {}

    # ---------------- H1: honest payload ----------------
    res, rec = harness.run_payload("H1", boot.txs(0, [
        (boot.oracle, "setPrice(uint256)", (2000 * ETH,), 0),
        (boot.lending, "deposit()", (), DEPOSIT),
    ]).raws)
    R["H1"] = summarize(rec)

    # ---------------- H9: cross-application interaction violation
    # (run before H2 so the cap is still respected): borrow FIRST, then a
    # price write — ordering obligation violated; Ethereum executes fine.
    res, rec = harness.run_payload("H9", boot.txs(1, [
        (boot.lending, "borrow(uint256)", (10 * ETH,), 0),
        (boot.oracle, "setPrice(uint256)", (3000 * ETH,), 0),
    ]).raws)
    R["H9"] = summarize(rec)

    # ---------------- H2: policy violation (aggregate cap) ----------------
    res, rec = harness.run_payload("H2", boot.txs(2, [
        (boot.lending, "borrow(uint256)", (500 * ETH,), 0),
    ]).raws)
    R["H2"] = summarize(rec)

    # ---------------- H3: hidden write / effect ----------------
    # The block writes the lending `hidden` slot (slot 5).  The "presented"
    # record (what a producer WOULD attach in Mode H-B) omits exactly that
    # write.  SRW3 compares presented vs execution-derived -> REJECT.
    def presented_omitting_hidden(ev):
        writes = []
        for (a, s), v in sorted(ev.storage_writes.items()):
            if a == boot.lending.lower() and int(s, 16) == 5:
                continue  # the hidden write the producer omits
            writes.append({"address": a, "slot": s, "value": v})
        return {"writes": writes}

    res, rec = harness.run_payload("H3", boot.txs(3, [
        (boot.lending, "steal(uint256)", (7,), 0),
    ]).raws, presented_effects=presented_omitting_hidden)
    R["H3"] = summarize(rec)

    # ---------------- H4: stale state/evidence ----------------
    # Take the PREVIOUS block's evidence and present it for a NEW payload:
    # parent root is stale w.r.t. the payload's parent.
    res_new = boot.sim.produce(boot.txs(4, [
        (boot.oracle, "setPrice(uint256)", (2500 * ETH,), 0),
    ]).raws)
    ev_stale = harness.last_ev          # evidence of the previous block
    stale = collect_evidence(dn, harness.last_payload,
                             ev_stale.execution_configuration["slotNumber"],
                             beacon_root(ev_stale.execution_configuration["slotNumber"]))
    parent_block = dn.block_by_hash(res_new.payload["parentHash"], full=False)
    # R1: the caller constructs the SecurityContext_H for this direct-gate
    # evaluation; the gate validates it (SC-1..SC-9) and never rebuilds it.
    sc4 = build_security_context(
        policy, pdigest, dn.chain_id(),
        lineage_head=store.head or boot.sim.head,
        client_config_digest=stale.execution_configuration["configDigest"],
        client_identity=stale.execution_identity["client"])
    v, checks = gate.evaluate(stale, security_context=sc4, expectations={
        "expectedParentRoot": parent_block["stateRoot"]})
    R["H4"] = {"ethereum": "VALID (baseline evidence-valid)",
               "srw3": v.verdict, "layer": v.layer, "reason": v.reason,
               "securityContextDigest": sc4.context_digest}

    # ---------------- H5: authority substitution ----------------
    res, rec = harness.run_payload("H5", boot.txs(5, [
        (boot.oracle, "setPrice(uint256)", (2600 * ETH,), 0),
    ]).raws, presented_context={"authorizedClientSubject":
                                "execution-client:EVIL-CLIENT-1.0"})
    R["H5"] = summarize(rec)
    R["H5"]["securityContextDigest"] = rec.security_context_digest

    # ---------------- H6: policy substitution ----------------
    res, rec = harness.run_payload("H6", boot.txs(6, [
        (boot.oracle, "setPrice(uint256)", (2700 * ETH,), 0),
    ]).raws, presented_context={"presentedPolicyVersion":
                                "srw3-policy-1h-v1-EVIL"})
    R["H6"] = summarize(rec)
    R["H6"]["securityContextDigest"] = rec.security_context_digest

    # ---------------- H7: execution-context substitution ----------------
    res, rec = harness.run_payload("H7", boot.txs(7, [
        (boot.oracle, "setPrice(uint256)", (2800 * ETH,), 0),
    ]).raws, presented_context={"presentedConfigDigest":
                                "0x" + "de" * 32})
    R["H7"] = summarize(rec)
    R["H7"]["securityContextDigest"] = rec.security_context_digest

    # ---------------- H8: self-authorizing evidence ----------------
    ev = harness.last_ev
    cc = gate.client_cert(ev)
    ec = gate.evidence_cert(ev)
    ec.parent_cert_id = ec.cert_id          # cite itself as parent
    from authority import verify_certificate_chain
    certs_by_id = {gate.root_cert.cert_id: gate.root_cert,
                   cc.cert_id: cc, ec.cert_id: ec}
    av = verify_certificate_chain(ec, {
        "protocolRootSubject": gate.root_cert.subject,
        "protocolRootGenesis": deployment["genesisHash"],
        "chainId": dn.chain_id(),
        "authorizedClientSubject": cc.subject,
        "clientConfigDigest": ev.execution_configuration["configDigest"],
        "policyVersion": policy.policy_version,
        "certsById": certs_by_id,
    })
    R["H8"] = {"ethereum": "VALID", "srw3": "SRW3_REJECT" if not av.ok else "SRW3_VALID",
               "layer": av.layer, "reason": av.reason}

    # ---------------- H10: clean no-policy path ----------------
    # Handled in run_determinism.py (compares identical payloads with and
    # without the SRW3 layer on independent chains); record the shadow-mode
    # non-invasiveness statement here.
    R["H10"] = {"ethereum": "VALID", "srw3": "DISABLED",
                "note": "cross-chain comparison executed by run_determinism.py "
                        "(H10-D): identical block hashes with and without SRW3"}

    r1_support.attach_and_dump(
        R, f"{HERE}/transcripts/srw3/scenarios_H.json")
    print(json.dumps({k: {kk: vv for kk, vv in v.items() if kk in
                          ("ethereum", "srw3", "layer", "reason")}
                      for k, v in R.items()}, indent=1))
    return 0


def _payload_of(dn, block_hash: str) -> dict:
    """Reconstruct an ExecutionPayloadV4 view from the client's own block."""
    b = dn.block_by_hash(block_hash)
    return {
        "parentHash": b["parentHash"], "feeRecipient": b["miner"],
        "stateRoot": b["stateRoot"], "receiptsRoot": b["receiptsRoot"],
        "logsBloom": b["logsBloom"], "prevRandao": b["prevRandao"],
        "blockNumber": b["number"], "gasLimit": b["gasLimit"],
        "gasUsed": b["gasUsed"], "timestamp": b["timestamp"],
        "extraData": b["extraData"], "baseFeePerGas": b["baseFeePerGas"],
        "blockHash": b["hash"],
    }


def _slot_of(dn, block_hash: str) -> int:
    return int(dn.block_by_hash(block_hash, full=False)["slotNumber"], 16)


if __name__ == "__main__":
    raise SystemExit(main())
