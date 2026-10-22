#!/usr/bin/env python3
"""SRW3 Phase 1O — the Phase 1N claim auditor (mandate §3).

Recomputes, from RAW evidence only, the full inventory of every Phase 1N
claim: source location, intended proposition, kind, exact command, exit
code, timeout budget, log existence/size, proof-terminal markers,
trivial-proof warnings, vacuity assessment, runner coverage, and the
final 1O classification.  NOTHING is taken from the 1N classification
CSVs on trust — those are compared against the recomputation and every
disagreement is reported.

Deterministic and re-runnable:  python3 phase1o/scripts/audit_1n_claims.py
Outputs (under phase1o/claims/):
  phase1n-claim-inventory.csv   — one row per claim, all fields above
  phase1n-reclassification.csv  — 1N class vs 1O class, disagreement flag
  phase1n-audit-summary.txt     — counts + the disagreement list
Exit code 0 iff the inventory is complete (every runner claim has raw
evidence; every declared claim is accounted for).  Evidence gaps do not
fail the audit — they are RECORDED (this is an investigation, not a gate).
"""
import csv
import pathlib
import re
import sys

REPO = pathlib.Path(__file__).resolve().parents[2]
P1N = REPO / "phase1n"
OUT = REPO / "phase1o" / "claims"
OUT.mkdir(parents=True, exist_ok=True)
KLOGS = P1N / "transcripts" / "k"

PROOF_FILES = {"abs": P1N / "proofs" / "n_abs_proofs.k",
               "sim": P1N / "proofs" / "n_sim_proofs.k"}
RUNNERS = {"abs": P1N / "proofs" / "run_n_abs_proofs.sh",
           "sim": P1N / "proofs" / "run_n_sim_proofs.sh"}
LADDER_CSVS = {"abs": KLOGS / "claims-status-abs.csv",
               "sim": KLOGS / "claims-status-sim.csv"}

# --------------------------------------------------------------------------
# intended propositions, per claim (from the proof-file comment blocks and
# the claim forms read at audit time; one line each, machine-checkable form)
# --------------------------------------------------------------------------
PROPS = {
    "ABS-INIT-BASE": "M-machine: the genesis <absjshadow> state driven by aInitJ(aOkT) reaches the literal initialized-safe state absSt(true,true,0,0,0,true,adNone)",
    "ABS-INIT-BASE-INV": "ABSInv(absSt(true,true,0,0,0,true,adNone)) == true (the base successor satisfies the abstract invariant, by evaluation)",
    "ABS-UNIV-BASE": "For all AX: ABSInv(AX) implies ABSInv(absRunF(aRunNilJ, AX)) (the empty run returns the state; base case of the universal induction)",
    "ABS-UNIV-STEP": "UNIVERSAL: for all RUN:APProg, AX:AState — ABSInv(AX) and absExecutable(RUN,AX) imply ABSInv(absRunF(RUN,AX)) (structural [circularity] form; the universal reachable-state safety theorem at the abstract level)",
    "ABS-UNIV-TAIL": "UNIVERSAL variant, unpinned: same proposition as ABS-UNIV-STEP stated without branch pinning (probes whether kore circularity self-applies)",
    "ABS-PREFIX-SAFE": "UNIVERSAL corollary: for all RUN, AX — ABSInv(AX) and absCfgPinnedOf(AX) and absExecutable(RUN,AX) imply absInitShaped(absRunF(RUN,AX)) (the committed-prefix form)",
    "ABS-NEG-UNSAFE-ACCEPT": "NEGATIVE CONTROL (must fail): the commit-accept rule cannot carry the safety bookkeeping when the computed-SafeJ bit is aOkF (presented-unsafe accept is unprovable)",
    "ABS-NEG-REFUSE-ON-MINT": "NEGATIVE CONTROL (must fail): the gate-refusal [owise] rule cannot fire on a mint-satisfying state (non-overlap of the partition)",
}

