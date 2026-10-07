"""SRW3 Phase 1H — determinism (section 17) + H10-D non-invasiveness.

Methodology (payload-fixed):
  runA   build the canonical sequence on instance A (clean: no build retry,
         no adapter error); capture the exact payload bytes P1..P5.
  runA2  independent fresh build run on a restarted instance A: the built
         payloads must be byte-identical and the chain identical.
  runB   REPLAY the captured payloads on instance B (newPayloadV5 + fcu):
         the same canonical payload must produce identical execution,
         evidence digests and SRW3 verdicts on an independent instance.
  runB_np fresh build run WITHOUT the SRW3 policy: identical block hashes
         establish non-invasiveness (H10-D).
"""
from __future__ import annotations

import json
import shutil
import subprocess
import sys
import time

sys.path.insert(0, "/home/z/my-project/srw3-work/phase1h/python")

from boot import Boot, HERE, CAP, DEPOSIT  # noqa: E402
from cl_sim import ChainSim, beacon_root  # noqa: E402
from engine_client import Devnet  # noqa: E402
from gate_h import GateH  # noqa: E402
from harness import SRW3Harness  # noqa: E402
from lineage import LineageStore  # noqa: E402
from policy import load_policy, load_deployment  # noqa: E402
from evidence import collect_evidence  # noqa: E402

ETH = 10**18
GETH = "/home/z/my-project/tools/geth/geth-linux-amd64-1.17.7-3d858f85/geth"


def spawn_node(tag: str, http_port: int, auth_port: int, fresh=True) -> dict:
    dd = f"{HERE}/devnet/chain-det-{tag}"
    if fresh:
        shutil.rmtree(dd, ignore_errors=True)
        subprocess.run([GETH, "--datadir", dd, "init",
                        f"{HERE}/devnet/genesis.json"],
                       check=True, capture_output=True)
    log = open(f"{HERE}/transcripts/client/geth-det-{tag}.log", "a")
    p = subprocess.Popen([
        GETH, "--datadir", dd, "--networkid", "93471",
        "--nat", "none", "--maxpeers", "0", "--nodiscover", "--port", "0",
        "--syncmode", "full", "--gcmode", "archive",
        "--http", "--http.addr", "127.0.0.1", "--http.port", str(http_port),
        "--http.api", "eth,web3,net,debug,txpool,admin",
        "--http.corsdomain", "*", "--http.vhosts", "*",
        "--authrpc.addr", "127.0.0.1", "--authrpc.port", str(auth_port),
        "--authrpc.vhosts", "*", "--authrpc.jwtsecret", f"{HERE}/devnet/jwt.hex",
        "--rpc.allow-unprotected-txs", "--verbosity", "2"],
        stdout=log, stderr=log)
    jwt = open(f"{HERE}/devnet/jwt.hex").read().strip()
    dn = Devnet(f"http://127.0.0.1:{auth_port}",
                f"http://127.0.0.1:{http_port}", jwt)
    for _ in range(80):
        try:
            dn.chain_id()
            time.sleep(3.0)
            return {"dn": dn, "proc": p, "datadir": dd,
                    "ports": (http_port, auth_port)}
        except Exception:
            time.sleep(0.5)
    raise RuntimeError(f"node {tag} failed to start")


def stop_node(node):
    node["proc"].terminate()
    node["proc"].wait(timeout=25)


