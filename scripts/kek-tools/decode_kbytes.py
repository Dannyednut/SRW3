#!/usr/bin/env python3
"""Decode a K Bytes literal (e.g. b"abc\\x01\\x00\\x80") from krun output
and return the hex digest. Takes the LAST Bytes literal in the input."""
import re
import sys

raw = sys.stdin.read()
matches = re.findall(r'b"((?:[^"\\]|\\.)*)"', raw, re.S)
if not matches:
    print("", end="")
    sys.exit(1)
lit = matches[-1]
out = bytearray()
i = 0
while i < len(lit):
    c = lit[i]
    if c == "\\" and i + 1 < len(lit):
        n = lit[i + 1]
        if n == "x":
            out.append(int(lit[i + 2:i + 4], 16))
            i += 4
            continue
        mapping = {"n": 10, "t": 9, "r": 13, '"': 34, "\\": 92, "0": 0,
                   "a": 7, "b": 8, "f": 12, "v": 11, "'": 39}
        out.append(mapping.get(n, ord(n)))
        i += 2
        continue
    out.append(ord(c) if ord(c) < 256 else 0)
    i += 1
print(out.hex(), end="")
