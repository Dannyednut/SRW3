#!/usr/bin/env python3
"""Split the ghost claims into per-claim spec modules for isolated kprove runs.
Emits /tmp/ghost_claims/c_<LABEL>.k with module SRW3-GC-<LABEL> containing the
single claim, and prints the label list."""
import re, os, sys

ART = "/home/z/my-project/srw3-kevm/proofs/induction_ghost.k"
OUTDIR = "/tmp/ghost_claims"
os.makedirs(OUTDIR, exist_ok=True)

text = open(ART).read()
# isolate the claims module body
m = re.search(r"module SRW3-GHOST-CLAIMS\n(.*?)\nendmodule", text, re.S)
if not m:
    sys.exit("FATAL: claims module not found")
body = m.group(1)

# split into claim chunks at line-start 'claim' boundaries
chunks = re.findall(r"((?:^  claim .*?\n)(?:    .*?\n)*?    \[(?:circularity, )?label\([A-Z0-9a-z-]+\)\])",
                    body, re.M | re.S)
if not chunks:
    sys.exit("FATAL: no claims extracted")

labels = []
for ch in chunks:
    lab = re.search(r"label\(([A-Za-z0-9-]+)\)", ch).group(1)
    labels.append(lab)
    mod = f"""requires "{ART}"
module SRW3-GC-{lab}
  imports SRW3-GHOST-OBS

{ch}
endmodule
"""
    open(f"{OUTDIR}/c_{lab}.k", "w").write(mod)

print(" ".join(labels))
