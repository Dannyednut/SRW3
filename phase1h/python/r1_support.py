"""SRW3 Phase 1H-R1 — shared support for the repair pass.

Path helpers (the Phase 1H scripts hardcoded the original development
checkout path; R1 makes them checkout-independent), transcript rerun
markers, and git metadata access.  Contains NO secrets: git operations run
against the local clone only.
"""
from __future__ import annotations

import json
import os
import subprocess
import time

PYTHON_DIR = os.path.dirname(os.path.abspath(__file__))
PHASE1H_DIR = os.path.dirname(PYTHON_DIR)
REPO_ROOT = os.path.dirname(PHASE1H_DIR)
REPAIR_DIR = os.path.join(REPO_ROOT, "phase1h-r1-fix")
REPAIR_TRANSCRIPTS = os.path.join(REPAIR_DIR, "transcripts", "repair")

REPAIR_PHASE = "1H-R1"
REPAIR_BRANCH = "phase1h-r1-fix"


def git_meta() -> dict:
    """Local-clone git metadata (branch + HEAD sha); never contacts remotes."""
    out = {"branch": None, "commit": None, "basePhase1hSha": None}
    try:
        out["branch"] = subprocess.run(
            ["git", "rev-parse", "--abbrev-ref", "HEAD"], cwd=REPO_ROOT,
            capture_output=True, text=True, timeout=10).stdout.strip()
        out["commit"] = subprocess.run(
            ["git", "rev-parse", "HEAD"], cwd=REPO_ROOT,
            capture_output=True, text=True, timeout=10).stdout.strip()
        out["basePhase1hSha"] = subprocess.run(
            ["git", "rev-parse", "phase1h"], cwd=REPO_ROOT,
            capture_output=True, text=True, timeout=10).stdout.strip() or None
    except Exception:
        pass
    return out


def r1_meta() -> dict:
    """Rerun marker embedded in every regenerated Phase 1H transcript."""
    m = git_meta()
    return {
        "repairPhase": REPAIR_PHASE,
        "repairBranch": REPAIR_BRANCH,
        "repairCommit": m["commit"],
        "basePhase1hSha": m["basePhase1hSha"],
        "rerunAfterR1": True,
        "recordedAt": time.time(),
        "note": "transcript regenerated after the Phase 1H-R1 repair "
                "(lineage semantic idempotence + first-class "
                "SecurityContext_H binding)",
    }


def attach_and_dump(obj: dict, path: str) -> None:
    """Attach the rerun marker as a top-level key and write the JSON."""
    obj["_r1"] = r1_meta()
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        json.dump(obj, f, indent=1, default=str)


def ensure_repair_transcript_dir() -> str:
    os.makedirs(REPAIR_TRANSCRIPTS, exist_ok=True)
    return REPAIR_TRANSCRIPTS
