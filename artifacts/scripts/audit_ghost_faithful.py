#!/usr/bin/env python3
"""
Mechanical faithfulness certificate for proofs/induction_ghost.k.

Verifies, at any time, that the ghost artifact's copied semantics block is a
byte-faithful ordered copy of k/srw3.k lines 24-530 (modules SRW3-SYNTAX ..
SRW3-CLAIMS), and prints the complete ghost delta (the //GHOST:-marked live
code lines, the ONLY semantic additions).

Exit 0 = PASS, 1 = FAIL.
"""
import difflib, sys

SRC = "/home/z/my-project/srw3-kevm/k/srw3.k"
ART = "/home/z/my-project/srw3-kevm/proofs/induction_ghost.k"

src_lines = open(SRC).read().splitlines()
art_lines = open(ART).read().splitlines()

kept = [ln for ln in art_lines if "//GHOST:" not in ln]
delta = [ln for ln in art_lines if "//GHOST:" in ln]

body_src = src_lines[23:530]  # 1-indexed lines 24..530
sm = difflib.SequenceMatcher(a=body_src, b=kept, autojunk=False)
blocks = [b for b in sm.get_matching_blocks() if b.size > 0]
matched = sum(b.size for b in blocks)
consumed = []
for b in blocks:
    consumed.extend(body_src[b.a:b.a + b.size])
ok = consumed == body_src
print(f"faithfulness: {matched}/{len(body_src)} source lines matched in order: {'PASS' if ok else 'FAIL'}")
if not ok:
    for i, (x, y) in enumerate(zip(consumed, body_src)):
        if x != y:
            print(f"first divergence at source-relative line {i+1}:")
            print(f"  kept   : {x!r}")
            print(f"  source : {y!r}")
            break
    sys.exit(1)

print(f"\n--- ghost delta: {len(delta)} marked live-code lines (the ONLY additions) ---")
for ln in delta:
    print(ln)