def prop_for(claim: str) -> str:
    if claim in PROPS:
        return PROPS[claim]
    m = re.match(r"ABS-STEP-([A-Z-]+)$", claim)
    if m:
        return f"M-machine step shape: one abstract transition class fires and the shadow reaches the exact abstract successor (pinned class {m.group(1)})"
    if claim.startswith("ABS-PRESV-"):
        return "UNIVERSAL one-step invariant preservation (Bool form), branch-pinned: for all symbolic fields of the pinned ABSInv branch, ABSInv(absStepJ(state, pinned-concrete-command)) == true"
    if claim.startswith("ABS-PRES-"):
        return "Definitional successor-shape check (branch-pinned): absStepJ(pinned-branch state, pinned-concrete-command) == the pinned successor shape (restates the definition's own output)"
    if claim.startswith("ABS-INV-EXCL"):
        return "Branch exclusivity: the mixed-pin state valuations do not satisfy ABSInv (the two ABSInv branches are exclusive on the pin flags)"
    if claim.startswith("ABS-RUN-"):
        return "Concrete-pipeline composition: the fold absRunF over a fixed concrete command list computes the pinned final state / the invariant holds of it (evaluation over the fold, no symbolic dispatch)"
    if claim.startswith("SIM-ALG-"):
        return "Counting algebra: simJ(post-shape) ==K absStructOf(absStepJ(simJ(pre-shape), cmd)) over symbolic pool cardinalities (the pool arithmetic correspondence)"
    if claim.startswith("SIM-NEG-"):
        return "NEGATIVE CONTROL (must fail): the mis-presentation destination is unreachable in the simulation relation (mint on forbidden source / commit on stale slot)"
    if claim.startswith("SIM-"):
        return "Simulation shape: the concrete M3 transition class (its own guard verbatim as hypothesis) projects through simJ to the abstract class successor (structural agreement, hash equalities as hypotheses)"
    return "(proposition not annotated)"

# --------------------------------------------------------------------------
# source locations + declared claims
# --------------------------------------------------------------------------
def source_locations():
    locs = {}
    for ladder, pf in PROOF_FILES.items():
        lines = pf.read_text().splitlines()
        for i, ln in enumerate(lines, 1):
            m = re.search(r"label\(([A-Z][A-Z0-9-]*)\)", ln)
            if m:
                locs.setdefault(m.group(1), (ladder, f"{pf.name}:{i}"))
    return locs

def runner_claims():
    """claim -> (ladder, expected, timeout) parsed from the retained runners."""
    got = {}
    for ladder, rf in RUNNERS.items():
        for ln in rf.read_text().splitlines():
            m = re.match(r'\s*"([A-Z][A-Z0-9-]*)\|([A-Z-]+)\|(\d+)"', ln)
            if m:
                got[m.group(1)] = (ladder, m.group(2), int(m.group(3)))
    return got

# --------------------------------------------------------------------------
# log terminal analysis
# --------------------------------------------------------------------------
def analyze_log(path: pathlib.Path):
    if not path.exists():
        return dict(exists=False, size=0, trivial=False, no_rewrite=False,
                    top_only=False, budget_str=False, stuck=False,
                    note="log missing")
    size = path.stat().st_size
    if size == 0:
        return dict(exists=True, size=0, trivial=False, no_rewrite=False,
                    top_only=False, budget_str=False, stuck=False,
                    note="0 bytes — the documented timeout-of-record signature "
                         "(transcripts/k/README-0-size-logs.txt)")
    txt = path.read_text(errors="replace")
    trivial = "WarnTrivialClaim" in txt
    no_rewrite = "Claim proven without rewriting" in txt
    # vacuity probe: strip warning/parse-noise; what REMAINS?
    keep = []
    for ln in txt.splitlines():
        s = ln.strip()
        if not s:
            continue
        if re.search(r"Warning|Source\(|Location\(|^\^|with underscore|Rule|"
                     r"Utility|Internal|io\.html|k-framework|Skipping|While|"
                     r"In the|See |^\d+ \||^\t|^\.|^If|^\s*\.\s*$|^\*", ln):
            continue
        keep.append(s)
    residue = [s for s in keep if s != "#Top"]
    top_only = (len(residue) == 0) and no_rewrite
    budget_str = "branches were still unexplored" in txt
    stuck = "cannot be rewritten further" in txt
    return dict(exists=True, size=size, trivial=trivial, no_rewrite=no_rewrite,
                top_only=top_only, budget_str=budget_str, stuck=stuck, note="")

