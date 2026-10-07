"""SRW3 Phase 1H — resource/performance measurements (section 18).

Three workload classes (small / medium / large), each executed as real
payloads through the real Engine API.  For every payload we measure:
  client execution baseline : newPayload RPC round-trip (geth executes the
                              payload inside this call)
  evidence extraction       : receipts + callTracer + prestateTracer(diff)
  SRW3 gate time            : layered gate evaluation
  serialization             : evidence JSON size (bytes) + json.dumps time
  memory                    : adapter RSS delta (rough, via /proc)

No synthetic microbenchmarks: every number comes from the devnet path.
"""
from __future__ import annotations

import json
import resource
import sys
import time

sys.path.insert(0, "/home/z/my-project/srw3-work/phase1h/python")

from boot import Boot, boot_devnet, HERE, CAP, DEPOSIT  # noqa: E402
from engine_client import Devnet  # noqa: E402
from gate_h import GateH  # noqa: E402
from harness import SRW3Harness  # noqa: E402
from lineage import LineageStore  # noqa: E402
from policy import load_policy, load_deployment  # noqa: E402
from evidence import collect_evidence  # noqa: E402
from cl_sim import beacon_root  # noqa: E402

ETH = 10**18


def rss_mb() -> float:
    return resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / 1024.0


def measure_payload(dn, sim, gate, raw_txs: list[str]) -> dict:
    # baseline: client execution (newPayload performs the execution)
    t0 = time.perf_counter()
    res = sim.produce(raw_txs)
    t_produce = (time.perf_counter() - t0) * 1000  # includes txpool wait

    t0 = time.perf_counter()
    ev = collect_evidence(dn, res.payload, res.slot, beacon_root(res.slot))
    t_evidence = (time.perf_counter() - t0) * 1000

    t0 = time.perf_counter()
    verdict, checks = gate.evaluate(ev)
    t_gate = (time.perf_counter() - t0) * 1000

    t0 = time.perf_counter()
    ev_json = ev.to_json()
    ev_json["storage_writes"] = {f"{a}|{s}": v for (a, s), v in ev.storage_writes.items()}
    ev_json["storage_reads"] = [f"{a}|{s}" for (a, s) in sorted(ev.storage_reads)]
    blob = json.dumps(ev_json, default=lambda o: o.hex() if isinstance(o, bytes) else str(o))
    t_ser = (time.perf_counter() - t0) * 1000

    # client-side execution time reported by geth for this block
    blk = dn.rpc.call("eth_getBlockByHash", [res.payload["blockHash"], False])
    return {
        "txs": len(raw_txs),
        "gasUsed": int(res.payload["gasUsed"], 16),
        "harnessProduceMs": round(t_produce, 2),
        "evidenceExtractionMs": round(t_evidence, 2),
        "gateMs": round(t_gate, 2),
        "evidenceSubMs": ev.timings_ms,
        "evidenceJsonBytes": len(blob),
        "serializeMs": round(t_ser, 3),
        "verdict": verdict.verdict,
        "traceEvents": len(ev.effect_trace),
        "balAccounts": ev.bal_summary.get("accounts"),
    }


def spawn_fresh(tag: str, http_port: int, auth_port: int):
    import shutil, subprocess
    dd = f"{HERE}/devnet/chain-perf-{tag}"
    shutil.rmtree(dd, ignore_errors=True)
    subprocess.run([GETH_BIN, "--datadir", dd, "init",
                    f"{HERE}/devnet/genesis.json"], check=True,
                   capture_output=True)
    log = open(f"{HERE}/transcripts/client/geth-perf-{tag}.log", "w")
    p = subprocess.Popen([
        GETH_BIN, "--datadir", dd, "--networkid", "93471",
        "--nat", "none", "--maxpeers", "0", "--nodiscover", "--port", "0",
        "--syncmode", "full", "--gcmode", "archive",
        "--http", "--http.addr", "127.0.0.1", "--http.port", str(http_port),
        "--http.api", "eth,web3,net,debug,txpool,admin",
        "--http.corsdomain", "*", "--http.vhosts", "*",
        "--authrpc.addr", "127.0.0.1", "--authrpc.port", str(auth_port),
        "--authrpc.vhosts", "*", "--authrpc.jwtsecret",
        f"{HERE}/devnet/jwt.hex",
        "--rpc.allow-unprotected-txs", "--verbosity", "2"],
        stdout=log, stderr=log)
    jwt = open(f"{HERE}/devnet/jwt.hex").read().strip()
    dn = Devnet(f"http://127.0.0.1:{auth_port}",
                f"http://127.0.0.1:{http_port}", jwt)
    for _ in range(80):
        try:
            dn.chain_id()
            time.sleep(3.0)
            return dn, p
        except Exception:
            time.sleep(0.5)
    raise RuntimeError(f"perf node {tag} failed")


