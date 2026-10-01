#!/usr/bin/env python3
"""Generalized per-claim splitter for the Phase-1B ghost proof files.
Usage: split_gen_claims.py <proof-file> <obs-module> <prefix>
Emits /tmp/gen_claims/<prefix>_<LABEL>.k with module <prefix>-GC-<LABEL>
containing the single claim, and prints the label list."""
import re, os, sys

art, obsmod, prefix = sys.argv[1], sys.argv[2], sys.argv[3]
OUTDIR = "/tmp/gen_claims"
os.makedirs(OUTDIR, exist_ok=True)

text = open(art).read()
m = re.search(r"module " + obsmod + r"-GHOST-CLAIMS\n(.*?)\nendmodule", text, re.S)
if not m:
    sys.exit(f"FATAL: claims module {obsmod}-GHOST-CLAIMS not found in {art}")
body = m.group(1)
chunks = re.findall(
    r"((?:^  claim .*?\n)(?:    .*?\n)*?    \[(?:circularity, )?label\([A-Z0-9a-z-]+\)\])",
    body, re.M | re.S)
if not chunks:
    sys.exit("FATAL: no claims extracted")
labels = []
relpath = os.path.relpath(art, "/tmp/gen_claims")
for ch in chunks:
    lab = re.search(r"label\(([A-Za-z0-9-]+)\)", ch).group(1)
    labels.append(lab)
    mod = f"""requires "{relpath}"
module {prefix}-GC-{lab}
  imports {obsmod}-GHOST-OBS

{ch}
endmodule
"""
    open(f"{OUTDIR}/{prefix}_{lab}.k", "w").write(mod)
print(" ".join(labels))