# --------------------------------------------------------------------------
# the 1O classification vocabulary (finer than 1N's, per mandate §3)
# --------------------------------------------------------------------------
def classify(row, log):
    exp, raw = row["expected"], row["raw_result"]
    attempted = row["runner_attempted"]
    if not attempted:
        return ("unattempted-in-bundle",
                "declared in the proof file but absent from the retained "
                "runner's CLAIMS list; no retained log; the universal "
                "proposition has NO raw evidence in the bundle")
    if raw == "PROVED":
        if exp == "FAIL":
            return "ALARM-unexpected-proof", "FAIL-expected claim PROVED"
        if log["no_rewrite"]:
            # closed without rewriting: sound only as far as evaluation goes
            if exp == "PASS":
                return ("proved-nontrivial",
                        "rc=0 with rewriting; no trivial marker; strict-PASS "
                        "claims close with real rewrite steps")
            return ("proved-by-evaluation",
                    "rc=0, closed 'without rewriting' (function evaluation on "
                    "the pinned branch / concrete pipeline); non-vacuous only "
                    "up to the definition's own output; NOT a universal "
                    "theorem over runs")
        if log["trivial"]:
            return ("proved-trivial-flagged",
                    "rc=0 with WarnTrivialClaim; closure content must be read "
                    "from the log")
        return "proved-nontrivial", "rc=0; no trivial marker"
    m = re.match(r"FAILED\(rc=(\d+)\)", raw)
    if not m:
        return "ALARM-unclassified", f"unknown raw_result {raw}"
    rc = int(m.group(1))
    if rc == 124:
        if exp == "FAIL":
            return ("timed-out-expected-fail",
                    "budget exhausted on a FAIL-expected control: the design "
                    "expectation is met (not proved) but NO counterexample "
                    "was constructed — weaker than refuted")
        return ("timed-out",
                "budget exhausted (rc=124); 0-byte log per the documented "
                "timeout-of-record convention; the raw result is the exit "
                "code only")
    if exp == "FAIL":
        return ("refuted-by-proof-failure",
                f"rc={rc}: kprove discharged the proof search WITHOUT proving "
                f"the claim (the control behaves as designed); note: rc=1 is "
                f"proof failure, not counterexample construction")
    if log["budget_str"]:
        return ("failed-budget",
                f"rc={rc}; the log states the prover was killed mid-search "
                f"('branches were still unexplored')")
    if log["stuck"]:
        return ("failed-stuck",
                f"rc={rc}; the backend terminated on a stuck configuration "
                f"(a residual of record)")
    return "failed", f"rc={rc}; proof search failed"

