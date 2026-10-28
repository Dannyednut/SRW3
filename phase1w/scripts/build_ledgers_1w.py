#!/usr/bin/env python3
"""SRW3 Phase 1W — build the append-only claim ledger + exit-code inventory
from the machine-readable verdict ledgers of the model runner and the ghost
battery.

Inputs:
  phase1v/claims/model-verdicts-1w.csv   (tag,class,rc,expected,observed,verdict,note)
  phase1v/claims/ghost-verdicts-1w.csv   (same shape)
Outputs:
  phase1v/claims/claims-1w.csv    claim_id,expectation,class,source,exit_code,budget_s,note
  phase1v/claims/exit-codes-1w.csv claim_id,exit_code,budget_s,wall_s

Classification vocabulary (closed; summarized by summarize_1v.py):
  control      — an adversarial or recorded-outcome control (OLD-model exploits,
                 parse rejections, designed proof failures, the recorded 1U
                 old-model outcomes)
  regression   — fixed-model regression controls (T1/T2/GEN batteries, valid
                 flows, hardening blocks, the immutability control)
  proved       — a kprove claim that closes (the ghost per-claim battery)
  fidelity     — the byte-faithfulness certificate of the ghost artifact
expectation: PASS (the observed verdict matched the expectation) — any
deviation would have failed the runner and would appear as FAIL here.

Level III only.
"""
import csv
import os

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CL = os.path.join(BASE, "claims")

MODEL_CLASSES = {
    "parse-reject": "control",
}


def classify(tag: str, vclass: str) -> str:
    if vclass == "fidelity":
        return "fidelity"
    # parse rejections are adversarial controls regardless of model generation
    if vclass in MODEL_CLASSES:
        return MODEL_CLASSES[vclass]
    # the model-layer kprove rows (claims battery + negative control) are
    # regression rows of the fixed model
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
    for vcsv, source_label in (
        (os.path.join(CL, "model-verdicts-1w.csv"), "phase1w/tests/run_1w_model_tests.sh"),
        (os.path.join(CL, "ghost-verdicts-1w.csv"), "phase1w/proofs/run_1w_ghost.sh"),
    ):
        with open(vcsv) as f:
            # the note field is free text that may contain commas; split off
            # only the first six fields and keep the remainder as the note
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

    with open(os.path.join(CL, "claims-1w.csv"), "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=["claim_id", "expectation", "class", "source", "exit_code", "budget_s", "note"])
        w.writeheader()
        w.writerows(claims)
    with open(os.path.join(CL, "exit-codes-1w.csv"), "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=["claim_id", "exit_code", "budget_s", "wall_s"])
        w.writeheader()
        w.writerows(exits)
    print(f"claims-1w.csv: {len(claims)} rows; exit-codes-1w.csv: {len(exits)} rows")


if __name__ == "__main__":
    main()
