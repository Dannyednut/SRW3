"""SRW3 Phase 1H — SRW3 lineage persistence (sidecar, client-local).

NOT inside Ethereum state: one JSON record per payload + a head pointer file.
Restart-safe (records are on disk before any use), replay-idempotent
(record(key) is a no-op if the identical record exists), and reorg-aware:
the lineage head FOLLOWS the client's canonical head as established by
engine_forkchoiceUpdated responses (section 22 relationship: SRW3 lineage is
a CLIENT-LOCAL projection of canonical history, not the history itself).
"""
from __future__ import annotations

import json
import os
import time


class LineageStore:
    def __init__(self, dirpath: str):
        self.dir = dirpath
        os.makedirs(dirpath, exist_ok=True)
        self.head_path = os.path.join(dirpath, "head.json")
        self._head = None
        if os.path.exists(self.head_path):
            self._head = json.load(open(self.head_path))["head"]

    # ---------------- records ----------------

    def _rec_path(self, block_hash: str) -> str:
        return os.path.join(self.dir, f"rec-{block_hash.removeprefix('0x')}.json")

    def record(self, block_hash: str, parent_hash: str, verdict: str,
               evidence_digest: str, cert_id: str, policy_version: str,
               execution_id: str, head_before: str | None,
               extra: dict | None = None) -> dict:
        rec = {
            "blockHash": block_hash,
            "parentHash": parent_hash,
            "verdict": verdict,
            "evidenceDigest": evidence_digest,
            "authorityCertificate": cert_id,
            "policyVersion": policy_version,
            "executionId": execution_id,
            "lineageHeadBefore": head_before,
            "recordedAt": time.time(),
        }
        if extra:
            rec.update(extra)
        p = self._rec_path(block_hash)
        if os.path.exists(p):
            old = json.load(open(p))
            if old == rec:
                return rec  # replay-idempotent
            # same payload, different verdict -> lineage inconsistency
            raise RuntimeError(
                f"SRW3 lineage inconsistency: {block_hash} recorded twice with "
                f"different content (old verdict {old['verdict']}, new {verdict})")
        tmp = p + ".tmp"
        json.dump(rec, open(tmp, "w"), indent=1)
        os.replace(tmp, p)   # atomic: survives crash mid-write
        return rec

    def get(self, block_hash: str) -> dict | None:
        p = self._rec_path(block_hash)
        return json.load(open(p)) if os.path.exists(p) else None

    def all_records(self) -> list[dict]:
        return [json.load(open(os.path.join(self.dir, f)))
                for f in sorted(os.listdir(self.dir))
                if f.startswith("rec-")]

    # ---------------- head (follows canonical forkchoice) ----------------

    def set_head(self, head: str) -> None:
        self._head = head
        tmp = self.head_path + ".tmp"
        json.dump({"head": head, "updated": time.time()}, open(tmp, "w"))
        os.replace(tmp, self.head_path)

    @property
    def head(self) -> str | None:
        return self._head
