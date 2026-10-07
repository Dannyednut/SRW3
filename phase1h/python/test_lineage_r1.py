"""SRW3 Phase 1H-R1 — LID lineage-idempotence suite (Fix A).

Verifies the repaired LineageStore against the R1 requirements:

  LID-1  exact duplicate replay (independently generated timestamps)
  LID-2  duplicate differing only in recordedAt            -> IDEMPOTENT
  LID-3  duplicate with different verdict                  -> inconsistency
  LID-4  duplicate with different evidence digest          -> inconsistency
  LID-5  duplicate with different authority certificate    -> inconsistency
  LID-6  duplicate with different policy version           -> inconsistency
  LID-7  duplicate with different security-context digest  -> inconsistency
  LID-8  (supplementary) semantic extra-field mutation     -> inconsistency
  LID-9  (supplementary) observation metadata cannot MASK
         a semantic mutation                               -> inconsistency
  LID-10 (supplementary, section 14) restart persistence:
         new store instance over the same directory replays idempotently,
         bytes unchanged, no duplicate record

Pure-Python suite (no devnet): exercises the persistence layer itself.
Output: phase1h-r1-fix/transcripts/repair/lineage_idempotence.json
"""
from __future__ import annotations

import json
import os
import sys
import tempfile
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import r1_support  # noqa: E402
from lineage import (LineageStore, LineageInconsistencyError,  # noqa: E402
                     semantic_record, is_observation_key)

RESULTS: list[dict] = []


def expect(name: str, expected: str, ok: bool, observed, detail=None):
    RESULTS.append({
        "test": name,
        "expected": expected,
        "observed": observed,
        "pass": bool(ok),
        "detail": detail,
    })
    print(("PASS " if ok else "FAIL ") + name + " -> " + str(observed))


def base_args(i: int = 0) -> dict:
    """One semantic content; observation metadata is generated per call."""
    return {
        "block_hash": "0x" + f"{i:064x}",
        "parent_hash": "0x" + f"{i+1:064x}",
        "verdict": "SRW3_VALID",
        "evidence_digest": "0x" + "ab" * 32,
        "cert_id": "0x" + "cd" * 32,
        "policy_version": "srw3-policy-1h-v1",
        "execution_id": "0x" + "ef" * 32,
        "head_before": "0x" + "11" * 32,
        "extra": {"srw3Layer": None, "reason": None, "slot": 7,
                  "securityContextDigest": "0x" + "cc" * 32},
    }


def rec_file_bytes(store: LineageStore, block_hash: str) -> bytes:
    p = os.path.join(store.dir,
                     f"rec-{block_hash.removeprefix('0x')}.json")
    return open(p, "rb").read() if os.path.exists(p) else b""


