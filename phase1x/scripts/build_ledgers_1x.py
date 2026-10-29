#!/usr/bin/env python3
"""SRW3 Phase 1X — build the append-only claim ledger + exit-code inventory
from the machine-readable verdict ledgers (phase1x/scripts/build_ledgers_1x.py).

Inputs (phase1x/claims/):
  ghost-verdicts-1x.csv   (tag,class,rc,expected,observed,verdict,note) — the
                          FRESH Phase 1X ghost battery output (required)
  model-verdicts-1x.csv   — the model verdict ledger. In Phase 1X this is a
                          DISCLOSED FIXTURE: a byte-identical copy of the
                          committed, immutable Phase 1W model ledger
                          (phase1w/claims/model-verdicts-1w.csv), used to
                          exercise the combined-ledger gate. Its provenance is
                          preserved in the source column of every model row
                          ('fixture:phase1w/claims/model-verdicts-1w.csv') and
                          the historical file itself is never modified.

Outputs (phase1x/claims/):
  claims-1x.csv     claim_id,expectation,class,source,exit_code,budget_s,note
  exit-codes-1x.csv claim_id,exit_code,budget_s,wall_s

Classification vocabulary: control / regression / proved / fidelity (as 1W).
Duplicates are FATAL (ledgers must be per-run fresh; last-wins dedup is the
runner's responsibility via dedup_ledger).

Level III only.
"""
import csv
import os

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # phase1x/
CL = os.path.join(BASE, "claims")

MODEL_CLASSES = {
    "parse-reject": "control",
}

MODEL_SOURCE = "fixture:phase1w/claims/model-verdicts-1w.csv (1W evidence, immutable)"
GHOST_SOURCE = "phase1x/proofs/run_1x_ghost.sh (fresh Phase 1X run)"


def classify(tag: str, vclass: str) -> str:
    if vclass == "fidelity":
        return "fidelity"
    if vclass in MODEL_CLASSES:
        return MODEL_CLASSES[vclass]
    if tag.startswith("NEW1W-"):
        return "regression"
    if vclass == "kprove":
        if "NEG" in tag or tag.endswith("-GH-T") or tag == "ghost-GH-T":
            return "control"
        return "proved"
    if tag.startswith("OLD1U-") or tag.startswith("OLD1T-") or tag.startswith("OLD1V-"):
        return "control"
    return "regression"


def budget_for(rc: str) -> str:
    return "124" if rc == "124" else "120"


def main() -> None:
    claims, exits = [], []
    seen = set()
    inputs = (
        (os.path.join(CL, "model-verdicts-1x.csv"), MODEL_SOURCE),
        (os.path.join(CL, "ghost-verdicts-1x.csv"), GHOST_SOURCE),
    )
    for path, source_label in inputs:
        if not os.path.exists(path):
            raise SystemExit(f"FATAL: missing verdict ledger {path}")
        with open(path) as f:
            rows = [r for r in (line.rstrip("\n").split(",", 6) for line in f)
                    if r and r[0] != "tag"]
        for r in rows:
            tag, vclass, rc, expected, observed, verdict, note = r
            if tag in seen:
                raise SystemExit(f"FATAL: duplicate verdict row {tag} (ledgers must be per-run fresh)")
            seen.add(tag)
            cls = classify(tag, vclass)
            expectation = "PASS" if verdict == "OK" else "FAIL"
            claims.append({
                "claim_id": tag,
                "expectation": expectation,
                "class": cls,
                "source": source_label,
                "exit_code": rc,
                "budget_s": budget_for(rc),
                "note": f"{vclass}; expected [{expected}]; observed [{observed}]; {note}",
            })
            wall = "0"
            for tok in note.split():
                if tok.startswith("wall="):
                    wall = tok[5:]
            exits.append({"claim_id": tag, "exit_code": rc, "budget_s": budget_for(rc), "wall_s": wall})

    with open(os.path.join(CL, "claims-1x.csv"), "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=["claim_id", "expectation", "class", "source", "exit_code", "budget_s", "note"])
        w.writeheader()
        w.writerows(claims)
    with open(os.path.join(CL, "exit-codes-1x.csv"), "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=["claim_id", "exit_code", "budget_s", "wall_s"])
        w.writeheader()
        w.writerows(exits)
    n_model = sum(1 for c in claims if c["source"].startswith("fixture:"))
    print(f"claims-1x.csv: {len(claims)} rows ({n_model} fixture-model + {len(claims) - n_model} fresh-1X-ghost); "
          f"exit-codes-1x.csv: {len(exits)} rows")


if __name__ == "__main__":
    main()
