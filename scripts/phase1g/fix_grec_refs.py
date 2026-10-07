#!/usr/bin/env python3
"""Mechanical rewrite of the gate-rule #w3GRec calls to the threaded
#w3GRecOf form (the OOM fix); also replaces the stale #w3GRec declaration
with the #w3GRecOf declaration."""
import re

P = "/home/z/my-project/srw3-kevm/k/kevm/srw3-authz-evm.k"
s = open(P).read()

# 1. declaration swap
s = s.replace(
    '  syntax LinRecG ::= "#w3GRec" "(" Map "," Map "," Int "," Bytes "," Bytes ","\n'
    '                       List "," List ")" [function]',
    '  syntax LinRecG ::= "#w3GRecOf" "(" LinRecF "," Bytes "," Bytes "," Bytes ","\n'
    '                       List ")" [function]')

# 2. the two call shapes (PS/NB/HB and SG/N/LinRoot variants)
def repl_ps(m):
    return ("#w3GRecOf( #w3FRec(PS, DECL, #w3FCUR, NB, HB, PL, PRESENTED)\n"
            "                           , PL, #w3FParRoot(PS, DECL, #w3FCUR)\n"
            "                           , HB, #w3ExecTrace )")

s2 = re.sub(r"#w3GRec\(PS, DECL, NB, HB, PL, PRESENTED, #w3ExecTrace\)",
            repl_ps, s)
s2 = re.sub(r"#w3GRec\(PS, DECL, NB, HB, PL, PRESENTED\n(\s*)\)",
            lambda m: "#w3GRecOf( #w3FRec(PS, DECL, #w3FCUR, NB, HB, PL, PRESENTED)\n"
                      f"{m.group(1)}    , PL, #w3FParRoot(PS, DECL, #w3FCUR), HB\n"
                      f"{m.group(1)}    , #w3ExecTrace )", s2)

def repl_sg(m):
    return ("#w3GRecOf( #w3FRec(SG, DECL, #w3FCUR, N, LinRoot, PL, PRESENTED)\n"
            "                           , PL, #w3FParRoot(SG, DECL, #w3FCUR)\n"
            "                           , LinRoot, #w3ExecTrace )")

s2 = re.sub(r"#w3GRec\(SG, DECL, N, LinRoot, PL, PRESENTED, #w3ExecTrace\)",
            repl_sg, s2)
s2 = re.sub(r"#w3GRec\(SG, DECL, N, LinRoot, PL, PRESENTED\n(\s*)\)",
            lambda m: "#w3GRecOf( #w3FRec(SG, DECL, #w3FCUR, N, LinRoot, PL, PRESENTED)\n"
                      f"{m.group(1)}    , PL, #w3FParRoot(SG, DECL, #w3FCUR), LinRoot\n"
                      f"{m.group(1)}    , #w3ExecTrace )", s2)

open(P, "w").write(s2)
left = len(re.findall(r"#w3GRec\(", s2))
print("remaining old-style #w3GRec( calls:", left)
print("declaration swapped:", '"#w3GRecOf" "(" LinRecF' in s2)