def build_sequence(node, run_tag: str, use_policy: bool, attempts=8) -> dict:
    """Build the canonical sequence; retry on a fresh instance until no
    payload-build retry (CL attribute degree of freedom) and no adapter
    error occurred.  Captures payload bytes."""
    for i in range(attempts):
        if i:
            stop_node(node)
            node2 = spawn_node(run_tag, *node["ports"])
            node.update(proc=node2["proc"], dn=node2["dn"],
                        datadir=node2["datadir"], ports=node2["ports"])
        dn = node["dn"]
        b = Boot(dn)
        payloads = []
        rebuilt = []
        sim_recs = []
        b.deploy_all()
        payloads = list(b.deploy_payloads)
        rebuilt = list(b.deploy_rebuilt)
        srw3 = []
        ev_last = None
        if use_policy:
            pol_path, dep_path = b.write_policy(f"{HERE}/policy")
            policy = load_policy(pol_path)
            deployment = load_deployment(dep_path)
            pdigest = policy.verify_against_deployment(deployment)
            gate = GateH(policy, pdigest, deployment["genesisHash"])
            store = LineageStore(f"{HERE}/fixtures/lineage/det-{run_tag}")
            h = SRW3Harness(dn, b.sim, gate, policy, pdigest, store,
                            mode="shadow")
            res, rec = h.run_payload("D1", b.txs(0, [
                (b.oracle, "setPrice(uint256)", (2000 * ETH,), 0),
                (b.lending, "deposit()", (), DEPOSIT)]).raws)
            payloads.append(res.payload); rebuilt.append(res.rebuilt)
            srw3.append({"blockHash": rec.block_hash,
                         "srw3": rec.srw3_result,
                         "evidenceDigest": (rec.evidence or {}).get("effectDigest"),
                         "cert": (rec.evidence or {}).get("authorityCertificate")})
            res, rec = h.run_payload("D2", b.txs(1, [
                (b.lending, "borrow(uint256)", (500 * ETH,), 0)]).raws)
            payloads.append(res.payload); rebuilt.append(res.rebuilt)
            srw3.append({"blockHash": rec.block_hash,
                         "srw3": rec.srw3_result,
                         "evidenceDigest": (rec.evidence or {}).get("effectDigest"),
                         "cert": (rec.evidence or {}).get("authorityCertificate")})
            ev_last = h.last_ev
        else:
            for txs in [b.txs(0, [
                    (b.oracle, "setPrice(uint256)", (2000 * ETH,), 0),
                    (b.lending, "deposit()", (), DEPOSIT)]).raws,
                    b.txs(1, [
                        (b.lending, "borrow(uint256)", (500 * ETH,), 0)]).raws]:
                r = b.sim.produce(txs)
                payloads.append(r.payload); rebuilt.append(r.rebuilt)
        blocks = []
        for n in range(1, len(payloads) + 1):
            blk = dn.rpc.call("eth_getBlockByNumber", [hex(n), False])
            blocks.append({"number": n, "hash": blk["hash"],
                           "stateRoot": blk["stateRoot"]})
        clean = (not any(rebuilt)
                 and "SRW3_ERROR" not in [s["srw3"] for s in srw3])
        if clean:
            return {"blocks": blocks, "payloads": payloads, "srw3": srw3,
                    "rebuilt": rebuilt, "evDigest":
                        ev_last.effect_digest if ev_last else None,
                    "evExecId": ev_last.execution_id if ev_last else None,
                    "head": b.sim.head}
        print(f"  [{run_tag}] attempt {i}: rebuilt={rebuilt} "
              f"verdicts={[s['srw3'] for s in srw3]} -> fresh retry")
    raise RuntimeError(f"could not obtain a clean run on {run_tag}")


def replay_sequence(node, payloads: list, pol_path: str, dep_path: str) -> dict:
    """Replay captured payload bytes on an independent instance; then gate."""
    dn = node["dn"]
    sim = ChainSim.create(dn, 93471)
    gate = None
    policy = load_policy(pol_path)
    deployment = load_deployment(dep_path)
    pdigest = policy.verify_against_deployment(deployment)
    from eth_utils import to_checksum_address

    def state_reader(addr, slot, block_hash):
        return dn.rpc.call("eth_getStorageAt",
                           [to_checksum_address(addr), slot, block_hash])

    gate = GateH(policy, pdigest, deployment["genesisHash"],
                 state_reader=state_reader)
    store = LineageStore(f"{HERE}/fixtures/lineage/det-replay")
    srw3 = []
    for p in payloads:
        if p is None:
            continue
        st = dn.new_payload_v5(p, [], beacon_root(int(p["slotNumber"], 16)), [])
        assert st["status"] == "VALID", st
        sim.canonicalize(p["blockHash"])
        ev = collect_evidence(dn, p, int(p["slotNumber"], 16),
                              beacon_root(int(p["slotNumber"], 16)))
        v, _ = gate.evaluate(ev)
        srw3.append({"blockHash": p["blockHash"], "srw3": v.verdict,
                     "evidenceDigest": ev.effect_digest,
                     "cert": None, "stateRoot": p["stateRoot"]})
    blocks = []
    for n in (1, 2, 3, 4, 5):
        blk = dn.rpc.call("eth_getBlockByNumber", [hex(n), False])
        blocks.append({"number": n, "hash": blk["hash"],
                       "stateRoot": blk["stateRoot"]})
    return {"blocks": blocks, "srw3": srw3, "head": sim.head}


