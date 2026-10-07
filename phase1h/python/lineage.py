"""SRW3 Phase 1H — SRW3 lineage persistence (sidecar, client-local).

NOT inside Ethereum state: one JSON record per payload + a head pointer file.
Restart-safe (records are on disk before any use), replay-idempotent, and
reorg-aware: the lineage head FOLLOWS the client's canonical head as
established by engine_forkchoiceUpdated responses (section 22 relationship:
SRW3 lineage is a CLIENT-LOCAL projection of canonical history, not the
history itself).

Phase 1H-R1 (semantic replay idempotence, R1):

A lineage record carries two kinds of information:

  SECURITY-SEMANTIC FIELDS — define the identity/content of the record:
      blockHash, parentHash, verdict, evidenceDigest, authorityCertificate,
      policyVersion, executionId, lineageHeadBefore, and every
      security-relevant extra field (srw3Layer, reason, slot,
      securityContextDigest, ...).

  OBSERVATION METADATA — non-semantic side observations of the recording
      process (recordedAt and optional process/session metadata).

Duplicate insertion rules (R1):

  * identical SEMANTIC content (observation metadata may differ freely)
        -> IDEMPOTENT: return the previously persisted record, do not
           rewrite it, do not touch its recordedAt, leave the file bytes
           unchanged;
  * ANY security-semantic disagreement
        -> FAIL CLOSED with LineageInconsistencyError naming the differing
           semantic fields.

The semantic projection is computed by semantic_record(); the canonical
comparison is exact structural equality of the projections (both sides are
JSON-loaded objects, so comparison is deterministic and independent of file
formatting).  Observation metadata can therefore never turn an identical
replay into an inconsistency, and it can never mask a semantic mutation:
the semantic projection IGNORES observation keys entirely and compares
everything else.
"""
from __future__ import annotations

import json
import os
import time

# Non-semantic observation keys: never part of the record identity, never
# compared, never able to trigger or suppress a lineage inconsistency.
# The explicit set covers the historical field; the prefix rule covers
# optional future process/session metadata without enumerating it.
OBSERVATION_KEYS = frozenset({
    "recordedAt",        # wall-clock recording time (the R1 defect)
})
OBSERVATION_PREFIXES = ("obs_", "obs.", "session_", "session.")


def is_observation_key(key: str) -> bool:
    """True for non-semantic observation metadata (R1 classification)."""
    if key in OBSERVATION_KEYS:
        return True
    return any(key.startswith(p) for p in OBSERVATION_PREFIXES)


# Fixed security-semantic fields of every lineage record.  Extra keys are
# semantic by default (srw3Layer, reason, slot, securityContextDigest, ...);
# only is_observation_key() demotes a key to non-semantic.
SEMANTIC_FIELDS = (
    "blockHash",
    "parentHash",
    "verdict",
    "evidenceDigest",
    "authorityCertificate",
    "policyVersion",
    "executionId",
    "lineageHeadBefore",
)


class LineageInconsistencyError(RuntimeError):
    """A payload already carries a semantically DIFFERENT lineage record.

    Fail-closed by design (Phase 1H-R1): the store refuses to overwrite or
    silently accept a second, security-semantic-different record for the
    same blockHash.  Subclasses RuntimeError for backward compatibility
    with Phase 1H handlers.
    """


def semantic_record(record: dict) -> dict:
    """Canonical security-semantic projection of a lineage record (R1).

    Drops observation metadata (recordedAt, process/session keys), keeps
    every fixed semantic field and every semantic extra field.  The result
    is a plain dict; comparison is structural equality.  Deterministic:
    the projection depends only on the record's semantic content.
    """
    return {k: v for k, v in record.items() if not is_observation_key(k)}


def semantic_diff(old: dict, new: dict) -> list[str]:
    """Sorted list of semantic keys where two projections disagree."""
    keys = set(old) | set(new)
    return sorted(k for k in keys if old.get(k) != new.get(k))


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
        """Persist one lineage record with R1 replay-idempotence.

        First insertion for a blockHash: atomically write the record.

        Duplicate insertion with IDENTICAL semantic content: return the
        previously persisted record unchanged (no rewrite, no recordedAt
        update, file bytes untouched).

        Duplicate insertion with ANY semantic difference (verdict, evidence
        digest, authority certificate, policy version, lineage head,
        security-context digest, layer/reason/slot, ...): raise
        LineageInconsistencyError (fail closed).
        """
        rec = {
            "blockHash": block_hash,
            "parentHash": parent_hash,
            "verdict": verdict,
            "evidenceDigest": evidence_digest,
            "authorityCertificate": cert_id,
            "policyVersion": policy_version,
            "executionId": execution_id,
            "lineageHeadBefore": head_before,
            "recordedAt": time.time(),   # OBSERVATION metadata (non-semantic, R1)
        }
        if extra:
            rec.update(extra)
        p = self._rec_path(block_hash)
        if os.path.exists(p):
            old = json.load(open(p))
            old_sem = semantic_record(old)
            new_sem = semantic_record(rec)
            if old_sem == new_sem:
                # R1: semantically identical replay -> idempotent.  Return
                # the PREVIOUSLY PERSISTED record; never rewrite the file
                # (recordedAt and bytes stay exactly as first written).
                return old
            # R1: security-semantic disagreement -> fail closed, naming
            # the differing semantic fields (deterministic message).
            diff = semantic_diff(old_sem, new_sem)
            raise LineageInconsistencyError(
                f"SRW3 lineage inconsistency: {block_hash} recorded twice with "
                f"different security-semantic content "
                f"(old verdict {old.get('verdict')}, new {verdict}); "
                f"differing semantic fields: {diff}")
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
