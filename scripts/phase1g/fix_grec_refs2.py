#!/usr/bin/env python3
"""Tolerant rewrite: every remaining #w3GRec( ... ) call (any line-wrapping)
becomes the threaded #w3GRecOf(#w3FRec(...), ...) form."""
import re

P = "/home/z/my-project/srw3-kevm/k/kevm/srw3-authz-evm.k"
s = open(P).read()


def rewrite(kind, m):
    # kind in {PSNB, SGN}: the argument tuple differs
    if kind == "PSNB":
        return ("#w3GRecOf( #w3FRec(PS, DECL, #w3FCUR, NB, HB, PL, PRESENTED)"
                ", PL, #w3FParRoot(PS, DECL, #w3FCUR), HB, #w3ExecTrace )")
    return ("#w3GRecOf( #w3FRec(SG, DECL, #w3FCUR, N, LinRoot, PL, PRESENTED)"
            ", PL, #w3FParRoot(SG, DECL, #w3FCUR), LinRoot, #w3ExecTrace )")


# match #w3GRec( <ws> PS|SG , DECL , NB|N , HB|LinRoot , PL , PRESENTED <ws> , <ws> #w3ExecTrace <ws> )
pat = re.compile(
    r"#w3GRec\(\s*(PS|SG)\s*,\s*DECL\s*,\s*(NB|N)\s*,\s*(HB|LinRoot)\s*,"
    r"\s*PL\s*,\s*PRESENTED\s*,\s*#w3ExecTrace\s*\)")

def sub(m):
    kind = "PSNB" if m.group(1) == "PS" else "SGN"
    return rewrite(kind, m)

s2, n = pat.subn(sub, s)
print("rewritten calls:", n)
open(P, "w").write(s2)
print("remaining old-style:", len(re.findall(r"#w3GRec\(", s2)))