GETH_BIN = "/home/z/my-project/tools/geth/geth-linux-amd64-1.17.7-3d858f85/geth"


def main() -> int:
    import subprocess as _sp
    _sp.run(["pkill", "-f", "chain-perf"], capture_output=True)
    import time as _t
    _t.sleep(1.5)
    rss0 = rss_mb()
    R = {"adapterRssStartMB": round(rss0, 1)}
    classes = {}
    pol_path = dep_path = None

    # workload builders (deterministic; each sender used once per class)
    def small():
        return boot.txs(1, [(boot.oracle, "setPrice(uint256)",
                             (1000 * ETH + small.n * 7, ), 0)]).raws

    def medium():
        txs = []
        for i in range(10):
            txs.append((boot.oracle, "setPrice(uint256)",
                        (2000 * ETH + i, ), 0))
        return boot.txs(2, txs).raws

    def large():
        # 60 txs; conflicting storage writes capped at ~15 per block —
        # Geth v1.17.7's payload builder was observed never committing
        # batches of 40+ heavily-conflicting SSTOREs (documented as a
        # client-behavior finding; see report section 18).
        txs = []
        recip = ["0x14dC79964da2C08b23698B3D3cc7Ca32193d9955",
                 "0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f"]
        for i in range(30):   # plain transfers: no storage conflict
            txs.append((recip[i % 2], None, (), 10**16))
        for i in range(10):
            txs.append((boot.oracle, "setPrice(uint256)", (3000 * ETH + i, ), 0))
        for i in range(10):
            txs.append((boot.lending, "deposit()", (), 10**17))
        for i in range(10):
            txs.append((boot.lending, "steal(uint256)", (i, ), 0))
        return boot.txs(3, txs).raws

    small.n = 0
    procs = []
    for name, builder, reps in [("small", small, 8), ("medium", medium, 6),
                                ("large", large, 4)]:
        # fresh node per workload class: a failed build batch poisons the
        # txpool for later builds (documented client behavior), and class
        # isolation keeps the workload definitions clean
        dn, proc = spawn_fresh(name, 8571 + 2 * (0 if name == "small" else
                                                (1 if name == "medium" else 2)),
                               8572 + 2 * (0 if name == "small" else
                                           (1 if name == "medium" else 2)))
        procs.append(proc)
        boot = Boot(dn)
        boot.deploy_all()
        if pol_path is None:
            pol_path, dep_path = boot.write_policy(f"{HERE}/policy")
        policy = load_policy(pol_path)
        deployment = load_deployment(dep_path)
        pdigest = policy.verify_against_deployment(deployment)
        gate = GateH(policy, pdigest, deployment["genesisHash"])
        gate.state_reader = lambda a, s, b, _dn=dn: _dn.rpc.call(
            "eth_getStorageAt", [a, s, b])
        runs = []
        for i in range(reps):
            if name == "small":
                small.n = i
            runs.append(measure_payload(dn, boot.sim, gate, builder()))
        med = lambda k: round(
            sum(r[k] for r in runs) / len(runs), 2)
        classes[name] = {
            "runs": runs,
            "summary": {
                "txsPerPayload": runs[0]["txs"],
                "gasUsed": runs[0]["gasUsed"],
                "evidenceExtractionMsMedian": sorted(
                    r["evidenceExtractionMs"] for r in runs)[len(runs) // 2],
                "gateMsMedian": sorted(r["gateMs"] for r in runs)[len(runs)//2],
                "evidenceJsonBytes": runs[0]["evidenceJsonBytes"],
                "traceEvents": runs[0]["traceEvents"],
                "overheadPct_ofProduce": round(
                    100 * (med("evidenceExtractionMs") + med("gateMs"))
                    / max(med("harnessProduceMs"), 0.01), 1),
            },
        }
    for p in procs:
        p.terminate()
    R["classes"] = classes
    R["adapterRssEndMB"] = round(rss_mb(), 1)
    R["adapterRssDeltaMB"] = round(rss_mb() - rss0, 1)
    R["notes"] = {
        "baseline": "harnessProduceMs includes txpool admission wait + "
                    "fcu/getPayload build + newPayload execution (client-side "
                    "execution dominates it)",
        "scaling": "evidence extraction scales with trace volume "
                   "(callTracer + prestateTracer); gate time is dominated by "
                   "the canonical effect encoding",
    }
    json.dump(R, open(f"{HERE}/transcripts/perf/perf_results.json", "w"),
              indent=1, default=str)
    for k, v in classes.items():
        print(k, json.dumps(v["summary"]))
    print("adapter RSS delta MB:", R["adapterRssDeltaMB"])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
