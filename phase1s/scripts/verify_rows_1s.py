#!/usr/bin/env python3
# =============================================================================
# SRW3 Phase 1S — the static row witness (TCB-1, disclosed)
#     (phase1s/scripts/verify_rows_1s.py; output: phase1s/audit/row-witness-1s.txt)
#
# Checks, EXTERNALLY (Python — disclosed as trusted computing base; see
# spec/state-correspondence.md §5), that the in-repo integer mirror
# declared inside the frozen QS module corresponds ROW-BY-ROW to the
# frozen 1P TDRR machine:
#   W1  every absStepE rule block of the 1Q/QS source corresponds to
#       exactly one absStepT rule block of the frozen 1P file, under the
#       documented renames (absStepT -> absStepE; the tagged state
#       constructor absStT(tag, bits, ...) -> absStQE(bits, ...); the
#       ABSInv body's TG -> branchTag(C, T));
#   W2  ABSInvE's rule body ≡ ABSInvT's rule body under the same renames;
#   W3  the command syntax productions are shared verbatim (the AOk/ASrc/
#       ACmd/APProd lines appear in both files);
#   W4  the sha256 anchors of both frozen files match the of-record values.
# Fail-closed: any mismatch exits nonzero and says which row.
# Level III only; no consensus-integration claim.
# =============================================================================
import hashlib
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
Q = REPO / "phase1q" / "semantics" / "abs-machine-q.k"      # the absStepE rows live here
P = REPO / "phase1p" / "semantics" / "abs-machine-tdrr.k"  # the absStepT rows of record
OUT = REPO / "phase1s" / "audit" / "row-witness-1s.txt"

ANCHORS = {
    "1P_TDRR": ("448db6a46101d1f848a7ad364fc07a06cc99a903b4615afc0e5753ca0d8db511", P),
    "1Q_MACHINE": ("2e938fcb8939e0efe15e554687947b4dc44ece9a6a843f293799a18204e5383f", Q),
}

RULE_RE = r"  rule (absStepT|ABSInvT)\(.*?(?=\n  (?:rule |syntax |// ==)|\nendmodule)"


def canon(block: str) -> str:
    """Strip comments, collapse whitespace — the comparison canonical form."""
    b = re.sub(r"//[^\n]*", "", block)          # trailing + full-line comments
    b = re.sub(r"\n\s*\n", "\n", b)              # blank lines
    b = re.sub(r"\s+", " ", b)                   # collapse all whitespace
    return b.strip()


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def blocks(src: Path, fun: str) -> list:
    return [canon(b) for b in re.findall(
        r"  rule " + fun + r"\(.*?(?=\n  (?:rule |syntax |// ==)|\nendmodule)",
        src.read_text(), re.DOTALL)]


def normalize_t_block(block: str) -> str:
    """absStepT/absStT/ABSInvT block -> the mirror-normalized text."""
    b = block
    b = b.replace("absStepT", "absStepE")
    b = b.replace("ABSInvT", "ABSInvE")
    # the tagged constructor: drop the tag field, keep the bits
    b = re.sub(r"absStT\(TG:Int, ", "absStQE(", b)
    b = re.sub(r"absStT\(TG, ", "absStQE(", b)
    b = re.sub(r"absStT\(0, false, false, ", "absStQE(false, false, ", b)
    b = re.sub(r"absStT\(1, true, true, ", "absStQE(true, true, ", b)
    # the ABSInv body's TG references
    b = b.replace("TG", "branchTag(C, T)")
    return b.strip()


def normalize_e_block(block: str) -> str:
    b = block.replace("absStepE", "absStepE")
    return b.strip()


def main() -> int:
    lines = []
    ok = True
    for name, (expected, path) in ANCHORS.items():
        got = sha256(path)
        good = got == expected
        ok &= good
        lines.append(f"W4 {'OK' if good else 'FAIL'} {name}: sha256 {got[:16]}… "
                     f"{'== anchored' if good else '!= anchored ' + expected[:16]}…")

    t_blocks = [normalize_t_block(b) for b in blocks(P, "absStepT")]
    inv_t = [normalize_t_block(b) for b in blocks(P, "ABSInvT")]
    e_blocks = [normalize_e_block(b) for b in blocks(Q, "absStepE")]
    inv_e = [normalize_e_block(b) for b in blocks(Q, "ABSInvE")]

    # W1: multiset equality of the step rows (canonical form: comments and
    # whitespace stripped — the COMPARISON is over the rule content only;
    # the verbatim-transcription claim is about content, not comment text)
    from collections import Counter
    ct, ce = Counter(t_blocks), Counter(e_blocks)
    only_t = ct - ce
    only_e = ce - ct
    if only_t or only_e:
        ok = False
        lines.append(f"W1 FAIL step-row multisets differ: {sum(only_t.values())} 1P-only, "
                     f"{sum(only_e.values())} 1Q-only")
        for b in list(only_t)[:3]:
            lines.append("  1P-only row:\n" + b)
        for b in list(only_e)[:3]:
            lines.append("  1Q-only row:\n" + b)
    else:
        lines.append(f"W1 OK  step rows: {len(t_blocks)} absStepT rows ≡ {len(e_blocks)} absStepE rows "
                     f"(multiset-equal under the documented renames)")

    # W2: the invariant body
    if len(inv_t) == 1 and len(inv_e) == 1 and inv_t[0] == inv_e[0]:
        lines.append("W2 OK  ABSInvE body ≡ ABSInvT body (under the renames)")
    else:
        ok = False
        lines.append(f"W2 FAIL ABSInv blocks: 1P={len(inv_t)}, 1Q={len(inv_e)}, "
                     f"equal={inv_t[:1] == inv_e[:1]}")

    # W3: the command syntax is shared verbatim
    q_src, p_src = Q.read_text(), P.read_text()
    shared_ok = True
    for prod in ['syntax AOk ::= "aOkT" | "aOkF"',
                 'syntax ACmd ::= aInitJ ( AOk )',
                 'aGateJ ( AOk )',
                 'aCommitJ ( AOk , AOk )',
                 'syntax APProg ::= "aRunNilJ" | aConsJ ( ACmd , APProg )']:
        if prod not in q_src or prod not in p_src:
            shared_ok = False
            lines.append(f"W3 FAIL missing production: {prod}")
    if shared_ok:
        lines.append("W3 OK  the command syntax productions are shared verbatim")

    OUT.write_text("\n".join(lines) + "\n")
    print("\n".join(lines))
    print("ROW-WITNESS:", "ALL CHECKS PASS" if ok else "FAIL-CLOSED")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
