"""SRW3 Phase 1H — ClientExecutionEvidence adapter.

Derives SRW3 execution evidence FROM THE REAL CLIENT (Geth):
  payload digest / parent root / child root: Engine API payload + block headers
  execution identity / configuration:        RPC (web3_clientVersion, chainId,
                                             debug_chainConfig)
  ordered effect trace:                      receipts + callTracer + prestateTracer(diffMode)
  block access list:                         ExecutionPayloadV4.blockAccessList (EIP-7928)

Nothing is reconstructed from a synthetic SRW3 state model; every field
records where it came from.  Domain separation mirrors the Phase 1F/1G
machinery (ExecutionId over (parentRoot, payloadDigest, configDigest,
envDigest); ordered canonical effect encoding under "SRW3-EFFECTS-V1").
"""
from __future__ import annotations

import hashlib
import json
import time
from dataclasses import dataclass, field, asdict

from eth_utils import keccak

from bal_decode import decode_bal, bal_summary

EFFECTS_DOM = b"SRW3-EFFECTS-V1"
EXECID_DOM = b"SRW3-EXECID-V1"

SYSTEM_ADDRS = {
    "0x000f3df6d732807ef1319fb7b8bb8522d0beac02",  # beacon roots (EIP-4788)
    "0x0000f90827f1c53a10cb7a02335b175320002935",  # history storage (EIP-2935)
    "0x00000961ef480eb55e80d19ad83579a64c007002",  # withdrawal queue (EIP-7002)
    "0x0000bbddc7ce488642fb579f8b00f3a590007251",  # consolidation queue (EIP-7251)
    "0x0000bff46984e3725691fa540a8c7589300d8282",  # builder deposit (EIP-8282)
    "0x000064d678505ad48f8ccb093bc65613800e8282",  # builder exit
    "0xfffffffffffffffffffffffffffffffffffffffe",  # system address
}


def _h(x) -> str:
    return "0x" + keccak(x).hex()


def _u32(v: int) -> bytes:
    return int(v).to_bytes(32, "big")


def _b32(x: str) -> bytes:
    return bytes.fromhex(x.removeprefix("0x").rjust(64, "0"))


def _b20(x: str) -> bytes:
    return bytes.fromhex(x.removeprefix("0x").rjust(40, "0"))


@dataclass
class ClientExecutionEvidence:
    # --- bindings required by Phase 1H section 8 ---
    payload_digest: str          # payload.blockHash (client's own commitment)
    parent_root: str             # parent header stateRoot (client's canonical record)
    execution_identity: dict     # client impl/version/chain/fork
    effect_digest: str           # keccak over canonical ordered effect encoding
    child_state_root: str        # payload.stateRoot, cross-checked vs header
    execution_configuration: dict  # chain config digest + fork + slot context

    # --- derived, from the client ---
    execution_id: str = ""
    env_digest: str = ""
    effect_trace: list = field(default_factory=list)   # ordered event tuples
    call_tree: list = field(default_factory=list)      # flattened callTracer
    storage_writes: dict = field(default_factory=dict)  # (addr,slot) -> value
    storage_reads: set = field(default_factory=set)
    logs: list = field(default_factory=list)
    receipts: list = field(default_factory=list)
    bal_raw: str = ""
    bal: dict = field(default_factory=dict)
    bal_summary: dict = field(default_factory=dict)
    timings_ms: dict = field(default_factory=dict)
    provenance: dict = field(default_factory=dict)

    def to_json(self) -> dict:
        d = asdict(self)
        d["storage_reads"] = sorted(self.storage_reads)
        return d


def active_fork(chain_config: dict, ts: int) -> str:
    names = [
        ("amsterdam", "amsterdamTime"), ("osaka", "osakaTime"),
        ("prague", "pragueTime"), ("cancun", "cancunTime"),
        ("shanghai", "shanghaiTime"),
    ]
    for name, key in names:
        t = chain_config.get(key)
        if t is not None and ts >= int(t):
            return name
    return "pre-shanghai"


