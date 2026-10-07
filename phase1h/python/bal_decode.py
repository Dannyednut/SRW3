"""SRW3 Phase 1H — minimal RLP decoder + EIP-7928 Block Access List decoding.

Used to independently decode the `blockAccessList` field carried by
ExecutionPayloadV4 (engine_newPayloadV5 / engine_getPayloadV6) so the SRW3
adapter can compare the BAL against its own execution-derived effect trace.
"""
from __future__ import annotations


def rlp_decode(b: bytes):
    """Return (value, rest). value is bytes or list (nested)."""
    if not b:
        raise ValueError("empty input")
    p = b[0]
    if p < 0x80:
        return b[:1], b[1:]
    if p < 0xB8:
        n = p - 0x80
        return b[1:1 + n], b[1 + n:]
    if p < 0xC0:
        ln = p - 0xB7
        n = int.from_bytes(b[1:1 + ln], "big")
        return b[1 + ln:1 + ln + n], b[1 + ln + n:]
    if p < 0xF8:
        n = p - 0xC0
        body, rest = b[1:1 + n], b[1 + n:]
    else:
        ln = p - 0xF7
        n = int.from_bytes(b[1:1 + ln], "big")
        body, rest = b[1 + ln:1 + ln + n], b[1 + ln + n:]
    items = []
    while body:
        item, body = rlp_decode(body)
        items.append(item)
    return items, rest


def _hex(b) -> str:
    return "0x" + b.hex()


def decode_bal(rlp_hex: str) -> dict:
    """Decode EIP-7928 BAL (hex string) into a structured dict.

    Structure (EIP-7928):
      BAL = [ [address, [ [slot, value], ...], [readSlots...], [balances],
               [nonce, ...], [code] ], ... ]
    Note: field shapes vary slightly by EIP revision; this decoder is
    defensive and records the raw shape for the report.
    """
    raw = bytes.fromhex(rlp_hex.removeprefix("0x"))
    bal, _ = rlp_decode(raw)
    accounts = []
    for entry in bal:
        addr = _hex(entry[0])
        acc = {"address": addr}
        idx = 1
        # storage changes (EIP-7928 final, as implemented by Geth v1.17.7):
        #   [slot, [[blockAccessIndex, postValue], ...]]
        # blockAccessIndex attributes each write to a transaction (or system
        # operation) inside the block.
        if idx < len(entry) and isinstance(entry[idx], list):
            changes = []
            for pair in entry[idx]:
                if isinstance(pair, list) and len(pair) == 2:
                    slot_b, writes = pair
                    per_tx = []
                    if isinstance(writes, list):
                        for w in writes:
                            if isinstance(w, list) and len(w) == 2:
                                per_tx.append({
                                    "blockAccessIndex": int.from_bytes(w[0], "big")
                                    if isinstance(w[0], bytes) else 0,
                                    "post": _hex(w[1]),
                                })
                    changes.append({"slot": _hex(slot_b), "writes": per_tx})
            acc["storage_changes"] = changes
            idx += 1
        # storage reads: list of slot
        if idx < len(entry) and isinstance(entry[idx], list):
            reads = []
            for s in entry[idx]:
                if isinstance(s, bytes):
                    reads.append(_hex(s))
            acc["storage_reads"] = reads
            idx += 1
        # balances / nonces / code (variable per revision): keep raw remainder
        acc["remaining_fields"] = [
            [_hex(x) if isinstance(x, bytes) else x for x in f] if isinstance(f, list)
            else _hex(f) for f in entry[idx:]
        ]
        accounts.append(acc)
    return {"accounts": accounts, "account_count": len(accounts),
            "rlp_bytes": len(raw)}


def bal_summary(bal: dict) -> dict:
    """Aggregate view used by the BAL-vs-trace analysis (section 19)."""
    writes = set()
    reads = set()
    for a in bal["accounts"]:
        for c in a.get("storage_changes", []):
            writes.add((a["address"], c["slot"]))
        for r in a.get("storage_reads", []):
            reads.add((a["address"], r))
    return {
        "accounts": bal["account_count"],
        "storage_writes": len(writes),
        "storage_reads": len(reads),
        "write_set": sorted(writes),
        "read_set": sorted(reads),
    }


def bal_write_attribution(bal: dict) -> dict:
    """(addr, slot) -> list of (blockAccessIndex, postValue) — per-tx write
    attribution carried by the EIP-7928 BAL."""
    out = {}
    for a in bal.get("accounts", []):
        for c in a.get("storage_changes", []):
            out[(a["address"].lower(), c["slot"].lower())] = [
                (w["blockAccessIndex"], w["post"]) for w in c.get("writes", [])]
    return out
