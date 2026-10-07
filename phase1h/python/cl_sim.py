"""SRW3 Phase 1H — CL simulator.

Plays the consensus client against the real Geth Engine API:
  forkchoiceUpdatedV4(+attributes) -> getPayloadV6 -> newPayloadV5 -> forkchoiceUpdatedV4

All block-context attributes (timestamp, prevRandao, beacon root, slot number)
are DETERMINISTIC functions of the slot index so that identical transactions
produce byte-identical payloads across independent runs (required by
Phase 1H section 17).
"""
from __future__ import annotations

import hashlib
import time
from dataclasses import dataclass, field

from engine_client import Devnet, ZERO_HASH

BASE_TS = 1_700_000_000  # deterministic wall-clock-free base timestamp
FEE_RECIPIENT = "0x9965507D1a55bcC269514583FDeE676187EF7C6A"  # dev account 5


def prev_randao(slot: int) -> str:
    return "0x" + hashlib.sha256(f"srw3-prevrandao-{slot}".encode()).hexdigest()


def beacon_root(slot: int) -> str:
    return "0x" + hashlib.sha256(f"srw3-beaconroot-{slot}".encode()).hexdigest()


@dataclass
class BuildResult:
    slot: int
    payload_id: str | None
    envelope: dict | None = None
    payload: dict | None = None
    new_payload_status: dict | None = None
    build_fcu_status: dict | None = None
    canonicalize_status: dict | None = None
    rebuilt: bool = False
    head_before: str = ZERO_HASH
    tx_count: int = 0