def main() -> int:
    r1_support.ensure_repair_transcript_dir()
    tmp = tempfile.mkdtemp(prefix="srw3-r1-lid-")

    # ---------------- LID-1: exact duplicate replay ----------------
    store = LineageStore(os.path.join(tmp, "lid1"))
    a1 = base_args(1)
    first = store.record(**a1)
    time.sleep(0.02)                       # ensure a different wall-clock
    bytes_before = rec_file_bytes(store, a1["block_hash"])
    second = store.record(**a1)            # re-derived recordedAt differs
    bytes_after = rec_file_bytes(store, a1["block_hash"])
    ok = (second == first
          and second["recordedAt"] == first["recordedAt"]
          and bytes_before == bytes_after
          and len(store.all_records()) == 1)
    expect("LID-1", "same persisted record returned; file bytes unchanged; "
                    "no second record", ok,
           {"returnsPersisted": second == first,
            "recordedAtUnchanged": second["recordedAt"] == first["recordedAt"],
            "bytesUnchanged": bytes_before == bytes_after,
            "recordCount": len(store.all_records())})

    # ---------------- LID-2: timestamp-only difference ----------------
    store = LineageStore(os.path.join(tmp, "lid2"))
    a2 = base_args(2)
    first = store.record(**a2)
    old_sem = semantic_record(first)
    new_sem = dict(old_sem)
    new_sem["recordedAt"] = first["recordedAt"] + 123.456
    ok = (semantic_record(new_sem) == semantic_record(first)
          and is_observation_key("recordedAt")
          and not is_observation_key("verdict"))
    expect("LID-2", "IDEMPOTENT (recordedAt is non-semantic)", ok,
           {"semanticProjectionIgnoresRecordedAt":
                semantic_record(new_sem) == semantic_record(first),
            "recordedAtClassifiedObservation": is_observation_key("recordedAt")})

    # ---------------- LID-3..LID-7: semantic mutations fail closed ------
    mutation_cases = [
        ("LID-3", "verdict", "SRW3_REJECT"),
        ("LID-4", "evidence_digest", "0x" + "ff" * 32),
        ("LID-5", "cert_id", "0x" + "9e" * 32),
        ("LID-6", "policy_version", "srw3-policy-1h-v1-EVIL"),
    ]
    for name, field, evil in mutation_cases:
        store = LineageStore(os.path.join(tmp, name.lower()))
        args = base_args(3)
        store.record(**args)
        mutated = dict(args)
        mutated[field] = evil
        try:
            store.record(**mutated)
            expect(name, "REJECT / lineage inconsistency", False,
                   "UNEXPECTED-ACCEPT")
        except LineageInconsistencyError as e:
            expect(name, "REJECT / lineage inconsistency", True,
                   "LineageInconsistencyError", str(e)[:160])
        except Exception as e:  # noqa: BLE001
            expect(name, "REJECT / lineage inconsistency", False,
                   f"wrong error type {type(e).__name__}", str(e)[:160])

    # LID-7: security-context digest is SEMANTIC (extra field)
    store = LineageStore(os.path.join(tmp, "lid7"))
    args = base_args(4)
    store.record(**args)
    mutated = dict(args)
    mutated["extra"] = dict(args["extra"])
    mutated["extra"]["securityContextDigest"] = "0x" + "dd" * 32
    try:
        store.record(**mutated)
        expect("LID-7", "REJECT / lineage inconsistency", False,
               "UNEXPECTED-ACCEPT")
    except LineageInconsistencyError as e:
        expect("LID-7", "REJECT / lineage inconsistency", True,
               "LineageInconsistencyError", str(e)[:160])

    # ---------------- LID-8: any semantic extra mutation fails ----------
    store = LineageStore(os.path.join(tmp, "lid8"))
    args = base_args(5)
    store.record(**args)
    mutated = dict(args)
    mutated["extra"] = dict(args["extra"])
    mutated["extra"]["slot"] = 99
    try:
        store.record(**mutated)
        expect("LID-8", "REJECT / lineage inconsistency (semantic extra)",
               False, "UNEXPECTED-ACCEPT")
    except LineageInconsistencyError:
        expect("LID-8", "REJECT / lineage inconsistency (semantic extra)",
               True, "LineageInconsistencyError")

    # ---------------- LID-9: observation metadata cannot mask ----------
    store = LineageStore(os.path.join(tmp, "lid9"))
    args = base_args(6)
    store.record(**args)
    mutated = dict(args)
    mutated["verdict"] = "SRW3_REJECT"      # semantic mutation...
    # ...recordedAt freely differs on top; must STILL fail
    try:
        store.record(**mutated)
        expect("LID-9", "REJECT / lineage inconsistency (metadata cannot "
                        "mask semantic difference)", False,
               "UNEXPECTED-ACCEPT")
    except LineageInconsistencyError:
        expect("LID-9", "REJECT / lineage inconsistency (metadata cannot "
                        "mask semantic difference)", True,
               "LineageInconsistencyError")

    # ---------------- LID-10: restart persistence (section 14) ---------
    dir10 = os.path.join(tmp, "lid10")
    store = LineageStore(dir10)
    a10 = base_args(7)
    first = store.record(**a10)
    bytes_before = rec_file_bytes(store, a10["block_hash"])
    store.set_head(a10["block_hash"])       # head advanced (canonicalized)
    del store                               # --- "restart" ---
    store2 = LineageStore(dir10)            # fresh instance over same dir
    # replay with the SAME semantic content (fresh wall-clock)
    second = store2.record(**a10)
    bytes_after = rec_file_bytes(store2, a10["block_hash"])
    ok = (second == first
          and bytes_before == bytes_after
          and len(store2.all_records()) == 1
          and store2.head == a10["block_hash"]
          and second["lineageHeadBefore"] == a10["head_before"])
    expect("LID-10", "restart: same record returned, bytes unchanged, no "
                     "duplicate, head preserved", ok,
           {"returnsPersisted": second == first,
            "bytesUnchanged": bytes_before == bytes_after,
            "recordCount": len(store2.all_records()),
            "headRestored": store2.head == a10["block_hash"]})

    # ---------------- error message determinism check -------------------
    store = LineageStore(os.path.join(tmp, "msg"))
    args = base_args(8)
    store.record(**args)
    mutated = dict(args)
    mutated["verdict"] = "SRW3_REJECT"
    msgs = []
    for _ in range(2):
        try:
            store.record(**mutated)
        except LineageInconsistencyError as e:
            msgs.append(str(e))
    expect("LID-MSG", "deterministic inconsistency message", 
           msgs[0] == msgs[1] and "verdict" in msgs[0],
           "message stable and names the differing semantic field")

    summary = {
        "suite": "SRW3 Phase 1H-R1 lineage semantic-idempotence (Fix A, LID)",
        "total": len(RESULTS),
        "passed": sum(1 for r in RESULTS if r["pass"]),
        "failed": sum(1 for r in RESULTS if not r["pass"]),
        "tests": RESULTS,
        "classification": "R1: implementation-level semantic idempotence, "
                          "experimentally tested (not a K proof)",
    }
    r1_support.attach_and_dump(
        summary, os.path.join(r1_support.REPAIR_TRANSCRIPTS,
                              "lineage_idempotence.json"))
    print(f"\nLID suite: {summary['passed']}/{summary['total']} PASS")
    return 0 if summary["failed"] == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
