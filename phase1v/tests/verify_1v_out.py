#!/usr/bin/env python3
"""SRW3 Phase 1V — fail-closed krun-output verifier (companion of
run_1v_model_tests.sh).

Usage: verify_1v_out.py <tag> <rawfile> <expected_result> [cell=NAME:substr]...

Asserts, on the LAST <srw3|srw3g> configuration block of the raw krun output:
  1. exactly ONE final configuration block (a second block = nondeterministic
     multi-branch output = FAILURE — observed live when a configuration-
     expansion function is missing an equation: the gate requires goes
     symbolic and kore-exec prints BOTH branches);
  2. no stuck-function tool error (WarnFunctionWithoutEvaluators) and no
     [Error] from the backend;
  3. the <result> cell equals <expected_result>;
  4. every cell=NAME:substr assertion: the normalized (whitespace-collapsed)
     body of cell NAME contains substr.

Exit 0 = all assertions hold; nonzero = the first failed assertion (printed).
"""
import re
import sys


def norm(s: str) -> str:
    return " ".join(s.split())


def main() -> int:
    tag, raw, eres = sys.argv[1], sys.argv[2], sys.argv[3]
    cells = sys.argv[4:]
    txt = open(raw, encoding="utf-8", errors="replace").read()

    if "WarnFunctionWithoutEvaluators" in txt:
        print(f"{tag}: FAIL stuck function (WarnFunctionWithoutEvaluators) in backend output")
        return 1
    if "[Error]" in txt:
        print(f"{tag}: FAIL backend [Error] present in a designed-successful run")
        return 1

    blocks = re.findall(r"<srw3[a-z]?>.*?</srw3[a-z]?>", txt, re.S)
    if len(blocks) != 1:
        print(f"{tag}: FAIL expected exactly 1 final configuration block, found {len(blocks)} "
              f"(nondeterministic multi-branch output)")
        return 1
    final = blocks[-1]

    def cell(name: str) -> str | None:
        m = re.search(r"<%s>\s*(.*?)\s*</%s>" % (name, name), final, re.S)
        return norm(m.group(1)) if m else None

    res = cell("result")
    # quote-canonical: K pretty-prints String cells with quotes; expectations
    # may be written with or without them.
    def canon(s):
        s = norm(s).strip()
        if len(s) >= 2 and s[0] == '"' and s[-1] == '"':
            s = s[1:-1]
        return s
    if canon(res) != canon(eres):
        print(f"{tag}: FAIL result cell: expected {eres!r}, observed {res!r}")
        return 1

    for spec in cells:
        if not spec.startswith("cell="):
            print(f"{tag}: FAIL malformed assertion spec {spec!r}")
            return 1
        name, _, sub = spec[5:].partition(":")
        body = cell(name)
        if body is None:
            print(f"{tag}: FAIL cell <{name}> not found in the final configuration")
            return 1
        if norm(sub) not in body:
            print(f"{tag}: FAIL cell <{name}>: expected to contain {norm(sub)!r}, observed {body[:160]!r}")
            return 1

    print(f"{tag}: OK result={res} cells={len(cells)} asserted")
    return 0


if __name__ == "__main__":
    sys.exit(main())
