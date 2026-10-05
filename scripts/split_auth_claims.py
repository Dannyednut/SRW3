#!/usr/bin/env python3
"""Split Phase 1E proof files into one claim per file (the audit_ghost_gen
precedent) and return the list of (file, label, specmodule) triples.

Usage: python3 scripts/split_auth_claims.py <proof-file.k> <outdir>
Writes <outdir>/<stem>_<LABEL>.k, each containing the module preamble with all
claims removed except one, keeping the module name unchanged.
"""
import re
import sys
import os

def main() -> None:
    src, outdir = sys.argv[1], sys.argv[2]
    os.makedirs(outdir, exist_ok=True)
    text = open(src).read()
    stem = os.path.splitext(os.path.basename(src))[0]
    # split on top-level claim markers
    parts = re.split(r"(?m)^(\s*claim // (\w+)[^\n]*)\n", text)
    # parts: [pre, claimline, label, rest, claimline, label, rest, ...]
    pre = parts[0]
    triples = []
    i = 1
    while i + 2 < len(parts) + 1 and i < len(parts):
        claimline, label, rest = parts[i], parts[i + 1], parts[i + 2]
        # rest runs until the next claim; ensure endmodule only in the last chunk
        body = pre + claimline + "\n" + rest.rstrip() + "\n"
        # normalize endmodule: keep exactly one at the end
        body = body.replace("endmodule", "")
        body = body.rstrip() + "\nendmodule\n"
        out = os.path.join(outdir, f"{stem}_{label}.k")
        open(out, "w").write(body)
        triples.append((out, label))
        i += 3
    for out, label in triples:
        print(f"{out}\t{label}")

if __name__ == "__main__":
    main()
