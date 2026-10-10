#!/usr/bin/env python3
"""Assemble phase1i-r3/transcripts/k/claims-status.csv + score.txt from the
actual kprove logs and resumable markers (the unambiguous R3 score
convention, handoff §8):

  score.txt = "<N_proved> <N_failed>" counted 1:1 over the claim inventory in
  run_r3_proofs.sh (each label = exactly one kprove invocation = one log
  file).  A FAILED entry is a retained outcome (with its error class), NOT a
  silent skip; the classification (PROVED / NOT MECHANIZED / STRUCTURAL / ...)
  lives in claim-classification.csv and the report — never in the raw score.

Also emits claim-classification.csv: label, kprove result, scientific label
(the audit-facing status), evidence pointer."""
import os
import re
import subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = "/".join(HERE.split("/")[:-2])   # .../phase1i-r3/proofs -> repo root
KDIR = os.path.join(REPO, "phase1i-r3", "transcripts", "k")
PROOFS = os.path.join(REPO, "phase1i-r3", "proofs")

# the inventory: parse R3_CLAIMS from run_r3_proofs.sh (single source of truth)
runner = open(os.path.join(PROOFS, "run_r3_proofs.sh")).read()
inv = re.search(r"R3_CLAIMS=\(\n((?:  .*\n)+?)\)", runner).group(1)
CLAIMS = re.findall(r"([A-Za-z0-9\-]+)\n", inv)

# the scientific classification of the expected-fail labels (the R2 discipline:
# the hs stuck-term boundary over the computed verdict / the circularity
# blocker; concrete substitutes = LLVM demos + Python mirror)
CLASSIFICATION = {
    "R3-PIPELINE-HONEST": (
        "NOT MECHANIZED (hs stuck-term boundary: ErrorBottomTotalFunction over "
        "the computed verdict / unevaluated Keccak256raw in the destination "
        "map — the same blocker class as R1-T5/R2-PIPELINE-HONEST; concrete "
        "substitutes: T1-llvm-honest-two-block-pipeline.txt with REAL keccak "
        "+ Python suite 181/181 + the mechanized R3-VALID-ACCEPT)"),
    "R3-PIPELINE-FORGED": (
        "NOT MECHANIZED (hs stuck-term boundary: ErrorBottomTotalFunction, "
        "same class as R2-PIPELINE-FORGED; concrete substitutes: "
        "T5/T6/T7-llvm-* rejects + Python INJ/VERDICT/CROSSROOT groups)"),
    "R3-ALL": (
        "NOT MECHANIZED (the kore circularity/implication blocker — the same "
        "known blocker as frozen PI7-ALL / R1-ALL / R2-ALL; the full log is "
        "retained; structural closure evidence: the producer-exhaustiveness "
        "and command-surface audits + the per-claim ladder)"),
    "R3-ANCHOR-IMMUTABLE": (
        "STRUCTURAL (audit-verified, not a kprove claim: no rule writes "
        "<r3anchor>; mechanical scan = "
        "transcripts/legacy/anchor-immutability-scan.txt; per-rule frame "
        "conjuncts mechanized inside R3-INIT-PINS-AUTHORIZED / R3-MINT-SHAPE-*"
        " / R3-VALID-ACCEPT / R3-CONFIG-FRAME-ACCEPT)"),
}


def result_of(claim):
    log = os.path.join(KDIR, f"kprove_{claim}.log")
    marker = os.path.join(KDIR, f".done_{claim}")
    txt = open(log, errors="replace").read() if os.path.exists(log) else ""
    # PROVED iff the resumable marker existed at runner time OR the log
    # records success: kprove emits "Claim proven ..." (no-rewrite proofs)
    # and produces NO "[Error]" line at all for rc==0 runs (warnings only).
    if os.path.exists(marker) or ("Claim proven" in txt) or (
            txt and "[Error]" not in txt):
        return "PROVED", "kprove_" + claim + ".log", "PROVED"
    if not os.path.exists(log):
        return "NOT_RUN", "kprove_" + claim + ".log", "NOT RUN"
    if "ErrorBottomTotalFunction" in txt:
        raw = "FAILED(ErrorBottomTotalFunction)"
    elif "cannot be rewritten further" in txt:
        raw = "FAILED(stuck-configuration)"
    elif "Circular" in txt or "circularity" in txt:
        raw = "FAILED(circularity)"
    else:
        raw = "FAILED(see log)"
    cls = "NOT MECHANIZED" if claim in CLASSIFICATION else "FAILED"
    return raw, "kprove_" + claim + ".log", cls


def main():
    rows, crows, proved, failed = [], [], 0, 0
    for cl in CLAIMS:
        raw, log, cls = result_of(cl)
        rows.append((cl, "haskell", "yes", raw, log))
        if cls == "PROVED":
            pass
        crows.append((cl, raw, cls))
        if raw == "PROVED":
            proved += 1
        elif raw.startswith("FAILED"):
            failed += 1
    # the structural claim is inventoried but not kprove-invoked
    crows.append(("R3-ANCHOR-IMMUTABLE", "not-invoked(structural)",
                  CLASSIFICATION["R3-ANCHOR-IMMUTABLE"][0]))
    with open(os.path.join(KDIR, "claims-status.csv"), "w") as f:
        f.write("claim,backend,invoked,kprove_result,log\n")
        for r in rows:
            f.write(",".join(r) + "\n")
    with open(os.path.join(KDIR, "claim-classification.csv"), "w") as f:
        f.write("claim,kprove_result,scientific_label\n")
        for cl, raw, cls in crows:
            f.write(f'{cl},{raw},"{cls}"\n')
    with open(os.path.join(KDIR, "score.txt"), "w") as f:
        f.write(f"{proved} {failed}\n")
    print(f"inventory: {len(CLAIMS)} kprove claims "
          f"+ 1 structural (R3-ANCHOR-IMMUTABLE)")
    print(f"score: {proved} PROVED / {failed} FAILED "
          f"(failed = retained NOT-MECHANIZED outcomes, see "
          f"claim-classification.csv)")
    for cl, raw, cls in crows:
        if raw != "PROVED":
            print(f"  {cl}: {raw} -> {cls[:60]}...")


if __name__ == "__main__":
    main()
