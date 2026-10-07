"""SRW3 Phase 1H — consensus-visible SIMULATION (section 15).

Mode: consensus-visible-sim.  SRW3_REJECT is TRANSLATED by the CL simulator
into an Engine-API-INVALID decision (payload NOT canonicalized, head stays
at parent).  This models a protocol rule change; it is NOT an Ethereum
consensus modification (the real client still returns VALID for the payload
— recorded side by side).
"""
from __future__ import annotations

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import r1_support  # noqa: E402

from boot import Boot, boot_devnet, HERE, CAP, DEPOSIT  # noqa: E402
from harness import SRW3Harness  # noqa: E402
from gate_h import GateH, build_security_context  # noqa: E402
from lineage import LineageStore  # noqa: E402
from policy import load_policy, load_deployment  # noqa: E402

ETH = 10**18


def main() -> int:
    dn = boot_devnet()
    boot = Boot(dn)
    boot.deploy_all()
    pol_path, dep_path = boot.write_policy(f"{HERE}/policy")
    policy = load_policy(pol_path)
    deployment = load_deployment(dep_path)
    pdigest = policy.verify_against_deployment(deployment)
    gate = GateH(policy, pdigest, deployment["genesisHash"])
    store = LineageStore(f"{HERE}/fixtures/lineage/consensus_sim")
    harness = SRW3Harness(dn, boot.sim, gate, policy, pdigest, store,
                          mode="consensus-visible-sim")

    R: dict = {}
    head0 = boot.sim.head

    # 1) honest payload -> SRW3_VALID -> canonicalized
    res1, rec1 = harness.run_payload("CS1-honest", boot.txs(0, [
        (boot.oracle, "setPrice(uint256)", (2000 * ETH,), 0),
        (boot.lending, "deposit()", (), DEPOSIT)]).raws)
    R["CS1"] = {"ethereum": rec1.ethereum_result, "srw3": rec1.srw3_result,
                "canonicalized": rec1.canonicalized,
                "head": boot.sim.head[:14]}

    # 2) violating payload -> SRW3_REJECT -> simulated INVALID
    res2, rec2 = harness.run_payload("CS2-violating", boot.txs(1, [
        (boot.lending, "borrow(uint256)", (500 * ETH,), 0)]).raws)
    R["CS2"] = {"clientSays": res2.new_payload_status["status"],
                "latestValidHashFromClient":
                    res2.new_payload_status.get("latestValidHash"),
                "srw3": rec2.srw3_result, "layer": rec2.srw3_layer,
                "simulatedResult": rec2.ethereum_result,
                "canonicalized": rec2.canonicalized,
                "rejectedBlockNotCanonical": dn.rpc.call(
                    "eth_getBlockByNumber",
                    [res2.payload["blockNumber"], False])["hash"]
                    != res2.payload["blockHash"],
                "head": boot.sim.head[:14]}

    # 3) the CL cannot extend the rejected branch (simulated rule)
    res3 = boot.sim.build_on(res2.payload["blockHash"], boot.txs(2, [
        (boot.oracle, "setPrice(uint256)", (2100 * ETH,), 0)]).raws)
    if res3.payload is not None:
        boot.sim.submit(res3)   # the client happily VALIDates the child
    boot.sim.fcu(rec2.parent_hash)  # simulated rule restores head to parent
    boot.sim.drain_pool()           # clear re-injected txs
    R["CS3"] = {
        "buildOnRejected": {
            "fcu": res3.build_fcu_status if res3.payload else "build failed",
            "newPayload": res3.new_payload_status["status"]
            if res3.new_payload_status else None,
        },
        "note": "the execution client has no notion of an SRW3-invalid block: "
                "it builds and VALIDates a child of the rejected payload; "
                "only the CL-side simulated rule prevents extension",
    }

    # 4) re-presentation of the SAME rejected payload: the client accepts
    # (already imported) but the SRW3 record is stable and idempotent.
    # R1: the re-evaluation uses the R1 replay recipe — the context is
    # reconstructed from the persisted record's pre-payload lineage head.
    from evidence import collect_evidence
    from cl_sim import beacon_root
    dup2 = dn.new_payload_v5(res2.payload, [], beacon_root(res2.slot), [])
    ev2 = collect_evidence(dn, res2.payload, res2.slot, beacon_root(res2.slot))
    rec2_old = store.get(res2.payload["blockHash"])
    sc_cs4 = build_security_context(
        policy, pdigest, dn.chain_id(),
        lineage_head=rec2_old["lineageHeadBefore"],
        client_config_digest=ev2.execution_configuration["configDigest"],
        client_identity=ev2.execution_identity["client"])
    v4, _ = gate.evaluate(ev2, security_context=sc_cs4,
                          lineage_head_expectation=rec2_old["lineageHeadBefore"])
    old2 = store.get(res2.payload["blockHash"])
    R["CS4"] = {"clientSays": dup2["status"], "srw3": v4.verdict,
                "layer": v4.layer,
                "securityContextDigest": sc_cs4.context_digest,
                "recordedSecurityContextDigest":
                    old2.get("securityContextDigest"),
                "contextDigestMatchesRecord":
                    old2.get("securityContextDigest") == sc_cs4.context_digest,
                "lineageRecordStable":
                    old2 is not None and old2["verdict"] == "SRW3_REJECT"}
    boot.sim.drain_pool()

    # 5) recovery: honest payload after simulated rejection
    res5, rec5 = harness.run_payload("CS5-recovery", boot.txs(4, [
        (boot.oracle, "setPrice(uint256)", (2200 * ETH,), 0)]).raws)
    R["CS5"] = {"srw3": rec5.srw3_result,
                "canonicalized": rec5.canonicalized,
                "head": boot.sim.head[:14]}

    R["analysis"] = {
        "latestValidHashSemantics":
            "client returns latestValidHash=parent for an execution-VALID "
            "payload; an SRW3-INVALID translation would overload INVALID "
            "with a NON-execution validity notion (see report section 15)",
        "forkchoiceSemantics":
            "the CL must treat the SRW3-rejected head as nonexistent; "
            "forkchoice then never extends it; identical policy required "
            "across all clients or branches diverge",
        "reorgConsequence":
            "if any client lacks the policy, it will extend the rejected "
            "branch, producing a persistent fork: SRW3 enforcement at this "
            "boundary is a fork-choice rule, not a validity rule",
    }

    r1_support.attach_and_dump(
        R, f"{HERE}/transcripts/srw3/consensus_sim.json")
    print(json.dumps(R, indent=1)[:2200])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