@dataclass
class ChainSim:
    dn: Devnet
    chain_id: int
    head: str = ZERO_HASH
    finalized: str = ZERO_HASH
    safe: str = ZERO_HASH
    slot: int = 0
    last_ts: int = BASE_TS
    fee_recipient: str = FEE_RECIPIENT
    log: list = field(default_factory=list)

    # ---------------- state ----------------

    @classmethod
    def create(cls, dn: Devnet, chain_id: int) -> "ChainSim":
        gen = dn.head()
        ts = int(gen["timestamp"], 16) if "timestamp" in gen else 0
        return cls(dn=dn, chain_id=chain_id, head=gen["hash"],
                   finalized=gen["hash"], safe=gen["hash"],
                   last_ts=max(BASE_TS, ts),
                   slot=int(gen.get("slotNumber", "0x0"), 16))

    def attributes(self, slot: int) -> dict:
        return {
            "timestamp": hex(self.last_ts + 1),
            "prevRandao": prev_randao(slot),
            "suggestedFeeRecipient": self.fee_recipient,
            "withdrawals": [],
            "parentBeaconBlockRoot": beacon_root(slot),
            "slotNumber": hex(slot),
        }

    # ---------------- primitives ----------------

    def fcu(self, head: str, attrs: dict | None = None,
            finalized: str | None = None, safe: str | None = None) -> dict:
        fin = finalized if finalized is not None else self.finalized
        saf = safe if safe is not None else self.safe
        r = self.dn.forkchoice_updated_v4(head, fin, saf, attrs)
        self.log.append({"op": "fcu", "head": head, "attrs": attrs, "resp": r})
        return r

    def build_on(self, parent: str, raw_txs: list[str] | None = None,
                 slot: int | None = None) -> BuildResult:
        """Start payload building on `parent` (may reorg), return built payload."""
        slot = slot if slot is not None else self.slot + 1
        attrs = self.attributes(slot)
        attrs["timestamp"] = hex(self.last_ts + 1)
        self.last_ts += 1
        self.dn.rpc.log = []
        for raw in (raw_txs or []):
            self.dn.send_raw_tx(raw)
        if raw_txs:
            # wait until the txpool has admitted every tx, then settle so the
            # miner worker's pool snapshot includes them (build jobs snapshot
            # the pool at job start; a job started too early misses txs)
            import time as _t
            deadline = _t.time() + 5
            while _t.time() < deadline:
                st = self.dn.rpc.call("txpool_status", [])
                if int(st["pending"], 16) + int(st["queued"], 16) >= len(raw_txs):
                    break
                _t.sleep(0.05)
            _t.sleep(1.2)
        res = BuildResult(slot=slot, payload_id=None, head_before=self.head,
                          tx_count=len(raw_txs or []))
        # Fallback loop: an identical-attributes fcu returns the SAME build
        # job; a fresh pool snapshot requires a NEW payload identity
        # (timestamp+1 per attempt).  Rebuilt payloads are flagged so
        # determinism checks can detect CL-side attribute divergence.
        for attempt in range(4):
            a = dict(attrs)
            if attempt:
                a["timestamp"] = hex(int(attrs["timestamp"], 16) + attempt)
                self.last_ts = int(attrs["timestamp"], 16) + attempt
            fcu = self.fcu(parent, a)
            res.build_fcu_status = fcu.get("payloadStatus")
            pid = fcu.get("payloadId")
            if not pid:
                self.log.append({"op": "build-failed", "slot": slot,
                                 "fcu": fcu})
                return res
            res.payload_id = pid
            # getPayloadV6 DELIVERS and CLOSES the build job: calling it too
            # early returns/seals an empty payload before the worker's first
            # commit finishes.  Wait for the initial commit proportional to
            # the transaction count.
            if raw_txs:
                _t.sleep(min(3.0, 0.05 * len(raw_txs) + 0.4))
            env = self.dn.get_payload_v6(pid)
            if not raw_txs or (len(env["executionPayload"]["transactions"])
                               == len(raw_txs)):
                if attempt:
                    res.rebuilt = True
                break
            _t.sleep(1.0)
        else:
            env = self.dn.get_payload_v6(res.payload_id)
        res.envelope = env
        res.payload = env["executionPayload"]
        if raw_txs and len(res.payload["transactions"]) != len(raw_txs):
            raise RuntimeError(
                f"payload build missed transactions: built "
                f"{len(res.payload['transactions'])} of {len(raw_txs)} "
                f"(txpool race persisted)")
        return res

    def submit(self, res: BuildResult) -> BuildResult:
        """engine_newPayloadV5 for a built payload (no canonicalization)."""
        attrs_slot = res.slot
        res.new_payload_status = self.dn.new_payload_v5(
            res.payload, [], beacon_root(attrs_slot), [])
        self.log.append({"op": "newPayload", "slot": attrs_slot,
                         "hash": res.payload["blockHash"],
                         "resp": res.new_payload_status})
        return res

    def canonicalize(self, block_hash: str) -> dict:
        r = self.fcu(block_hash)
        if r.get("payloadStatus", {}).get("status") == "VALID":
            self.head = block_hash
        return r

    def drain_pool(self, max_blocks: int = 4) -> int:
        """Mine empty blocks until the txpool is clean (used after reorgs:
        reverted branch txs are re-injected into the pool and would
        contaminate later scenario payloads)."""
        n = 0
        for _ in range(max_blocks):
            st = self.dn.rpc.call("txpool_status", [])
            if int(st["pending"], 16) + int(st["queued"], 16) == 0:
                break
            self.produce(None)
            n += 1
        return n

    def produce(self, raw_txs: list[str] | None = None,
                parent: str | None = None, submit_only: bool = False,
                defer_canonicalize: bool = False) -> BuildResult:
        """Full CL cycle: build on parent (default: current head), submit,
        canonicalize.  With defer_canonicalize=True the payload is executed
        (newPayload) but NOT canonicalized — the gate point sits between
        execution and fork choice (section 15/29)."""
        parent = parent or self.head
        res = self.build_on(parent, raw_txs)
        if res.payload is None:
            return res
        self.submit(res)
        if not submit_only and not defer_canonicalize:
            res.canonicalize_status = self.canonicalize(res.payload["blockHash"])
        self.slot = res.slot
        return res