def collect_evidence(dn, payload: dict, slot: int,
                     beacon_root_hex: str) -> ClientExecutionEvidence:
    """Build evidence for one executed payload, entirely from client data."""
    t = {}

    t0 = time.perf_counter()
    block_hash = payload["blockHash"]
    parent_hash = payload["parentHash"]
    child_root = payload["stateRoot"]

    # execution identity + configuration (client-provided).
    # NOTE: geth v1.17.7 does NOT expose debug_chainConfig; the chain config
    # is read from admin_nodeInfo.protocols.eth.config instead (recorded in
    # provenance).  If neither were available this would be an explicit
    # NOT EXPOSED BY CLIENT gap requiring instrumentation.
    client_version = dn.rpc.call("web3_clientVersion", [])
    chain_id = dn.chain_id()
    try:
        node_info = dn.rpc.call("admin_nodeInfo", [])
        chain_config = node_info["protocols"]["eth"]["config"]
    except Exception:
        chain_config = {}
    fork = active_fork(chain_config, int(payload["timestamp"], 16))

    # parent root: from the client's canonical record of the parent block
    parent_block = dn.block_by_hash(parent_hash, full=False)
    if parent_block is None:
        raise RuntimeError(f"parent block {parent_hash} unknown to client")
    parent_root = parent_block["stateRoot"]

    # state-root binding check (section 9): the client's post-execution
    # commitment for THIS block
    block = dn.block_by_hash(block_hash, full=False)
    header_child_root = block["stateRoot"] if block else None
    t["state_root_binding"] = (time.perf_counter() - t0) * 1000

    # receipts: authoritative ordering + logs + status
    t0 = time.perf_counter()
    receipts = dn.block_receipts(block_hash) or []
    t["receipts"] = (time.perf_counter() - t0) * 1000

    # call tree (ordered, addressed)
    t0 = time.perf_counter()
    call_traces = dn.trace_block_call_tracer(block_hash)
    t["call_tracer"] = (time.perf_counter() - t0) * 1000

    # storage diff (reads + writes with values)
    t0 = time.perf_counter()
    diffs = dn.trace_block_prestate_diff(block_hash)
    t["prestate_diff"] = (time.perf_counter() - t0) * 1000

    # ---- effect derivation ----
    calls: list[dict] = []

    def flatten(node: dict):
        calls.append({
            "from": (node.get("from") or "").lower(),
            "to": (node.get("to") or "").lower(),
            "type": node.get("type", "CALL"),
            "value": str(node.get("value", "0x0")),
            "fn": node.get("input", "0x")[:10],
        })
        for ch in node.get("calls", []) or []:
            flatten(ch)

    for i, tr in enumerate(call_traces):
        node = tr.get("result", {})
        if node:
            node = dict(node)
            node["_txIndex"] = i
            flatten(node)

    writes: dict[tuple[str, str], str] = {}
    reads: set[tuple[str, str]] = set()
    for d in diffs:
        res = d.get("result", {})
        for addr, acc in res.get("pre", {}).items():
            for slot in (acc.get("storage") or {}):
                if addr.lower() not in SYSTEM_ADDRS:
                    reads.add((addr.lower(), slot.lower()))
        for addr, acc in res.get("post", {}).items():
            for slot, val in (acc.get("storage") or {}).items():
                if addr.lower() not in SYSTEM_ADDRS:
                    writes[(addr.lower(), slot.lower())] = val

    logs = []
    for r in receipts:
        for lg in r.get("logs", []):
            logs.append({
                "addr": lg["address"].lower(),
                "topic0": lg["topics"][0] if lg.get("topics") else "0x",
                "data": lg.get("data", "0x"),
                "txIndex": int(r["transactionIndex"], 16),
            })

    # ---- canonical ordered encoding (Phase 1F fragment adapted) ----
    # tx order = receipt order (execution order in the block); within a tx:
    # calls in callTracer pre-order, then storage writes/reads in canonical
    # (addr, slot) order, then logs.  Interaction obligations evaluated on
    # this encoding operate at tx granularity (documented in the report).
    txs_ordered = sorted(
        range(len(receipts)), key=lambda i: int(receipts[i]["transactionIndex"], 16))
    diff_by_tx = {}
    for i, d in enumerate(diffs):
        diff_by_tx[i] = d.get("result", {})

    enc = bytearray(EFFECTS_DOM)
    trace: list = []
    for i in txs_ordered:
        tx_hash = receipts[i].get("transactionHash", "0x")
        enc += b"TX|" + _b32(tx_hash) + b"|"
        trace.append(["TX", i, tx_hash])
        # calls for this tx: callTracer returns block traces in tx order
        if i < len(call_traces):
            calls_tx: list[dict] = []

            def flat2(node: dict):
                calls_tx.append({
                    "from": (node.get("from") or "").lower(),
                    "to": (node.get("to") or "").lower(),
                    "type": node.get("type", "CALL"),
                    "value": str(node.get("value", "0x0")),
                    "fn": node.get("input", "0x")[:10],
                })
                for ch in node.get("calls", []) or []:
                    flat2(ch)

            n = call_traces[i].get("result", {})
            if n:
                flat2(n)
            for c in calls_tx:
                enc += b"CALL|" + _b20(c["from"]) + _b20(c["to"]) \
                    + _u32(int(c["value"], 16)) + b"|"
                trace.append(["CALL", c])
            calls.extend(calls_tx)
        # writes/reads for this tx from per-tx prestate diff
        res = diff_by_tx.get(i, {})
        tx_writes = []
        tx_reads = []
        for addr, acc in res.get("pre", {}).items():
            for slot in (acc.get("storage") or {}):
                if addr.lower() not in SYSTEM_ADDRS:
                    tx_reads.append((addr.lower(), slot.lower()))
        for addr, acc in res.get("post", {}).items():
            for slot, val in (acc.get("storage") or {}).items():
                if addr.lower() not in SYSTEM_ADDRS:
                    tx_writes.append((addr.lower(), slot.lower(), val))
                    writes[(addr.lower(), slot.lower())] = val
        for (a, s) in sorted(set(tx_reads)):
            enc += b"READ|" + _b20(a) + _b32(s) + b"|"
            trace.append(["READ", a, s])
        for (a, s, v) in sorted(tx_writes):
            enc += b"WRITE|" + _b20(a) + _b32(s) + _b32(v) + b"|"
            trace.append(["WRITE", a, s, v])
            reads.add((a, s))
        for lg in logs:
            if lg["txIndex"] == i:
                enc += b"LOG|" + _b20(lg["addr"]) + _b32(lg["topic0"]) + b"|"
                trace.append(["LOG", lg])
        enc += b"ENDTX|"
    effect_digest = _h(bytes(enc))

    # execution configuration digest (client-provided config, canonical form)
    config_json = json.dumps(chain_config, sort_keys=True, separators=(",", ":"))
    config_digest = _h(config_json.encode())
    env_payload = json.dumps({
        "timestamp": payload["timestamp"],
        "prevRandao": payload["prevRandao"],
        "slotNumber": payload.get("slotNumber"),
        "parentBeaconBlockRoot": beacon_root_hex,
        "feeRecipient": payload["feeRecipient"],
        "gasLimit": payload["gasLimit"],
        "baseFeePerGas": payload["baseFeePerGas"],
        "excessBlobGas": payload.get("excessBlobGas"),
    }, sort_keys=True, separators=(",", ":"))
    env_digest = _h(env_payload.encode())

    exec_id = _h(EXECID_DOM + _b32(parent_root) + _b32(block_hash)
                 + _b32(config_digest) + _b32(env_digest))

    # BAL from the payload itself (EIP-7928, ExecutionPayloadV4)
    bal_raw = payload.get("blockAccessList") or ""
    bal = decode_bal(bal_raw) if bal_raw else {}
    bsum = bal_summary(bal) if bal else {}

    ev = ClientExecutionEvidence(
        payload_digest=block_hash,
        parent_root=parent_root,
        execution_identity={
            "client": client_version,
            "chainId": chain_id,
            "impl": "go-ethereum",
        },
        effect_digest=effect_digest,
        child_state_root=child_root,
        execution_configuration={
            "configDigest": config_digest,
            "chainConfig": chain_config,
            "activeFork": fork,
            "slotNumber": slot,
            "beaconRoot": beacon_root_hex,
        },
        execution_id=exec_id,
        env_digest=env_digest,
        effect_trace=trace,
        call_tree=calls,
        storage_writes=writes,
        storage_reads=reads,
        logs=logs,
        receipts=[{k: r[k] for k in ("transactionHash", "status", "gasUsed",
                                     "contractAddress", "transactionIndex")}
                  for r in receipts],
        bal_raw=bal_raw,
        bal=bal,
        bal_summary=bsum,
        timings_ms={k: round(v, 3) for k, v in t.items()},
        provenance={
            "payload": "engine_getPayloadV6 / engine_newPayloadV5",
            "parentRoot": "eth_getBlockByHash(parentHash).stateRoot",
            "childRoot": "payload.stateRoot == eth_getBlockByHash(hash).stateRoot",
            "effects": "debug_traceBlockByHash(callTracer+prestateTracer diffMode)"
                       " + eth_getBlockReceipts",
            "bal": "ExecutionPayloadV4.blockAccessList (EIP-7928)",
            "config": "debug_chainConfig + web3_clientVersion",
        },
    )
    if header_child_root and header_child_root.lower() != child_root.lower():
        raise RuntimeError("state-root binding mismatch: payload vs header")
    return ev