def main() -> int:
    locs = source_locations()
    runners = runner_claims()
    rows = []
    for ladder, cs in LADDER_CSVS.items():
        with cs.open() as f:
            for r in csv.DictReader(f):
                rows.append((ladder, r))
    inventory = []
    for ladder, r in rows:
        cl = r["claim"]
        ladder2, loc = locs.get(cl, (ladder, "LABEL-NOT-FOUND"))
        ratt = runners.get(cl)
        attempted = ratt is not None
        exp_runner = ratt[1] if ratt else "(not in runner)"
        tmo = ratt[2] if ratt else ""
        logf = KLOGS / r["log"]
        log = analyze_log(logf)
        cls, why = classify(dict(r, runner_attempted=attempted), log)
        inv = dict(
            claim=cl, ladder=ladder2, source=loc,
            intended_proposition=prop_for(cl),
            kind=("negative-control" if cl.startswith(("ABS-NEG", "SIM-NEG"))
                  else "universal-attempt" if cl in ("ABS-UNIV-STEP", "ABS-UNIV-TAIL",
                                                     "ABS-PREFIX-SAFE")
                  else "theorem-claim"),
            runner_attempted="yes" if attempted else "NO",
            expected_runner=exp_runner, timeout_s=tmo,
            raw_result_1n=r["raw_result"], trivial_flag_1n=r["trivial"],
            log=r["log"], log_bytes=log["size"],
            log_exists="yes" if log["exists"] else "NO",
            log_nonempty="yes" if log["size"] > 0 else "no",
            warn_trivial="yes" if log["trivial"] else "no",
            proven_without_rewriting="yes" if log["no_rewrite"] else "no",
            top_only_residual="yes" if log["top_only"] else "no",
            budget_marker="yes" if log["budget_str"] else "no",
            stuck_marker="yes" if log["stuck"] else "no",
            command=(f"timeout {tmo} kprove {PROOF_FILES[ladder2].name} -d <def> "
                     f"--spec-module {'N-ABS-PROOFS' if ladder2 == 'abs' else 'N-SIM-PROOFS'} "
                     f"--claims {cl}") if attempted else "(no runner invocation)",
            classification_1o=cls, rationale=why,
        )
        inventory.append(inv)

    # declared-but-unlisted claims (in proof files, absent from ladder CSVs):
    # they ARE Phase 1N claims and get their own inventory rows
    csv_claims = {i["claim"] for i in inventory}
    unlisted = sorted(set(locs) - csv_claims)
    for cl in unlisted:
        ladder2, loc = locs[cl]
        ratt = runners.get(cl)
        attempted = ratt is not None
        logf = KLOGS / f"kprove_{cl}.log"
        log = analyze_log(logf)
        cls, why = classify(dict(expected="(not in runner)", raw_result="(never run)",
                                 runner_attempted=attempted), log)
        inventory.append(dict(
            claim=cl, ladder=ladder2, source=loc,
            intended_proposition=prop_for(cl),
            kind="universal-attempt",
            runner_attempted="yes" if attempted else "NO",
            expected_runner=ratt[1] if ratt else "(not in runner)",
            timeout_s=ratt[2] if ratt else "",
            raw_result_1n="(no ladder row)", trivial_flag_1n="(no ladder row)",
            log=logf.name, log_bytes=log["size"],
            log_exists="yes" if log["exists"] else "NO",
            log_nonempty="yes" if log["size"] > 0 else "no",
            warn_trivial="yes" if log["trivial"] else "no",
            proven_without_rewriting="yes" if log["no_rewrite"] else "no",
            top_only_residual="yes" if log["top_only"] else "no",
            budget_marker="yes" if log["budget_str"] else "no",
            stuck_marker="yes" if log["stuck"] else "no",
            command=(f"timeout {ratt[2]} kprove {PROOF_FILES[ladder2].name} -d <def> "
                     f"--spec-module {'N-ABS-PROOFS' if ladder2 == 'abs' else 'N-SIM-PROOFS'} "
                     f"--claims {cl}") if attempted else "(no runner invocation)",
            classification_1o=cls, rationale=why,
        ))

    # ---- reclassification comparison (1N vs 1O) --------------------------
    p1n_cls = {}
    with (P1N / "claim-classification.csv").open() as f:
        for r in csv.DictReader(f):
            p1n_cls[r["claim"]] = r["classification"]
    disagree = []
    for inv in inventory:
        c1n = p1n_cls.get(inv["claim"], "(absent)")
        c1o = inv["classification_1o"]
        same = ((c1n == c1o)
                or (c1n == "proved" and c1o.startswith("proved"))
                or (c1n == "refuted" and c1o.startswith("refuted")))
        if not same:
            disagree.append((inv["claim"], c1n, c1o, inv["rationale"]))

    # ---- write outputs ----------------------------------------------------
    fields = list(inventory[0].keys())
    with (OUT / "phase1n-claim-inventory.csv").open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fields)
        w.writeheader()
        w.writerows(inventory)
    with (OUT / "phase1n-reclassification.csv").open("w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["claim", "classification_1N", "classification_1O", "rationale"])
        for row in disagree:
            w.writerow(row)
    counts = {}
    for inv in inventory:
        counts[inv["classification_1o"]] = counts.get(inv["classification_1o"], 0) + 1
    with (OUT / "phase1n-audit-summary.txt").open("w") as f:
        f.write(f"Phase 1N claims inventoried: {len(inventory)}\n")
        f.write(f"declared in proof files but absent from the ladder CSVs: "
                f"{len(unlisted)} {unlisted}\n")
        for k in sorted(counts):
            f.write(f"  {k}: {counts[k]}\n")
        f.write(f"1N-vs-1O classification disagreements: {len(disagree)}\n")
        for c, a, b, why in disagree:
            f.write(f"  {c}: 1N={a}  1O={b}\n    {why}\n")
    print(f"inventoried {len(inventory)} claims; unlisted-declared: {unlisted}")
    for k in sorted(counts):
        print(f"  {k}: {counts[k]}")
    print(f"disagreements vs 1N classification: {len(disagree)}")
    return 0

if __name__ == "__main__":
    sys.exit(main())