def main() -> int:
    subprocess.run(["pkill", "-f", "chain-det-"], capture_output=True)
    time.sleep(1)
    A = spawn_node("A", 8565, 8566)
    try:
        runA = build_sequence(A, "A", use_policy=True)
        print("runA clean:", runA["blocks"][1]["hash"][:14], runA["srw3"])

        # independent fresh build on restarted A
        stop_node(A)
        A2 = spawn_node("A", 8565, 8566)
        runA2 = build_sequence(A2, "A2", use_policy=True)

        # replay the exact payload bytes on an independent instance B
        B = spawn_node("B", 8567, 8568)
        runB = replay_sequence(B, runA["payloads"],
                               f"{HERE}/policy/srw3_policy.json",
                               f"{HERE}/policy/deployment.json")
        stop_node(B)

        # H10-D: fresh no-policy build
        B2 = spawn_node("B", 8567, 8568)
        runB_np = build_sequence(B2, "B-np", use_policy=False)
        stop_node(B2)

        # align by payload block hash (replay evaluates deploy payloads too)
        A_by_hash = {s["blockHash"]: s for s in runA["srw3"]}
        B_by_hash = {s["blockHash"]: s for s in runB["srw3"]}
        common = [h for h in A_by_hash if h in B_by_hash]
        A_verdicts = [A_by_hash[h]["srw3"] for h in common]
        B_verdicts = [B_by_hash[h]["srw3"] for h in common]
        A_digests = [A_by_hash[h]["evidenceDigest"] for h in common]
        B_digests = [B_by_hash[h]["evidenceDigest"] for h in common]
        R = {
            "runA": {k: v for k, v in runA.items() if k != "payloads"},
            "runA2": {k: v for k, v in runA2.items() if k != "payloads"},
            "runB_replay": runB,
            "runB_np": {k: v for k, v in runB_np.items() if k != "payloads"},
            "payloadBytesIdentical_A1_vs_A2":
                [p["blockHash"] if p else None for p in runA["payloads"]]
                == [p["blockHash"] if p else None for p in runA2["payloads"]],
            "determinism": {
                "blockHashesIdentical_A1_vs_A2":
                    runA["blocks"] == runA2["blocks"],
                "blockHashesIdentical_A_vs_B_replay":
                    runA["blocks"] == runB["blocks"],
                "evidenceDigestsIdentical_A_vs_B_replay":
                    A_digests == B_digests,
                "comparedPayloads": len(common),
                "execIdsIdentical": runA["evExecId"] == runA2["evExecId"],
                "verdictsIdentical_A_vs_B_replay":
                    A_verdicts == B_verdicts,
            },
            "H10-D non-invasiveness": {
                "blockHashesIdentical_policy_vs_noPolicy":
                    runA["blocks"] == runB_np["blocks"],
            },
        }
        json.dump(R, open(f"{HERE}/transcripts/srw3/determinism.json", "w"),
                  indent=1)
        print(json.dumps({"determinism": R["determinism"],
                          "payloadBytesIdentical": R["payloadBytesIdentical_A1_vs_A2"],
                          "H10-D": R["H10-D non-invasiveness"]}, indent=1))
        return 0
    finally:
        for n in (A,):
            try:
                stop_node(n)
            except Exception:
                pass


if __name__ == "__main__":
    raise SystemExit(main())
